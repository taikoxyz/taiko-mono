# Etna upgrade activation

**Non-normative preamble.** Normative definitions begin in section 1. These definitions are incorporated by [SPEC section 10.1](SPEC.md#101-protocol-upgrade-boundaries). Each section and its fenced definitions belong to its governing rule. SPEC.md takes precedence. Unzen-to-Etna deployment/migration and section 8's exceptional verifier-failure rollback are separate.

## 1. Upgrade classes

<!-- governed-by: START-10.1-1 -->

Supported **validity-changing upgrades** governed by this document use one workflow: publish timestamp T, execute old rules through the first eligible checkpoint H whose EL timestamp is at least T, pause above H, settle H on L1, then activate new rules from H+1. T triggers a checkpoint pause; it never selects new execution rules by itself. Blocks at/above T through H still use old rules. Local clocks, L1 submission and proof-completion times do not select H. A stalled chain cannot reach H merely because wall-clock T passed, and no exact-time or zero-downtime guarantee is made. Separately specified exceptional DAO implementation upgrades for verifier failure or an activated-rule stall are outside this workflow; this document does not define their repair or migration procedure.

An **ordinary EL fork** changes only EL execution rules or parameters, including gas/zk-gas metering, preserving structure and K. A **structural upgrade** changes other validity/app/committee rules, including K. Both pause and activate identically. Let G=lcm(oldK,newK); eligible checkpoints are positive heights divisible by G. H is the first such height reached at/after T in the authorized generation. With unchanged K, this is the first ordinary grid checkpoint at/after T; with changed K, it is the first common-grid checkpoint. U remains divisible by both K values and maxBatchBlocks supports both grids. Since 1<=oldK,newK<=6, G<=30. Intermediate old-K landings remain allowed; an entire G-block interval need not fit one transaction.

Supported in-place upgrades preserve the Inbox/router, fixed statement/ABI, signing domain, genesis, consensus parameters, appendix B layouts and deployment immutables. Compatible implementation code and deterministic app metadata may change. Different immutable interfaces, statement/header encodings, storage layouts or signer/genesis state are unsupported in place: section 10 requires separate Inbox/genesis deployment and compatible registry plus an independently specified migration. This specification supplies no cross-deployment migration protocol.

The timestamp construction in CONS-3.2-3, the historical pause predicate in CONS-3.4-3, and the anchor freshness bound in CONS-3.4-8, including the maxAnchorAge value in Inbox slot 282, are deployment invariants. Every supported in-place epoch preserves these semantics identically; kind 2 cannot weaken or disable them. A change to these premises requires separate deployment and a separately specified migration.

**Verifier maintenance** changes proof implementations, images or backend dependencies while preserving exact rules/structure/encoding commitments. The owner authorizes an exact replacement policy for an existing epoch without a pause trigger. It can repair proving of unchanged rules; registration alone is insufficient and a validity change cannot be maintenance.

L1 forks have an external deadline. Header fields already tolerated by 3.3 need no upgrade. Same-rule proof fixes use maintenance, with compatible clients where needed; supported validity changes use the checkpoint-pause workflow and remain subject to the in-place restrictions. Clients, guests, authorized policies and activation or separately specified migration must be ready before L1 activation. Choosing T at the L1 fork time does not guarantee readiness before that deadline.

## 2. Canonical on-chain plan

<!-- governed-by: START-10.1-4 -->

The Inbox stores an append-only journal. Plan 0 is the active baseline, pinning original rules, structure, proof policy and executor. Each plan is exactly this canonical ABI tuple without trailing bytes:

```txt
UpgradePlan = (
  uint256 nonce, bytes32 previousPlanHash,
  uint8 kind, uint48 authorizedGeneration, uint48 epochStartHeight,
  uint64 triggerTimestamp,
  bytes32 oldRulesHash, bytes32 newRulesHash,
  bytes32 oldStructureHash, bytes32 newStructureHash,
  uint8 oldK, uint8 newK,
  address activationExecutor, bytes32 activationExecutorCodeHash,
  address policyVerifier, bytes32 policyVerifierCodeHash,
  bytes32 imageSetHash, bytes32 artifactManifestHash,
  bytes32 migrationHash, bytes32 policyTargetPlanHash
)
kind = 0  // baseline only: nonce/triggerTimestamp/epochStartHeight = 0; previousPlanHash = 0
kind = 1  // ordinary EL fork; triggerTimestamp = T; old/new structure and K agree
kind = 2  // structural upgrade; triggerTimestamp = T
kind = 3  // same-rule maintenance; triggerTimestamp = 0; target is an activated kind 0, 1 or 2 planHash
planHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_PLAN_V1"),
  uint256(l1ChainId), uint256(l2ChainId), address(inbox), address(registry), UpgradePlan))
```

rulesHash and structureHash hash the exact canonical rule/structure descriptors for an epoch, excluding their own hashes and guest-image/verifier-code/manifest hashes. artifactManifestHash hashes exact published manifest bytes pinning reproducible source/build identities, rules/encodings, verifier, image tuples and historical artifacts. It contains neither its own hash nor final planHash and grants no authority. Guests need not embed their own image hashes.

The immutable policy verifier exposes `policyIdentity() -> (bytes32 rulesHash, bytes32 structureHash, bytes32 imageSetHash)`, equal to the plan's `(newRulesHash, newStructureHash, imageSetHash)`, and `imagePolicies() -> ImagePolicy[]`. **At installation** the Inbox obtains this canonical array, checks its hash/identities/revocations and caches its exact tuples under planHash. It is sorted strictly by keccak256(abi.encode(tuple)), without duplicates:

```txt
Dependency = (address verifier, bytes32 codeHash)
ImagePolicy = (uint8 backend, address verifier, bytes32 verifierCodeHash,
  bytes32 blockImageId, bytes32 aggregationImageId, Dependency[] dependencies)
imageSetHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_IMAGES_V1"), ImagePolicy[]))
// backend: 0 SGX, 1 RISC0, 2 SP1. Dependencies are strictly address-sorted,
// immutable, and checked against live code hashes.
```

The manifest publishes the array. Zero image ID means an unused layer, never a wildcard; SGX uses its authenticated measurement/instance-policy identifier. Backend verifiers extract identities from authenticated proofs/attestations. An aggregation proof must authenticate both its aggregation image and the block image used by every inner receipt. Its proved public journal binds blockImageId, and the aggregation guest verifies every inner receipt against that exact ID. A caller-supplied block-image label is insufficient; an aggregated backend uses a nonzero blockImageId even when L1 verifies only the outer proof. Exact plan membership is an additional restriction: backend allowlists cannot widen it, but native instance validity, allowlists and revocation may narrow or disable it, including SGX instance revocation. Mutable proxy dependencies are unsupported. Each policy requires exactly two distinct-backend sub-proofs, at least one ZK. Nodes/tooling check that the pinned programs implement the declared epoch rules. Installation and worst-case verification must fit the deployment's L1 per-transaction limit.

The initial rule epoch starts at 0; every validity activation appends an epoch at H+1. The plan's epochStartHeight identifies its current predecessor epoch. Kind 1 preserves structure/K and uses an empty migration call list; kind 2 may perform committed compatible migration. Both set policyTargetPlanHash=0 and commit the canonical migration description. Maintenance preserves old/new rules, structure and K, zeroes migrationHash and targets an activated baseline/upgrade record with matching commitments, possibly historical. A new maintenance record replaces the direct policy pointer for that target epoch; it cannot widen the epoch's range. All plans preserve the baseline executor. Checked widths/arithmetic reject truncation, overflow or incompatible plans.

## 3. Authority, journal and non-retroactivity

<!-- governed-by: START-10.1-5 -->

The pinned immutable executor is the actual owner of Inbox, registry and L1 SignalService. The DAO/timelock, through its Controller where used, controls the executor's governance-call entry point. Deployment checks all three ownership links and executor code hash. Its permissionless activation entry point executes only an installed committed plan, never arbitrary governance calls. Normal mutations share land/recover protection. Inbox nonpayable interfaces are:

```txt
installUpgradePlan(bytes plan, bytes artifactManifest,
  uint256 expectedNonce, bytes32 expectedPreviousPlanHash, uint48 expectedGeneration)
cancelUpgradePlan(bytes32 planHash, uint48 expectedGeneration)
beginUpgrade(bytes32 planHash)
activateUpgrade(bytes32 planHash, bytes migrationDescription)
revokeProofPolicy(bytes32 imageSetHash)
revokeImage(uint8 backend, uint8 layer, bytes32 imageId) // 0 block, 1 aggregation
getUpgradePlan(uint256 nonce) -> (bytes plan, uint8 status)

recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil,
  Exclusion[] exclusions, uint256[] fiToClear)
```

Only the actual owner installs, cancels or revokes. beginUpgrade/activateUpgrade also require that owner and a matching live executor context. Anyone may use the executor's executeUpgrade(planHash,migrationDescription). Installation checks expected nonce/head/generation against the tuple and current state, predecessor epoch/commitments, manifest/code/policy commitments and widths. It increments nextNonce and appends exact bytes with UpgradePlanInstalled. Nonces never wrap/reset; cancelled/stale bytes are retained. Off-chain configuration grants no authority.

At most one kind-1/2 validity plan is pending globally; maintenance/revocation remain available for activated epochs. Installing a validity plan is complete DAO/timelock authority for its generation, T, rules/policy, migration and executor; no future H hash or second governance cycle is required. Its new policy is ineligible until explicit activation, even if T passes or H lands. Installation leaves old rules active and writes the pause trigger atomically. Pending status lasts through the pause and settlement; only executeUpgrade changes it to active.

Require `0 < T < 2^64` and `block.timestamp + maxAnchorAge < T <= block.timestamp + maxTimestampLead`, with both sums fitting uint64. maxTimestampLead is a finite deployment-pinned interval in seconds, greater than maxAnchorAge, published/tested at launch. This strict lead ensures no block anchored before publication can reach T under 3.4. Plan publication must therefore be authenticated before a valid chain reaches its pause boundary, including after exceptional checkpoint rollback. Require compatible old/new K, U and maxBatchBlocks. Reject a trigger whose checked representation or common-grid computation is invalid.

The owner may cancel the exact kind-1/2 plan only while it is pending; T or H settlement does not by itself disable cancellation. There is no reserved veto period after sealing: a permissionless caller may land H and executeUpgrade in the same transaction, and a later cancellation reverts. DAO authorization, voting or timelock delay does not reserve transaction ordering or guarantee a response window. Cancellation makes it terminal status 3 and atomically clears pending/trigger/sealed height; all executed blocks still used old rules, so neither retained history nor an execution-rule schedule changes. Historical trigger checks at old anchors remain binding. Resume must use an anchor whose authenticated pause predicate permits the resumed height. Replacement is cancellation followed by a fresh installation with current nonce/head/generation and the same T lead checks. Active, cancelled, stale or unknown records cannot be cancelled/executed.

Recovery atomically marks any pending kind-1/2 plan stale (status 4), clears its trigger/sealed height and discards the unsettled suffix under section 8. No pending plan carries into a new generation; a new one needs fresh authority and T. Recovery uses the six-argument ABI in section 8.3. Recovery preserves active epoch history, policies/revocations and journal bytes/nonces. Exceptional verifier-failure rollback reconciles pending/sealed state with independently authenticated retained headers without reviving terminal authority. Staling an inconsistent pending plan atomically clears pendingValidityNoncePlusOne, pauseTrigger and pauseHeight. If rollback restores c below a consistent pending sealed H, clear only pauseHeight while retaining its authenticated pending authority/trigger; re-landing an eligible boundary runs the normal first-seal checks. Preserve every activated epoch route and its activation history: the prescribed rollback rejects restored c below any activated kind-1/2 boundary H. If the last trusted landing is below such H, a separately specified exceptional DAO implementation upgrade must define route/history reconciliation before resumption; ordinary rollback/recovery and a replacement landing cannot rewrite that boundary. Recovery preserves active epochs. A corrective ordinary plan is usable only if the active rules still allow reaching and settling its next pause checkpoint; otherwise an activated-rule stall requires a separately specified exceptional DAO implementation upgrade. No old activation is replayable.

Metadata uses ERC-7201 namespace taiko.etna.upgrades, base UPGRADE_BASE outside appendix B reserved slots, computed by the [ERC-7201 root formula](https://eips.ethereum.org/EIPS/eip-7201). It is distinct from unsettled-block limit U. Each declaration occupies one successive full slot:

```txt
uint256 nextNonce                                      // UPGRADE_BASE+0
bytes32 lastPlanHash                                   // UPGRADE_BASE+1
mapping(uint256 => bytes) plans                        // UPGRADE_BASE+2
mapping(bytes32 => uint8) status                       // UPGRADE_BASE+3
uint256 pendingValidityNoncePlusOne                    // UPGRADE_BASE+4
address executor                                      // UPGRADE_BASE+5
bytes32 executorCodeHash                              // UPGRADE_BASE+6
uint256 maxTimestampLead                              // UPGRADE_BASE+7
uint256 pauseHeight                                   // UPGRADE_BASE+8; 0 until H lands
uint256 pauseTrigger                                  // UPGRADE_BASE+9; historical anchor witness
mapping(bytes32 => bytes32) policyReplacement           // UPGRADE_BASE+10
mapping(bytes32 => bool) revokedPolicies                // UPGRADE_BASE+11
mapping(bytes32 => bool) revokedImages                  // UPGRADE_BASE+12
EpochRoute[] epochRoutes                               // UPGRADE_BASE+13
mapping(bytes32 => ImagePolicy[]) cachedImagePolicies   // UPGRADE_BASE+14
uint256 revocationCount                                // UPGRADE_BASE+15
```

pauseTrigger is zero when inactive, otherwise `(uint256(generation)<<112) | (uint256(G)<<64) | T`, with 48-bit generation, 1<=G<=30, positive uint64 T and high bits zero. Its G must equal the installed plan's lcm(oldK,newK). Installation writes it; cancellation, activation, recovery and exceptional rollback staling the pending plan clear it atomically with pendingValidityNoncePlusOne and pauseHeight. The fixed slot UPGRADE_BASE+9 belongs to every anchor witness; inheritance retains its proven value.

For each block at height r, decode the value at that block's own anchor. A nonzero trigger of the same generation requires this deterministic check: let q=G\*floor((r-1)/G), the immediately preceding common-grid height. If q is at/after this generation's origin, authenticate that canonical EL ancestor and require timestamp(q)<T; otherwise no preceding eligible checkpoint exists in this generation. Prove q's header and all parent-hash links back from r's parent, or reuse already authenticated execution headers; at most G prior headers suffice, a separate bounded allowance from 6.2's committee history. At a batch's first block, q may be at or below proof origin p; supply and authenticate the required pre-p headers instead of assuming every ancestor is inside the execution payload. A missing/wrong ancestor or timestamp(q)>=T invalidates the block. This permits H itself and forbids every subsequent block while the trigger is live, including batches that try to skip H. Cancellation later cannot waive a historical violation; another generation's trigger does not impose this predicate. Local clocks and a caller-selected H cannot replace it.

Before any land storage write, reject h>pauseHeight when a pending pauseHeight is nonzero and determine whether a pending same-generation trigger with h%G=0 and lastTimestamp>=T would seal. Require h+1<2^48 and pauseHeight=0 for that first seal during this preflight. After both proofs and all checks succeed, land assigns pauseHeight=h without further validation in the write phase; the per-block predicate proves h is the first eligible boundary. After rollback clears a seal above restored c, a later eligible landing may seal again under the same normal checks. Merely settling H never activates the new policy. Status is 1 active (baseline/maintenance included), 2 pending, 3 cancelled, 4 stale; statuses 1/3/4 are terminal authority. Baseline starts nextNonce=1, lastPlanHash=baseline hash, epochRoutes=[(0,baselineHash)], executor/maxTimestampLead pinned, all other pending/counter/mapping state empty or zero. Activation appends (H+1,planHash), with strictly increasing heights; binary search selects one epoch, not a journal scan. Getters/events expose exact bytes, caches, routes, statuses, pause seal and revocations. First false-to-true revocation increments revocationCount with overflow rejection; duplicates are idempotent. Recovery/rollback preserve every revocation/count. A matching count does not prove arbitrary mapping equality.

Executor and Inbox store matching execution contexts in transient storage keyed by keccak256("taiko.etna.upgrades.executionContext"). The Inbox getter upgradeExecutionContext() returns that value during execution and zero otherwise; registry ordinary mutations consult it. The persistent pause trigger is distinct from this transaction-local lock.

## 4. L1 proof routing and timestamp binding

<!-- governed-by: START-10.1-13 -->

The immutable router verifies a fixed landing statement of 22 static ABI words, 704 bytes, domain TAIKO_ETNA_LAND_V1. LandInput has nine fields including uint256 lastTimestamp, constrained below 2^64. Both guests prove it equals the terminal executed EL header's timestamp and authenticate the same complete statement. It seals the dynamic pause checkpoint; it does not choose an execution-rule version.

```txt
proof = abi.encode(bytes encodedStatement, uint256[2] policyIndices, bytes twoProofs)
```

The wrapper is canonical without trailing bytes; encodedStatement is exactly 704 bytes and hashes to the Inbox commitment from input/origin/blobs/cuts. The router decodes full chain/deployment/generation identity and rejects unsupported lengths/domains or failed bindings. Binary-search the activated epoch containing h; reject a batch crossing an activated boundary p<H<h. A post-H batch may start at H, whose retained origin is checked under 6.1; it executes only H+1 onward with the new epoch policy. Pending new policies are ineligible. Apply the direct maintenance replacement for the selected epoch. Check the live same-generation pause seal if present; both guests additionally enforce every block's historical trigger/ancestor check, even after cancellation clears current state. The router selects policies by activated height epochs; each batch executes one epoch's rules.

The two indices select cached exact policy tuples: bounds-check each, authenticate backend/layer/image identities, require distinct backends and at least one ZK, and recheck selected verifier/dependency code hashes, policy identity and native validity. verifySelectedProofs(bytes32 statement,uint256[2] indices,bytes proofs) verifies both proofs and returns authenticated identities for comparison. Read only the selected tuples/dependencies; never re-enumerate/hash imagePolicies() or scan history on land. Caches are immutable; maintenance creates a fresh cache and direct replacement pointer.

Global policy/image revocation is independent of timestamp, epoch and generation. Reject revoked imageSetHash or used (backend,layer,imageId), including authenticated inner block images in aggregated proofs. Repackaging does not bypass revocation; installation rejects revoked tuples. A revoked unused tuple need not disable sound alternatives; all actually used tuples must pass native validity and revocation. Revoking every valid combination stops settlement. Already accepted false landings require section 8's exceptional handling. Any failure reverts land and pause-seal updates.

## 5. Checkpoint pause and atomic activation

<!-- governed-by: START-10.1-8 -->

Nodes and guarded signers evaluate the same per-anchor trigger/ancestor predicate as both guests. They execute/sign H under old rules and refuse the next step while paused, preserving HRS/WAL. Missing/unfinalized L1 data is an untrusted wait with FinalizeBlock retry under SYNC-9-2, not a safety halt. A decided block whose cited canonical anchor positively proves a trigger violation is invalid and safety-halts. Neither a later cancellation nor a local lagging view changes that historical validity.

A pending future trigger alone never prevents ordinary trust-wait/timeout restart before/at H. Record refused height/generation/reason and gate automatic restart only when that step violates the authenticated pause predicate. At the boundary wait for finalized activation, cancellation or exceptional rollback clearing the pending plan, and readiness, adopting a release-proving anchor for H+1. A release-proving anchor is a canonical header finalized in the node's own L1 view whose authenticated pauseTrigger and ancestor evidence allow the refused height under section 3. It need not prove trigger=0: if cancellation of plan P1, paused at checkpoint H1, and installation of a future plan P2 occur atomically, P2's nonzero trigger may already permit H1+1. Normal trust, readiness and generation checks still apply. Recovery ends the old generation and uses 8.4 startup; it never restarts an old-generation step. Safety halts require investigation. The process may remain alive while signing/production waits; automatic release preserves signing state and creates no new slashing offence.

The executor exposes permissionless executeUpgrade(planHash,migrationDescription). Require the installed pending plan/current generation, pinned owner/code identities, nonzero sealed pauseHeight H, latest checkpoint exactly H, H%G=0 and consistent retained landings[H]/SignalService records. H's timestamp, already authenticated by the landing statement, is at least T. H hashes, FI cursor and stateRoot are read on-chain inside execution, not supplied as future governance arguments. Wrong/missing seal or records, c!=H, wrong generation or terminal authority revert. Reaching wall-clock T, a noneligible post-T landing or H landing without explicit execution cannot activate a plan.

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

The executor establishes its transient context, enters beginUpgrade and holds the shared Inbox/registry guards through final activation. Ordinary land/recover/nonce/plan/queue/registry/withdrawal mutations reject while the guard is held. Committed implementation calls and matching activation are the only exceptions. Activation checks actual owner, live executor code hash, matching derived contexts, plan/generation/checkpoint/pauseHeight/trigger and clears context/guard while marking active, clearing pending/pauseTrigger/pauseHeight and appending the epoch. Any failed call/assertion/check reverts the entire transaction. The installed journal nonce/status and generation prevent replay; there is no expiring authorization.

**Checks are bounded, with no storage-history scan.** If Call[] is nonempty, take a runtime snapshot before calls and compare afterward: deployment/proxy owners and pinned code/config identities; genesis/config scalars, delays including slot 282, generation/recoveryNonce, current origin, checkpoint and H's three-word landing/SignalService record, FI head/tail and activeCommitteeSnapshot; namespace counters (including revocationCount)/head/current-plan status/pending/pauseTrigger/pauseHeight, epoch-route length/latest entry and executor/maxTimestampLead; registry configuration plus current checkpoint length/latest record/count/root. The pinned executor fixes this scalar read set and its getters/slots; expected new implementation hashes are checked by the committed assertions, rather than compared to the old implementation. The checker reads a fixed number of scalar words/code hashes independent of registry occupancy, FI backlog, number of landings or plans. Deployment acceptance bounds that cost under the L1 transaction limit. **For empty Call[], skip this snapshot**; core activation, context, code and immutable-identity assertions still apply, and all history stays untouched.

The reviewed preservation set includes all historical landings, plan bytes **and statuses**, queue contents and generation-origin records; revokedPolicies, revokedImages and revocationCount; policyReplacement and every cachedImagePolicies tuple/dependency; all activated epoch-route history and sealed pause heights; registry principal, ownership, **keys, exit confirmations and historical committee checkpoints**, exits, top-ups and lifetime forfeiture flags; and fixed appendix B layouts. Migration calls preserve all of these. Only explicit protocol lifecycle transitions may change their named current record or append state; no compatible migration may clear a revocation, rewrite a cache/replacement, resurrect terminal status or erase history. This is a requirement on the DAO-reviewed implementation and migration write set; the bounded checker **does not prove equality of arbitrary historical mappings**. It must not claim such a proof or attempt an unbounded scan. Any migration requiring a different physical protocol layout is unsupported in place. As in SPEC 1, malicious DAO-controlled proxy code/getters can bypass the specification; these checks do not remove that trust assumption.

Nodes preserve fixed origin, signed HRS/WAL, EL/Comet history through H and committed current/pending validator transitions with H+2 activation. Deterministic compatible app metadata may be converted; incompatible signer/genesis/transitions require separate deployment and a separately specified migration. Nodes authenticate finalized UpgradeActivated(planHash,H,ELHash,CometHash) and readiness before H+1; unfinalized inclusion is insufficient.

## 6. Jobs, failures and acceptance

<!-- governed-by: START-10.1-15 -->

Jobs bind deployment, generation, epoch/plan/rules, statement/config/image versions and (p,h]. Jobs may span timestamp T because rules remain old through H, but never an activated H boundary. Post-H jobs require activation. Old jobs stay eligible only in their original height range under current exact replacements, native validity and global revocation, regardless of submission time. Never relabel a job; historical artifacts permit replay, not revoked-image acceptance.

Before T, validate old/new paths, real two-proof capacity and node/signer readiness. An unavailable new image cannot prevent proving H under the old epoch policy. Failed execution leaves the plan/trigger/seal intact and may be retried without a new governance cycle. While the plan remains pending, an executed owner cancellation can release it after T/H; this transaction may lose to immediate permissionless activation, including activation in the H-landing transaction. There is no guaranteed post-seal governance response window. Once cancellation wins, a finalized release-proving anchor and readiness permit continuation under old rules. Any replacement is a fresh installation. Recovery stales the pending plan and restarts a new generation. A corrective plan with fresh authority is possible only if the active rules can reach its pause checkpoint. If the activated epoch cannot produce/settle blocks, maintenance cannot change its rules, recovery retains it, and normal plans cannot reach a corrective boundary: a separately specified exceptional DAO implementation upgrade is required. No silent fallback or retained-prefix rewrite is allowed. Pause duration includes proving, L1 settlement/finality, execution/finality and readiness.

[Upgrade acceptance](ACCEPTANCE.md#upgrade-activation-spec-101) requires canonical ABIs/storage, checked T lead/common grids, historical trigger and bounded ancestor authentication, dynamic H sealing, explicit installed authorization, bounded migration and complete preservation, scoped restart, real old-H/new-H+1 proofs and the first post-upgrade finalized landing. It covers pending cancellation/activation races without a guaranteed veto window, stale pending state on recovery, cached alternatives/native revocation, aggregation image binding, overlap/finality and signer persistence. A manifest or prose/model check alone is not deployment acceptance.
