// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseTest} from "./utils/BaseTest.sol";
import {IOrkoPay} from "../src/interfaces/IOrkoPay.sol";

contract OrkoPayRefundTest is BaseTest {
    function test_refund_returnsGrossToCustomer() public {
        bytes32 id = _payEth(alice, "INV-4001", northwind, 10 ether);
        uint256 before = alice.balance;

        vm.prank(northwind);
        pay.refund(id);

        assertEq(alice.balance, before + 10 ether, "customer made whole");
        assertEq(pay.balanceOf(northwind, ETH), 0, "merchant debited");
        assertEq(pay.accruedFees(ETH), 0, "fee returned");
        assertEq(address(pay).balance, 0, "no residue");
        assertEq(uint8(pay.orderOf(id).status), uint8(IOrkoPay.OrderStatus.Refunded));
    }

    function test_refund_token() public {
        bytes32 id = _payUsdc(alice, "INV-4002", contoso, 750e6);
        uint256 before = usdc.balanceOf(alice);

        vm.prank(contoso);
        pay.refund(id);

        assertEq(usdc.balanceOf(alice), before + 750e6);
        assertEq(pay.balanceOf(contoso, address(usdc)), 0);
        assertEq(pay.accruedFees(address(usdc)), 0);
    }

    function test_refund_onlyAffectsTargetOrder() public {
        bytes32 a = _payEth(alice, "INV-4003", northwind, 4 ether);
        _payEth(bob, "INV-4004", northwind, 6 ether);

        vm.prank(northwind);
        pay.refund(a);

        uint256 remainingFee = _fee(6 ether, 200);
        assertEq(pay.balanceOf(northwind, ETH), 6 ether - remainingFee);
        assertEq(pay.accruedFees(ETH), remainingFee);
    }

    function test_refund_byOwner() public {
        bytes32 id = _payEth(alice, "INV-4005", northwind, 1 ether);

        vm.prank(admin);
        pay.refund(id);

        assertEq(uint8(pay.orderOf(id).status), uint8(IOrkoPay.OrderStatus.Refunded));
    }

    function test_refund_emitsOrderRefunded() public {
        bytes32 id = _payEth(alice, "INV-4006", northwind, 1 ether);

        vm.expectEmit(true, true, false, true, address(pay));
        emit IOrkoPay.OrderRefunded(id, alice, ETH, 1 ether);

        vm.prank(northwind);
        pay.refund(id);
    }

    function test_refund_allowedAtWindowBoundary() public {
        bytes32 id = _payEth(alice, "INV-4007", northwind, 1 ether);
        vm.warp(block.timestamp + REFUND_WINDOW);

        vm.prank(northwind);
        pay.refund(id);
    }

    function test_refund_revertsAfterWindow() public {
        bytes32 id = _payEth(alice, "INV-4008", northwind, 1 ether);
        vm.warp(block.timestamp + REFUND_WINDOW + 1);

        vm.prank(northwind);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.RefundWindowClosed.selector, id));
        pay.refund(id);
    }

    function test_refund_revertsForOtherMerchant() public {
        bytes32 id = _payEth(alice, "INV-4009", northwind, 1 ether);

        vm.prank(contoso);
        vm.expectRevert(IOrkoPay.Unauthorized.selector);
        pay.refund(id);
    }

    function test_refund_revertsForCustomer() public {
        bytes32 id = _payEth(alice, "INV-4010", northwind, 1 ether);

        vm.prank(alice);
        vm.expectRevert(IOrkoPay.Unauthorized.selector);
        pay.refund(id);
    }

    function test_refund_revertsTwice() public {
        bytes32 id = _payEth(alice, "INV-4011", northwind, 1 ether);

        vm.startPrank(northwind);
        pay.refund(id);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.OrderNotRefundable.selector, id));
        pay.refund(id);
        vm.stopPrank();
    }

    function test_refund_revertsForUnknownOrder() public {
        bytes32 id = _orderId("INV-missing");

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.OrderNotRefundable.selector, id));
        pay.refund(id);
    }

    function test_refund_revertsIfMerchantAlreadyWithdrew() public {
        bytes32 id = _payEth(alice, "INV-4012", northwind, 1 ether);
        uint256 net = pay.balanceOf(northwind, ETH);

        vm.startPrank(northwind);
        pay.withdraw(ETH, net);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.InsufficientBalance.selector, net, 0));
        pay.refund(id);
        vm.stopPrank();
    }
}
