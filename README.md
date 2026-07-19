# Smart Contract Practice — Asset Registry & Token System

A set of Solidity contracts built and tested with [Foundry](https://book.getfoundry.sh/), focused on the core primitives behind real-world asset (RWA) tokenization: ownership tracking, access control, transfers, and allowances.

Built as hands-on practice ahead of a Senior Blockchain Engineer role involving Ethereum-based tokenized asset marketplaces.

## Contracts

### `AssetRegistry.sol`
A minimal on-chain registry mapping asset IDs to owner addresses — the core primitive behind representing real-world assets on-chain.

- Admin-gated asset registration (`onlyOwner` modifier)
- Owner-gated asset transfers (only the current owner of a specific asset can transfer it)
- Full event coverage (`AssetRegistered`, `AssetTransferred`) for off-chain indexing
- Guards against duplicate registration and zero-address transfers

### `SimpleToken.sol`
A hand-built, ERC-20-style token implementation (not inheriting OpenZeppelin, to demonstrate first-principles understanding of the standard).

- Balances, transfers, and the `approve` / `transferFrom` allowance pattern
- Gas-efficient custom errors (`InsufficientBalance`, `InsufficientAllowance`, `NotOwner`, `ZeroAddress`) instead of string-based `require()`
- Owner-gated minting
- Demonstrates `view` vs `pure` function semantics (`isRich`, `calculateFee`)
- `transferWithFee` — a composed function showing safe internal-call patterns (checks return values, follows Checks-Effects-Interactions ordering)

## Test Coverage

Both contracts have full Foundry test suites covering the happy path, access control failures, and edge cases (duplicate registration, zero-address transfers, insufficient allowance/balance).

```shell
forge test -vvv
```

19 tests passing across both contracts.

## Live Deployments — Sepolia Testnet

| Contract | Address | Etherscan |
|---|---|---|
| AssetRegistry | `0xe70F53Ba0B894065940567F4F3e96d0b8B1D334c` | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xe70F53Ba0B894065940567F4F3e96d0b8B1D334c) |
| SimpleToken | `0x4A04bC8d1d91B7b6C49e3bcfaA6A816727D62243` | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0x4A04bC8d1d91B7b6C49e3bcfaA6A816727D62243) |

## Tech Stack

- **Solidity** `^0.8.24` (compiled with `0.8.35`)
- **Foundry** (Forge for testing/deployment, `forge-std` for cheatcodes/assertions)
- **Sepolia** testnet, deployed via Alchemy RPC

## Local Setup

### Build
```shell
forge build
```

### Test
```shell
forge test -vvv
```

### Deploy (Sepolia)
Requires a `.env` file (not committed — see `.gitignore`) with:
```
SEPOLIA_RPC_URL=your_alchemy_or_infura_sepolia_url
PRIVATE_KEY=0xyour_test_wallet_private_key
```

Then:
```shell
source .env
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## Author

**James Makau**
Senior Software Development Engineer — 10+ years in fintech, cloud-native systems, and AI-augmented engineering, now building toward blockchain/smart contract engineering.

[LinkedIn](#) · jamesmakau18@gmail.com