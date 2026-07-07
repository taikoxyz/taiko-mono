# PROPOSAL-0019: Unzen Hardfork — Re-enable Forced Inclusions and Mandate ZK Proofs

## Executive Summary

This proposal activates the Unzen hardfork on L1. It re-enables the forced inclusion mechanism
that was disabled as part of the June 2026 incident response, replaces the proof verifier so
that every proven batch must include at least one ZK proof, and completes the SGX remediation by
replacing the SGX verifier with the hardened implementation wired to the audited upstream
Automata DCAP attestation.

It executes **7 L1 actions** and **no L2 actions**:

1. `setMrEnclave(TRUSTED_MR_ENCLAVE_GETH, true)` on the new SGX-geth verifier.
2. `setMrSigner(TRUSTED_MR_SIGNER, true)` on the new SGX-geth verifier.
3. `setMrEnclave(TRUSTED_MR_ENCLAVE_RETH_1, true)` on the new SGX-reth verifier.
4. `setMrEnclave(TRUSTED_MR_ENCLAVE_RETH_2, true)` on the new SGX-reth verifier.
5. `setMrSigner(TRUSTED_MR_SIGNER, true)` on the new SGX-reth verifier.
6. Upgrade `Inbox` to a new implementation with forced inclusions re-enabled and the new
   `ZkRequiredVerifier` baked in as its immutable proof verifier.
7. Call `Inbox.init3()` to void the stale forced inclusion queue entry left over from the
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

The new `ZkRequiredVerifier` accepts exactly two sub-proofs in one of three combinations:

| Combination      | Contains ZK |
| ---------------- | ----------- |
| SGX_GETH + RISC0 | yes         |
| SGX_GETH + SP1   | yes         |
| SGX_RETH + RISC0 | yes         |
| SGX_RETH + SP1   | yes         |
| RISC0 + SP1      | yes         |

Consequences:

- SGX-geth prover diversity is preserved: both SGX flavors participate, each through a new
  hardened verifier. The forbidden pair is SGX_GETH + SGX_RETH (zero ZK) — the exact
  combination that finalized the June 2026 forged proofs.
- Proving survives a total SGX outage via the RISC0 + SP1 combination.
- `ZkRequiredVerifier` is an existing, in-repo compose contract — no new policy code was written.

Because `Inbox` stores its proof verifier as an immutable, the verifier swap requires the new
implementation; it cannot be set by calldata.

### 3. SGX verifier replaced: upstream audited attestation + post-v3.1.0 hardening

The SGX slots in `ZkRequiredVerifier` are **not** the Proposal0017 verifiers
(`0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` geth, `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8`
reth). Those contracts are immutably wired to the pre-incident vendored Automata attestation
(which lacks on-chain DEBUG-enclave rejection) and predate the SGX hardening merged since
v3.1.0. Because every link in the chain is an immutable
(`SgxVerifier → attestation`, `ZkRequiredVerifier → sub-verifiers`, `Inbox → proof verifier`), this
proposal is the natural — and only — deployment window; skipping it would force a second Inbox
upgrade later.

The bundle therefore deploys, bottom-up:

1. **`AutomataDcapAttestationFee`** — the audited upstream Automata DCAP entrypoint
   (+ `V3QuoteVerifier`, RIP-7212 P256 verifier, Automata's on-chain PCCS). Deployed first by
   `DeployAutomataDcapAttestation` under `FOUNDRY_PROFILE=layer1o` (the upstream code only
   compiles under via_ir). Non-upgradeable, verification fee pinned to zero.
2. **Two `SecureSgxVerifier` instances (SGX-geth and SGX-reth)** — the hardened in-repo
   verifier: trust registry moved in-contract, permanent MRENCLAVE/MRSIGNER untrust (no silent
   revival), uint32 instance-id overflow rejection, quote-freshness gate, per-MRENCLAVE
   ATTRIBUTES pin. Constructor params mirror Proposal0017: owner = DAO controller, registrar =
   admin.taiko.eth multisig, 24h instance validity delay — but the attestation immutable points
   at the upstream entrypoint, and **both flavors share the single entrypoint** (the old setup
   needed one attester per flavor only because the allowlists lived in the attester; they now
   live in each verifier). The contracts are identical: each becomes geth- or reth-flavored
   through the `ZkRequiredVerifier` slot it occupies, the measurements trusted on it, and the
   raiko instances that register on it.
3. **`ZkRequiredVerifier`** wiring both new SGX verifiers + the reused RISC0/SP1 verifiers.

**Trust configuration (actions 1–5).** The new verifiers deploy fail-closed: with empty
allowlists, `registerInstance` reverts for every quote. The trusted measurements are exactly the
sets live on the Proposal0017 attesters (read from `MrEnclaveUpdated`/`MrSignerUpdated` events
on `SGXGETH_ATTESTER 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` and `SGXRETH_ATTESTER
0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`, set at Proposal0017 execution, L1 block
`25,423,573`, unchanged since). The raiko images do not change; only the verifier contracts do,
so the measurements carry over verbatim (both flavors share one raiko signing identity):

| Constant                   | Value                                                                | Meaning                      |
| -------------------------- | -------------------------------------------------------------------- | ---------------------------- |
| `TRUSTED_MR_ENCLAVE_GETH`  | `0xbefb2c7ec44cefe57f4ff0ca815a8b8f15e05631bf3abe36cbc12d28f778fa36` | raiko SGX-geth MRENCLAVE     |
| `TRUSTED_MR_ENCLAVE_RETH_1`| `0xdccd8f30ea4a137ddfa63d743e3aa7c7a8e80585912d19c4b66f7d8d6098bec4` | raiko SGX-reth MRENCLAVE     |
| `TRUSTED_MR_ENCLAVE_RETH_2`| `0x92dd96a170d1ffb998afa210b3ef8af8c408ab76c4717e0eb8076d4a5da4e740` | raiko SGX-reth MRENCLAVE     |
| `TRUSTED_MR_SIGNER`        | `0x48fa5bbad91d274735d238715913c8712a7505bb6d0dd832764bedb46d587013` | post-incident raiko MRSIGNER |

**Instance registration (post-execution, operational).** Both new verifiers start with
`nextInstanceId == 0`. After execution, the registrar (`admin.taiko.eth`,
`0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`) must call `registerInstance` on each with a fresh
raiko quote of the matching flavor, verified through the **new upstream attestation
entrypoint**. Unlike
Proposal0017 — where proving halted until SGX registration — the `RISC0 + SP1` combination keeps
proving alive throughout; the SGX+ZK combinations become available once registration completes.
Track registration as a required follow-up, not optional cleanup.

### 4. Stale forced inclusion queue voided (`init3`)

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

1. `SGXGETH_VERIFIER_NEW.setMrEnclave(TRUSTED_MR_ENCLAVE_GETH, true)`
2. `SGXGETH_VERIFIER_NEW.setMrSigner(TRUSTED_MR_SIGNER, true)`
3. `SGXRETH_VERIFIER_NEW.setMrEnclave(TRUSTED_MR_ENCLAVE_RETH_1, true)`
4. `SGXRETH_VERIFIER_NEW.setMrEnclave(TRUSTED_MR_ENCLAVE_RETH_2, true)`
5. `SGXRETH_VERIFIER_NEW.setMrSigner(TRUSTED_MR_SIGNER, true)`
6. Upgrade `L1.INBOX` to `MAINNET_INBOX_NEW_IMPL`.
7. Call `Inbox.init3()`.

The order matters: the SGX verifiers' trust registries are configured before the Inbox starts
routing proofs through them, and `init3` only exists on the new implementation. All actions
execute atomically within the proposal, so no forced inclusion can be saved between the upgrade
and the void, and neither verifier is ever live with an empty allowlist.

## Production Addresses

| Constant              | Address                                      | Notes                                             |
| --------------------- | -------------------------------------------- | ------------------------------------------------- |
| `L1.INBOX`            | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | Shasta Inbox proxy                                |
| `RISC0_RETH_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | RISC0 verifier (reused)                           |
| `SP1_RETH_VERIFIER`   | `0x73A0Db393ef87ce781ac7957bE10D6628432100F` | SP1 verifier (Proposal0017, reused)               |
| —                     | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` | old SGX-geth verifier (Proposal0017) — **retired**, replaced by `SGXGETH_VERIFIER_NEW` |
| —                     | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` | old SGX-reth verifier (Proposal0017) — **retired**, replaced by `SGXRETH_VERIFIER_NEW` |
| —                     | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` | old SGX-geth attester proxy — **retired**, replaced by `DCAP_ATTESTATION` |
| —                     | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` | old SGX-reth attester proxy — **retired**, replaced by `DCAP_ATTESTATION` |

RISC0/SP1 addresses were read live from the current `MainnetVerifier` (`risc0RethVerifier()`,
`sp1RethVerifier()`) and cross-checked against the Proposal0017 address table.

## Deployed Addresses

> **TODO(unzen):** deployment is two steps (the upstream Automata code requires via_ir, which is
> quarantined in the `layer1o` profile):
>
> 1. `FOUNDRY_PROFILE=layer1o forge script DeployAutomataDcapAttestation ...` (set
>    `CONTRACT_OWNER` = DAO controller, `PCCS_ROUTER` = Automata's mainnet PCCS router) → note
>    the logged entrypoint.
> 2. `DCAP_ATTESTATION=<entrypoint> forge script DeployUnzenContracts ...` (profile `layer1`;
>    reverts if `DCAP_ATTESTATION` is unset or has no code).
>
> Then fill this table and the constants in [`Proposal0019.s.sol`](./Proposal0019.s.sol), and
> regenerate `Proposal0019.action.md` (`P=0019 pnpm proposal`). The script reverts while the
> constants are zero.

| Constant                 | Address | Contract                                                     |
| ------------------------ | ------- | ------------------------------------------------------------ |
| `DCAP_ATTESTATION`       | TBD     | `AutomataDcapAttestationFee` (upstream, non-upgradeable)     |
| `SGXGETH_VERIFIER_NEW`   | TBD     | `SecureSgxVerifier` (`ZkRequiredVerifier` immutable)         |
| `SGXRETH_VERIFIER_NEW`   | TBD     | `SecureSgxVerifier` (`ZkRequiredVerifier` immutable)         |
| `ZK_REQUIRED_VERIFIER`       | TBD     | `ZkRequiredVerifier` (`MainnetInbox` immutable)                  |
| `MAINNET_INBOX_NEW_IMPL` | TBD     | `MainnetInbox` implementation                                |

## Client Rollout Prerequisite

Once the due-check is live, a proposer running software that always sends
`numForcedInclusions = 0` will have `propose()` revert whenever a forced inclusion has been
pending longer than 576s. The queue is empty immediately after `init3`, so the risk window opens
with the first post-fork `saveForcedInclusion` call. Proposer software supporting forced
inclusion consumption, and raiko capacity for one ZK proof per proven batch, must both be in
production before this proposal executes.

## Verification

Before submission:

1. Confirm `MAINNET_INBOX_NEW_IMPL` and `ZK_REQUIRED_VERIFIER` match the `DeployUnzenContracts`
   broadcast, and confirm bytecode exists at both:

   ```bash
   cast code <ADDRESS> --rpc-url <RPC_URL>
   ```

2. Confirm the new `MainnetInbox` implementation was deployed with `ZK_REQUIRED_VERIFIER`:

   ```bash
   cast call <MAINNET_INBOX_NEW_IMPL> "getConfig()((address,address,address,address,address,uint256,uint256,uint48,uint48,uint48,uint48,uint48,uint8,uint16,uint64,uint64,uint16))" --rpc-url <RPC_URL>
   ```

   The first tuple field must equal `ZK_REQUIRED_VERIFIER`.

3. Confirm `ZK_REQUIRED_VERIFIER` wires the four production sub-verifiers (`sgxGethVerifier()`/
   `sgxRethVerifier()` must return the NEW verifiers, not the retired `0x41e79EB4…`/`0x9D3C595B…`):

   ```bash
   cast call <ZK_REQUIRED_VERIFIER> "sgxGethVerifier()(address)" --rpc-url <RPC_URL>
   cast call <ZK_REQUIRED_VERIFIER> "sgxRethVerifier()(address)" --rpc-url <RPC_URL>
   cast call <ZK_REQUIRED_VERIFIER> "risc0RethVerifier()(address)" --rpc-url <RPC_URL>
   cast call <ZK_REQUIRED_VERIFIER> "sp1RethVerifier()(address)" --rpc-url <RPC_URL>
   ```

4. Confirm both new SGX verifiers' attestation chain and fail-closed defaults (run for
   `<SGXGETH_VERIFIER_NEW>` and `<SGXRETH_VERIFIER_NEW>`):

   ```bash
   # must equal DCAP_ATTESTATION (the upstream entrypoint, shared by both)
   cast call <SGX_VERIFIER> "automataDcapAttestation()(address)" --rpc-url <RPC_URL>
   # owner must be the DAO controller, registrar the admin multisig
   cast call <SGX_VERIFIER> "owner()(address)" --rpc-url <RPC_URL>
   cast call <SGX_VERIFIER> "registrar()(address)" --rpc-url <RPC_URL>
   # fail-closed enclave policy enforced
   cast call <SGX_VERIFIER> "checkLocalEnclaveReport()(bool)" --rpc-url <RPC_URL>
   # upstream entrypoint verification fee must be zero (registerInstance is non-payable)
   cast call <DCAP_ATTESTATION> "getBp()(uint16)" --rpc-url <RPC_URL>
   ```

5. Confirm the forced inclusion queue state is still `head=2, tail=3` (nothing can change it —
   saves are hard-disabled and consumption requires `numForcedInclusions > 0`, which reverts):

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f "getForcedInclusionState()(uint48,uint48)" --rpc-url <RPC_URL>
   ```

6. Confirm the Inbox reinitializer version is `2` (`init2` consumed by Proposal0017, `init3`
   available):

   ```bash
   cast storage 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f 0 --rpc-url <RPC_URL>
   ```

   Expected: `0x...02`.

7. Confirm proposer/prover client releases supporting forced inclusions and per-batch ZK proving
   are deployed in production.

8. Generate calldata:

   ```bash
   P=0019 pnpm proposal
   ```

9. Dryrun on L1:

   ```bash
   P=0019 pnpm proposal:dryrun:l1
   ```

After execution:

1. Confirm the Inbox proxy implementation is `MAINNET_INBOX_NEW_IMPL`.
2. Confirm `getForcedInclusionState()` returns `head == tail == 3`.
3. Confirm `getConfig().proofVerifier` returns `ZK_REQUIRED_VERIFIER`.
4. Confirm `saveForcedInclusion` accepts a fee-paying submission (no longer reverts with
   `ForcedInclusionsDisabled`).
5. Confirm both new SGX verifiers' trust registries took effect (the geth MRENCLAVE on the geth
   verifier, both reth MRENCLAVEs on the reth verifier, the MRSIGNER on both;
   `revokedMrEnclave`/`revokedMrSigner` all false).
6. **Register the raiko SGX instances** (registrar, `admin.taiko.eth`): call
   `registerInstance(rawQuote)` on each new verifier with a fresh quote of the matching flavor,
   then confirm `nextInstanceId() > 0` on both. Until this completes, proving runs on
   RISC0 + SP1 only.
7. Confirm proving continues: the next `prove()` transactions must carry two sub-proofs including
   at least one of RISC0/SP1; an SGX_GETH + SGX_RETH pair must now revert with
   `CV_VERIFIERS_INSUFFICIENT`.
8. Follow-up cleanup PR (post-execution): remove the now-retired `MainnetVerifier` contract and
   the old SGX verifier/attester constants from `LibL1Addrs` — kept until execution so the live
   contracts remain rebuildable/verifiable from main and a rollback path exists.

## Security Contacts

- security@taiko.xyz
