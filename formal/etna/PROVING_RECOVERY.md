# F05: nonzero settled recovery and proving resources

[`EtnaProvingRecovery.tla`](EtnaProvingRecovery.tla) is a scripted companion to
the unchanged [M07 pipeline](PROVING_PROGRESS.md). It calls M07's real `Produce`,
`Capture`, resource, completion, publication, landing, ordinary finality and
trusted completed-recovery actions. It adds observations and three finite input
programs; it does not introduce another acceptance engine or copy `Ready`.
M07's SHA-256 remains
`4a102d5e465b7c943b8564994a320fb4b2af13fbe5348c0f095aa75016fa0105`.

## Pinned correspondence and premises

The normative source remains SPEC commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`.

| Selected behavior                                                                                        | Source and boundary                                                                          |
| -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Original full proof/data range, matching current interior cut and actual suffix settlement               | LAND-6.1-2/3/8; PROOF-6.2-9; BATCH-6.3-8/10                                                  |
| Fixed recovery origin is settled c; the new generation starts at c+1 and uses the authenticated R origin | RECOV-8.4-2/3/7/12/13; external authentication/finality is assumed by the existing M07 macro |
| An old immutable job cannot span generations or be relabeled                                             | BATCH-6.3-9/12a/13; generation is a symbolic statement binding, not a new Solidity argument  |
| History and backend availability are separate from completed proof artifacts and public data             | PROOF-6.2-4/6; SYNC-9.1-1/2/4/6                                                              |
| A recent reference does not erase older proving dependencies                                             | PROOF-6.2-33; BATCH-6.3-5/6/7; the scalar ancestry budget is an M07 interface abstraction    |
| Mere inclusion gives no production credit before finality and anchor adoption                            | BACKP-6.4-8; ordinary finalization here is explicitly observed after the source block        |

`Recover` is the existing trusted **already finalized and authenticated**
recovery/bootstrap macro. Its modeled execution at R and later observation are
separate. These scripts do not execute the owner transaction, authenticate its
L1 proof, restore physical EL/Comet stores or derive a committee. Valid chain/STF,
sound backend proofs, authentic inputs and that completed bootstrap remain
premises. Ordinary finality receipts do not prove the recovery macro's premises.

## Three chronological programs

All cases use MaxHead=2, MaxProduces=3, MaxTime=5, U=2, BlobCapacity=2,
RefWindow=5, AncestryBudget=5 and ResourceProfile="Variable". Time and capacity
are normalized model units. The two logical jobs are each captured at most once.

At time0 each program produces heights1 and2, captures short job0 `(p=0,h=1,ref=0)`,
explicitly enables private history and both backends, completes both proofs and
publishes full data. `OldOutstanding` additionally captures long job1
`(0,2,0)`, completes both proofs and publishes its original two-block data.
The actual sequence then ticks to1, lands job0 at checkpoint1, ticks to2,
finalizes source block1 and publishes its finalized anchor.

`FreshAbsent` explicitly removes history and both backend resources before
recovery. At time2 all programs execute M07 `Recover`: R=3, observation=4,
generation=1, origin/start/head/included/finalized=1, dependency=3,
finalizedBlock=3 and anchor `(generation=1,checkpoint=1,reference=3,cut=Cut(0,1))`.
The action preserves records, jobs, proofs, public data and resource availability.
It retains canonical height2's old suffix identity; only the next actual
`Produce` overwrites that height with `Cut(1,2)`. Retention is not a claim that
the discarded old suffix remains canonical in the new generation.

| Program          | Actual post-recovery actions                                                                                                      | Required outcome                                                                                                                                                                 |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FreshPresent`   | Produce new-generation height2; capture unused job1 `(1,2,4)`; publish full data; complete A/B; tick5; land                       | Fresh task binds dependency3 and cuts `[Cut(0,1),Cut(1,2)]`; actual landing at5 advances c1 to2                                                                                  |
| `FreshAbsent`    | Same fresh capture/publication; attempt both completions while absent; explicitly restore history, A and B; complete; tick5; land | Both early completion attempts are actually disabled, absence persists, and later explicit arrivals permit the fresh landing                                                     |
| `OldOutstanding` | Produce new-generation height2; attempt the original long job's landing at4                                                       | Actual `ENABLED Land(1)` is false and no old landing occurs, despite live reference0, supported ancestry, matching frontier1, both original proofs, full two-unit data and head2 |

The last program's other prerequisites are audited as literal raw facts. Its
reference age is4 within window5; its cuts match retained checkpoint1; both
proofs still bind the original generation0 statement. This isolates generation
binding from expiry, ancestry, missing artifacts or `included > head` masking.
The old generation semantic control already exists in M07's
`progress-bad-generation.cfg`; F05 adds this specific nonzero-origin workload
and a shared source-fault obligation, not a newly discovered protocol defect.

## Actual receipts, audits and non-vacuity

Each script step records ordinal, action label, actual `ENABLED Do(label)`,
whether it executed, raw complete M07 `r` before/after and production counts.
Execution uses actual enabledness. A disabled attempt records unchanged base
state and advances only the companion cursor. Expected success/rejection is an
independently enumerated observation; it never guards execution or hides an
unexpectedly enabled old landing. The original stage stays0; M07's default
setup scheduler is not invoked.

The independent audits check exact receipt order/continuity, required enabledness,
ordinary landing/finality chronology, literal recovery origin and preserved
state, resource absence/arrival, literal fresh job statements/landing records,
and old-job premises plus actual landing outcomes. Full normal cases retain
M07's relevant original audits as well. A required disabled action fails
`RecoveryEnabledAudit` immediately.

The three named terminal witnesses require the actual final receipt, all new
audits, three produced events, one recovery, the ordinary and recovery finality
observations, exact final c/time/job and landing counts. They are not merely
cursor witnesses. A missing required recovery cannot earn a completed-script
receipt even if a safety-only search exhausts normally. These are selected
finite reachability checks, without fairness or temporal universal progress.

## Focused source-fault obligations

Four additive `proving-recovery-*` entries use the existing shared sensitivity
engine and private copies of unchanged M07. Original and actually restored
source must pass the declared focused normal workload; each mutant must violate
only its exact named audit. Old IDs and all old config bytes remain unchanged.

| Obligation                    | Exact perturbation                                          | Required mutant failure                                          |
| ----------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| `proving-recovery-origin`     | Recover writes start0 instead of the actual included origin | `RecoveryOriginAudit`                                            |
| `proving-recovery-resources`  | Recover fabricates history and both backend resources       | `RecoveryResourceAudit`                                          |
| `proving-recovery-generation` | Ready omits its generation conjunct                         | `RecoveryGenerationAudit`, after the actual old landing executes |
| `proving-recovery-enabled`    | Recover gets a FALSE guard                                  | `RecoveryEnabledAudit` at the required recovery step             |

Each focused config enables `PipelineTypeOK` and its target audit. This prevents
older generic audits or the expected-enabledness audit from masking a different
intended failure; full normal configs retain the complete checks. These are
verification sensitivity controls, not four protocol bugs. The ten new configs
use the existing `MODULE: EtnaProvingRecovery` mechanism without runner/API edits.
Actual frozen runs, source restoration and independent review are reported by
the task owner; earlier prep prototypes are not final evidence.

This companion establishes no actual proof, complete recovery implementation,
resource fairness, finality/latency SLA, sustained capacity, full protocol
composition or universal ability to recover. No sixth increment follows.
