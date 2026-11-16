# M11-A: L1 rules schedule and historical-anchor observation

[`EtnaRulesSchedule.tla`](EtnaRulesSchedule.tla) checks finite schedule programs
and L2 rule/stop observations under SPEC
`d18357214fab30ea512ae9858a11699806d72ba1`, START-10.1-3e..5c/14a..f and
RECOV-8-47a. Contract interface source is
`89f419915de4b73bb57c53bf970f6dea9e8e8c8c`,
`contracts/layer1/etna/impl/EtnaInbox.sol`: scheduleRules, scheduleStop, recover,
\_checkRecoveryState, \_recoveredRulesSchedule and \_setRulesSchedule.

The module extends the unchanged `EtnaSettlement` model. Accepted recovery
actually invokes its `Recover` action; failed public attempts leave its state
unchanged. A bounded `LandFresh(1)` prehistory is used where recovery must start
above S. The wrapper adds schedule-specific checks and writes, not another
registry/FI engine. Both the inherited settlement model's proof premise and this
wrapper's list-free recovery premise remain abstractions. This is not refinement
of real contracts, actual guest/client execution or structural K-upgrade code.

## Finite workload and time domain

There are 23 fixed raw public programs containing 38 calls. They cover earliest
notice, equal-rule rescheduling, cancellation, strict pending/stop lock equality,
invalid rule numbers, activation promotion, rejected promotion atomicity, stop
move/cancel/reached state and invalid grids, too-early time, owner/initialization,
zero/nonzero recovery, bad recovery rule/nonce/checkpoint/generation/deadline,
missing start, and a new stop after recovery. Calls and contexts are raw fixture
data; operational decisions do not consult scenario names. Only setup selects
whether the inherited landing prehistory is needed.

The normal public configuration exhausts those programs. The observation
configuration exhausts candidate products on six programs: Reschedule, Promote,
StopReached, RecoveryZero, RecoveryNew and RecoveryStop. It is not all arbitrary
call arguments, all program permutations or unbounded operator behavior.

Fixed quantities are S=6, K=6 and normalized maxAnchorAge=1. A seeded landing
moves the abstract checkpoint 0 to1, projected as public height12; the original
start stays6. Recovery can therefore move its origin to12 without changing S.
L1 timestamps are 0..6 and candidate L2 timestamps 1..7. The finite sentinel99
stands for uint48.max **only in the rulesTime cancellation field**. It is not
an ordinary physical Unix timestamp and this model does not prove uint48
arithmetic/ABI overflow behavior.

Canonical finalized L1 schedule snapshots are retained separately from the
current L1 clock and latest slot value. Each public call records its post-call
snapshot; after the program, L1 can advance while the schedule stays unchanged.
A candidate can select a current-generation historical snapshot whose timestamp
is at most its own timestamp and no more than one normalized unit older.
The candidate's parent is at or above that generation's origin and has a lower
timestamp. The anchor index is the already resolved, authenticated carried or
inherited anchor; envelope decoding, parent-anchor inheritance validation and
full block validity are environmental prerequisites, not additional engines here.

Rule selection uses that anchor's schedule and the **candidate L2 timestamp**.
Stop validity uses the **parent height/time** and **original S**, including after
recovery. Unknown rules produce Wait; support installation and retry of the same
pending candidate can produce Accept. This abstracts the node's refusal/wait
behavior, not CometBFT proposal/signature APIs. Stop denotes an invalid successor,
not a safety-halt implementation. At most one initial candidate and its retries
are observed per trace; all enumerated candidates are explored across traces.

## PublicAttempt schema 1 for C05

`PublicAttempt` is the actual receipt from an executed public attempt. It is
absent initially (`present=FALSE`); only present receipts may be exported.
Programs and indices identify the original ordered calls, not copied expected
outcomes. No Python protocol implementation is needed to calculate a receipt.

| Field                      | Meaning                                                                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `schemaVersion`, `present` | 1 and whether an attempt executed                                                                                          |
| `program`, `index`         | Raw program id and one-based call position                                                                                 |
| `setup`                    | S, K, M, cancellation sentinel, seeded-landing flag, initial initialized/start-written flags, normalized origin block/time |
| `operation`                | Rules, Stop or Recover                                                                                                     |
| `args`                     | Original rules/time/grid, expectedGeneration/expectedC/expectedRecoveryNonce/validUntil; irrelevant arguments are retained |
| `context`                  | Original owner/initialized/registryUnlocked/startWritten, normalized L1 timestamp and L1 block                             |
| `accepted`                 | Actual modeled acceptance or revert                                                                                        |
| `before`, `after`          | All five schedule fields, generation, nonce, checkpoint, originHeight, and origin record                                   |
| `origin`                   | present, height, l1Block, timestamp; absent before an unwritten start                                                      |
| `scheduleEvent`            | present, five least-significant-first 48-bit limbs, reserved16=0                                                           |

Event limbs are `(activeRules,nextRules,rulesTime,stopTime,stopGrid)`. They
represent the raw packed event's fields; TLC does not perform uint240 arithmetic.
When present is false, no event was emitted and limb placeholders are ignored.
C05 must map fields and independently pack the actual Solidity uint256 word;
it must not merely compare the model helper's packed answer with itself.

The required concrete mapping is:

- `context.timestamp`, a **present** origin's timestamp, and validUntil use an
  explicit affine map T(t)=B+1152\*t. Context t=0 is a real time T(0).
- Stored rulesTime=0 and stopTime=0 map to zero sentinels; finite nonzero stored
  times and scheduling arguments map with T. Rules-time sentinel99 maps to
  uint48.max. Stop-cancellation arguments `(0,0)` remain zero.
- Public heights S=6/checkpoint12, K=6, L1 block numbers, generation and nonce are
  not timestamp-scaled. Setup's origin block is100; a call's block is100+at.
- An absent origin is all zero on chain; its timestamp is not T(0).
  `originHeight` projects the raw origin record. For an unwritten start, the
  contract's generationStartHeight() getter reverts, so use origins(generation)
  plus the explicit start-written flag instead of asserting a zero getter return.

The switching-network S=6 setup and optional first landing must be constructed
through public APIs by C05. The inherited proof premise is not a substitute for
that concrete prehistory. All modeled registry contexts are unlocked; callback
lock behavior is not claimed. Uninitialized/missing-start profiles use zero
checkpoint/origin projections. No private slot planting is required to construct
these schedules. Concrete ABI/uint48 boundaries and any unavailable setup cases
must be separately labeled by the consumer, not fabricated as model exports.

## Independent assertions and mutation sensitivity

Operational `Allowed`, `Changed` and `Written` compute public-call behavior.
`ExpectedAccept` and `ExpectedAfter` read captured raw arguments/context/prestate
without invoking those helpers. `OriginalCallPreserved` independently compares
receipt arguments/context against the original raw program. Full after-state
must match both the independent expected state and, at a completed call boundary,
the current raw model state. Events are checked independently against its actual
five-field after-state and emission flag. Source arrays, inherited state and
original call inputs are not rewritten to accommodate a failed test.

`historyAudit` is an observer-only append sequence. At a public call it captures
actual receipt after-state schedule/generation/origin and the original call time;
at an L1 advance it captures the current raw schedule fields/generation/origin
and next timestamp. Initialization is a separate literal record. It never calls
`Snapshot` or `AppendSnapshot`, and no operational guard or writer consults it.
`HistoryProvenance` compares the entire retained operational history against that
audit, including every old entry and the sequence length, then binds the latest
entry to current raw L1 state. Candidate receipt histories must equal the audited
prefix of their independently recorded observation length. Thus an incorrect
history append cannot silently change both the input and expected rule.

Candidate observations capture the actual selected schedule/rule/stop/outcome,
L1 clock, candidate metadata, support set and historical snapshots. Independent
formulas read the selected raw historical snapshot. `AnchorAgreement` additionally
compares all available valid same-generation anchors for that candidate's time
and parent, establishing equal rule and stop results in this workload. It does
not claim agreement with anchors absent from the finite canonical history.

There are 34 configurations: two normal exhaustive searches, twenty-two permanent
negative controls and ten existential witnesses. Controls alter strict lock
inequalities, owner/initialization gating, failed promotion persistence, raw
schedule/argument/event/origin writes, recovery pending/stop/number behavior,
historical-anchor choice, L1/L2 clock choice, activation equality, candidate-
instead-of-parent stop inputs, recovery-origin-instead-of-S, unsupported-rule
acceptance and the selected-rule write itself. Three additional controls corrupt a newly stored snapshot, rewrite an older
retained snapshot, or omit a history append. Pure writes leave acceptance
guards unchanged. Every control requires exactly its named invariant violation;
parse errors, incomplete assignments and timeouts never count as a pass.

Witnesses show earliest scheduling, lock equality rejection, MAX cancellation,
promotion, zero/nonzero recovery, a historical-rule decision different from
using today's schedule, a stopped successor, support upgrade followed by retry,
and production eligibility after recovery. They establish existence, not
fairness, eventual upgrade or liveness under arbitrary failure.

## Reproduction and evidence discipline

Use the unchanged runner with supplied Java/TLC/Python and output locations:

```sh
"$PYTHON" formal/etna/check.py --java "$JAVA" --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR" --case rules-public --case rules-observation \
  --case rules-negative-schedule-write --case rules-negative-historical-anchor \
  --case rules-negative-mixed-clock
```

All configurations are `configs/rules-*.cfg`. The runner snapshots every top-level
TLA module and selected configuration, using one worker, seed one, a 512 MiB heap
and 45 seconds per case. Source must remain frozen during runs.

The first thirty exact expectations were declared before implementation; the
original-argument control was added during source-informed refinement. This is
not conventional production-code unit-test RED/GREEN: no production code changes.
The initial incomplete waitSeen assignment was a repaired TLA modeling error,
not a protocol finding or semantic negative result. A successful 31-case run
preceded sparse candidate enumeration, which preserves the same admissible
candidate product while avoiding invalid Cartesian tuples. No timed-out or
incomplete larger workload is silently counted as passing.

Independent review subsequently exposed a history-assertion gap: changing only
Snapshot's schedule write to ZeroSchedule still exhausted the old normal
observation search with 5,892 distinct states. The earlier candidate assertions
read the same corrupted history. Existing witnesses could reject that broad
mutation, so this is not a claim that all previous configurations missed it.
Review repair wave 1 added the independent audit, retained-prefix/current-state
checks, and three permanent history-write controls. Normal graphs still exhaust
at 217 public and 13,680 observation states. This is a model/assertion repair;
no specification or production implementation defect was established.
