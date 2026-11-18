# AgentStreak — Contract Notes

Single contract `AgentStreak` for the Binance Agent ID Hackathon (submission ends
9 Dec 2026 08:00 UTC). Free daily streak claim for Agent ID holders on BNB Smart Chain
mainnet (chain 56). **No owner, no fees, no upgradeability, no pause, no token,
no funds held** — the contract holds no BNB and no tokens; `claim()` is free apart
from gas. Also stated in the contract's NatSpec header.

## Files

| File | What it is |
|---|---|
| `src/AgentStreak.sol` | Final contract source (single file, hand-rolled minimal ERC721, no OpenZeppelin) |
| `test/AgentStreak.t.sol` | Foundry test suite (13 tests, incl. gas measurement) |
| `AgentStreak.abi.json` | ABI JSON |
| `AgentStreak.bytecode.hex` | Deployment (creation) code, `0x`-prefixed hex |
| `script/AgentStreak.s.sol` | Deploy script (`forge script`, no constructor args) |
| `foundry.toml` | Compiler settings (see below) |

## Toolchain

- **Foundry 1.9.0** (`forge`, `cast`, `anvil` already installed at `~/.foundry/bin` —
  no install needed). No testnet rehearsal run: local Foundry tests only
  (no wallet / private key involved anywhere; nothing was deployed on-chain).
- Compiler: **solc 0.8.26**, optimizer **enabled, runs = 200, via_ir = true**.
  `via_ir` was the big win: deploy gas fell 969,579 → **824,322** (runs=200,
  no via_ir: 969,579; runs=1, no via_ir: 959,127; runs=2000: 1,113,276).
- Creation code: **3,428 bytes**; runtime code: **3,402 bytes**.
  Creation-code SHA-256: `c0fce4867f30dc04cb5a47c09244cd5cae98543f6db350419b58caad2c6b5b34`.

## Design

- Agent ID check: `balanceOf(msg.sender) > 0` on SPACE ID Agent ID
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (immutable constant).
- `claim()`: one claim per UTC day (`block.timestamp / 86400`). Reverts
  `AlreadyClaimedToday` / `NotAgentIdHolder`. Streak `+1` if yesterday claimed
  (`lastClaimDay + 1 == day`), else reset to `1`. Per-user storage packs into ONE
  slot (`lastClaimDay uint64`, `streak uint32`, `totalClaims uint32`, `hasBadge bool`).
- First claim appends to `claimants[]`, emits `BadgeMinted` + ERC721 `Transfer`
  (zero address → holder). Badge `tokenId = uint160(msg.sender)`.
- Soulbound badge: minimal ERC721 in the same contract (`name` "AgentStreak Badge",
  `symbol` "ASTREAK", `balanceOf`/`ownerOf`/`tokenURI`/`getApproved`/`isApprovedForAll`/
  `supportsInterface`). `transferFrom`, `safeTransferFrom` (both overloads),
  `approve`, `setApprovalForAll` all revert `Soulbound()`. `tokenURI` returns a
  `data:application/json` metadata URI with badge name, description, live streak
  and total claims.
- Views: `getStreak`, `getStats` (streak, totalClaims, lastClaimDay, hasBadge),
  `totalClaimants()`, `claimants(i)`, `getClaimants(offset, limit)` paging,
  plus global `totalClaims` counter.

## Gas (measured in Foundry tests, solc 0.8.26, optimizer runs=200, via_ir)

| Operation | Gas |
|---|---|
| Deploy (CREATE execution only) | **824,322** |
| Deploy as a real tx (+ 21,000 base) | **845,322** |
| First `claim()` (badge mint + cold storage) | 122,324 |
| Later `claim()` (warm path) | 40,232 |

## Deploy-cost table (deploy tx = 845,322 gas)

| Gas price | Deploy cost (BNB) | Fits in 0.00039107 BNB? |
|---|---|---|
| 0.15 gwei | **0.00012680** | ✅ YES — uses 32.4%, leaves 0.00026427 BNB |
| 0.5 gwei | 0.00042266 | ❌ NO — short by 0.00003159 BNB |
| 1 gwei | 0.00084532 | ❌ NO |
| 3 gwei | 0.00253597 | ❌ NO |

**Verdict: DEPLOY FITS in the deployer wallet (0.00039107 BNB) at gas prices up to
≈ 0.46 gwei.** At the effective baw gas price seen on BSC (~0.15–0.17 gwei) the
deploy costs ~0.000127–0.000144 BNB and leaves ~0.00025 BNB spare. Do NOT deploy if
the live gas price is above ~0.4 gwei — wait for it to drop or top up the wallet.
Claim gas for users is tiny (first claim 122,324 gas ≈ 0.00001835 BNB @ 0.15 gwei;
later claims 40,232 gas ≈ 0.00000603 BNB @ 0.15 gwei).

## Tests — 13 passed, 0 failed

`forge test` (Foundry, mock Agent ID etched at the real Agent ID address):

| Test | Result |
|---|---|
| claim works for a holder | ✅ PASS |
| double claim same day reverts | ✅ PASS |
| streak increments on consecutive days (warp) | ✅ PASS |
| streak resets to 1 after a missed day | ✅ PASS |
| non-holder reverts | ✅ PASS |
| badge minted exactly once (first claim only) | ✅ PASS |
| badge transfer / approve reverts (soulbound) | ✅ PASS |
| badge tokenId equals holder address as uint160 | ✅ PASS |
| view functions return correct values | ✅ PASS |
| tokenURI contains live streak | ✅ PASS |
| tokenURI reverts without badge | ✅ PASS |
| getClaimants paging works | ✅ PASS |
| deploy + claim gas measurement | ✅ PASS |

Note: one test initially failed after enabling `via_ir` because `block.timestamp`
was read across `vm.warp` and the optimizer cached it (Foundry lint
`environment-read-across-mutation`). Fixed in the TEST only — tests now use
`vm.getBlockTimestamp()` after warping. Contract code was not at fault.

## Deployment steps (constructor args: NONE)

1. Confirm deployer wallet balance ≥ ~0.00015 BNB and live BSC gas price ≤ 0.4 gwei
   (check first — see verdict above).
2. `cd ~/workspace/agentstreak/contract`
3. `forge build` (verify creation-code hash matches
   `c0fce4867f30dc04cb5a47c09244cd5cae98543f6db350419b58caad2c6b5b34`).
4. Deploy with the deployer's own tooling (baw or `forge script
   script/AgentStreak.s.sol --rpc-url <BSC mainnet RPC> --broadcast`), gas price
   capped at 0.4 gwei, no constructor arguments, no value.
5. Verify the deployed address + record the tx hash; verify source on BscScan.
6. Sanity-check on mainnet (read-only): `getStreak`, `totalClaimants`,
   `supportsInterface(0x80ac58cd)`.

**Nothing in this directory was deployed on-chain. No wallet, seed phrase, or
private key was used or touched. No interaction with MarsNexus or any other
contract.**
