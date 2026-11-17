// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FeeMath} from "../src/libraries/FeeMath.sol";
import {FeeMathHarness} from "./harness/FeeMathHarness.sol";

contract FeeMathTest is Test {
    uint256 internal constant MAX_FEE_BPS = 1_000;

    FeeMathHarness internal h;

    function setUp() public {
        h = new FeeMathHarness();
    }

    function test_split_example() public view {
        (uint256 fee, uint256 net) = h.split(10 ether, 250);
        assertEq(fee, 0.25 ether);
        assertEq(net, 9.75 ether);
    }

    function test_split_roundsDownInMerchantFavour() public view {
        (uint256 fee, uint256 net) = h.split(49, 200);
        assertEq(fee, 0);
        assertEq(net, 49);
    }

    function testFuzz_split_conservesValue(uint256 amount, uint256 bps) public view {
        amount = bound(amount, 0, type(uint128).max);
        bps = bound(bps, 0, MAX_FEE_BPS);

        (uint256 fee, uint256 net) = h.split(amount, bps);

        assertEq(fee + net, amount, "net + fee == gross");
        assertLe(fee, (amount * MAX_FEE_BPS) / 10_000, "fee within cap");
    }

    function testFuzz_split_revertsAboveCap(uint256 bps) public {
        bps = bound(bps, MAX_FEE_BPS + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(FeeMath.FeeTooHigh.selector, bps));
        h.split(1 ether, bps);
    }

    function testFuzz_effectiveBps_flooredAtZero(uint16 base, uint16 discount) public view {
        uint256 eff = h.effectiveBps(base, discount);

        assertLe(eff, base);
        if (discount >= base) assertEq(eff, 0);
        else assertEq(eff, uint256(base) - discount);
    }
}
