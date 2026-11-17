// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Pausable
/// @notice Emergency stop mechanism controlled by the inheriting contract.
/// @dev Adapted from OpenZeppelin Contracts v5 (MIT).
abstract contract Pausable {
    bool private _paused;

    error EnforcedPause();
    error ExpectedPause();

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert ExpectedPause();
        _;
    }

    /// @notice Whether the contract is paused.
    function paused() public view returns (bool) {
        return _paused;
    }

    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}
