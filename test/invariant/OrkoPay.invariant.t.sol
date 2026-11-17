// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {OrkoPay} from "../../src/OrkoPay.sol";
import {IOrkoPay} from "../../src/interfaces/IOrkoPay.sol";

/// @notice Drives random sequences of ETH payments, withdrawals, refunds and
///         fee sweeps against OrkoPay.
contract OrkoPayHandler is Test {
    OrkoPay internal immutable pay;
    address internal immutable feeRecipient;

    address[2] internal merchants;
    address[3] internal customers;
    bytes32[] internal orderIds;
    uint256 internal nonce;

    constructor(OrkoPay pay_, address northwind, address contoso, address feeRecipient_) {
        pay = pay_;
        feeRecipient = feeRecipient_;
        merchants = [northwind, contoso];
        customers = [makeAddr("c0"), makeAddr("c1"), makeAddr("c2")];
    }

    function deposit(uint256 merchantSeed, uint256 customerSeed, uint256 amount) external {
        amount = bound(amount, 1, 50 ether);
        address merchant = merchants[merchantSeed % merchants.length];
        address customer = customers[customerSeed % customers.length];

        bytes32 id = keccak256(abi.encode("invariant-order", nonce++));
        vm.deal(customer, customer.balance + amount);
        vm.prank(customer);
        pay.deposit{value: amount}(id, merchant);
        orderIds.push(id);
    }

    function withdraw(uint256 merchantSeed, uint256 amount) external {
        address merchant = merchants[merchantSeed % merchants.length];
        uint256 bal = pay.balanceOf(merchant, address(0));
        if (bal == 0) return;

        amount = bound(amount, 1, bal);
        vm.prank(merchant);
        pay.withdraw(address(0), amount);
    }

    function refund(uint256 orderSeed) external {
        if (orderIds.length == 0) return;
        bytes32 id = orderIds[orderSeed % orderIds.length];

        IOrkoPay.Order memory o = pay.orderOf(id);
        if (o.status != IOrkoPay.OrderStatus.Paid) return;

        vm.prank(o.merchant);
        try pay.refund(id) {} catch {}
    }

    function collectFees() external {
        if (pay.accruedFees(address(0)) == 0) return;
        vm.prank(feeRecipient);
        pay.collectFees(address(0));
    }
}

contract OrkoPayInvariantTest is BaseTest {
    OrkoPayHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new OrkoPayHandler(pay, northwind, contoso, feeRecipient);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = OrkoPayHandler.deposit.selector;
        selectors[1] = OrkoPayHandler.withdraw.selector;
        selectors[2] = OrkoPayHandler.refund.selector;
        selectors[3] = OrkoPayHandler.collectFees.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @dev Every wei held is owed to a merchant or to the platform.
    function invariant_ethFullyBacked() public view {
        uint256 owed = pay.balanceOf(northwind, ETH) + pay.balanceOf(contoso, ETH)
            + pay.accruedFees(ETH);
        assertEq(address(pay).balance, owed);
    }
}
