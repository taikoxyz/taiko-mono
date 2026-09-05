# Slot Chain V2.27 Full Contract Implementation Design

**Status:** Approved and independently reviewed implementation architecture, amended for the v2.27 freeze

**Normative protocol baseline:** `de437d8270460b38775c30d77e26f2da328a477f`

**Stacked repository baseline:** `538742575d732507c26f9c895a3ccbe3d11207e6`

**Target branch:** `codex/slot-chain-v2-contracts`

**Stacked base:** `claude/chain-liveness-builder-roles-cda13y` / PR #22064

## 1. Objective

Implement and test every on-chain Slot Chain V2.27 component described by the frozen LaTeX, PDF,
executable models, and commitment vectors at the normative protocol baseline. Remove provisional,
superseded, unreachable, duplicated, and specification-incompatible Slot Chain code before it can
be mistaken for a production component. The result is an additive, deployable V2 suite under
`packages/protocol`; it must exercise real Solidity storage, authority, accounting, bounded-gas,
migration, settlement, bridge, and reclamation behavior.

PR #22096 owns all Solidity, tests, generated contract artifacts, conformance tooling, and
implementation-only planning. PR #22064 remains design-only. PR #22096 must not change the
normative LaTeX, PDF, Python models, or protocol vectors by inventing a Solidity-specific rule. If
implementation exposes a contradiction, work on the affected slice stops and the correction is
made and reviewed on PR #22064 before implementation resumes.

The implementation PR must not select the V2 suite for production, modify the behavior of the
currently selected Inbox, Bridge, vault, Resolver, or deployment path, or treat a passing test
suite as deployment authorization. Production cutover remains a separately reviewed operation.

## 2. Normative Precedence

The implementation consumes, in descending precedence:

1. `packages/protocol/docs/preconfirmation-v2/tex/main.tex` at normative commit `de437d827`;
2. the executable Python models and commitment vectors in the same directory;
3. this implementation architecture; and
4. repository Solidity conventions in `packages/protocol/CLAUDE.md`.

The older August 29 contract-suite specification, the September 1 implementation plan, and their
earlier baselines are historical inputs. They may be reused only where they agree with v2.27. In
particular, no older
Bridge-facade, shared-cap, migration-callback, route-authority, retirement, or reclamation rule may
override the final VMC1, RAV2, DRV2, DSV2, ICV2, BRX1, or related fixed-width protocols.

If Solidity exposes a contradiction between normative sources, the current implementation round
stops. A failing regression is added, the model and LaTeX/PDF are corrected in an isolated design
commit, and implementation resumes only after that correction is reviewed.

## 3. Selected Architecture

The selected implementation method is a conformance-led incremental rebuild. Existing code is not
grandfathered merely because it compiles or has tests. A source is retained only after its ABI,
hash domains, widths, state transitions, gas envelope, failure semantics, and ownership class match
v2.27 and its focused differential tests pass. Everything else is deleted or rewritten; no
compatibility shim may preserve a superseded V2 draft API.

A tracked conformance ledger maps every normative component, selector, fixed-width return, state
transition, custom error, commitment vector, gas bound, and release-blocking invariant to its
implementation and tests. A ledger row may be `missing`, `red`, `passing`, or `reviewed`; only
`reviewed` satisfies completion. Generated reports must fail if a normative row is absent, if a
Solidity surface has no normative row, or if a reviewed row's source/test hashes drift.

### 3.1 Dead-code policy

The first implementation slice removes the untracked provisional ScheduleOracle experiment:

- `packages/protocol/contracts/layer1/slotchain/iface/IScheduleOracleV1.sol`;
- `packages/protocol/contracts/layer1/slotchain/impl/ScheduleOracleV1.sol`;
- `packages/protocol/contracts/layer1/slotchain/libs/LibScheduleOracleReads.sol`; and
- `packages/protocol/test/layer1/slotchain/schedule/ScheduleOracleV1.t.sol`.

Those files explicitly describe an incomplete release-only slice and do not implement the frozen
constructor, seal, snapshot, expiry, liability, and activation rules. Their behavior must not be
salvaged behind the same names. The same rule applies to committed partial components: retain them
only when the conformance ledger and tests prove exact v2.27 behavior. Dead-code discovery covers
unreferenced source, unreachable selectors, obsolete domains/magic values, duplicate authorities,
test-only production paths, stale generated artifacts, and ownership-manifest rows without a live
consumer. Deletion is verified by compilation, reference search, artifact-ownership checks, and
the conformance ledger; it is never inferred only from line coverage.

The suite is dependency-layered and isolated from the live protocol:

```text
packages/protocol/contracts/
  shared/slotchain/
    iface/     chain-neutral interfaces and exact external boundaries
    libs/      encodings, trees, signatures, proofs, checked calls
    impl/      chain-neutral custody and frozen facade implementations
  layer1/slotchain/
    iface/     L1 component interfaces with full NatSpec
    libs/      authenticated history and pure L1 transition helpers
    impl/      market, registry, queue, settlement, migration, source bridge
  layer2/slotchain/
    iface/     L2 component interfaces with full NatSpec
    libs/      route, credit, execution-context, terminal helpers
    impl/      activation, apply router, stores, destination bridge, pool, terminal plane

packages/protocol/test/
  shared/slotchain/
  layer1/slotchain/
  layer2/slotchain/

packages/protocol/integration/slotchain/
  two-chain deployment, relay, migration, bridge, and restart tests
```

### 3.2 Complete component inventory

The conformance ledger is seeded from the following explicit inventory. A later plan may split a
row into libraries and interfaces, but it may not omit, merge, or replace a deployable or
creation-only boundary with a catch-all label.

The root build contains exactly eighteen artifacts from one release-pinned compiler invocation and
one `layer1` artifact-owner profile:

| Root artifact | Root role / lifecycle |
| --- | --- |
| `RootMigrationExecutorV1` | Permanent bootstrap authority; independently deployed and one-shot consumed. |
| `ProtocolRootFactoryV1` | Permanent immutable root factory. |
| `ProtocolRootCreate3ProxyV1` | Fixed CREATE3 proxy creation and runtime artifact embedded by the factory. |
| `BuilderRegistry` | Root role 1; protocol-lifetime. |
| `ScheduleOracle` | Root role 2; protocol-lifetime. |
| `ProtocolChangeTimelockV1` | Root role 3; protocol-lifetime. |
| `ProtocolVersionManagerV2` | Root role 4; protocol-lifetime. |
| `ActiveSettlementRouter` | Root role 5; protocol-lifetime and owner of the migration gate word. |
| `ForcedQueue` | Root role 6; protocol-lifetime. |
| `AggregatorSeatMarket` | Root role 7; protocol-lifetime perpetual reverse-ask auction. |
| `BridgeDomainRegistry` | Root role 8; protocol-lifetime append-only registry. |
| `SourceBundleFactory` | Root role 9; protocol-lifetime. |
| Manifest-named source-bundle deployer | Additional role-9-reachable creation/runtime artifact. |
| `BridgeInboxAdapter` | Additional role-9-reachable artifact; release-scoped instances. |
| `SourceBridgeV2` | Additional role-9-reachable artifact; release-scoped instances. |
| `BridgeCreditRegistryV2` | Additional role-9-reachable artifact; release-scoped instances. |
| Source native `QuotaManager` | Additional role-9-reachable artifact; release-scoped instances. |
| `SourceTerminalVerifier` / `TerminalSignalVerifier` | Two normative names for the same immutable, read-only, unpausable root-lifetime artifact. |

`SourceBundleFactory` occurs once in the eighteen-artifact count even though both the role manifest
and source-artifact root commit it. The two commitments must resolve to byte-identical creation and
runtime code. The terminal verifier is deployed once as root source infrastructure, and its
address, runtime and configuration repeat across every release; it is never a fresh bundle child.

The remaining PR-owned deployables and release-scoped instances are separately ledgered:

| Plane | Required concrete boundaries |
| --- | --- |
| Settlement | Fresh `Settlement` implementation and its manifest-pinned deployment artifact, normal/recovery proof entry points, data sessions, canonical history, reward receipts and migration lifecycle. |
| L1 ingress/proofs | Distinct kind-0 ingress adapter; `ScheduleSszMultiproofVerifierV1` and the exact schedule-fork verifier interface/call boundary; `RegistrationMptVerifierV2`; migration-transition verifier descriptor/interface/call boundary. |
| Source bundle | Bundle deployer, `BridgeInboxAdapter`, `SourceBridgeV2`, `BridgeCreditRegistryV2`, source native `QuotaManager`, support registry and pauser components named by the source descriptor. |
| Destination lifetime | `ProtocolReleaseAuthorityV2`, `InboxApplyRouterV2`, `TerminalDomainRegistrarV2`, `TerminalAccumulatorV2` and `NativeLiquidityPoolV2`. |
| Destination release | Fresh `InboxCreditStoreV2`, `DestinationBridgeV2`, native `QuotaManager`, endpoint/domain state and the manifest-selected `AnchorV4` installation boundary. |
| Genesis compatibility | `LegacyGenesisCutoverInboxV1`, `LegacyResumeZkPairVerifierV1`, immutable fixed-key RISC0 and SP1 adapters, and the exact legacy facade/install boundaries admitted by the compatibility profile. |

Creation-only rows are independently owned even when no reusable runtime remains: the fixed
`ForceSend` init code and hash, complete component and release init codes, bundle creation code,
and any manifest-pinned raw creation artifact. The ledger proves their byte length, code hash,
consumer and one permitted deployment path.

Manifest-pinned external or legacy dependencies are not misreported as PR-owned implementations.
They include the canonical ERC-2470 singleton, EIP-4788 beacon-root and EIP-2935 history carriers,
the selected builder token and legacy V1 Inbox/Bridge/SignalService endpoints, external RISC0/SP1
verifier roots and the release-selected schedule-fork, registration-MPT and migration-transition
proof systems/keys. PR #22096 owns their exact interfaces, descriptors, fixed-key adapters where
specified, authenticated call paths and fault-injection tests; it does not fabricate cryptographic
verifier bytecode or keys that the normative release manifest treats as external inputs.

Interfaces and factories are deliverables, not substitutes for the concrete state machines.

Production components are non-proxy unless the frozen legacy-compatibility profile explicitly
requires a final storage-compatible facade or the authenticated AnchorV4 topology. Dependencies
are constructor immutables, deterministic precomputed addresses, or narrowly scoped one-shot seals.
There is no generic Resolver dependency, arbitrary setter, delegate target, root setter, or
governance pause on canonical progress or claims.

Source ownership and artifact ownership are separate. Shared types, interfaces, constants and
libraries whose production members are exclusively `internal` are canonical **source-inline**
modules. L1 and L2 consumers necessarily compile and inline that same source in their own profiles;
those modules have no independently consumed deployable artifact. The ownership checker pins their
source hash, allowlisted consumer profiles and kind-specific nondeployability: ABI-only interfaces
may declare external functions but produce no bytecode, while internal libraries have no
public/external production functions and produce no consumer link references. All deployable
contracts instead have one **artifact-owned** Foundry profile. An externally linked library, if ever
unavoidable, is artifact-owned and linkable only inside that same owner profile; shared L1/L2 logic
uses internal source-inline libraries. Cross-profile users load an artifact-owned contract's
already compiled bytecode or call it through a separate source-inline ABI-only interface; they do
not source-import and recompile the implementation under another EVM or optimizer configuration.
Build-info does not self-authenticate a Foundry profile name. Profile identity is therefore the
trusted clean-build invocation plus its fixed output root, checked against the resolved
`forge config --json` compiler, source, test, script, output and cache settings.
Every managed build-info AST must be a structurally valid Solidity `SourceUnit` with an array of
typed child nodes; missing, falsy or malformed AST data proves nothing, even for a
`free-definitions` source that emits no contract artifact. Since Forge tests have FFI authority and
build outputs are mutable, the final ownership trust point force-rebuilds shared, L1 and L2 and
immediately checks those fresh outputs after all executable tests have completed.

The artifact and address ownership classes are:

| Component class                                                                                                                                         | Chain               | Ownership/build rule                                                                                                       | Lifecycle/address rule                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Types, interfaces, constants, and internal-only encodings, trees, proof/call libraries                                                                  | Both                | `source-inline`; canonical shared source hash; compile only in allowlisted consuming profiles                              | No independent deployed address or runtime; consumers contain the inlined code and must have zero link references to the module.         |
| Chain-neutral deployables                                                                                                                               | Both                | `artifact-owned` by `shared`, `out/shared`, oldest supported fork; cross-profile use loads bytecode or a source-inline ABI | Exactly one creation/runtime artifact owner. A deployed object's manifest scope determines address reuse.                                |
| Complete eighteen-artifact root set listed above                                                                                                      | L1                  | One release-pinned compiler invocation; `artifact-owned` only by `layer1`, `out/layer1`; no shared or mixed-profile exception | Root-lifetime objects repeat address/runtime/configuration; release-scoped members use fresh instances as specified.                      |
| Settlement, kind-0 ingress and source bundle release-scoped instances                                                                                  | L1                  | `artifact-owned` by `layer1`; an artifact in the eighteen-root set can never be sourced from `shared` or another profile   | Fresh release-scoped accounts. Historical accounts serve only retained liabilities/proofs and never become current again.                |
| InboxApplyRouterV2, ProtocolReleaseAuthorityV2, TerminalDomainRegistrarV2, TerminalAccumulatorV2 and NativeLiquidityPoolV2                              | L2                  | `artifact-owned` by `layer2`, `out/layer2`                                                                                 | Protocol-lifetime objects; successors repeat address/runtime/configuration and preserve cursor/routes/releases/writers/tickets/frontier. |
| InboxCreditStoreV2, DestinationBridgeV2 and native QuotaManager                                                                                         | L2                  | `artifact-owned` by `layer2`, `out/layer2`; no shared-output fallback                                                       | Fresh release-scoped accounts and endpoint domain. Reuse is forbidden even when code is identical.                                       |
| Frozen legacy facades and AnchorV4                                                                                                                      | Owning legacy chain | `artifact-owned` by the manifest-named profile; compiled artifact hash recorded before installation tests                  | Installation is exercised only in isolated migration tests. This PR does not select it on the production path.                           |

The release manifest's exhaustive component table remains authoritative for individual kinds. The
ownership checker rejects an unclassified module, source-inline hash/profile/kind/ABI/link drift,
artifact-owned cross-profile recompilation, output-path drift, a fresh address for a
protocol-lifetime object, or reuse of a release-scoped address. Generated compiler artifacts for a
source-inline module are not addressable protocol artifacts and cannot be loaded, linked, deployed,
or placed in a release manifest. This compiler-output gate pins source, ABI, creation/runtime,
compiler, link-reference and immutable-reference commitments. Constructor-derived
`componentConfigHashV2` values are not compiler outputs and are checked later against live
deployments by the independent deployment-transcript gate.

## 4. Component Boundaries

### 4.1 Shared primitives

Shared libraries implement byte-exact commitments, fixed-domain Merkle trees, the bounded MMR,
canonical RLP/MPT verification, low-`s` signatures, checked arithmetic, and exact-length checked
external calls. A caller cannot choose a hashing domain, silently narrow an integer, accept trailing
return data, or substitute an uncommitted code/configuration hash.

Interfaces own full NatSpec. Implementations use `@inheritdoc`, named imports, repository naming
conventions, custom errors, and the required security contact.

### 4.2 L1 availability and economic plane

The L1 data plane contains the immutable economic profile, builder registry and liability
generations, schedule/lookahead oracle, bounded data sessions, permanent forced queue, and the
continuous reverse-ask `AggregatorSeatMarket`.

The seat is an availability service obligation, never consensus or proof authority. The market
owns offers, tranches, premium reserves, pull credits, staged handovers, release requests, and
asynchronous enforcement. Settlement owns the current roster and duties. Every cross-contract
mutation uses the exact fixed-width interface and exact target defined by the baseline.

### 4.3 L1 settlement and migration plane

Settlement owns candidate validation, normal settlement, recovery episodes, canonical history,
reward receipts, roster duties, successor selection, and bounded reclamation. Proof submission,
forced recovery, sync, and canonical progress remain permissionless and do not call the market or
an operator-controlled address.

`ActiveSettlementRouter` (including its single owned migration-gate word),
`ProtocolVersionManagerV2`, and the deployment factories implement proof-first activation and
abort. The gate is Router storage, not a contract or address. VMC1 is the sole post-QMIG mutating external call, is
made with its exact 100-byte calldata, zero value, exact caller, and 200,000 requested gas, and is
the final external call inside the outer atomic activation revert domain.

No component may select a historical Settlement, route, Bridge, generation, or source bundle by a
caller-supplied witness. Authority is derived through the Router/registry fixed-width reads and
manifest-pinned code/configuration.

Ordinary tier-1/2/3 proofs use one immutable
`SettlementValidityVerifierDescriptorV2` committed by the execution profile and target
constructor. It is distinct from the migration-transition verifier. The descriptor binds exact
address, runtime, acyclic configuration, verifying key, proof system, public-input schema,
selector, proof-size limit, call gas, and post-verification reserve. Settlement authenticates
code/configuration on every proof and accepts only an exact 32-byte return equal to its independently
reconstructed statement hash. One descriptor is permitted only because its key proves the
authenticated tier and all three branches; no tier fallback, mutable registry, inherited
predecessor verifier, or caller-selected verifier exists.
The verifier runtime is state-independent: its key/configuration are embedded, it has no storage,
proxy, delegatecall or mutable external dependency, and any STATICCALL target is a fixed precompile
authorized by the `proofSystemId` policy. Registration checks the full transient descriptor and
stores its hash in RTR2; activation recovers the full descriptor from the target's exact 352-byte
SVD2 view, hashes it against RTR2, and repeats live code/configuration checks before switching.

### 4.4 Source and destination bridge planes

The source side uses fresh V2 custody: immutable SourceBridge, BridgeCreditRegistry, quota/domain
registry, queue adapter, and terminal-proof finalization. It never reuses the existing V1 Bridge
account and never mutates V1 selectors or storage. The root-lifetime
`SourceTerminalVerifier`/`TerminalSignalVerifier` is the one exception to the fresh source-bundle
lifecycle: it is a single retained artifact and address shared by every release.

The destination side uses `InboxApplyRouterV2`, immutable endpoint credit stores,
`DestinationBridgeV2`, `NativeLiquidityPoolV2`, release authority, terminal registrar, and
depth-64 terminal accumulator. ICV2 supplies the exact O(1) credit/fee read. RAV2 authenticates
retirement. DRV2/DSV2 preserve direct-successor and multi-hop reclamation independently of the
latest tip.

Recipient calls, liquidity callbacks, Store writes, Bridge lifecycle changes, terminal appends,
and source liability changes are separately bounded and joined only in the normative revert
domains. A failed target restores the complete inner child frame, including Pool/ticket transfer,
quota, pull and terminal effects, to its entry state. The authenticated outer catch may then perform
only the normative result transition: leave NEW/RETRIABLE unchanged, write owner-initial RETRIABLE,
or make the separate owner-last failure finalizer atomically write FAILED and its terminal leaf.
Failure of that finalizer restores the outer entry state. No unlisted partial mutation survives.

### 4.5 Deterministic deployment and profiles

Address cycles are solved by manifest-pinned deterministic factories or a fixed deployment nonce
sequence, never by general setters. The implementation produces reproducible runtime hashes,
configuration hashes, storage layouts, creation artifacts, component DAGs, and root deployment
transcripts.

The kind-0 adapter is a fresh release-scoped ERC-2470 deployment, not a
`SourceBundleFactory` child and not part of the frozen eighteen-artifact root cohort. The execution
profile sole dynamic bytes field is the exact two-artifact bundle containing Settlement and
kind-0 creation/runtime bytes. Profile-fixed creation, salt, complete-initcode, runtime and
configuration hashes let ProtocolVersionManager recompute the constructor tail and CREATE2 address
on chain. Constructor conformance proves the exact initial storage and absence of pre-activation
mutation. Exact-code front-runs are reusable; collisions or any code/config/state mismatch reject.
During activation both old and new adapters are append-inert, the final ACTIVE write moves the sole
typed append authority atomically, and historical adapters retain only record/refund servicing.
The exact raw artifact bundle maximum is 137,744 bytes and the complete ABI profile maximum is
146,848 bytes; REGISTER_RELEASE is therefore capped at exactly 149,088 bytes end-to-end. PIA2
stores the derived kind-0 constructor-poststate commitment, while RTR2 stores the component-read
gas, ordinary-verifier descriptor hash and kind-0 authorization ID. Those compact authenticated
records let activation reproduce all checks after restart without retaining or accepting the raw
profile. Kind-0 immutable/link-reference tables must be empty and its runtime cannot delegate.

The production profile generator rejects test verifiers, null or uncalibrated economic fields,
unknown ownership classes, artifact-owned recompile/output drift, source-inline
source/profile/ABI/link drift, legacy endpoint reuse, mutable trust-map wrappers, and incomplete
authority burning. The conformance ledger has separate rows for the ordinary Settlement verifier
dependency/interface/call helper and the kind-0 complete-initcode deployment artifact; neither may
be marked reviewed until the exact v2.27 profile, constructor, gas-threshold and lifecycle tests
pass.

## 5. Core State and Boundary Invariants

The following invariants are release-blocking:

- canonical safety never depends on an honest, present, or distinct builder or seat holder;
- every canonical transition is monotone, authenticated, replay-protected, and bounded;
- the last scheduled builder of one window and first builder of the next may be the same key, but
  the global same-key run is at most two slots; each window has its own immutable slashable builder
  tranche and no builder liability or clock is silently inherited across the boundary;
- a malicious boundary builder can withhold only its own service; it cannot forge execution,
  inherit an expired duty, suppress forced recovery, or prevent later permissionless progress;
- aggregator-seat APPLY installs a term and may start service but allocates no duty; a fresh duty is
  created only after strict `now > recoveryAt`, using the then-current responsibility base, and
  builder scheduling never creates, cures, fails over or slashes a seat duty;
- equality at a deadline follows the frozen inclusive/exclusive rule; subtraction cannot underflow
  and a zero sentinel cannot become accidentally due;
- all history, frontier, queue, duty, tranche, offer, journal, and scan work has a fixed capacity or
  O(1) reverse index;
- ETH and token liabilities are conserved across deposits, reservations, credits, slashes,
  refunds, target failures, migration, retirement, and reclamation;
- terminal or released state never resurrects, and direct-successor receipts remain sufficient
  after arbitrary later hops;
- migration success, abort, expiry, reorg, callback failure, and restart leave one fully specified
  authority owner and no ambiguous lease or generation; and
- bootstrap authority is either unused in the initial state or irreversibly consumed/burned.

## 6. Data Flow and Failure Isolation

Normal and recovery proofs authenticate their prestate, statement, verifier, bounded data, and
expected output before canonical state is published. State publication precedes only the explicitly
allowed final migration callback. Any verification, return-length, magic, code-hash, gas, or join
failure reverts the entire canonical transition.

Economic maintenance is deliberately outside canonical progress. Market, premium, bond, reward,
and operator payout failures can revert only their maintenance or claim transaction. Payouts use
pull credits and checks-effects-interactions.

Bridge and Pool entry points use explicit reentrancy state and complete transient authorization
tuples. Only the exact child callback is permitted while entered. Direct calls, stale routes,
historical Bridges, alternate Stores, malformed return data, duplicate consumption, excessive gas,
and callback reentry revert without effect.

External faults use custom typed errors. Tests assert both the selector and unchanged state, not
merely that a call reverted.

### 6.1 Delayed genesis campaign

Genesis is not the later-version migration path. A delayed, finite campaign binds the exact legacy
resume profile, target, proposal and forced cutoffs, hard block/time deadlines and maximum scan
geometry. Permissionless bounded scans produce the review envelope and abandonment receipt before
the legacy gate enters reversible QUIESCENT. The landing transaction verifies the proof first, then
executes LGAR, LGFN, MCAN, QMIG, MAPS and publication in one revert domain.

If no proof lands, hard expiry permissionlessly restores the unchanged legacy ACTIVE path. A bad
target requires a higher-nonce delayed campaign. Pending legacy rows are abandoned only under the
frozen receipt rules; if the deployed Inbox cannot accept the exact final storage-compatible
implementation, or lossless pending-row treatment is required, in-place cutover stops and an
independently initialized state migration is required.

### 6.2 Later-version migration

Later migration retains the old canonical authority through ARMED and READY. The proof is verified
before Router enters ACTIVATING. The exact journal is `MFRZ -> MCAN -> Kind0 ingress binding ->
SourceBridge activation -> source authority/index install -> BRC1 consume/post-read -> destination
adapter seal -> Bridge ingress binding -> QMIG -> MAPS -> internal registration/receipt/successor
writes -> public target ACTIVE -> clear context -> Router IDLE -> VMC1 -> PVM IDLE`. ACTIVATING
gates all newly installed ingress until publication. VMC1 is the final external call and sole
mutating external-call exception after QMIG. Any fault, malformed return or failed post-read
restores old READY/IDLE authority, Queue cursor/liability, empty target, every prepared adapter's
unsealed state, inactive target SourceBridge, pre-cutover ingress/profile maps, unused registration,
absent receipts and the original LIVE lease. The separate permissionless abort remains available
until successful activation consumes it.

### 6.3 Destination retirement and reclamation

Release rotation atomically records a proof-bound retirement Queue watermark and an immutable local
direct-successor DRV2/DSV2 receipt. Reclaim is permissionless but succeeds only after InboxApply has
reached the watermark, `terminalizedPinnedCount[oldDomain] == oldStore.pinnedCount`, aggregate old
Bridge pull liability is zero, the old route/writer and complete lifetime graph still authenticate,
and the direct-successor receipt matches the old/new versions, manifests, domains and Bridges.

The old Bridge transfers its complete raw surplus to the typed sink before setting the one-shot
retired bit. A rejected or partial transfer, callback, reentrancy, graph mismatch or duplicate call
changes nothing. The receipt is direct-successor based rather than latest-tip based, so A may
reclaim from A-to-B after B-to-C while B independently uses B-to-C. Historical source liabilities
and terminal proof reads remain available and cannot be reclaimed as surplus.

## 7. Implementation and Commit Strategy

The work remains one stacked PR but is implemented as dependency-ordered TDD commits. Each slice
contains its ledger rows, interfaces, failing tests, minimum conforming implementation, adversarial
boundary tests, generated artifacts, and review evidence. A slice is not committed until its owning
profile builds, focused and profile tests pass, touched Solidity formats cleanly, storage layout is
recorded, artifact ownership is reproducible, and critical/high review findings are resolved.

The detailed plan replaces the stale September 1 round list with these gated capabilities:

0. synchronize the stacked base, remove provisional/dead code, repair CI and establish the v2.27
   conformance ledger;
1. revalidate shared encodings, trees, signatures, exact-call, RLP/MPT, economics and custody
   primitives against all 812 model vectors;
2. revalidate root CREATE2/CREATE3 bootstrap, the nine-role manifest, component factories and
   activation receipts, including every first/last deployment and collision boundary;
3. implement BuilderRegistry, liability generations, ScheduleOracle, data sessions and ForcedQueue;
4. implement normal/recovery Settlement, canonical history, reward receipts and permissionless
   liveness paths;
5. implement the perpetual reverse-ask market, seat terms, premiums, duties, handover, failover,
   slash, release and boundary transitions;
6. implement the complete source and destination bridge graphs, terminal plane, pull accounting,
   quota, failure finalization, refund and cancellation;
7. implement delayed genesis, later-version migration/abort, release rotation, retirement,
   direct-successor reclamation and deterministic deployment; and
8. run two-chain integration, coverage, gas/size/layout, restart/serialization, differential and
   adversarial release audits.

Every capability may be split into smaller commits, but no commit may claim a concrete component
complete while its external transitions or failure domains remain represented only by a mock.

## 8. Verification Strategy

Verification includes:

- unit tests for every public transition and custom error;
- golden-vector and differential tests against all Python commitment/state models;
- fuzz tests for widths, deadlines, malformed ABI/returndata, ordering and replay;
- invariant/handler tests for solvency, monotonicity, terminality, bounded work and authority;
- explicit builder-window traces for first/last placement, independent tranches and same-key
  two-slot runs, separately from seat-term tests for APPLY-without-duty, strict recoveryAt duty
  creation, handover, late cure, failover and slash;
- target revert, out-of-gas, reentrancy, callback rollback and EIP-150 envelope tests, including
  every owner/non-owner, initial/retry/last-attempt outer-catch branch;
- delayed-genesis scan/QUIESCENT/resume/abandonment and unsupported-in-place fallback tests;
- later-migration exact journal/rollback tests and retirement/reclamation tests for every watermark,
  cursor, pinned/terminal count, pull-liability, graph, transfer and direct-successor gate;
- two-Anvil-chain integration for normal/recovery settlement, DIRECT ETH ingress, LP funding,
  DONE/FAILED/cancel/refund, proof-first activation, abort and multi-hop reclamation;
- storage-layout compatibility tests only for explicitly supported legacy facades;
- deterministic artifact/profile/deployment transcript regeneration; and
- gas and runtime/initcode size checks at every normative maximum with the specified safety margin.

The test suite must additionally prove that deleting a provisional or superseded implementation
does not leave a source import, manifest row, artifact, selector, deployment node or test fixture
that can silently select the old behavior. Differential tests consume the normative Python export
one way; Solidity or TypeScript must not recompute a second expected value using equivalent local
logic.

Coverage must exceed 95% for the new suite, but line coverage is not acceptance by itself. Every
normative transition, error branch, boundary equality, maximum-capacity state, external-call fault,
and rollback domain must have semantic assertions.

## 9. Completion Criteria

The implementation PR is complete only when every row in the v2.27 conformance ledger is reviewed,
every normative on-chain component and interface exists, no unclassified/dead Slot Chain source or
artifact remains, the final models and Solidity agree on commitments and transitions, all test
classes above pass, runtime/config/layout artifacts are reproducible, the full deployment can be
created on two local chains, GitHub CI is green, and no reviewed Critical or High finding remains.

Coverage must exceed 95% for the new contract suite, but completion also requires explicit semantic
tests for every public transition, custom error, deadline equality, capacity boundary, external
call fault, rollback domain and first/last builder or seat boundary. A coverage percentage cannot
waive an uncovered normative branch.

Completion of this PR does not make the protocol production-ready. Real circuits and verifier
keys, measured production economic parameters, client/fork support, cross-language conformance,
testnet migration rehearsal and soak, operational monitoring, and independent proof-system,
Solidity, Bridge, and economic audits remain external release gates. The PR must report these
honestly and must not include a production cutover.

## 10. Stop Conditions

Implementation stops and returns to design review if any slice requires:

- a caller-controlled trust assumption or historical target selector;
- unbounded protocol work or an unindexed hot-path scan;
- a canonical dependency on seat/market/operator availability;
- partial state survival outside a normative failure domain;
- reuse of live V1 custody or mutation of production-path behavior;
- a generic mutable authority not committed by the release manifest; or
- weakening a normative invariant, test, gas bound, or security check merely to compile or pass.
