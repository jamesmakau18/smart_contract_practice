// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SecureWallet
/// @notice The fix for TxOriginWallet.sol's phishing vulnerability: checks
///         msg.sender (whoever called THIS function directly) instead of
///         tx.origin (whoever started the whole transaction chain, however
///         many hops away).
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
