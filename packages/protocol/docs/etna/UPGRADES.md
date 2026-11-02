# Etna upgrade activation

This document supplies the plan encoding, authorization, proof routing and activation rules referenced by [SPEC section 10.1](SPEC.md#101-protocol-upgrade-boundaries). Those rules and the definitions below are normative. They specify required implementation behavior; they do not claim that the contracts, clients or guests already implement it. The Unzen-to-Etna migration and section 8's exceptional verifier-failure rollback remain separate.

## 1. Upgrade classes

An **ordinary EL fork** changes only EL execution rules or execution parameters. It preserves the consensus envelope/header encodings, statement and cut encodings, K, committee/epoch rules, signing domain, Comet genesis/consensus parameters and deployment-immutable values. Its trigger is an L2 timestamp T. Each block uses the old EL rules when its own timestamp is below T and the new rules at or above T. Wall clocks, L1 submission times and proof-completion times do not select the rules. Production need not stop or settle exactly at T; normal validity and back-pressure rules still apply.

A **structural upgrade** is any change outside that class, including a change to a statement, envelope/header encoding, K or app/committee rules. It has a checkpoint boundary H: old rules through H and new rules from H+1. Changes requiring a new Inbox, signing domain or Comet genesis remain the separate migration required by SPEC 10; this mechanism cannot rewrite those immutables or reset signer state.

## 2. Canonical on-chain plan

The Inbox maintains an append-only plan journal. Plan 0 is the active deployment baseline; it pins the original structure/rules and the original proof policy. A subsequent plan is exactly the canonical ABI encoding of this ordered tuple, without trailing bytes:

```txt
UpgradePlan = (
  uint256 nonce, bytes32 previousPlanHash,
  uint8 kind, uint48 authorizedGeneration, uint48 epochStartHeight,
  uint256 boundary,
  bytes32 oldRulesHash, bytes32 newRulesHash,
  bytes32 oldStructureHash, bytes32 newStructureHash,
  uint8 oldK, uint8 newK,
  uint256 statementFormat, address statementAdapter, bytes32 statementAdapterCodeHash,
  address policyVerifier, bytes32 policyVerifierCodeHash,
  bytes32 imageSetHash, bytes32 artifactManifestHash,
  bytes32 migrationHash
)
kind = 0  // deployment baseline only: nonce/boundary/epochStartHeight = 0; previousPlanHash = 0
kind = 1  // ordinary EL fork; boundary = T
kind = 2  // structural upgrade; boundary = H
planHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_PLAN_V1"),
  uint256(l1ChainId), uint256(l2ChainId), address(inbox), address(registry), UpgradePlan))
```

`rulesHash` is keccak256 of the exact published canonical rule-descriptor bytes, including the predecessor validity schedule; `structureHash` likewise hashes the structural descriptor for the fields listed in section 1. These descriptors exclude their own hashes and all guest-image, verifier-address/code and manifest hashes. Concrete source/build revisions are separately pinned in the artifact manifest, avoiding any requirement for an artifact to embed its own hash. `artifactManifestHash` is keccak256 of the exact published manifest bytes. The manifest identifies source/build revisions, supported rule/encoding versions, the verifier and permitted guest-image set, and the full retained schedule; its bytes are published with the plan. It is not an independent authority and does not contain its own artifactManifestHash or the final planHash. Guest-image hashes are pinned separately from rule commitments so a program never has to embed its own image hash.

The adapter exposes `decodeStatement(bytes statement, bytes terminalHeader)` and returns chain/deployment identity, generation, p/h, lastBlockHash, lastStateRoot and terminal timestamp under the pinned structural format. It checks canonical statement/header encoding and the header number/stateRoot. Its code hash is pinned, and ordinary plans must keep its address, code hash and statementFormat unchanged.

The verifier exposes `policyIdentity() -> (bytes32 rulesHash, bytes32 structureHash, uint256 statementFormat, bytes32 imageSetHash)`, exactly matching the plan. Its accepted set is the canonical ABI array of these tuples, sorted strictly by keccak256(abi.encode(tuple)), with no duplicate tuples:

```txt
Dependency = (address verifier, bytes32 codeHash)
ImagePolicy = (uint8 backend, address verifier, bytes32 verifierCodeHash,
  bytes32 blockImageId, bytes32 aggregationImageId, Dependency[] dependencies)
imageSetHash = keccak256(abi.encode(bytes32("ETNA_UPGRADE_IMAGES_V1"), ImagePolicy[]))
// backend: 0 = SGX, 1 = RISC0, 2 = SP1.
// Dependencies are strictly address-sorted and immutable, with matching live code hashes.
```

The complete tuple array is published in the manifest. A zero image ID is allowed only for a layer that the pinned backend does not use, never as a wildcard; SGX uses the attested measurement/instance-policy identifier. The adapter for each backend extracts the block/aggregation identities from authenticated proof/attestation material. The policy verifier checks exact tuple membership and live dependency identities for each sub-proof, independently of any mutable global backend image allowlist. Mutable proxy dependencies are not accepted by this immutable policy interface; changing a dependency requires a new plan/policy. The verifier address has deployed immutable code with the recorded code hash, enforces this exact set and the complete retained rules, and requires exactly two distinct-backend sub-proofs, at least one ZK, under the existing ZkRequiredVerifier policy. A new image registration outside the plan cannot enlarge that accepted set. Before installation, nodes and deployment tooling check that the pinned verifier/images actually implement the declared rules and schedule. L1 routing checks the code hash and policy identity on every verification; malformed or mismatched inputs revert.

The plan's `epochStartHeight` identifies its current structural epoch (initially 0); a structural plan creates the next epoch starting after H when activated. New T values must exceed every timestamp trigger inherited into the current epoch, including not-yet-reached triggers. The successor epoch inherits all previously authorized timestamp rules, including future triggers; a structural manifest must define their deterministic interpretation under its new structure. A timestamp plan cannot alter structural fields: old/new structure hashes and K must match the current epoch. Arithmetic and ABI widths are checked without truncation or wrapping.

## 3. Authority, journal and non-retroactivity

These nonpayable Inbox interfaces use its existing owner and the same mutation/reentrancy protection as `land` and `recover`:

```txt
installUpgradePlan(bytes plan, bytes artifactManifest,
  uint256 expectedNonce, bytes32 expectedPreviousPlanHash, uint48 expectedGeneration)
activateStructuralUpgrade(bytes32 planHash, uint48 expectedGeneration,
  uint256 expectedH, bytes32 expectedELHash, bytes32 expectedCometHash,
  bytes migrationDescription)
cancelStructuralUpgrade(bytes32 planHash, uint48 expectedGeneration)
getUpgradePlan(uint256 nonce) -> (bytes plan, uint8 status)
```

Only the actual Inbox owner may mutate plans, through its DAO/timelock execution path. Installation requires expectedNonce = nextNonce, expectedPreviousPlanHash = lastPlanHash, plan.nonce = expectedNonce and plan.previousPlanHash = expectedPreviousPlanHash; expectedGeneration and plan.authorizedGeneration must both match the current generation, and the plan epoch must be current, the old rule/structure commitments to match the preceding effective schedule, and the verifier/manifest commitments to match. It increments the nonce and emits `UpgradePlanInstalled(planHash, plan, artifactManifest)`. Nonces never wrap or reset, including during recovery; cancelled records remain in the journal. Off-chain configuration cannot create, replace or activate a plan.

For a timestamp plan, require `0 < T < 2^64`, strictly increasing timestamp triggers in the epoch, `migrationHash = 0`, and **T > installation block.timestamp + maxAnchorAge**, with checked arithmetic. A valid block using an earlier anchor cannot reach T under SPEC 3.4. Therefore crossing T requires an anchor from after publication; nodes authenticate the plan from that finalized L1 view before validating/signing the affected block. This lead bound is not a guarantee of software readiness or L1 finality.

For a structural plan, require **H >= installation-time lastCheckpoint.height + U**, `H < 2^48`, and H divisible by both oldK and newK. Also check all unchanged deployment bounds, including compatibility of U and maxBatchBlocks with newK. The U lead bound prevents an already valid suffix from having crossed H at installation. At most one structural plan may be pending; no new plan is installed until it activates, is cancelled, or becomes stale through a generation change. There is no L1-clock trigger for structural activation.

The owner may cancel only an unactivated structural plan, emitting `StructuralUpgradeCancelled(planHash)` and releasing its fence. A retry uses a fresh nonce/plan; it cannot reactivate a cancelled record. Timestamp plans and activated structural history cannot be cancelled or rewritten by these interfaces. An ordinary recovery inherits the deployment's timestamp schedule and activated structural history. An unactivated structural plan is ineffective once its authorized generation differs from the Inbox generation; its fence cannot revive, and a replacement requires new authorization. Section 8 verifier-failure rollback must separately repair any affected upgrade ranges while preserving journal/nonces and cancellation history.

Upgrade metadata lives in a separate ERC-7201 namespace `taiko.etna.upgrades`, never in SPEC appendix B's reserved slots. At the namespace base, successive slots hold: `uint256 nextNonce`, `bytes32 lastPlanHash`, `mapping(uint256 => bytes) plans`, `mapping(bytes32 => uint8) status`, and `uint256 pendingStructuralNoncePlusOne`. Stored status is 1 for a timestamp/baseline record, 2 for prepared structural, 3 for activated structural and 4 for cancelled; a generation-mismatched prepared record is effectively stale. Plan 0 and the initial journal are initialized with the Inbox, with nextNonce = 1 and lastPlanHash equal to the baseline hash. Baseline old/new commitments and K agree, its migrationHash is zero, and it uses the original pinned adapter/verifier policy. Each plan is retained byte-for-byte; view methods expose the same committed bytes. Nodes authenticate this state/code through their own finalized L1, rather than trusting a manifest publisher.

## 4. L1 proof routing and timestamp binding

The Inbox's immutable verifier is an upgrade-aware router implementing the configured `verifyProof` interface; each selected policy verifier preserves ZkRequiredVerifier's two-proof requirement. The `land(input, leaves, proof)` ABI and its 21-word V1 statement remain unchanged. The opaque `proof` argument has this canonical outer encoding:

```txt
proof = abi.encode(bytes32("ETNA_UPGRADE_PROOF_V1"),
  uint256 statementFormat, uint256 p, uint256 h, uint256 generation,
  bytes encodedStatement, bytes terminalELHeader, bytes twoProofs)
```

The prefix format is permanent for this routing protocol. Its p/h/generation are untrusted dispatch hints: use h to locate a candidate structural epoch and its pinned adapter, require the expected statementFormat and adapter code hash, then decode and require all hinted values to equal the authenticated statement fields. The router independently rechecks canonical epoch/range selection after decoding. For every supported format, keccak256(encodedStatement) must equal the commitment passed by the Inbox; the adapter cannot replace this binding. V1 additionally requires exactly appendix A's 672 statement bytes. Verify its deployment/chain/generation fields, and independently hash the exact terminal header against lastBlockHash. The adapter checks header number/stateRoot against lastHeight/lastStateRoot and returns the terminal timestamp. Header decoding uses the pinned structural encoding and a 4,096-byte bound. Unsupported future formats cannot activate without a pinned supported adapter; changing the permanent envelope or header-hash commitment itself requires a new-router migration at a structural boundary. No caller-supplied timestamp or L1 transaction timestamp substitutes for this binding. Extra fields/trailing bytes, unsupported encodings or a failed binding revert before delegating to proof verification.

First select the structural epoch containing h; while a same-generation structural plan is pending, reject h > H. Within the selected epoch, choose the latest applicable timestamp policy with T <= the authenticated terminal timestamp, or that epoch's baseline when none applies. Each successor structural baseline already includes the complete inherited timestamp schedule. An ordinary plan installed after that baseline extends it. The selected verifier/image-set identity is exact, not a union of all images ever registered.

For an ordinary fork, an old-only verifier accepts only terminal timestamps < T. The new policy proves **every** block in (p,h] against its own timestamp and the retained schedule; it supports mixed pre-T/post-T batches and grid segments. Strictly increasing EL timestamps make the terminal-header gate sufficient to exclude an old-only proof containing any post-T block. Both sub-proofs authenticate the same unchanged statement and complete interval. The outer header/context is not a third proof.

For a structural boundary, a batch must lie entirely on one side: h <= H or p >= H. A range p < H < h is rejected, even with a sound mixed-rule proof. No new-epoch range is accepted before activation. A post-H verifier validates the preserved starting checkpoint and the new rules without changing history through H. The guest authenticates the required plan/activation record under its statement-bound L1 reference header; that reference cannot predate the installation/activation it relies on. All original origin, cut, overlapping suffix, FI and two-proof checks continue to apply.

## 5. Activation and node/signing behavior

Ordinary EL forks require no stop at a grid height. A node authenticates and supports the plan before preparing, accepting, executing or signing a block whose timestamp is >= T. Its guest and Engine build/import use the same schedule. A batch crossing T is legal; a delayed old-only batch ending below T remains eligible after wall-clock T. Unknown or unavailable upgrade material keeps the node untrusted and prevents affected signatures; an authenticated rules violation follows SPEC 8's safety-halt path. A restart that preserves all rule/structure/statement commitments is operational; changing validity requires a plan. Same-domain HRS and signed journals are retained.

For a prepared structural plan, signers refuse proposals/votes above H until activation is authenticated; they do not reset state or automatically restart past this fence. ProcessProposal rejects an above-H candidate; a decided above-H block before activation is a safety halt and cannot land. The refusal itself adds no new slashing offence; existing double-sign rules still apply.

Structural activation requires, atomically, the expected current generation, **latest checkpoint height exactly H**, a retained H landing with the expected EL and Comet hashes, and the matching uncancelled prepared plan. A checkpoint above H, an unlanded H or mismatching hashes fails. The owner executes the canonical migration below and activation in one atomic governance operation; any failed call, assertion, invariant or final activation reverts the whole operation. H and earlier EL/Comet history remain unchanged.

```txt
Call = (address target, uint256 value, bytes data)
Assertion = (address target, bytes data, bytes expectedReturnData)
Migration = (Call[] calls, Assertion[] assertions)
migrationHash = keccak256(abi.encode(Migration))
```

`migrationDescription` is exactly that canonical ABI encoding. Calls execute in order, require value = 0 and success, and cannot target the executor itself. Each assertion is a successful STATICCALL with byte-for-byte expected return data; reverts, missing data and a different result fail. Implementations/code hashes, layout/config versions and any migration-completion markers are explicit assertions. An assertion is never an operator's unchecked Boolean.

The owner is an on-chain atomic governance executor controlled by the DAO/timelock, with its immutable code hash pinned in the structural descriptor. Its `executeStructuralUpgrade(planHash, expectedGeneration, H, ELHash, CometHash, migrationDescription)` checks plan/context/hash, takes the protected-state snapshot, executes exactly the committed calls and assertions, and calls Inbox activation before clearing its non-reentrant execution context. Inbox activation requires this actual owner, its pinned code hash, and `activeUpgradeContext()` equal to keccak256(abi.encode(planHash, expectedGeneration, H, ELHash, CometHash, migrationHash)). Direct or out-of-context activation is rejected. Deployments without that enforced atomic execution path cannot activate structural upgrades.

The executor and final activation enforce preserved checkpoint height/hash, H's complete landing record and authenticated header stateRoot, generation and fixed genesis/origin, FI head/tail, and the existing committee snapshot. A state-layout migration must preserve the logical staking principal/ownership/exit/top-up records, with an on-chain pre/post state-commitment assertion supplied by its pinned migration implementation; inability to check those invariants prevents activation. Nodes independently preserve already committed current/pending Comet validator transitions and their H+2 activation, plus all signed HRS/WAL state. App metadata conversion is deterministic under the pinned rule descriptor; incompatible pending-transition or signer-state changes use the new-genesis migration instead. These node checks cannot be replaced by an EL checkpoint hash alone. Activation emits `StructuralUpgradeActivated(planHash, H, ELHash, CometHash)` and starts the next structural epoch at H+1. Nodes independently authenticate finality of activation and H's checkpoint before enabling H+1; an unfinalized L1 activation is insufficient. Any required metadata migration preserves the fixed generation genesis and prior signer state; a migration that cannot do so uses the separate new-Inbox/new-genesis path.

## 6. Jobs, failures and acceptance

Jobs bind deployment, generation, plan-history/rules commitment, statement/config/image versions and (p,h]. Ordinary jobs may cross T with the new complete-schedule policy; structural jobs never cross H. Old-only proofs remain valid solely in their original pre-T or pre-H ranges. The on-chain router/fence invalidates out-of-range jobs, regardless of submission time; jobs cannot be relabelled or rewritten into a new version. Historical materials remain available for replay, while current policy selection excludes obsolete images outside their ranges.

Before T, deploy and validate both rule paths, real mixed-boundary two-proof capacity and node/signer readiness. If readiness or proving fails, stop before signing affected blocks and repair the implementation of the already authorized schedule; do not silently delay T or revert to old rules. A failed structural preparation/activation leaves the old rules and fence in place; the owner may cancel and authorize a new boundary before activation. After activation, reverting to old rules is another authorized upgrade/migration, not a local rollback. Existing signed state is never erased; settlement failure uses SPEC 8's separate recovery/rollback procedures. No zero-downtime or automatic recovery guarantee follows from either trigger.

The upgrade acceptance in [ACCEPTANCE.md](ACCEPTANCE.md#upgrade-activation-spec-101) covers canonical plan/API/storage encodings, exact T/H inequalities, proof/header binding, real mixed-boundary proofs, overlapping jobs, atomic migration, finality, restarts, recovery and historical replay. Deployment of these mechanisms and passing that acceptance are required before exercising upgrades; changing this specification is not implementation or launch acceptance.
