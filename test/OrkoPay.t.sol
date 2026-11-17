// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseTest} from "./utils/BaseTest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IOrkoPay} from "../src/interfaces/IOrkoPay.sol";
import {Pausable} from "../src/utils/Pausable.sol";
import {SafeTransferLib} from "../src/libraries/SafeTransferLib.sol";

contract OrkoPayDepositTest is BaseTest {
    // --- ETH ---------------------------------------------------------------

    function test_deposit_creditsNetOfFee() public {
        _payEth(alice, "INV-1001", northwind, 10 ether);

        uint256 fee = _fee(10 ether, 200); // 2.5% base - 0.5% tier
        assertEq(pay.balanceOf(northwind, ETH), 10 ether - fee, "merchant net");
        assertEq(pay.accruedFees(ETH), fee, "accrued fee");
        assertEq(pay.totalVolume(ETH), 10 ether, "volume");
        assertEq(address(pay).balance, 10 ether, "custody");
    }

    function test_deposit_recordsOrder() public {
        vm.warp(1_750_000_000);
        bytes32 id = _payEth(alice, "INV-1002", contoso, 2 ether);

        IOrkoPay.Order memory o = pay.orderOf(id);
        assertEq(o.customer, alice);
        assertEq(o.merchant, contoso);
        assertEq(o.asset, ETH);
        assertEq(o.gross, 2 ether);
        assertEq(o.fee, _fee(2 ether, 250));
        assertEq(o.paidAt, 1_750_000_000);
        assertEq(uint8(o.status), uint8(IOrkoPay.OrderStatus.Paid));
    }

    function test_deposit_emitsPaymentReceived() public {
        bytes32 id = _orderId("INV-1003");

        vm.expectEmit(true, true, true, true, address(pay));
        emit IOrkoPay.PaymentReceived(id, alice, northwind, ETH, 1 ether, _fee(1 ether, 200));

        vm.prank(alice);
        pay.deposit{value: 1 ether}(id, northwind);
    }

    function test_deposit_revertsOnZeroValue() public {
        vm.prank(alice);
        vm.expectRevert(IOrkoPay.ZeroAmount.selector);
        pay.deposit{value: 0}(_orderId("INV-1004"), northwind);
    }

    function test_deposit_revertsForUnknownMerchant() public {
        address ghost = makeAddr("ghost");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.MerchantInactive.selector, ghost));
        pay.deposit{value: 1 ether}(_orderId("INV-1005"), ghost);
    }

    function test_deposit_revertsForDeactivatedMerchant() public {
        vm.prank(ops);
        registry.setActive(contoso, false);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.MerchantInactive.selector, contoso));
        pay.deposit{value: 1 ether}(_orderId("INV-1006"), contoso);
    }

    function test_deposit_revertsOnDuplicateOrderId() public {
        bytes32 id = _payEth(alice, "INV-1007", northwind, 1 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.OrderExists.selector, id));
        pay.deposit{value: 1 ether}(id, northwind);
    }

    function test_deposit_revertsWhenPaused() public {
        vm.prank(admin);
        pay.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pay.deposit{value: 1 ether}(_orderId("INV-1008"), northwind);
    }

    function test_deposit_usesTierAtPaymentTime() public {
        bytes32 first = _payEth(alice, "INV-1009", northwind, 10 ether);

        vm.prank(ops);
        registry.setTier(northwind, 250); // waives the fee entirely

        bytes32 second = _payEth(alice, "INV-1010", northwind, 10 ether);

        assertEq(pay.orderOf(first).fee, _fee(10 ether, 200));
        assertEq(pay.orderOf(second).fee, 0);
    }

    // --- ERC-20 -------------------------------------------------------------

    function test_depositToken_creditsNetOfFee() public {
        _payUsdc(alice, "INV-2001", contoso, 1_000e6);

        uint256 fee = _fee(1_000e6, 250);
        assertEq(pay.balanceOf(contoso, address(usdc)), 1_000e6 - fee, "merchant net");
        assertEq(pay.accruedFees(address(usdc)), fee, "accrued fee");
        assertEq(usdc.balanceOf(address(pay)), 1_000e6, "custody");
        assertEq(pay.balanceOf(contoso, ETH), 0, "no cross-asset credit");
    }

    function test_depositToken_revertsForUnsupportedToken() public {
        MockERC20 dai = new MockERC20("Dai", "DAI", 18);
        dai.mint(alice, 1_000e18);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.UnsupportedAsset.selector, address(dai)));
        pay.depositToken(_orderId("INV-2002"), contoso, address(dai), 100e18);
    }

    function test_depositToken_revertsForNativeSentinel() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.UnsupportedAsset.selector, ETH));
        pay.depositToken(_orderId("INV-2003"), contoso, ETH, 1 ether);
    }

    function test_depositToken_revertsWithoutAllowance() public {
        address carol = makeAddr("carol");
        usdc.mint(carol, 500e6);

        vm.prank(carol);
        vm.expectRevert(SafeTransferLib.TokenTransferFromFailed.selector);
        pay.depositToken(_orderId("INV-2004"), contoso, address(usdc), 500e6);
    }

    function test_depositToken_revertsAfterDelisting() public {
        vm.prank(admin);
        pay.setSupportedAsset(address(usdc), false);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOrkoPay.UnsupportedAsset.selector, address(usdc)));
        pay.depositToken(_orderId("INV-2005"), contoso, address(usdc), 100e6);
    }
}
