// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RWAShareToken} from "../src/RWAShareToken.sol";

contract RWAShareTokenTest is Test {
    RWAShareToken public token;

    address public issuer = address(this);
    address public alice = address(0x1); // will be whitelisted
    address public bob = address(0x2); // will NOT be whitelisted

    function setUp() public {
        token = new RWAShareToken("Nairobi Office Tower Shares", "NOTS", issuer);
        token.addToWhitelist(alice);
        // bob deliberately left off the whitelist
    }

    // ── Whitelist enforcement ────────────────────────────────

    function test_IssuerIsWhitelistedAtDeploy() public view {
        assertTrue(token.isWhitelisted(issuer));
    }

    function test_OwnerCanWhitelistNewAddress() public view {
        assertTrue(token.isWhitelisted(alice));
    }

    function test_MintToNonWhitelistedAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(RWAShareToken.NotWhitelisted.selector, bob));
        token.mint(bob, 100);
    }

    function test_MintToWhitelistedAddressSucceeds() public {
        token.mint(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
    }

    function test_TransferToNonWhitelistedAddressReverts() public {
        token.mint(alice, 1000);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAShareToken.NotWhitelisted.selector, bob));
        bool success = token.transfer(bob, 100);
        success;
    }

    function test_TransferBetweenWhitelistedAddressesSucceeds() public {
        token.addToWhitelist(bob); // now whitelist bob too
        token.mint(alice, 1000);

        vm.prank(alice);
        bool success = token.transfer(bob, 300);
        assertTrue(success);

        assertEq(token.balanceOf(bob), 300);
        assertEq(token.balanceOf(alice), 700);
    }

    function test_RemovingFromWhitelistBlocksFutureTransfers() public {
        token.mint(alice, 1000);
        token.removeFromWhitelist(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAShareToken.NotWhitelisted.selector, alice));
        bool success = token.transfer(issuer, 100);
        success;
    }

    // ── Access control ───────────────────────────────────────

    function test_NonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(); // OpenZeppelin's Ownable reverts with its own custom error
        token.mint(alice, 1000);
    }

    function test_NonOwnerCannotWhitelist() public {
        vm.prank(alice);
        vm.expectRevert();
        token.addToWhitelist(bob);
    }

    // ── Pausability ───────────────────────────────────────────

    function test_OwnerCanPauseAndBlocksTransfers() public {
        token.mint(alice, 1000);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(); // Pausable's own custom error
        bool success = token.transfer(issuer, 100);
        success;
    }

    function test_OwnerCanUnpauseAndRestoreTransfers() public {
        token.mint(alice, 1000);
        token.pause();
        token.unpause();

        vm.prank(alice);
        bool success = token.transfer(issuer, 100); // should succeed now
        assertTrue(success);
        assertEq(token.balanceOf(issuer), 100);
    }

    function test_NonOwnerCannotPause() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
    }
}
