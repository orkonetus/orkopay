// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseTest} from "./utils/BaseTest.sol";
import {RevertingReceiver} from "./mocks/RevertingReceiver.sol";
import {ReentrantPayout} from "./mocks/ReentrantPayout.sol";
import {IOrkoPay} from "../src/interfaces/IOrkoPay.sol";
import {SafeTransferLib} from "../src/libraries/SafeTransferLib.sol";

contract OrkoPayWithdrawTest is BaseTest {
    function test_withdraw_paysRegisteredPayout() public {
        _payEth(alice, "INV-3001", northwind, 10 ether);
        uint256 bal = pay.balanceOf(northwind, ETH);

        vm.prank(northwind);
        pay.withdraw(ETH, bal);

        assertEq(northwindPayout.balance, bal, "payout received");
        assertEq(pay.balanceOf(northwind, ETH), 0, "balance cleared");
        assertEq(northwind.balance, 0, "operator address not paid");
    }

    function test_withdraw_partial() public {
        _payEth(alice, "INV-3002", northwind, 10 ether);
        uint256 bal = pay.balanceOf(northwind, ETH);

        vm.prank(northwind);
        pay.withdraw(ETH, 1 ether);

        assertEq(pay.balanceOf(northwind, ETH), bal - 1 ether);
        assertEq(northwindPayout.balance, 1 ether);
    }

    function test_withdraw_token() public {
        _payUsdc(alice, "INV-3003", contoso, 2_000e6);
        uint256 bal = pay.balanceOf(contoso, address(usdc));

        vm.prank(contoso);
        pay.withdraw(address(usdc), bal);

        assertEq(usdc.balanceOf(contosoPayout), bal);
        assertEq(pay.balanceOf(contoso, address(usdc)), 0);
    }

    function test_withdraw_emitsWithdrawal() public {
        _payEth(alice, "INV-3004", northwind, 1 ether);

        vm.expectEmit(true, true, false, true, address(pay));
        emit IOrkoPay.Withdrawal(northwind, ETH, northwindPayout, 0.5 ether);

        vm.prank(northwind);
        pay.withdraw(ETH, 0.5 ether);
    }

    function test_withdraw_revertsWhenOverBalance() public {
        _payEth(alice, "INV-3005", northwind, 1 ether);
        uint256 bal = pay.balanceOf(northwind, ETH);

        vm.prank(northwind);
        vm.expectRevert(
            abi.encodeWithSelector(IOrkoPay.InsufficientBalance.selector, bal + 1, bal)
        );
        pay.withdraw(ETH, bal + 1);
    }

    function test_withdraw_revertsOnZero() public {
        vm.prank(northwind);
        vm.expectRevert(IOrkoPay.ZeroAmount.selector);
        pay.withdraw(ETH, 0);
    }

    function test_withdraw_allowedWhilePaused() public {
        _payEth(alice, "INV-3006", northwind, 1 ether);

        vm.prank(admin);
        pay.pause();

        vm.prank(northwind);
        pay.withdraw(ETH, 0.1 ether);
        assertEq(northwindPayout.balance, 0.1 ether);
    }

    function test_withdraw_allowedAfterDeactivation() public {
        _payEth(alice, "INV-3007", northwind, 1 ether);

        vm.prank(ops);
        registry.setActive(northwind, false);

        vm.prank(northwind);
        pay.withdraw(ETH, 0.1 ether);
        assertEq(northwindPayout.balance, 0.1 ether);
    }

    function test_withdraw_followsPayoutUpdate() public {
        _payEth(alice, "INV-3008", northwind, 1 ether);
        address newPayout = makeAddr("northwindTreasury");

        vm.prank(admin);
        registry.updatePayout(northwind, newPayout);

        vm.prank(northwind);
        pay.withdraw(ETH, 0.1 ether);
        assertEq(newPayout.balance, 0.1 ether);
        assertEq(northwindPayout.balance, 0);
    }

    function test_withdraw_revertsWhenPayoutRejectsETH() public {
        RevertingReceiver sink = new RevertingReceiver();
        _payEth(alice, "INV-3009", northwind, 1 ether);

        vm.prank(admin);
        registry.updatePayout(northwind, address(sink));

        vm.prank(northwind);
        vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
        pay.withdraw(ETH, 0.1 ether);
    }

    function test_withdraw_cannotReenter() public {
        address evil = makeAddr("evil");
        ReentrantPayout payout = new ReentrantPayout(IOrkoPay(address(pay)));

        vm.prank(ops);
        registry.register(evil, address(payout), 0, "Evil Corp");
        _payEth(alice, "INV-3010", evil, 1 ether);
        uint256 bal = pay.balanceOf(evil, ETH);

        vm.prank(evil);
        vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
        pay.withdraw(ETH, bal / 2);

        assertEq(pay.balanceOf(evil, ETH), bal, "balance untouched");
    }
}
