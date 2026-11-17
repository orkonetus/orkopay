// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title ReentrancyGuard
/// @notice Standard non-reentrant lock.
/// @dev Adapted from OpenZeppelin Contracts v5 (MIT). Apply `nonReentrant` to
///      every function that moves value.
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    error Reentrancy();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}
