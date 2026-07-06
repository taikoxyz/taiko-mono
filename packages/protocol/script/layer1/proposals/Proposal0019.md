# PROPOSAL-0019: Unzen Hardfork — Re-enable Forced Inclusions and Mandate ZK Proofs

## Executive Summary

This proposal activates the Unzen hardfork on L1. It re-enables the forced inclusion mechanism
that was disabled as part of the June 2026 incident response, and replaces the proof verifier so
that every proven batch must include at least one ZK proof.

It executes **2 L1 actions** and **no L2 actions**:

1. Upgrade `Inbox` to a new implementation with forced inclusions re-enabled and the new
   `AnyTwoVerifier` baked in as its immutable proof verifier.
2. Call `Inbox.init3()` to void the stale forced inclusion queue entry left over from the
   incident window.

The fork activates at proposal execution. There is no in-contract timestamp gating; proposer and
prover software supporting forced inclusions and the ZK proof mandate must be rolled out **before**
this proposal executes (see [Client Rollout Prerequisite](#client-rollout-prerequisite)).

## What Changes

### 1. Forced inclusions re-enabled

The incident-response commits `fd8a69852` and `b73608696` disabled forced inclusions in three
places. The new implementation restores:

- `saveForcedInclusion(...)`: the unconditional `ForcedInclusionsDisabled` revert is removed —
  anyone can queue a forced inclusion again by paying the fee.
- `propose(...)`: the `numForcedInclusions == 0` restriction is removed — proposers can consume
  queued inclusions again.
- The due-check (`UnprocessedForcedInclusionIsDue`) is restored — once the oldest queued inclusion
  is older than `forcedInclusionDelay` (576s), proposers **must** process due inclusions (up to 10
  per proposal) or their proposal reverts.

**Deliberately NOT restored** (unchanged from the current post-incident state):

- Permissionless proposing (the fallback that allowed anyone to propose when the oldest forced
  inclusion was overdue by `160 × 576s ≈ 25.6h`) remains disabled.
- Permissionless proving-by-age remains disabled (this was the incident's on-chain amplifier).

### 2. ZK proof mandated on every batch

The current live `MainnetVerifier` (`0x71808449A6217898d602c1a392D95b931Ac5d878`, from
Proposal0017) accepts `SGX_GETH + SGX_RETH` — two TEE attestations with **zero ZK proofs**. Both
root causes of the June incident were SGX-side (leaked signing key + debug-mode attestation gap);
a mandatory ZK proof makes a repeat of that class of forgery insufficient to finalize.

The new `AnyTwoVerifier` accepts exactly two sub-proofs in one of three combinations:

| Combination      | Contains ZK |
| ---------------- | ----------- |
| SGX_RETH + RISC0 | yes         |
| SGX_RETH + SP1   | yes         |
| RISC0 + SP1      | yes         |

Consequences:

- The SGX-geth verifier (`0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee`) drops out of the
  verification chain (it is intentionally not touched by this proposal; it simply stops being
  referenced).
- Proving survives a total SGX outage via the RISC0 + SP1 combination.
- `AnyTwoVerifier` is an existing, in-repo compose contract — no new policy code was written.

Because `Inbox` stores its proof verifier as an immutable, the verifier swap requires the new
implementation; it cannot be set by calldata.

### 3. Stale forced inclusion queue voided (`init3`)

On-chain queue state at the time of writing: `head=2, tail=3` — exactly one pending entry.

All three forced inclusions ever queued came from `0x2f205367f408269b2aae3dd5fd4358aa6ae8d7e0`
(not associated with the attacker cluster; the pattern is consistent with a user force-exiting
during the incident):

| Queue idx | Tx                                                                   | L1 block     | Status                                |
| --------- | -------------------------------------------------------------------- | ------------ | ------------------------------------- |
| 0         | `0x67900d1499ee23864bf857662f6cde6e059de4d9a3b4b9d335862b3b626dc2a5` | `25,369,849` | consumed pre-upgrade                  |
| 1         | `0x77b219ef57e98875f2159c1d569b7f965ea1ee0adedd6a22ca96c2aaa5da5a7e` | `25,369,953` | consumed pre-upgrade                  |
| 2         | `0xdb21315494272eba02ccad0fe94dcb5c71d1fb6d94384b4a80b1de3875a52441` | `25,370,166` | **pending — voided by this proposal** |

The pending entry's blob (timestamp `1782095507`, 2026-06-22 02:31:47 UTC) exits the ~18-day
EIP-4844 blob retention window around 2026-07-10. After that no node can fetch its data, so the
inclusion is underivable. Re-enabling the due-check without voiding it would force proposers to
consume an underivable inclusion — voiding is therefore a hard prerequisite, not cleanup.

`init3()` (owner-only, `reinitializer(3)`) moves the queue head to the tail and emits
`ForcedInclusionsVoided(oldHead, newHead)`. The entry's 0.001 ETH fee remains in the Inbox
contract (no refund path exists on-chain; the `ForcedInclusion` struct does not record the payer).

## Action Order

1. Upgrade `L1.INBOX` to `MAINNET_INBOX_NEW_IMPL`.
2. Call `Inbox.init3()`.

The order matters: `init3` only exists on the new implementation. Both actions execute atomically
within the proposal, so no forced inclusion can be saved between the upgrade and the void.

## Production Addresses

| Constant              | Address                                      | Notes                            |
| --------------------- | -------------------------------------------- | -------------------------------- |
| `L1.INBOX`            | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | Shasta Inbox proxy               |
| `SGXRETH_VERIFIER`    | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` | SGX-reth verifier (Proposal0017) |
| `RISC0_RETH_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | RISC0 verifier (reused)          |
| `SP1_RETH_VERIFIER`   | `0x73A0Db393ef87ce781ac7957bE10D6628432100F` | SP1 verifier (Proposal0017)      |

All sub-verifier addresses were read live from the current `MainnetVerifier`
(`sgxRethVerifier()`, `risc0RethVerifier()`, `sp1RethVerifier()`) and cross-checked against the
Proposal0017 address table.

## Deployed Addresses

> **TODO(unzen):** run `DeployUnzenContracts` on chain 1, then fill this table and the constants
> in [`Proposal0019.s.sol`](./Proposal0019.s.sol), and regenerate `Proposal0019.action.md`
> (`P=0019 pnpm proposal`). The script reverts while the constants are zero.

| Constant                 | Address | Contract                                    |
| ------------------------ | ------- | ------------------------------------------- |
| `MAINNET_INBOX_NEW_IMPL` | TBD     | `MainnetInbox` implementation               |
| `ANY_TWO_VERIFIER`       | TBD     | `AnyTwoVerifier` (`MainnetInbox` immutable) |

## Client Rollout Prerequisite

Once the due-check is live, a proposer running software that always sends
`numForcedInclusions = 0` will have `propose()` revert whenever a forced inclusion has been
pending longer than 576s. The queue is empty immediately after `init3`, so the risk window opens
with the first post-fork `saveForcedInclusion` call. Proposer software supporting forced
inclusion consumption, and raiko capacity for one ZK proof per proven batch, must both be in
production before this proposal executes.

## Verification

Before submission:

1. Confirm `MAINNET_INBOX_NEW_IMPL` and `ANY_TWO_VERIFIER` match the `DeployUnzenContracts`
   broadcast, and confirm bytecode exists at both:

   ```bash
   cast code <ADDRESS> --rpc-url <RPC_URL>
   ```

2. Confirm the new `MainnetInbox` implementation was deployed with `ANY_TWO_VERIFIER`:

   ```bash
   cast call <MAINNET_INBOX_NEW_IMPL> "getConfig()((address,address,address,address,address,uint256,uint256,uint48,uint48,uint48,uint48,uint48,uint8,uint16,uint64,uint64,uint16))" --rpc-url <RPC_URL>
   ```

   The first tuple field must equal `ANY_TWO_VERIFIER`.

3. Confirm `ANY_TWO_VERIFIER` wires the three production sub-verifiers:

   ```bash
   cast call <ANY_TWO_VERIFIER> "sgxRethVerifier()(address)" --rpc-url <RPC_URL>
   cast call <ANY_TWO_VERIFIER> "risc0RethVerifier()(address)" --rpc-url <RPC_URL>
   cast call <ANY_TWO_VERIFIER> "sp1RethVerifier()(address)" --rpc-url <RPC_URL>
   ```

4. Confirm the forced inclusion queue state is still `head=2, tail=3` (nothing can change it —
   saves are hard-disabled and consumption requires `numForcedInclusions > 0`, which reverts):

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f "getForcedInclusionState()(uint48,uint48)" --rpc-url <RPC_URL>
   ```

5. Confirm the Inbox reinitializer version is `2` (`init2` consumed by Proposal0017, `init3`
   available):

   ```bash
   cast storage 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f 0 --rpc-url <RPC_URL>
   ```

   Expected: `0x...02`.

6. Confirm proposer/prover client releases supporting forced inclusions and per-batch ZK proving
   are deployed in production.

7. Generate calldata:

   ```bash
   P=0019 pnpm proposal
   ```

8. Dryrun on L1:

   ```bash
   P=0019 pnpm proposal:dryrun:l1
   ```

After execution:

1. Confirm the Inbox proxy implementation is `MAINNET_INBOX_NEW_IMPL`.
2. Confirm `getForcedInclusionState()` returns `head == tail == 3`.
3. Confirm `getConfig().proofVerifier` returns `ANY_TWO_VERIFIER`.
4. Confirm `saveForcedInclusion` accepts a fee-paying submission (no longer reverts with
   `ForcedInclusionsDisabled`).
5. Confirm proving continues: the next `prove()` transactions must carry two sub-proofs including
   at least one of RISC0/SP1; an SGX_GETH + SGX_RETH pair must now revert with
   `CV_VERIFIERS_INSUFFICIENT`.

## Security Contacts

- security@taiko.xyz
