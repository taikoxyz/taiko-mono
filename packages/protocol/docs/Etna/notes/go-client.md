# Phase 1: Go client evidence

Baseline: `961bbd8ff55a0f66f44ad04160eb51638d655b66` (main-configured checkout; remote freshness unverified). Scope: preconfirmation driver, `pkg/preconf`, proposer, prover, and the adjacent insertion/RPC code necessary to trace their behavior. No Etna mechanism is proposed here.

Labels: **Proven** means established by the cited code, not that the running deployment was audited. **Assumed** names a dependency whose behavior is necessary but is outside the inspected repository. **Open** names an unresolved check. Evidence identifiers resolve to exact paths and line ranges in the final table.

## 1. The flow a new engineer should understand

**Proven [G01–G06]:** There are two relevant entry paths; they should not be conflated into a single Go proposer that also preconfirms.

1. **Preconfirmation path.** An external block builder calls `POST /preconfBlocks` on the Go driver with parent hash, number, timestamp, fee recipient, gas limit, base fee, extra data, and one compressed transaction list that already includes the anchor. This endpoint receives a block-building request; it does not fetch the user's transactions from the txpool itself. It rejects a syncing/not-ready engine and obtains the parent. It checks its current handover window when a beacon client is configured, creates an execution payload, does structural validation, then asks the engine to build/import the block.
2. **Gossip.** If P2P and a signer are configured, the builder signs the resulting block hash under `SigningDomainBlocksV1` and the L2 chain ID, stores the signature in the local L1-origin record, caches the envelope, and publishes it. Publication failure is logged; the already-built block is not undone. If P2P/signer are disabled, the code explicitly skips publication. This is a local operational option, not an on-chain availability guarantee.
3. **Receiving driver.** The P2P package delivers an unsafe payload to the server. The server checks structure/anchor shape, waits or caches while syncing, checks that the block is beyond the latest L1-derived origin, resolves ancestors, and feeds the block to the engine. It can import a different unsafe branch.
4. **L1 proposal path.** The standalone Go proposer waits until the engine is synced, checks whether it is the current whitelist operator when that contract is configured, fetches transactions from the engine's pool, constructs a derivation manifest, compresses it into blobs, and sends `Inbox.propose`. This code is an independent L1 proposer path; it does not demonstrate extraction of the preconfirmed chain into a landing batch. The Rust preconfirmation builder/proposer analysis must supply that production integration.
5. **Derivation.** On an L1 proposal, the Go driver derives the manifest and constructs the anchor transaction from the relevant L1 header and proposal information. If the derived proposal exactly matches blocks already in the canonical local chain, it updates their L1-origin records. Otherwise it builds the derived chain and reports a preconfirmation-chain reorg.
6. **Proof.** The prover consumes `Proposed` events, waits for the derived proposal's last L2 block, checks that the event remains canonical on L1, schedules the assigned proposer/prover or fallback prover, requests proofs, buffers and aggregates consecutive proposals, and sends a distinct `Inbox.prove` transaction. It does not propose with proof. The proposal transaction carries blobs; the proof transaction carries proofs/commitments in calldata and has `Blobs: nil`.

**Proven [G07–G08]:** The standalone proposer uses a configured proposing interval or, when unset, a randomized 12–120-second interval. Its manifest assigns timestamps `l1Head.Time + i` to consecutive blocks. The latter is a one-second timestamp increment, not evidence of one-second user-visible preconfirmation issuance. This code also waits for a newer L1 head when the most recent proposal occupied the currently observed L1 block.

**Open:** Neither local HTTP success, gossip publication success, nor a one-second manifest timestamp increment establishes a measured one-second preconfirmation SLA. Latency requires builder scheduling, network propagation, engine execution, and instrumentation outside these inspected functions.

## 2. What “valid now” means

There are at least four distinct predicates: admissible gossip, executable state transition, agreement with eventual L1 derivation, and finalized state. A signature is not any of the last three by itself.

| Check | What the Go repository establishes | Status and boundary |
|---|---|---|
| Message structure | Nonzero timestamp, fee recipient, gas limit, base fee and extra data; exactly one compressed transaction-list field; compressed-size bound; successful zlib decompression and RLP decoding; a nonempty decoded list. | **Proven [G09].** This is admission, not full block execution. |
| Signature production | The locally built header hash is signed with block signing domain and L2 chain ID, then stored with the block's L1 origin. | **Proven [G02].** |
| Signature verification | The driver supplies current/next sequencer addresses to the external P2P runtime and installs itself as its callbacks. There is no signature recovery in `ValidateExecutionPayload`. | **Proven [G09–G11]** for this division of responsibility. **Assumed A-GOSSIP:** the pinned external Taiko optimism fork correctly validates the wire signature, reconstructs the committed header, and domain-separates messages before callback. Do not promote that assumption to a repository-proven guarantee. |
| Sequencing authority | Current and next sequencer addresses are read through `PreconfWhitelist.GetOperatorForCurrentEpoch/GetOperatorForNextEpoch` and its `Operators` mapping. The local builder checks its slot window. | **Proven [G10, G12–G14].** Incoming callback code does not independently prove the sender's exact historical sequencing window for every block; the P2P dependency is the remaining check boundary. |
| Parent linkage | Blocks must be beyond the L1-origin height and based on that canonical chain. A missing/noncanonical parent triggers cache lookup and peer requests; successful ancestor recovery permits import. | **Proven [G15–G17].** A node missing parent data cannot immediately conclude execution validity. It keeps an unresolved payload; absence is not proof of invalidity. |
| Execution validity | Local engine payload construction, `NewPayload`, and forkchoice updates must return `VALID`. | **Proven [G18].** **Assumed A-ENGINE:** the pinned Taiko-geth implements intended transaction, state-root, gas, anchor-execution and fork-specific consensus checks correctly. |
| Advertised hash equals locally executed result | The inserter rebuilds from envelope inputs and returns the engine-created block; the inspected insertion function does not explicitly compare that returned hash against `envelope.Payload.BlockHash`. | **Proven [G16, G18]** about the inspected function. **Open O-HASH:** verify the external gossip/engine combination supplies complete binding from signed advertised header to the executed result. This note does not assert an exploitable vulnerability. |
| Anchor shape | First transaction must target configured anchor; recovered sender must be golden-touch address; ABI selector must identify `anchor`, `anchorV2`, `anchorV3`, or `anchorV4`. | **Proven [G19].** This validator does not compare anchor arguments against the canonical L1 header, check proposal deadlines, or inspect execution receipts. Golden touch is a special system-transaction sender, not the preconfirmation operator signature. |
| Anchor correctness for L1 derivation | The derivation path reads the designated L1 block and constructs `anchorV4` using L1 number/hash/root and end-of-submission-window timestamp. Exact known-block matching checks the anchor transaction hash. | **Proven [G20–G21].** This later comparison is stronger than the earlier shape validator. **Assumed A-ENGINE** covers execution-time checks before landing. |
| Time | Structural preconf validator only checks nonzero timestamp. Local handover is wall-clock beacon slot based. Engine receives timestamp for execution. | **Proven [G09, G13, G18].** **Open:** a complete received-message future-skew/historical-authority audit requires the pinned P2P dependency and engine. Do not invent a time bound from this repository. |
| L1 canonicality | When a proposal lands, it becomes the derivation source and may replace a preconfirmed branch. L1 event hashes are separately checked for reorgs. | **Proven [G05, G22].** L1 inclusion is not proof verification or Ethereum finality. |
| Finality | Driver safe/finalized forkchoice fields use its last verified checkpoint, obtained from the inbox's `LastFinalizedProposalId` and a locally known L2 block. | **Proven [G23].** These Engine API labels do not prove that the containing L1 block reached Ethereum consensus finality; the lookup uses latest inbox state. |

**Proven implication of [G15–G18]:** Today's system permits local execution validation without waiting for batch landing **when the node has the ancestry/state and full payload**. It does not implement the stronger unconditional sentence “every node can immediately classify every received block as valid or invalid.” An orphan or a syncing node has a third state: unavailable/unresolved. Nor does locally executable mean that a competing or later L1-derived block cannot replace it.

**Open source-documentation discrepancy [G24]:** `pkg/preconf/payload.go` says its signature covers envelope bytes and points to `pkg/preconf/validation.go`; at this baseline the directory contains only `payload.go`, and the builder explicitly signs the header hash. The comment is not accepted as proof of wire semantics. Also, `HeaderDifficulty` is carried for Unzen's block ZK gas use, but this local envelope struct performs no validation itself.

## 3. Lookahead and alternatives

**Proven [G12–G14]:** `lookahead.go` maintains operator information for three epochs and computes half-open L1 slot ranges. For the current operator, the range ends `handoverSkipSlots` before the epoch boundary; for the next operator it begins there. The driver's default is eight skipped slots. It polls at `SecondsPerSlot / 3`, reads current/next operators from the whitelist contract when L1 advances, and refreshes the range data using `SlotsPerEpoch`. A missed-slot log uses a six-second wall-clock threshold. This is timing tied to CL slots/epochs even though the selected operator addresses come from the whitelist contract rather than from a CL validator proposer schedule fetched here.

**Proven [G13, G25]:** The local build endpoint calls the window check only when an L1 beacon client exists; the window checker allows by default when lookahead or beacon data is uninitialized. The cache loop skips entirely if the beacon client or P2P node is absent. The standalone Go proposer allows proposing without its configured whitelist client. These are configuration/development bypasses, not proof of a secure permissionless fallback protocol: on-chain admission rules still apply.

**Proven [G14, G26]:** Handover asks for an end-of-sequencing marker on P2P when the next sequencer starts without one. It is a synchronization aid, not an on-chain commitment or availability proof. Marker state is keyed by beacon epoch.

**Scope exclusion:** URC and any URC lookahead machinery are **removed in Etna**. The inspected Go lookahead is the current whitelist/handover path and must still be accounted for because it violates Etna's desired seconds-only, no-lookahead timing model if copied as-is.

## 4. Withholding, equivocation and reorgs

**Proven [G02, G15–G17, G26]:** Block creation and dissemination are separable. The build endpoint can insert a block and then fail to gossip it; disabling P2P also skips dissemination. A receiver who sees a child without its parent caches it, requests the parent by hash, and waits for enough ancestry. A node with the block can respond using the preserved original signature. Requests for blocks at/below the landed L1-origin boundary are ignored. Requests with no peer on the request topic are skipped rather than consuming the local duplicate-request cache entry.

**Proven [G17, G27]:** If another unsafe block at the same height has a different hash, `TryImportingPayload` logs the conflict and imports the incoming block; it does not freeze the height on first observation. If a child is based on an orphan, the server tries to reconstruct the required branch. This is explicit support for preconfirmation reorgs. The later L1-derived manifest can also force reconstruction of the chain and sets `PreconfChainReorged`.

**Proven scoped observation [G02, G15, G17, G26]:** These withholding recovery paths publish peer requests and update caches/heads. They contain no objective on-chain withholding challenge, bonded availability claim, or slash transaction. There is no measured false-positive/false-negative detector in the inspected Go path. Treating a request timeout as proof of a malicious operator would be a new and unjustified claim.

**Assumed A-NETWORK:** An honest synced node is connected to at least one peer that has and serves needed data. If no peer has it, local recovery cannot conjure a withheld block. If the attacker later reveals a complete signed branch beyond the L1-origin boundary, this code provides mechanisms capable of importing it; exact acceptance of old signatures depends on the external P2P authority/time rules noted above.

Concrete threat trace supported by the architecture:

1. The active authorized operator privately builds a valid chain beyond the last landed L1 origin and gives different peers different subsets (or withholds the whole suffix).
2. Honest peers have stale state or unresolved children and ask for missing parents. No local observation distinguishes intentional withholding from packet loss, partition, or a crashed operator.
3. A later authorized payload or L1 proposal reveals a branch inconsistent with an honest node's unsafe head. The driver can recover ancestors and replace unsafe blocks, or derive the L1 proposal afresh.
4. Users who treated unsafe execution as irreversible ordering, and off-chain provers who invested work before canonical L1 ordering, bear reorg/stale-work risk. The Go code does not make that risk slashable by itself.

**Status:** Steps 1–3 are a **proven possibility of the inspected control flow**, conditional on A-GOSSIP accepting the authorized messages. Economic MEV gain, practical exploitability against deployed builders, and exactly how far a delayed signature remains admissible are **open** and require the other client and dependency analyses. This is not a claimed deployed exploit.

## 5. Proving, failure and fallback

**Proven [G06, G28]:** Proving is triggered from a landed `Proposed` event; the designated prover is the proposal's proposer. The client also treats configured local proposer addresses as assignments it can fulfill. A nonassigned prover with `proveUnassignedProposals` enabled waits for the contract-derived proving window, then adds a 72-second local buffer before enqueueing recovery work. Without that flag, it skips unassigned proposals even after expiration. This is a client policy, not permissionlessness of the verifier contracts.

**Proven [G29]:** A proof request includes proposal ID, actual prover address, event L1 hash, the covered L2 block numbers, designated proposer, previous anchor-block number, and a checkpoint `{blockNumber, blockHash, stateRoot}`. The previous anchor state is read at the previous proposal's last block. Requests skip finalized proposals and defer proposals outside a configured range after the finalized head.

**Proven [G30]:** The normal proof path selects RISC0 or SP1 and requests a companion SGX-geth proof. A forced-SGX option selects an SGX primary. ZK-only mode requests SP1 plus RISC0, bypassing the RISC0 backlog fallback state machine. These are client modes; whether a pair is accepted is ultimately a verifier configuration matter.

**Proven [G31]:** When RISC0 falls too far behind, the client can enter SP1 fallback, clear RISC0 buffers/cache, and reenqueue affected proposals. It resumes RISC0 only when its backlog/finalized-head conditions permit. This fallback is different from replacing an absent assigned prover; it chooses another proof backend in an already-running prover.

**Proven [G32]:** The `prove` transaction commits the first proposal ID and parent block hash, last proposal hash, ending block number/state root, actual prover, and one transition per proposal containing proposer, timestamp and block hash. Aggregated IDs must be consecutive; the two subproofs are sorted by verifier ID before ABI encoding. There is no attached blob data in this transaction.

**Proven [G22, G33–G34]:** Before sending, the prover checks that the proposal's L1 event block is still canonical and that it has not already been finalized. These are optimistic checks: a competing prover can finalize it after the check. A reverted submission is counted and returned as `ErrUnretryableSubmission`; the outer prover clears/requeues buffers on reverts. Retry exhaustion in event handling rolls back the scan cursor so later rescans can recover work. This software prevents some stale work but provides no transaction-validity-level mutual exclusion and cannot eliminate race gas loss.

**Assumed A-PROVER-EXISTS:** After an assigned prover fails, at least one eligible, funded prover enables fallback work and can access the data/proof backend. The client alone provides no guarantee if all such processes are offline, economically unwilling, or blocked by a whitelist contract. Contract whitelist analysis belongs to the L1 note.

## 6. User guarantees by milestone

| Milestone | Guarantee supported here | Guarantee not established |
|---|---|---|
| Builder HTTP success | A local block was constructed/imported; publication may have been attempted. | Delivery to the whole network, global agreement, irreversibility. |
| Peer has authenticated envelope | Conditional on A-GOSSIP, an allowed operator signed the committed message/header. | Correct execution, full ancestry availability, no equivocation. |
| Synced node executes/imports | Conditional on A-ENGINE and O-HASH resolution, it has an executable branch extending the L1-derived boundary. | That the branch will land unchanged or cannot be replaced while unsafe. |
| Batch is included in L1 | The L1 proposal supplies the canonical derivation input for that L1 chain view. | A valid ZK proof is already included; Ethereum finality. |
| Inbox marks proposal finalized | The on-chain proof/finalization path has advanced, and the client can derive a verified checkpoint. | Finality of the underlying L1 transaction unless Ethereum consensus finality is separately checked. |

The entries are **proven interpretations** of the code cited above, with named external assumptions retained. They must not be shortened to “a preconfirmation is final after one second.”

## 7. Evidence table

All paths are repository-relative. Line ranges identify the exact code inspected, not generated bindings.

| ID | Material claim | Source |
|---|---|---|
| G01 | Build request route, readiness, parent and supplied payload fields | `packages/taiko-client/driver/preconf_blocks/server.go:259–267`; `packages/taiko-client/driver/preconf_blocks/api.go:72–140,160–205` |
| G02 | Sign built header hash, persist signature, publish; gossip failure/disabling does not undo insertion | `packages/taiko-client/driver/preconf_blocks/api.go:197–297` |
| G03 | Receive, validate, cache during synchronization, import | `packages/taiko-client/driver/preconf_blocks/server.go:271–374` |
| G04 | Standalone proposer txpool flow and blob proposal | `packages/taiko-client/proposer/proposer.go:169–228,231–283`; `packages/taiko-client/proposer/transaction_builder/blob.go:47–134` |
| G05 | Existing preconf match updates origin; differing derivation reconstructs and marks reorg | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/inserter.go:155–209,213–276` |
| G06 | Event-triggered proof scheduling after derivation | `packages/taiko-client/prover/event_handler/proposal.go:21–53,81–123,128–208` |
| G07 | Proposal interval and newer-L1-block wait | `packages/taiko-client/proposer/proposer.go:294–315,347–362` |
| G08 | Per-manifest-block timestamps and forced-inclusion request count | `packages/taiko-client/proposer/transaction_builder/blob.go:60–118` |
| G09 | Exact structural preconf validation and absence of signature/anchor-argument checking there | `packages/taiko-client/driver/preconf_blocks/server.go:955–1007` |
| G10 | Runtime P2P current/next sequencer address callbacks | `packages/taiko-client/driver/preconf_blocks/server.go:1034–1061` |
| G11 | External P2P initialization and pinned dependency | `packages/taiko-client/driver/driver.go:143–171`; `go.mod:308–310` |
| G12 | Whitelist operator resolves separate sequencer address | `packages/taiko-client/pkg/rpc/methods.go:916–957` |
| G13 | Build handover check and fail-open configuration behavior | `packages/taiko-client/driver/preconf_blocks/api.go:160–166`; `packages/taiko-client/driver/preconf_blocks/server.go:1080–1110` |
| G14 | Epoch history, slot ranges, handover width, polling and whitelist refresh | `packages/taiko-client/driver/preconf_blocks/lookahead.go:10–14,42–109`; `packages/taiko-client/driver/driver.go:37,87–89,381–443,445–497,549–559` |
| G15 | Missing-ancestor lookup, peer request, no-peer skip and canonical boundary | `packages/taiko-client/driver/preconf_blocks/server.go:774–849,857–895,903–916` |
| G16 | Preconf ancestry gate, engine payload reconstruction, signature storage, returned executed block | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:655–793` |
| G17 | Orphans, same-height conflicts, import and unsafe-head reorg | `packages/taiko-client/driver/preconf_blocks/server.go:1314–1345,1407–1496` |
| G18 | Engine payload construction and mandatory `VALID` responses | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:89–120,126–208` |
| G19 | Anchor shape validator: recipient, golden-touch sender, method | `packages/taiko-client/prover/anchor_tx_validator/anchor_tx_validator.go:25–40,43–75` |
| G20 | Canonical L1 header and anchorV4 construction from derivation | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:478–519` |
| G21 | Known-block match compares anchor hash, gas limit and timestamp | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:360–362,417–423` |
| G22 | L1 event canonicality check and pre-send finalization race checks | `packages/taiko-client/prover/event_handler/util.go:20–42`; `packages/taiko-client/prover/proof_submitter/transaction/sender.go:85–134` |
| G23 | Inbox-finalized checkpoint loading and Engine API safe/finalized fields | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/inserter.go:29–73`; `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/checkpoint_cache.go:127–140`; `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:102–110` |
| G24 | Envelope comment, signature and difficulty fields; missing-file reference is not authoritative | `packages/taiko-client/pkg/preconf/payload.go:9–29`; compare `packages/taiko-client/driver/preconf_blocks/api.go:241–247`; baseline file enumeration `git ls-tree 961bbd8ff55a0f66f44ad04160eb51638d655b66 packages/taiko-client/pkg/preconf/` |
| G25 | No whitelist configured allows standalone proposer; beacon/P2P absent skips cache | `packages/taiko-client/proposer/proposer.go:392–415`; `packages/taiko-client/driver/driver.go:385–391` |
| G26 | End-of-sequencing request and signed-block recovery | `packages/taiko-client/driver/driver.go:406–442`; `packages/taiko-client/driver/preconf_blocks/server.go:376–379,500–589`; `packages/taiko-client/driver/preconf_blocks/api.go:299–305` |
| G27 | Later L1 derivation explicitly signals preconf reorg | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/inserter.go:269–276`; `packages/taiko-client/driver/preconf_blocks/server.go:1288–1297` |
| G28 | Assignment identity, unassigned fallback flag, proving expiry and 72-second buffer | `packages/taiko-client/prover/event_handler/proposal_handler.go:67–70`; `packages/taiko-client/prover/event_handler/proposal.go:141–206`; `packages/taiko-client/prover/event_handler/util.go:18,45–65`; `packages/taiko-client/prover/event_handler/assignment_expired.go:33–59` |
| G29 | Proof request checkpoint, previous anchor state, finalized and window gates | `packages/taiko-client/prover/proof_submitter/proof_submitter.go:143–198,203–270` |
| G30 | Primary/companion proof mode choice | `packages/taiko-client/prover/proof_submitter/proof_submitter.go:273–311` |
| G31 | RISC0/SP1 backlog fallback, draining and requeue | `packages/taiko-client/prover/proof_submitter/risc0_sp1_fallback.go:88–151,158–177,212–270` |
| G32 | Proof commitment fields, consecutiveness, ordered subproofs, separate calldata-only prove transaction | `packages/taiko-client/prover/proof_submitter/transaction/builder.go:36–160` |
| G33 | Revert receipt and race-cost handling | `packages/taiko-client/prover/proof_submitter/transaction/sender.go:45–82`; `packages/taiko-client/prover/prover.go:310–349` |
| G34 | Retry exhaustion rolls cursor back for rescan | `packages/taiko-client/prover/event_handler/proposal.go:81–123`; `packages/taiko-client/prover/prover.go:384–440` |

## 8. Constraints to carry into synthesis

1. **Proven:** Preconf validity must separate authentication, available ancestry, execution, canonical landing and finality. A missing ancestor is unresolved, not cryptographically invalid.
2. **Proven:** Current local unsafe-chain behavior admits reorgs; an authenticated preconfirmation is not an irrevocable ordering guarantee.
3. **Proven:** Slot/epoch handover and the whitelist-sourced identity cache must be replaced to meet R1/R5; disabling those checks is not a security construction.
4. **Proven:** Current proof generation is causally downstream of L1 proposal and derivation. R7 needs a different commitment/anchor/proving input boundary, not simply a multicall around today's `propose` and `prove`.
5. **Proven scoped conclusion:** The inspected client provides best-effort missing-data recovery, not attributable/punishable withholding.
6. **Open:** Complete current signature/hash/time validation lives partly in pinned external P2P/engine repositories. An implementation-ready replacement must explicitly specify those predicates rather than inherit this gap in evidence.
