# AgentStreak — Architecture

## Overview

AgentStreak is a free daily streak claim for Binance Agent ID holders on BNB Smart Chain.
One claim per wallet per UTC day, gas only, no fee. Streaks are tracked on-chain in
consecutive UTC days. The first claim mints a free soulbound badge (1 per wallet,
non-transferable). A public leaderboard is indexed from claim events. The contract
holds no funds and has no owner.

## Contract storage layout

(Design specification — exact variable names/slots to be confirmed against the
deployed source in `contract/`.)

| Storage | Type | Purpose |
|---|---|---|
| `agentId` | `address` (immutable) | SPACE ID Agent ID contract: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (ERC-721). Eligibility = `balanceOf(wallet) > 0`. |
| `_users` | `mapping(address => User)` | Per-wallet struct: `streak` (uint32), `totalClaims` (uint32), `lastClaimDay` (uint64), `hasBadge` (bool). |
| `_claimants` | `address[]` | Every wallet that has ever claimed, in first-claim order (for leaderboard paging). |
| badge | ERC-721 (soulbound) | Badge token; transfers blocked (revert on `transferFrom`/`safeTransferFrom` except mint). 1 per wallet, enforced by `hasBadge`. Token ID = sequential. |

No owner/admin storage, no fee storage, no pause flag, no upgrade slot — by design.

## Claim / streak rules

1. **Eligibility**: caller must hold at least 1 Agent ID (`agentId.balanceOf(msg.sender) > 0`), else revert.
2. **One claim per UTC day**: `day = block.timestamp / 1 days`; revert if `lastClaimDay[msg.sender] == day`.
3. **Streak update**:
   - If `lastClaimDay == day - 1` → `streak += 1` (consecutive day).
   - Else (gap of 2+ days, or first claim) → `streak = 1` (reset).
   - No separate `bestStreak` is stored; the leaderboard ranks by current streak, then `totalClaims`.
4. **Badge**: on first successful claim (`!hasBadge`), mint 1 soulbound badge to the caller, set `hasBadge = true`.
5. **Events** (emitted on every claim — the indexing source of truth):
   - `Claimed(address indexed user, uint256 indexed day, uint256 streak, uint256 totalClaims)`
   - `BadgeMinted(address indexed user, uint256 indexed tokenId)` (first claim only)
6. **First-claim registration**: on a wallet's first claim, push it to `claimants[]`.

Day boundaries use UTC (`block.timestamp / 86400`), matching the "once per day" rule
regardless of the user's local timezone.

## Badge design

- ERC-721, non-transferable (soulbound): all transfer entry points revert except minting.
- 1 per wallet, minted automatically on first claim — no separate mint transaction, no cost beyond the claim's gas.
- Metadata: static on-chain/URI per token; no rarity, no tiers, no monetary value.
- The badge is a proof-of-participation record, not a reward token and not redeemable for anything.

## Leaderboard indexing

- **Source**: `Claimed` events (and `BadgeMinted` for badge holders).
- **Off-chain indexer** (frontend or a lightweight script): scan events from the deploy
  block, aggregate latest `streak` / `totalClaims` per address, sort by
  current streak (then total claims).
- **On-chain paging**: `getClaimants(uint256 offset, uint256 limit)` returns a slice of
  `_claimants[]` so the frontend can page through all claimants without loading the whole
  array in one call; per-address state is read via view functions (`getStreak`,
  `getStats`, `totalClaimants`, `claimants(index)`, badge `balanceOf`/`ownerOf`/`tokenURI`).
- No off-chain database is required; the chain is the database.

## Gas notes

- **Deploy budget constraint: the deploy transaction must fit within ~0.00039107 BNB**
  (the available wallet balance at build time). This is a hard cap, not a target.
- Claim is a single lightweight transaction: one ERC-721 `balanceOf` check, a few storage
  writes (`lastClaimDay`, `streak`, `totalClaims`, `hasBadge`, `claimants` push on first
  claim), plus badge mint on first claim only. No loops over unbounded arrays in `claim()`.
- Measured numbers (deployed 18 Nov 2026, block 134331779, tx `0x28e466571d0e58da5ed42dc348024fceb4af6d55b54cc1001353894bd2fd9482`):
  - Deploy gas used: **790,870 gas**, fee **0.00006632 BNB** @ 0.0839 gwei (via EIP-2470 factory, gas-limit cap 1,000,000; node estimate was 805,504).
  - Claim gas (first claim, with badge mint): **122,324 gas** (Foundry-measured).
  - Claim gas (repeat claim, no badge): **40,232 gas** (Foundry-measured).
- Note: the first deploy attempt used the wrong calldata format for the factory (ABI-encoded `deploy(bytes,bytes32)` instead of raw `salt || initCode`) and deployed an empty contract at `0x2cEc7F4f026D1c103bfecC142519c9E1Be5404F9`, costing 0.00001095 BNB. The factory expects raw `salt (32 bytes) || initCode` — no selector, no ABI encoding. Total spent on deploys: 0.00007727 BNB; wallet balance after: 0.00031381 BNB.
- Known compiler settings (from `contract/foundry.toml`, confirmed): solc **0.8.26**,
  optimizer **enabled, 200 runs, via_ir=true** (also recorded in `docs/VERIFICATION.md`).
- Deploy status: **DEPLOYED within budget** — fee 0.00006632 BNB vs the 0.00039107 BNB cap.
- If the deploy does not fit the budget, the contract must be slimmed (fewer storage
  slots, no unused code) before any retry — do not fund the deploy from another wallet
  without the owner's explicit approval.

## Frontend

- Static web app in `frontend/`; connects the user's own wallet; reads contract state
  directly from BNB Smart Chain; sends the claim transaction only after the user
  confirms it in their own wallet.
- No backend, no user accounts, no off-chain storage of user data.
