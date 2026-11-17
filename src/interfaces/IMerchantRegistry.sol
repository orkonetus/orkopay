// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title IMerchantRegistry
/// @notice Read interface OrkoPay uses to resolve merchant settlement details.
interface IMerchantRegistry {
    struct Merchant {
        bool active;
        uint16 tierDiscountBps; // discount off the platform base fee
        uint64 registeredAt;
        address payout; // destination for merchant withdrawals
        string name; // human-readable label, e.g. "Northwind Store"
    }

    /// @notice Whether `merchant` may currently receive payments.
    function isActive(address merchant) external view returns (bool);

    /// @notice Address that receives `merchant`'s withdrawals.
    function payoutOf(address merchant) external view returns (address);

    /// @notice Fee discount for `merchant`, in basis points.
    function tierDiscountOf(address merchant) external view returns (uint16);

    /// @notice Full registry record for `merchant`.
    function merchantOf(address merchant) external view returns (Merchant memory);
}
