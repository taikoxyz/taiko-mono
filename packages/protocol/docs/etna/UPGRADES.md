# Etna upgrade activation

This document supplies definitions incorporated by the rule IDs in [SPEC section 10.1](SPEC.md#101-protocol-upgrade-boundaries). Each section names its governing rule; its definitions, including fenced encodings, belong to that rule. SPEC.md takes precedence in a conflict. The Unzen-to-Etna migration and section 8's exceptional verifier-failure rollback remain separate.

## 1. Upgrade classes

<!-- governed-by: START-10.1-1 -->

An **ordinary EL fork** changes EL execution rules or execution parameters, including gas/zk-gas metering. It preserves consensus envelope/header encodings, the landing statement and cut encodings, K, committee/epoch rules, signing domain, Comet genesis/consensus parameters and deployment-immutable values. Each block uses old rules below T and new rules at or above T, using its own timestamp. Local clocks, L1 submission times and proof-completion times do not select rules. Production need not stop or settle exactly at T; normal validity and back-pressure rules apply.

A **structural upgrade** changes other validity or app/committee rules, including K. Its checkpoint boundary is H: old rules through H, new rules from H+1. An in-place upgrade preserves the deployment's immutable router, V2 landing statement/ABI, signing domain, genesis and consensus parameters. A change to those fields, including a different statement or consensus header encoding, uses the separate new-Inbox/router or new-genesis migration at a checkpoint boundary under SPEC 10. It cannot reset signer state.

**Verifier maintenance** changes only proof implementations, images or backend dependencies while preserving exact rule/structure/encoding commitments. It replaces an exact proof policy for an existing rule schedule, requires owner authorization, and has no EL timestamp or structural-height trigger. It may repair proving of an already authorized schedule. Backend image registration alone is insufficient. A validity-rule change disguised as maintenance is invalid.

L1 forks have an external deadline. Appended header fields tolerated by SPEC 3.3 need no upgrade. An implementation fix preserving all rules and encodings is verifier maintenance (plus a compatible client release where needed). A change of L1 witness/state-commitment or authenticated header encoding is structural and, if it changes a deployment-immutable interface, requires separate migration. A change confined to EL execution rules uses T. All required clients, guests, authorized policies and structural activation/migration must be ready before the L1 fork; an L2 trigger cannot defer that deadline.

## 2. Canonical on-chain plan

<!-- governed-by: START-10.1-4 -->

The Inbox maintains an append-only plan journal. Plan 0 is the active deployment baseline, pinning original rules, structure, proof policy and executor. A plan is exactly this canonical ABI tuple, without trailing bytes:

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
kind = 3  // verifier maintenance; boundary = 0; policyTargetPlanHash names kind 0, 1 or 2
planHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_PLAN_V2"),
  uint256(l1ChainId), uint256(l2ChainId), address(inbox), address(registry), UpgradePlan))
```

`rulesHash` is keccak256 of the exact published canonical rule-descriptor bytes, including the retained validity schedule; `structureHash` hashes the structural descriptor for section 1's fields. Descriptors exclude their own hashes and all guest-image, verifier-code and manifest hashes. `artifactManifestHash` is keccak256 of exact published manifest bytes. The manifest pins source/build revisions, supported rules/encodings, verifier, image tuples and retained schedule; it contains neither its own hash nor the final planHash and is not an independent authority. Guests need not embed their own image hashes.

The immutable policy verifier exposes `policyIdentity() -> (bytes32 rulesHash, bytes32 structureHash, bytes32 imageSetHash)`, exactly equal to `(newRulesHash, newStructureHash, imageSetHash)` in the plan. It also exposes `imagePolicies() -> ImagePolicy[]`; installation/router hash this returned canonical array, compare imageSetHash, and enumerate all used layers against global revocations. Its accepted set is the canonical ABI array below, sorted strictly by keccak256(abi.encode(tuple)), without duplicate tuples:

```txt
Dependency = (address verifier, bytes32 codeHash)
ImagePolicy = (uint8 backend, address verifier, bytes32 verifierCodeHash,
  bytes32 blockImageId, bytes32 aggregationImageId, Dependency[] dependencies)
imageSetHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_IMAGES_V1"), ImagePolicy[]))
// backend: 0 = SGX, 1 = RISC0, 2 = SP1.
// Dependencies are strictly address-sorted, immutable and checked against live code hashes.
```

The full array is published in the manifest. A zero image ID denotes only a layer unused by that backend, never a wildcard; SGX uses its attested measurement/instance-policy identifier. Backend verifiers extract layer/image identities from authenticated proof/attestation material. The policy checks exact tuple membership and live dependency identities independently of mutable backend allowlists. Proxy dependencies are unsupported; changing a dependency requires a maintenance plan. Every policy requires exactly two distinct-backend sub-proofs, at least one ZK. Installation checks live code hashes and policy identity; nodes and deployment tooling additionally check that the pinned programs implement the declared complete schedule. Every verification rechecks the same identities.

`epochStartHeight` names the current structural epoch (initially 0); structural activation creates an epoch starting at H+1. A timestamp plan preserves structure and K, has zero migrationHash/policyTargetPlanHash, and extends the effective schedule with T greater than every activated trigger. A structural plan has zero policyTargetPlanHash and inherits all activated timestamp history. A maintenance plan has unchanged old/new rules, structure and K, zero migrationHash, and targets an existing noncancelled baseline/timestamp/structural record with those commitments; it never changes that record's validity range. It may target a pending record. All plans preserve the baseline executor address/code hash. ABI widths and arithmetic are checked without truncation or wrapping; failed checks revert installation.

## 3. Authority, journal and non-retroactivity

<!-- governed-by: START-10.1-5 -->

The actual Inbox owner is a pinned immutable on-chain executor controlled by the DAO/timelock. The DAO is the governance authority; public triggering of an authorized migration does not grant governance authority. Its address/code hash are explicit in every plan and stored in the upgrade namespace. All mutations share the land/recover reentrancy protection. The nonpayable Inbox interfaces are:

```txt
installUpgradePlan(bytes plan, bytes artifactManifest,
  uint256 expectedNonce, bytes32 expectedPreviousPlanHash, uint48 expectedGeneration)
cancelUpgradePlan(bytes32 planHash, uint48 expectedGeneration)
replaceTimestampPlan(bytes32 oldPlanHash, bytes replacementPlan, bytes artifactManifest,
  uint256 expectedNonce, bytes32 expectedPreviousPlanHash, uint48 expectedGeneration)
authorizeStructuralUpgrade(bytes32 planHash, uint48 expectedGeneration, uint256 H,
  uint256 validUntil)
beginStructuralUpgrade(bytes32 planHash) // owner only, within pinned active executor context
activateStructuralUpgrade(bytes32 planHash, bytes migrationDescription)
revokeProofPolicy(bytes32 imageSetHash)
revokeImage(uint8 backend, uint8 layer, bytes32 imageId) // layer: 0 block, 1 aggregation
getUpgradePlan(uint256 nonce) -> (bytes plan, uint8 status)
```

Only the actual owner installs, cancels, authorizes or revokes. Installation requires expectedNonce = nextNonce, expectedPreviousPlanHash = lastPlanHash, matching tuple nonce/head, and expectedGeneration = plan.authorizedGeneration = current generation. For kind 1/2 the epoch is current and old commitments match the effective schedule; maintenance instead matches its target epoch and commitments, even for a historical epoch. It checks manifest/code/policy commitments, increments nextNonce, appends exact bytes and emits `UpgradePlanInstalled(planHash, plan, artifactManifest)`. Nonces never wrap/reset; cancelled and stale records remain. Off-chain configuration cannot create authority.

At most one validity-changing plan (kind 1 or 2) is pending globally. A timestamp record stays pending until a successful landing first proves lastTimestamp >= T, which marks it active; its rules nevertheless apply to every block at/above T from installation. Structural preparation waits until that pending timestamp is landed or safely cancelled. Maintenance and revocation remain available while either class is pending. No pending descendants need rewriting on cancellation.

For kind 1, require `0 < T < 2^64`, `T > block.timestamp + maxAnchorAge`, and `T <= block.timestamp + maxTimestampLead` at installation. `maxTimestampLead` is a positive, finite, deployment-pinned interval in seconds, greater than maxAnchorAge, published and tested at launch; both sums must fit uint64. There is no inferred default or unit conversion. The lower bound means a valid block using an anchor older than publication cannot reach T under SPEC 3.4. Crossing T therefore requires an anchor that can authenticate publication; this does not guarantee readiness or finality.

An unactivated timestamp plan may be cancelled or replaced **only while `block.timestamp + maxAnchorAge < T`**, with checked arithmetic, expected generation and current pending plan. No valid block anchored before cancellation can have reached T, so later anchors authenticate removal without reinterpreting signed history. Cancellation emits `UpgradePlanCancelled(planHash)` and restores the preceding effective schedule; replacement atomically cancels and installs a fresh nonce/head using all installation checks. Journal history is preserved. Once the inequality fails, cancellation/replacement is rejected even if no post-T checkpoint has landed. Repair then preserves authorized rules (possibly using maintenance); reversal after affected blocks exist requires a separately authorized upgrade/migration or SPEC 8's exceptional procedure.

For kind 2, require `H >= installation-time lastCheckpoint.height + U`, `H < 2^48`, H divisible by oldK and newK, and unchanged U/maxBatchBlocks compatible with newK. The U lead prevents an already valid suffix from crossing H before publication. The owner may cancel an unactivated structural plan, releasing its same-generation fence. Cancelled records cannot reactivate; a new plan uses a fresh nonce.

The DAO/timelock may authorize a structural plan **before H**, binding `(planHash, current generation, H, validUntil)` without future EL/Comet hashes. Require a matching pending plan and `block.timestamp <= validUntil < 2^64`. An authorization cannot be replaced while live; after expiry the owner may renew the same unchanged plan with a fresh monotonically increasing authorization nonce. Cancellation or a generation change invalidates it. Expiry leaves the fence in place until renewal or cancellation. Execution is permissionless within the deadline and derives H's hashes from authenticated on-chain records under section 5. It requires no DAO transaction after H is known.

Ordinary recovery preserves timestamp schedules (including a pending timestamp), activated structural history, proof-policy replacements and revocations. An old-generation pending structural plan and its authorization become stale and lose their fence permanently; recovery atomically clears that stale pending pointer and invalidates/clears its authorization tuple without resetting the next authorization nonce or deleting history; timestamp rules do not become stale merely because generation changed. A retained pending timestamp is cancelled, if still safe, using the current generation. Verifier-failure rollback separately repairs affected ranges, preserving journal/nonces, authorization invalidations and revocations.

Metadata uses the ERC-7201 namespace `taiko.etna.upgrades`, never appendix B's reserved slots. Each item occupies a successive full slot at the namespace base (no packing):

```txt
uint256 nextNonce
bytes32 lastPlanHash
mapping(uint256 => bytes) plans
mapping(bytes32 => uint8) status
uint256 pendingValidityNoncePlusOne
address activationExecutor
bytes32 activationExecutorCodeHash
uint256 maxTimestampLead
uint256 checkpointTimestamp
uint256 nextAuthorizationNonce
bytes32 authorizedPlanHash
uint256 authorizedGeneration
uint256 authorizedH
uint256 authorizationValidUntil
uint256 authorizationNonce
bytes32 structuralExecutionContext
mapping(bytes32 => bytes32) policyReplacement // target planHash -> latest maintenance planHash
mapping(bytes32 => bool) revokedPolicies     // imageSetHash; false -> true only
mapping(bytes32 => bool) revokedImages       // keccak256(abi.encode(backend, layer, imageId))
```

Baseline old/new rules, structure and K agree; migrationHash and policyTargetPlanHash are zero. All mappings start empty except the exact baseline bytes and its active status. Structural epochs and retained timestamp schedules are derived from activated structural/timestamp records plus the live pending timestamp record; no off-chain epoch table is authoritative. Status: 1 active (including baseline/maintenance), 2 pending, 3 cancelled; only a status-2 structural record with a generation mismatch is effectively stale; activated epochs never become stale on recovery. Baseline initializes nextNonce = 1, lastPlanHash = baseline hash, nextAuthorizationNonce = 1, counters/authorizations otherwise empty, checkpointTimestamp = genesis EL timestamp, and executor/maxTimestampLead from deployment. Genesis timestamp/hash correspondence is checked by nodes/guests at startup. A successful landing updates checkpointTimestamp from its proven lastTimestamp. State, plan bytes, authorizations and replacement/revocation mappings have public getters authenticated by nodes from their own finalized L1. Journal/counter/status/revocation mutations emit exact new values; activation also emits H and its derived hashes. Authorization allocates authorizationNonce = nextAuthorizationNonce and then increments nextAuthorizationNonce with overflow rejection. Expiry alone does not clear it; cancellation, recovery invalidation and activation clear the stored authorization tuple. Activation consumes its authorization; allocated authorization nonces never wrap, reset or become reusable.

## 4. L1 proof routing and timestamp binding

<!-- governed-by: START-10.1-13 -->

The Inbox's immutable verifier is an upgrade-aware router. Appendix A's V2 landing statement appends **lastTimestamp** to the former fields: 22 static ABI words, 704 bytes, domain `TAIKO_ETNA_LAND_V2`. LandInput also appends uint256 lastTimestamp. Require `lastTimestamp < 2^64`. Both guests prove it equals the timestamp of the terminal executed EL header whose hash/stateRoot are lastBlockHash/lastStateRoot. Every sub-proof authenticates this same full statement. V1 statements are rejected by this V2 deployment; APP_VERSION and the consensus-envelope prefix remain unchanged.

```txt
proof = abi.encode(bytes encodedStatement, bytes twoProofs)
```

The wrapper is canonical without trailing bytes, and encodedStatement is exactly 704 bytes. Its hash must equal the Inbox commitment computed from land input, origin, blobs and cuts. The router decodes one fixed statement format, checking full chain/deployment/generation identity. There are no dispatch hints, per-epoch statement adapters or on-chain EL-header RLP parser. A format/router change requires separate Inbox/router migration at a structural checkpoint boundary. Caller-supplied timestamps are accepted only with both proofs binding them to execution.

Select the structural epoch containing h and reject p < H < h at any structural boundary. A live same-generation pending structural fence rejects h > H. Within the epoch select the latest activated or pending timestamp plan with T <= lastTimestamp, or the epoch baseline. New complete-schedule policies prove all retained rules per block, including a batch spanning T. Old-only policies are eligible only for lastTimestamp < T, regardless of L1 submission time. Then apply any exact maintenance replacement for that selected plan. A replacement cannot widen its timestamp/height range. Recheck policy code/dependencies, identity and exact image tuples before accepting both proofs. Failure reverts land; checkpointTimestamp and pending-status updates are atomic with proof verification.

**Revocation is independent of proof-claimed timestamp.** The owner can monotonically revoke a whole imageSetHash or a used `(backend, layer, imageId)`. Every selected/replacement policy and authenticated sub-proof is checked against global revocations across all epochs/generations. Repackaging a revoked image in a new verifier tuple cannot restore it; installation rejects policies containing revoked keys. Maintenance may supply sound alternative images for exactly the same rules and all still-unlanded ranges, including historical pre-T work. A revoked policy/image is never accepted solely because its proof claims a pre-T timestamp. Revoking the only available combination stops settlement until a sound authorized replacement exists. No rule repairs an already accepted false landing by trusting a compromised proof's timestamp; that is SPEC 8's verifier-failure case and remains subject to section 1's soundness assumption.

## 5. Structural fence and atomic activation

<!-- governed-by: START-10.1-8 -->

For a live same-generation structural plan, signers refuse proposals/votes above H until finalized activation or cancellation is authenticated, preserving HRS/WAL state. ProcessProposal rejects while required material is unavailable. **A node unable to see a block's cited finalized L1 anchor or applicable activation/cancellation waits untrusted under SYNC-9-2; FinalizeBlock waits/retries, not safety-halts.** Normal trust recovery may restart Comet under SYNC-9-12. A deliberate live structural fence is not bypassed by automatic restart. Only an authenticated canonical L1 view at the block's cited anchor positively establishing an unreleased same-generation fence makes a decided above-H block a safety violation and halt. Guests prove that historical anchor's plan/fence state and ancestry; current L1 routing does not replace historical validity. Later cancellation cannot retroactively authorize a block citing an earlier live fence. Refusal creates no new slashing offence.

The pinned immutable executor exposes permissionless `executeStructuralUpgrade(planHash, migrationDescription)`. It checks stored unconsumed authorization, current generation, deadline, actual owner/executor address and live code hash. It requires the latest checkpoint exactly H and reads ELHash/CometHash, generation, FI cursor and authenticated header stateRoot from retained `landings[H]` and the matching SignalService checkpoint. Values are read inside execution, never supplied as future governance arguments. Missing/mismatched H records, c < H, c > H, cancelled/stale plans or expired authorization revert.

```txt
Call = (address target, uint256 value, bytes data)
Assertion = (address target, bytes data, bytes expectedReturnData)
Migration = (Call[] calls, Assertion[] assertions)
migrationHash = keccak256(abi.encode(Migration))
context = keccak256(abi.encode(planHash, authorizationNonce, currentGeneration,
  H, ELHash, CometHash, migrationHash))
```

Canonical migrationDescription must match migrationHash. Calls execute in order, with value = 0 and success required, and cannot target the executor itself. Assertions are successful STATICCALLs with byte-for-byte expected return data, including implementation/code identities, layout/config versions and completion markers. Before calls the executor establishes its context and calls beginStructuralUpgrade, which checks that context/authorization and locks ordinary Inbox and registry mutation entry points (including land, recover, nonce invalidation, plan mutations and withdrawals) across the migration. Only committed implementation-upgrade calls and final matching activation are allowed in this context. Registry ordinary mutation entry points read the Inbox structuralExecutionContext and reject while it is nonzero; no separate registry guard storage is needed. The Inbox records structuralExecutionContext; after entering the guards the executor snapshots protected state; afterward it checks that state plus assertions and calls Inbox activation in the same non-reentrant transaction. Activation requires msg.sender to be the actual pinned owner, live executor code hash, and `activeUpgradeContext()` equal to the derived context. It rechecks plan, authorization, deadline, checkpoint, held guards/context and protected values before consuming authority, changing epoch/status and clearing the context/guards. Direct/out-of-context activation or any failed step reverts the whole transaction, including migration calls. The DAO need only preauthorize; any caller can execute once H lands.

The protected pre/post state includes **all** of the following:

- Deployment identities, fixed genesis/origin and every deployment-immutable parameter; router address/code hash and V2 statement/ABI; actual owner and pinned executor address/code hash; maxTimestampLead.
- Appendix B's complete retained protocol state, including maxAnchorAge and forcedInclusionDelay (slot 282), recoveryGeneration and recoveryNonce (292), latest checkpoint, H's full landing and SignalService checkpoint, all generation origins/retained landings, FI head/tail and queue contents, activeCommitteeSnapshot, and genesis/config records. Appendix B physical layouts and existing field values remain fixed under STOR-B-19; an incompatible layout change requires separate deployment/migration.
- The complete upgrade journal: nextNonce, lastPlanHash, every prior plan/status, pending record, checkpointTimestamp, authorization tuple/nonces, held execution context, policy replacements and revocations. Migration calls cannot mutate these. Only final activation may consume the current authorization, mark its plan active, clear its pending pointer/context/guards and establish the new structural epoch; checkpointTimestamp and prior history stay fixed.
- Registry logical principal, ownership, keys, exits, confirmations, top-ups, historical checkpoints and lifetime entryKey forfeiture flags, with a pinned on-chain pre/post logical-state commitment check. No migration-time registry/queue mutation may escape comparison.

The executor checks complete commitments/read interfaces specified by the pinned migration implementation, plus explicit protected configuration/counter/router getters; caller-supplied Booleans are insufficient. If an invariant cannot be checked on-chain, that in-place migration is unsupported. These checks constrain compliant migration execution; they do not remove SPEC 1's trust in DAO-controlled proxy upgrades and audited implementation/getter correctness. A malicious DAO proxy upgrade can still bypass the specification.

Nodes preserve committed current/pending Comet validator transitions and their H+2 activation, fixed generation origin, signed HRS/WAL state and EL/Comet history through H. App metadata conversion is deterministic under the pinned descriptor; incompatible transitions or signer/genesis changes require separate migration. Nodes authenticate finalized activation and H's checkpoint before H+1. Activation emits `StructuralUpgradeActivated(planHash, H, ELHash, CometHash)` and starts the epoch at H+1; an unfinalized L1 transaction is insufficient.

## 6. Jobs, failures and acceptance

<!-- governed-by: START-10.1-15 -->

Jobs bind deployment, generation, plan/rules commitment, statement/config/image versions and (p,h]. Ordinary jobs may cross T using complete-schedule programs; structural jobs never cross H. A post-H job starts at p >= H only after applicable activation is authenticated. Old-only proofs remain eligible solely in their original ranges and only while their policy/images are unrevoked and not superseded by maintenance. Router/fence/policy checks apply regardless of submission time. Jobs cannot be relabelled; historical artifacts support replay, not acceptance of revoked images.

Before T, validate both rule paths, mixed-boundary real two-proof capacity and node/signer readiness. Safe early cancellation/replacement is allowed under section 3; after that window, readiness/proving failures stop affected progress and require repair of the authorized path, not silent delay or fallback. Failed structural execution leaves old rules, fence and authorization unchanged; anyone may retry within its deadline. The owner may cancel or, after expiry, renew authorization without H's hashes in a new governance proposal. After activation, reversal is another authorized upgrade/migration. Signed state is never erased; settlement failure follows SPEC 8. Neither trigger guarantees zero downtime or automatic recovery.

The [upgrade acceptance](ACCEPTANCE.md#upgrade-activation-spec-101) covers canonical encodings/storage, preauthorization, safe timestamp cancellation, independent revocation, exact T/H bounds, V2 timestamp binding, real mixed-boundary proofs, overlapping jobs, protected-state atomicity, lagging L1 views, finality, restarts, recovery and historical replay. The mechanisms and passing deployment acceptance are required before exercising upgrades.
