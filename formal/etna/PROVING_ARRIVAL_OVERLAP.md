# J05: partial proof arrivals and overlapping same-block landings

`EtnaProvingArrivalOverlap.tla` adds a finite scheduler and a complete raw observer to unchanged `EtnaProvingProgress`. All original actions and `Init` remain authoritative. The wrapper bypasses only `Setup`, keeps `stage=0` and never increments production count itself. There is no recovery or rewrite action in this scheduler.

The canonical SPEC remains commit `d18357214fab30ea512ae9858a11699806d72ba1`, blob `649548c58d6629dd85143b33efd3644a3bb71509`, SHA-256 `4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`. Current-source comparison is scoped correspondence only. This batch addresses the partial-arrival and unchanged overlapping-task boundaries of PROOF-6.2, LAND-6.1, BATCH-6.3, and BACKP-6.4; it does not establish correspondence with a concrete prover/STF implementation.

## Finite product and frozen literal calls

Bounds are `MaxHead=3`, `MaxProduces=3`, `MaxTime=2`, `U=2`, `BlobCapacity=2`, `RefWindow=1`, `AncestryBudget=1`. Resource profile is Variable. Original past reference, past finality, block-end checkpoint, full original data, backend binding, actual parent, generation and candidate-anchor guards are TRUE. Reference/generation rewrites and proved/included production credit are FALSE.

All twelve exact event lists and their expected enabledness vectors are literal CASE arms in `OverlapCalls` and `OverlapExpectedEnabled`. Configurations select pure zero-arity literal operators with `<-`; cfg syntax cannot directly encode sets of tuple literals. The union normal configuration covers all twelve programs, and twelve singleton witness configurations each demand the entire terminal history.

Each list starts `ProduceOld, ProduceOld, CaptureShort, CaptureLong`: actual initial-anchor production twice at time 0, then job 0 `(parent0,terminal1,reference0)` and job 1 `(parent0,terminal2,reference0)`. Each arrival is immediately followed by `ShortA, ShortB`; Early adds `LongA` immediately after those attempts. H means `History(TRUE)`, A/B mean the corresponding `Availability(backend,TRUE)`.

| Arrival order | Short A/B enabled masks after arrivals | Early long A masks | Profiles             |
| ------------- | -------------------------------------- | ------------------ | -------------------- |
| HAB           | 00 / 10 / 11                           | 0 / 1 / 1          | HAB Early / HAB Late |
| HBA           | 00 / 01 / 11                           | 0 / 0 / 1          | HBA Early / HBA Late |
| AHB           | 00 / 10 / 11                           | 0 / 1 / 1          | AHB Early / AHB Late |
| ABH           | 00 / 00 / 11                           | 0 / 0 / 1          | ABH Early / ABH Late |
| BHA           | 00 / 01 / 11                           | 0 / 0 / 1          | BHA Early / BHA Late |
| BAH           | 00 / 00 / 11                           | 0 / 0 / 1          | BAH Early / BAH Late |

The exact common tail is `PublishShort, BOff, Tick, ShortLand, AbsentLongB, PublishSuffix, BOn, LongB, SuffixLand, PublishFull, FullLand, Tick, Finalize, PublishAnchor, ProduceFinal`. Late inserts its sole `LongA` between `ShortLand` and `AbsentLongB`. Early therefore has 31 calls and 32 reached program states; Late has 29 calls and 30 reached program states. These are static schedule sizes, not engine results. Enabled repeat completions execute idempotently and do not represent extra proof work.

`OverlapCall` dispatches these names to actual inherited actions. Every enabled call executes, except the explicitly named omission under test. Actual `ENABLED` alone selects execution. Literal masks never gate actions. Each receipt retains call, enabled/executed bits, and the entire original `r`, `seen`, `stage`, and `producedCount` before and after. Stage is bound before primed raw fields are evaluated. Types cover complete original state and journals; refusals require exact raw equality.

## Critical chronology and independent literal observations

Both captured job records, payload sequences, cut sequences, dependency 0 and distinct statements are defined literally without the engine's Data/Cuts/Statement/Ready helpers. Short results bind the short statement and long results bind the long statement. Each initial attempt's actual enabledness and returned proof are checked against independent literal vectors.

At time 1, short Land executes with both cached results and full short data while B is absent. Long A has completed; long B is actually attempted and refused while B is absent. `Publish(1,FALSE)` at included 1 publishes only height 2, while the immutable long job retains both original payloads. After B returns, long B completes. Actual suffix-only Land then refuses even though both statements match, dependency/reference 0 are supported, age 1 equals RefWindow 1, the origin record exists, and the current cut at included 1 matches.

After actual full two-payload publication, long Land executes in the same time-1 block with actual parent 1; immutable job parent remains 0. Record 1 must survive, record 2 must have parent 1, and heights 1/2 each apply exactly once. At time 2, actual `Finalize(1)` selects block-end checkpoint 2. Publication creates the literal anchor `(generation0,checkpoint2,reference1,Cut(0,2))`; actual production with that anchor creates height 3. Full witness checks require these receipts and identities, beyond terminal counters.

## Omission and actual-source controls

`missing-short-land` suppresses only the enabled short Land. All subsequent enabled calls still execute. At included 0, suffix publication is now the complete long range, so the nominal suffix Land legitimately goes 0→2. The later full Land refuses because it is settled. Its raw endpoint has head3/included2/finalized2, one Land with parent0, no record1, record2 parent0 and applied counts1/1. This control demonstrates why headline counters do not establish the two-landing history.

`missing-full-publication` suppresses only full long publication. Both long results exist, but long Land refuses on the one-payload publication. Finality selects checkpoint1 and publishes its anchor. The scheduled production explicitly requests literal checkpoint2, so it refuses: the raw endpoint is head2/included1/finalized1, one Land, record1 present, record2 absent. A different candidate checkpoint1 could permit production, outside this fixed event list. Union omission configs require the precise partial endpoints; singleton `-raw` configs emit them with the exact `OverlapPartialTerminalNotReached` violation. PASS here is witness loss, not successful full progress.

The planned fault uniquely changes the actual `Land` r-prime update from `r'=[r EXCEPT !.included=x.terminal,!.records[x.terminal]=rec]` to `r'=[r EXCEPT !.included=x.terminal,!.records[x.terminal]=rec,!.records[r.included]=IF r.included=0 THEN @ ELSE AbsentRecord]` in a private copy. It preserves genesis on the first Land, then erases retained record1 on the second. The focused `retained-prefix-audit` config excludes inherited checkpoint preservation and full terminal assertions so the intended exact `OverlapRetainedPrefixAudit` failure is isolated immediately. Mutation must never change observer expectations. The same private copy must pass all twelve full witnesses before mutation, fail that audit on the actual source mutation, then restore exact source bytes and pass all twelve full witnesses again.

No TLC/SANY engine has run as part of static preparation. Runtime evidence and exact source/tool/copy guards belong in the retained task report. Execution requires independent literal-dispatch source approval and one full-witness smoke, then root readback before remaining lanes.

## Limits

This is a finite twelve-program product over selected arrival permutations and long-A timing, with bounded repeated attempts. It proves no arbitrary outage interleavings, fairness, throughput, real proving performance, archived-product equivalence, concrete STF correctness or frozen protocol implementation. Capacity counts symbolic payloads. The original RefWindow also bounds producer anchor age, so this does not establish independent age budgets. Broader source correspondence and final accumulated gates remain root responsibilities; no sixth batch is implied.
