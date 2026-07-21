// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CommitRevealGame
/// @notice The fix for GuessingGame.sol's front-running vulnerability: a
///         two-phase commit-reveal scheme. Players first submit a HASH of
///         their guess plus a secret salt (unreadable in the mempool),
///         and only later reveal the actual guess + salt, checked against
///         their earlier commitment. By the time the real answer is ever
///         visible on-chain, front-running it no longer helps an attacker.
contract CommitRevealGame {
    bytes32 public answerHash;
    address public winner;
    uint256 public prize;

    mapping(address => bytes32) public commitments;

    constructor(string memory _answer) payable {
        answerHash = keccak256(abi.encodePacked(_answer));
        prize = msg.value;
    }

    function commitGuess(bytes32 commitment) external {
        commitments[msg.sender] = commitment;
    }

    function revealGuess(string calldata _guess, bytes32 salt) external {
        require(winner == address(0), "Already won");
        require(
            commitments[msg.sender] == keccak256(abi.encodePacked(_guess, salt, msg.sender)),
            "Reveal does not match your earlier commitment"
        );

        if (keccak256(abi.encodePacked(_guess)) == answerHash) {
            winner = msg.sender;
            payable(msg.sender).transfer(prize);
        }
    }
}
