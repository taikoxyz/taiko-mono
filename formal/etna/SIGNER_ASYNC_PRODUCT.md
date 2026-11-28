# Free two-rank signer crash and recovery product

`EtnaSignerAsyncProduct.tla` imports unchanged `EtnaSignerCrash` and starts at
its real Init. Literal independent records check all21 operational variables,
initial values, and every action's complete changed and unchanged state.
This is a symbolic process-crash product with one serialized signer owner.

The scheduler offers all26 Request arguments: domain0 ranks1/2, A/B/Nil,
salts0/1 and both application replies; domain1 rank1/A/salt0 and both replies.
Both Trust domains and Expose replies, Persist, Connect, Crash, Restart,
MarkUncertain and every currently queued Deliver interleave freely. The actual
recovery action is offered while PRE everFloor=0, including private Computed
and Persisted work; no second recovery is offered. No oracle selects actions,
pre-filters old requests or forbids repeated set-idempotent Expose/Deliver.
All six operational correctness switches remain TRUE in every profile.
No old operational/config/checker or default493-config bytes change.

## Independent observations

`AsyncRequestEnabled` compares actual ENABLED Request in both directions for
all26 arguments in every reachable state. Its expected eligibility is derived
from running/certain/trusted/connected/reply/Idle, actual domain and known floor,
and PRE durable rank/payload. It never calls an inherited guard or constructor.
`AsyncOtherEnabled` similarly checks both Expose replies, both Trust domains,
Connect, Persist, recovery, Crash, Restart, uncertainty and delivery for every
record (including records absent from the queue). Refusal means model
eligibility observation, not an external signer response.

Every wrapper executes the actual operational action before independently
checking a complete PRE/POST record equation, including fields that must stay
unchanged. `AsyncExactReuse` checks at the actual Request branch that same-rank,
same-payload retry chooses PRE durable bytes, regardless of the incoming salt.
The fresh branch expects the literal symbolic signature tuple. Incoming salt
and reply are captured with the actual call on any audit failure and on the
selected witness milestone; inherited actualRequest alone lacks salt.
Expose checks current durable bytes, actualRequest identity, floor, exact return
and queue unions, event and frame. Deliver checks the actual record argument,
exact delivery union, event and frame even when its set union changes nothing.

Init, effects and reuse use sticky Booleans. A failure-only raw record contains
kind, actual arguments and complete PRE state; normal states have no latest-call
history factor. Only a selected witness uses its own small phase counter,
queued identity and milestone call. Raw operational states remain in TLC traces.
Trust preserves connection; Connect has no explicit certainty guard; Persist
has no trust guard. Crash resets knownFloor to0 even after recovery. Restart
reloads durableFloor without restoring trust or certainty. Deliver never needs
current trust, certainty, generation or a running process.

## Opt-in profiles

Use the existing checker with an explicit config directory and local tools:

```sh
python formal/etna/check.py --java "$JAVA" --tlc-jar "$TLC_JAR" \
  --config-dir formal/etna/products/signer-async --case normal \
  --output-dir "$OUTPUT_DIR" --timeout 300
```

- `normal`: joint full free-graph safety. A valid PASS needs real queue0
  completion within the approved cap, at most300seconds.
- `reuse-audit`, `request-audit`: focused positive controls selecting only the
  independent exact PRE-byte reuse or all26 eligibility audit, respectively.
- `witness-retry`: actual private persisted Nil/salt0 crash, restart, actual
  same-rank incoming-salt1 retry returning the saved bytes; then actual repeated
  Request/Expose whose return and queue unions are idempotent, first delivery
  and actual repeated delivery whose delivery union is idempotent.
- `witness-value-conflict`, `witness-nil-conflict`: rank2 A or Nil persisted and
  Idle with valid trust/connection, all lower-rank offers refused, exact payload
  retry enabled with both salts, and same-rank A-to-Nil or Nil-to-A refused.
- `witness-computed-recovery`, `witness-persisted-recovery`: old rank1 Nil/salt0
  queued and NOT delivered, rank2 B/salt0 private work in the selected phase,
  actual recovery, actual crash/restart with reloaded floor1, actual fresh
  domain1 return, then actual FIRST delivery of the retained old queued record.
  The Computed branch requires private bytes absent from writes; Persisted
  requires those bytes in durable storage but absent from returned.
- `witness-uncertain`: actual uncertainty, all26 Request and both Expose offers
  refused, then actual crash/restart preserving uncertainty and all refusals.

Each witness expects its single exact named `*NotReached` violation. This is
reachability evidence, separate from exhaustive safety. No engine result is
implied by static profile tests. Parser/setup errors, timeout, wrong violation,
source drift and incomplete graphs get zero PASS credit. Raw failed larger
attempts remain retained if observer or semantic reductions become necessary;
no reduced graph certifies the advertised joint dimensions.

## Actual-source controls and limits

The author control changes the actual Request reuse branch from PRE durable[d]
to recomputing `Record(d,s,p,salt)` using the incoming salt. It must violate
`AsyncExactReuse` with same-rank/payload, distinct saved/incoming salts and
actual captured call arguments. It must use the same private source copy for
original, fault and restoration, with exhaustive queue0 original/restored
`reuse-audit` positives and the independent Nil/retry witness.
The independently selected control removes only the actual same-rank conflict
conjunct with RejectConflicts still TRUE. It must violate
`AsyncRequestEnabled` at a reachable Idle, trusted/connected same-rank different
payload prestate. Removing a floor guard alone may be masked by correct trust
and cancellation behavior, so it supplies no control evidence here.

Execution requires a separate root-reviewed static packet, one <=20second
smoke release/readback, then separate full/control release. Existing
check.py, sensitivity.execute and conformance/run_isolated are the sole runner,
classifier, supervisor and isolation implementation. Private input copies,
read-only model/tools and one writable output, exact hashes and bounded nested
deadlines are part of that packet, not new runtime machinery in this module.

C01 remains OPEN; all19 archived cases remain INCONCLUSIVE. Durable generation
floor, trust authentication and cancellation are abstract interface premises,
not concrete FilePV/WAL/process-supervisor, power-loss, failover or cryptographic
proof. Fresh domain1 intentionally has only rank1/A/salt0. No fairness,
eventual reconnect/delivery, full archived graph, production equivalence or
SignalService/beaconRootsFrom bootstrap verification is claimed. Measured raw
outcomes and exact input identities belong in the task report after execution.
