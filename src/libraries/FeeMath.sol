// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title FeeMath
/// @notice Basis-point fee calculations for OrkoPay settlement.
/// @dev Fees are expressed in basis points (1 bp = 0.01%, 10_000 bps = 100%).
///      Denomination-agnostic: works on raw wei or token base units.
library FeeMath {
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @dev Hard cap on any configured platform fee (10%).
    uint256 internal constant MAX_FEE_BPS = 1_000;

    error FeeTooHigh(uint256 bps);

    /// @notice Reverts if `bps` exceeds the platform fee cap.
    function checkBps(uint256 bps) internal pure {
        if (bps > MAX_FEE_BPS) revert FeeTooHigh(bps);
    }

    /// @notice Splits `amount` into the platform fee and the merchant's net.
    /// @dev Fee rounds down in the merchant's favour.
    /// @param amount Gross amount paid by the customer.
    /// @param feeBps Effective fee in basis points.
    /// @return fee   Portion retained by the platform.
    /// @return net   Portion credited to the merchant.
    function split(uint256 amount, uint256 feeBps)
        internal
        pure
        returns (uint256 fee, uint256 net)
    {
        checkBps(feeBps);
        fee = (amount * feeBps) / BPS_DENOMINATOR;
        net = amount - fee;
    }

    /// @notice Effective fee for a merchant: base rate minus tier discount,
    ///         floored at zero.
    function effectiveBps(uint256 baseBps, uint256 tierDiscountBps)
        internal
        pure
        returns (uint256)
    {
        if (tierDiscountBps >= baseBps) return 0;
        return baseBps - tierDiscountBps;
    }
}
