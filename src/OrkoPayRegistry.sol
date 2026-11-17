// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "./utils/Ownable.sol";
import {Ownable2Step} from "./utils/Ownable2Step.sol";
import {IMerchantRegistry} from "./interfaces/IMerchantRegistry.sol";

/// @title OrkoPayRegistry
/// @notice On-chain directory of merchants permitted to receive payments
///         through OrkoPay.
/// @dev Roles:
///      - owner (operations multisig): operator management, payout changes.
///      - operators (merchant onboarding service): registration, status, tiers.
contract OrkoPayRegistry is IMerchantRegistry, Ownable2Step {
    /// @notice Largest tier discount an operator may assign (10%).
    uint16 public constant MAX_TIER_DISCOUNT_BPS = 1_000;

    /// @notice Accounts allowed to onboard and manage merchants.
    mapping(address account => bool) public isOperator;

    mapping(address merchant => Merchant) private _merchants;
    address[] private _merchantList;

    event OperatorSet(address indexed operator, bool enabled);
    event MerchantRegistered(
        address indexed merchant, address indexed payout, uint16 tierDiscountBps, string name
    );
    event MerchantStatusChanged(address indexed merchant, bool active);
    event MerchantTierChanged(address indexed merchant, uint16 tierDiscountBps);
    event PayoutUpdated(address indexed merchant, address indexed previous, address indexed payout);

    error NotOperator();
    error InvalidPayout();
    error AlreadyRegistered(address merchant);
    error UnknownMerchant(address merchant);
    error TierTooHigh(uint16 tierDiscountBps);

    modifier onlyOperator() {
        if (!isOperator[msg.sender] && msg.sender != owner()) revert NotOperator();
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ---------------------------------------------------------------------
    // Owner
    // ---------------------------------------------------------------------

    /// @notice Grants or revokes the operator role.
    function setOperator(address operator, bool enabled) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        isOperator[operator] = enabled;
        emit OperatorSet(operator, enabled);
    }

    /// @notice Changes where `merchant`'s withdrawals are sent.
    /// @dev Restricted to the owner: a compromised operator key must not be
    ///      able to redirect merchant funds.
    function updatePayout(address merchant, address payout) external onlyOwner {
        Merchant storage m = _requireKnown(merchant);
        if (payout == address(0)) revert InvalidPayout();
        address previous = m.payout;
        m.payout = payout;
        emit PayoutUpdated(merchant, previous, payout);
    }

    // ---------------------------------------------------------------------
    // Operators
    // ---------------------------------------------------------------------

    /// @notice Registers a new merchant.
    /// @param merchant        Merchant's operating address (used as identifier).
    /// @param payout          Address that receives the merchant's withdrawals.
    /// @param tierDiscountBps Fee discount in basis points (0 = standard rate).
    /// @param name            Human-readable label.
    function register(
        address merchant,
        address payout,
        uint16 tierDiscountBps,
        string calldata name
    ) external onlyOperator {
        if (merchant == address(0) || payout == address(0)) revert InvalidPayout();
        if (_merchants[merchant].registeredAt != 0) revert AlreadyRegistered(merchant);
        if (tierDiscountBps > MAX_TIER_DISCOUNT_BPS) revert TierTooHigh(tierDiscountBps);

        _merchants[merchant] = Merchant({
            active: true,
            tierDiscountBps: tierDiscountBps,
            registeredAt: uint64(block.timestamp),
            payout: payout,
            name: name
        });
        _merchantList.push(merchant);

        emit MerchantRegistered(merchant, payout, tierDiscountBps, name);
    }

    /// @notice Activates or deactivates a merchant. Inactive merchants cannot
    ///         receive new payments but can still withdraw.
    function setActive(address merchant, bool active) external onlyOperator {
        Merchant storage m = _requireKnown(merchant);
        m.active = active;
        emit MerchantStatusChanged(merchant, active);
    }

    /// @notice Updates a merchant's fee tier.
    function setTier(address merchant, uint16 tierDiscountBps) external onlyOperator {
        Merchant storage m = _requireKnown(merchant);
        if (tierDiscountBps > MAX_TIER_DISCOUNT_BPS) revert TierTooHigh(tierDiscountBps);
        m.tierDiscountBps = tierDiscountBps;
        emit MerchantTierChanged(merchant, tierDiscountBps);
    }

    // ---------------------------------------------------------------------
    // IMerchantRegistry
    // ---------------------------------------------------------------------

    /// @inheritdoc IMerchantRegistry
    function isActive(address merchant) external view returns (bool) {
        return _merchants[merchant].active;
    }

    /// @inheritdoc IMerchantRegistry
    function payoutOf(address merchant) external view returns (address) {
        return _merchants[merchant].payout;
    }

    /// @inheritdoc IMerchantRegistry
    function tierDiscountOf(address merchant) external view returns (uint16) {
        return _merchants[merchant].tierDiscountBps;
    }

    /// @inheritdoc IMerchantRegistry
    function merchantOf(address merchant) external view returns (Merchant memory) {
        return _merchants[merchant];
    }

    // ---------------------------------------------------------------------
    // Enumeration
    // ---------------------------------------------------------------------

    /// @notice Number of merchants ever registered.
    function merchantCount() external view returns (uint256) {
        return _merchantList.length;
    }

    /// @notice Paginated list of merchant addresses in registration order.
    function merchants(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory page)
    {
        uint256 len = _merchantList.length;
        if (offset >= len) return new address[](0);

        uint256 end = limit > len - offset ? len : offset + limit;
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; ++i) {
            page[i - offset] = _merchantList[i];
        }
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    function _requireKnown(address merchant) private view returns (Merchant storage m) {
        m = _merchants[merchant];
        if (m.registeredAt == 0) revert UnknownMerchant(merchant);
    }
}
