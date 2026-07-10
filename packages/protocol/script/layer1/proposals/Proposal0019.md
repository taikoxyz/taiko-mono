# PROPOSAL-0019: Unzen Hardfork — Re-enable Forced Inclusions and Mandate ZK Proofs

## Executive Summary

This proposal activates the Unzen hardfork on L1. It re-enables the forced inclusion mechanism
that was disabled as part of the June 2026 incident response, replaces the proof verifier so
that every proven batch must include at least one ZK proof, and rotates the trusted RISC0/SP1
proving images to the raiko release shipping with Unzen.

The SGX verifiers are the ones Proposal0017 deployed, reused unchanged. This proposal does not
deploy new SGX verifier contracts, register SGX instances, or transfer ownership. It does rotate
the trusted SGX MRENCLAVE allowlist on the existing attester proxies to the raiko release shipping
with Unzen; the trusted MRSIGNER remains unchanged (see
[SGX verifiers reused](#3-sgx-verifiers-reused-from-proposal0017)).

It executes **20 L1 actions** and **no L2 actions**:

- **Actions 1–4**: rotate the trusted RISC0 image IDs — untrust the two live raiko2 v0.5.1
  IDs, trust the two new ones.
- **Actions 5–12**: rotate the trusted SP1 program vkeys — untrust the four live raiko2 v0.5.1
  vkeys, trust the four new ones.
- **Actions 13–18**: rotate the trusted SGX MRENCLAVE values on the reused Proposal0017 attesters.
  The MRSIGNER allowlist is unchanged.
- **Action 19**: upgrade `Inbox` to a new implementation with forced inclusions re-enabled and
  the new `ZkRequiredVerifier` baked in as its immutable proof verifier.
- **Action 20**: call `Inbox.init3()` to void the stale forced inclusion queue entry left over
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

- SGX-geth prover diversity is preserved: both SGX flavors participate, through the verifiers
  Proposal0017 deployed. The forbidden pair is SGX_GETH + SGX_RETH (zero ZK) — the exact
  combination that finalized the June 2026 forged proofs.
- Proving survives a total SGX outage via the RISC0 + SP1 combination.
- `ZkRequiredVerifier` is an existing, in-repo compose contract — no new policy code was written.

Because `Inbox` stores its proof verifier as an immutable, the verifier swap requires the new
implementation; it cannot be set by calldata.

### 3. SGX verifiers reused from Proposal0017

The SGX slots in `ZkRequiredVerifier` are the verifiers Proposal0017 deployed:

- SGX-geth: `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee`
- SGX-reth: `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8`

No new SGX contract is deployed, so the bundle deploys exactly two contracts:
`ZkRequiredVerifier`, and the `MainnetInbox` implementation that bakes it in as an immutable.

The reused SGX verifiers keep pointing at the Proposal0017 attester proxies:

- SGX-geth attester: `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`
- SGX-reth attester: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`

Three properties, each read from mainnet, define the SGX scope:

1. **Ownership is already where it belongs.** `owner()` on both verifiers, and on both attester
   proxies, returns the DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`;
   `pendingOwner()` is zero on both. There is no handover to accept.
2. **MRENCLAVE and MRSIGNER live on the attester proxies, not on the verifiers.** The trusted
   MRSIGNER is already the post-incident signer from Proposal0017 and remains trusted on both
   attesters:

   | Read                                           | Result |
   | ---------------------------------------------- | ------ |
   | `0x0ffa4A62….trustedUserMrSigner(0x48fa5bba…)` | `true` |
   | `0x8d7C9549….trustedUserMrSigner(0x48fa5bba…)` | `true` |

3. **Each verifier has one registered instance, and this proposal does not touch it.**
   `nextInstanceId()` is `1` on each verifier — one instance apiece, `validSince = 1782741203`
   (2026-06-29) against an `INSTANCE_EXPIRY` of 31536000s, so both remain valid until roughly
   2027-06-29.

   The MRENCLAVE allowlist is consulted **only at registration time**, inside the attester's
   `verifyParsedQuote`. The deployed `verifyProof` reads none of it:

   ```solidity
   require(_isInstanceValid(id, instance), SGX_INVALID_INSTANCE());   // addr match + expiry window
   require(instance == ECDSA.recover(signatureHash, signature), SGX_INVALID_PROOF());
   ```

   Two consequences follow, and neither is addressed here:
   - **Trusting a new MRENCLAVE does not register an instance.** `registerInstance` is
     registrar-gated (admin.taiko.eth), and the attester rejects a quote whose MRENCLAVE is not
     yet trusted — which only becomes true at execution. So the raiko2 instances must be
     registered _after_ this proposal lands. Until then no raiko2 enclave can produce an accepted
     SGX sub-proof, and proving leans on the `RISC0 + SP1` combination, which `ZkRequiredVerifier`
     accepts. There is no halt.
   - **Untrusting an MRENCLAVE does not revoke an instance already registered under it.** The
     deployed `Instance` struct is `(address addr, uint64 validSince)` — no MRENCLAVE is stored,
     so `verifyProof` has nothing to re-check. The pre-Unzen instance therefore remains a fully
     accepted SGX signer until `validSince + INSTANCE_EXPIRY` (~2027-06-29), even though its
     measurement is untrusted by actions 13–15 above. Whether its enclave can still derive the
     hash the `Inbox` demands is an off-chain question; on-chain, nothing stops it. Retiring it
     requires `deleteInstances`, which is `onlyOwner` and so must come from the DAO.
     **That is deliberately out of scope for this proposal** and is left to a follow-up.

The proposal rotates only MRENCLAVE trust on those existing attesters:

| Attester | Untrusted MRENCLAVE                                                  |
| -------- | -------------------------------------------------------------------- |
| SGX-geth | `0xbefb2c7ec44cefe57f4ff0ca815a8b8f15e05631bf3abe36cbc12d28f778fa36` |
| SGX-reth | `0xdccd8f30ea4a137ddfa63d743e3aa7c7a8e80585912d19c4b66f7d8d6098bec4` |
| SGX-reth | `0x92dd96a170d1ffb998afa210b3ef8af8c408ab76c4717e0eb8076d4a5da4e740` |

The replacement `NEW_SGXGETH_MR_ENCLAVE`, `NEW_SGXRETH_NON_EDMM_MR_ENCLAVE`, and
`NEW_SGXRETH_EDMM_MR_ENCLAVE` constants are TODO placeholders until the Unzen raiko SGX release
is cut. No SGX ATTRIBUTES policy is configured here because this proposal is not migrating to
`SecureSgxVerifier`; the deployed Proposal0017 attester proxies expose only the existing
MRENCLAVE/MRSIGNER allowlist interface used by `setMrEnclave(bytes32,bool)`.

Deploying the hardened `SecureSgxVerifier` against these attester proxies is not possible:
`SgxVerifier.registerInstance` calls `IDcapAttestation.verifyAndAttestOnChain(bytes)` (selector
`0x38d8480a`), which the deployed attester implementations do not export — they expose
`verifyParsedQuote(...)` (`0x089a168f`) instead. Reaching that interface requires the upstream
Automata entrypoint, which reads Intel collateral from an on-chain PCCS router that Automata does
not maintain on Ethereum mainnet. That migration is a separate change, once mainnet PCCS exists.

### 4. RISC0/SP1 proving images rotated (actions 1–12)

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

1. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_PROPOSAL_IMAGE_ID, false)`
2. `RISC0_RETH_VERIFIER.setImageIdTrusted(OLD_RISC0_AGGREGATION_IMAGE_ID, false)`
3. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_PROPOSAL_IMAGE_ID, true)`
4. `RISC0_RETH_VERIFIER.setImageIdTrusted(NEW_RISC0_AGGREGATION_IMAGE_ID, true)`
5. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256, false)`
6. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)`
7. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256, false)`
8. `SP1_RETH_VERIFIER.setProgramTrusted(OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)`
9. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256, true)`
10. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)`
11. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256, true)`
12. `SP1_RETH_VERIFIER.setProgramTrusted(NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)`
13. `SGXGETH_ATTESTER.setMrEnclave(OLD_SGXGETH_MR_ENCLAVE, false)`
14. `SGXRETH_ATTESTER.setMrEnclave(OLD_SGXRETH_NON_EDMM_MR_ENCLAVE, false)`
15. `SGXRETH_ATTESTER.setMrEnclave(OLD_SGXRETH_EDMM_MR_ENCLAVE, false)`
16. `SGXGETH_ATTESTER.setMrEnclave(NEW_SGXGETH_MR_ENCLAVE, true)`
17. `SGXRETH_ATTESTER.setMrEnclave(NEW_SGXRETH_NON_EDMM_MR_ENCLAVE, true)`
18. `SGXRETH_ATTESTER.setMrEnclave(NEW_SGXRETH_EDMM_MR_ENCLAVE, true)`
19. Upgrade `L1.INBOX` to `MAINNET_INBOX_NEW_IMPL`.
20. Call `Inbox.init3()`.

The order matters: `init3` only exists on the new implementation, so it follows the upgrade. All
actions execute atomically within the proposal, so no forced inclusion can be saved between the
upgrade and the void, and there is no block in which both the old and the new ZK image IDs or SGX
MRENCLAVE values are trusted.

## Production Addresses

| Constant              | Address                                      | Notes                                                            |
| --------------------- | -------------------------------------------- | ---------------------------------------------------------------- |
| `L1.INBOX`            | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | Shasta Inbox proxy                                               |
| `RISC0_RETH_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | RISC0 verifier (reused)                                          |
| `SP1_RETH_VERIFIER`   | `0x73A0Db393ef87ce781ac7957bE10D6628432100F` | SP1 verifier (Proposal0017, reused)                              |
| `SGXGETH_VERIFIER`    | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` | SGX-geth verifier (Proposal0017, reused)                         |
| `SGXRETH_VERIFIER`    | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` | SGX-reth verifier (Proposal0017, reused)                         |
| —                     | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` | SGX-geth attester proxy — MRENCLAVE/MRSIGNER registry, DAO-owned |
| —                     | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` | SGX-reth attester proxy — MRENCLAVE/MRSIGNER registry, DAO-owned |
| —                     | `0x71808449A6217898d602c1a392D95b931Ac5d878` | `MainnetVerifier` — **retired** by action 19                     |

RISC0/SP1 addresses were read live from the current `MainnetVerifier` (`risc0RethVerifier()`,
`sp1RethVerifier()`) and cross-checked against the Proposal0017 address table.

## Deployed Addresses

Deployed in a single step with
`FOUNDRY_PROFILE=layer1 forge script DeployUnzenContracts ...`:

| Constant                 | Address                                      | Contract                                        |
| ------------------------ | -------------------------------------------- | ----------------------------------------------- |
| `ZK_REQUIRED_VERIFIER`   | `0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec` | `ZkRequiredVerifier` (`MainnetInbox` immutable) |
| `MAINNET_INBOX_NEW_IMPL` | `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` | `MainnetInbox` implementation                   |

Both are verified on-chain: `ZK_REQUIRED_VERIFIER` returns the four production sub-verifiers (and
`address(0)` for `tdxGethVerifier()` / `opVerifier()`), matching the outgoing `MainnetVerifier`
getter-for-getter, and `MAINNET_INBOX_NEW_IMPL.getConfig().proofVerifier` equals
`ZK_REQUIRED_VERIFIER`.

> **TODO(unzen):** the `NEW_RISC0_*` / `NEW_SP1_*` image IDs and `NEW_SGX*_MR_ENCLAVE` values in
> [`Proposal0019.s.sol`](./Proposal0019.s.sol) are still `bytes32(0)`, pending the Unzen raiko
> release. Fill them, then regenerate `Proposal0019.action.md` (`P=0019 pnpm proposal`). The
> script reverts with `ZkImageIdNotSet()` or `SgxMrEnclaveNotSet()` while any of them is zero.

## Client Rollout Prerequisite

Once the due-check is live, a proposer running software that always sends
`numForcedInclusions = 0` will have `propose()` revert whenever a forced inclusion has been
pending longer than 576s. The queue is empty immediately after `init3`, so the risk window opens
with the first post-fork `saveForcedInclusion` call. Proposer software supporting forced
inclusion consumption, and raiko capacity for one ZK proof per proven batch, must both be in
production before this proposal executes.

The ZK/SGX image rotation adds a second prerequisite: a raiko2 service running the **new** image
set and SGX enclaves must be deployed alongside the current (v0.5.1) one before execution, and the
prover's raiko endpoint must be switched to it at execution time. Any proof aggregated under the
old images that has not landed on L1 by execution is discarded and must be re-proven with the new
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

3. Confirm `ZK_REQUIRED_VERIFIER` wires the four production sub-verifiers. `sgxGethVerifier()` and
   `sgxRethVerifier()` must return the **reused Proposal0017 verifiers**, and all four must equal
   what the outgoing `MainnetVerifier` (`0x71808449…`) returns for the same getters — that
   equality is what proves this swap only narrows the accepted combinations:

   ```bash
   cast call <ZK_REQUIRED_VERIFIER> "sgxGethVerifier()(address)" --rpc-url <RPC_URL>   # 0x41e79EB4…
   cast call <ZK_REQUIRED_VERIFIER> "sgxRethVerifier()(address)" --rpc-url <RPC_URL>   # 0x9D3C595B…
   cast call <ZK_REQUIRED_VERIFIER> "risc0RethVerifier()(address)" --rpc-url <RPC_URL> # 0x059dAF31…
   cast call <ZK_REQUIRED_VERIFIER> "sp1RethVerifier()(address)" --rpc-url <RPC_URL>   # 0x73A0Db39…
   ```

4. Confirm both reused SGX verifiers and both attester proxies are DAO-owned and live:

   ```bash
   # both must return the DAO controller 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a
   cast call 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee "owner()(address)" --rpc-url <RPC_URL>
   cast call 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8 "owner()(address)" --rpc-url <RPC_URL>
   # both must return 1 — one registered, unexpired raiko instance each
   cast call 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee "nextInstanceId()(uint256)" --rpc-url <RPC_URL>
   cast call 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8 "nextInstanceId()(uint256)" --rpc-url <RPC_URL>
   # attester proxies must also be DAO-owned
   cast call 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261 "owner()(address)" --rpc-url <RPC_URL>
   cast call 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3 "owner()(address)" --rpc-url <RPC_URL>
   ```

5. Confirm the `NEW_RISC0_*` / `NEW_SP1_*` / `NEW_SGX*_MR_ENCLAVE` constants match the Unzen raiko
   release artifacts, and that the raiko2 service running the new images is deployed alongside the
   v0.5.1 one.

6. Confirm the forced inclusion queue state is still `head=2, tail=3` (nothing can change it —
   saves are hard-disabled and consumption requires `numForcedInclusions > 0`, which reverts):

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f "getForcedInclusionState()(uint48,uint48)" --rpc-url <RPC_URL>
   ```

7. Confirm the Inbox reinitializer version is `2` (`init2` consumed by Proposal0017, `init3`
   available):

   ```bash
   cast storage 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f 0 --rpc-url <RPC_URL>
   ```

   Expected: `0x...02`.

8. Confirm proposer/prover client releases supporting forced inclusions and per-batch ZK proving
   are deployed in production.

9. Generate calldata:

   ```bash
   P=0019 pnpm proposal
   ```

10. Dryrun on L1:

    ```bash
    P=0019 pnpm proposal:dryrun:l1
    ```

After execution:

1. Confirm the Inbox proxy implementation is `MAINNET_INBOX_NEW_IMPL`.
2. Confirm `getForcedInclusionState()` returns `head == tail == 3`.
3. Confirm `getConfig().proofVerifier` returns `ZK_REQUIRED_VERIFIER`.
4. Confirm `saveForcedInclusion` accepts a fee-paying submission (no longer reverts with
   `ForcedInclusionsDisabled`).
5. Confirm the ZK image rotation took effect: `isImageTrusted` returns false for both
   `OLD_RISC0_*` IDs and true for both `NEW_RISC0_*` IDs; `isProgramTrusted` returns false for
   all four `OLD_SP1_*` vkeys and true for all four `NEW_SP1_*` vkeys.
6. Confirm the SGX MRENCLAVE rotation took effect: `trustedUserMrEnclave` returns false for the
   three `OLD_SGX*_MR_ENCLAVE` values and true for the three `NEW_SGX*_MR_ENCLAVE` values.
7. **Register the raiko2 SGX instances.** admin.taiko.eth (the registrar) calls `registerInstance`
   on each verifier with a fresh raiko2 quote of the matching flavor. This cannot be done before
   execution — the attester rejects a quote whose MRENCLAVE is not yet trusted. Until it lands,
   no raiko2 enclave can produce an accepted SGX sub-proof and proving leans on `RISC0 + SP1`.
8. **Switch the prover's raiko endpoint** (k8s config) to the raiko2 service running the new
   images — proofs from the v0.5.1 images no longer verify.
9. Confirm proving continues: the next `prove()` transactions must carry two sub-proofs including
   at least one of RISC0/SP1; an SGX_GETH + SGX_RETH pair must now revert with
   `CV_VERIFIERS_INSUFFICIENT`.
10. Follow-up: retire the pre-Unzen SGX instances. `deleteInstances([0])` on each verifier
    (`onlyOwner`, so a DAO action) removes the raiko1 enclave keys, which remain accepted signers
    until ~2027-06-29 because untrusting their MRENCLAVE does not revoke them. Sequence it after
    the raiko2 registrations above so SGX prover diversity is never lost.
11. Follow-up cleanup PR (post-execution): remove the now-retired `MainnetVerifier` contract source
    (`contracts/layer1/mainnet/MainnetVerifier.sol`) and its deploy-script wiring (the imports and
    `new MainnetVerifier(...)` calls in `DeployShastaContracts.s.sol` and
    `DeployHackRecoveryContracts.s.sol`) — kept until execution so the live contract remains
    rebuildable/verifiable from main and a rollback path exists. **Do not** remove
    `SGXGETH_VERIFIER` / `SGXRETH_VERIFIER` or the two attester addresses from `LibL1Addrs`:
    `DeployUnzenContracts` reads the verifiers from `LibL1Addrs`, and the attester proxies remain the
    live MRENCLAVE/MRSIGNER registries.

## Security Contacts

- security@taiko.xyz
