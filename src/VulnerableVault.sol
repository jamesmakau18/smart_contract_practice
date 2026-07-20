// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title VulnerableVault
/// @notice DELIBERATELY INSECURE — for educational purposes only.
///         This contract lets users deposit and withdraw ETH, but
///         contains a classic reentrancy bug in `withdraw()`.
///         Do not use any pattern from this file in real code.
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice THE BUG: this sends ETH to the caller BEFORE updating
    ///         their balance to zero. If the caller is a contract with
    ///         a `receive()` function, it can call back into `withdraw()`
    ///         again before the first call ever reaches the line that
    ///         sets `balances[msg.sender] = 0`.
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        // ── INTERACTION happens BEFORE effects — this is the bug ──
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // By the time execution reaches this line on the ORIGINAL call,
        // an attacker's fallback may have already called withdraw()
        // multiple times, each time seeing the same non-zero balance.
        balances[msg.sender] = 0;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
