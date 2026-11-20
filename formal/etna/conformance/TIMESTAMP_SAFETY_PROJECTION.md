# Etna timestamp safety projection

The Y01 wrapper inherits the W07 timestamp product and adds a TLC view
`SafetyView == <<s,bad>>`. Every call still runs the original `Next`
and `Offers`, including refused calls. Each call builds its complete
receipt, updates the observation record and checks admission, frame and event
against the original literal oracles before constructing the sticky `bad'`.

| Profile | Scenario | MaxL1 | MaxHeight | MaxProduces | MaxWrites |
| --- | --- | ---: | ---: | ---: | ---: |
| small-safety | Smoke | 2 | 1 | 1 | 0 |
| reset-safety | Reset | 1 | 0 | 0 | 1 |
| structural-safety | StructuralSafety | 5 | 4 | 4 | 1 |

The corresponding configurations check `Frames`, `Typed`, `Prefix` and
`ScheduleDispatch` with the original initial and transition relation.
`StructuralSafety` retains the original full call envelope at 5/4/4/1.

## Edge lifting

Let a full product state be `(s,bad,last,seen)`. Let `π` return `(s,bad)`.

| Definition | Dependencies relevant to the view |
| --- | --- |
| `Init` | A fixed initial receipt and observation record accompany the original initialized `s` and `bad=FALSE`. |
| `Next`, `Offers`, `BaseOffers`, `CaptureOffers`, `RulesOffers`, `StopOffers` | Choice of kind and arguments uses `Scenario`, the finite constants and `s`. |
| `Can`, `After`, `Event` and literal counterparts | Admission and event computation use the kind, arguments, `s` and constants, including the schedule helpers. `Event` takes actual admission as an input. |
| `Call` | Assigns `s'=r` and the complete `last'=<<k,a,ok,e>>`. Computes `bad'` from old `bad` and the admission, frame and event comparison. |
| `UpdateSeen` | Computes the whole `seen'` from old `seen`, `s`, kind, arguments, actual admission and `r`. Old `seen` occurs only in this observer and witness predicates. No other action reads it. |

For any actual edge with projected source `(s,bad)`, every reachable
representative of that pair offers the same kind and arguments. For that
call, `ok`, `r`, `e` and all three literal comparisons agree between
representatives. The edge therefore lifts from each representative by
assigning `s'=r`, the original `bad'` and the full receipt
`last'=<<k,a,ok,e>>`. Compute `seen'` by applying the original
`UpdateSeen` to that representative's observations. This gives the exact
original full successor for the selected call and representative. A
stuttering step lifts by leaving every variable unchanged. Every original
edge also projects to the corresponding quotient edge. Induction from
`Init` gives the same reachable pairs for the two relations.

`Frames` reads `bad`, so a bad frame remains a distinct key even when
its `s` equals a previously reached state. `Typed` and `Prefix` read only
`s` and constants. For each independently required rules or stop call,
`ScheduleDispatch` still tests
`ENABLED (Next /\ last'=<<k,a,ok,e>> /\ s'=r)` with the expected
admission, event and successor. The edge lifting argument preserves the
kind and all four terms of this **primed** receipt. Each full
representative can supply its own `seen'` in the enabledness query.

All three profiles have empty rules-write offers and empty `RequiredRules`.
The reset and structural profiles check actual stop dispatch, and the smoke
profile has empty `RequiredStops`. Rules-write dispatch remains a separate
scope in the original timestamp product.

Progress and reachability witnesses such as `NoStructural` depend on
`seen`. Their profiles use the original witness view that retains those
observations. The projection supports the four stated safety predicates.
An exhausted projected graph establishes only their bounded result. The
original unviewed timeout remains inconclusive, and liveness, full trace
enumeration, concrete implementation, proving and deployment are outside
this result.

## Source and native invocation

`audit_projection_source` checks the exact reviewed TLA module bytes.
The source hashes below identify the proof boundary including the schedule
read by the original product.

| Module | SHA-256 |
| --- | --- |
| EtnaTimestampRecoveryProduct.tla | d1f46b2ef4543620f7777882c3190bfc4f5e4c4b4f74fd4ec02ee86e741a2e59 |
| EtnaTimestampSchedule.tla | cb164fdfedf957ecad468deff00affedd2e106e87d56b5b659edfed9765b76bb |
| EtnaTimestampSafety.tla | e5071ca484c4d2aa2d92b57b4e2eb190d8c1d0b9a9f1de1db8db2991a8bdebee |

`projection_receipt` accepts the complete raw TLC output, a read-only staged
model directory and the collector's execution record bytes. The collector
records the actual Java arguments, native working directory, typed exit
status and timeout flag, and hashes the raw bytes and the four actual
input files in that run. Readback verifies the hashes and the paths in TLC's
module-parsing diagnostics against that record. It checks each projected config
against its pinned original with the module annotation and view as the only
changes. The collector retains the real working directory, inputs, tool
identities and pre/post hashes and modes. The execution result requires
native exit 0 and a completed empty-queue graph with a proper footer. Raw
TLC output identifies the wrapper and imported modules. The actual command
and staged config bytes identify the selected profile, and the captured raw
digest binds the transcript to that run.

The fixed receipt claim is `boundary-products/timestamp-projection` for the
exact reviewed `SPEC.md`, `ACCEPTANCE.md` and `SWITCH.md` bundle. The shared
selector can return each reviewed boundary-product source scope with
execution `NOT_EVALUATED`. A verified finite execution appears in the
projection receipt's outcome and graph fields.

Same-copy source controls use separate native invocations and retain the
raw refusal and frame observations for the unchanged W07 timestamp oracle.
A control with altered source cannot receive the ordinary projection
receipt. Complete witnesses and source controls retain all native state
and receipt terms for replay.
