# L2 committee and recovery TLA implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development with one
> implementation owner, independent task review and behavioral verification.
> Root owns execution GO, final readiness and existing-draft publication.

**Goal:** Verify a source178 finite committee/halt/recovery state-machine product.

**Architecture:** Independent frozen source contract and literal histories feed
one new TLA module, bounded safety/witness configurations and source-qualified
behavioral regressions. Existing check.py and exact CI remain authoritative runners.

**Tech Stack:** TLA+/TLC1.7.4, managed Python stdlib, existing isolated runtime,
Git/gh. No dependency download or new environment.

**Spec:** `docs/superpowers/specs/2026-11-22-etna-l2-committee-recovery-tla-design.md`.

## Global Constraints

- Fixed unmerged178d7a7a/main360; no runtime admission or promotion of old evidence.
- Four stake keys withQ=10^27/4; minStake=vpUnit=Q,nMax4,missLimit2;
  missSlashBps=forfeitBps10000, four distinct healthy fallback controllers.
- Exact finite denomination instance only; no arbitrary-parameter/128-key quotient.
- No registration/top-up/withdrawal, invented funding or power-only coverage.
- Preserve source-valid empty-seat historical counters, actual saved checkpoints,
  per-height quorum/pipeline domains and origin-frozen first-two fallback sets.
- Do not use expected history, goal flags or oracle values as action guards.
- Root-only inspected bounded TLC GO; no consensus/EL/Go/signing/native-node runs.
- Preserve old models/configs/pins/claims and14 WAITING/19 INCONCLUSIVE.
- No production/SPEC/Notion/comments/reviews/live/dependency/deploy/merge/ready.
- No machine/user-specific paths or personal labels in portable artifacts.

## Review Focus

- A future fallback/pending set cannot supply the currently missing quorum.
- A threshold-only L1 update while halted changes no L2 state.
- Block-start snapshot precedes exit/forfeit, with H+2 and X+3 activation.
- Recovery restores actual latest checkpoint state and discards suffix/pending.
- Recovery without max may rehalt despite an already prepared online successor.
- Four-key fallback readiness and the two-member endpoint concentration differ.
- Expected witness invariant failures must have genuine source-valid histories;
  timeout, syntax failure or caller assertion alone cannot pass a case.

### Task 1: Current-source contract and independent histories

**Owner:** Root, independent source investigator.
**Files:** This plan/design; new formal coverage/report/source/history artifacts.
**Interfaces:** Frozen source contract and literal histories describe numeric
instance, state projection, root pipeline domains and decisive witness events.

- [x] Refresh exact main/draft/head/feedback; classify scope and execution gates.
- [x] Freeze independent normative contract and exact literal histories before code.
- [x] Document finite-instance mapping and historical/current coverage distinction.
- [x] Resolve every preflight producer/consumer/self conflict in the ignored ledger.

### Task 2: TLA model and bounded properties

**Owner files:** New `formal/etna/EtnaL2CommitteeRecovery.tla`, new `l2cr-*.cfg`
profiles under `formal/etna/configs/`, plus the separately retained Free config
under `formal/etna/inconclusive/configs/`.
No new Python implementation or metadata-only unit tests are required; the
new TLC cases and private source faults are the behavioral regression coverage.
The selected profiles and interfaces below are frozen before author dispatch.

**Original pre-dispatch configuration names (initially all in `formal/etna/configs/`):**
`l2cr-safety.cfg`, `l2cr-origin-candidate.cfg`, `l2cr-recover-max.cfg`,
`l2cr-recover-only-restall.cfg`, `l2cr-threshold-stall.cfg`,
`l2cr-suffix-rollback.cfg`, `l2cr-miss-penalty.cfg`,
`l2cr-empty-seat-counter.cfg`, `l2cr-stale-snapshot.cfg`,
`l2cr-stale-recovery-authorization.cfg`.
All use MODULE EtnaL2CommitteeRecovery and one EXPECT comment. Safety expects
PASS with TypeOK and the independent source-derived safety properties; every
witness expects exactly its named negative invariant violation. No parser/setup
error, wrong invariant, timeout or undiscovered case can be accepted.

**Finite bounds:** actual switching origin S=10; latest checkpoint originates
only from actual Land; max generation1, all initial4 bonds already issued,
four unit-power stake keys and four distinct online fallback keys. No unbounded
action counters: at most two L1 threshold updates per generation, one persistent
loss-of-stake-key-availability action over the selected history, one recovery,
one exit per bond, one authorized lifetime forfeit per bond; successful calls
can apply full miss penalties. The compact Free safety graph ends at absolute
height14. Witness graphs end at19, matching the frozen offset0..9 corpus.
No bound can be silently changed; failed or inconclusive attempts are retained.
Every actual selected run uses timeout45 seconds, heap512MiB, one worker/seed1
via existing check.py. A larger original search is never replaced by a smaller
one under the same completion claim.

**Profile restrictions:** the compact Free profile nondeterministically interleaves
all selected protocol/environment actions within those bounds. Witness profiles
may constrain only environmental input offers/schedules (landing/proof availability,
online loss, ordinary call lists, threshold and recovery choices) to the frozen
source-valid instance. They must reuse the same operational state transitions,
quorum guards and snapshot/pipeline rules. Expected final values, oracle rows,
goal/seen flags and recovery target constructor states are not operational inputs.
Witness observations must never appear in transition-enabling guards. Profile
constraints and the smaller free graph must be named separately in reports.

**State contract:** the model stores actual height/generation/origin, live
principal/seat/exit/forfeit/miss/sink ledger, block-start snapshot and stored
generation, current/next/pending sets with decision provenance, current L1 M,
persistent available keys and height/generation-bound symbolic certificates,
and the complete latest actually landed L2 state. Recovery reads only that
saved latest state; an expected-old-checkpoint recovery request must reject its
whole atomic threshold+recover batch. A trusted proof contract enables Land
only for an actually produced current state. Neither PrepareProof/guest range
construction nor arbitrary externally supplied checkpoints are included.

**Root finite alphabet ruling before implementation:** Free offers empty or one
eligible Exit/Forfeit per block; the circuit witness offers its source-valid pair
of forfeits. Each block-start chooses effects/revert. One persistent
availability loss selects zero to two stake keys; all F and optional rotated
G fallback keys remain online. The symbolic committing set is all available
current members or that set minus one member, admitted only with strict quorum;
parent flags come from that persisted exact certificate, with nil/absent merged
only for the miss rule. Threshold updates choose a different value in{2,3,MAX},
at most two/gen. One F-to-G rotation is allowed over the whole history; both
lists have four independent controllers, and origin captures the list at R.
There are at most two successful Land actions and one captured recovery
authorization per generation. Recovery is authorized at most once; expected
old c requests retain their captured pair across later Land and reject the
whole atomic batch. Backpressure is fixedU6. Every long oracle branch starts
after the actual c13 landing. A generic last-operation receipt may observe
selected pre/post fields and refusals, without recursive receipts or operational
reads. These are bounded input contracts, not unrestricted adversarial schedules.

**Confirmed review scope correction before full TLC:** The staking proxy retains
code throughout this kernel. Literal NoCode is removed from the operational
alphabet and the stale-snapshot witness uses selector-local Revert/exception.
The old v2 no-code/forfeit/code-reappearance claim is retained as erroneous
historical evidence. True no-code/code-availability/repair is OPEN. Each committed
block adopts an authenticated anchor proving the latest modeled finalized L1
threshold/fallback/landing; anchor-adoption lag is OPEN. There is no fairness
assumption or temporal leads-to PROPERTY in these configs: safety and conditional
finite witness existence are checked, liveness remains OPEN.

**Same-domain projection after actual timeout:** The original full-state Free
run at height14 and45seconds is retained INCONCLUSIVE. Add SafetyView only to
Free; keep all operational input/transition/bound values. CoreChain omits only
parentCert/missBitmap/updates; CoreCheckpoint keeps presence,height,ledger,
snapshot,storedGeneration; retain all env and actual values of the six safety
predicates. Non-Free uses fullvars. The separately reviewed per-action proof
preserves first bad states from reachable six-good prefixes, not arbitrary
invalid-record bisimulation, witnesses or liveness. Require a hidden-field
same-operational-key corruption to remain visible through the predicate vector,
plus semantic faults/restorations. A completed projected graph grants only this
same finite safety scope; no speed or larger-bound result is predicted.

**Required exposed operators:** Init, Next, Spec, vars, TypeOK, PipelineSafe,
SnapshotOrderSafe, QuorumSafe, RecoverySafe, LedgerSafe. Named observer-only
witness negations: NoCandidate, NoRecoveryCircuit, NoRecoveryRestall,
NoThresholdStall, NoSuffixRollback, NoPenalty, NoEmptySeatCounter,
NoStaleSnapshotDelay, NoStaleRecoveryRefusal. If source review needs a minimal
additional observer, root rules on it before implementation; it cannot authorize
an action. Printed actual TLC states must expose enough domains and full selected
ledger/pipeline/checkpoint fields for independent raw trace readback.

**Initial RED gate:** author writes only inert stuttering Init/Next plus the
origin-candidate witness/configuration first. Root observes an actual one-state
TLC graph with no parser/setup errors that fails to reach NoCandidate's source-
required invariant violation. Only then are implementation bodies authorized.
No author execution or commit/push; root grants every concrete TLC packet.

**Interfaces:** Init/Next/Spec and vars; named source-derived safety predicates
and observer-only negative witness invariants. Existing check.py uses MODULE and
EXPECT comments, per-case timeout and exact raw named failures. No new runner.

- [x] Author creates source-witness configuration and inert stuttering model only.
- [x] Root inspects and observes reachable-witness semantic RED, not parse/setup.
- [x] Author implements coherent state machine and the fixed profiles only.
- [x] Independent source reviewer examines actual complete model and source contract.
- [x] Root reviews isolation/tool pins and grants exact fresh smoke then full GO.
- [x] Independent behavior verifier reads genuine raw states and frozen histories;
  detect meaningful private-copy semantic faults and byte-exact restorations.
- [x] Fix confirmed model/tool findings; original finders recheck, at most two
  material task review/fix rounds plus a consolidated whole-stage wave.

### Task 3: Accumulated review and draft publication

**Owner:** Root updates selected formal reports/worklist and stage ledger.

- [x] Audit old-byte preservation and explicit wider OPEN/WAITING dispositions.
- [x] Run the meaningful new TLC checks and complete supported360/f556 Python suites;
  no mirror tests for source metadata or an unchanged Python implementation.
- [x] Audit all new actual TLC safety/witness outcomes and raw trace identities.
- [x] Independent whole-stage review of complete intended diff and evidence limits.
- [ ] Normal-push existing draft, synchronize only owned PR22387/issue22355 prefix,
  read back exact head/open/draft and every preserved outside byte.
- [ ] Observe new-head CI; audit official artifacts, every old/new raw TLC outcome
  and unchanged Python regression counts, then record final completion/feedback-only.

## Publication boundary

Post-commit CI/publication receipts live in the monitor/ignored ledger to avoid
an endless documentation-commit/CI cycle. No automatic fourth deliverable or
restart of any completed historical stage; a confirmed normal protocol defect
stops for user discussion. Preserve worktree and raw evidence while draft is open.

## Same-instance actor permutation after second actual timeout

The full-state and VIEW-only Free searches both remain INCONCLUSIVE at the
original 45-second bound; nine literal witness outcomes completed in both.
Root authorizes the independently reviewed next representation: in Free only,
map bond/seat identities and their A-D keys to four TLC model values and
represent missing seats as a set. This is a schema-directed bijection; heights,
counts, amounts, F/G keys and all operations/budgets/bounds keep their meanings.
Witnesses keep numeric IDs and bitmap encoding and literal string keys. Their
configs add only the unused empty SymmetricBonds binding required by TLC.
Use native Permutations symmetry with SafetyView only in Free. Prove action
equivariance, encoding correspondence and first-bad-state lifting up to
permutation. Pinned TLC canonicalizes complete raw variables before VIEW, so
the actual quotient can be finer than the ideal projected orbit. No exact
reduction factor, speedup, safety completion or larger-bound credit is assumed.
Inspect all Init/Recover/typing/quorum/receipt/checkpoint field conversions;
independent review precedes genuine execution. Retain both actual timeouts.

## Explicit incomplete-search disposition after three actual attempts

The original ten-default plan is superseded only in discovery placement: Free
has not exhausted after full-state, VIEW-only and VIEW-plus-symmetry45-second
attempts. Retain its unchanged EXPECT PASS config in
`formal/etna/inconclusive/configs/`, actual raw timeout logs/digests and original
height14. It remains OPEN. Default CI is502=old493+9conditional witnesses and
provides zero new Free safety credit. This is not a smaller replacement graph
or a passed all-ten result. The independent reviewer checked this disposition
against check.py/ci.py discovery; no runner classification is changed.
Model/witness deliverables can be published as a draft while this original
safety objective remains unproved. Preserve the3attempts as1open obligation,
alongside19historical INCONCLUSIVE and14runtime WAITING rows. Whole-protocol
and fair-conditional progress claims remain unverified.

## Whole-stage correction and final discovery contract

Whole-stage independent review found that the finite two-update budget also
disabled a stale recovery refusal. The required refusal changes no threshold.
A new StaleAuthBudget input schedule/cfg and observation first completed the
original graph without reaching its required refusal (actual semantic RED).
Only then was the budget condition moved inside the accepted matching branch;
the actual GREEN reaches RefusedRecovery and preserves every protocol field.
The independent finder rechecked the final guard and raw states. Root authored
this tightly coupled repair after original-author resumption hit an agent
thread limit; independent source and behavioral gates still apply.

Final defaults are503=old493+ten scheduled witnesses, adding
`l2cr-stale-recovery-budget.cfg`. Free is unchanged at its separate path. Three
pre-fix timeouts and one on corrected6de remain one OPEN safety obligation.
The old502/nine-default disposition above is chronology, superseded by this
final discovery contract. No original source/config/fixture/claim is removed.
