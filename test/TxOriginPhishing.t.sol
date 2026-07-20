// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TxOriginWallet, PhishingAttacker} from "../src/TxOriginWallet.sol";

/// @title SecureWallet
/// @notice The fix: checks msg.sender (whoever called THIS function
///         directly) instead of tx.origin (whoever started the whole
///         transaction chain, however many hops away).
contract SecureWallet {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function withdrawAll(address to) external {
        require(msg.sender == owner, "Not authorized");
        payable(to).transfer(address(this).balance);
    }

    receive() external payable {}
}

/// @title SecurePhishingAttacker
/// @notice The IDENTICAL phishing trick, structurally, but aimed at
///         SecureWallet instead of TxOriginWallet — used to prove the
///         msg.sender-based check actually blocks it.
contract SecurePhishingAttacker {
    SecureWallet public target;
    address public attackerAddress;

    constructor(address payable _target) {
        target = SecureWallet(_target);
        attackerAddress = msg.sender;
    }

    function claimReward() external {
        target.withdrawAll(attackerAddress);
    }
}

contract TxOriginPhishingTest is Test {
    TxOriginWallet public vulnerableWallet;
    SecureWallet public secureWallet;
    PhishingAttacker public attacker;
    SecurePhishingAttacker public secureAttacker;

    address public victimOwner = address(0x1);
    address public attackerAddress = address(0x2);

    function setUp() public {
        // Owner deploys the VULNERABLE wallet and funds it
        vm.prank(victimOwner);
        vulnerableWallet = new TxOriginWallet();
        vm.deal(address(vulnerableWallet), 5 ether);

        // Owner deploys the SECURE wallet and funds it
        vm.prank(victimOwner);
        secureWallet = new SecureWallet();
        vm.deal(address(secureWallet), 5 ether);

        // Attacker deploys malicious "claim reward" contracts targeting each
        vm.startPrank(attackerAddress);
        attacker = new PhishingAttacker(payable(address(vulnerableWallet)));
        secureAttacker = new SecurePhishingAttacker(payable(address(secureWallet)));
        vm.stopPrank();
    }

    /// @notice Proves the exploit: the OWNER calls what looks like a
    ///         harmless function, but it secretly drains their own wallet
    ///         to the attacker — because tx.origin still equals the owner,
    ///         even though the owner never called the wallet directly.
    function test_TxOriginPhishingDrainsWallet() public {
        assertEq(address(vulnerableWallet).balance, 5 ether);

        // The VICTIM initiates this call, thinking they're claiming a reward.
        // We use the two-argument prank(sender, origin) here deliberately:
        // this exploit's entire premise is that tx.origin reflects the
        // REAL transaction initiator across every hop, so we need Foundry
        // to actually simulate that, not just override msg.sender for
        // this one call.
        vm.prank(victimOwner, victimOwner);
        attacker.claimReward();

        // Wallet is drained, attacker got everything
        assertEq(address(vulnerableWallet).balance, 0);
        assertEq(attackerAddress.balance, 5 ether);
    }

    /// @notice Proves the fix: the IDENTICAL phishing trick fails against
    ///         SecureWallet. When SecurePhishingAttacker calls
    ///         target.withdrawAll(...), msg.sender inside that function is
    ///         the SecurePhishingAttacker CONTRACT's address — not the
    ///         victim's — so the require() correctly rejects it, no matter
    ///         who originally kicked off the transaction.
    function test_SameTrickFailsAgainstMsgSenderCheck() public {
        assertEq(address(secureWallet).balance, 5 ether);

        vm.prank(victimOwner);
        vm.expectRevert("Not authorized");
        secureAttacker.claimReward();

        // Balance untouched — the attack never got anywhere
        assertEq(address(secureWallet).balance, 5 ether);
        assertEq(attackerAddress.balance, 0);
    }
}
