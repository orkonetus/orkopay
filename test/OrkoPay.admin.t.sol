// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseTest} from "./utils/BaseTest.sol";
import {OrkoPay} from "../src/OrkoPay.sol";
import {OrkoPayRegistry} from "../src/OrkoPayRegistry.sol";
import {IOrkoPay} from "../src/interfaces/IOrkoPay.sol";
import {IMerchantRegistry} from "../src/interfaces/IMerchantRegistry.sol";
import {Ownable} from "../src/utils/Ownable.sol";
import {Ownable2Step} from "../src/utils/Ownable2Step.sol";
import {FeeMath} from "../src/libraries/FeeMath.sol";

contract OrkoPayAdminTest is BaseTest {
    // --- constructor ---------------------------------------------------------

    function test_constructor_rejectsZeroRegistry() public {
        vm.expectRevert(IOrkoPay.InvalidAddress.selector);
        new OrkoPay(admin, IMerchantRegistry(address(0)), feeRecipient, 250, 1 days);
    }

    function test_constructor_rejectsFeeAboveCap() public {
        vm.expectRevert(abi.encodeWithSelector(FeeMath.FeeTooHigh.selector, 1_001));
        new OrkoPay(admin, registry, feeRecipient, 1_001, 1 days);
    }

    function test_constructor_rejectsLongRefundWindow() public {
        vm.expectRevert(IOrkoPay.InvalidConfig.selector);
        new OrkoPay(admin, registry, feeRecipient, 250, 31 days);
    }

    // --- fees ----------------------------------------------------------------

    function test_collectFees_byRecipient() public {
        _payEth(alice, "INV-5001", contoso, 10 ether);
        uint256 fees = pay.accruedFees(ETH);

        vm.prank(feeRecipient);
        pay.collectFees(ETH);

        assertEq(feeRecipient.balance, fees);
        assertEq(pay.accruedFees(ETH), 0);
    }

    function test_collectFees_byOwnerPaysRecipient() public {
        _payEth(alice, "INV-5002", contoso, 10 ether);
        uint256 fees = pay.accruedFees(ETH);

        vm.prank(admin);
        pay.collectFees(ETH);

        assertEq(feeRecipient.balance, fees);
        assertEq(admin.balance, 0);
    }

    function test_collectFees_isPerAsset() public {
        _payEth(alice, "INV-5003", contoso, 10 ether);
        _payUsdc(alice, "INV-5004", contoso, 1_000e6);

        vm.prank(feeRecipient);
        pay.collectFees(address(usdc));

        assertEq(usdc.balanceOf(feeRecipient), _fee(1_000e6, 250));
        assertEq(pay.accruedFees(ETH), _fee(10 ether, 250), "ETH fees untouched");
    }

    function test_collectFees_revertsForStranger() public {
        _payEth(alice, "INV-5005", contoso, 1 ether);

        vm.prank(bob);
        vm.expectRevert(IOrkoPay.Unauthorized.selector);
        pay.collectFees(ETH);
    }

    function test_collectFees_revertsWhenEmpty() public {
        vm.prank(feeRecipient);
        vm.expectRevert(IOrkoPay.ZeroAmount.selector);
        pay.collectFees(ETH);
    }

    function test_setBaseFee() public {
        vm.prank(admin);
        pay.setBaseFee(300);
        assertEq(pay.baseFeeBps(), 300);
    }

    function test_setBaseFee_revertsAboveCap() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(FeeMath.FeeTooHigh.selector, 1_001));
        pay.setBaseFee(1_001);
    }

    function test_setFeeRecipient_revertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert(IOrkoPay.InvalidAddress.selector);
        pay.setFeeRecipient(address(0));
    }

    function test_setRefundWindow_revertsAboveMax() public {
        vm.prank(admin);
        vm.expectRevert(IOrkoPay.InvalidConfig.selector);
        pay.setRefundWindow(30 days + 1);
    }

    function test_setSupportedAsset_rejectsNativeSentinel() public {
        vm.prank(admin);
        vm.expectRevert(IOrkoPay.InvalidAddress.selector);
        pay.setSupportedAsset(ETH, true);
    }

    function test_setRegistry_carriesBalances() public {
        _payEth(alice, "INV-5006", northwind, 1 ether);
        uint256 bal = pay.balanceOf(northwind, ETH);

        OrkoPayRegistry next = new OrkoPayRegistry(admin);
        vm.startPrank(admin);
        next.register(northwind, northwindPayout, 50, "Northwind Store");
        pay.setRegistry(next);
        vm.stopPrank();

        assertEq(pay.balanceOf(northwind, ETH), bal);
        vm.prank(northwind);
        pay.withdraw(ETH, bal);
        assertEq(northwindPayout.balance, bal);
    }

    // --- access control ------------------------------------------------------

    function test_adminFunctions_revertForNonOwner() public {
        vm.startPrank(ops);

        vm.expectRevert(Ownable.NotOwner.selector);
        pay.setBaseFee(100);

        vm.expectRevert(Ownable.NotOwner.selector);
        pay.setFeeRecipient(ops);

        vm.expectRevert(Ownable.NotOwner.selector);
        pay.setRegistry(registry);

        vm.expectRevert(Ownable.NotOwner.selector);
        pay.setRefundWindow(1 days);

        vm.expectRevert(Ownable.NotOwner.selector);
        pay.setSupportedAsset(address(usdc), false);

        vm.expectRevert(Ownable.NotOwner.selector);
        pay.pause();

        vm.stopPrank();
    }

    // --- ownership -----------------------------------------------------------

    function test_ownership_twoStepTransfer() public {
        address multisig = makeAddr("multisig");

        vm.prank(admin);
        pay.transferOwnership(multisig);
        assertEq(pay.owner(), admin, "unchanged until accepted");
        assertEq(pay.pendingOwner(), multisig);

        vm.prank(multisig);
        pay.acceptOwnership();
        assertEq(pay.owner(), multisig);
        assertEq(pay.pendingOwner(), address(0));
    }

    function test_ownership_onlyPendingCanAccept() public {
        vm.prank(admin);
        pay.transferOwnership(makeAddr("multisig"));

        vm.prank(bob);
        vm.expectRevert(Ownable2Step.NotPendingOwner.selector);
        pay.acceptOwnership();
    }
}
