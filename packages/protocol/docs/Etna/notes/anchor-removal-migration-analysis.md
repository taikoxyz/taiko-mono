# Anchor removal: migration mechanism analysis

Date: 2026-10-01. Source checkout: `7217121d516ce37e8c1684d168d6e5b525f8765c`. This is a design analysis, not an implementation, live deployment audit or passing devnet rehearsal. Solidity references below describe the checked-in source. Design-page line references describe the starting version reviewed before the concurrent documentation rewrite.

The source decision is David's [strictly standard EIP-4788 direction](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756531478), preserved in the session snapshot `/tmp/etna-anchor-scratch/issue-22147.md`. It permits loss of automatic Anchor writes and automatic checkpoint persistence. It does not permit a Taiko-specific call, extended system-call payload or mandatory ordinary transaction that reproduces the anchor.

## Recommendation

Use the **current block's successfully retrieved canonical EIP-4788 value** to gate both legacy L2 checkpoint-writing paths. Legacy execution records zero; every Etna block records its authenticated segment-origin L1 execution hash, which is nonzero. The standard pre-execution write occurs before every ordinary transaction, including the first transaction of the first Etna block. Both `Anchor.anchorV4` and L2 `SignalService.saveCheckpoint` require the current recorded value to be zero; missing or malformed oracle results revert. Thus both paths close before the first Etna transaction without an L2 activation transaction, extra system call or persistent L2 phase word.

Remove `beginEtna`, `anchorEtna`, their transaction envelopes and the first-block activation MPT witness entirely. The L1 Inbox already checks ACTIVE and authenticates the exact sealed legacy head. Requiring the first segment's authenticated origin number to be at least its stored `activationL1Number` suffices. Activation does not require an L2 storage write. The first Etna block may contain zero transactions.

This conclusion is conditional on exact canonical oracle code, identical standard pre-execution behavior on builders/importers/provers, sound header-origin validation and a migration certificate proving that both contract guards are already present in the sealed legacy state. A bare `root != 0` consensus check authenticates no L1 origin.

## Why the existing paths need explicit closure

| Source evidence | Consequence |
| --- | --- |
| `packages/protocol/contracts/layer2/core/Anchor.sol:86` checks only the golden-touch sender; `:124` exposes `anchorV4`. | The public signing key is not an authentication boundary. Ordinary transaction semantics after the fork must not turn that sender into a checkpoint author. |
| `Anchor.sol:173` validates the previous ancestors digest, then calls `checkpointStore.saveCheckpoint` only when the supplied L1 number advances at `:181`. | In the first anchorless successor the last legacy digest can still match. A forged higher checkpoint can reach SignalService unless a new guard closes it first. |
| `Anchor.sol:199` through `:227` calculates the old digest excluding the parent, then adds the parent. | Later stale-digest reversion does not protect the first anchorless block. Do not rely on eventual uncallability. |
| `SignalService.sol:174` authenticates `_authorizedSyncer`, rejects zero hash/root, then overwrites `_checkpoints[VERSION][number]`. | The old contract-to-contract identity is insufficient after anchor removal. Add the independent L2 zero-value gate and a non-overwriting checkpoint rule. |
| `SignalService.sol:35` identifies Inbox as the L1 syncer and Anchor as the L2 syncer; constructor `:86` rejects a zero syncer. | L1 and L2 need explicit immutable mode/wiring. A zero-address sentinel is not supported by today's constructor and is unnecessary for the transition. |
| `SignalService.sol:206` rejects absent checkpoints by zero block hash; `:284` binds the proof root to the stored root. | Existing bridge proof consumers already require a checkpoint. Revealing a hash preimage can retain their proof ABI. |
| `packages/protocol/contracts/layer1/core/impl/Inbox.sol:364` publishes an L2 terminal checkpoint through L1 SignalService. | L1 publication keeps its migration phase gate and never uses the L2 beacon-root zero/nonzero discriminator. |

The existing design explicitly recognizes finite legacy draining (`design/migration.html:233`–`:240`), certificate-derived H0 (`:290`–`:309`), ACTIVE and immutable activation clocks (`:311`–`:320`), and an origin at/after activation (`:325`–`:326`). Its additional first-system-transaction switch (`:447`–`:458`) can be deleted without weakening those L1 predicates.

## Exact execution discriminator

The canonical beacon-roots contract is `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`. The standard privileged caller is `0xfffffffffffffffffffffffffffffffffffffffe`. The deployed bytecode and caller semantics remain the unmodified EIP-4788 implementation.

For each post-Unzen legacy or Etna block, before transaction execution, clients execute the normal EIP-4788 system call with exactly the header's 32-byte `parentBeaconBlockRoot`. No checkpoint tuple, Inbox proof, phase value or callback is passed. The canonical contract writes timestamp and root to its existing ring slots. The standard EIP-4788 operation precedes EIP-2935; each uses its upstream 30,000,000-gas system-call allowance and accounting outside transaction/header gasUsed, identically on builders, importers and proving guests.

The transitional contracts use this read operation:

```text
readCurrentRecordedRoot():
    require block.timestamp != 0
    require beaconRoots.codehash == manifest-pinned canonicalRuntimeCodeHash
    (ok, returnBytes) = beaconRoots.staticcall{gas: 100000}(abi.encode(uint256(block.timestamp)))
    require ok && returnBytes.length == 32
    return the exact bytes32 value

Anchor.anchorV4(checkpoint):
    require readCurrentRecordedRoot() == bytes32(0)
    run the existing legacy sender, ancestor and checkpoint checks
    run the existing legacy updates

L2 SignalService.saveCheckpoint(checkpoint):
    require msg.sender == retainedAnchorProxy
    require readCurrentRecordedRoot() == bytes32(0)
    apply preserved legacy checkpoint validity and agreed duplicate semantics

L1 SignalService.saveCheckpoint(checkpoint):
    use the L1 drain/ACTIVE Inbox authorization rule
    do not query EIP-4788 to determine phase
```

The code hash comparison is a proposed defense against accidentally installed noncanonical code; the manifest and migration proof must establish the same code hash. A nonzero code-length check alone is insufficient. A implementation can share a single audited helper; it must not turn a failed query into a successful zero read.

Important distinctions:

1. The getter takes **raw 32-byte calldata**, with no Solidity selector. It returns zero successfully for an existing zero-root record. Timestamp zero, a timestamp miss or a modulo-collision miss is an error, not evidence of legacy execution.
2. Query `block.timestamp`, not a caller-provided timestamp, parent timestamp, old checkpoint timestamp or latest known off-chain timestamp. After the current pre-execution write, the current ring entry cannot be displaced by older entries.
3. Do not change the canonical getter to reject stored zero roots. Legacy execution needs to distinguish an authenticated zero record from missing data. The reveal entrypoint independently rejects zero roots.
4. The legacy caller check remains. The zero-root condition is an additional fork discriminator, not permission for anyone to save legacy checkpoints.
5. The Etna header rule is `parentBeaconBlockRoot == s.origin.hash != 0` for **every** block. `s.origin` is the exact authenticated HeaderStore tuple supplied to Inbox and bound by the proof. No per-block checkpoint choice remains.
6. Missing oracle state is fail-closed. Do not add `catch { return 0; }`, an empty-code exception, a timestamp-fork fallback or an owner emergency switch.
7. No application may directly write the canonical oracle. Its system-only write branch remains upstream behavior; a normal call from an ordinary account goes to the getter. Private-key unforgeability for the system address remains the ordinary Ethereum assumption.

This closes the first-block attack even if the attacker pays normal fees and includes a golden-touch transaction at index zero, last index or through a contract. The Anchor guard fails before its mutations; the SignalService guard independently prevents publication. A EIP-7702 authorization for the former golden-touch account grants no checkpoint authority after Etna. There is no continuing reserved-sender, fee-exemption or transaction-index rule needed for that address in Etna.

The discriminator is one-way **along accepted Etna descendants**, since their header rule never permits zero again. It is not a permanent Solidity latch independent of chain history. Correct historical replay and an L1 reorg may legitimately execute an older zero-root legacy history. A standalone EVM run with a fabricated zero header is not an accepted Etna block.

## Activation without an activation transaction or witness

Retain the existing L1 phases PREPARED → DRAINING → ACTIVE and the exact finite-drain certificate. Keep the Inbox phase namespace and its activation clocks. Delete the proposed Anchor phase namespace A; if a deployed variant already had a reserved slot, preserve the slot rather than recycling it, but this design never writes a new A word.

The successful permissionless L1 `activateEtna` operation still:

1. Verifies the migration certificate against the immutable manifest and READY adapter state.
2. Verifies no frozen proposal or forced obligation remains unproved.
3. Verifies the terminal legacy root contains all required upgrades and canonical EIP contracts.
4. Atomically seals the legacy adapter, installs the unique certificate-derived H0, records `initialHeadHash`, enters ACTIVE and records `activationL1Number`/`activationTime`.

It never waits for a first Etna block or for an L2 activation flag. H0 commits only to the terminal **legacy** root. The migration certificate must not assert that 4788 already contains a nonzero Etna root or that a post-Etna checkpoint has been revealed; either would create a dependency on the work activation enables.

At first-segment acceptance Inbox independently requires:

```text
phase == ACTIVE
s.oldHeadHash == hashHead(currentHead)
s.segmentNumber == currentHead.segmentNumber + 1

if currentHead.segmentNumber == 0:
    s.segmentNumber == 1
    s.oldHeadHash == stored initialHeadHash
    currentHead is the exact stored H0
    s.firstL2Number == H0.l2Number + 1
    s.origin.number >= immutable activationL1Number
    s.forceStart == s.forceEnd == 0
    body.forced is empty

HeaderStore contains exactly s.origin
s.origin.hash != 0 && s.origin.stateRoot != 0
normal origin age, earlier-than-landing, stage, DA and producer checks pass
```

Because HeaderStore authenticates an ancestor in the *same* L1 history, an origin at the activation block or later has a post-state after activation. The activation block's complete header can be used once that block has been produced and its hash can be pinned from a later block. An intra-block state root before the activation transaction is not the root in that execution header. A future or alternate-chain RPC header cannot satisfy HeaderStore's canonical hash check.

There is no new boolean supplied by a caller or private proof witness. The existing statement already commits `oldHeadHash`, segment number, origin and body hash (`design/index.html:42`–`:53`). The circuit already reconstructs the complete prior Head and authenticates its hash. Inbox's exact stored-head checks establish whether its segment-zero sentinel is legitimate. The existing public-input hash binds the complete statement and mandatory force hash (`design/index.html:135`–`:142`), so it needs no extra activation field.

The circuit proves the first header extends H0's exact block hash, uses H0's state root, satisfies all header rules and executes the standard system operations plus its ordinary transaction list. It uses the segment-zero exception only for the authenticated prior Head and enforces the empty first force interval. Subsequent heads have nonzero authenticated origins and retain origin monotonicity, including exact hash equality at equal height.

A local preconfirmation verifier checks the public activation/certificate/H0 facts and canonical origin in its current L1 view before claiming `VALID_IN_VIEW`. If it lacks that context, the result is `UNKNOWN`. The L2 executor itself does not need L1 RPC during execution; origin authentication is the validator's separate responsibility. EVM success is not origin authentication or L1 finality.

Dependency order is therefore:

```text
ordinary legacy installation and canonical EIP deployments
  → fully proved finite legacy terminal state
  → migration certificate
  → L1 activation and unique H0
  → available authenticated L1 origin at/after activation
  → first header and standard pre-execution root write
  → ordinary transaction list, possibly empty
  → public staging, proof, acceptance and Ethereum finality
```

Nothing in this order depends on a future segment commitment, future landing block hash, first transaction sender or optional checkpoint reveal.

## Deployment and drain order

1. **Audit and roll out execution parity first.** In the source issue, geth builds skip 4788 when the root is nil and stamp zero too late, while import executes the zero write. This becomes consensus-critical the moment code exists. Verify the fix and exact versions for every builder, importer, Go/Rust driver and legacy/Etna proving guest, including empty/default blocks and engine API derivation. The issue's parity report is historical evidence, not proof that the launch versions are deployed.
2. **Deploy canonical EIP-2935 and EIP-4788 contracts before Etna.** Use their audited canonical ordinary deployment transactions at canonical addresses, after parity requirements are met, with required ordinary prefunding. New networks may use a reviewed genesis allocation. Do not introduce first-Etna deployment transactions or fork-time code insertion. EIP-2935 is separate from checkpoint revelation and has its own parity check.
3. **Observe canonical legacy blocks with deployed code.** They must execute both standard pre-execution calls identically. 4788 stores authenticated zero records. A contract deployed during transaction execution was absent at that block's pre-execution step; do not mistake that deployment block for a successful zero-write demonstration. The next block can produce one.
4. **Install both transitional guards and reveal support through normal pre-cutover upgrades.** Preserve all addresses, old slots and immutable remote identities. Legacy `anchorV4` continues with its old envelope, gas and historical fee split. The root zero condition is satisfied on valid legacy blocks. Reveal support creates no record from those zero roots.
5. **Freeze and drain using the existing finite adapter.** Historical proposals and forced/default blocks remain legacy; both continue to include their legacy anchors. A future L2 timestamp is never the activation switch. Old proving programs must support the actual canonical EIP deployments and guard execution, or an audited compatible legacy revision is a launch prerequisite.
6. **Certify the full installation in the terminal legacy root.** Bind canonical EIP runtime code hashes, both retained proxies' implementation identities/storage layouts, both guards, L2 reveal mode, L1/remote wiring, preserved checkpoint/cache version and immutable migration configuration. Reject partial installation. Do not ask a digest or address declaration to substitute for an authenticated state/code proof.
7. **Activate on L1, then build first Etna normally.** The nonzero origin hash replaces the legacy zero value in the header. Standard EIP-4788 closes both old paths before all ordinary transactions. No DAO action is required between terminal legacy and first Etna execution.

The first-Etna boundary is identified by the authenticated migration head and Etna revision, not by a fixed wall-clock fork timestamp. A timestamp gate by itself can halt a slow legacy drain or a valid legacy block carrying a later timestamp. All participants must select the proper legacy/Etna validation relation for historical execution and the authenticated branch.

The existing finite drain semantics remain mandatory. In particular, the deterministic forced suffix still has its original source plus a default legacy anchor-only source (`design/migration.html:409`–`:418`). Removing anchors from those *legacy* blocks would change committed derivation and invalidate the migration proof. Removing Etna anchors is not permission to erase old obligations or change old fees.

## Retained storage, interfaces and changed observables

| Component | Required design change | Preserved property |
| --- | --- | --- |
| Retained L2 Anchor | Transitional zero-root guard on `anchorV4`; no `beginEtna` or `anchorEtna`; no new phase word. Retain historical getters and any independently specified fee sweep. | Proxy address; `blockHashes` slot 251; Pacaya slots 252–254; `_lastProposalId` 255; `_blockState` 256–257; gap 258 onward. See `Anchor_Layout.sol:21`–`:25`. |
| Retained L2 SignalService | Immutable explicit L2 mode; guarded legacy `saveCheckpoint`; permissionless `revealCheckpoint(uint64,bytes)` with exact 4788/header authentication and idempotent non-overwriting persistence. | VERSION=1; received cache slot 253; checkpoints slot 254; signal-slot domain and remote proxy. See `SignalService_Layout.sol:21`–`:24`, `SignalService.sol:49`–`:75`. |
| L1 SignalService | Keep finite legacy syncer before ACTIVE and new Inbox afterward; reject the L2 reveal entrypoint explicitly. | Accepted L2 terminal root publication remains atomic with canonical L1 head acceptance. |
| New Inbox | First-head ACTIVE/origin-height checks replace execution of the activation MPT proof. | `activateEtna`, certificate, H0, clocks, immutable manifest and drain protocol remain. |
| Body and statement | Allow 0…1024 ordinary transactions per block; keep 8192 segment transaction cap and existing three-field BodyV1. Remove anchor args and activation arrays. | Canonical RLP/transaction/header encodings, DA caps and public reconstruction; existing statement and proof hash formats suffice. |
| EVM profile | Standard 4788/2935 calls plus ordinary transactions; no anchor sender, fixed-k, receipt, gas reserve or fee exemption. | Header gas limit remains exactly 10,000,000. Upstream system-call work is part of execution/state/proving, with upstream transaction gas accounting. |
| Bridge/Vault | Separate reveal may precede an unchanged bridge proof/claim. | Addresses, custody, message status, signal proofs and historical checkpoints/caches remain. |

Anchor history stops advancing after the final legacy block. Its stored latest L1 number and ancestors digest are explicitly **historical**; do not fabricate new values in their getters. EIP-2935 supplies only its bounded rolling L2 hash history after deployment; it does not preserve permanent `blockHashes` semantics or backfill old history. Preserve already stored mapping entries and every reserved slot even if no new writes use them. Old `Anchored` events stop.

Current L1 origin consumers resolve the accepted/local L2 header's `parentBeaconBlockRoot` to the complete authenticated L1 header. A latest-revealed checkpoint may lag that actual origin and is not a substitute for it. The raw L1 header must hash exactly; use a compatible upstream encoder or raw-header source, not hand-assembled partial fields.

The companion checkpoint design adds ordinary `pinCurrentOrigin()` and `revealPinnedCheckpoint(bytes)` calls with an explicit new pinned-origin namespace. A pin preserves a nonzero current origin hash before its ring entry can be lost; it requires no header preimage and its calldata is exactly four bytes. This does not change the migration discriminator or introduce a mandatory transaction. The complete normative API, namespace and forced-recovery rules are in `design/checkpoints.html`.

For new L2 checkpoint persistence, the reveal checks a canonical full L1 RLP header of at most 1,536 bytes, a nonzero 32-byte state root at item 3, a canonical integer fitting uint48 at item 8 before conversion, and exact hash equality to a successfully retrieved nonzero recorded root. An existing equal checkpoint is an idempotent success even after oracle expiry; a conflicting record fails. Do not require a global increasing reveal order. Existing signal proof APIs and cache-count return value can stay unchanged for separate reveals. Any optional one-transaction proof extension is a separate versioned interface design, not an activation prerequisite.

Minimal bootstrap body is `RLP([1, [[headerRlpBytes, []]], []])`. At the 1024-byte header limit it is at most **1039 bytes**, comfortably below the existing 32768-byte calldata cap. It has empty transaction and receipt tries and zero transaction gas used, yet a nontrivial state transition from standard system calls. No first-block activation MPT execution or 1,000,000-gas anchor envelope remains. Complete L1 proof/staging/acceptance costs still require measurement.

## Counterexamples and required response

| Attempt or failure | Incorrect design | Required result |
| --- | --- | --- |
| First anchorless block includes paid golden-touch `anchorV4(fakeHigherCheckpoint)` | Trust that the ancestors digest is already stale. | Current nonzero 4788 entry rejects it before either old writer publishes anything. |
| First Etna block executes `anchorV4` before an ordinary `setEtna` or `revealCheckpoint` transaction | Disable legacy only after a normal transaction flips phase. | There is no such phase transaction; standard pre-execution already closed the path. |
| Slow legacy drain crosses scheduled FORK_TS, or a valid preactivation legacy header has a later timestamp | Use timestamp alone to disable the old anchor. | Valid legacy zero-root blocks still drain. Etna admissibility depends on activation/H0 and authenticated origin. |
| Attacker supplies old zero-root timestamp to the guard | Query attacker input rather than current block timestamp. | Guard always queries exactly `block.timestamp`. |
| Oracle is absent, getter reverts or returns an empty string | Treat read failure/default decoding as zero. | Both legacy writers revert; preflight prevents activation with this installation. |
| Noncanonical contract at canonical address returns zero | Check only nonempty code or trust an address label. | Runtime code hash and certified state must match canonical code. |
| Etna block uses zero header root to reopen legacy writer | Run EVM and infer validity from contract success. | Header/guest validation rejects before accepting the block; no L1 checkpoint for that root. |
| Etna header carries nonzero invented L1 hash | Validate merely nonzero root. | Exact HeaderStore/statement/origin equality fails; a fake root cannot reach accepted L2 history. |
| Caller invokes canonical 4788 with the bytes of a fake root | Treat any contract call as a write. | Ordinary caller enters canonical getter logic, not the system write branch. |
| Canonical contract deployed before geth build/import parity | Assume existing hook calls have always been state-equivalent. | Deployment is blocked pending parity evidence; otherwise state roots diverge immediately. |
| Certificate proves new Anchor but not guarded SignalService, or vice versa | Audit only a manifest address list. | Installation relation rejects missing code/guard and prevents activation. |
| Certificate requires first nonzero 4788 root or Etna phase slot before L1 activation | Make the terminal legacy state depend on first Etna execution. | Reject that certificate design as circular; certify only preinstalled capabilities. |
| First origin predates activation, while L2 timestamp is after activation | Treat L2 time as proof of Inbox ACTIVE. | Inbox enforces canonical `origin.number >= activationL1Number`. |
| Circuit accepts prover-selected `isFirstEtna` for a later head | Permit arbitrary bootstrap sentinel bypass. | Exact stored head and segment sequence determine bootstrap status; no free flag. |
| Permissionless reveal front-runs an identical reveal | Non-idempotent duplicate logic creates griefing. | Identical stored number/hash/root succeeds; no second write or conflicting overwrite. |
| No one reveals a newly recorded origin | Require a reveal/receipt every block to make the fork usable. | Block/segment remains valid. A relayer reveals an available authenticated header when a claim needs it. |
| Previously recorded oracle entry is overwritten after a timestamp jump | Assume 8191 stored blocks or guaranteed wall-clock retention. | Old missing entry cannot reveal; use a previously pinned origin, an already persisted checkpoint, or a newer recorded origin containing the persistent signal. |
| L1 reorg removes activation or selected origin | Treat nonzero root as finality or retain effects from orphan history. | Roll back dependent L2 history and its checkpoint/bridge effects; verify against the replacement canonical L1 view. |

The 4788 ring uses `timestamp % 8191`, not an 8191-block queue. Overwrite of an entry at timestamp t requires a later colliding timestamp, whose minimum positive difference is 8191 timestamp seconds; gaps can jump directly to one. This is not an unconditional wall-clock service guarantee. A stopped chain does not expire entries merely through elapsed real time. Newly executed blocks record the current origin even when the origin repeats, making a recent timestamp usable for reveal. Cross-layer liveness still assumes block production, a funded capable participant and proof/header availability.

## Finality and verification obligations

The current root is authoritative only within a validated L2 history. Neither a reveal transaction nor an executed soft block establishes Ethereum finality. HeaderStore pins canonical L1 ancestry in the acceptance history; if a relevant ancestor is reorged, dependent pins, acceptance and derived L2 effects must roll back. Historical checkpoint/cache preservation remains conditional on A-LEGACY. A new implementation cannot retroactively authenticate unsound old roots.

The implementation rehearsal must cover zero-root legacy execution after both deployments; ordinary deployment-block versus next-block behavior; empty first Etna execution; direct and nested late legacy calls; an Etna golden-touch sender/type-4 authorization; missing/malformed oracle reads; nonzero but wrong origins; a future-timestamp preactivation legacy block; rollback across installation/activation; partial upgrades; default/forced drain blocks; preserved cache and old-message claims; and identical build/import/prover state roots. These are future checks, not claims of tests run in this documentation task.

No experiment or production-source modification is needed to establish the mechanism. Launch remains blocked until actual deployed code, client/guest parity, storage layouts, proof artifacts, canonical deployment transactions and finite-drain data have been authenticated and rehearsed.
