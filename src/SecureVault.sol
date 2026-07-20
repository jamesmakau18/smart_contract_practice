// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SecureVault
/// @notice A fixed version of VulnerableVault, using TWO independent
///         defenses against reentrancy — either one alone would have
///         stopped the attack, but production code typically uses both
///         as defense-in-depth.
contract SecureVault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice FIX 1 — Checks-Effects-Interactions: the balance is zeroed
    ///         out BEFORE the ETH is sent, not after. So even if the
    ///         recipient's receive() tries to call withdraw() again,
    ///         the vault now sees a balance of 0 and reverts immediately.
    ///
    ///         FIX 2 — `nonReentrant` modifier (from OpenZeppelin): sets
    ///         a lock at the start of the function and releases it at
    ///         the end. Any attempt to re-enter this function while the
    ///         lock is held reverts instantly, regardless of ordering.
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        // ── EFFECT happens BEFORE interaction — the actual fix ──
        balances[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
