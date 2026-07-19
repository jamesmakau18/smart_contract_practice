// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title RWAShareToken
/// @notice Represents fractional ownership shares in a real-world asset
///         (e.g. a property, a fund, a piece of equipment). Built on
///         OpenZeppelin's audited ERC20 rather than hand-rolled, since this
///         is what a production RWA platform would actually do.
///
/// @dev Key RWA-specific additions on top of vanilla ERC20:
///      1. Compliance whitelist — only KYC'd/approved addresses can hold
///         or receive shares (a legal requirement for most real asset
///         tokenization, unlike a permissionless meme token).
///      2. Pausable — lets the asset issuer freeze all transfers in an
///         emergency (e.g. a legal dispute, a detected exploit, a
///         regulatory order) without needing to redeploy anything.
///      3. Role-gated minting — only the owner (the asset issuer/platform)
///         can mint new shares, representing new fractional ownership
///         being issued against the underlying asset.
contract RWAShareToken is ERC20, Ownable, Pausable {
    // ── Compliance ─────────────────────────────────────────

    // Addresses that have passed KYC/compliance checks and may hold shares.
    mapping(address => bool) public isWhitelisted;

    event AddressWhitelisted(address indexed account);
    event AddressRemovedFromWhitelist(address indexed account);

    error NotWhitelisted(address account);

    // ── Constructor ────────────────────────────────────────

    constructor(string memory name_, string memory symbol_, address initialOwner)
        ERC20(name_, symbol_)
        Ownable(initialOwner)
    {
        // The issuer/platform is automatically whitelisted so it can
        // receive the initial minted supply and distribute it.
        isWhitelisted[initialOwner] = true;
        emit AddressWhitelisted(initialOwner);
    }

    // ── Compliance management (owner-only) ──────────────────

    /// @notice Approve an address to hold/receive shares (e.g. after KYC).
    function addToWhitelist(address account) external onlyOwner {
        isWhitelisted[account] = true;
        emit AddressWhitelisted(account);
    }

    /// @notice Revoke an address's ability to hold/receive shares.
    /// @dev Does NOT burn or seize existing balance — it only blocks
    ///      further transfers TO or FROM this address going forward.
    ///      Real platforms usually pair this with a legal/off-chain process.
    function removeFromWhitelist(address account) external onlyOwner {
        isWhitelisted[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    // ── Issuance ─────────────────────────────────────────────

    /// @notice Mint new fractional shares to a whitelisted holder.
    /// @dev Represents the issuer bringing new ownership shares on-chain
    ///      against the underlying real-world asset.
    function mint(address to, uint256 amount) external onlyOwner {
        if (!isWhitelisted[to]) revert NotWhitelisted(to);
        _mint(to, amount);
    }

    // ── Emergency controls ───────────────────────────────────

    /// @notice Freeze all transfers platform-wide. Emergency use only.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume normal transfers.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ── Core override: enforce compliance + pause on every transfer ──

    /// @dev OpenZeppelin v5 routes ALL balance changes (transfer, mint,
    ///      burn, transferFrom) through this single internal function,
    ///      so overriding it here is the correct, comprehensive place
    ///      to enforce both the whitelist and the pause switch — rather
    ///      than duplicating checks across transfer/transferFrom separately.
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        // `from == address(0)` means this is a mint — the recipient still
        // must be whitelisted, but there's no sender to check.
        if (from != address(0) && !isWhitelisted[from]) revert NotWhitelisted(from);

        // `to == address(0)` means this is a burn — no recipient to check.
        if (to != address(0) && !isWhitelisted[to]) revert NotWhitelisted(to);

        super._update(from, to, value);
    }
}
