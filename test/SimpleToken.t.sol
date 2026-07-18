// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SimpleToken} from "../src/SimpleToken.sol";

contract SimpleTokenTest is Test {
    SimpleToken public token;

    address public deployer = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public feeCollector = address(0x3);

    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        token = new SimpleToken("Practice Token", "PRAC", INITIAL_SUPPLY);
    }

    // ── Basic setup checks ──────────────────────────────────

    function test_InitialSupplyMintedToDeployer() public view {
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    // ── Transfer tests ──────────────────────────────────────

    function test_TransferMovesBalance() public {
        bool success = token.transfer(alice, 100);
        assertTrue(success);

        assertEq(token.balanceOf(alice), 100);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - 100);
    }

    function test_TransferRevertsOnInsufficientBalance() public {
        vm.prank(alice); // alice has 0 tokens
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleToken.InsufficientBalance.selector,
                0,
                100
            )
        );
        bool success = token.transfer(bob, 100);
        success;
    }

    function test_TransferRevertsToZeroAddress() public {
        vm.expectRevert(SimpleToken.ZeroAddress.selector);
        bool success = token.transfer(address(0), 100);
        success;
    }

    // ── Allowance / transferFrom tests ──────────────────────

    function test_ApproveSetsAllowance() public {
        token.approve(alice, 500);
        assertEq(token.allowance(deployer, alice), 500);
    }

    function test_TransferFromWithAllowance() public {
        // deployer approves alice to spend 500 on their behalf
        token.approve(alice, 500);

        // alice now moves 200 of deployer's tokens to bob
        vm.prank(alice);
        bool success = token.transferFrom(deployer, bob, 200);
        assertTrue(success);

        assertEq(token.balanceOf(bob), 200);
        // remaining allowance should be reduced
        assertEq(token.allowance(deployer, alice), 300);
    }

    function test_TransferFromRevertsWithoutEnoughAllowance() public {
        token.approve(alice, 50);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleToken.InsufficientAllowance.selector,
                50,
                200
            )
        );
        bool success = token.transferFrom(deployer, bob, 200);
        success;
    }

    // ── Minting tests ───────────────────────────────────────

    function test_OwnerCanMint() public {
        token.mint(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 1000);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(SimpleToken.NotOwner.selector);
        token.mint(alice, 1000);
    }

    // ── Pure/view function tests ─────────────────────────────

    function test_CalculateFeeIsPureMath() public view {
        // 250 basis points = 2.5%
        uint256 fee = token.calculateFee(1000, 250);
        assertEq(fee, 25);
    }

    function test_IsRichReflectsBalance() public view {
        assertTrue(token.isRich(deployer)); // deployer has the full supply
        assertFalse(token.isRich(alice)); // alice has 0
    }

    function test_TransferWithFeeSplitsCorrectly() public {
        // send 1000 tokens to alice, with a 10% fee (1000 basis points) to feeCollector
        token.transferWithFee(alice, 1000, feeCollector, 1000);

        assertEq(token.balanceOf(feeCollector), 100); // 10% fee
        assertEq(token.balanceOf(alice), 900); // remainder
    }
}
