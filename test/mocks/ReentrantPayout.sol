// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IOrkoPay} from "../../src/interfaces/IOrkoPay.sol";

/// @notice Payout address that tries to re-enter OrkoPay when paid.
contract ReentrantPayout {
    IOrkoPay internal immutable pay;

    constructor(IOrkoPay pay_) {
        pay = pay_;
    }

    receive() external payable {
        pay.withdraw(address(0), msg.value);
    }
}
