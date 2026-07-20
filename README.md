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

### `RWAShareToken.sol`
A fractional real-world-asset ownership token, built on **OpenZeppelin's** audited `ERC20`, `Ownable`, and `Pausable` base contracts rather than hand-rolled logic — the approach a production RWA platform would actually take.

- Compliance whitelist gating every mint, transfer, and burn — modeling the KYC/AML requirements real asset tokenization is legally subject to
- Enforced through a single overridden `_update()` hook (OpenZeppelin v5 pattern), guaranteeing the compliance check applies everywhere token balances change, rather than duplicating checks across multiple functions
- Owner-gated minting (new shares can only be issued to whitelisted holders)
- `Pausable` emergency stop — the issuer can freeze all transfers instantly without redeploying, for legal or security incidents

### Security case study — `VulnerableVault.sol` vs `SecureVault.sol`
A deliberate, hands-on demonstration of **reentrancy** — the vulnerability class behind the 2016 DAO hack (~$60M stolen) — built to prove understanding by exploiting a real bug, not just describing one.

- **`VulnerableVault.sol`** — a vault contract with a classic reentrancy flaw: it sends ETH to the caller *before* zeroing their recorded balance.
- **`ReentrancyAttacker.sol`** — a malicious contract that exploits this by recursively re-entering `withdraw()` from within its own `receive()` fallback, before the vault ever reaches the line that clears its balance.
- **`SecureVault.sol`** — the fixed version, using two independent defenses: reordering to Checks-Effects-Interactions (balance zeroed *before* the external call), plus OpenZeppelin's `ReentrancyGuard` (`nonReentrant`) as defense-in-depth.

These two contracts are intentionally kept side by side, unpatched, as a permanent "before/after" reference — `VulnerableVault` is never meant to be fixed or deployed with real value; it exists purely to prove the exploit and contrast it against the corrected pattern.

### Security case study — `TxOriginWallet.sol` vs `SecureWallet.sol`
Demonstrates the **`tx.origin` phishing vulnerability** — a common Solidity access-control mistake.

- **`TxOriginWallet.sol`** — authorizes withdrawals using `tx.origin == owner` instead of `msg.sender == owner`.
- **`PhishingAttacker.sol`** — a malicious contract disguised as something innocuous (`claimReward()`). When the real owner is tricked into calling it, `tx.origin` still equals the owner throughout the entire call chain — even though the owner never called the wallet directly — letting the attacker drain it.
- **`SecureWallet.sol`** — the fix: checks `msg.sender` instead, which correctly resolves to the *immediate* caller at each hop, not the original transaction initiator.

**Rule demonstrated:** never use `tx.origin` for authorization, without exception.

### Security case study — `UncheckedCounter.sol` vs `CheckedCounter.sol`
Demonstrates **integer underflow** via an `unchecked` block.

- **`UncheckedCounter.sol`** — spends a user's points inside `unchecked { }`, opting out of Solidity 0.8+'s default overflow/underflow protection. Spending more points than a user has doesn't revert — it wraps around to `type(uint256).max`, silently granting an almost-infinite balance.
- **`CheckedCounter.sol`** — the fix: simply removing `unchecked`. Solidity 0.8+'s built-in protection reverts automatically on underflow, with no extra code required.

**Rule demonstrated:** `unchecked` blocks trade safety for gas savings — only ever justified when the arithmetic is provably safe, and easy to get wrong.

### Security case study — `GuessingGame.sol` vs `CommitRevealGame.sol`
Demonstrates **front-running** — not a code bug, but a consequence of how public blockchains work: pending transactions are visible in the mempool before confirmation.

- **`GuessingGame.sol`** — accepts a plaintext guess. Anyone watching the mempool (e.g. `FrontRunnerBot.sol`) can see a correct guess about to be submitted and resubmit it with higher gas to get mined first, stealing the prize.
- **`CommitRevealGame.sol`** — the fix: a two-phase commit-reveal scheme. Players first submit a hash of their guess plus a secret salt (unreadable in the mempool), then reveal the real answer later, checked against their earlier commitment. By the time the real answer is visible, front-running it is no longer possible.

**Rule demonstrated:** sensitive on-chain actions that reveal information (guesses, bids, orders) need commit-reveal or similar patterns — plaintext submission is inherently front-runnable.

## Test Coverage

All contracts have full Foundry test suites covering the happy path, access control failures, and edge cases (duplicate registration, zero-address transfers, insufficient allowance/balance, compliance/pause enforcement, and four distinct exploit/fix pairs).

```shell
forge test -vvvv
```

**39 tests passing across 8 test suites**, including eight tests that specifically prove security behavior rather than just feature correctness:

| Test | Contract | Proves |
|---|---|---|
| `test_ReentrancyDrainsVault` | `VulnerableVault` | Reentrancy **succeeds** — a 1 ETH deposit drains the vault's full 5 ETH balance. |
| `test_ReentrancyAttackFailsAgainstSecureVault` | `SecureVault` | The identical attack **fails**, reverting via `ReentrancyGuardReentrantCall()`. |
| `test_TxOriginPhishingDrainsWallet` | `TxOriginWallet` | The phishing trick **succeeds** — the owner unknowingly drains their own wallet via `tx.origin`. |
| `test_SameTrickFailsAgainstMsgSenderCheck` | `SecureWallet` | The identical trick **fails** against a `msg.sender`-based check. |
| `test_UnderflowWrapsToHugeNumber` | `UncheckedCounter` | Underflow **succeeds** — spending more than a balance wraps to `type(uint256).max`. |
| `test_CheckedVersionRevertsOnUnderflow` | `CheckedCounter` | The identical call **reverts** cleanly under Solidity 0.8+'s default protection. |
| `test_FrontRunnerStealsPrize` | `GuessingGame` | Front-running **succeeds** — a bot copies a plaintext guess and steals the prize. |
| `test_CommitRevealPreventsFrontRunning` | `CommitRevealGame` | The identical attempt **fails** — a stolen answer has no matching prior commitment. |

Note: every "vulnerable" test reports `[PASS]` in Foundry's output — this reflects each test's *assertions* being correct (i.e. correctly proving the exploit works), not that the vulnerable contract is safe. Each vulnerable contract (`VulnerableVault`, `TxOriginWallet`, `UncheckedCounter`, `GuessingGame`) remains permanently exploitable by design, kept only as a documented "before" reference; only its paired "secure" contract reflects a safe, production-shaped pattern.

## Live Deployments — Sepolia Testnet

| Contract | Address | Etherscan |
|---|---|---|
| AssetRegistry | `0xe70F53Ba0B894065940567F4F3e96d0b8B1D334c` | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xe70F53Ba0B894065940567F4F3e96d0b8B1D334c) |
| SimpleToken | `0x4A04bC8d1d91B7b6C49e3bcfaA6A816727D62243` | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0x4A04bC8d1d91B7b6C49e3bcfaA6A816727D62243) |

*`RWAShareToken` and all six security case-study contracts are covered by full Foundry test suites but kept as local/testnet-ready practice contracts, not yet deployed to Sepolia.*

## Tech Stack

- **Solidity** `^0.8.24` (compiled with `0.8.35`)
- **Foundry** (Forge for testing/deployment, `forge-std` for cheatcodes/assertions)
- **OpenZeppelin Contracts** (`ERC20`, `Ownable`, `Pausable`, `ReentrancyGuard`)
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


[LinkedIn](https://www.linkedin.com/in/james-makau-17b90a146/) · jamesmakau18@gmail.com