# AgentStreak — BscScan Source Verification Procedure

Goal: verify the deployed `AgentStreak` contract source on BscScan (BNB Smart Chain
mainnet) so anyone can read exactly what the contract does. This is a hackathon
eligibility requirement (source verified + open-source repo).

> Status: **NOT YET DONE — no contract is deployed yet.** This document is the
> procedure to follow once the contract agent reports the deployed address and
> the exact compiler settings. Do NOT attempt verification before then.

## What you need before starting

| Item | Value / status |
|---|---|
| Network | BNB Smart Chain mainnet (chain ID 56) |
| Deployed contract address | **TODO — pending deploy** |
| Contract file | `contract/AgentStreak.sol` (exact source as deployed) |
| Compiler version | **TODO — from the contract agent (e.g. `v0.8.24+commit...`)** |
| Optimizer | Enabled/disabled + runs — **TODO — from the contract agent** |
| Constructor arguments | **TODO — from the contract agent (ABI-encoded, if any; likely the Agent ID address `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`)** |
| EVM version | **TODO — from the contract agent (default unless stated)** |
| License | MIT |
| BscScan account | Any account able to submit a verification (no payment required) |

## Step-by-step (BscScan web UI)

1. Deploy the contract on BNB Smart Chain mainnet and record the deployed address
   and the transaction hash.
2. Go to the contract page: `https://bscscan.com/address/<DEPLOYED_ADDRESS>#code`
   and click **"Verify and Publish"**.
3. Compiler type: choose **Solidity (Single file)** if the contract is a single
   flattened file, or **Solidity (Standard JSON Input)** if it has imports —
   use whichever matches how the contract agent built it.
4. Fill in:
   - **Compiler version**: exactly the version used to compile the deployed bytecode
     (must match byte-for-byte, including the commit hash suffix).
   - **Open Source License Type**: MIT.
   - **Optimization**: Yes/No + runs, exactly as compiled.
   - **EVM version**: as compiled (default if untouched).
5. Paste the source:
   - Single-file: paste the flattened source (all imports inlined).
   - Standard JSON Input: paste the full standard JSON used for compilation.
   - The source must be **identical** to what was deployed — even a comment change
     breaks the match.
6. Constructor arguments: if the constructor takes arguments, paste the ABI-encoded
   arguments (BscScan can auto-fill these from the deploy transaction — check the
   "Constructor Arguments" field it detects and confirm it matches).
7. Submit and wait for the result. Success shows **"Compiler Version"**,
   **"Optimization Enabled"**, and the full source on the contract page, plus a
   green checkmark.
8. If verification fails with a bytecode mismatch:
   - Re-check compiler version (including commit suffix), optimizer runs, and EVM version.
   - Re-check that the pasted source is the exact deployed source.
   - Re-check constructor arguments encoding.
   - Do **not** re-deploy to "fix" verification without confirming the mismatch cause —
     redeploying changes the address and costs gas.
9. Once verified, update `README.md` with the BscScan link and record the deployed
   address in this file and in `docs/ARCHITECTURE.md`.

## After verification

- Confirm the verified source shows **no owner/admin functions, no fees, no pause,
  no upgrade** — matching the README "Owner Permissions" section. If anything
  differs, update the README and disclose it.
- Link the verified contract in the hackathon submission.
