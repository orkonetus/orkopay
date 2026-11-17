// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrkoPay} from "../../src/OrkoPay.sol";
import {OrkoPayRegistry} from "../../src/OrkoPayRegistry.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice Shared fixture: registry with two merchants, OrkoPay accepting ETH
///         and a 6-decimal USDC mock, two funded customers.
abstract contract BaseTest is Test {
    OrkoPay internal pay;
    OrkoPayRegistry internal registry;
    MockERC20 internal usdc;

    address internal constant ETH = address(0);

    uint16 internal constant BASE_FEE_BPS = 250; // 2.5%
    uint32 internal constant REFUND_WINDOW = 14 days;

    address internal admin = makeAddr("admin"); // ops multisig
    address internal ops = makeAddr("ops"); // onboarding service
    address internal feeRecipient = makeAddr("feeRecipient");

    // Northwind: 0.5% tier discount -> 2.0% effective fee
    address internal northwind = makeAddr("northwind");
    address internal northwindPayout = makeAddr("northwindPayout");

    // Contoso: standard rate -> 2.5% effective fee
    address internal contoso = makeAddr("contoso");
    address internal contosoPayout = makeAddr("contosoPayout");

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public virtual {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        registry = new OrkoPayRegistry(admin);

        vm.prank(admin);
        registry.setOperator(ops, true);

        vm.startPrank(ops);
        registry.register(northwind, northwindPayout, 50, "Northwind Store");
        registry.register(contoso, contosoPayout, 0, "Contoso Tickets");
        vm.stopPrank();

        pay = new OrkoPay(admin, registry, feeRecipient, BASE_FEE_BPS, REFUND_WINDOW);

        vm.prank(admin);
        pay.setSupportedAsset(address(usdc), true);

        _fund(alice);
        _fund(bob);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _fund(address who) internal {
        vm.deal(who, 100 ether);
        usdc.mint(who, 1_000_000e6);
        vm.prank(who);
        usdc.approve(address(pay), type(uint256).max);
    }

    function _orderId(string memory invoice) internal pure returns (bytes32) {
        return keccak256(bytes(invoice));
    }

    function _payEth(address customer, string memory invoice, address merchant, uint256 amount)
        internal
        returns (bytes32 id)
    {
        id = _orderId(invoice);
        vm.prank(customer);
        pay.deposit{value: amount}(id, merchant);
    }

    function _payUsdc(address customer, string memory invoice, address merchant, uint256 amount)
        internal
        returns (bytes32 id)
    {
        id = _orderId(invoice);
        vm.prank(customer);
        pay.depositToken(id, merchant, address(usdc), amount);
    }

    function _fee(uint256 gross, uint256 bps) internal pure returns (uint256) {
        return (gross * bps) / 10_000;
    }
}
