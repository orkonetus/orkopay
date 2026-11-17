// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "./utils/Ownable.sol";
import {Ownable2Step} from "./utils/Ownable2Step.sol";
import {Pausable} from "./utils/Pausable.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
import {FeeMath} from "./libraries/FeeMath.sol";
import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {IMerchantRegistry} from "./interfaces/IMerchantRegistry.sol";
import {IOrkoPay} from "./interfaces/IOrkoPay.sol";

/// @title OrkoPay
/// @notice Settlement contract for crypto payments made to OrkoNet merchants.
///         Customers pay for an order in ETH or a supported stablecoin; the
///         payment is credited to the merchant net of the platform fee, and the
///         merchant withdraws to their registered payout address on demand.
/// @dev Balances are pull-based and tracked per (merchant, asset). Native ETH
///      is represented as `asset == address(0)`.
contract OrkoPay is IOrkoPay, Ownable2Step, Pausable, ReentrancyGuard {
    using SafeTransferLib for address;

    /// @notice Sentinel asset address for native ETH.
    address public constant NATIVE = address(0);

    /// @notice Upper bound on the configurable refund window.
    uint32 public constant MAX_REFUND_WINDOW = 30 days;

    /// @notice Merchant directory used to validate payees and resolve fees.
    IMerchantRegistry public registry;

    /// @notice Address that receives swept platform fees.
    address public feeRecipient;

    /// @notice Platform base fee in basis points, before merchant discount.
    uint16 public baseFeeBps;

    /// @notice Time after payment during which an order can be refunded.
    uint32 public refundWindow;

    /// @notice ERC-20 tokens accepted for payment (ETH is always accepted).
    mapping(address token => bool) public supportedAsset;

    /// @notice Lifetime gross volume settled per asset.
    mapping(address asset => uint256) public totalVolume;

    mapping(address merchant => mapping(address asset => uint256)) private _balances;
    mapping(address asset => uint256) private _accruedFees;
    mapping(bytes32 orderId => Order) private _orders;

    event RegistryUpdated(address indexed registry);
    event FeeRecipientUpdated(address indexed recipient);
    event BaseFeeUpdated(uint16 bps);
    event RefundWindowUpdated(uint32 window);
    event SupportedAssetUpdated(address indexed token, bool supported);

    constructor(
        address initialOwner,
        IMerchantRegistry registry_,
        address feeRecipient_,
        uint16 baseFeeBps_,
        uint32 refundWindow_
    ) Ownable(initialOwner) {
        if (address(registry_) == address(0) || feeRecipient_ == address(0)) {
            revert InvalidAddress();
        }
        FeeMath.checkBps(baseFeeBps_);
        if (refundWindow_ > MAX_REFUND_WINDOW) revert InvalidConfig();

        registry = registry_;
        feeRecipient = feeRecipient_;
        baseFeeBps = baseFeeBps_;
        refundWindow = refundWindow_;
    }

    // ---------------------------------------------------------------------
    // Payments
    // ---------------------------------------------------------------------

    /// @inheritdoc IOrkoPay
    function deposit(bytes32 orderId, address merchant)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        _settle(orderId, merchant, NATIVE, msg.value);
    }

    /// @inheritdoc IOrkoPay
    function depositToken(bytes32 orderId, address merchant, address token, uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        if (token == NATIVE || !supportedAsset[token]) revert UnsupportedAsset(token);

        _settle(orderId, merchant, token, amount);

        // --- interaction ---
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IOrkoPay
    /// @dev Callable by the order's merchant, or by the owner for support
    ///      escalations. The merchant's share is debited from their
    ///      unwithdrawn balance and the platform fee is returned from accrued
    ///      fees, so the customer always receives the full gross amount.
    function refund(bytes32 orderId) external nonReentrant {
        Order storage o = _orders[orderId];
        if (o.status != OrderStatus.Paid) revert OrderNotRefundable(orderId);
        if (msg.sender != o.merchant && msg.sender != owner()) revert Unauthorized();
        if (block.timestamp > uint256(o.paidAt) + refundWindow) {
            revert RefundWindowClosed(orderId);
        }

        address asset = o.asset;
        uint256 net = o.gross - o.fee;
        uint256 bal = _balances[o.merchant][asset];
        if (bal < net) revert InsufficientBalance(net, bal);

        // --- effects ---
        o.status = OrderStatus.Refunded;
        _balances[o.merchant][asset] = bal - net;
        _accruedFees[asset] -= o.fee;

        // --- interaction ---
        _transferOut(asset, o.customer, o.gross);

        emit OrderRefunded(orderId, o.customer, asset, o.gross);
    }

    /// @inheritdoc IOrkoPay
    /// @dev Intentionally not gated by `whenNotPaused`: merchants must always be
    ///      able to exit with settled funds.
    function withdraw(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = _balances[msg.sender][asset];
        if (amount > bal) revert InsufficientBalance(amount, bal);

        address to = registry.payoutOf(msg.sender);
        if (to == address(0)) revert MerchantInactive(msg.sender);

        // --- effects ---
        _balances[msg.sender][asset] = bal - amount;

        // --- interaction ---
        _transferOut(asset, to, amount);

        emit Withdrawal(msg.sender, asset, to, amount);
    }

    // ---------------------------------------------------------------------
    // Fees
    // ---------------------------------------------------------------------

    /// @inheritdoc IOrkoPay
    function collectFees(address asset) external nonReentrant {
        if (msg.sender != feeRecipient && msg.sender != owner()) revert Unauthorized();

        uint256 amount = _accruedFees[asset];
        if (amount == 0) revert ZeroAmount();

        // --- effects ---
        _accruedFees[asset] = 0;

        // --- interaction ---
        address to = feeRecipient;
        _transferOut(asset, to, amount);

        emit FeesCollected(asset, to, amount);
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    /// @notice Points OrkoPay at a new merchant registry.
    /// @dev Existing balances are keyed by merchant address and carry over;
    ///      merchants must be present in the new registry to withdraw.
    function setRegistry(IMerchantRegistry registry_) external onlyOwner {
        if (address(registry_) == address(0)) revert InvalidAddress();
        registry = registry_;
        emit RegistryUpdated(address(registry_));
    }

    /// @notice Updates the platform base fee. Applies to new payments only.
    function setBaseFee(uint16 bps) external onlyOwner {
        FeeMath.checkBps(bps);
        baseFeeBps = bps;
        emit BaseFeeUpdated(bps);
    }

    /// @notice Updates the address that receives swept fees.
    function setFeeRecipient(address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        feeRecipient = recipient;
        emit FeeRecipientUpdated(recipient);
    }

    /// @notice Updates the refund window. Applies to existing orders as well.
    function setRefundWindow(uint32 window) external onlyOwner {
        if (window > MAX_REFUND_WINDOW) revert InvalidConfig();
        refundWindow = window;
        emit RefundWindowUpdated(window);
    }

    /// @notice Enables or disables an ERC-20 as a payment asset.
    /// @dev Only plain ERC-20s are supported: no fee-on-transfer or rebasing
    ///      tokens. Disabling a token does not affect existing balances.
    function setSupportedAsset(address token, bool supported) external onlyOwner {
        if (token == NATIVE) revert InvalidAddress();
        supportedAsset[token] = supported;
        emit SupportedAssetUpdated(token, supported);
    }

    /// @notice Halts new payments. Withdrawals and refunds stay available.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes new payments.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @inheritdoc IOrkoPay
    function balanceOf(address merchant, address asset) external view returns (uint256) {
        return _balances[merchant][asset];
    }

    /// @inheritdoc IOrkoPay
    function accruedFees(address asset) external view returns (uint256) {
        return _accruedFees[asset];
    }

    /// @inheritdoc IOrkoPay
    function orderOf(bytes32 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    /// @dev Records the order and credits the merchant. Callers perform any
    ///      inbound token transfer after this returns.
    function _settle(bytes32 orderId, address merchant, address asset, uint256 gross) private {
        if (gross == 0) revert ZeroAmount();
        if (_orders[orderId].status != OrderStatus.None) revert OrderExists(orderId);
        if (!registry.isActive(merchant)) revert MerchantInactive(merchant);

        uint256 feeBps = FeeMath.effectiveBps(baseFeeBps, registry.tierDiscountOf(merchant));
        (uint256 fee, uint256 net) = FeeMath.split(gross, feeBps);

        // --- effects ---
        _balances[merchant][asset] += net;
        _accruedFees[asset] += fee;
        totalVolume[asset] += gross;
        _orders[orderId] = Order({
            customer: msg.sender,
            paidAt: uint64(block.timestamp),
            status: OrderStatus.Paid,
            merchant: merchant,
            asset: asset,
            gross: gross,
            fee: fee
        });

        emit PaymentReceived(orderId, msg.sender, merchant, asset, gross, fee);
    }

    function _transferOut(address asset, address to, uint256 amount) private {
        if (asset == NATIVE) {
            to.safeTransferETH(amount);
        } else {
            asset.safeTransfer(to, amount);
        }
    }
}
