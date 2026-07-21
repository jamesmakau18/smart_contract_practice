// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CheckedCounter
/// @notice The fix for UncheckedCounter.sol's underflow vulnerability:
///         simply removing the `unchecked` block. Solidity 0.8+'s default
///         overflow/underflow protection then reverts automatically if a
///         subtraction would go below zero — no extra code needed.
contract CheckedCounter {
    mapping(address => uint256) public points;

    function addPoints(address user, uint256 amount) external {
        points[user] += amount;
    }

    function spendPoints(uint256 amount) external {
        points[msg.sender] -= amount;
    }
}
