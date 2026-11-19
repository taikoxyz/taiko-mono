# Current timestamp schedule and structural recovery product

This separately named finite model follows SPEC `2e6763e21` and ACCEPTANCE section6.
The historical grid-based rules model and its evidence are unchanged. The new
model is neither a current client/contract nor a runtime readiness assertion.

## One state and actual inputs

`EtnaTimestampSchedule.tla` defines current operational schedule functions.
`EtnaTimestampRecoveryProduct.tla` owns the single live schedule, generation,
checkpoint, nonce, origin records and chain in `s`. Its L1 views record each
block's post-transaction state. A block captures its own finalized anchor view;
later L1 writes do not rewrite that block or a captured proof job. The external
authorization object is a caller input, not a contract recovery queue, and does
not freeze landing. Recover checks its actual generation/checkpoint/nonce,
inclusive deadline, owner and initialized/start state. It has no planned-stop
prerequisite. Only empty recovery exclusion/FI-clear lists are represented.
Nonce invalidation needs initialization, owner and matching nonce but no start
write; the pure adapter admits the authentic generation0 state with no origin
record before that write. Recover still refuses it. DAO approval/timelock and
the 8.1 independent audit are owner-call legitimacy premises, not modeled delays;
this product does not measure governance recovery time.

Time and height are separate: L1 block `31+i` has timestamp `100+i` in these
profiles. Recovery stores both the actual execution number and timestamp. A
later finality observation enables the fresh chain. Its first BFT time equals
R's timestamp; its EL timestamp is max(parent EL time+1,BFT time,anchor time).
The concrete regression also uses R.number31/R.time1401, a post-R anchor32/time1402
and first BFT1401/EL1404. Its numerical distinction is not a native execution.

The first block crossing the nonzero stop is valid; subsequent production is
invalid because its parent has reached the stop. There is no grid or prescribed
terminal height. Unknown rules cause WAIT even when the parent has reached a
stop. Every captured block is independently replayed at its own anchor schedule;
using a current schedule to reinterpret history is rejected. Real EL execution,
FI trials, guest implementations, consensus quorum and proving remain premises.

For a named witness, run `python -B timestamp_recovery.py CASE NATIVE_LOG
--workspace-root WORKSPACE`. The JSON receipt contains the fixed
`rules-schedule-model/timestamp-stop` scope, exact current SPEC, ACCEPTANCE
and SWITCH identities, case, raw-log SHA-256 and verified transition count.
The optional `--expect-claim` asserts the expected claim ID. The receipt covers
the named raw witness. Queue exhaustion, source restoration and engine status
require their separate native records. The pure `audit(text, case)` also
accepts raw frame sequences for source-control inspection. Replay checks every
attempt against the selected profile's actual offers. In particular, Recover
receives the authorization stored in its PRE frame, including its exact deadline.
The general contract adapter accepts a genuinely fresh caller authorization.

## Numeric representation

The pinned TLC engine uses bounded machine integers. Native `FieldLimit=999` and
`NonceLimit=9` are finite abstractions, not the protocol's bit widths. Cancellation
is represented by sentinel999 only in the typed `rulesTime` field and a
ScheduleRules activation-time argument. Init requires the whole profile clock
and lead time below that sentinel. The raw event of a successful Rules/Stop/
Recover call is four ordered limbs `(active,next,time,stop)`; failed calls emit
scalar0. The concrete observer maps only that rulesTime sentinel to `2^48-1` and
packs the exact192-bit slot value. Integer999 in another field stays999.

Pure Python checks the real packed48-bit operational fields, uint256 nonce and
deadline, exact nonwrapping sums, cancellation, promotion failure atomicity and
emitted word. Those checks confer no native full-width or ABI execution credit.
Canonical decoded L1 header timestamps already satisfy CONS-3.3-6's uint64 bound;
the adapter assumes authenticated headers and does not check header decoding,
header-width boundaries, canonicality or cryptographic storage proofs.

## Finite profiles and reachable goals

The composition uses new-network S=0, U=2, maxAnchorAge2, two generations, two
immutable proof slots and at most four Produce actions. Main L1 index1..5 means
numbers32..36/timestamps101..105. The main fixed argument alphabet offers Stop103,
nonzero authorization rules1/deadline108, the old interval0→2/reference32 and a
fresh2→3 interval whose reference is actual R. Action ordering remains free.
Finality offers the latest earlier L1 block; proposers can retain older valid
anchors. Software upgrades from rules0 to the declared set{0,1,2}; main proof
completion uses that declared image set. These are selected finite inputs,
not arbitrary schedules, archive delays, job intervals or image combinations.
Named existence companions use VIEW `(s,bad,seen)` to omit only the previous
attempt receipt from fingerprinting. Operational offers, guards, successor
functions, observations and targets never read that previous receipt. The full
actual receipt is still emitted and every adjacent raw transition is checked.
Ordinary safety and source-control profiles retain the complete state. The view
is not credited as full-state safety exhaustion.

The structural goal requires actual terminal Land, then an attempted next block
which is refused solely by the stop (backpressure and every other guard pass),
matching frozen authorization and nonzero recovery, R finality/observation,
the first fresh block with distinct BFT/EL times, fresh Capture and both backend
completions, full publication and Land. Finally the next produced block's own
anchor must carry that newly finalized checkpoint. A later live finality value
alone cannot stand in for that causal last step. The separate fresh-Land goal
keeps the terminal/refusal/recovery/clock prerequisites. Stale-checkpoint
reachability requires all recovery guards except expectedC to pass. A separate
goal permits recovery without any stop.

Small safety and the schedule-dispatch companion are separate bounded graphs.
The latter freely offers Rules/Stop and L1 advancement. Its independently fixed
selected boundary inputs check the actual `Next` receipt, acceptance, event and
whole successor through ENABLED. Omitting a scheduler branch cannot be hidden by
unchanged helper enabledness or an identical storage effect. The reset companion
offers only Stop/Authorize/Recover, at one execution L1 block; it tests the
transition reset independently of the full structural progress goal.

## Private provenance and concrete fixture projection

Job `data` retains complete private block/anchor provenance so the observer can
recompute rules, parent-stop checks and immutable range identity. It is not an
actual public payload. The concrete versioned blob-hash fixture is derived only
from a synthetic EL label. That label includes selected BFT/rules metadata and is
not an EL-header codec. No private witness publication, privacy result, real blob
compression/KZG, actual stateRoot or proof generation follows from it. The W06
four-cut/21-word adapter is reused only for this explicitly synthetic commitment
projection and original-range settlement checks; validator-state commitments
stay outside the proving statement.

Every native trace keeps full actual inputs and PRE/POST state; raw replay checks
every transition, selected slot limbs and original captured data/proof pair.
Expected observations never choose a scheduler branch. Original/source-fault/
restored phases must use the same private source inode and modes. Setup errors,
timeouts and missing reachability are not semantic detections. Native0 with queue0
gives only that finite graph's safety result; named native12 is existence only.

Current status: static implementation and focused interpreter validation only;
native profiles, source controls, restorations and independent raw readback have
not yet run. The initial21-test RED and GREEN precede the combined unknown-rule/
stop regression; that regression exposed a verification-mode label defect. These
are verification-tool findings, not a confirmed natural protocol flaw.

ACCEPTANCE6's actual client/EL/two-guest shared vectors, real rule upgrades,
one-third software pauses, FI singleton trials, mixed two/three-ruleset landing,
cold sync and structural deployment rehearsal remain WAITING. In particular a
three-block pure historical-rules test is not a real three-ruleset landing.
