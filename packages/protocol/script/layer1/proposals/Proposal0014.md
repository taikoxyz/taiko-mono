# PROPOSAL-0014: Register raiko2 v0.2.0 Shasta ZK Verifier Digests

## Executive Summary

This proposal **additively** registers the RISC Zero and SP1 guest digests from **[raiko2 v0.2.0](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0)** on the existing **Shasta-only** verifiers on Ethereum mainnet (`RISC0_SHASTA_VERIFIER`, `SP1_SHASTA_VERIFIER`).

It executes **6 L1 actions** via the DAO Controller. There are **no** L2 actions, **no** contract upgrades, and **no** SGX / attestation changes.

This follows the same pattern as [PR #21661 — Proposal0013 (raiko2 v0.1.0)](https://github.com/taikoxyz/taiko-mono/pull/21661). If Proposal0013 is merged first, this proposal is the **next** digest registration for the **[v0.2.0 release](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0)** (SP1 stack **6.1.0**, consolidated RISC0 aggregation for Boundless; see release notes).

Earlier trusted image/program IDs from [`Proposal0009`](./Proposal0009.s.sol), [`Proposal0010`](./Proposal0010.s.sol), and optionally Proposal0013 **remain** trusted unless a future proposal revokes them.

## Rationale

- Provers built from **raiko2 v0.2.0** emit new RISC0 `image_id` and SP1 program vkey values. On-chain verifiers must whitelist these digests before proofs from that release can verify.
- Scope is intentionally minimal: Shasta verifier addresses only, additive `setImageIdTrusted` / `setProgramTrusted` with `true`.

## Technical Specification

### Verifier Targets (unchanged from prior Shasta registrations)

| Constant                | Value                                        |
| ----------------------- | -------------------------------------------- |
| `RISC0_SHASTA_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` |
| `SP1_SHASTA_VERIFIER`   | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` |

### Guest digests ([raiko2 v0.2.0 — ZK Guest Digests](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0))

| Constant                          | Role (release)    | Value (`bytes32`)                                                    |
| --------------------------------- | ----------------- | -------------------------------------------------------------------- |
| `RISC0_PROPOSAL_IMAGE_ID`         | risc0 proposal    | `0x588c81521db5bef5e07f5beab37f1f0b2bba925ac82e733db7cc72e046362754` |
| `RISC0_AGGREGATION_IMAGE_ID`      | risc0 aggregation | `0x91ddc48054ff4ec62a93bfa0583582d0e04de6ab3928e51e0ea3ee523fee129f` |
| `SP1_PROPOSAL_VKEY_BN256`         | sp1 proposal      | `0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580` |
| `SP1_PROPOSAL_VKEY_HASH_BYTES`    | sp1 proposal      | `0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580` |
| `SP1_AGGREGATION_VKEY_BN256`      | sp1 aggregation   | `0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5` |
| `SP1_AGGREGATION_VKEY_HASH_BYTES` | sp1 aggregation   | `0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5` |

### L1 Actions (6 total)

1. `Risc0Verifier.setImageIdTrusted(RISC0_PROPOSAL_IMAGE_ID, true)` on `RISC0_SHASTA_VERIFIER`.
2. `Risc0Verifier.setImageIdTrusted(RISC0_AGGREGATION_IMAGE_ID, true)` on `RISC0_SHASTA_VERIFIER`.
3. `SP1Verifier.setProgramTrusted(SP1_PROPOSAL_VKEY_BN256, true)` on `SP1_SHASTA_VERIFIER`.
4. `SP1Verifier.setProgramTrusted(SP1_PROPOSAL_VKEY_HASH_BYTES, true)` on `SP1_SHASTA_VERIFIER`.
5. `SP1Verifier.setProgramTrusted(SP1_AGGREGATION_VKEY_BN256, true)` on `SP1_SHASTA_VERIFIER`.
6. `SP1Verifier.setProgramTrusted(SP1_AGGREGATION_VKEY_HASH_BYTES, true)` on `SP1_SHASTA_VERIFIER`.

## Verification

1. Open [raiko2 v0.2.0 release](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0) and confirm the **ZK Guest Digests** table matches the constants in [`Proposal0014.s.sol`](./Proposal0014.s.sol).

2. Regenerate the controller calldata (writes `Proposal0014.action.md`):

   ```bash
   cd packages/protocol
   P=0014 pnpm proposal
   ```

3. Dry-run on an L1 fork (mainnet RPC):

   ```bash
   P=0014 pnpm proposal:dryrun:l1
   ```

   Expect `DryrunSucceeded()` (or equivalent successful dryrun revert per `BuildProposal`).

4. Optionally compare digests with the raiko2 build artifact / `guest-digests` output for tag **v0.2.0** (commit **`f5d4665`** on the release page).

## Security Contacts

- security@taiko.xyz
