// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {UncheckedCounter} from "../src/UncheckedCounter.sol";
import {CheckedCounter} from "../src/CheckedCounter.sol";

contract IntegerUnderflowTest is Test {
    UncheckedCounter public vulnerable;
    CheckedCounter public secure;

    address public user = address(0x1);

    function setUp() public {
        vulnerable = new UncheckedCounter();
        secure = new CheckedCounter();

        // Give the user a small, honest amount of points on each
        vulnerable.addPoints(user, 10);
        secure.addPoints(user, 10);
    }

    /// @notice Proves the exploit: spending MORE points than the user
    ///         actually has doesn't revert — it wraps around to a
    ///         near-maximum uint256 value, effectively giving the user
    ///         (almost) infinite fake points.
    function test_UnderflowWrapsToHugeNumber() public {
        assertEq(vulnerable.points(user), 10);

        vm.prank(user);
        vulnerable.spendPoints(11); // spending 1 MORE than they have

        // Instead of reverting, the balance wraps around to a massive number
        uint256 resultingBalance = vulnerable.points(user);
        console.log("Balance after underflow exploit:", resultingBalance);

        // This is type(uint256).max (i.e. 2^256 - 1), since 10 - 11 wraps around
        assertEq(resultingBalance, type(uint256).max);
        assertGt(resultingBalance, 10); // absurdly, "spending" points INCREASED their balance
    }

    /// @notice Proves the fix: the identical call reverts cleanly against
    ///         the checked version, because Solidity 0.8+'s default
    ///         overflow/underflow protection is active (no `unchecked`).
    function test_CheckedVersionRevertsOnUnderflow() public {
        assertEq(secure.points(user), 10);

        vm.prank(user);
        vm.expectRevert(); // Solidity's built-in panic: arithmetic underflow
        secure.spendPoints(11);

        // Balance is untouched, since the transaction reverted entirely
        assertEq(secure.points(user), 10);
    }
}
