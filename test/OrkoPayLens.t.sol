// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseTest} from "./utils/BaseTest.sol";
import {OrkoPayLens} from "../src/periphery/OrkoPayLens.sol";
import {IOrkoPay} from "../src/interfaces/IOrkoPay.sol";

contract OrkoPayLensTest is BaseTest {
    OrkoPayLens internal lens;

    function setUp() public override {
        super.setUp();
        lens = new OrkoPayLens();
    }

    function test_summaries() public {
        _payEth(alice, "INV-6001", northwind, 1 ether);
        _payUsdc(bob, "INV-6002", northwind, 300e6);

        address[] memory merchants = new address[](2);
        merchants[0] = northwind;
        merchants[1] = contoso;

        address[] memory assets = new address[](2);
        assets[0] = ETH;
        assets[1] = address(usdc);

        OrkoPayLens.MerchantSummary[] memory s =
            lens.summaries(IOrkoPay(address(pay)), registry, merchants, assets);

        assertEq(s.length, 2);
        assertEq(s[0].info.name, "Northwind Store");
        assertEq(s[0].balances[0], pay.balanceOf(northwind, ETH));
        assertEq(s[0].balances[1], pay.balanceOf(northwind, address(usdc)));
        assertEq(s[1].balances[0], 0);
    }

    function test_ordersOf() public {
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = _payEth(alice, "INV-6003", contoso, 1 ether);
        ids[1] = _orderId("INV-unknown");

        IOrkoPay.Order[] memory orders = lens.ordersOf(IOrkoPay(address(pay)), ids);

        assertEq(orders[0].customer, alice);
        assertEq(uint8(orders[1].status), uint8(IOrkoPay.OrderStatus.None));
    }
}
