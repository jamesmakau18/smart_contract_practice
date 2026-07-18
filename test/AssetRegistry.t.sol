// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";

/// @notice This test suite does programmatically what you were doing
///         by hand in Remix: register an asset, transfer it, check
///         unauthorized calls revert. Run with `forge test -vvv`.
contract AssetRegistryTest is Test {
    AssetRegistry public registry;

    // Fake addresses Foundry gives us for testing — no real ETH needed
    address public deployer = address(this); // the test contract deploys, so it's the "owner"
    address public alice = address(0x1);
    address public bob = address(0x2);

    // This runs before EVERY test function below — fresh contract each time
    function setUp() public {
        registry = new AssetRegistry();
    }

    /// @notice The deployer should automatically become the owner
    function test_DeployerIsOwner() public view {
        assertEq(registry.owner(), deployer);
    }

    /// @notice Owner should be able to register a new asset to Alice
    function test_OwnerCanRegisterAsset() public {
        registry.registerAsset(1, alice);
        assertEq(registry.getOwnerOf(1), alice);
        assertEq(registry.totalAssets(), 1);
    }

    /// @notice A non-owner trying to register an asset should revert
    function test_NonOwnerCannotRegisterAsset() public {
        // vm.prank makes the NEXT call appear to come from `alice`, not the test contract
        vm.prank(alice);

        // We expect this call to revert with our custom error message
        vm.expectRevert("Not authorized: caller is not contract owner");
        registry.registerAsset(1, alice);
    }

    /// @notice The current owner of an asset should be able to transfer it
    function test_OwnerCanTransferAsset() public {
        registry.registerAsset(1, alice);

        // Now pretend Alice is calling — she owns asset 1, so she can transfer it
        vm.prank(alice);
        registry.transferAsset(1, bob);

        assertEq(registry.getOwnerOf(1), bob);
    }

    /// @notice Someone who does NOT own the asset should not be able to transfer it
    function test_NonOwnerCannotTransferAsset() public {
        registry.registerAsset(1, alice);

        // Bob does not own asset 1, so this should revert
        vm.prank(bob);
        vm.expectRevert("You do not own this asset");
        registry.transferAsset(1, bob);
    }

    /// @notice Cannot register the same asset ID twice
    function test_CannotRegisterDuplicateAsset() public {
        registry.registerAsset(1, alice);

        vm.expectRevert("Asset ID already registered");
        registry.registerAsset(1, bob);
    }

    /// @notice Cannot transfer an asset to the zero address
    function test_CannotTransferToZeroAddress() public {
        registry.registerAsset(1, alice);

        vm.prank(alice);
        vm.expectRevert("Cannot transfer to zero address");
        registry.transferAsset(1, address(0));
    }
}
