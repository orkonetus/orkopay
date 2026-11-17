// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";

/// @title SafeTransferLib
/// @notice ETH and ERC-20 transfer helpers that revert on failure and tolerate
///         tokens that do not return a boolean.
/// @dev Adapted from solmate / OpenZeppelin SafeERC20 (MIT).
library SafeTransferLib {
    error ETHTransferFailed();
    error TokenTransferFailed();
    error TokenTransferFromFailed();

    function safeTransferETH(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert ETHTransferFailed();
    }

    function safeTransfer(address token, address to, uint256 amount) internal {
        bytes memory data = abi.encodeCall(IERC20.transfer, (to, amount));
        if (!_callOptionalReturn(token, data)) revert TokenTransferFailed();
    }

    function safeTransferFrom(address token, address from, address to, uint256 amount)
        internal
    {
        bytes memory data = abi.encodeCall(IERC20.transferFrom, (from, to, amount));
        if (!_callOptionalReturn(token, data)) revert TokenTransferFromFailed();
    }

    function _callOptionalReturn(address token, bytes memory data) private returns (bool) {
        if (token.code.length == 0) return false;
        (bool ok, bytes memory ret) = token.call(data);
        if (!ok) return false;
        return ret.length == 0 || abi.decode(ret, (bool));
    }
}
