# Etna architecture — revised candidate

This is the mechanism map; exact encodings and predicates are in the HTML reference. The [revision-1 change set](revision-1.md) records the response to the first independent review. No convergence or launch claim is made by this map. Proposed rules are specifications under A-IMPLEMENTATION; mathematical consequences, assumptions and unresolved evidence are labelled in the reference.

## Chosen boundary

Strict based sequencing: L1 chooses among valid available proof-bearing successors. There is no exclusive sequencer, external voting quorum, CL lookahead or mandatory private relay. Any address can stage, authorize and relay a valid candidate; optional bonded publisher/custodian/worker services create objective duties but no canonical priority. A canonical producer must authorize the exact statement; merely naming a payment beneficiary does not establish assent.

R7 is interpreted literally: the canonical action carries complete matching DA and a valid ZK proof atomically. A **prior nonexclusive generic DA publication is now required**, and a full copy is published again at canonical acceptance. It reserves no head/order and creates no unproved canonical block. This increases cost and latency; it does not claim one total transaction from first broadcast to finality. A stronger prohibition on all earlier L1 copies would require revisiting this candidate.

## Core state and public staging

- A unique accepted Head and immutable AcceptedReceipt bind exact parent, terminal L2 hash/root/number/time, origin, force cursor and snapshot, revision and execution context commitment. Head.segmentCommitment=contextHash/taskHash, not the payment-dependent statement hash; the receipt separately retains that full hash. Payment/job/producer/stage-salt choices cannot change a sealed execution head or stale its identical-execution descendants.
- The DARegistry records an actual current-transaction blob or complete bounded calldata plus the complete StageContext. A deterministic salted stageId is computable before L1 inclusion. Immutable first-context publication supports deadline evidence; immutable per-stage receipts support fresh restaging without resetting old deadlines.
- StageContext binds all execution-affecting fields, including exact parent, terminal outputs, origin, forced interval, DA/manifest and block-hash commitments. It excludes producer/payment/job assignment and stageId. taskHash equals its domain-separated hash. Exact schema is in staging.html.
- Canonical acceptance requires the chosen stage to be at least360 and at most900 seconds old, its exact context/data relationship, a valid producer authorization, a sound full execution proof and complete republication. Staging alone publishes no checkpoint, reserves no sequence and cannot lock recovery.
- Blob mode is one actual blob, full canonical field-vector/KZG binding inside the proof; calldata mode body≤32768 bytes. Complete blob body≤122880 bytes, proof≤16384 bytes, calldata envelope≤65536 bytes. Full encoding, padding and resource conformance remain launch measurements.
- HeaderStore pins a canonical RLP execution header while its nonzero EVM BLOCKHASH is available, storing its immutable authenticated root/time/hash. No CL schedule is used. Origins are nondecreasing; the same number requires the same header. Origin reuse allows early-sealed segments without waiting for an L1 block. Origin age≤900 seconds at landing; L2 block time≤origin.timestamp+60 and≤landing time.
- Up to60 blocks per segment,120M aggregate gas,10M per block. One-second issue target under named network/execution assumptions. A local900-block unsafe horizon bounds speculative exposure; staging/proving run in a pipeline. Healthy illustrative landing7–8min, bounded-inclusion example≈660s plus header acquisition, not a measured SLA.

## Local validity and canonical competition

A full node verifies signature/domain, any advertised preexisting reserve, parent linkage, authentic anchor, complete bytes, per-block consensus/header rules and EVM execution. Known-invalid is INVALID; absent dependencies are UNKNOWN; a correct candidate is VALID_IN_VIEW. No global first-received fork choice exists. Soft users may lose a branch; bridge settlement only uses proof-authenticated checkpoints and L1 finality.

All canonical data must be publicly available for the maturity interval. This removes the first-reveal-at-landing trace, not privately performed computation or ordinary public competing branches. A node that sees missing promised bytes refuses soft acceptance, requests/retrieves data and may challenge an actual signed obligation. It does not manufacture on-chain evidence of global P2P absence.

## Frozen forced FIFO

A request publishes its≤2048-byte raw L2 transaction on L1, gas bound1M, and records immutable timestamp/block/index. Each Head freezes exact queue tail at its fixed origin; boundary records uniquely authenticate that cut. A child consumes exactly up to4 due requests below the parent cut, in order before discretionary transactions. Maturity120s; state-invalid requests have deterministic proved rejection outcomes; valid reverts count as execution attempts. No admin void or expiry.

Origin freshness, rather than strict per-segment advancement, forces a progressing chain to expose new snapshots. Under successor spacingΔ, an item with p predecessors is processed by t_enqueue+1020+(1+ceil((p+1)/4))*Δ. New arrivals cannot add predecessors. No uniform short delay or progress with zero capable funded provers is promised.

Fee0.001ETH×(1+floor(pending/50)); half credits the proof-bound processor, half enters an irreversible nonwithdrawable ETH sink. A self-processing attacker cannot recover that half. At empty queue,1000 enqueues without intermediate consumption charge10.5ETH, sink5.25ETH, plus L1/proof/DA costs. Interleaved enqueues/consumption require a separate cost path; the quadratic fill cost is not falsely applied to every strategy.

## Duties, penalties and economic scope

- Optional buckets:60 positions,10TAIKO per position,600 total; issuance60s, retention1200s, evidence3600s, challenge response600s. Fixed immutable key/history, no liability reset on rotation. Exact capacity-overlap capital model is in roles.html. This replaces revision0's60.48million-TAIKO continuous-signer burden.
- A served block/fragment claim retains bounded calldata publication challenges. Each fragment≤32768 bytes; four cover the segment cap. Q=2×4M×(opening basefee+2gwei) ETH is paid by the challenger; timely actual responder receives Q. Shared-digest duplicates refund lazily. Failure refunds Q and slashes the reserved position10%reporter/90%permanent TAIKO sink. No mint or conversion oracle.
- A separate sealed-context publication-by claim signs the known contextHash, with publishBy=issuedAt+240s. An actual matching first-context publication by that time discharges it; later publication cannot cure default. It is not an unsupported mapping from an early block's keccak to a future blob hash.
- Explicit producer authorization plus accepted block-root membership can prove contradiction of the same owner's signed block in the exact matching base-head/revision/height context. Naming that owner as beneficiary is insufficient. Cross-address and cross-segment attribution gaps are disclosed; public-stage eligibility independently applies to every accepted segment.
- Proof jobs remain voluntary and nonexclusive.1000TAIKO worker reserve, positive sponsor bounty, offer expiry600s. At acceptance require exact stage/context and parent; deadline=max(acceptedAt+300,stage.publishedAt+480). Both stage and origin must remain valid through deadline+120. Historical parent consumption and revision retirement determine success/cancellation/default; late changes never erase earlier misses.
- All liabilities are≤held assets, separately per token. Direct donations are uncredited surplus and cannot block exits. Withdrawals pull credits after settlement; no owner sweep. Position loss is capped once; finite service penalties are not insurance against unlimited external MEV.
- Anti-capture mechanisms are zero canonical exclusivity, no finite role capacity to squat, linear finite service exposure, mandatory FIFO, irreversible congestion-priced queue cost and open staged/proof entry. They do not prove separate beneficial owners or fair/profitable outcomes for every prover. Staging spam costs real L1 data/state resources but can still burden observers; no node is promised capacity to prove every competing stage.

## Existing custody and migration

Reuse Bridge, SignalService and ERC20/ERC721/ERC1155 Vault addresses on both layers; retain Anchor proxy. Exact saveCheckpoint(tuple(uint48,bytes32,bytes32)) provenance and every shared upgrade/storage obligation are in migration.html. Remove operational owner pause/mint/remapping/resolver/quota/fee powers; owner governs upgrades only. Preserve historic statuses/cache/checkpoints/version and legacy bond units.

Finite permissionless legacy drain freezes old proposal/forced tails, settles historical commitments with immutable ZK keys, then activates Etna objectively. The first new Anchor transaction is beginEtna with authenticated new-Inbox ACTIVE evidence; later blocks use anchorEtna. No timeout fabricates a checkpoint or deletes legacy obligations. Live deployment/code/layout/DA compatibility and actual migration proof witnesses must be established before launch.

## L1 dependencies and reviewed boundary

Frames8141 are assumed available but optional for liveness. A four-frame private sender/payer/action/terminal-VERIFY envelope makes stale/failed losers transaction-invalid under the analyzed draft; current public mempool policy excludes that terminal shape. Ordinary atomic public submissions remain available and can revert/pay gas. ePBS/BAL/FOCIL/shorter production intervals add no role-assignment dependency. Gas/DA/proof limits must obey the actual activated fork.

The first review found one High withholding gap, one Medium cadence gap, one Low surplus inconsistency and one Medium economic gate. The changed mechanisms require fresh independent review. No theorem makes literal R1–R7 impossible; no readiness verdict is justified before the required convergence process.
