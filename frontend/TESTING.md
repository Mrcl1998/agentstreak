# AgentStreak Frontend — TESTING.md

Static site, no build step, no backend, no server. Files: `index.html`, `app.js`, `styles.css`.

## How to run locally

```bash
cd ~/workspace/agentstreak/frontend
python3 -m http.server 8123 --bind 127.0.0.1
# open http://127.0.0.1:8123/
```

Requires an injected wallet (MetaMask / Binance Wallet extension) for the connect
and claim flows. Reads use public BSC RPCs, so the Agent ID check works without a wallet
only after a wallet is connected (the check is keyed to the connected address).

## What was verified (2026-11-18)

- **CDN:** `https://cdn.jsdelivr.net/npm/ethers@6.13.2/dist/ethers.umd.min.js`
  returns HTTP 200, `Content-Type: application/javascript`. ethers v6.13.2 UMD used.
- **Syntax:** `node --check app.js` — OK.
- **Serving:** `python3 -m http.server` serves `index.html` (200, 4150 B),
  `styles.css` (200), `app.js` (200). All 21 element IDs referenced by `app.js`
  exist in `index.html` (connectBtn, addressDisplay, networkWarning,
  switchNetworkBtn, noProvider, notDeployed, errorBox, agentIdStatus, streakNum,
  totalClaimsNum, lastClaimDay, countdown, claimBtn, claimStatus, txResult,
  badgeStatus, badgeMeta, badgeTokenId, lbStatus, lbTable, lbBody).
- **Dry run 1 — no injected wallet, placeholder contract address**
  (`/tmp/agentstreak-dryrun.cjs`, stubbed DOM): not-deployed banner visible,
  no-provider warning visible, claim button disabled with "Connect wallet first",
  leaderboard shows "Waiting for contract deployment…", no crash, no error.
- **Dry run 2 — simulated connected wallet, placeholder contract address**
  (`/tmp/agentstreak-dryrun2.cjs`, stubbed `window.ethereum` + ethers):
  address shown (`0x1111…1111`), no network warning on chain 56, Agent ID status
  "✓ You hold an Agent ID", claim button disabled with "Contract not deployed yet",
  not-deployed banner visible, leaderboard waiting state, no error, **no transaction
  attempted**.

## What still needs the deployed contract address

`CONTRACT_ADDRESS` in `app.js` is currently the zero address (placeholder). Until the
contract agent supplies the real deployed address, these paths are untested against a
live contract and show the "not deployed yet" state by design:

1. `getStats()` / streak card population, countdown start, "already claimed today" state.
2. `claim()` — the write path (user confirms in their own wallet; tx hash + BscScan
   link on success, revert/rejection surfaced as an error).
3. Badge `ownerOf` / `tokenURI` reads (badge tokenId = address as number).
4. Leaderboard — `Claimed` event scan first, fallback to `getClaimants` paging +
   `getStats` per claimant. The event scan uses `queryFilter(..., 0, "latest")`;
   if the public RPC rejects the full-range query, the fallback runs automatically.
5. Network switch button (`wallet_switchEthereumChain`, with `wallet_addEthereumChain`
   fallback on error 4902) — code-reviewed only, not exercised against a live wallet.

## Notes / known limitations

- WalletConnect is **not** wired in: injected provider is the core path per spec;
  the Reown project ID exists but adding it was not needed for the required flows.
  If the hackathon judges require it, it can be added as a secondary connect option.
- No wallet session is persisted anywhere (no `localStorage`, no server).
- No on-chain transaction was attempted during testing; no wallet or private key
  was used. MarsNexus was not touched.
