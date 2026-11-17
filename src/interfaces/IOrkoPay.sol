// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title IOrkoPay
/// @notice External interface for the OrkoPay settlement contract.
/// @dev `asset == address(0)` denotes native ETH throughout.
interface IOrkoPay {
    enum OrderStatus {
        None,
        Paid,
        Refunded
    }

    struct Order {
        address customer; // payer of record
        uint64 paidAt; // block timestamp of payment
        OrderStatus status;
        address merchant;
        address asset; // address(0) for ETH
        uint256 gross; // amount paid by the customer
        uint256 fee; // platform fee retained at payment time
    }

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    /// @notice Emitted when a customer pays for an order.
    event PaymentReceived(
        bytes32 indexed orderId,
        address indexed customer,
        address indexed merchant,
        address asset,
        uint256 gross,
        uint256 fee
    );

    /// @notice Emitted when an order is refunded in full to its customer.
    event OrderRefunded(
        bytes32 indexed orderId, address indexed customer, address asset, uint256 amount
    );

    /// @notice Emitted when a merchant withdraws settled funds.
    event Withdrawal(address indexed merchant, address indexed asset, address to, uint256 amount);

    /// @notice Emitted when accrued platform fees are swept.
    event FeesCollected(address indexed asset, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ZeroAmount();
    error InvalidAddress();
    error InvalidConfig();
    error Unauthorized();
    error UnsupportedAsset(address asset);
    error MerchantInactive(address merchant);
    error OrderExists(bytes32 orderId);
    error OrderNotRefundable(bytes32 orderId);
    error RefundWindowClosed(bytes32 orderId);
    error InsufficientBalance(uint256 requested, uint256 available);

    // ---------------------------------------------------------------------
    // Payments
    // ---------------------------------------------------------------------

    /// @notice Pays for `orderId` in ETH. The full `msg.value` is settled.
    function deposit(bytes32 orderId, address merchant) external payable;

    /// @notice Pays for `orderId` in a supported ERC-20 (e.g. USDC). Requires
    ///         prior approval of `amount` to this contract.
    function depositToken(bytes32 orderId, address merchant, address token, uint256 amount)
        external;

    /// @notice Refunds a paid order in full to its customer.
    function refund(bytes32 orderId) external;

    /// @notice Withdraws `amount` of `asset` from the caller's settled balance
    ///         to their registered payout address.
    function withdraw(address asset, uint256 amount) external;

    /// @notice Sweeps all accrued platform fees in `asset` to the fee recipient.
    function collectFees(address asset) external;

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Settled, withdrawable balance of `merchant` in `asset`.
    function balanceOf(address merchant, address asset) external view returns (uint256);

    /// @notice Platform fees in `asset` awaiting collection.
    function accruedFees(address asset) external view returns (uint256);

    /// @notice Full record for `orderId` (zeroed if unknown).
    function orderOf(bytes32 orderId) external view returns (Order memory);
}
