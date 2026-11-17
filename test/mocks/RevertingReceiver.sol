// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @notice Payout address that rejects ETH, e.g. a misconfigured Safe module.
contract RevertingReceiver {
    receive() external payable {
        revert("RevertingReceiver: no ETH");
    }
}
