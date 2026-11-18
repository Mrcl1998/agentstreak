# AgentStreak

A **free daily streak claim for Binance Agent ID holders** — built for the Binance Agent ID Hackathon.

Any wallet holding an Agent ID can claim **once per day** (1 transaction, gas only, no fee). Streaks are tracked on-chain in consecutive UTC days. The first claim mints a **free soulbound badge** (1 per wallet, non-transferable). A public on-chain leaderboard shows the longest streaks.

- **No token.** No yield. No prizes promised to users.
- **No funds held by the contract.** There is nothing to deposit, stake, or lock.
- **No owner.** No fees, no pause, no upgrade. (See [Owner Permissions](#owner-permissions).)

## How it works

1. **Connect your wallet** — the frontend connects your own wallet (e.g. Binance Wallet). No login, no QR code, no pairing code, no seed phrase — ever.
2. **Check your Agent ID** — the contract checks that your wallet holds an Agent ID (SPACE ID Agent ID, ERC-721). If you don't hold one, the claim reverts.
3. **Claim once a day** — one transaction per UTC day, gas only. Claiming on consecutive UTC days grows your streak; missing a day resets it to 1.
4. **Watch your streak + leaderboard** — streaks and the leaderboard are public and read straight from the chain.

## Contract

| Item | Value |
|---|---|
| Network | BNB Smart Chain mainnet |
| Contract address | **TBD — pending deploy** |
| Agent ID contract | `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (SPACE ID, ERC-721) |
| BscScan | TBD — link added once deployed and verified |

## Architecture (in 10 lines)

1. **Contract** (`contract/`): `AgentStreak.sol` — claim, streak, and badge logic; holds no funds.
2. **Claim rule**: one claim per wallet per UTC day; only wallets holding an Agent ID.
3. **Streak rule**: claim on consecutive UTC days increments the streak; a missed day resets it to 1.
4. **Badge**: first successful claim mints 1 soulbound (non-transferable) badge per wallet.
5. **Events**: every claim emits an event (`Claimed`, `BadgeMinted`) — the source of truth for indexing.
6. **Leaderboard**: built off-chain by indexing claim events; `getClaimants` paging for reads.
7. **Frontend** (`frontend/`): static web app; connects the user's own wallet; every tx confirmed by the user in their own wallet.
8. **No backend server**: the frontend reads the chain directly; no user data is collected or stored off-chain.
9. **No funds flow**: the contract never receives, holds, or pays out BNB or tokens (gas goes to the network only).
10. **Docs**: `docs/ARCHITECTURE.md` (storage, rules, gas) and `docs/VERIFICATION.md` (BscScan source verification).

## Owner Permissions

**There is no owner.** The contract is designed with:

- No owner address, no `onlyOwner` functions, no admin role.
- No fee setting, no fee collection, no withdrawal function.
- No pause, no upgrade proxy, no kill switch.
- No function that can move, lock, or seize any user's streak, badge, or funds.

> Status: this is the design specification. It will be confirmed against the deployed contract once deployed — if the deployed contract contains any owner or admin function, this section will be corrected and the discrepancy disclosed here.

## Security

- **No funds held**: the contract holds no BNB and no tokens; there is nothing to steal from it.
- **No approvals requested**: the frontend never asks for token approvals or spending permissions.
- **No token, no yield, no returns**: AgentStreak does not issue a token and does not promise any income, reward, or prize to users.
- **No seed phrase, QR code, or pairing code**: AgentStreak never asks for your seed phrase, private key, wallet QR scan, or pairing code. Anyone asking for those in AgentStreak's name is a scammer.
- **Every transaction is confirmed by you**: each claim is a transaction you review and confirm in your own wallet. Nothing is signed or sent without you.
- **Open source**: the contract source is published in this repo and verified on BscScan (see `docs/VERIFICATION.md`) so anyone can read exactly what it does.

## Hackathon

Built for the **Binance Agent ID Hackathon** (submissions close 9 December 2026, 08:00 UTC).

Eligibility for the project awards requires the product to be live with **at least 30 Agent ID addresses interacting** before 9 December 2026, 08:00 UTC. Judging weights: depth 30%, practicality 25%, completion 25%, innovation 20%.

## Links

- Repository: https://github.com/Mrcl1998/agentstreak
- Contract on BscScan: TBD — pending deploy
- Agent ID contract on BscScan: https://bscscan.com/address/0x60b9262456de011f7d15a54cdd8c48baaa8b022f

## License

MIT — see [LICENSE](LICENSE).
