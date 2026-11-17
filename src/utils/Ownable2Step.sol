// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "./Ownable.sol";

/// @title Ownable2Step
/// @notice Ownership transfers must be accepted by the new owner, so a typo
///         in the destination address cannot brick admin control.
/// @dev Adapted from OpenZeppelin Contracts v5 (MIT).
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    error NotPendingOwner();

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @notice Address that may call `acceptOwnership`, if any.
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /// @notice Starts a transfer to `newOwner`. Passing address(0) cancels a
    ///         pending transfer.
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /// @notice Completes a pending ownership transfer.
    function acceptOwnership() public virtual {
        if (msg.sender != _pendingOwner) revert NotPendingOwner();
        _transferOwnership(msg.sender);
    }

    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }
}
