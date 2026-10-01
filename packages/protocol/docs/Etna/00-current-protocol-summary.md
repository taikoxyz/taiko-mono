# 00. The current protocol (Shasta + Unzen) as it exists on `main`

> Read this instead of the code. Every factual statement carries a `file:line` reference into the repository at commit `61d8f18` (branch `main`, read on 2026-09-30). Paths are relative to `packages/protocol/` for contracts and docs, `packages/taiko-client/` for the Go client, and `packages/taiko-client-rs/crates/` for the Rust client, unless written in full. Facts that a sub-agent found and an independent verifier re-checked are the default; the few places where the verifier disagreed are marked.
>
> Scope: what the protocol does today, what it guarantees, and exactly which of those guarantees come from an admin, a whitelist, or an L1 slot assumption. Anything Etna must remove is marked **[REMOVED IN ETNA]**. Anything Etna must reproduce permissionlessly is marked **[MUST REPLACE]**.

## Contents

1. [One-page mental model](#1-one-page-mental-model)
2. [L1: the Inbox](#2-l1-the-inbox)
3. [L1: the two whitelists](#3-l1-the-two-whitelists)
4. [L1: proof verification](#4-l1-proof-verification)
5. [L2: the Anchor](#5-l2-the-anchor)
6. [Shared: SignalService, Bridge, Vaults (frozen by R2)](#6-shared-signalservice-bridge-vaults-frozen-by-r2)
7. [Derivation: how blobs become blocks](#7-derivation-how-blobs-become-blocks)
8. [Clients: proposer, prover, driver](#8-clients-proposer-prover-driver)
9. [Preconfirmations today](#9-preconfirmations-today)
10. [Withholding today](#10-withholding-today)
11. [Everything coupled to L1 slots or epochs](#11-everything-coupled-to-l1-slots-or-epochs)
12. [Everything gated by an admin](#12-everything-gated-by-an-admin)
13. [Dead code, stale docs, and inconsistencies](#13-dead-code-stale-docs-and-inconsistencies)
14. [Glossary](#14-glossary)
15. [Sources and verification status](#15-sources-and-verification-status)

---

## 1. One-page mental model

Taiko is a based rollup: L1 (Ethereum) orders the data, L2 nodes derive blocks from that data deterministically, and a validity proof lets L1 accept the resulting state root. The unit of L1 submission is a **proposal** (formerly "batch"); the unit of L2 execution is a **block**; a proposal derives into one or more blocks.

```
                     L2 users
                        │ txs
                        ▼
   ┌──────────────── operator (whitelisted) ────────────────┐
   │  sequencer key: builds 1 block/s, signs, gossips (P2P)  │  ← "preconfirmation"
   │  proposer key:  batches blocks into blobs, propose()    │
   └───────────────┬───────────────────────────┬────────────┘
                   │ gossip                    │ propose(blobs)   one per L1 block
                   ▼                           ▼
        L2 nodes (Go / Rust driver)      L1 Inbox (proxy 0x6f21…ef1f)
        re-execute, adopt as "unsafe"    stores keccak(Proposal) in a ring buffer
                   │                           │ Proposed event
                   │   derivation (Derivation.md rules)
                   ◄───────────────────────────┘
                   │ "L1 wins": derived blocks replace conflicting preconf blocks
                   ▼
        prover (whitelisted) ─ Raiko ─► prove(commitment, [SGX|ZK, ZK])
                                               │
                                               ▼
                             Inbox.prove: finalizes range, saveCheckpoint → L1 SignalService
                                               │
                             Bridge / Vaults prove L2→L1 messages against that checkpoint
```

Three facts organise everything below:

- **Proving is finalization.** `Inbox.prove` verifies one aggregated proof over a contiguous range of proposals and immediately advances `lastFinalizedProposalId` and writes the end state root into the L1 `SignalService` (`contracts/layer1/core/impl/Inbox.sol:321-400`). There is no separate finalize step, no contest window, no tiers.
- **L1 never sees block contents.** The Inbox stores only proposal hashes and blob pointers; every rule that turns bytes into blocks lives in the off-chain derivation (`docs/Derivation.md`) and is re-executed by provers.
- **Every role is gated by an allowlist or an admin today.** Proposing requires being the `PreconfWhitelist` operator of the current 384-second epoch; proving requires `ProverWhitelist` membership; keeping the proof systems alive requires DAO and multisig actions. None of it is slashable.

---

## 2. L1: the Inbox

Contract: `contracts/layer1/core/impl/Inbox.sol` (832 lines), a UUPS proxy at mainnet `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` (`contracts/layer1/mainnet/LibL1Addrs.sol:37`). It is simultaneously the proposal ring buffer, the prover entry point, the bond ledger (`IBondManager`) and the forced-inclusion queue (`IForcedInclusionStore`) (`Inbox.sol:36`). All parameters are constructor immutables (`Inbox.sol:72-121`), so changing any of them is a new implementation behind the DAO.

### 2.1 State

- `CoreState` packs `nextProposalId`, `lastProposalBlockId`, `lastFinalizedProposalId`, `lastFinalizedTimestamp`, `lastCheckpointTimestamp` (all `uint48`) plus `lastFinalizedBlockHash` (`contracts/layer1/core/iface/IInbox.sol:83-97`).
- `_proposalHashes[id % ringBufferSize]` holds `keccak(Proposal)` (`Inbox.sol:136`, `:627-629`). Mainnet ring buffer size is `21_600`, documented as "1 proposal per L1 slot over 3 days" (`contracts/layer1/mainnet/MainnetInbox.sol:15-18`).
- A `Proposal` is `{id, timestamp, endOfSubmissionWindowTimestamp, proposer, parentProposalHash, originBlockNumber, originBlockHash, basefeeSharingPctg, DerivationSource[] sources}` (`IInbox.sol:60-79`); each `DerivationSource` is `{isForcedInclusion, BlobSlice{blobHashes[], offset, timestamp}}` (`IInbox.sol:52-57`; `contracts/layer1/core/libs/LibBlobs.sol:200-207`).
- Storage layout: 43-slot gap remains at slot 258 (`Inbox.sol:145`; `contracts/layer1/mainnet/MainnetInbox_Layout.sol:26`).

### 2.2 `propose(bytes _lookahead, bytes _data)` (`Inbox.sol:270-290`)

In execution order:

1. Decode `ProposeInput{deadline, blobReference{blobStartIndex, numBlobs, offset}, numForcedInclusions}` (`IInbox.sol:100-109`; 15-byte packed codec, `contracts/layer1/core/libs/LibCodec.sol:24-42`); `deadline == 0 || block.timestamp <= deadline` (`Inbox.sol:765`).
2. `nextProposalId > 0` (activation required) (`Inbox.sol:278`).
3. **One proposal per L1 block**: `block.number > lastProposalBlockId` (`Inbox.sol:590`), and ring buffer capacity `ringBufferSize > nextProposalId - lastFinalizedProposalId` (`Inbox.sol:591-593`).
4. **Forced inclusions are consumed before the proposer check** (`Inbox.sol:595-596`): count the contiguous prefix of the first `min(available, 10)` queue entries that are due (`block.timestamp >= entry.timestamp + forcedInclusionDelay`, `Inbox.sol:653-661`); require `numForcedInclusions >= dueToProcess` else `UnprocessedForcedInclusionIsDue` (`Inbox.sol:662-664`); process `toProcess = min(requested, available, 10)` (`Inbox.sol:666-667`); pay their ETH fees to `msg.sender` by a push `call` forwarding all gas (`Inbox.sol:710`; `contracts/shared/libs/LibAddress.sol:52-62`). Forced sources come first, the proposer's own blob slice last (`Inbox.sol:598-599`, `:669`).
5. **Proposer gate [REMOVED IN ETNA]**: `_proposerChecker.checkProposer(msg.sender, _lookahead)` returns `endOfSubmissionWindowTimestamp` (`Inbox.sol:602-603`), preceded by the comment "Permissionless proposing is temporarily disabled" (`Inbox.sol:601`). `_lookahead` is URC-era plumbing that the current checker ignores (`contracts/layer1/preconf/impl/PreconfWhitelist.sol:127-135`).
6. Bond gate only if `_minBond > 0` (`Inbox.sol:604-607`); mainnet `minBond = 0` (`MainnetInbox.sol:37`).
7. Build the proposal with `timestamp = block.timestamp`, `originBlockNumber = block.number - 1`, `originBlockHash = blockhash(block.number - 1)`, `parentProposalHash = getProposalHash(id - 1)` (`Inbox.sol:609-621`); store the hash, bump `nextProposalId`, set `lastProposalBlockId = block.number`, emit `Proposed(id, proposer, parentProposalHash, endOfSubmissionWindowTimestamp, basefeeSharingPctg, sources)` (`Inbox.sol:284-288`, `:747-756`; `IInbox.sol:169-176`).

`propose` has no `whenNotPaused` and no `tx.origin` use (`Inbox.sol:270`; grep). Every revert reason on this path and who can trigger it is listed in `03-frame-transactions-research.md` §4 claim 36.

Details a successor must know (found by the verifier of the Inbox summary):

- Forced-inclusion fees are pushed to `msg.sender` with a full-gas `call` **before** the proposer gate runs (`Inbox.sol:595-603`, `:710`); an unauthorized caller gets an external call to itself before being rejected. Safe only because the whole transaction reverts and the transient reentry lock is held.
- `_dequeueAndProcessForcedInclusions` returns `oldestTimestamp_` and `_consumeForcedInclusions` discards it (`Inbox.sol:671`, `:683-684`, `:713`); its NatSpec still says "and whether permissionless proposals are allowed" (`:635-636`). This is the stub where `permissionlessInclusionMultiplier` was meant to plug in.
- `IProposerChecker.checkProposer` is declared non-`view` (`contracts/layer1/core/iface/IProposerChecker.sol:16-21`), so a checker may mutate state during `propose` (a URC-style checker would); `PreconfWhitelist` implements it as `view`.
- `proposalAge` is computed `unchecked` from a prover-supplied timestamp (`Inbox.sol:322`, `:336`); a future timestamp underflows. Harmless only because every verifier ignores the argument.
- `saveForcedInclusion` is not `nonReentrant` and refunds with a full-gas call (`Inbox.sol:431`, `:441`); the entry is already enqueued before the refund, so this is a design note, not a bug.
- `forcedInclusionDelay` is a `uint16` (max 65,535 s ≈ 18.2 h) and `permissionlessInclusionMultiplier` a `uint8` (`IInbox.sol:41`, `:48`).
- `LibInboxSetup` and `LibForcedInclusion` expose `public` library functions, so the implementation delegatecalls into separately deployed, linked library contracts (`LibInboxSetup.sol:9-10`); a successor must deploy and link them too.
- Mainnet intent comments the code does not enforce: "internal target is still to submit every ~2 hours" (`MainnetInbox.sol:40`), "Allows the security council time to intervene if a bug is found" (`:41-42`).

### 2.3 `prove(bytes _data, bytes _proof)` = finalize (`Inbox.sol:321-400`)

1. Decode `ProveInput{Commitment}` where `Commitment = {firstProposalId, firstProposalParentBlockHash, lastProposalHash, actualProver, endBlockNumber, endStateRoot, Transition[] transitions}` and `Transition = {proposer, timestamp, blockHash}` (`IInbox.sol:112-144`). The codec bounds a proof to 65,535 transitions (`LibCodec.sol:90-92`).
2. Range validation: `transitions.length > 0`; `firstProposalId <= lastFinalized + 1`; `lastProposalId < nextProposalId`; `lastProposalId >= lastFinalized + 1`; `offset` = index of the first unfinalized proposal, so a proof may overlap already-finalized proposals (`Inbox.sol:788-811`).
3. `proposalAge = block.timestamp - transitions[offset].timestamp` (`Inbox.sol:336`); passed to the verifier only for single-proposal proofs (`Inbox.sol:395`) and read by no deployed verifier.
4. **Prover gate [REMOVED IN ETNA]**: `_checkProver(msg.sender)`: whitelist "enabled" iff the whitelist address is non-zero and `proverCount > 0`; if enabled, `msg.sender` must be whitelisted (`Inbox.sol:771-779`). The gate is on the transaction sender, not on `commitment.actualProver`, which is self-declared (`IInbox.sol:131`).
5. Continuity: the parent hash of the first newly finalized proposal must equal `lastFinalizedBlockHash`, and `commitment.lastProposalHash` must equal the ring-buffer hash of the last proposal (`Inbox.sol:343-351`).
6. Liveness bond, **only when the whitelist is not enabled** (`Inbox.sol:356-359`): deadline `= max(transitions[offset].timestamp + provingWindow, lastFinalizedTimestamp + maxProofSubmissionDelay)`; if late, debit up to `livenessBond` from `transitions[offset].proposer` (best effort), credit half to `actualProver`, leave half uncredited (`Inbox.sol:729-744`; `contracts/layer1/core/libs/LibBonds.sol:148-170`). The uncredited half stays in the contract's token balance with no owner and no sweep function.
7. **Checkpoint**: `_signalService.saveCheckpoint({blockNumber: endBlockNumber, stateRoot: endStateRoot, blockHash: transitions[last].blockHash})` (`Inbox.sol:364-370`).
8. Update `lastFinalizedProposalId`, `lastFinalizedTimestamp`, `lastFinalizedBlockHash`; emit `Proved(firstProposalId, firstNewProposalId, lastProposalId, actualProver)` (`Inbox.sol:376-387`).
9. **Last**: `_proofVerifier.verifyProof(ageOrZero, hashCommitment(commitment), _proof)`, a `view` that must revert on an invalid proof, rolling back everything above (`Inbox.sol:394-398`; `contracts/layer1/verifiers/IProofVerifier.sol:9-24`).

There is no contestation, no fraud proof, no proving "tier", and no designated prover: the address that submits is the prover (`IInbox.sol:182`).

### 2.4 Forced inclusion (`Inbox.sol:431-443`; `contracts/layer1/core/libs/LibForcedInclusion.sol`)

- Anyone posts exactly one blob containing a `DerivationSourceManifest` and calls `saveForcedInclusion(BlobReference)` with ETH; reverts until proposal 1 exists (`Inbox.sol:432-433`); exactly one blob (`LibForcedInclusion.sol:52`).
- Fee `= baseFee × (threshold + pending) / threshold` in gwei; mainnet base `0.001 ETH`, threshold `50` (`LibForcedInclusion.sol:89-93`; `MainnetInbox.sol:48-49`). Excess refunded (`Inbox.sol:439-442`).
- The request's clock starts at `block.timestamp` of the save (`LibBlobs.sol:232`); due after `forcedInclusionDelay` seconds, a `uint16` (`IInbox.sol:41`), mainnet `576 s`, commented as "1.5 epochs" (`MainnetInbox.sol:46-47`).
- Consumption rule and fee payment: §2.2 step 4. Each forced source derives to exactly one block with `coinbase = proposal.proposer` (`docs/Derivation.md:166`, `:202`).
- `permissionlessInclusionMultiplier = 160` (≈ 25.6 h) is stored and validated but **never enforced on-chain** (`Inbox.sol:121`, `:172`, `:546` are the only uses; `contracts/layer1/core/libs/LibInboxSetup.sol:41-44`); the Rust proposer implements the rule client-side and would revert at `checkProposer` if it tried (`proposer/src/proposer.rs:669-683`; `test/layer1/core/inbox/InboxPropose.t.sol:296-320` asserts the revert).
- Emergency: `init3()` (owner, `reinitializer(3)`) voided the whole queue after "the June 2026 incident during which forced inclusions were disabled" and their blobs expired (`Inbox.sol:246-258`).
- The fee paid to the consuming proposer is the fee recorded at save time, not the fee current at consumption (`Inbox.sol:706`; `LibForcedInclusion.sol:61`). Payout and refund both use a full-gas `call` that reverts the whole transaction if the recipient rejects ETH (`Inbox.sol:710`, `:441`; `LibAddress.sol:52-62`), so a contract-based proposer must accept plain ETH.

### 2.5 Bonds (`contracts/layer1/core/libs/LibBonds.sol`; `contracts/layer1/core/iface/IBondManager.sol`)

- Ledger on L1 in the Inbox, `uint64 balance` in gwei of an 18-decimal ERC-20 (TAIKO on mainnet) plus `uint48 withdrawalRequestedAt` (`IBondManager.sol:13-19`; `LibBonds.sol:18`, `:202-205`).
- `deposit` (cancels a pending withdrawal), `depositTo` (does not), `requestWithdrawal`, `cancelWithdrawal`, `withdraw` (must keep `minBond` until `withdrawalDelay` after a request) (`Inbox.sol:402-425`; `LibBonds.sol:35-115`). Mainnet `withdrawalDelay = 1 week` (`MainnetInbox.sol:39`).
- Exactly one slashing rule exists: the late-proof liveness settlement of §2.3 step 6. No bond is ever debited by proposing ("bonds remain optimistic", `docs/Derivation.md:143-144`). There is no L2 bond manager: `contracts/layer2/core/BondManager_Layout.sol` is an orphan layout with no contract.
- Mainnet: `minBond = 0`, `livenessBond = 0`, and settlement is skipped while the prover whitelist is enabled, so **no bond is at stake today** (`MainnetInbox.sol:37-38`; `Inbox.sol:356-359`).

### 2.6 Mainnet configuration (`MainnetInbox.sol:31-52`)

| Parameter | Value | Unit | Enforced? |
|---|---|---|---|
| `minBond` | 0 | gwei | check skipped when 0 |
| `livenessBond` | 0 | gwei | settlement is a no-op |
| `withdrawalDelay` | 1 week | s | yes |
| `provingWindow` | 4 hours | s | only in the (disabled) liveness settlement |
| `permissionlessProvingDelay` | 5 days | s | **never read** (`Inbox.sol:99`, `:165`, `:539` only) |
| `maxProofSubmissionDelay` | 3 minutes | s | only in the liveness settlement |
| `ringBufferSize` | 21,600 | proposals | yes |
| `basefeeSharingPctg` | 75 at the snapshot commit; 100 on `main` since Proposal0026 (`MainnetInbox.sol:45-46` at 31df8fe, checked 2026-10-01) | % | consumed by the node, not the Inbox |
| `forcedInclusionDelay` | 576 | s | yes |
| `forcedInclusionFeeInGwei` | 1,000,000 | gwei | yes |
| `forcedInclusionFeeDoubleThreshold` | 50 | pending | yes |
| `permissionlessInclusionMultiplier` | 160 | × delay | **never read** |
| `MAX_FORCED_INCLUSIONS_PER_PROPOSAL` | 10 | count | yes; "must be < 12" assumes one proposal per 12-s slot (`Inbox.sol:62-65`) |

Recovery scars from the June 2026 incident: `init2` resets the finalized pointer (`Inbox.sol:217-244`); `init3` voids forced inclusions (`Inbox.sol:253-258`).

---

## 3. L1: the two whitelists

Etna must remove both. This section states exactly what each guarantees so the design can provide the same guarantee permissionlessly.

### 3.1 `PreconfWhitelist` (`contracts/layer1/preconf/impl/PreconfWhitelist.sol`) [REMOVED IN ETNA] [MUST REPLACE]

Mainnet proxy `0xFD01…b2ac` (`LibL1Addrs.sol:38`). It is the Inbox's `IProposerChecker`.

**Roster.** Up to 255 operators (`uint8 operatorCount`, `:54`), each `{activeSince (epoch start), index, sequencerAddress}` keyed by proposer address (`:15-20`, `:49-50`). The proposer address is the on-chain identity; the sequencer address is "for off-chain use" and is never verified by any contract (`:42-48`). Added by `addOperator` (owner or an ejecter), active from the start of the epoch two epochs later (`:94-96`, `:207-231`, `OPERATOR_CHANGE_DELAY = 2`, `:26`). Removed **immediately** by `removeOperator*` (owner or ejecter), never the last active one (`:99-110`, `:237-266`). Ejecters are set by the owner or the immutable `_ejectorManager`, on mainnet the `admin.taiko.eth` multisig `0x9CBe…9C7F` (`:76-79`, `:115-124`; `LibL1Addrs.sol:66`).

**Selection.** Time is cut into 384-second epochs aligned to the beacon genesis (`contracts/layer1/preconf/libs/LibPreconfConstants.sol:347-348`, hard-coded 12 s × 32; `contracts/layer1/preconf/libs/LibPreconfUtils.sol:425-442`). The operator for epoch E is `operatorMapping[uint256(beaconRoot) % operatorCount]` where `beaconRoot` is the EIP-4788 root of the first non-missed slot of epoch E − 2, found by probing the 4788 contract in 12-second steps up to 32 times (`:275-314`; `LibPreconfUtils.sol:390-406`). A zero root selects index 0 unchecked (`:288`, `:292`). Removing an operator mid-epoch can change the selection for the rest of the epoch because of swap-and-pop (`:254-263`).

**Gate.** `checkProposer(proposer, bytes)` requires `proposer == operator(current epoch)` and returns `endOfSubmissionWindowTimestamp = 0` with the comment "Slashing is not enabled for whitelisted preconfers" (`:127-141`). Consequently every mainnet proposal carries `endOfSubmissionWindowTimestamp = 0`.

**What it guarantees today (verified):**

1. Exactly one address may land proposals in a given epoch; the assignment is a deterministic function of chain state and is publicly computable two epochs (768 s) ahead (`:144-151`).
2. Uniform selection seeded by beacon randomness that operators cannot influence.
3. Bounded churn: additions take effect ≥ 2 epochs out; removals cannot empty the set.
4. The sequencer key that signs preconfirmations belongs to a governance-admitted party.

**What it does not guarantee:** liveness (an offline operator blocks the whole epoch; there is no fallback and no penalty), any binding between preconfirmations and L1 (the sequencer address is never seen on-chain), any bond, any slashing.

Further facts (verified): a newly added operator waits between one and two epochs of wall time (active from the start of epoch E + 2 when added during E, `:176-179`, `:218`); EIP-4788 retains only 8,191 roots (about 27 h at 12-s slots), so the assignment for old epochs cannot be recomputed on-chain later (`LibPreconfUtils.sol:411-418`); all epoch timestamps are truncated to `uint32` (`:16`, `:176-179`); `latestActivationEpoch` is never lowered on removal (`:228`, `:237-266`).

**Etna must reproduce permissionlessly:** (i) a deterministic, publicly computable assignment of sequencing rights with lead time, (ii) a fallback when the assignee is silent, (iii) an economic substitute for admin trust, and (iv) none of it may use 12-second slots, 32-slot epochs, or 4788 probing in slot steps.

### 3.2 `ProverWhitelist` (`contracts/layer1/core/impl/ProverWhitelist.sol`) [REMOVED IN ETNA] [MUST REPLACE]

Mainnet proxy `0xEa79…12Ae` (`LibL1Addrs.sol:39`). A global `mapping(address => bool)` plus a count (`ProverWhitelist_Layout.sol:21-22`), edited by the owner or the immutable `_proverManager` (`admin.taiko.eth`) (`ProverWhitelist.sol:45-48`, `:74-79`). Enforced in `Inbox.prove` on `msg.sender` (§2.3 step 4). If the count drops to zero the Inbox treats the whitelist as absent and proving becomes permissionless with bonds re-enabled (`ProverWhitelist.sol:104-106`; `Inbox.sol:775`).

**What it guarantees today:** only these N addresses can finalize state, and while it is on, none of them is economically accountable on-chain (bond settlement is skipped, `Inbox.sol:356-359`). The property it was bought for is stated in the mainnet config: "Allows the security council time to intervene if a bug is found" (`MainnetInbox.sol:41`), i.e. a human in the loop before a possibly-buggy proof system finalizes state.

**Etna must reproduce:** sender-agnostic proof acceptance (already the code path when the whitelist is off), an accountable prover identity for payouts (today `actualProver` is self-declared), and a substitute for the "human in the loop" that does not depend on an admin acting in day-to-day operation.

---

## 4. L1: proof verification

Directory: `contracts/layer1/verifiers/`. The Inbox holds one immutable `IProofVerifier` (`Inbox.sol:72`, `:156`) and calls it once, last, in `prove` (§2.3 step 9).

### 4.1 Public input

`commitmentHash = keccak256(abi.encode(Commitment))` with an explicit word layout (`contracts/layer1/core/libs/LibHashOptimized.sol:32-80`). Each leaf verifier then hashes `("VERIFY_PROOF", chainId, leafVerifierAddress, commitmentHash, proofSigner)` (`contracts/layer1/verifiers/LibPublicInput.sol:95-113`); `proofSigner` is the SGX instance address for TEE proofs and must be `address(0)` for ZK proofs (`LibPublicInput.sol:90-93`). ZK leaves additionally bind the block-proving program id into the aggregation journal (`LibPublicInput.sol:120-129`). A proof therefore commits to: chain id, one specific leaf deployment, first proposal id, parent block hash of the first proposal, hash of the last proposal, the self-declared prover, end block number, end state root, and per proposal `(proposer, timestamp, endBlockHash)`. `proposalAge` is not in the hash.

### 4.2 Composition

`ComposeVerifier.verifyProof` decodes `SubProof[]{verifierId, proof}`, requires strictly ascending non-zero ids mapped to immutable leaf addresses, calls each leaf with the same commitment hash, then applies a hard-coded rule (`contracts/layer1/verifiers/compose/ComposeVerifier.sol:59-90`). Verifier ids: `SGX_GETH=1, TDX_GETH=2, OP=3, SGX_RETH=4, RISC0_RETH=5, SP1_RETH=6` (`:13-21`; no TDX verifier exists in the repo).

- **Mainnet today: `ZkRequiredVerifier`** at `0x7284aaC0…` since Proposal0019 (Unzen, executed 2026-08-03): exactly two sub-proofs, `[SGX_GETH|SGX_RETH, RISC0|SP1]` or `[RISC0, SP1]`; SGX + SGX is structurally impossible (`compose/ZkRequiredVerifier.sol:6-13`, `:37-50`; `deployments/mainnet-contract-logs-L1.md:221-222`, `:330`).
- **Deprecated `MainnetVerifier`** accepted `SGX_GETH + SGX_RETH` with zero ZK, "the exact combination that finalized the June 2026 forged proofs" (`contracts/layer1/mainnet/MainnetVerifier.sol:8-14`). This is the most important security fact in the repository for Etna's threat model: TEE-only finalization was exploited in production.
- Leaves on mainnet: SGX-geth `0x41e7…`, SGX-reth `0x9D3C…`, RISC0 `0x059d…`, SP1 `0x73A0…` (`LibL1Addrs.sol:56-61`).

### 4.3 ZK leaves (`Risc0Verifier.sol`, `SP1Verifier.sol`)

Each rebuilds the public input, requires both the aggregation program id and the block-proving program id to be in an **owner-gated allowlist** (`Risc0Verifier.sol:16`, `:43-46`, `:62-64`; `SP1Verifier.sol:16`, `:44-47`, `:64-66`), then `staticcall`s a third-party Groth16 / PLONK verifier (RISC0 router `0x8EaB…`, SP1 gateway `0x3B60…`; `script/layer1/core/DeployShastaMainnet.s.sol:25`, `:28`). Every raiko release rotates the ids atomically in a DAO proposal; in-flight proofs under the old ids stop verifying (`script/layer1/proposals/Proposal0019.md:184-188`). Current ids: raiko2 v0.8.0-rc1 since 2026-09-21 (Proposal0021).

### 4.4 TEE leaves (`SgxVerifier.sol`, `SecureSgxVerifier.sol`)

An SGX proof is 89 bytes `instanceId(4) || instance(20) || ecdsaSig(65)`; validity is `ECDSA.recover(publicInput) == instance` for a registered, unexpired, still-trusted instance (`SgxVerifier.sol:459-480`, `:591-604`). Registration verifies an Intel DCAP quote through Automata's `IDcapAttestation`, pins MRENCLAVE/MRSIGNER allowlists and attribute policies (all owner-set), and on mainnet is gated on the immutable registrar `admin.taiko.eth` (`:316-456`; `script/layer1/mainnet/DeployHackRecoveryContracts.s.sol:83-101`). The owner can also add an arbitrary EOA as an instance with no attestation (`addInstances`, `:224-232`), so the TEE leg is ultimately "owner-honest". The bytecode live on mainnet predates the `main` source (365-day expiry, allowlists on separate attester proxies; `Proposal0019.md:103-127`).

**Admin gates in day-to-day proving (all [REMOVED IN ETNA] as operational gates; proof-system upgrades by DAO remain acceptable):** image-id rotation (DAO), MRENCLAVE rotation (DAO), SGX instance registration (multisig), prover whitelist edits (multisig). Only the composition rule and the Inbox binding are admin-free at runtime.

Facts a successor verifier design must carry (found by the verifier of the verifiers summary):

- **A codeless remote verifier accepts everything.** `Risc0Verifier` and `SP1Verifier` check only the `success` flag of a `staticcall`; a call to an address with no code succeeds, so if the immutable remote verifier address were ever an EOA, self-destructed, or wrong, every proof with trusted ids would pass (`Risc0Verifier.sol:33`, `:77-80`; `SP1Verifier.sol:34`, `:76-83`). The remote verifier addresses are a hard trust anchor.
- `ComposeVerifier` decides sufficiency by leaf **address** equality, not by id; a subclass wired with the same address in two slots would let one leaf satisfy a "two systems" rule (`ComposeVerifier.sol:85`, `:107-111`).
- Deleted SGX instances can never re-register the same key (`addressRegistered` is never cleared, `SgxVerifier.sol:245`, `:569-571`); on mainnet the registrar gate precedes the owner check, so the owner's delay bypass is unreachable (`:319`, `:455`); registration forwards `{value: 0}` to a `payable` attester, so a fee-enabled attester would brick registration (`:332-335`).
- No leaf verifier reads `block.number`, slots, or `tx.origin`; the only block-based assumption is the 256-block `blockhash` window for permissionless SGX registration (`:431-447`).

### 4.5 What the ZK guest actually proves (gap fill G4, `notes/phase1-gap-G4.md`)

The on-chain `prove` checks only the ring-buffer hash of the last proposal and the parent-hash link (§2.3 steps 5); every other field is bound only through `hashCommitment`. The RISC0/SP1 proposal guest (`taikoxyz/raiko2` at tag `v0.8.0-rc1`, the commit Proposal0021 rotated the mainnet image ids to) proves, per proposal: the KZG versioned hashes of the supplied blobs equal the proposal's `blobHashes`; applying the Shasta derivation rules (the Rust `taiko-client-protocol` crate compiled into the guest) to those blobs under the supplied `Proposal` struct yields a block list; executing each block on the witnessed parent state, dropping invalid transactions, yields exactly the supplied L2 blocks; every block's first transaction is the canonical golden-touch `anchorV4` whose checkpoint is a real header in an L1 hash chain ending at `originBlockHash`; and the journal equals the on-chain public-input recipe. The aggregation guest chains N such receipts and rebuilds the `Commitment`.

Trust boundary (what is **not** proven): the guest does not prove the `Proposed` event exists on L1; authenticity rests on `hashProposal` covering `timestamp`, `originBlockNumber`, `originBlockHash` and every blob hash, plus the ring-buffer equality (raiko2 states this explicitly). `actualProver` is a free choice of the prover. The chain-id list, fork schedule, predeploy addresses, the Anchor's `_blockState` slot and the L2 SignalService checkpoint slot are compiled into the guest; a mismatch with deployed contracts is a liveness failure, or a soundness failure if the guest rule is weaker. Trusted image ids are owner-rotated and cannot be tied to source without a rebuild. The Go prover never checks the proof's public input; disagreement surfaces only as an on-chain revert. **For Etna:** a landing that finalizes without an exact ring-buffer match (there is no prior proposal record under propose-with-proof) must bind the batch's L1 identity inside the public input instead, and every compiled-in constant is an upgrade-coupling hazard between guest, contracts and clients.

---

## 5. L2: the Anchor

Contract: `contracts/layer2/core/Anchor.sol` (240 lines), a UUPS proxy predeploy at `0x1670000000000000000000000000000000010001` (`contracts/layer2/mainnet/LibL2Addrs.sol:9`), owned on L2 by the `DelegateController`, which executes DAO actions relayed over the Bridge (`contracts/layer2/governance/DelegateController.sol:40-52`).

- Every L2 block's first transaction is `anchorV4(Checkpoint{blockNumber, blockHash, stateRoot})` from the **golden touch** account `0x0000777735367b36bC9B61C50022d9D0700dB4Ec`, whose private key is public and embedded in every client; signing uses a fixed ECDSA nonce so every node produces byte-identical anchor transactions (`Anchor.sol:37`, `:86-89`, `:124-128`; `driver/anchor_tx_constructor/anchor_tx_constructor.go:31`, `:123-139`; `protocol/src/signer.rs:20-21`).
- The contract recomputes a keccak over the previous 255 L2 block hashes plus chain id and requires it to equal the value stored by the previous block's anchor, which forces exactly one successful anchor per consecutive block once bootstrapped (`:173-179`, `:194-229`). It records `blockHashes[parent] = blockhash(parent)` (`:132-133`).
- If `checkpoint.blockNumber > _blockState.anchorBlockNumber`, it forwards the checkpoint to the L2 `SignalService` via `ICheckpointStore.saveCheckpoint` and updates the number (`:182-185`). Equal or lower numbers are silently ignored. **Nothing on-chain checks that `blockHash`/`stateRoot` are the real L1 values**; correctness rests on the off-chain derivation rule (`docs/Derivation.md:238-240`) and, ultimately, on the L1 proof of that L2 block.
- Nothing else is validated: no proposal id, block index, timestamp, base fee, proposer or prover identity (`_lastProposalId` is deprecated, `:65-66`). `ANCHOR_GAS_LIMIT = 1_000_000` is declared "must be enforced" but is enforced by the node, not the contract (`:39-40`; `docs/Derivation.md:342-345`).
- The Anchor receives the non-coinbase share of L2 base fees (`basefeeSharingPctg = 75%` to coinbase at the snapshot commit; Proposal0026 raised it to 100 % on `main`, so the Anchor now accrues nothing new and keeps only its legacy balance); the owner can `withdraw` them (`:140-156`).
- Storage: `blockHashes` at 251, three retired Pacaya slots, deprecated `_lastProposalId` at 255, `_blockState` at 256-257, 43-slot gap (`contracts/layer2/core/Anchor_Layout.sol:21-25`).
- Verified details: the `l1ChainId` immutable is validated but never read by any logic (`:50`, `:103`); there is no owner function to reset `_blockState`, so a chain whose ancestors hash ever desynchronises is recoverable only by `upgradeTo` (`:113-115`, `:145-156`); the Anchor has no `receive()`; the Go syncer has a second calldata-decoding exception for proposal id 1 on every chain (`driver/chain_syncer/event/syncer.go:318-324`).

---

## 6. Shared: SignalService, Bridge, Vaults (frozen by R2)

Directory: `contracts/shared/`. Same code on both layers behind UUPS proxies. Mainnet addresses: L1 SignalService `0x9e0a…C77C`, Bridge `0xd602…d8EC`, ERC20/721/1155 Vaults `0x9962…15Ab` / `0x0b47…19Aa` / `0xaf14…1702` (`LibL1Addrs.sol:43-48`); L2 SignalService `0x1670…0005`, Bridge `0x1670…0001`, Vaults `0x1670…0002/3/4` (`LibL2Addrs.sol:11-17`).

### 6.1 The exact interface the rollup must satisfy

`ICheckpointStore` (`contracts/shared/signal/ICheckpointStore.sol:322-354`):

```solidity
struct Checkpoint { uint48 blockNumber; bytes32 blockHash; bytes32 stateRoot; }
function saveCheckpoint(Checkpoint calldata _checkpoint) external;   // only _authorizedSyncer
function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory);
event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);
```

- `saveCheckpoint` reverts unless `msg.sender == _authorizedSyncer`, an **immutable set in the implementation's constructor**: the Inbox proxy on L1, the Anchor proxy on L2 (`contracts/shared/signal/SignalService.sol:35-37`, `:86-93`, `:174-175`; `script/layer1/mainnet/DeployHackRecoveryContracts.s.sol:53-57`; `script/layer2/DeployShastaL2Contracts.s.sol:49-53`). Zero `stateRoot` or `blockHash` is rejected; otherwise `_checkpoints[VERSION][blockNumber] = {blockHash, stateRoot}` is written with **no monotonicity check and silent overwrite** (`:176-184`). Lookup is by exact remote block number; there is no "latest" getter (`:187-194`, `:206-218`).
- `stateRoot` must be the remote block's post-state root, because it is the root the account proof of the remote SignalService is verified against (`:284-296`).
- `VERSION = 1` namespaces both the checkpoint and received-signal mappings; bumping it in a new implementation invalidates old entries without touching old slots (`:49-52`, `:67-73`).
- Storage layout: EssentialContract prefix (slots 0-250), two dead Pacaya slots (251-252), `_receivedSignals` (253), `_checkpoints` (254), 46-slot gap (255-300) (`contracts/shared/signal/SignalService_Layout.sol:10-24`).

**Consequence for R2.** A new syncer address requires a new SignalService *implementation* (constructor arg) plus an owner `upgradeTo` on the existing proxy; the proxy address and storage are preserved. If the Etna inbox reuses the existing Inbox proxy address, the L1 SignalService needs no change at all; likewise on L2 if the Anchor proxy is upgraded in place.

Further verified facts: `saveCheckpoint` carries no pause gate, so pausing a SignalService halts proving of signals but never the anchor transaction or the Inbox (`SignalService.sol:174-177`); `_authorizedSyncer` is `internal immutable` with no getter, so the wired syncer cannot be read on-chain (`:37`); the quota manager is optional and a zero address disables rate limiting entirely (`Bridge.sol:652`; `ERC20Vault.sol:532`), and an owner `updateQuota` refills the window immediately (`QuotaManager.sol:74-77`, `:110`); `processMessage` hard-reverts if `destOwner` or the relayer cannot accept ETH within 135k gas (`Bridge.sol:395`, `:400`).

### 6.2 Signals and proofs

- `sendSignal(bytes32)` writes the signal into raw slot `keccak256(abi.encodePacked("SIGNAL", uint64 chainId, address app, bytes32 signal))` with `app = msg.sender` (`SignalService.sol:107-109`, `:160-171`, `:220-237`).
- `proveSignalReceived(chainId, app, signal, proof)` (`whenNotPaused`) decodes exactly one `HopProof{chainId, blockId, rootHash, cacheOption, accountProof, storageProof}`; requires the stored checkpoint for `blockId` to have `stateRoot == rootHash`; verifies a secure-MPT account proof of `_remoteSignalService` (immutable) and a storage proof of the slot (`:113-127`, `:253-297`; `contracts/shared/libs/LibTrieProof.sol:38-69`). **Multi-hop is rejected** (`:272`). Received signals are cached per `VERSION` (`:125`).
- Pause is `onlyFromOwnerOr(pauser)` with an immutable pauser (mainnet L1: admin multisig) (`:43`, `:201`).

### 6.3 Bridge and Vaults (unchanged by Etna; summarised for completeness)

- `Bridge.sendMessage` escrows ETH, assigns an id, hashes `("TAIKO_MESSAGE", message)` and sends the hash as a signal (`contracts/shared/bridge/Bridge.sol:217-255`, `:536-539`). `processMessage` (anyone; permissionless relayers) proves the signal from the source chain's Bridge (resolver-registered), invokes `to.onMessageInvocation(bytes)` or delivers plain ETH, pays the relayer, records a status `NEW → DONE | RETRIABLE → DONE | FAILED`, and consumes an ETH quota (`:307-404`; `contracts/shared/bridge/QuotaManager.sol:86-99`).
- Vaults escrow or burn on the source chain and release or mint on the destination, deploying bridged-token proxies on first use; `onMessageInvocation` requires the caller to be the resolver-named Bridge with a context from the peer vault (`contracts/shared/vault/ERC20Vault.sol:394-463`, `:640-658`; `contracts/shared/vault/BaseVault.sol:53-62`).
- `ForkRouter` is a delegatecall splitter used transiently during forks; it reserves slots 0-150 (`contracts/shared/fork-router/ForkRouter.sol:18-24`, `:50-57`). No concrete SignalService or Anchor router exists on `main` any more (only layout stubs).
- Day-to-day bridging depends on no admin. Admin action is needed only to register chains/tokens, change quotas, migrate bridged tokens, pause, or upgrade.

**Withholding relevance:** L2→L1 messages are provable only after the Inbox saves a checkpoint at or beyond the L2 block that sent the signal, i.e. after proof finalization (`SignalService.sol:284`); L1→L2 messages only after an anchor carries a fresh enough L1 checkpoint (`Anchor.sol:182-185`). Prover withholding or stale anchoring delays bridging indefinitely; nothing in the shared layer mitigates it.

---

## 7. Derivation: how blobs become blocks

Specification: `docs/Derivation.md` (current for Shasta, with the stale spots listed in §13). Implementations: Go `driver/chain_syncer/event/derivation/source_fetcher.go`, Rust `driver/src/derivation/pipeline/shasta/`. Provers re-execute the same rules.

1. Subscribe to `Proposed`; `proposal.timestamp` is the emitting L1 block's timestamp; origin data is from the block before (`Derivation.md:59-64`).
2. Per source (forced first, proposer last): blob slice must decode as `[32-byte version = 0x1][32-byte size][zlib(RLP(DerivationSourceManifest))]`; per-source block cap 192 pre-Unzen, 768 after (keyed on the proposal's L1 timestamp); a forced source must contain exactly one block (`Derivation.md:154-166`; `source_fetcher.go:77-168`).
3. **Any failure replaces only that source with the default manifest**: one block with no user transactions, `coinbase = proposer`, parent's anchor and gas limit, timestamp = the computed lower bound (`Derivation.md:168-185`, `:196`). This is the censorship-resistance property: a malicious proposer cannot invalidate a forced inclusion by corrupting its own source.
4. A `BlockManifest` is `{timestamp, coinbase, anchorBlockNumber (0 = inherit), gasLimit, transactions}` (`Derivation.md:108-120`). Forced-inclusion blocks have all metadata overwritten with inherited values before validation (`:200-212`).
5. **Timestamp rule**: every block in `[max(parent.timestamp + 1, proposal.timestamp − TIMESTAMP_MAX_OFFSET, SHASTA_FORK_TIME), proposal.timestamp]`, else the whole source defaults (`:218-224`). The `+1` is the one-second minimum block spacing; the upper bound is the **L1 landing time**, so a preconfirmed block dated after the L1 block in which its proposal lands is retroactively invalid. `TIMESTAMP_MAX_OFFSET = 12 × 512 = 6144 s` on mainnet, literally 12 seconds per L1 block (`:371`).
6. **Anchor rule**: `anchorBlockNumber` non-decreasing, `≤ originBlockNumber`, `≥ originBlockNumber − MAX_ANCHOR_OFFSET (512)`, and a non-forced source must advance the anchor at least once; else default (`:226-236`; `driver/src/derivation/pipeline/shasta/validation.rs:145-186`). The anchor hash and state root are re-fetched from L1 by the node at landing.
7. **Gas rule**: ±200 ppm per block within [10M, 45M]; +1,000,000 is added for the anchor tx (`:249-263`).
8. Header: `extraData = basefeeSharingPctg(1) || proposalId(6)`; `mixHash = keccak(parent.difficulty, number)`; base fee by EIP-4396 with `BLOCK_TIME_TARGET = 2 s` (`:294-315`, `:379`). Note the Inbox comment says "Derivation enforces 1s block times" (`Inbox.sol:63-64`); the 1 s is the minimum spacing, the 2 s is the base-fee target.
9. Blocks per proposal: up to 10 forced × 1 block + 1 proposer source × 768 blocks.

**Unzen fork semantics (gap fill G7, `notes/phase1-gap-G7.md`).** "Unzen" is two coupled things: the L1 governance upgrade Proposal0019 (forced inclusions re-enabled, `ZkRequiredVerifier`, image rotation; no timestamp gating in Solidity) and an L2 timestamp hardfork. Fork times are hard-coded identically in taiko-geth and alethia-reth, not in this repository: mainnet Shasta `1_775_135_700` (2026-04-02), mainnet Unzen `1_786_021_200` (2026-08-06), Hoodi Shasta `1_770_296_400`, Hoodi Unzen `1_781_787_600`. At Unzen the L2 execution layer activates Cancun, Prague and Osaka header fields (zero beacon root, empty requests hash, zero blob gas; blob transactions forbidden), switches on zk-gas metering (`BLOCK_ZK_GAS_LIMIT = 100_000_000`, `TX_INTRINSIC_ZK_GAS = 243_000`; block building stops at the first non-anchor transaction that would exceed the limit, and import rejects a body extending past that point), and **repurposes `header.difficulty` to carry `block_zk_gas_used`** (0 before Unzen). The random seed described in `Derivation.md` lives in `mixHash`, not `difficulty`; both clients already do this. Because difficulty is execution-dependent, `getPayloadV2.blockValue` transports it back into `newPayloadV2` and the gossip envelope grew an optional 32-byte `HeaderDifficulty` field; only the Rust receiver validates that field against the fork schedule. The per-source block cap rises from 192 to 768, keyed on the proposal's L1 timestamp. [proven by code reading; alethia-reth's block executor was not read, only its chainspec]

**What derivation does not do:** it never consults the preconfirmed chain. The block at a height is whatever L1 data says; a node compares and reorgs (§9.5).

---

## 8. Clients: proposer, prover, driver

Two implementations exist and are wire-compatible: Go (`packages/taiko-client`) and Rust (`packages/taiko-client-rs`). The L2 execution engines are `taiko-geth` and `alethia-reth` (outside this repository).

### 8.1 Proposer

- Go: a timer loop (`--epoch.interval`, else random 12-120 s, `proposer/proposer.go:348-363`); each tick checks it is the whitelist's current operator (comparing the operator's `sequencerAddress` to its own proposer address, a latent mismatch for operators whose two addresses differ, `:393-416`; `pkg/rpc/methods.go:917-935`) [REMOVED IN ETNA]; pulls tx lists from the L2 txpool (`taikoAuth_txPoolContentWithMinTip`), never from preconfirmed blocks (`:188-196`); builds manifests with `timestamp = l1Head.time + i` and `anchorBlockNumber = l1Head.number` (`proposer/transaction_builder/blob.go:60-94`); encodes into ≤ 6 blobs of 130,044 bytes (`:138-152`); sends `propose("", encodeProposeInput{deadline: 0, numForcedInclusions: 0xffff})` through an Optimism `SimpleTxManager`, optionally via a private RPC; a mined-but-reverted proposal is simply logged and the lists stay in the pool (`:366-385`). No builder API, no bundles.
- Rust: same loop with `getOperatorForCurrentEpoch() == own address` or the client-side "forced inclusion is permissionless" rule (`proposer/src/proposer.rs:272-325`); `numForcedInclusions = u16::MAX` (`proposer/src/transaction_builder.rs:177-184`).

**Who turns the preconfirmed chain into the L1 proposal? Nobody in this repository (gap fill G1, `notes/phase1-gap-G1.md`).** Both in-repo proposers read only the L2 txpool and cannot express per-block anchor numbers or real block timestamps. Both "preconfirmation drivers" (Go `driver/preconf_blocks`, Rust `whitelist-preconfirmation-driver`) are passive HTTP/WS servers that accept a fully formed block from an authenticated external caller, execute it, sign it and gossip it. Three source comments name that caller "Catalyst"; no README, spec, interface document or flag names it or its algorithm. Manifest assembly, per-block `anchorBlockNumber` selection (fixed at preconf time inside the anchor transaction), forced-inclusion height reservation and landing timing are therefore an implicit contract, reconstructable only by inverting the derivation and canonical-match rules: every header field must replay byte-for-byte, timestamps must stay within `[landing.timestamp − 6144 s, landing.timestamp]`, one proposal per L1 block, at most 768 blocks per source. **For Etna:** the sequencer-to-lander pipeline must be specified in the protocol, not left to an external component.

### 8.2 Prover

- Go (`prover/`): scans `Proposed` events with 6 confirmations; waits until the L2 node has sealed the proposal's last block, explicitly refusing preconfirmation blocks (`pkg/rpc/methods.go:281-300`); the **designated prover is the proposer address** for `provingWindow` (4 h), others step in only with `--prover.proveUnassignedProposals` after `provingWindow + 72 s` (`prover/event_handler/proposal.go:130-209`; `prover/event_handler/util.go:18`, `:48-66`); requests a primary (RISC0 or SP1) and a companion (SGX-geth, or RISC0 in ZK-only mode) proof from a Raiko host (`POST /v4/proof/proposal`, 10-minute request timeout, `prover/proof_producer/compose_proof_producer.go:54-137`); buffers single-proposal proofs and aggregates them into one batch per lane when the buffer fills or after 30 minutes (`prover/proof_submitter/proof_submitter.go:460-472`); submits `prove(commitment, [companion, primary])` sorted by verifier id, only after the parent proposal is finalized on L1 (`:421-426`; `prover/proof_submitter/transaction/builder.go:37-161`); a revert re-queues the proposals and the "already finalized" check drops them on the next attempt (`prover/prover.go:311-352`). No constant states proving latency; only the 10-minute and 30-minute timeouts exist.
- There is no Rust prover.

Proving economics and limits (gap fill G5, `notes/phase1-gap-G5.md`; verified missed facts): provers are not compensated on-chain at all; the only crediting path is the dormant late-proof settlement, which is a proposer slash split 50/50, not a reward, and is skipped while the whitelist is on. The Go client waits `provingWindow + 72 s` before proving another proposer's proposal, except that a proposal first seen after its window expired is proved immediately. Measured L1 gas of `prove` in the repo is 82,220 for one transition and about 768 gas per additional transition, **measured with a no-op verifier** (`snapshots/shasta-prove.json`; `MockProofVerifier`); the real RISC0 Groth16 router and SP1 PLONK gateway are only `vm.mockCall`ed in tests, so their gas is unmeasurable from this repository (the SGX leaf is about 7.7k gas per the Daybreak audit). Verifier gas is per proof, not per transition, so aggregation amortizes it; the quadratic memory term of decoding makes a single `prove` infeasible somewhere around 8k to 12k transitions at a 36M-gas L1 block (derived, not measured), far below the 21,599 ring-buffer and 65,535 codec bounds. `_data` is decoded before any validation, so an oversized input burns the memory cost before reverting. Raiko aggregation is retried forever with constant back-off while the lane stays latched. Neither client handles bonds (no deposit, withdraw or balance check anywhere). `--tx.numConfirmations` defaults to 0, so both roles treat a transaction as final on the first receipt and never re-check it after a shallow L1 reorg. `Transition.timestamp` is the L1 header timestamp of the observed `Proposed` log, not read back from the Inbox. With a remote signer the designated-prover comparison uses the signer's address. The golden-touch private key is hard-coded in `bindings/encoding/struct.go:5`.

### 8.3 Driver (derivation and engine)

- Go: `L2ChainSyncer.Sync()` on every L1 head: optional beacon (checkpoint) sync, then `Proposed` events from the L1 cursor, per-proposal blob fetch (beacon node by slot, matched by recomputed KZG commitment, blob-server fallback), manifest decode, `ValidateMetadata`, anchor tx assembly, and `engine_forkchoiceUpdated → getPayload → newPayload (VALID) → forkchoiceUpdated(head, safe = finalized = last finalized checkpoint)` (`driver/chain_syncer/chain_syncer.go:82-176`; `driver/chain_syncer/event/blocks_inserter/common.go:38-212`). Before inserting, `isKnownCanonicalProposal` rebuilds every block's attributes and anchor tx and compares them with the existing (preconfirmed) blocks; if identical, only L1-origin records are updated, else the derived blocks replace them (`blocks_inserter/inserter.go:101-279`; `common.go:216-454`).
- Rust: `SyncPipeline` = `BeaconSyncer` to the finalized L2 block from `getCoreState()` at finalized L1, then `EventSyncer` following `Proposed` through `ShastaDerivationPipeline` with the same engine sequence; ingress for preconfirmations is a serialized queue gated closed until a "confirmed sync" probe passes (`driver/src/sync/mod.rs:103-108`; `driver/src/sync/event.rs:707-759`, `:1141-1173`).

---

## 9. Preconfirmations today

### 9.1 What a preconfirmation is

The current-epoch operator's **sequencer key** builds blocks through a JWT-protected local API (`POST /preconfBlocks` with `ExecutableData{parentHash, feeRecipient, blockNumber, gasLimit, timestamp, transactions (RLP, zlib), extraData, baseFeePerGas}`), the node executes them through the Engine API, the operator signs the resulting block hash and, separately, the SSZ envelope, and the envelope is gossiped over libp2p gossipsub (`driver/preconf_blocks/api.go:72-313`; `whitelist-preconfirmation-driver/src/api/service/handlers.rs:60-231`). Envelope: 2 flag bytes (end-of-sequencing, forced-inclusion, difficulty-present, signature-present) + 32-byte parent beacon root + optional 32-byte header difficulty (Unzen) + SSZ `ExecutionPayloadV1` with exactly one element in `transactions` (the compressed tx list including the anchor) + optional 65-byte block-hash signature; the wire message is `snappy(sig65 || envelope)` (`/root/go/pkg/mod/github.com/taikoxyz/optimism@.../op-service/eth/ssz.go:523-596`; `whitelist-preconfirmation-driver/src/codec.rs:184-230`). Topics: `/taiko/{chainId}/0/{preconfBlocks, requestPreconfBlocks, responsePreconfBlocks, requestEndOfSequencingPreconfBlocks}` (`whitelist-preconfirmation-driver/src/network/topics.rs:22-33`). The gossip layer lives in a forked op-node (Go) or in the Rust crate; not in taiko-geth.

Signing prehash: `keccak256(0x00×32 || chainId_be32 || keccak256(payload))` (`codec.rs:60-68`; op-node `signer.go:18-27`).

Further verified facts (P2P layer, `notes/phase1-go-preconf.verify.md`, `notes/phase1-rust-client.verify.md`): the `requestPreconfBlocks` and `requestEndOfSequencingPreconfBlocks` topics are **unauthenticated** (the op-node fork carries `// TODO: add signer, sign request`); validators only rate-limit (200 tokens per peer per minute, 45-s per-hash window), so any peer can make every operator node perform block lookups and publish responses. The block topic does not require the embedded block-hash signature; a block gossiped without it is stored with an all-zero `L1Origin.Signature` and later cannot be served on the response topic. Go persists the *embedded* block-hash signature, not the wire signature, so response-topic verification over `BlockHash` is consistent. A Go node started without `--l1.beacon` never runs the lookahead loop, leaves the accepted signer set at `[0x0, 0x0]`, and rejects all gossip forever. Every slot or epoch gate in the Go client (build window, end-of-sequencing keys, `/status`) is computed from the **host wall clock** relative to beacon genesis, not from observed L1 blocks, so a skewed clock changes who may build. The Go request handler waits up to 1 s of jitter while holding the server mutex. Rust decodes `operatorCount` as `u8`, dedupes per-height caps by message rather than by hash, and latches ingress open permanently after the first head L1 origin. The Rust JWT middleware skips authentication for HTTP `OPTIONS`.

### 9.2 The validity predicate: can every node decide locally and immediately?

**No.** A node can decide that a block is well-formed, signed by *some* allowed key, and executable on its current head. It cannot decide that the block is what L1 will eventually say happened at that height. Per check (from the cross-cutting analysis, `notes/` source `preconf-validity.md`):

| # | Check | Go | Rust | Locally decidable today? |
|---|---|---|---|---|
| V1 | Wire signature over the SSZ envelope | signer ∈ `[currOperator, nextOperator]` from the last L1 read (`gossip.go:776-800`; `driver/preconf_blocks/server.go:1048-1062`) | signer ∈ whole roster of `sequencerAddress`es, refreshed every 384 s, `activeSince` ignored (`network/handler.rs:298-304`; `operator_set.rs:111-155`) | Yes (membership). The embedded block-hash signature is not verified on the block topic by either client. |
| V2 | Sequencing right for this slot | slot window enforced only on the node's own build API, never on received gossip (`api.go:162-166` vs `server.go:271-383`); reads at "latest" so nodes straddling an epoch boundary disagree | no notion of epoch at all | **No.** Not consensus-deterministic across nodes. |
| V3 | Parent linkage | parent must be canonical at N−1 at insertion; otherwise cache and request the parent (`common.go:797-813`; `server.go:1407-1431`) | same (`cache_import.rs:154-170`; `production/path.rs:82-122`) | Yes, relative to the node's own view. |
| V4 | Number / timestamp bounds | `number > headL1Origin` only; timestamp only `≠ 0` (`util.go:147-153`; `server.go:957-959`) | same (`event.rs:606-616`; `validation.rs:25`) | Number: yes. Timestamp, gas band, base fee: **only at landing** (they depend on `proposal.timestamp`). |
| V5 | Anchor tx correctness | recipient, golden-touch sender, method name only; calldata values never decoded (`prover/anchor_tx_validator/anchor_tx_validator.go:44-76`) | recipient, chain id, sender, `anchorV4` selector (`protocol/src/shasta/anchor.rs:249-291`) | Shape: yes. Checkpoint contents and anchor-number rules: **only at landing** (could be checked against the node's L1 view, but are not). |
| V6 | Execution validity | the node **rebuilds** the block from attributes; `newPayload` must be VALID; the produced hash is never compared with the signed hash (`common.go:761-793`) | same; on mismatch it warns, purges the envelope, and keeps the produced block (`cache_import.rs:186-207`) | Yes (attributes are executable). "Signed hash == produced hash" is computable but not enforced. |
| V7 | Consistency with what L1 will land | not checkable | not checkable | **No.** Different proposed contents, timestamp clamping, anchor rules, forced inclusions inserted ahead, blob decode failures, a missed landing, or an L1 reorg all change the derived block. |

Conflicting blocks at one height: both gossip layers accept up to 10 distinct hashes per height (`gossip.go:397-408`; `handler.rs:33`); Go inserts a new sibling over an existing one whenever its parent is canonical ("Preconfirmation block is reorging", `server.go:1449-1489`); Rust promotes the most recently processed valid sibling (`engine.rs:390-395`). There is no first-seen rule and **no equivocation evidence is recorded anywhere**.

What the execution engine adds on `engine_newPayload` (gap fill G6, `notes/phase1-gap-G6.md`; taiko-geth only, alethia-reth not read): timestamp strictly greater than parent at import, but the usual `timestamp ≤ now` check is **skipped for preconfirmation blocks**; no gas-limit band (only `gasLimit ≤ 2^63−1` and `gasUsed ≤ gasLimit`); the EIP-4396 base fee is recomputed and verified, so the envelope's `baseFeePerGas` is effectively ignored; `extraData` must be exactly 7 bytes; the anchor transaction's type, recipient, selector, zero value, exactly 1,000,000 gas, fee cap and sender are checked **at build time only** (`forkchoiceUpdated` with attributes), not re-checked at import; invalid user transactions are skipped at build and would be rejected at import; difficulty is 0 before Unzen and recomputed zk gas after; **a reverted anchor transaction does not invalidate the block** (no receipt-status check). So V6 today means "the attributes are executable", and even the anchor's semantic effect (the checkpoint being written) is not part of validity.

### 9.3 User guarantees today

- **At preconfirmation:** a signed message from an allow-listed key plus the receiving node's own execution of it. No bond, no slashing condition, no on-chain object references the signature (`PreconfWhitelist.sol:139-140`). The only sanction is governance removal from the roster.
- **At L1 landing:** the block at that height is now fixed by L1 data and deterministic derivation; whether it equals the preconfirmed block is known only now.
- **At proof finalization:** `lastFinalizedProposalId` advances; the driver marks the block `safe`/`finalized`; from here the block is protected by the validity-proof system.

### 9.4 Handover between operators [REMOVED IN ETNA]

Go splits each 384-s epoch into `[0, 24)` slots for the current operator and `[24, 32)` for the next (`handoverSkipSlots = 8`, `driver/preconf_blocks/lookahead.go:70-100`; `driver/driver.go:37`), refreshed from `getOperatorForCurrentEpoch/NextEpoch` on a `SecondsPerSlot/3` ticker (`driver.go:385-621`). The incoming operator requests the outgoing operator's **end-of-sequencing** block once; only the current operator answers; if unanswered, nothing retries (`driver.go:408-443`; `server.go:670-673`). On-chain, the current operator may still propose during the handover slots, because `checkProposer` uses the epoch of the landing L1 block (`PreconfWhitelist.sol:136`). Rust has no handover logic ("Catalyst owns handover", `importer/mod.rs:180-185`). Gap fill G2 (`notes/phase1-gap-G2.md`) confirms that the 8-slot window is a Go-driver convention for L2 block *building* only; no contract, proposer or document restricts the current operator from *landing* proposals during those slots, and no L1 block tag (latest, safe, finalized) is designated anywhere as the reference for operator selection: on-chain it is necessarily the including block, off-chain every reader uses `latest` with no pinning. Etna must define sequencing rights as a function of an L1 block identity, not of wall time.

### 9.5 "L1 wins"

When a proposal lands, the derived blocks are authoritative. Go: if every block matches byte-for-byte (parent, anchor tx hash, coinbase, mixDigest, number, gas limit, timestamp, extraData, base fee, payload id), only L1-origin rows are updated; else the derived blocks are inserted with forkchoice moved to them and `PreconfChainReorged = true` resets the unsafe head (`inserter.go:169-276`; `server.go:1288-1297`). Rust: `head_l1_origin` advances and every cached or in-flight preconf payload at or below it is `Stale` (`event.rs:395-397`, `:606-616`). The code never treats a conflicting L1 proposal as evidence of misbehaviour.

---

## 10. Withholding today

Scenario: the current operator builds blocks in its own engine but does not gossip them.

- **(a) Other nodes observe** nothing: their unsafe head stops advancing; there is no heartbeat, expected-block-rate, or "operator silent" detector in either client (`server.go:1509-1526`; `runner.rs:209-215`).
- **(b) The code does** nothing proactive. Parent requests are only sent when a child with an unknown parent arrives (impossible under full withholding), and the one end-of-sequencing request at handover is answered only by the withholding operator itself (`server.go:787-830`, `:670-673`; `driver.go:415-443`).
- **(c) The operator can later land the withheld blocks and force a reorg.** The only L1 constraints are the epoch check, the bond check, one proposal per L1 block, and derivation validity (`PreconfWhitelist.sol:127-141`; `Inbox.sol:590-607`; `Derivation.md:218-263`). Nothing on L1 references gossip. On landing, every node replaces its preconfirmed blocks (§9.5), unconditionally.
- **(d) Withheld blocks can invalidate the next operator's blocks at handoff.** Operator A (epoch E) secretly builds k+1..k+m on the last gossiped block k; operator B starts building on k at slot 24; A lands its proposal before epoch E ends; B's blocks are reorged out on every node, and B's own proposal can only land in epoch E+1 appended after A's blocks, re-executing B's transactions at new heights on a different state. B has no defence and nothing to slash.
- **(e) Penalty:** none automatic. The preconf signatures are stored only in the L2 engine's `L1Origin` rows and are never submitted to L1; the only remedy is manual `removeOperator` by the owner or an ejecter.

Forced inclusions and the preconfirmed chain (gap fill G3, `notes/phase1-gap-G3.md`): the preconfer does not reserve heights for forced inclusions and nothing in the repository does; the `IsForcedInclusion` flag on gossiped blocks is never checked against the queue. Because forced sources derive first, at the heights the preconfer already used, and because both proposers request `u16::MAX` inclusions (draining not-yet-due entries too), **any non-empty queue at landing reorgs the entire preconfirmed suffix** on every node, due or not, including entries saved in the same L1 block as the proposal. The inclusion bound is conditional, not hard: an entry among the first 10 is consumed by the first proposal landing at L1 time ≥ save + 576 s, but only a whitelisted operator can propose, and an entry whose blob expires before any proposal lands derives to an empty default block.

Adjacent facts: blob withholding is impossible after landing (the blob hashes must be present in the same L1 transaction, `LibBlobs.sol:221-227`); an undecodable proposer source degrades to the default anchor-only block rather than stalling; there is no "give me everything after height h" primitive, so a single withheld block stalls all cached children (bounded at 768 envelopes); proof withholding by the whitelisted provers has no fallback (`permissionlessProvingDelay` is dead config) and stalls finalization until the ring buffer fills (≈ 3 days), after which `propose` reverts `NotEnoughCapacity`.

---

## 11. Everything coupled to L1 slots or epochs

Etna's R5 forbids all of the following. Each is a hard-coded 12-second or 32-slot assumption unless noted.

| Where | What | Value |
|---|---|---|
| `LibPreconfConstants.sol:347-348` | `SECONDS_IN_SLOT`, `SECONDS_IN_EPOCH` | 12, 384 |
| `LibPreconfConstants.sol:342-345` | beacon genesis timestamps per chain id | hard-coded |
| `LibPreconfUtils.sol:390-406` | 4788 root probing in 12-s steps, up to 32 | slot-coupled |
| `PreconfWhitelist.sol:26`, `:30` | `OPERATOR_CHANGE_DELAY`, `RANDOMNESS_DELAY` | 2 epochs each |
| `Inbox.sol:62-65` | `MAX_FORCED_INCLUSIONS_PER_PROPOSAL < 12` rationale | one proposal per 12-s slot |
| `MainnetInbox.sol:15-18` | ring buffer 21,600 | 3 days ÷ 12 s |
| `MainnetInbox.sol:46-47` | `forcedInclusionDelay = 576` | "1.5 epochs" |
| `docs/Derivation.md:371`; `protocol/src/shasta/constants.rs:33-35`; `bindings/manifest/manifest.go:26-28` | `TIMESTAMP_MAX_OFFSET = 12 × MAX_ANCHOR_OFFSET` | 6144 s mainnet |
| `protocol/src/shasta/constants.rs:20-22` | 192 blocks "cover an Ethereum epoch" | comment |
| `docs/zk_gas_spec.md:419` | zk-gas budget rationale "384 blocks per proposal (one epoch)" | spec only |
| `driver/driver.go:37`, `:391`, `:462`, `:497`; `driver/preconf_blocks/lookahead.go`; `server.go:60` | handover skip slots 8, ticker `SecondsPerSlot/3`, 6-s missed-slot grace, `slotInEpoch >= 2`, shutdown margin 8 slots | slots |
| `whitelist-preconfirmation-driver/src/cache.rs:29`; `api/service/mod.rs:53-73` | `L1_EPOCH_DURATION_SECS = 384`, `SECONDS_PER_SLOT = 12`, handover/shutdown windows in slots | hard-coded |
| `contracts/shared/libs/LibNetwork.sol:22` | `ETHEREUM_BLOCK_TIME = 12` | unused constant |
| `driver/chain_syncer/event/blocks_inserter/checkpoint_cache.go:14` | 3-minute TTL "half an epoch" | comment |
| Go client defaults 12 s / 48 s / 72 s / 12-120 s | RPC timeout, resubmission, proof-expiry delay, propose interval | chosen as slot multiples |

Expressed in seconds or L1 block numbers already (acceptable under R5): `forcedInclusionDelay`, `provingWindow`, `maxProofSubmissionDelay`, `withdrawalDelay`, `MAX_ANCHOR_OFFSET` (L1 blocks), the derivation timestamp lower bound (`parent + 1`), blob retention (wall-clock under EIP-8198).

---

## 12. Everything gated by an admin

Etna's R1 requires that none of these touch day-to-day operation. DAO-only *upgrades* remain acceptable.

| Gate | Holder (mainnet) | Effect on liveness if the holder never acts again |
|---|---|---|
| `PreconfWhitelist.addOperator/removeOperator` (`PreconfWhitelist.sol:94-110`) | DAO controller or ejecters (set by `admin.taiko.eth`) | roster frozen; a dead operator's epochs have no valid proposer; no fallback |
| `ProverWhitelist.whitelistProver` (`ProverWhitelist.sol:74-95`) | DAO controller or `admin.taiko.eth` | prover set frozen; if they stop, no finalization ever |
| `Risc0Verifier.setImageIdTrusted`, `SP1Verifier.setProgramTrusted` (`Risc0Verifier.sol:43-46`; `SP1Verifier.sol:44-47`) | DAO controller | next raiko release cannot be trusted; ZK legs frozen on current images |
| `SgxVerifier.setMrEnclave/setMrSigner/addInstances/deleteInstances`, attribute policies (`SgxVerifier.sol:224-300`; `SecureSgxVerifier.sol:73-148`) | DAO controller (on attester proxies live) | SGX legs die at the next enclave release or expiry |
| `SgxVerifier.registerInstance` registrar (`SgxVerifier.sol:319`) | `admin.taiko.eth` | no new SGX instances; chain must prove RISC0 + SP1 |
| `Inbox.activate/init2/init3` (`Inbox.sol:188`, `:217`, `:253`) | owner | no incident recovery |
| `Anchor.withdraw` (`Anchor.sol:145`) | L2 DelegateController | base-fee share stranded (no liveness effect) |
| `SignalService.pause`, `Bridge.pause` (`SignalService.sol:201`; `Bridge.sol:556`) | owner or immutable pauser (`admin.taiko.eth`) | pausing halts bridging; `Inbox.propose/prove` and `Anchor.anchorV4` have no pause |
| `QuotaManager.updateQuota` (`QuotaManager.sol:70`) | `admin.taiko.eth` | bridge throttled at current quota |
| `DefaultResolver.registerAddress` (`DefaultResolver.sol:44`) | owner | no new chains or token implementations |
| UUPS `upgradeTo` on every proxy (`EssentialContract.sol:207`) | DAO controller (L1), DelegateController via bridged DAO actions (L2) | acceptable under R1 (upgradeability only) |

Not gated by anyone: `Bridge.processMessage` (relayers are permissionless), `saveForcedInclusion`, bond deposits and withdrawals, `Anchor.anchorV4` (public key), and, when the whitelist count is zero, `prove`.

---

## 13. Dead code, stale docs, and inconsistencies

Recorded so that the design does not build on them.

- `permissionlessProvingDelay` and `permissionlessInclusionMultiplier` are stored, validated, and never enforced (`Inbox.sol:99`, `:121`, `:165`, `:172`, `:539`, `:546`). The Rust proposer enforces the second client-side; the contract would revert (`proposer.rs:669-683`; `InboxPropose.t.sol:296-320`).
- `LibForcedInclusion.isOldestForcedInclusionDue` is never called (`LibForcedInclusion.sol:152-170`); the Inbox re-implements it inline.
- `LibPreconfConstants.TWO_EPOCHS`, `DISPUTE_PERIOD`, `RANDOMNESS_DELAY_EPOCHS`, `PRECONF_DOMAIN_SEPARATOR` and `LibPreconfUtils.getEpochtimestampForSlot` are dead. `LibNames.B_PRECONF_SLASHER` (`"preconf_slasher"`) is a reserved, unused resolver name [REMOVED IN ETNA].
- `propose(bytes _lookahead, …)` and `IProposerChecker._lookaheadData` are URC-era plumbing; `packages/taiko-client-rs/crates/bindings/src/lookahead_store.rs` is a generated binding imported by nothing [REMOVED IN ETNA].
- `contracts/layer2/core/BondManager_Layout.sol` and `AnchorForkRouter_Layout.sol` are orphan layouts with no contract. `packages/protocol/CLAUDE.md:69` still says the Anchor "does bond management"; it does not. The Rust `BOND_PROCESSING_DELAY = 6` constant is unused (`constants.rs:49-50`).
- `docs/how_taiko_proves_blocks.md`, `docs/contestable_validity_rollup.md`, `docs/actors_privileges_deployments.md` describe the 2023-era design (signed anchor with `l1SignalRoot`, tiers, contests, `AddressManager`, Transparent proxies, TimelockController); none of it exists on `main`. `docs/multihop_bridging_deployment.md` describes a caching API that no longer exists; the slot formula is still exact.
- `docs/Derivation.md` cites stale line numbers (`:60`, `:85`, `:148`), says `SHASTA_FORK_TIME` is "not scheduled" while Unzen is live, and its `difficulty` rule is contradicted by the Rust driver (header difficulty must be 0 pre-Unzen and non-zero, equal to zk gas used, post-Unzen; `payload.rs:775-807`; `ingress.rs:276-278`). `BLOCK_TIME_TARGET = 2 s` (base-fee target) coexists with the Inbox comment "Derivation enforces 1s block times" (minimum spacing).
- `pkg/preconf/payload.go:27` references a non-existent `pkg/preconf/validation.go`.
- The Go proposer compares the operator's `sequencerAddress` with its own *proposer* address (`proposer.go:405`; `methods.go:935`): correct only for operators that registered the same key for both roles.
- `IPreconfWhitelist.sol:39-40` says randomness comes from "the first block in the last epoch"; the implementation uses two epochs back.
- The verifier for the L1 Inbox summary flagged that `getConfig().proposerChecker` on mainnet and the on-chain owners of the proxies were not read from chain in this study; they are taken from deploy scripts and proposal logs.

---

## 14. Glossary

- **Proposal**: the unit of L1 submission (formerly "batch"): a hashed record pointing at blob slices. **Block**: an L2 block derived from a proposal. **Source**: one derivation source inside a proposal (forced or proposer-supplied).
- **Operator / preconfer**: a `PreconfWhitelist` entry; its **proposer address** lands proposals on L1, its **sequencer address** signs preconfirmations.
- **Preconfirmation (preconf)**: a signed, gossiped L2 block that has not yet landed on L1. **Unsafe head**: the highest preconfirmed block a node has executed. **Head L1 origin**: the highest L2 block known to be derived from L1; the "confirmed boundary".
- **End of sequencing (EOS)**: a flag on an operator's last block of its epoch, used only for handover.
- **Derivation**: the deterministic rules turning `Proposed` events plus blobs into blocks. **Default manifest**: the anchor-only single block substituted for an invalid source.
- **Anchor transaction**: the golden-touch system transaction that opens every L2 block and carries an L1 checkpoint. **Golden touch**: the public-key system account.
- **Checkpoint**: `{blockNumber, blockHash, stateRoot}` of the other chain, saved into a SignalService by its authorized syncer. **Signal**: a 32-byte value written into a computed storage slot of the SignalService, provable on the other chain against a checkpoint.
- **Commitment / transition**: the proof's public input; a transition is `(proposer, timestamp, endBlockHash)` per proposal.
- **Liveness bond**: the only bond; debited from a proposal's proposer when its proof lands late (disabled on mainnet).
- **Forced inclusion (FI)**: a user-posted single-blob, single-block source that the next proposer must include once due.
- **Raiko**: the off-chain proving host (SGX, RISC0, SP1 back-ends). **Companion / primary proof**: the two sub-proofs required by the compose verifier.
- **URC / lookahead**: the deprecated registry-based preconfer selection; only plumbing remains [REMOVED IN ETNA].

---

## 15. Sources and verification status

This document synthesizes ten area summaries produced by reading sub-agents and re-checked by independent skeptic sub-agents (each checked ≥ 15 claims against the code and listed missed facts), a completeness critic, and targeted gap-fill reads. The architect additionally read `Inbox.sol`, `IInbox.sol`, `Anchor.sol`, `SignalService.sol`, `ICheckpointStore.sol`, `PreconfWhitelist.sol`, `LibPreconfConstants.sol`, `LibPreconfUtils.sol`, `LibBonds.sol`, `LibForcedInclusion.sol`, `LibBlobs.sol`, `MainnetInbox.sol`, `LibInboxSetup.sol`, `MainnetVerifier.sol`, `ZkRequiredVerifier.sol`, `ComposeVerifier.sol`, `IProofVerifier.sol`, `LibPublicInput.sol` and `docs/Derivation.md` in full. Verification reports (`notes/phase1-*.verify.md`, ten areas) and the gap-fill answers G1 to G7 (`notes/phase1-gap-G*.md`) are recorded under `notes/`; gap fills G8 to G12 (proposer economics today, blob-fetch paths, the L2 fee flow in detail, the Bridge quota state on mainnet, and the raiko SGX lane) were not produced because the sub-agent budget ran out, and are listed as open items in `01-threat-model.md` §8. Where a verifier marked a claim WRONG or IMPRECISE, the corrected statement is what appears above.
