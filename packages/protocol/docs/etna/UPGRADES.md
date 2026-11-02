# Etna upgrade activation

These definitions are incorporated by [SPEC section 10.1](SPEC.md#101-protocol-upgrade-boundaries). Each section and its fenced definitions belong to its governing rule. SPEC.md takes precedence. Unzen-to-Etna deployment/migration and section 8's exceptional verifier-failure rollback are separate.

## 1. Upgrade classes

<!-- governed-by: START-10.1-1 -->

An **ordinary EL fork** changes only EL execution rules or parameters, including gas/zk-gas metering. It preserves consensus envelope/header, statement and cut encodings, K, committee/epoch rules, signing domain, Comet genesis/consensus parameters and deployment-immutable values. Each block uses old rules below timestamp T and new rules at/above T, using its own timestamp. Local clocks, L1 submission and proof-completion times do not select rules. Production and proof batches may cross T without stopping or settling exactly there; validity and back-pressure still apply.

A **structural upgrade** changes other validity/app/committee rules, including K. Old rules apply through checkpoint H, new rules from H+1. Supported in-place upgrades preserve the Inbox/router, the fixed statement/ABI, signing domain, genesis, consensus parameters, appendix B layouts and deployment immutables. They may change compatible implementation code and deterministic app metadata. A change requiring different immutable interfaces, statement/header encodings, storage layouts or signer/genesis state is **unsupported in place**: section 10 requires separate deployment of an Inbox/genesis and compatible registry, plus an independently specified migration. A checkpoint alone supplies no cross-deployment migration protocol; this specification does not define one or authorize bypassing START-10-24.

**Verifier maintenance** changes proof implementations, images or backend dependencies while preserving exact rules/structure/encoding commitments. The owner authorizes an exact replacement policy for an existing schedule, without T/H. It may repair proving of an authorized schedule. Backend image registration alone is insufficient; validity changes cannot be maintenance.

L1 forks have an external deadline. Header fields already tolerated by 3.3 need no upgrade. Same-rule proof fixes use maintenance, with compatible client releases where needed; EL-only rule changes use T. L1 witness/state-commitment or authenticated-encoding changes are structural, subject to the in-place restrictions above. Required clients, guests, authorized policies and activation or separately specified deployment/migration must be ready before L1 activation. An L2 trigger cannot defer L1's deadline.

## 2. Canonical on-chain plan

<!-- governed-by: START-10.1-4 -->

The Inbox stores an append-only journal. Plan 0 is the active baseline, pinning original rules, structure, proof policy and executor. Each plan is exactly the following canonical ABI tuple, without trailing bytes:

```txt
UpgradePlan = (
  uint256 nonce, bytes32 previousPlanHash,
  uint8 kind, uint48 authorizedGeneration, uint48 epochStartHeight,
  uint256 boundary,
  bytes32 oldRulesHash, bytes32 newRulesHash,
  bytes32 oldStructureHash, bytes32 newStructureHash,
  uint8 oldK, uint8 newK,
  address activationExecutor, bytes32 activationExecutorCodeHash,
  address policyVerifier, bytes32 policyVerifierCodeHash,
  bytes32 imageSetHash, bytes32 artifactManifestHash,
  bytes32 migrationHash, bytes32 policyTargetPlanHash
)
kind = 0  // baseline only: nonce/boundary/epochStartHeight = 0; previousPlanHash = 0
kind = 1  // ordinary EL fork; boundary = T
kind = 2  // structural upgrade; boundary = H
kind = 3  // maintenance; boundary = 0; target is a kind 0, 1 or 2 planHash
planHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_PLAN_V1"),
  uint256(l1ChainId), uint256(l2ChainId), address(inbox), address(registry), UpgradePlan))
```

rulesHash hashes the exact published canonical rule descriptor, including retained schedules; structureHash hashes the structural descriptor for section 1. Descriptors exclude their own hashes and guest-image/verifier-code/manifest hashes. artifactManifestHash hashes exact published manifest bytes. The manifest pins reproducible source/build identities, rules/encodings, verifier, image tuples and retained schedule; it contains neither its own hash nor final planHash and grants no authority. Guests need not embed their own image hashes.

The immutable policy verifier exposes `policyIdentity() -> (bytes32 rulesHash, bytes32 structureHash, bytes32 imageSetHash)`, equal to the plan's `(newRulesHash, newStructureHash, imageSetHash)`, and `imagePolicies() -> ImagePolicy[]`. **At installation** the Inbox obtains this canonical array, checks its hash/identities/revocations and caches its exact tuples under planHash. It is sorted strictly by keccak256(abi.encode(tuple)), without duplicates:

```txt
Dependency = (address verifier, bytes32 codeHash)
ImagePolicy = (uint8 backend, address verifier, bytes32 verifierCodeHash,
  bytes32 blockImageId, bytes32 aggregationImageId, Dependency[] dependencies)
imageSetHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_IMAGES_V1"), ImagePolicy[]))
// backend: 0 SGX, 1 RISC0, 2 SP1. Dependencies are strictly address-sorted,
// immutable, and checked against live code hashes.
```

The manifest publishes the array. Zero image ID means an unused layer, never a wildcard; SGX uses its authenticated measurement/instance-policy identifier. Backend verifiers extract identities from authenticated proofs/attestations. Exact plan membership is an additional restriction: backend allowlists cannot widen it, but native instance validity, allowlists and revocation may narrow or disable it, including SGX instance revocation. Mutable proxy dependencies are unsupported. Each policy requires exactly two distinct-backend sub-proofs, at least one ZK. Nodes/tooling check that the pinned programs implement the declared complete schedule. Installation and worst-case verification must fit the deployment's L1 per-transaction limit.

The initial structural epoch starts at 0; a structural activation creates one at H+1. A timestamp plan preserves structure/K, zeroes migrationHash/policyTargetPlanHash, and uses T greater than every activated trigger. A structural plan zeroes policyTargetPlanHash and inherits activated timestamp history. Maintenance preserves old/new rules, structure and K, zeroes migrationHash, and targets a noncancelled baseline/timestamp/structural record with those commitments, possibly pending or in a historical epoch. It never widens its target's validity range. All plans preserve the baseline executor. Checked widths/arithmetic reject truncation, overflow or incompatible plans.

## 3. Authority, journal and non-retroactivity

<!-- governed-by: START-10.1-5 -->

The pinned immutable executor is the **actual owner of Inbox, registry and L1 SignalService**. The DAO/timelock (through its Controller where used) controls its governance-call entry point; the Controller is not a second proxy owner. Deployment checks all three ownership links and executor code hash. The permissionless structural entry point executes only a committed, installed plan; it cannot forward arbitrary governance calls. Normal mutations share land/recover protection. Inbox nonpayable interfaces are:

```txt
installUpgradePlan(bytes plan, bytes artifactManifest,
  uint256 expectedNonce, bytes32 expectedPreviousPlanHash, uint48 expectedGeneration)
cancelUpgradePlan(bytes32 planHash, uint48 expectedGeneration)
replaceTimestampPlan(bytes32 oldPlanHash, bytes replacementPlan, bytes artifactManifest,
  uint256 expectedNonce, bytes32 expectedPreviousPlanHash, uint48 expectedGeneration)
beginStructuralUpgrade(bytes32 planHash)
activateStructuralUpgrade(bytes32 planHash, bytes migrationDescription)
revokeProofPolicy(bytes32 imageSetHash)
revokeImage(uint8 backend, uint8 layer, bytes32 imageId) // 0 block, 1 aggregation
getUpgradePlan(uint256 nonce) -> (bytes plan, uint8 status)

RecoveryTimestampAction = (uint8 mode, bytes32 expectedPendingPlanHash,
  bytes replacementPlan, bytes artifactManifest)
// mode 0: preserve; hash = 0 and both byte arrays empty
// mode 1: cancel; both byte arrays empty
// mode 2: cancel and install the replacement
recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil,
  Exclusion[] exclusions, uint256[] fiToClear, bytes timestampPlanAction)
// timestampPlanAction is exactly abi.encode(RecoveryTimestampAction), one dynamic tuple with outer offset 0x20.
```

Only the actual owner installs, cancels, replaces or revokes. Installation checks nextNonce/lastPlanHash against both expected and tuple values, and expectedGeneration = plan.authorizedGeneration = current generation. Kind 1/2 use the current epoch/effective predecessor; maintenance matches its target epoch/commitments. It validates manifest/code/policy commitments, increments nextNonce and appends exact bytes with UpgradePlanInstalled. Nonces never wrap/reset; cancellation/staleness never deletes journal bytes. Off-chain configuration supplies no authority.

At most one validity-changing kind 1/2 plan is pending globally; maintenance/revocation remain available. A timestamp is pending until a successful landing first proves lastTimestamp >= T, then becomes active. Its rules apply to blocks at/above T from installation, irrespective of status. No new structural plan is installed while it remains pending; safe cancellation or the atomic recovery action below supplies an exit.

Timestamp installation requires `0 < T < 2^64`, `block.timestamp + maxAnchorAge < T <= block.timestamp + maxTimestampLead`. Both sums must fit uint64. maxTimestampLead is a finite deployment-pinned interval in seconds, greater than maxAnchorAge, published/tested at launch; no default/unit conversion is inferred. An anchor before publication cannot validly reach T under 3.4, so crossing T requires an anchor able to authenticate publication. This does not guarantee readiness/finality.

Without recovery, pending timestamps may be cancelled/replaced only while `block.timestamp + maxAnchorAge < T`. Check current generation/pending hash and arithmetic. Cancellation restores the predecessor schedule; replacement atomically cancels and installs a fresh nonce/head with all installation checks. No valid block anchored before that cancellation can have reached T. At/after equality this ordinary API rejects cancellation, even without a post-T landing.

**Recovery is a separate atomic exit.** The DAO's existing recover authorization binds the entire timestampPlanAction, in addition to expected generation/checkpoint/recoveryNonce/deadline and lists. Modes 1/2 require the exact current pending kind-1 hash and **T > checkpointTimestamp** read at execution. Thus no retained checkpoint has used those rules. The same recover discards the entire unsettled suffix, increments generation, cancels the pending plan and removes its active route without rewriting retained history. Mode 2 then installs the supplied replacement at a fresh journal nonce/head, authorizedGeneration equal to the new generation and all normal timestamp lead/rule/code checks satisfied. It need not exceed the cancelled T. Any failure reverts recovery, cancellation and replacement together. Mode 0 preserves the pending timestamp. An activated timestamp or T <= checkpointTimestamp cannot be removed by this path. It does not repair a bad landed checkpoint; that remains verifier-failure rollback.

Structural installation requires H >= current checkpoint + U, H+1 < 2^48, common old/new-K divisibility and unchanged U/maxBatchBlocks compatibility. **Installation itself is complete DAO/timelock authorization** of the planHash, generation, H and migrationHash, including the executor identity. It sets the persistent fence. There is no second authorization, expiry, renewal or authorization nonce. Anyone may trigger the exact committed execution at c=H. Cancellation or generation change invalidates a pending plan permanently; activated history survives. Recovery clears a stale structural pending pointer/fence, preserves the journal, and handles any pending timestamp only through the explicit action. Proof replacements/revocations survive recovery and verifier-failure handling. Exceptional rollback restores checkpointTimestamp from the independently authenticated last-trusted header and reconciles pending status/routes to the retained prefix without reviving cancelled/stale authority; it is not the ordinary recovery action.

Metadata uses ERC-7201 namespace `taiko.etna.upgrades`, base UPGRADE_BASE, outside appendix B reserved slots. UPGRADE_BASE is erc7201("taiko.etna.upgrades"), using the [ERC-7201 root formula](https://eips.ethereum.org/EIPS/eip-7201), and is distinct from the unsettled-block limit U. Each declaration occupies one successive full slot (no packing):

```txt
uint256 nextNonce                                      // UPGRADE_BASE+0
bytes32 lastPlanHash                                   // UPGRADE_BASE+1
mapping(uint256 => bytes) plans                        // UPGRADE_BASE+2
mapping(bytes32 => uint8) status                       // UPGRADE_BASE+3
uint256 pendingValidityNoncePlusOne                    // UPGRADE_BASE+4
address activationExecutor                            // UPGRADE_BASE+5
bytes32 activationExecutorCodeHash                     // UPGRADE_BASE+6
uint256 maxTimestampLead                               // UPGRADE_BASE+7
uint256 checkpointTimestamp                            // UPGRADE_BASE+8
uint256 structuralFence                                // UPGRADE_BASE+9
mapping(bytes32 => bytes32) policyReplacement           // UPGRADE_BASE+10
mapping(bytes32 => bool) revokedPolicies                // UPGRADE_BASE+11, imageSetHash
mapping(bytes32 => bool) revokedImages                  // UPGRADE_BASE+12, hash(backend,layer,imageId)
EpochRoute[] structuralRoutes                          // UPGRADE_BASE+13
mapping(uint48 => TimestampRoute[]) timestampRoutes     // UPGRADE_BASE+14, key epochStartHeight
mapping(bytes32 => ImagePolicy[]) cachedImagePolicies   // UPGRADE_BASE+15, key planHash
EpochRoute = (uint256 startHeight, bytes32 planHash)     // two words per element
TimestampRoute = (uint256 T, bytes32 planHash)           // two words per element
```

structuralFence is zero when inactive, otherwise `uint256(generation) << 48 | H`, with 0 < H < 2^48, generation < 2^48 and unused high bits zero. Structural installation writes it atomically with the pending plan. Cancellation, activation or recovery invalidation clears it atomically. The fixed slot UPGRADE_BASE+9 is included in every anchor witness under appendix A; inherited anchors inherit the proven scalar. For **each block**, a nonzero fence of that block's generation requires height <= H. A later clearing cannot change the value authenticated at an earlier anchor. A malformed scalar invalidates the witness.

Status is 1 active (baseline/maintenance included), 2 pending, 3 cancelled. Only pending structural records become effectively stale on generation mismatch. Baseline old/new commitments/K agree, migrationHash/policyTargetPlanHash are zero, nextNonce=1, lastPlanHash=baseline hash, pending/fence/mappings otherwise empty, checkpointTimestamp=genesis EL timestamp, and executor/maxTimestampLead come from deployment. Nodes/guests check genesis timestamp/hash correspondence. Baseline initializes structuralRoutes with (0, baselineHash). Installation appends a timestamp route; cancellation (ordinary or recovery) removes only that last pending route, retaining its journal. Activation appends (H+1, planHash) to structuralRoutes and starts an empty timestamp-route array whose baseline program retains prior schedules. Arrays are strictly increasing; lookup uses binary search by h and lastTimestamp, not journal scans. Getters expose state, exact bytes, cached policies and routes. Events publish journal/status/route/fence/revocation changes. land atomically updates checkpointTimestamp and any newly active timestamp status after both proofs verify.

The executor and Inbox keep their matching execution contexts in **transient storage** keyed by keccak256("taiko.etna.upgrades.executionContext"); it is not a persistent namespace slot. The Inbox getter structuralExecutionContext() returns that transient value during execution and zero outside it. Registry ordinary mutations consult it for the shared guard. The persistent structuralFence is distinct from this transaction-local lock.

## 4. L1 proof routing and timestamp binding

<!-- governed-by: START-10.1-13 -->

The immutable router verifies a fixed landing statement: **22 static ABI words, 704 bytes**, domain TAIKO_ETNA_LAND_V1. LandInput has nine fields, including uint256 lastTimestamp. Require lastTimestamp < 2^64. Both guests prove it equals the timestamp of the terminal executed EL header whose hash/stateRoot are lastBlockHash/lastStateRoot, and authenticate the same complete statement.

```txt
proof = abi.encode(bytes encodedStatement, uint256[2] policyIndices, bytes twoProofs)
```

The wrapper is canonical without trailing bytes, encodedStatement is exactly 704 bytes, and its hash equals the Inbox commitment from input/origin/blobs/cuts. The router decodes the fixed format and full chain/deployment/generation identity. Unsupported lengths/domains or failed bindings revert. Statement fields determine range routing; the two indices identify only cached policy members. No per-epoch statement adapter or L1 header parser is required. Different immutable interfaces are unsupported in place under section 1.

Binary-search the structural route containing h, reject p < H < h at a boundary, and enforce the current same-generation fence. In that epoch binary-search the latest active/pending timestamp route with T <= lastTimestamp, otherwise use its baseline. Apply the direct maintenance replacement for that selected plan. New complete-schedule programs prove each block's retained rules, including mixed-T batches; old-only policies are eligible only below T, regardless of submission time.

The two indices are untrusted selectors into the **cached exact policy**. Bounds-check each, authenticate its extracted backend/layer/image identities against that tuple, require distinct backends and at least one ZK, and recheck selected verifier/dependency code hashes, policy identity and native backend validity. The policy exposes verifySelectedProofs(bytes32 statement, uint256[2] indices, bytes proofs), which verifies both proofs and returns their authenticated backend/layer/image identities for comparison with the cached tuples. Only the two selected tuples and their dependencies are read; land does not re-enumerate/hash imagePolicies() or scan history. Changing cached tuples is forbidden; maintenance installs a fresh plan/cache and updates the direct replacement mapping.

Global policy/image revocation is independent of claimed timestamp, epoch and generation. Reject a revoked imageSetHash or used `(backend,layer,imageId)`; repackaging a revoked image does not help. Installation rejects arrays containing revoked keys. Revoked unused tuples need not disable sound alternatives in the same policy; every actually used tuple must pass. Maintenance can replace exact same-rule proof implementations for unlanded historical ranges, without widening ranges. Revoking the only available combination stops settlement. Already accepted false landings require SPEC 8's exceptional handling, not trust in a compromised timestamp. **Both guests additionally prove every block's historical anchor-fence check under 3.4/6.2; a currently cleared fence cannot waive it.** Any failure reverts land and all timestamp/status updates.

## 5. Structural fence and atomic activation

<!-- governed-by: START-10.1-8 -->

Signers refuse above-H proposals/votes while the authenticated same-generation fence is live, retaining HRS/WAL. Missing/unfinalized L1 data causes an untrusted wait and FinalizeBlock retry under SYNC-9-2, not a safety halt. A decided block whose cited canonical anchor positively proves a same-generation fence with height > H is invalid and safety-halts. Nodes and both guests verify the fixed scalar witness; later cancellation cannot legalize it. Fence release by finalized activation/cancellation, followed by all ordinary trust/readiness checks, automatically restarts a signer-backed Comet process that previously refused; it never resets signing state or bypasses a still-live fence. No new slashing offence is created.

The executor exposes permissionless executeStructuralUpgrade(planHash,migrationDescription). It checks the installed pending plan, current generation and pinned owner/code identities, latest checkpoint exactly H and consistent retained landings[H]/SignalService checkpoint. EL/Comet hashes, FI cursor and stateRoot are read on-chain inside execution, not supplied as future governance arguments. Missing/mismatching records, wrong generation, c<H/c>H, cancelled or already active plans revert.

```txt
Call = (address target, uint256 value, bytes data)
Assertion = (address target, bytes data, bytes expectedReturnData)
Migration = (Call[] calls, Assertion[] assertions)
migrationHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_MIGRATION_V1"), Migration))
context = keccak256(abi.encode(bytes32("ETNA_UPGRADE_CONTEXT_V1"),
  uint256(l1ChainId), uint256(l2ChainId), address(inbox), address(registry),
  planHash, currentGeneration, H, ELHash, CometHash, migrationHash))
```

Canonical migrationDescription must match migrationHash. Calls are ordered, value=0, success required, cannot target executor, and may only perform the committed compatible implementation/metadata upgrade. Assertions are successful read-only STATICCALLs with byte-for-byte expectedReturnData comparison; a revert or mismatch fails execution. They may check fixed code/implementation/layout/config identities; **they must not pin user-mutable values** such as FI tail or registry count at authorization time. Such values are compared only before/after within the execution transaction. User activity before execution cannot invalidate an assertion about a fixed identity.

The executor establishes its transient context, enters beginStructuralUpgrade and holds the shared Inbox/registry guards through final activation. Ordinary land/recover/nonce/plan/queue/registry/withdrawal mutations reject while the guard is held. Committed implementation calls and matching activation are the only exceptions. Activation checks actual owner, live executor code hash, matching derived contexts, plan/generation/checkpoint/fence and clears context/guard while marking active, clearing pending/fence and appending the epoch. Any failed call/assertion/check reverts the entire transaction. The installed journal nonce/status and generation prevent replay; there is no expiring authorization.

**Checks are bounded, with no storage-history scan.** If Call[] is nonempty, take a runtime snapshot before calls and compare afterward: deployment/proxy owners and pinned code/config identities; genesis/config scalars, delays including slot 282, generation/recoveryNonce, current origin, checkpoint and H's three-word landing/SignalService record, FI head/tail and activeCommitteeSnapshot; namespace counters/head/pending/fence/checkpointTimestamp, routing-array lengths/latest entries and executor/maxTimestampLead; registry configuration plus current checkpoint length/latest record/count/root. The pinned executor fixes this scalar read set and its getters/slots; expected new implementation hashes are checked by the committed assertions, rather than compared to the old implementation. The checker reads a fixed number of scalar words/code hashes independent of registry occupancy, FI backlog, number of landings or plans. Deployment acceptance bounds that cost under the L1 transaction limit. **For empty Call[], skip this snapshot**; core activation, context, code and immutable-identity assertions still apply, and all history stays untouched.

Historical landings/plans/queue entries, registry principal/ownership/exits/top-ups/forfeiture flags and fixed appendix B layouts must remain preserved. This is a requirement on the DAO-reviewed implementation and migration write set; the bounded checker **does not prove equality of arbitrary historical mappings**. It must not claim such a proof or attempt an unbounded scan. Any migration requiring a different physical protocol layout is unsupported in place. As in SPEC 1, malicious DAO-controlled proxy code/getters can bypass the specification; these checks do not remove that trust assumption.

Nodes preserve fixed origin, signed HRS/WAL, EL/Comet history through H and committed current/pending validator transitions with H+2 activation. Deterministic compatible app metadata may be converted; incompatible signer/genesis/transitions require separate deployment and a separately specified migration. Nodes authenticate finalized activation and H before H+1. Emit StructuralUpgradeActivated(planHash,H,ELHash,CometHash); unfinalized inclusion is insufficient.

## 6. Jobs, failures and acceptance

<!-- governed-by: START-10.1-15 -->

Jobs bind deployment, generation, plan/rules, statement/config/image versions and (p,h]. Ordinary jobs may cross T with complete-schedule programs; structural jobs never cross H and post-H work requires activation. Old-only jobs remain eligible solely in original ranges under current exact replacements/native validity/global revocations, regardless of submission time. Never relabel a job; historical artifacts support replay, not revoked-image acceptance.

Before T, validate both rule paths, mixed-boundary real two-proof capacity and node/signer readiness. Early ordinary cancellation is permitted under section 3. After its window, repair the authorized rules or use atomic recovery cancellation/replacement only for T>checkpointTimestamp, discarding the unsettled generation. No silent fallback or retained-prefix rewrite is allowed. Failed structural execution leaves the plan/fence intact and can be retried without a new governance cycle. The owner may cancel; a new boundary needs a fresh plan. Activation/cancellation release triggers automatic readiness-gated restart. Activated-rule reversal needs new authority or SPEC 8 exceptional handling. Neither trigger guarantees zero downtime.

[Upgrade acceptance](ACCEPTANCE.md#upgrade-activation-spec-101) requires canonical ABI/storage/fence witnesses, recovery actions, exact T/H bounds, installed authorization, bounded migration under maximum user-populated state, automatic fence-release restart, real mixed proofs, historical fence rejection after cancellation, cached routing/revocation, finality, overlap and signer persistence. Implement and pass it before exercising upgrades.
