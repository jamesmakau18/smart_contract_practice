// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SecureVault} from "../src/SecureVault.sol";

/// @notice Same attacker shape as before, but pointed at SecureVault
///         instead of VulnerableVault, to prove the fix actually works.
contract SecureVaultAttacker {
    SecureVault public immutable target;

    constructor(address _target) {
        target = SecureVault(_target);
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw();
    }

    receive() external payable {
        if (address(target).balance >= 1 ether) {
            target.withdraw(); // this attempt should now FAIL
        }
    }
}

contract SecureVaultTest is Test {
    SecureVault public vault;
    SecureVaultAttacker public attacker;

    address public alice = address(0x1);
    address public eve = address(0x2);

    function setUp() public {
        vault = new SecureVault();

        vm.deal(alice, 5 ether);
        vm.deal(eve, 1 ether);

        vm.prank(alice);
        vault.deposit{value: 5 ether}();

        vm.prank(eve);
        attacker = new SecureVaultAttacker(address(vault));
    }

    /// @notice Proves the SAME attack pattern that drained VulnerableVault
    ///         now fails against SecureVault — Alice's funds stay safe,
    ///         and Eve can only ever withdraw what she actually deposited.
    function test_ReentrancyAttackFailsAgainstSecureVault() public {
        assertEq(vault.getBalance(), 5 ether);

        vm.prank(eve);
        // The re-entrant call inside receive() reverts (nonReentrant lock),
        // but Solidity's low-level .call() swallows that revert and just
        // returns success=false — which our own require() then catches.
        vm.expectRevert("Transfer failed");
        attacker.attack{value: 1 ether}();
    }
}
