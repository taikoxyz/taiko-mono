# H03: resource churn, expiry, distinct recapture and actual resumption

`EtnaProofRecapture.tla` is an additive finite scheduler and raw observer over
unchanged `EtnaProvingProgress` (M07). Its initial state is exactly `Init` plus
three local observer/scheduler variables. It bypasses `Setup`, holds `stage=0`,
and invokes the original `Produce`, `Capture`, `History`, `Availability`,
`Complete`, `Publish`, `Tick`, `Land`, `Finalize` and `PublishAnchor` actions.
There is no second proof, landing, finality or production engine.

The canonical SPEC authority remains commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`. The independently reviewed
workspace correspondence is a separate source gate; it does not replace that
historical pin. Relevant rules are LAND-6.1-10, PROOF-6.2-4/6/9,
BATCH-6.3-4/5/6/12a/13, BACKP-6.4-1/8, and ACCEPTANCE 1.3–1.5.
See [M07](PROVING_PROGRESS.md) for the original interface boundaries.

## Previously omitted chronology

The old ready/absent workloads consume both task slots or keep resources absent,
and stop at time 2. Here two old blocks are actually produced, one complete task
actually expires, and a distinct supported-reference task is captured. A backend
then returns the old task's valid statement in the new task's package. The fresh
correct statement is subsequently completed and actually lands; ordinary finality,
anchor publication and another actual production action complete the history.
No recovery action exists in the companion scheduler.

Bounds are `MaxHead=3`, `MaxProduces=3`, `MaxTime=4`, `U=2`, `BlobCapacity=2`,
`RefWindow=1`, `AncestryBudget=3`, two task IDs and backends A/B. M07 deliberately
uses the same `RefWindow` for proof-reference age and production `maxAnchorAge`.
This reduction is preserved, not a verification of two independent production
parameters. Publication capacity counts symbolic payload units, not literal blobs.

| Calls | Actual input/history                                                                                                                            |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 1–3   | Produce heights 1/2 with genesis anchor at time 0; Capture(0,0,2,0).                                                                            |
| 4–18  | One of two finite resource orders below; Complete old A/B, publish full old data; lose history and both backends while cached artifacts remain. |
| 19–21 | Tick twice; attempt Land(0) at time 2. Both old statements and full data are present. Only its reference age is invalid.                        |
| 22–28 | Capture(1,0,2,2); restore history/A/B; Complete(1,A,0), Complete(1,B,1), Publish(1,TRUE). A deliberately contains the old statement.            |
| 29–30 | Tick to 3; attempt Land(1). Age and ancestry are supported; only A's statement binding is wrong.                                                |
| 31–32 | Complete(1,A,1) replaces the old statement with the fresh statement; actual Land(1) at time 3.                                                  |
| 33–36 | Tick to 4; Finalize(3); PublishAnchor; Produce with literal anchor (generation 0, checkpoint 2, reference block 3, Cut(0,2)).                   |

`HistoryOrder` arrives with history before A; `BackendOrder` arrives with A before
history. Refused completions at calls 5, 9 and 12 alternate exactly one absent
prerequisite. Call 16 again attempts A with cached A proof present and history
available but its backend absent. Resource restoration never fabricates a proof.
These are bounded one-time arrivals/losses, not arbitrary outage interleavings or
an execution-fairness claim.

## Independent raw observations and complete positive terminal

Every scheduled call records the complete raw `r` and production count before and
after, its literal call arguments, actual inherited-action enabledness, and whether
it executed. Enabledness decides execution, including the two expected bad-land
attempts. No `Ready`, `OracleReady` or copied landing predicate schedules a refusal.
The dedicated expiry and binding audits observe those outcomes after the call.

Literal task/data/cut/proof records are written independently of M07's operational
`Data`, `Cuts`, `Statement` and `Ready` helpers. Raw resource audits check each
single-prerequisite refusal and unchanged raw state. Milestone audits inspect the
actual recapture, A replacement, accepted landing, finalization, publication and
production before/after states. Normal profiles also retain M07's applicable
input, statement, checkpoint, finality, anchor and once-only application invariants.

The positive witness requires all 36 receipts, with exactly calls 5/9/12/16/21/30
refused. Both old proof records, publication and complete old task remain intact.
The fresh job is identical except its immutable reference/statement is 2. The
actual fresh landing moves included checkpoint 0 to 2, at L1 block 3 with parent 0.
Ordinary finality observes block 3 at time 4 and yields checkpoint 2. The newly
published anchor is actually selected by produced height 3, from parent height 2.
Final generation/start/dependency remain 0; produced count/head are 3; included and
finalized heights are 2; heights 1/2 are each applied once, 0/3 zero times; exactly
one landing and no recovery occurred. Both resource orders must reach this full
terminal, not merely a prefix or an enabled final action.

## Profiles and discriminating controls

- `proof-recapture-normal`: both orders, all ordinary/raw/milestone/terminal audits.
- `proof-recapture-witness-historyfirst` and `...-backendfirst`: each independently
  violates only `RecaptureTerminalNotReached` at its complete positive terminal.
- `proof-recapture-audit-expiry` and `...-binding`: focused normal PASS profiles
  selecting only their dedicated raw refusal audit. Alone they make no positive
  progress claim; the normal/witness profiles establish the required prehistory.
- Five `proof-recapture-missing-*` profiles suppress exactly the scheduled fresh
  completion, fresh landing, finalization, anchor publication, or final production.
  They exhaustively PASS `RecaptureTerminalNotReached`, demonstrating lost complete
  progress. This is absence of a witness, not proof of safety or successful recovery.

Actual-source fault trials remove only the age conjunct from operational `Ready`,
or only its backend statement equality conjunct, in disposable private M07 copies.
The age omission actually executes Land(0) at time 2 and violates
`RecaptureExpiryAudit`; the equality omission actually executes mixed Land(1) at
3 and violates `RecaptureBindingAudit`. Focused configs avoid crediting a generic
inherited statement/type/parse failure. Baseline and actual same-copy restoration
must PASS. Original source bytes remain unchanged. These are source-fault
sensitivity experiments, not protocol findings.

The implementer executed all 41 discovered M07-dependent profiles: 21 original
`EtnaProvingProgress` profiles, 10 original `EtnaProvingRecovery` profiles, and
10 new `EtnaProofRecapture` profiles. Every exact expectation passed,
including the two full terminal counterexamples, normal queue-zero searches and
five missing-action witness-loss controls. Both actual-source omissions were
KILLED by their exact dedicated audits, with baseline/restored success and stable
original/tool inputs. The root records the independent source review, behavioral
challenge, raw artifacts and immutable hashes before publication.

## Reflection and remaining premises

The strongest plausible false green was a scheduler that precluded bad Land or a
terminal observer satisfied after only preparing a proof. Actual attempts, raw
before/after states, complete literal terminal conditions, two actual-source bad
lands and missing-required-action controls address that failure mode. Independent
behavioral verification must choose an additional challenge rather than only
repeat author-selected omissions.

The new exercised history is finite resource churn followed by actual expiry,
recapture, mismatched packaging, genuine fresh completion, inclusion, finality and
resumption. It does not solve long outages: reference 2 minus dependency 0 remains
within ancestry budget 3. Valid chain/STF, sound backend statements, authentic
reference/header/finalized anchors, usable history and actual proving capacity
remain premises. This is no real proof, cryptographic verification, throughput or
latency result, physical history-retention guarantee, runtime liveness theorem,
or refinement of a deployed prover/client.
