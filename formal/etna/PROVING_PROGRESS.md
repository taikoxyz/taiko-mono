# M07: bounded proving, data and back-pressure topology

`EtnaProvingProgress.tla` is an explicit **standalone interface model** of Etna
SPEC at `d18357214fab30ea512ae9858a11699806d72ba1`, sections 5.2 and
6.1–6.4. It does not form a product with the preceding settlement, identity,
committee, FI, signer or application modules. Its jobs assume a valid underlying
chain and sound backend proofs of their stated inputs; it checks pipeline binding,
ordering and conditional enabledness, not cryptography, STF execution or throughput.

## Distinct progress states

| State                              | Meaning                                                                      |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| `r.head`                           | Produced L2 height                                                           |
| `r.parentAnchor`                   | Actual anchor selected by the last produced block                            |
| `r.included`                       | Latest L1-included checkpoint; not production credit                         |
| `r.finalized` / `r.finalizedBlock` | Checkpoint in a finalized L1 block and that source block's identity          |
| `r.anchors`                        | Available authenticated finalized snapshots                                  |
| Produced event's `selected`        | Actual adoption in that candidate block                                      |
| Job/proof/data fields              | Immutable task, independent backend artifacts, public data and prerequisites |

The finite grid is K=1, U=2. A next block checks its **own candidate anchor**:
`nextHeight - candidate.checkpoint <= U`. It can select a newly finalized anchor
in the same validation step, even when the parent block's old anchor is paused.
No preliminary block under the old anchor or separate adoption transaction is
required. `Land` is independent of producing another L2 block. Proof completion
and L1 inclusion grant no credit. Finalization exposes a new snapshot; production
uses it only when that candidate actually selects it.

Every produced event retains the raw pre-head/parent cut, independently requested
anchor and actual selected anchor/output. Independent predecessor/origin checks
prevent a self-consistent height or anchor write from evading the limit. Retained
checkpoint records and per-height suffix application counts are separate histories.

## Immutable jobs and public data

Two logical job ids are available, each used once. Capture stores generation,
retained origin p, terminal h, reference identity, a dependency summary, every
payload in `(p,h]` and all cut identities from p through h. A symbolic statement
tuple commits to all of these. A separate raw capture ledger reconstructs the
expected tuple without the operational statement helper. This models statement
binding, not the exact Etna ABI, hashing or serialized public-input format.

Backend A and B availability, private consensus history, published payloads,
completed artifacts, reference age and ancestry support are distinct. A backend
may return a valid artifact for another captured task; packaging it for this job
does not make it a proof of this job. Actual completion outputs are checked against
independently retained request inputs, and landing requires both results to match
the same original task. Losing a backend after completion does not erase an already
valid cached proof. There is no fairness or rule forcing resources/data to arrive.

Publication can offer either the original range or a candidate suffix. Correct
landing accepts only the complete original `(p,h]` payload, including when another
job has advanced c to an interior cut. It checks that cut against the retained
record, records actual parent c, applies only `(c,h]`, and preserves prior records.
If c>=h, the task is already settled. Editing a completed job's reference or
generation does not reprove it: a new statement requires another logical task.

Blob capacity is normalized to payload units: capacity 2 can carry the two-block
job, while capacity 1 can carry its K=1 prefix but cannot make an old-p two-block
publication fit merely because one block is already settled. These units are not
literal blobs/bytes. Six-blob packing, decompression, encoding, actual headers,
EL/Comet/FI identities and proof construction are interface premises/exclusions.

## Reference and L1 finality clock

The normalized `now` and inclusion timestamps identify L1 block indices. Ordinary
landing requires a strictly past reference (`reference < now`) within the configured
window. Current-block references cannot be verified by treating them as historical
block hashes. The default window is 1; a focused old-generation control uses window
2 so its original reference remains live across the recovery macro.

`Finalize(block)` accepts a strictly earlier L1 block and derives the **last**
checkpoint included by that block. Two compatible overlapping jobs may both land
in block 1, but finalizing block 1 must expose their final checkpoint, not its
intermediate transaction state. Events distinguish source block identity from the
later time finality was observed. `PublishAnchor` uses that actual finalized block
as reference/root identity. An independent oracle derives ordinary finalization
chronology and block-end checkpoint from raw actual landing receipts, rather than
trusting the finalizer's mutable record map or selection helper.

Genesis is an imported finalized bootstrap. Recovery is a separately tagged,
trusted **already finalized and authenticated recovery/bootstrap macro**, not an
ordinary unfinalized transaction that immediately grants credit. It executes at
R=`oldNow+1` and is observed at `oldNow+2`, within the time bound. It preserves c,
records and physical backend/history availability while resetting unsettled
production to c and supplying the new-generation bootstrap anchor/dependency.
Ethereum finality of that external macro, authority, committee reconstruction and
physical EL restoration are premises; the ordinary finality oracle does not claim
to prove them. With the default time bound 2, recovery can occur only from now=0,
so these default cases cover recovery at c=0, not arbitrary settled recovery origins.

## Resource/ancestry boundary

The dependency scalar is a chosen summary of an older required anchor/selection
root, fixed for a generation in this fixture. Supported proof input requires
`reference - dependency <= AncestryBudget`. This represents a finite proving/ancestry
resource interface, not a new deployed contract condition. A fresh reference does
not change the old dependency. Recovery establishes a new dependency only under
its explicit authenticated bootstrap premise and does not make absent backends or
private history available.

The old-ancestry witness checks this topology: a newly captured current reference
can still be outside the modeled ancestry budget. The default `Absent` profile
cannot settle c=head and demonstrate a fully settled long-pause recovery/resumption.
No such result is claimed. BATCH-6.3's known long-pause limit remains; this increment
does not prove that refreshing a reference or recovery always repairs every missing
resource, nor that all possible historical reference choices have been exhausted.

## Exhaustive workload profiles

All cases bound head at 3, total production calls at 3 across generations, two job
ids and time at 2. The initial source-valid prefix produces heights 1 and 2 under
the imported genesis anchor, then captures old-p jobs. Every intermediate prefix
state is checked. The total production bound and finite task ids are external
workload limits, not protocol limits.

| Normal configuration      | Conditional workload                                                                                                                                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `progress-pipeline`       | Capture jobs `(0,1]` and `(0,2]`; execute successful history/backend availability, matched A/B completions and full publications before exposing all post-prefix actions; capacity 2                               |
| `progress-small-capacity` | Same executed ready-task prefix, capacity 1; the short prefix can land while the original two-block job cannot                                                                                                     |
| `progress-ancestry`       | Capture only the two-block job, leaving a fresh task slot; `ResourceProfile=Absent` keeps private history and both backend providers unavailable permanently; data may independently remain absent or be published |

The ready prefixes are explicit conditional scenarios. They **do not assert that
proofs inevitably arrive**. After those prefixes resources can disappear, artifact
packages/publications can change, references can expire, jobs can race and recovery
can invalidate them. The absent profile checks a legitimate permanent-resource
pause. These profiles do not exhaust arbitrary partial-arrival/outage schedules
before any job becomes ready. A broader initial dynamic-arrival experiment remains
incomplete, as described below.

All selected action types remain available subject to ordinary guards and the
finite workload. Some are unreachable after bounds are consumed: default recovery
advances directly from time 0 to 2; once both task ids are used, capturing a distinct
refreshed task is unavailable; after three production calls no further block is
in scope. Those finite edges are not protocol deadlock or throughput claims.

## Conditional progress and controls

`ReadyLandingEnabled` independently constructs the original task's full ready
prerequisites from captured inputs and actual artifact/publication state, then checks
that landing is enabled. `FinalizedCandidateEnabled` checks that an authenticated,
fresh candidate anchor with room under U enables the next production call even when
the parent anchor has no room. Neither predicate assumes execution fairness or
provides an unconditional temporal eventuality. Missing proof/data/finality or old
ancestry can legitimately pause the system.

Six deliberate witness searches reach the exact pause boundary, land while paused,
remain paused after mere inclusion, resume with actual finalized anchor adoption,
land an unchanged compatible overlapping job, and capture fresh-reference/old-root
ancestry. Twelve fault controls test included/proved credit, old generation,
reference/generation rewriting, suffix-only data, mismatched backend statements,
wrong actual parent, parent-anchor circular wait, current-block references,
premature/current-block ordinary finality and an intermediate checkpoint from a
block containing two positive-height landings. Each must fail its exact independent
receipt, input, chronology or enabledness invariant. These are model sensitivity
checks, not protocol findings.

## Incomplete historical experiment

Three initial dynamic-arrival profiles exceeded the 45-second limit. Exact inputs
and intermediate progress are archived outside the default suite under
`experiments/progress-initial/`. That prototype also preceded the strict-reference
and finality-clock repairs; it is historical modeling/cost evidence, **not** an
incomplete verification of the final model's exact semantics. The repaired full
arbitrary-arrival product was not exhaustively checked. The current ready/absent
workloads are not claimed equivalent to it. No timeout is counted as PASS.

This increment establishes no 4-second/20-minute SLA, sustained proving capacity,
consensus latency, complete protocol correctness or real proof. It assumes valid
underlying chain/STF, authentic reference/header inputs, proof soundness, data
identity and the tagged bootstrap interfaces. Unbounded loads, actual proving,
full ancestry proofs, deployment parameters, verifier-failure rollback and formal
composition with preceding increments remain outside scope.

## Validation of this candidate

The implementer ran all 21 default M07 cases on module SHA-256
`4a102d5e465b7c943b8564994a320fb4b2af13fbe5348c0f095aa75016fa0105`. All exact expectations passed: three normal exhaustive profiles,
twelve fault controls and six witnesses. Normal runs finished with queue zero;
controls/witnesses exited 12 at the declared invariant.

| Normal profile            | Generated | Distinct | Final queue |
| ------------------------- | --------: | -------: | ----------: |
| `progress-ancestry`       |     1,133 |      133 |           0 |
| `progress-pipeline`       |   172,176 |   10,381 |           0 |
| `progress-small-capacity` |    87,088 |    5,261 |           0 |

Independent source review and behavioral verification, plus accumulated-suite
results, are recorded by the task owner in the main report before integration.

The task owner also independently completed the current accumulated suite:
175/175 exact expectations, including 28 normal queue-zero searches and 147
expected invariant counterexamples. These counts do not change the scope limits
or make the archived incomplete products verified.
