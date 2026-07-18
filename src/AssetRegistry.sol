// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AssetRegistry - Day 1 practice contract
/// @notice A minimal registry mapping asset IDs to owners.
///         Deliberately simple: teaches state vars, mappings,
///         msg.sender, modifiers, and events in one file.
contract AssetRegistry {
    // The address that deployed the contract (the "admin")
    address public owner;

    // Maps an asset ID to the address that owns it
    mapping(uint256 => address) public assetOwner;

    // Tracks how many assets have been registered
    uint256 public totalAssets;

    // Emitted whenever a new asset is registered
    event AssetRegistered(uint256 indexed assetId, address indexed owner);

    // Emitted whenever an asset changes hands
    event AssetTransferred(uint256 indexed assetId, address indexed from, address indexed to);

    // Runs once, at deployment, and sets the deployer as owner
    constructor() {
        owner = msg.sender;
    }

    // A modifier is reusable "guard" logic you can attach to functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized: caller is not contract owner");
        _; // this underscore means "now run the rest of the function"
    }

    /// @notice Register a new asset ID to a given owner address.
    /// @dev Only the contract owner (admin) can register new assets.
    function registerAsset(uint256 assetId, address assetOwnerAddress) public onlyOwner {
        require(assetOwner[assetId] == address(0), "Asset ID already registered");
        assetOwner[assetId] = assetOwnerAddress;
        totalAssets += 1;

        emit AssetRegistered(assetId, assetOwnerAddress);
    }

    /// @notice Transfer an asset from the current owner to a new owner.
    /// @dev Only the CURRENT owner of that specific asset can transfer it.
    function transferAsset(uint256 assetId, address to) public {
        require(assetOwner[assetId] == msg.sender, "You do not own this asset");
        require(to != address(0), "Cannot transfer to zero address");

        address previousOwner = assetOwner[assetId];
        assetOwner[assetId] = to;

        emit AssetTransferred(assetId, previousOwner, to);
    }

    /// @notice Check who owns a given asset ID.
    function getOwnerOf(uint256 assetId) public view returns (address) {
        return assetOwner[assetId];
    }
}
