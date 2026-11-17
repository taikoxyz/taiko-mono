# Etna TLA+/TLC models

The [current remaining-work index](WORKLIST.md) records module ownership,
acceptance evidence, implementation dependencies and required compositions.
Historical batches below remain bounded evidence; they do not close those rows.

This directory contains incremental bounded Etna models for settlement and
checkpoint binding, per-node L1 trust, signer/application crash recovery,
committee activation, registry lifetime, forced inclusion and proving progress.
Specific wrappers compose selected interfaces; passing separate models does not
establish their whole-protocol composition or implementation conformance.
Actual measured outcomes and incomplete products are recorded in
[REPORT.md](REPORT.md) and each module's source-mapping document below.

The normative source is
[`SPEC.md`](../../packages/protocol/docs/etna/SPEC.md), pinned at
[`d18357214fab30ea512ae9858a11699806d72ba1`](https://github.com/taikoxyz/taiko-mono/blob/d18357214fab30ea512ae9858a11699806d72ba1/packages/protocol/docs/etna/SPEC.md).
Later specification changes require a correspondence review before reusing the
results. These checks do not establish CometBFT, cryptographic or deployment
correctness.

## Run

The draft-enabled [TLC/Python workflow](../../.github/workflows/protocol--etna-tlc.yml)
runs the exact-outcome gate below with a checksum-pinned TLC jar, an offline
read-only source snapshot and disposable outputs:

```sh
"$PYTHON" formal/etna/ci.py \
  --java "$JAVA" --tlc-jar "$TLA2TOOLS_JAR" --output-dir "$NEW_GATE_OUTPUT"
```

The direct gate's output directory must not already exist. Hosted CI uses the
[container adapter](ci_container.py) because its runner rejects nested user
namespaces. The adapter assembles its runtime locally without pulling an image,
keeps the caller's numeric UID and checks every configured binding before
creating Docker resources. Its outer output directory must already exist; the
inner gate directory is new. Native lanes retain their existing supervisor.
The parent retains diagnostics outside the container bindings and publishes
copies with atomic replacement. After owned resources are removed, a separate
check rejects links and special files throughout the output tree before raw
artifact upload; failure diagnostics use two fixed private files.

The gate requires every discovered
default configuration exactly once, rereads its actual TLC log,
and rejects empty or skipped mandatory Python suites. Native Go, contract,
the five Comet host-controller tests, proof and shared source-fault campaigns remain separate evidence;
this CI job does not run or certify those lanes. The script downloads nothing.

Use Java 17+ and `tla2tools.jar` from the official
[TLA+ tools release](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4).
The recorded runs use release 1.7.4 (its banner says TLC2 Version 2.19).
The runner uses only Python's standard library and does not download tools.

```sh
python3 formal/etna/check.py \
  --java java \
  --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR"
```

Set the two paths to an existing jar and an output directory outside Git. Each
case has a bounded timeout and heap. A passing suite includes intentionally
failing TLC runs: negative controls and reachability checks must violate their
**named** invariant, not fail to parse or crash. See [REPORT.md](REPORT.md) for
actual commands, tool hashes, bounds and results. On a sandboxed host TLC's
local management socket may need permission even though the model makes no
external network requests.

## First model: transaction ordering

[`EtnaSettlement.tla`](EtnaSettlement.tla) has a single canonical L1 contract
state, one authorized recovery request and one delayed valid proof. TLC chooses
when each is prepared and which transaction executes next. Authorizations and
proofs remain available after execution; an attempt cannot regain validity by
silently deleting its history.

| State                         | Meaning                                                                        |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `c`                           | Latest settled checkpoint height                                               |
| `generation`, `recoveryNonce` | Current recovery domain and authorization nonce                                |
| `startHeight`                 | Fixed checkpoint from which this generation started                            |
| `now`                         | Abstract, bounded L1 timestamp                                                 |
| `authorization`               | Captured generation, checkpoint, nonce and inclusive deadline                  |
| `pendingProof`                | Otherwise-valid proof captured with generation, origin and terminal height     |
| `landings`                    | Retained landing records, including each record's generation and actual parent |
| `lastLanding`, `audit`        | Observation-only state for checking outcomes and reachability                  |

`Authorize` and `PrepareProof` stand for offchain work; they do not freeze
onchain state. `LandFresh` permits a competing valid landing. `Land(pendingProof)`
then exercises delayed submission, including valid overlap `p < c < h`.
`Recover`, `InvalidateNonce` and `Tick` represent recovery execution, explicit
authorization invalidation and elapsed time.

### Source-to-model correspondence

| Model behavior                                                                                                                                           | Normative source                                                                                                    |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Land reads actual `c`, requires `startHeight <= p <= c < h`, retains the record at `p`, accepts that record's old generation only when `p = startHeight` | LAND-6.1-2/3/9/10, normative reference steps 1 and 2                                                                |
| Proof must verify under the current generation                                                                                                           | Normative `land` step 6 (`statement(recoveryGeneration, ...)`, generation-bound `cutHash`); PROOF-6.2-9/10/14/17/45 |
| A valid delayed proof can settle only the new suffix and records actual `c` as parent                                                                    | LAND-6.1-3/4/9; normative reference step 7                                                                          |
| Authorization does not freeze land                                                                                                                       | RECOV-8.3-7; RECOV-8.1-4                                                                                            |
| Recovery matches captured generation, `c`, nonce and `now <= deadline`                                                                                   | RECOV-8.3-3/4                                                                                                       |
| Successful recovery increments generation/nonce and preserves settled checkpoint                                                                         | RECOV-8-47/48/56/58; RECOV-8.3-8                                                                                    |
| Recovery takes current `c` as the new fixed origin                                                                                                       | RECOV-8.4-2/3/7                                                                                                     |
| Explicit invalidation advances the nonce without changing the checkpoint                                                                                 | RECOV-8.3-9/11                                                                                                      |
| Transactions are atomic and failed calls leave no partial state                                                                                          | LAND-6.1-9/11; RECOV-8.3-16/19, assumed atomic action boundary                                                      |

`pendingProof.generation` is an abstraction of the immutable public input a
proof authenticates. The Solidity interface has no caller-supplied generation
field whose value the contract merely trusts. Turning off
`CheckProofGeneration` deliberately models loss of that verifier/input binding.

### Checks and negative controls

Every normal configuration checks types, no successful stale-generation,
stale-checkpoint, stale-nonce or expired recovery, no old-generation landing,
no retained landing record above `c`, preservation of `c` through ordinary recovery,
and actual checkpoint parent recording. `NoFutureLandingRecords` checks only
height ordering; block-hash integrity and full prefix preservation are outside
this model. Audit flags accumulate observations
from successful actions, never enable actions, and never consult the optional
guard constants.

| Configuration                           | Expected result                                                                                                 |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `baseline.cfg`, `baseline-extended.cfg` | Complete exploration with all invariants satisfied                                                              |
| `missing-checkpoint.cfg`                | `NoStaleCheckpointRecovery` violation                                                                           |
| `missing-nonce.cfg`                     | `NoStaleNonceRecovery` violation                                                                                |
| `missing-deadline.cfg`                  | `NoExpiredRecovery` violation                                                                                   |
| `missing-proof-generation.cfg`          | `NoOldGenerationLanding` violation                                                                              |
| `reach-recovery.cfg`                    | `RecoveryNotReached` violation: successful recovery exists                                                      |
| `reach-overlap.cfg`                     | `OverlapNotReached` violation: successful overlapping landing exists                                            |
| `reach-invalidation.cfg`                | `InvalidationNotReached` violation: otherwise-current authorization is nonce-stale                              |
| `reach-expiry.cfg`                      | `ExpiryNotReached` violation: an authorization can expire                                                       |
| `reach-deadline-equality.cfg`           | `DeadlineEqualityNotReached` violation: recovery succeeds at a positive timestamp exactly equal to its deadline |
| `reach-old-proof.cfg`                   | `OldProofAfterRecoveryNotReached` violation: an old proof remains queued at the reused recovery origin          |

A reachability run intentionally asserts that an interesting state is absent;
its counterexample certifies **existence**, not eventual progress. Finite bounds
also impose terminal states, so deadlock checking is disabled explicitly. The
model has no fairness assumptions or liveness claim.

The small bound is `MaxHeight=2`, `MaxGeneration=1`, `MaxNonce=2`, `MaxTime=1`;
the extended bound uses height 3, generation 2 and nonce 3 with the same time
bound. Heights count normalized grid points, with `S=0`, `K=1`; these are not
production deployment parameters. No state constraint silently discards states;
finite bounds appear in the state domains and action enabling conditions.

### Assumptions and exclusions

- A transaction is one atomic action. Reentrancy, partial writes, contract code
  and failure/revert implementations are not verified.
- A single canonical L1 state is modeled. RPC lag, forks, per-node views,
  finality failure, crashes and signer persistence are not modeled yet.
- DAO authority, initialization, start setup and recovery list validity hold.
  Invalid authorizations are created by delay or invalidation, not by forgery.
- Fresh proofs are available as abstract valid inputs. All proof origins are
  captured from checkpoints; retained origin records are checked at execution.
- In the first model, proofs share one abstract block history, authenticate their complete range,
  and have cuts matching the current checkpoint. EL/Comet/validator-state hashes,
  FI cursors, blobs, cryptography, proof completeness and proving latency are
  outside this model. In particular, this does not establish fork-safe overlap
  merely by comparing heights.
- Ordinary recovery preserves settled history. Verifier-failure rollback is
  excluded; adding it requires revising checkpoint properties and modeling nonce
  preservation/invalidation and derived authorizations explicitly.
- These runs explore particular finite configurations using TLC fingerprints;
  they are not unbounded machine-checked theorems or proof of client conformance.

## Checkpoint identity extension

[`EtnaCheckpointIdentity.tla`](EtnaCheckpointIdentity.tla) uses
`EXTENDS EtnaSettlement` and calls the original actions from identity-aware
wrappers. It does not copy their implementations. The original module and its
12 configurations stay unchanged. `IdentitySpec` also includes all original
choices of authorization deadline, elapsed time and nonce invalidation; they
are not silently removed from the larger state graph.

New configurations declare `\* MODULE: EtnaCheckpointIdentity`; the same runner
uses that local module. Legacy configurations without a module declaration still
select `EtnaSettlement`. The runner snapshots the selected configurations, all
local TLA+ modules and the TLC jar. Any input drift invalidates the run instead
of attributing mixed-candidate results to the final files. Results record the
module and source/configuration hashes. For a single quick check, add
`--case identity-baseline-el` to the command above.

### Identity representation and source mapping

A symbolic cut has exactly the boundary fields relevant here:
`height`, `el`, `comet`, `fi`, `val`. Distinct tuple tokens stand for collision-free
hashes; actual hashing, ABI/RLP encoding, state execution and certificate validity
are not implemented. The `FI` variation uses integer cursor 0 or 1, with the
landing step-4 non-regression and suffix-consumption bound checked separately.
The current FI head is identified with `recordCuts[c].fi`; consistency with
a separate FI-head storage variable and queue-tail checks are not modeled.

| New state                        | Meaning                                                                                                                           |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `recordCuts`                     | Symbolic identity of each retained slot-285 landing record                                                                        |
| `prefixCuts`, `prefixGeneration` | Independent observation of the settled prefix, retaining the generation that settled each height                                  |
| `queuedIdentity`                 | Execution-history label, separately supplied leaf-history label, public-input origin and execution-start origin of a queued proof |
| `identityAudit`                  | Observation-only safety and reachability evidence; never enables an action                                                        |

Two histories, A and B, share all metadata before `ForkHeight` and differ in one
selected component at and after it. Four normal configurations separately vary
EL hash, Comet hash, FI cursor and validator-state hash. Identity tokens include
the generation: ordinary recovery may extend the retained prefix with a new
generation's history, without recomputing the older settled identities.
`SettledHistoryCompatible` checks that within each generation the settled cuts
fit one of the modeled histories. `RetainedRecordsMatchSettledPrefix` independently
relates the actual landing records to those observed settled cuts.

These histories **overapproximate boundary metadata**. In particular, isolated
Comet/FI/validator-state changes with an unchanged EL hash are interface checks,
not evidence of two physically realizable EVM histories or two honest-quorum
CometBFT certificates. No Byzantine-consensus conclusion follows from them.

| Composed behavior                                                                   | Normative source                                    |
| ----------------------------------------------------------------------------------- | --------------------------------------------------- |
| Public-input origin equals the complete retained record                             | Normative land steps 2/6; ENC-A-35; PROOF-6.2-40/46 |
| At `p<c`, supplied cut at actual checkpoint `c` equals its full retained cut        | Normative land step 3; ENC-A-29/33/34               |
| Every supplied interior leaf equals the execution-authenticated cut at its height   | PROOF-6.2-39/41/43/44; ENC-A-30/31                  |
| FI cursor does not regress or advance by more than the new suffix length            | Normative land step 4                               |
| Only `(c,h]` is appended to the settled prefix; terminal record matches that suffix | LAND-6.1-3/9; normative land step 7; PROOF-6.2-42   |
| Ordinary recovery preserves all retained identities and the settled prefix          | RECOV-8-48/56/58; RECOV-8.4-2/8                     |

The model keeps the supplied leaves separate from executed cuts. An input may
have an origin from another history or supplied leaves differing from execution;
preparing such an input does not assert that the production verifier accepts it.
The origin and cut-binding guards model the corresponding proof/public-input
checks, not new Solidity arguments.

### Recovery-origin exception

`queuedIdentity.publicOrigin` must match the complete retained record even when
`p=startHeight`, including its stored `parentValStateHash` (ENC-A-35). The
execution-start origin is separate: only its validator state then comes from
`GenesisVal(generation)` instead of the retained validator-state hash, following
PROOF-6.2-41a. Its height, EL hash, Comet hash and FI head still match the public
origin. Every interior checkpoint comparison uses the complete cut, without this
exception. The genesis token is an explicit assumption standing for authenticated
reconstruction, not a proof of CometBFT genesis arithmetic.

The positive recovery-origin witness requires a nonzero retained checkpoint,
an older-generation origin record, a successful landing in the new generation,
and an execution-start genesis validator state different from that retained
record's value. This checks that the origin exception has not accidentally been
removed by an overrestrictive equality.

### Identity checks

All identity cases inherit the first model's safety checks and add origin,
cut-binding, checkpoint-boundary, prefix/record and recovery-identity checks.
The ordinary bound is height 2, generation 1, nonce 2 and time 1. Shared-prefix
cases use height 3 and `ForkHeight=2`; ordinary cases use `ForkHeight=1`.
All guards are enabled unless the configuration explicitly names a negative
control. No configuration silently applies a state constraint.

| Configuration                                 | Expected result                                                                                   |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `identity-baseline-{el,comet,fi,val}.cfg`     | Complete exploration for each isolated cut component                                              |
| `identity-baseline-shared-prefix.cfg`         | Complete exploration with histories sharing height 1                                              |
| `identity-missing-origin.cfg`                 | `OriginIdentityBound` violation, including `p=c` with no interior cut                             |
| `identity-missing-boundary.cfg`               | `OverlapCheckpointBound` violation                                                                |
| `identity-missing-cut-binding.cfg`            | `ExecutionCutsBound` violation                                                                    |
| `identity-el-only-{comet,fi,val}.cfg`         | `OverlapCheckpointBound` violation when EL equality hides another component's difference          |
| `identity-landing-record-rewrite.cfg`         | `RetainedRecordsMatchSettledPrefix` violation when only the terminal stored record is changed     |
| `identity-recovery-rewrite.cfg`               | `RecoveryIdentityPreserved` violation                                                             |
| `identity-reach-same-history-overlap.cfg`     | `CompatibleOverlapNotReached` violation: a bound overlapping proof succeeds                       |
| `identity-reach-conflicting-overlap.cfg`      | `ConflictingOverlapNotReached` violation: a queued conflicting proof has `p<c<h`                  |
| `identity-reach-substituted-leaves.cfg`       | `SubstitutedLeavesNotReached` violation: supplied leaves can differ from execution                |
| `identity-reach-recovery.cfg`                 | `IdentityRecoveryNotReached` violation: recovery after settling a nonzero checkpoint exists       |
| `identity-reach-recovery-origin.cfg`          | `RecoveryOriginReuseNotReached` violation: new-generation landing reuses an older retained origin |
| `identity-reach-shared-prefix-divergence.cfg` | `DivergentSuffixNotReached` violation: a queued history can share `c` and diverge only after it   |

For example, a proof from B covering `(0,2]` can be queued, then A lands height 1.
With `ForkHeight=1`, B's cut at 1 conflicts with that checkpoint and its submission
must fail. Supplying A's leaf instead does not repair B's execution: cut binding
must reject that substitution. With `ForkHeight=2`, both histories agree at 1,
and B can legitimately settle the new suffix to height 2. TLC explores these
orders rather than relying on a manually scripted happy path.

The base module assumes compatible cuts; this extension checks those symbolic
identity bindings within its stated two-history abstraction. It still assumes
proof/cryptographic soundness and genesis reconstruction and does not prove
actual client/guest equivalence, real block ancestry, QC validity, L1 fork
handling, FI queue eligibility/tail/service, availability, liveness or an
unbounded protocol theorem.

## Extending this directory

Keep the small configurations as regression checks. Add coherent modules for
L1 observations, committee schedules, signer state or consensus here, and use
`EXTENDS`/`INSTANCE` plus an explicit top-level `Init`/`Next` when composition is
useful. Define ownership of shared variables and `UNCHANGED` obligations, then
review source mapping, assumptions and properties again. Combining modules does
not automatically preserve their individual guarantees. New observations may
also require revisiting which information the present abstraction discards.

## Incremental method and implementation correspondence

[Worklist #22355](https://github.com/taikoxyz/taiko-mono/issues/22355) tracks
larger modules. Continue this directory and runner; add one reviewable boundary
at a time. A checked finite model is evidence about its explicit transitions,
not evidence that client/contract code implements them.

The first per-node increment is [L1 trust](L1_TRUST.md). Keep separate:
canonical L1 state, a node's available view, the snapshot it authenticated, and
its permission to sign/serve. The new snapshot trace is an interface abstraction
of settlement/recovery; it is not a full Cartesian composition with the earlier
transaction-ordering model.

The method borrows three concrete ideas from upstream sources, checked and pinned
on 2026-11-14; their tools/test suites were not run for this project:

- [CometBFT's accountability model](https://github.com/cometbft/cometbft/blob/5df2ff93bdce11cfb4d59ee59a992363a9ce1d27/spec/light-client/accountability/Synopsis.md)
  makes simplifications explicit. Its one-height, equal-power model and
  nondeterministic timeouts/proposers do not establish Etna's full consensus.
- [Malachite's specification layers](https://github.com/circlefin/malachite/blob/a453b32155f4ba9f959724279b52f601bae92e09/specs/consensus/quint/README.md)
  separate functional logic, distributed state machine, and scenarios. Keep
  module-local rules separate from observations and scheduling in Etna too.
- [Cosmos Interchain Security's MBT driver](https://github.com/cosmos/interchain-security/blob/ea200443e95f7f56b9fd5fd6854f357da6c281ac/tests/mbt/driver/README.md)
  replays generated traces against an in-memory application. Its application
  harness deliberately excludes consensus and relayers. A future Etna adapter
  must likewise state which real components and states it compares.

For each increment, pin rules and exclusions; write named properties and
positive reachability witnesses; remove guards and independently mutate writes
or assertions; freeze input hashes; then review complete traces and bounded
results. If a counterexample appears, classify it as a model error, a missing
premise, a specification ambiguity, a protocol-rule error, or an implementation
mismatch before proposing changes.

Implementation replay is **pending**. A future trace adapter should map model
inputs to the actual app/signer/L1 test interfaces and compare, after each step,
the authenticated generation/checkpoint, app trust, halt/refusal reason, and
actual sign/serve result. It must preserve asynchronous observation boundaries;
an adapter which reads the latest global state for every node would erase the
very lag being tested. Skipped replay must fail its validation gate, and passing
selected traces must not be reported as an unbounded refinement proof.

## Crash recovery increment

[`CRASH_RECOVERY.md`](CRASH_RECOVERY.md) maps the M03 signer and application
models to the pinned Etna rules and CometBFT v0.40.0 source. Signer request,
computation, durable record, external exposure and delayed delivery are separate
steps. The app model separates EL effects/flush, saved responses, completed
application Commit, acknowledgment and Comet state.

These are two focused projections, not a formal product with each other or M02.
The app's crash is an aggregate crash of the modeled volatile execution; it is
not every independently scheduled app/EL/Comet process-failure interleaving.
Successful storage writes surviving process failure, serialized key ownership,
completed generation authentication and actual engine idempotence are explicit
interface obligations, not evidence of host-power or production-client safety.

Wider signer configurations which did not complete their bounded run are retained
under `experiments/` and explicitly labeled inconclusive in the M03 report.
They are not silently included among the default suite's successful outcomes.
The five-task continuation plan covers M03–M07; it stops on a credible protocol
counterexample and records model errors separately.

## Committee selection and activation increment

[`COMMITTEE.md`](COMMITTEE.md) maps a fixed-registry M04 model to selection,
historical D(t) snapshot versus S(t) authentication root, H+2 current/next sets,
recovery clearing pending updates, and actual terminal/L1 active snapshots.
Literal selection tables and a fixed switch calendar are independent of the
operational selector; immutable generation-keyed input history constrains every
captured derivation. This is a membership/power/snapshot schedule projection,
not full committee-record/hash/targetEpoch encoding or proposer-priority arithmetic.

## Registry lifecycle increment

[`REGISTRY.md`](REGISTRY.md) describes M05's separate issued identities/slots,
input-bound principal/cash histories, actual historical member sets, confirmation
clock and withdrawal preservation. Checked source-valid workload prefixes include
a genuinely active member's later pending-funded displacement and retirement.
Other small profiles cover repeated top-ups, numeric forfeiture branches and
multi-slot admission. Arbitrary-timing products that exceeded the checking budget
are preserved as exact source/config experiments and remain inconclusive.

## Forced-inclusion increment

[`FORCED_INCLUSION.md`](FORCED_INCLUSION.md) maps a bounded FI queue model to
historical anchored entries, per-block cursor processing, admission fees and
ordinary recovery blanking. `EtnaForcedInclusion.tla` extends the existing
settlement model through FI-aware wrappers rather than copying its transaction
guards. L1 queue head/tail, L2 processing cursor and retained checkpoint cursor
are separate. An independent ledger observes every produced block, including
zero-delta blocks. Normal workloads, incomplete wider products, symbolic
transaction/execution premises and actual measured outcomes are recorded in the
module document and [REPORT.md](REPORT.md). Reachability does not guarantee
eventual service, and this is not a client or cryptographic refinement proof.

## Proving and DA progress increment

[`PROVING_PROGRESS.md`](PROVING_PROGRESS.md) maps a separate bounded pipeline
interface to produced, L1-included, finalized and adopted checkpoint frontiers.
`EtnaProvingProgress.tla` tracks immutable jobs, both backend statements, complete
original-range payloads, reference/ancestry limits and production back-pressure.
It checks real action enabledness when the stated prerequisites hold, including
landing while paused and adopting a new finalized anchor in the next candidate.
Ready-resource and missing-resource workloads are distinct; neither guarantees
that data or proofs arrive. This model is not a formal product with the earlier
modules and establishes no sustained throughput or settlement latency.

[`PROVING_RECOVERY.md`](PROVING_RECOVERY.md) describes F05's scripted companion
over unchanged M07 actions: settle and ordinarily finalize checkpoint1, recover
at that nonzero origin, preserve or explicitly restore proving resources, and
observe a fresh task or rejection of an outstanding old-generation task with a
live reference. Actual enabledness receipts, literal audits and required terminal
witnesses bound these three chronologies without a universal recovery claim.

## Recovery transaction and implementation-correspondence batch

The next authorized batch comprises exactly C01, M08-A, C02, M09-A and C03.
Model exploration and selected actual-contract replay proceed in parallel; stop
on an independently supported actual issue, otherwise stop after five for a
coverage retrospective. Model/oracle/adapter repairs are recorded separately.

[`RECOVERY_TRANSACTION.md`](RECOVERY_TRANSACTION.md) describes M08-A's curated
raw list inputs, private tentative workspace, complete modeled abort equality
and exact public commit effects. It extends actual settlement actions, with
single-attempt workload and explicitly different private validation order from
the real contracts. Its versioned public-attempt interface feeds C03; internal
microsteps must not be interpreted as public intermediate Solidity states.

[`conformance/README.md`](conformance/README.md) documents the separate Lean/TLA
to real-code lane. C01 locally builds the current Lean package, regenerates its
Registry8 vectors twice and replays the unchanged original Solidity fixture.
Pins, actual command outcomes, metadata bridge and scope limits are recorded
there; model checks and selected implementation traces remain separate evidence.

## Verifier-failure rollback increment

[`VERIFIER_ROLLBACK.md`](VERIFIER_ROLLBACK.md) describes M09-A's distinct atomic
corrective-upgrade interface: trusted checkpoint/FI/snapshot restoration, current
nonce/generation, complete retained landing records, exit confirmations and both
derived authorization paths. Actual symbolic read/proof/cache/retry/payment
outcomes are checked against independent observations. Three prepared workloads
complete; the unrestricted runtime remains an archived incomplete product.
No concrete corrective upgrade API or real migration conformance is asserted.

The second five-increment batch is complete locally. Its final212-case regression,
selected real-contract executions, repaired verification gaps and retrospective
are recorded in [REPORT.md](REPORT.md). Further increments await the agreed
retrospective; passing these workloads does not close the module worklist.

## Third batch: import and rules plus real-code correspondence

A new user-authorized five-increment batch starts from the completed212-case
baseline: M10-A, C04, M11-A, C05 and C06. Stop on a confirmed real issue; otherwise
stop after these five. The previous retrospective remains the historical record.

[`CHECKPOINT_IMPORT.md`](CHECKPOINT_IMPORT.md) adds a thin authenticated import
transaction/admission model with40 exact normal/control/witness outcomes. It
checks durable store content, atomic publication, crash retry, generation fences
and older-versus-latest admission. It does not execute an actual importer or
compose the earlier models formally.

C04 extends the [real-code lane](conformance/README.md) with eight literal
Displaced-confirm95 and Withdrawn recovery receipts and actual public registry
history. This closes those two C03 profile gaps; callback coverage stays open.

[`RULES_SCHEDULE.md`](RULES_SCHEDULE.md) checks raw L1 schedule calls and separate
historical-anchor/L2 observations. Its34 exact outcomes include historical
store provenance controls. Schema1 public receipts feed C05 real-contract replay.
The model retains original S for planned stop even after recovery origin moves.

## Verification sensitivity batch

The user authorized V01–V05 after independent fault experiments exposed input,
success-observer and progress gaps. [`sensitivity/README.md`](sensitivity/README.md)
describes a reusable versioned fault campaign. It distinguishes intended semantic
kills, surviving faults, inconclusive execution and explicitly unassessed scope.
The initial three-fault diagnostic correctly reports SURVIVED/non-ready; this
is an honest baseline, not a completed coverage repair. Subsequent bounded tasks
repair and independently retest those obligations before one held-candidate
handoff model. Source pins and production packages remain unchanged.

V02 adds discriminatory import inputs and an explicit input-to-guard matrix in
[`CHECKPOINT_IMPORT.md`](CHECKPOINT_IMPORT.md). Nineteen selected deletions now
fail the intended independent classification observer; original raw0..15, actions
and old configurations remain unchanged. Chain/height checks and other unassessed
obligations are recorded, not counted as covered.

T03 adds three raw-only M10 inputs and five focused contradiction-authentication
profiles, preserving raw0..24 and all 345 previous main configurations. The five
branch omissions fail `ClassificationCorrect` with healthy input0 controls; the
[import matrix](CHECKPOINT_IMPORT.md#discriminatory-input-obligations) records
negative-input premises and remaining authentication/cryptography gaps. The
shared inventory now has 54 assessed required IDs across compatible runtimes.

V04 separately checks connection enabledness/existence and conditional temporal
progress. `EtnaImportProgress` wraps actual unchanged M10 actions with typed
observation tags and requires eventual stable connection under fixed correct
available inputs, target/generation and fair internal work with at most one crash.
Nested sole-property profiles run through the sensitivity tool, not the older
invariant-only failure classifier. This is no unconditional client/network claim.

V05 composes a held candidate with actual M11 public schedule/recovery calls,
separating historical derivation from learned recovery/signature authorization
and current-generation proof enabledness. See [CANDIDATE_HANDOFF.md](CANDIDATE_HANDOFF.md).

The positive-stop continuation adds three bounded Stop/Rules/Recover programs:
due, future and off-grid retained candidates. Historical stop survives current
stop clearing; support and authenticated generation knowledge remain separate.
Three new normal profiles, 21 reachability witnesses and exact source-only
stop/time/grid/signing controls supplement all 314 original configurations.
A separate nine-call actual Inbox replay reuses the C05 receipt exporter and
state/event/abort adapter; all 38 original C05 call semantics remain unchanged.
No stopped-candidate proof, real client/STF or unbounded refinement is claimed.

## Recovery first-header clocks

[T01](RECOVERY_TIME.md) adds a separate deterministic first-header companion and
three actual TLC receipts. It distinguishes BFT genesis time3 from EL timestamp
3/4/4 under explicit retained-parent/origin/anchor premises, with independent
literal audits, reachable witnesses and source-fault controls. It leaves all
existing models/configurations and old conformance payloads/pins unchanged.

### F01 positive import chronology

The seven additive `import-premise-*` configurations audit the actual healthy
M10 publication boundary and require origin/non-origin publication and trust
witnesses. Non-origin header4 now uses102 after genesis100; origin's retained
old-generation header20 remains distinct from its new height0/genesis100
bootstrap. Its stock-genesis first stored proposer is1 at priorities[-2,2],
with next proposer2 at[1,-1]; non-origin landed proposer2 is preserved.
See [CHECKPOINT_IMPORT.md](CHECKPOINT_IMPORT.md#f01-independent-positive-chronology-premise)
for the reproduced fixture defect, independent literal premise audit and exact
source-fault sensitivity. This is a necessary chronology check, not full
STF/window validity or importer conformance. Prior M10 source hashes and run
results are historical; the350 prior main configuration bytes are preserved.

### F02 chain and height input discrimination

Two additive `import-input-chain-height-*` configurations pair healthy raw0
with wrong-chain raw28 or wrong-height raw29. Only the changed header's L1
Comet commitment is rebound, exposing each equality without header-hash masking.
They are invalid classifier inputs requiring Reject, with no modeled
contradiction branch established, and are not proof-valid landing witnesses.
Two exact shared TLC source faults must cause false Verified and fail the
unchanged `ClassificationCorrect` observer at classification; original and
actually restored source must pass. See [the input obligations](CHECKPOINT_IMPORT.md#discriminatory-input-obligations).
All357 previous config bytes, raw0..27 and the complete operational/observer/
audit suffix remain unchanged. The assessed inventory is58 (53 TLC,3 identity,
2 rules), with the four aggregate unassessed entries retained.

### F01 correction: post-increment positive priority premises

Before F03 receipt freezing, independent source review found Raw11 first[7,-7]
and Raw20 second[6,-6] incompatible with necessary two-member stock committed
priority bounds6/8. Their former positive-premise labels are withdrawn. F01
corrects only those tuples to[-1,1]/stored proposer1 and[-2,2]/stored proposer2,
and adds literal bounds over actual non-origin published sets. Base tuples,
origin, actions, classifier,359 existing configs and previous fault selectors
remain unchanged. Two exact source faults restore the impossible tuples and
must fail the independent publication audit. See
[CHECKPOINT_IMPORT.md](CHECKPOINT_IMPORT.md#f01-correction-necessary-post-increment-priority-bounds).
These are necessary local premises and selected reachability, not a full valid
STF, committee history, authenticated window or concrete importer claim.

### F01 final correction: joint per-height pairs

The earlier independently bounded positive vectors are withdrawn as complete
committed-pair premises. The final base/Raw11/Raw20 pairs now match selected
actual fixed-genesis plus two-update stock executions, including changed powers,
exact stored proposers and base next[2,-1] with nonzero sum. Genesis is wholly
literal and decoupled from current First; affected negative targets stay
meaningful. An independent actual-publication literal pair table and a bounded
wrong-pair source fault distinguish coherence from per-set bounds. See
[CHECKPOINT_IMPORT.md](CHECKPOINT_IMPORT.md#f01-final-correction-jointly-committed-validator-pairs).
This is selected prefix arithmetic/header correspondence, not complete protocol
STF/history, EL execution or valid signed commits. Earlier source/results remain
historical;359 existing config bytes and operational Mutant=None actions remain.

### G02: stock disk/process restart

The [disk/process lane](conformance/COMET_RESTART.md) runs actual GoLevelDB
Bootstrap writers and distinct readers. Both clean close and abrupt death after
a completed-write receipt preserve the selected full state and historical rows;
readiness and missing-write controls discriminate the claimed boundary. This
uses unmodified F04 public fixtures and literal observers, with separate evidence
from the TLC/Python CI job. It establishes selected process restart behavior on
the executing filesystem; physical power loss and real multi-store import remain
unverified.

### G03: stock handshake boundaries

The [handshake scenario](conformance/COMET_RESTART.md#actual-stock-handshake-scenario)
calls actual stock CometBFT over real disk stores and a controlled ABCI boundary.
It observes selected height, AppHash and last-response refusals, exact replay
callbacks, the empty-store shortcut and SPEC's known non1 first-block stop.
Typed ReplayBlocks errors are distinguished from the exported Handshake's
string wrapping. These selected API observations leave actual Etna App/EL,
authenticated history and the documented stop's concrete recovery procedure open.

### G04: positive-stop old-proof handoff

[STOP_PROOF_HANDOFF.md](STOP_PROOF_HANDOFF.md) composes actual public recovery
with an independently queued opaque proof in all three selected positive-stop
programs. Actual landing is enabled before recovery and refused afterward; full
terminal witnesses cover pre-recovery support and knowledge-first ordering.
Missing queue/attempt lose their required witnesses, and removing the real
generation binding enables an observed bad landing. Proof/reference availability
is a fixed premise, separate from produced proofs and measured retention.

### G05: actual signer actions across handoff

[HANDOFF_SIGNER.md](HANDOFF_SIGNER.md) composes the unchanged signer engine with
G04's selected Future positive-stop program. Computed, persisted and already
exposed/retried old work undergo actual floor adoption, crash/restart, stale
action attempts and fresh-domain persist/expose. Full terminals require actual
progress; exposure receipts detect even idempotent returns. Omitting the actual
durable floor or crash HRS preservation produces the corresponding bad exposure.
Independent source review and actual-model/raw-receipt verification pass. This
is a bounded composition with explicit authenticated trust inputs; concrete
signer/FilePV/authentication and wider interleavings remain open. The five
increments and independent accumulated gates are complete; see the final retrospective below.

### G01–G05: accumulated gate complete

The [final retrospective](REPORT.md#coverage-closure-batch--final-gate-and-retrospective)
records387 exact outcomes (79 normal/308 named),68 assessed source-fault
obligations,227 ordinary Python tests and five separate controller tests, plus
current-byte actual persistence/handshake campaigns. Independent complete-batch
source and raw-evidence audits pass. Actual hosted run44030752309 at43fe46187
passes the same387/227 gate; complete399-file raw and two-file private archives
were checksum-verified and independently read back. The29-row worklist retains
broader runtime dependencies and19 archived-search obligations. Stop after five;
PR22387 remains draft and hourly feedback checks continue.

### H01: public-input Registry lifecycle

The [public Registry lane](conformance/REGISTRY_PUBLIC.md) executes real published
PoPs at their bound domain from a fresh minimal setup with no key generation or
signing. Five complete histories cover repeated activation, pending-principal
liability, first-confirmation preservation, exact-delay payout, public zero
withdrawal and historical/coalesced checkpoints. Independent raw storage/cash/
event/root observers detect actual pending-deduction and confirmation-guard
omissions; original/restored runs pass. Broader token callbacks, capacity,
displacement, real Inbox snapshots and deployment remain explicit premises or
open obligations. Historical older test-key setups retain their own attribution.

### H02: unsigned weighted consecutive Comet handovers

The [weighted handover lane](conformance/COMET_HANDOVER.md) executes actual
stock MakeGenesisState/updateState/MakeBlock over five consecutive six-height
programs. Independently frozen literal members, powers, priorities, stored
proposer, change heights and header-hash projections distinguish real priority
increment and premature-activation omissions. An independent change-height
fault checks metadata that memberships and hashes alone cannot expose.
Unsigned structural inputs do not establish commit admission, rounds, network
consensus or authenticated registry derivation; broader K02 remains OPEN.

### H03: proof expiry, fresh recapture and actual resumption

The [proof recapture lane](PROOF_RECAPTURE.md) composes unchanged M07 actions
in two36-attempt resource histories. It actually refuses an otherwise complete
expired task, refuses a fresh task carrying an old backend statement, completes
the fresh result, lands/finalizes checkpoint2, adopts its anchor and produces
block3. Dedicated actual-source faults distinguish age and statement binding.
Independent wrong-parent-credit and missing-action controls lose the complete
progress witness. These selected resource schedules retain the existing proof,
history and shared reference/anchor-window abstractions; wider P01 remains OPEN.

### Current normative deployment boundary

Main991e06f6 changes shared SignalService deployment/provider requirements. The
exact [scoped correspondence](conformance/spec_correspondence.json) preserves
historical consumer pins and the selected H01–H05 assumptions. It does not
certify the new same-code deployment, provider failure policy or atomic upgrade
checks. [D01 in the current worklist](WORKLIST.md#remaining-obligations) keeps
that acceptance WAITING; current30 obligations/11 composition families retain
all earlier incomplete work. This tracking update is not another H increment.

### H04: partially settled FI suffix recovery and replacement

The [FI suffix recovery lane](FI_SUFFIX_RECOVERY.md) executes two15-attempt
histories with three actual productions: old1/old2, settle only1, recover with
B hash blanked or retained, then produce and land replacement2. Literal raw
cursor/queue/fee/history observers distinguish real cursor/hash write omissions
and an independently selected revenue-reset fault. A missing-old2 control can
reach matching final scalar values while lacking the required discarded suffix.
Full history witnesses remain distinct from absence controls. Real STF/EVM,
resource behavior and wider F01 implementation correspondence remain WAITING.

### H05: payments before correction and legitimate fresh retry

The [rollback payments lane](ROLLBACK_PAYMENTS.md) executes actual modeled
withdrawal and forged-message payment before correction, preserves their raw
cash/escrow/completed/principal/withdrawn state, and pays remaining legitimate
escrow after a fresh proof. It separates imported1/1 from actual transfer deltas
and checks permitted amounts per action/payee, beyond net sums or overwritten
journals. Current-nonce and numeric-height-reuse variants remain within the
unchanged atomic M09 interface. This is the fifth selected increment; accumulated
final gates remain separate. Concrete corrective implementation Q02 and shared
SignalService deployment D01 remain WAITING.

### H01–H05 accumulated final gate and retrospective

All five selected increments are complete at implementation3bc4d53ff, after
independent per-task source/behavior gates and whole-batch source/raw audits.
[Final evidence and reflection](REPORT.md#adversarial-coverage-batch--final-gate-and-retrospective)
separate423 exact TLC outcomes,243 ordinary Python and5 controller tests,
seven fresh shared faults from75 assessed inventory, actual native handover,
and successful exact-head hosted run44068685817. The local incomplete-docs
snapshot failed only rules; its successful component results, separate corrected
offline rules run and hosted end-to-end success remain explicitly attributed.
Full R01/K02/P01/F01/Q02 and D01 are not closed. No sixth increment is authorized;
the draft and hourly feedback-only monitoring continue.

### J01: repeated recovery and immutable identity overlap

The [repeated-recovery lane](REPEATED_RECOVERY_IDENTITY.md) executes two actual
modeled recoveries with an intervening competing/overlapping landing. Complete
raw witnesses distinguish generation2 settlement and retained origins from equal
headline checkpoints. Actual generation and independent nonce saturation faults
fail at the second transition; missing actions can legitimately change later
acceptance. Independent source and behavior gates pass for this selected finite
S01/Q01 history. Concrete client/EL/guest comparison remains WAITING; J02–J05 and
accumulated final gates remain unfinished.

### J02: selective two-node generation knowledge

The [two-node supersession lane](TRUST_SUPERSESSION.md) requires actual initial
service, local revocation, retained lagging-node service and eventual old-session
containment in both node orders. Raw histories distinguish safe refusal from
excessive cross-node revocation and lost valid availability. A separate real
finality-boundary fault and missing-admission history provide independent
verification. Logical sessions do not establish physical restart or fresh
session-generation liveness; broader T01 remains WAITING. J03–J05 and accumulated
final gates remain unfinished.

### J03: pending-funded admission and complete retirement

The [Registry retirement lane](REGISTRY_RETIREMENT_PRODUCT.md) executes six
actual21-attempt orders through pending-funded admission, displacement, recovery,
forfeiture, historical slash, snapshots and public zero withdrawal. Intermediate
raw principal/slot histories distinguish errors hidden by matching final cash or
committee values. Actual admission and independent split faults/restoration
pass their intended checks after a wrapper priming-order correction; failed
initial runs retain zero credit. Broader R01 remains OPEN; J04/J05 and accumulated
final gates remain unfinished.

### J04: stored Nil bytes and legal delayed delivery

The [Nil replay lane](SIGNER_NIL_REPLAY.md) crosses eight crash/salt/delivery
histories. Actual pending captures distinguish saved-byte reuse from lawful new
computation, and old network delivery from fresh signature exposure. Independent
second-restart and missing-first-write challenges verify intermediate floors and
history rather than equal terminal records. A cfg representation setup failure
is retained with zero credit; corrected source/runtime/restoration gates pass.
Broader C01 remains OPEN; J05 and accumulated final gates remain unfinished.
