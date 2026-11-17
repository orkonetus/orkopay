// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseTest} from "./utils/BaseTest.sol";
import {OrkoPayRegistry} from "../src/OrkoPayRegistry.sol";
import {IMerchantRegistry} from "../src/interfaces/IMerchantRegistry.sol";
import {Ownable} from "../src/utils/Ownable.sol";

contract OrkoPayRegistryTest is BaseTest {
    address internal fabrikam = makeAddr("fabrikam");
    address internal fabrikamPayout = makeAddr("fabrikamPayout");

    function test_register_byOperator() public {
        vm.warp(1_760_000_000);
        vm.prank(ops);
        registry.register(fabrikam, fabrikamPayout, 100, "Fabrikam Digital");

        IMerchantRegistry.Merchant memory m = registry.merchantOf(fabrikam);
        assertTrue(m.active);
        assertEq(m.payout, fabrikamPayout);
        assertEq(m.tierDiscountBps, 100);
        assertEq(m.registeredAt, 1_760_000_000);
        assertEq(m.name, "Fabrikam Digital");
        assertEq(registry.merchantCount(), 3);
    }

    function test_register_byOwner() public {
        vm.prank(admin);
        registry.register(fabrikam, fabrikamPayout, 0, "Fabrikam Digital");
        assertTrue(registry.isActive(fabrikam));
    }

    function test_register_revertsForStranger() public {
        vm.prank(bob);
        vm.expectRevert(OrkoPayRegistry.NotOperator.selector);
        registry.register(fabrikam, fabrikamPayout, 0, "Fabrikam Digital");
    }

    function test_register_revertsWhenDuplicate() public {
        vm.prank(ops);
        vm.expectRevert(
            abi.encodeWithSelector(OrkoPayRegistry.AlreadyRegistered.selector, northwind)
        );
        registry.register(northwind, northwindPayout, 0, "Northwind Again");
    }

    function test_register_revertsOnZeroPayout() public {
        vm.prank(ops);
        vm.expectRevert(OrkoPayRegistry.InvalidPayout.selector);
        registry.register(fabrikam, address(0), 0, "Fabrikam Digital");
    }

    function test_register_revertsWhenTierTooHigh() public {
        vm.prank(ops);
        vm.expectRevert(abi.encodeWithSelector(OrkoPayRegistry.TierTooHigh.selector, 1_001));
        registry.register(fabrikam, fabrikamPayout, 1_001, "Fabrikam Digital");
    }

    function test_setActive_togglesStatus() public {
        vm.startPrank(ops);
        registry.setActive(northwind, false);
        assertFalse(registry.isActive(northwind));
        registry.setActive(northwind, true);
        assertTrue(registry.isActive(northwind));
        vm.stopPrank();
    }

    function test_setActive_revertsForUnknown() public {
        vm.prank(ops);
        vm.expectRevert(abi.encodeWithSelector(OrkoPayRegistry.UnknownMerchant.selector, fabrikam));
        registry.setActive(fabrikam, false);
    }

    function test_setTier() public {
        vm.prank(ops);
        registry.setTier(contoso, 75);
        assertEq(registry.tierDiscountOf(contoso), 75);
    }

    function test_updatePayout_onlyOwner() public {
        address treasury = makeAddr("treasury");

        vm.prank(ops);
        vm.expectRevert(Ownable.NotOwner.selector);
        registry.updatePayout(northwind, treasury);

        vm.prank(admin);
        registry.updatePayout(northwind, treasury);
        assertEq(registry.payoutOf(northwind), treasury);
    }

    function test_setOperator_revoke() public {
        vm.prank(admin);
        registry.setOperator(ops, false);

        vm.prank(ops);
        vm.expectRevert(OrkoPayRegistry.NotOperator.selector);
        registry.setTier(contoso, 10);
    }

    function test_merchants_pagination() public {
        vm.prank(ops);
        registry.register(fabrikam, fabrikamPayout, 0, "Fabrikam Digital");

        address[] memory first = registry.merchants(0, 2);
        assertEq(first.length, 2);
        assertEq(first[0], northwind);
        assertEq(first[1], contoso);

        address[] memory rest = registry.merchants(2, 10);
        assertEq(rest.length, 1);
        assertEq(rest[0], fabrikam);

        assertEq(registry.merchants(5, 10).length, 0);
        assertEq(registry.merchants(1, type(uint256).max).length, 2);
    }
}
