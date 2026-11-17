// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IOrkoPay} from "../interfaces/IOrkoPay.sol";
import {IMerchantRegistry} from "../interfaces/IMerchantRegistry.sol";

/// @title OrkoPayLens
/// @notice Stateless batch-read helper for the merchant dashboard and the
///         indexer. Not part of the settlement path; safe to redeploy freely.
contract OrkoPayLens {
    struct MerchantSummary {
        address merchant;
        IMerchantRegistry.Merchant info;
        uint256[] balances; // aligned with the `assets` argument
    }

    /// @notice Balances of `merchant` for each of `assets`.
    function balancesOf(IOrkoPay pay, address merchant, address[] calldata assets)
        public
        view
        returns (uint256[] memory out)
    {
        out = new uint256[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            out[i] = pay.balanceOf(merchant, assets[i]);
        }
    }

    /// @notice Order records for each of `orderIds`.
    function ordersOf(IOrkoPay pay, bytes32[] calldata orderIds)
        external
        view
        returns (IOrkoPay.Order[] memory out)
    {
        out = new IOrkoPay.Order[](orderIds.length);
        for (uint256 i; i < orderIds.length; ++i) {
            out[i] = pay.orderOf(orderIds[i]);
        }
    }

    /// @notice Registry record plus balances for each merchant in `merchants`.
    function summaries(
        IOrkoPay pay,
        IMerchantRegistry registry,
        address[] calldata merchants,
        address[] calldata assets
    ) external view returns (MerchantSummary[] memory out) {
        out = new MerchantSummary[](merchants.length);
        for (uint256 i; i < merchants.length; ++i) {
            out[i] = MerchantSummary({
                merchant: merchants[i],
                info: registry.merchantOf(merchants[i]),
                balances: balancesOf(pay, merchants[i], assets)
            });
        }
    }
}
