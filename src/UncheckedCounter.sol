// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title UncheckedCounter
/// @notice DELIBERATELY INSECURE — for educational purposes only.
///
/// @dev Context: Solidity 0.8+ reverts automatically on overflow/underflow
///      BY DEFAULT — this is genuinely one of the biggest safety upgrades
///      in the language's history (pre-0.8, this exact bug was rampant and
///      caused real exploits). BUT developers can opt back OUT of that
///      protection using an `unchecked { }` block, usually to save gas in
///      a spot they're SURE can't overflow. This contract shows what
///      happens when that assumption is wrong.
contract UncheckedCounter {
    mapping(address => uint256) public points;

    function addPoints(address user, uint256 amount) external {
        points[user] += amount;
    }

    /// @notice THE BUG: spends points inside an `unchecked` block,
    ///         assuming the caller always has enough. If `amount` exceeds
    ///         the user's balance, `points[user] - amount` UNDERFLOWS —
    ///         wrapping around to a near-maximum uint256 value instead of
    ///         reverting, silently giving the user a massive fake balance.
    function spendPoints(uint256 amount) external {
        unchecked {
            points[msg.sender] -= amount;
        }
    }
}
