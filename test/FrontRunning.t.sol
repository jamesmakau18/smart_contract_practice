// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GuessingGame, FrontRunnerBot} from "../src/GuessingGame.sol";

/// @title CommitRevealGame
/// @notice The fix: a two-phase "commit-reveal" scheme. Players first
///         submit a HASH of their guess plus a secret salt (so nobody can
///         see the actual answer in the mempool). Only in a LATER phase
///         do they reveal the actual guess + salt, which is checked
///         against their earlier commitment. By the time anyone can see
///         the real answer, it's already too late to front-run it —
///         the commitment was already locked in beforehand.
contract CommitRevealGame {
    bytes32 public answerHash;
    address public winner;
    uint256 public prize;

    mapping(address => bytes32) public commitments;

    constructor(string memory _answer) payable {
        answerHash = keccak256(abi.encodePacked(_answer));
        prize = msg.value;
    }

    /// @notice Phase 1: submit a hash of (guess + secret salt). Nobody
    ///         watching the mempool can reverse this back into the
    ///         plaintext guess.
    function commitGuess(bytes32 commitment) external {
        commitments[msg.sender] = commitment;
    }

    /// @notice Phase 2: reveal the actual guess and salt. This is checked
    ///         against the commitment from phase 1 — if someone tried to
    ///         front-run by copying a REVEAL transaction, they'd need to
    ///         have already committed the correct hash beforehand, which
    ///         requires knowing the answer in advance anyway.
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

contract FrontRunningTest is Test {
    GuessingGame public vulnerableGame;
    CommitRevealGame public secureGame;
    FrontRunnerBot public bot;

    address public honestPlayer = address(0x1001);
    address public frontRunner = address(0x1002);

    string constant SECRET_ANSWER = "blockchain";

    function setUp() public {
        vulnerableGame = new GuessingGame{value: 1 ether}(SECRET_ANSWER);
        secureGame = new CommitRevealGame{value: 1 ether}(SECRET_ANSWER);
        bot = new FrontRunnerBot(address(vulnerableGame));

        vm.deal(honestPlayer, 1 ether);
        vm.deal(frontRunner, 1 ether);
    }

    /// @notice Proves the exploit: the honest player's correct guess gets
    ///         "seen" (simulated) and resubmitted by the front-runner
    ///         FIRST, stealing the prize despite the honest player having
    ///         figured out the right answer.
    function test_FrontRunnerStealsPrize() public {
        // In reality, the bot would spot the honest player's PENDING
        // transaction in the mempool and copy it with higher gas. We
        // simulate that outcome directly: the bot's copy lands first.
        bot.frontRun(SECRET_ANSWER);

        assertEq(vulnerableGame.winner(), address(bot));
        assertEq(address(bot).balance, 1 ether);

        // The honest player's identical guess now reverts — the game
        // already has a winner, so require(winner == address(0), ...)
        // correctly blocks any further guesses, honest or not.
        vm.prank(honestPlayer);
        vm.expectRevert("Already won");
        vulnerableGame.guess(SECRET_ANSWER);
        assertEq(vulnerableGame.winner(), address(bot)); // unchanged
    }

    /// @notice Proves the fix: the honest player commits a hash first
    ///         (revealing nothing), and only reveals the real answer
    ///         later. Even if an attacker sees the REVEAL transaction in
    ///         the mempool and tries to copy it, they can't have a valid
    ///         PRIOR commitment matching it, so their reveal fails.
    function test_CommitRevealPreventsFrontRunning() public {
        bytes32 salt = keccak256(abi.encodePacked("honest-player-secret-salt"));
        bytes32 commitment = keccak256(abi.encodePacked(SECRET_ANSWER, salt, honestPlayer));

        // Phase 1: honest player commits privately (just a hash, unreadable)
        vm.prank(honestPlayer);
        secureGame.commitGuess(commitment);

        // An attacker watching the mempool sees ONLY the hash — cannot
        // reverse it back into "blockchain" + the salt. They have no
        // valid commitment of their own to reveal against.
        vm.prank(frontRunner);
        vm.expectRevert("Reveal does not match your earlier commitment");
        secureGame.revealGuess(SECRET_ANSWER, salt); // stolen answer, but wrong committer

        // Phase 2: the honest player reveals safely and wins
        vm.prank(honestPlayer);
        secureGame.revealGuess(SECRET_ANSWER, salt);

        assertEq(secureGame.winner(), honestPlayer);
        assertEq(honestPlayer.balance, 2 ether); // 1 ether starting + 1 ether prize
    }
}
