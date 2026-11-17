// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {FeeMath} from "../../src/libraries/FeeMath.sol";

/// @notice Exposes FeeMath's internal functions so reverts can be asserted.
contract FeeMathHarness {
    function split(uint256 amount, uint256 feeBps) external pure returns (uint256, uint256) {
        return FeeMath.split(amount, feeBps);
    }

    function effectiveBps(uint256 baseBps, uint256 discountBps) external pure returns (uint256) {
        return FeeMath.effectiveBps(baseBps, discountBps);
    }

    function checkBps(uint256 bps) external pure {
        FeeMath.checkBps(bps);
    }
}
