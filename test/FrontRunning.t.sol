// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GuessingGame, FrontRunnerBot} from "../src/GuessingGame.sol";
import {CommitRevealGame} from "../src/CommitRevealGame.sol";

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
