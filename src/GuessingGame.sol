// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title GuessingGame
/// @notice DELIBERATELY INSECURE — for educational purposes only.
///
/// @dev Context: front-running isn't a bug in the traditional sense —
///      there's no revert, no wrong math. The vulnerability is that ALL
///      pending Ethereum transactions sit visibly in the public "mempool"
///      before being confirmed. Anyone (especially bots) can see YOUR
///      transaction's exact contents, including function arguments, and
///      submit their OWN transaction with a higher gas fee to get mined
///      FIRST — effectively copying your answer and beating you to it.
///      This is a huge deal in real DeFi (sandwich attacks, MEV).
contract GuessingGame {
    bytes32 public answerHash;
    address public winner;
    uint256 public prize;

    constructor(string memory _answer) payable {
        answerHash = keccak256(abi.encodePacked(_answer));
        prize = msg.value;
    }

    /// @notice THE BUG: the guess is submitted in PLAINTEXT. The moment
    ///         you broadcast this transaction, it's visible in the
    ///         mempool to everyone — including bots watching for exactly
    ///         this kind of call — before it's ever mined.
    function guess(string calldata _guess) external {
        require(winner == address(0), "Already won");

        if (keccak256(abi.encodePacked(_guess)) == answerHash) {
            winner = msg.sender;
            payable(msg.sender).transfer(prize);
        }
    }
}

/// @title FrontRunnerBot
/// @notice Watches the mempool (simulated here — in reality this would be
///         off-chain infrastructure watching pending transactions) and,
///         upon seeing a correct guess about to be submitted, resubmits
///         the SAME guess with higher gas to get mined first and steal
///         the prize instead.
contract FrontRunnerBot {
    GuessingGame public target;

    constructor(address _target) {
        target = GuessingGame(_target);
    }

    /// @notice In real life this would be triggered by mempool-watching
    ///         infrastructure, not called directly like this. Here we
    ///         simulate "the bot saw the plaintext answer and copied it."
    function frontRun(string calldata stolenGuess) external {
        target.guess(stolenGuess);
    }

    /// @notice Required for this contract to receive the prize ETH at all —
    ///         without this, GuessingGame's payable(msg.sender).transfer(...)
    ///         would revert on arrival, since a contract with no receive()
    ///         or fallback() simply cannot accept plain ETH transfers.
    receive() external payable {}
}
