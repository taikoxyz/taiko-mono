# PROPOSAL-0019: Unzen Hardfork — Re-enable Forced Inclusions and Mandate ZK Proofs

## Executive Summary

This proposal activates the Unzen hardfork on L1. It re-enables the forced inclusion mechanism
that was disabled as part of the June 2026 incident response, replaces the proof verifier so
that every proven batch must include at least one ZK proof, completes the SGX remediation by
replacing the SGX verifier with the hardened implementation wired to the audited upstream
Automata DCAP attestation, and rotates the trusted RISC0/SP1 proving images to the raiko
release shipping with Unzen.

The new SGX verifiers' trust configuration (MRENCLAVE / ATTRIBUTES policy / MRSIGNER) and raiko
instance registration are performed **manually by admin.taiko.eth before execution** — the
verifiers deploy with the multisig as initial owner. The proposal then takes that trust
boundary into DAO custody by accepting ownership (see
[Trust configuration and registration](#trust-configuration-and-registration-manual-pre-execution)).

It executes **16 L1 actions** and **no L2 actions**:

- **Actions 1–2**: `acceptOwnership()` on the new SGX-geth and SGX-reth verifiers.
- **Actions 3–6**: rotate the trusted RISC0 image IDs — untrust the two live raiko2 v0.5.1
  IDs, trust the two new ones.
- **Actions 7–14**: rotate the trusted SP1 program vkeys — untrust the four live raiko2 v0.5.1
  vkeys, trust the four new ones.
- **Action 15**: upgrade `Inbox` to a new implementation with forced inclusions re-enabled and
  the new `ZkRequiredVerifier` baked in as its immutable proof verifier.
- **Action 16**: call `Inbox.init3()` to void the stale forced inclusion queue entry left over
  from the incident window.

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
   ATTRIBUTES pin. Both deploy with **admin.taiko.eth as initial owner and registrar** (24h
   instance validity delay, as in Proposal0017); ownership moves to the DAO controller via
   `transferOwnership` (manual) + `acceptOwnership` (actions 1–2). The attestation immutable
   points at the upstream entrypoint, and **both flavors share the single entrypoint** (the old
   setup needed one attester per flavor only because the allowlists lived in the attester; they
   now live in each verifier). The contracts are identical: each becomes geth- or reth-flavored
   through the `ZkRequiredVerifier` slot it occupies, the measurements trusted on it, and the
   raiko instances that register on it.
3. **`ZkRequiredVerifier`** wiring both new SGX verifiers + the reused RISC0/SP1 verifiers.

#### Trust configuration and registration (manual, pre-execution)

The new verifiers deploy
fail-closed: with empty allowlists, `registerInstance` reverts for every quote. Unlike
Proposal0017, the trust configuration is **not** part of the proposal — admin.taiko.eth, as
initial owner, performs it manually on each verifier before execution:

1. `setMrEnclave(mrEnclave, true)` for each raiko measurement of the matching flavor;
2. `setEnclaveAttributePolicy(mrEnclave, mask, expected)` for each trusted MRENCLAVE
   (registration fails closed for any MRENCLAVE without a policy);
3. `setMrSigner(mrSigner, true)` for the raiko signing identity;
4. `registerInstance(rawQuote)` with a fresh raiko quote of the matching flavor, verified
   through the **new upstream attestation entrypoint**. Because the multisig is still the
   _owner_ at this point, these registrations skip the 24h `instanceValidityDelay` and are
   usable immediately (the delay applies only to registrar, i.e. non-owner, registrations);
5. `transferOwnership(DAO controller)` on both verifiers.

The measurement values must be verified against the raiko release shipping with Unzen at
configuration time (the SGX images may be rebuilt alongside the rotated ZK images below); they
are deliberately not constants of this proposal.

**Ownership acceptance (actions 1–2).** The proposal completes the handover with
`acceptOwnership()` on both verifiers. `SgxVerifier` is `Ownable2Step`, so these actions revert
unless step 5 above has happened — the proposal **cannot execute** while the
MRENCLAVE/MRSIGNER trust boundary still sits with the multisig. After execution the DAO
controller owns both trust registries; admin.taiko.eth keeps only the registrar role (delayed,
policy-constrained instance registration). Should registration still be pending at execution,
the `RISC0 + SP1` combination keeps proving alive — the SGX+ZK combinations become available
once registration completes.

### 4. RISC0/SP1 proving images rotated (actions 3–14)

The raiko release shipping with Unzen rebuilds the ZK guest programs, so the trusted image set
on the (reused) `RISC0_RETH_VERIFIER` and `SP1_RETH_VERIFIER` rotates in the same bundle. The
currently trusted set is exactly the raiko2 v0.5.1 set from Proposal0017 (verified still live
on 2026-07-08 via `isImageTrusted` / `isProgramTrusted`):

| Untrusted (raiko2 v0.5.1)                     | Value                                                                |
| --------------------------------------------- | -------------------------------------------------------------------- |
| `OLD_RISC0_PROPOSAL_IMAGE_ID`                 | `0xa38d1fac63aa6a553fdb6fea01fdc96534564c31de916aaafe5f5a1dd3bb908b` |
| `OLD_RISC0_AGGREGATION_IMAGE_ID`              | `0x868b5154ae01a9a045051da2d7ba2e21d4132c7ec096da343fa24149407fefef` |
| `OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256`         | `0x007594632ec31fae9d44799b97316fcbcaa3ff6b5db268c7a5d8025b3bbb487e` |
| `OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES`    | `0x3aca319730c7eba7288f33727316fcbc551ffb5a76c9a31e4bb004b63bbb487e` |
| `OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256`      | `0x00e91cb391c22d6fd015e4c6041dbbe6efb2d8be6d4046eec28f12acba5a17bc` |
| `OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES` | `0x748e59c8708b5bf402bc98c041dbbe6e7d96c5f335011bbb051e25593a5a17bc` |

The new IDs (`NEW_RISC0_*`, `NEW_SP1_*`) are **TODO** in
[`Proposal0019.s.sol`](./Proposal0019.s.sol) until the release is cut; the build reverts while
they are zero.

The rotation is atomic with the rest of the bundle: from the execution block onward, proofs
aggregated under the old images no longer verify. Operationally, two raiko2 services (old and
new image sets) run in parallel before execution, and the prover's raiko endpoint must be
switched to the new-image service at execution time (see
[Client Rollout Prerequisite](#client-rollout-prerequisite)).

### 5. Stale forced inclusion queue voided (`init3`)

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

1. `SGXGETH_VERIFIER_NEW.acceptOwnership()`
2. `SGXRETH_VERIFIER_NEW.acceptOwnership()`
3. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_PROPOSAL_IMAGE_ID, false)`
4. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_AGGREGATION_IMAGE_ID, false)`
5. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_PROPOSAL_IMAGE_ID, true)`
6. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_AGGREGATION_IMAGE_ID, true)`
7. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256, false)`
8. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)`
9. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256, false)`
10. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)`
11. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256, true)`
12. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)`
13. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256, true)`
14. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)`
15. Upgrade `L1.INBOX` to `MAINNET_INBOX_NEW_IMPL`.
16. Call `Inbox.init3()`.

The order matters: the `acceptOwnership` actions come first so the proposal fails immediately
unless admin.taiko.eth has completed the manual trust configuration and handed over ownership;
`init3` only exists on the new implementation, so it follows the upgrade. All actions execute
atomically within the proposal, so no forced inclusion can be saved between the upgrade and the
void, and there is no block in which the inbox routes proofs through the new verifiers while
they are still admin-owned, nor one in which both old and new ZK image sets are trusted.

## Production Addresses

| Constant              | Address                                      | Notes                                                                                  |
| --------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------- |
| `L1.INBOX`            | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | Shasta Inbox proxy                                                                     |
| `RISC0_RETH_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | RISC0 verifier (reused)                                                                |
| `SP1_RETH_VERIFIER`   | `0x73A0Db393ef87ce781ac7957bE10D6628432100F` | SP1 verifier (Proposal0017, reused)                                                    |
| —                     | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` | old SGX-geth verifier (Proposal0017) — **retired**, replaced by `SGXGETH_VERIFIER_NEW` |
| —                     | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` | old SGX-reth verifier (Proposal0017) — **retired**, replaced by `SGXRETH_VERIFIER_NEW` |
| —                     | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` | old SGX-geth attester proxy — **retired**, replaced by `DCAP_ATTESTATION`              |
| —                     | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` | old SGX-reth attester proxy — **retired**, replaced by `DCAP_ATTESTATION`              |

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
> Then fill this table, the address constants **and the `NEW_RISC0_*` / `NEW_SP1_*` image IDs
> from the Unzen raiko release** in [`Proposal0019.s.sol`](./Proposal0019.s.sol), and
> regenerate `Proposal0019.action.md` (`P=0019 pnpm proposal`). The script reverts while any of
> these constants are zero.
>
> Before the proposal executes, admin.taiko.eth must complete the manual sequence on both SGX
> verifiers: `setMrEnclave` → `setEnclaveAttributePolicy` → `setMrSigner` →
> `registerInstance` → `transferOwnership(DAO controller)` (see
> [Trust configuration and registration](#trust-configuration-and-registration-manual-pre-execution)).

| Constant                 | Address | Contract                                                 |
| ------------------------ | ------- | -------------------------------------------------------- |
| `DCAP_ATTESTATION`       | TBD     | `AutomataDcapAttestationFee` (upstream, non-upgradeable) |
| `SGXGETH_VERIFIER_NEW`   | TBD     | `SecureSgxVerifier` (`ZkRequiredVerifier` immutable)     |
| `SGXRETH_VERIFIER_NEW`   | TBD     | `SecureSgxVerifier` (`ZkRequiredVerifier` immutable)     |
| `ZK_REQUIRED_VERIFIER`   | TBD     | `ZkRequiredVerifier` (`MainnetInbox` immutable)          |
| `MAINNET_INBOX_NEW_IMPL` | TBD     | `MainnetInbox` implementation                            |

## Client Rollout Prerequisite

Once the due-check is live, a proposer running software that always sends
`numForcedInclusions = 0` will have `propose()` revert whenever a forced inclusion has been
pending longer than 576s. The queue is empty immediately after `init3`, so the risk window opens
with the first post-fork `saveForcedInclusion` call. Proposer software supporting forced
inclusion consumption, and raiko capacity for one ZK proof per proven batch, must both be in
production before this proposal executes.

The ZK image rotation adds a second prerequisite: a raiko2 service running the **new** image
set must be deployed alongside the current (v0.5.1) one before execution, and the prover's
raiko endpoint must be switched to it at execution time. Any proof aggregated under the old
images that has not landed on L1 by execution is discarded and must be re-proven with the new
images.

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
   # owner must be the admin multisig (0x9CBeE534...) until the handover; registrar likewise
   cast call <SGX_VERIFIER> "owner()(address)" --rpc-url <RPC_URL>
   cast call <SGX_VERIFIER> "registrar()(address)" --rpc-url <RPC_URL>
   # fail-closed enclave policy enforced
   cast call <SGX_VERIFIER> "checkLocalEnclaveReport()(bool)" --rpc-url <RPC_URL>
   # upstream entrypoint verification fee must be zero (registerInstance is non-payable)
   cast call <DCAP_ATTESTATION> "getBp()(uint16)" --rpc-url <RPC_URL>
   ```

5. Confirm the manual admin.taiko.eth sequence completed on both new SGX verifiers — the
   proposal cannot execute before the last step, and the SGX+ZK proving paths depend on the
   others:

   ```bash
   # trust registry configured (repeat per trusted measurement / the shared signer)
   cast call <SGX_VERIFIER> "trustedUserMrEnclave(bytes32)(bool)" <MR_ENCLAVE> --rpc-url <RPC_URL>
   cast call <SGX_VERIFIER> "enclaveAttributePolicy(bytes32)(bytes16,bytes16)" <MR_ENCLAVE> --rpc-url <RPC_URL>
   cast call <SGX_VERIFIER> "trustedUserMrSigner(bytes32)(bool)" <MR_SIGNER> --rpc-url <RPC_URL>
   # raiko instance(s) registered (owner registrations are usable immediately)
   cast call <SGX_VERIFIER> "nextInstanceId()(uint256)" --rpc-url <RPC_URL>
   # ownership handover initiated: pendingOwner must be the DAO controller
   cast call <SGX_VERIFIER> "pendingOwner()(address)" --rpc-url <RPC_URL>
   ```

6. Confirm the `NEW_RISC0_*` / `NEW_SP1_*` constants match the Unzen raiko release artifacts,
   and that the raiko2 service running the new images is deployed alongside the v0.5.1 one.

7. Confirm the forced inclusion queue state is still `head=2, tail=3` (nothing can change it —
   saves are hard-disabled and consumption requires `numForcedInclusions > 0`, which reverts):

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f "getForcedInclusionState()(uint48,uint48)" --rpc-url <RPC_URL>
   ```

8. Confirm the Inbox reinitializer version is `2` (`init2` consumed by Proposal0017, `init3`
   available):

   ```bash
   cast storage 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f 0 --rpc-url <RPC_URL>
   ```

   Expected: `0x...02`.

9. Confirm proposer/prover client releases supporting forced inclusions and per-batch ZK proving
   are deployed in production.

10. Generate calldata:

    ```bash
    P=0019 pnpm proposal
    ```

11. Dryrun on L1:

    ```bash
    P=0019 pnpm proposal:dryrun:l1
    ```

After execution:

1. Confirm the Inbox proxy implementation is `MAINNET_INBOX_NEW_IMPL`.
2. Confirm `getForcedInclusionState()` returns `head == tail == 3`.
3. Confirm `getConfig().proofVerifier` returns `ZK_REQUIRED_VERIFIER`.
4. Confirm `saveForcedInclusion` accepts a fee-paying submission (no longer reverts with
   `ForcedInclusionsDisabled`).
5. Confirm the ownership handover completed: `owner()` on both new SGX verifiers returns the
   DAO controller (`0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`) and `pendingOwner()` is zero.
6. Confirm the ZK image rotation took effect: `isImageTrusted` returns false for both
   `OLD_RISC0_*` IDs and true for both `NEW_RISC0_*` IDs; `isProgramTrusted` returns false for
   all four `OLD_SP1_*` vkeys and true for all four `NEW_SP1_*` vkeys.
7. **Switch the prover's raiko endpoint** (k8s config) to the raiko2 service running the new
   images — proofs from the v0.5.1 images no longer verify.
8. Confirm proving continues: the next `prove()` transactions must carry two sub-proofs including
   at least one of RISC0/SP1; an SGX_GETH + SGX_RETH pair must now revert with
   `CV_VERIFIERS_INSUFFICIENT`.
9. Follow-up cleanup PR (post-execution): remove the now-retired `MainnetVerifier` contract and
   the old SGX verifier/attester constants from `LibL1Addrs` — kept until execution so the live
   contracts remain rebuildable/verifiable from main and a rollback path exists.

## Security Contacts

- security@taiko.xyz
