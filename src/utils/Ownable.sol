// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Ownable
/// @notice Single-owner access control.
/// @dev Adapted from OpenZeppelin Contracts v5 (MIT). Kept in-tree so the
///      audited surface does not move with dependency upgrades.
abstract contract Ownable {
    address private _owner;

    error NotOwner();
    error ZeroAddress();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /// @notice Current owner.
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @notice Transfers ownership to `newOwner`.
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _transferOwnership(newOwner);
    }

    function _checkOwner() internal view virtual {
        if (msg.sender != owner()) revert NotOwner();
    }

    function _transferOwnership(address newOwner) internal virtual {
        address previous = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}
