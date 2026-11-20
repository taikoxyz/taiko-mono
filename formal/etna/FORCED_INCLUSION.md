# M06: bounded forced inclusion and settlement composition

`EtnaForcedInclusion.tla` extends the actual `EtnaSettlement` module without
changing it. Its wrappers call the existing `Land`, `Recover`, `PrepareProof`,
`Authorize`, `InvalidateNonce` and `Tick` actions. `FINext` contains only wrapped
branches; raw base `Next`/`LandFresh` cannot bypass FI updates. This composes the
bounded settlement transaction-ordering model with FI state. It does not compose
the complete checkpoint-identity, committee, signer or application models.

Source: Etna SPEC at `d18357214fab30ea512ae9858a11699806d72ba1`, sections
7.1–7.3, LAND/PROOF 6.1/6.2 and RECOV-8-43..58. No production implementation or
protocol source is changed.

## Distinct state and rule mapping

| State/action                                                   | Meaning / source                                                                                                          |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Base `c`                                                       | Settled **L2 height**, not an FI cursor                                                                                   |
| `fi.tail`, live `fi.queue`, `fi.head`                          | L1 admission tail, entry records and landed FI head; FI-7.1 / 7.2-1                                                       |
| `fi.anchors[a]`                                                | Immutable end-of-L1-block head/tail/entry snapshot; FI-7.2-2/3                                                            |
| `fi.frontier`, `fi.cursor`, per-generation cuts                | Produced L2 frontier and local FI progress, including unsettled progress                                                  |
| Every immutable produced block and independent raw observation | Before/after cursor, actual historical anchor, storage witness, body positions and needed singleton context; FI-7.2-1..13 |
| `fi.landedCuts[h]`                                             | Retained checkpoint FI cursor, reused at a new generation's origin                                                        |
| By-value `fi.queued`                                           | FI cuts captured with the base delayed proof, not reread from a later live cursor                                         |
| `FILand`                                                       | Base actual-parent landing plus origin/interior/terminal FI cut checks and suffix-only progress                           |
| `FIRecover`                                                    | Base authenticated recovery plus hash-only blanking in `[head,tail)`, retained cursor, new-generation anchor floor        |
| Admission cash observations                                    | Actual pre-enqueue L1 head/tail and collected fee; inclusion/blank/replay do not charge/refund again                      |

`FITick` closes the old block's complete queue state, then calls the base time
advance. L1 block index is the base `now`; its separate fixture timestamp is
`10 + 2*index`, and forced-inclusion delay is 2 timestamp units. The authorization
clock remains the base normalized tick clock. L2 heights are independent. This
mapping is a fixed increasing small clock fixture, not Ethereum timing or a
wall-clock service claim. Only closed anchors (`a < now`) are available; anchors
cannot regress within a produced generation, and after recovery are at least R.

The current actual parent identity is tracked separately from chain generation.
The first new-generation block uses the retained old-generation parent at c.
An independent predecessor/origin rule checks both its parent and pre-block FI
cursor. Old-generation produced records remain immutable observations when
recovery discards their unsettled suffix.

## Transaction and EL projection

There are four raw fixtures: `A` is canonical and executes; `B` is canonical and
is included with an ordinary EVM revert; `Empty` is canonical but its full-budget
singleton build is empty; `Bad` is ineligible. `Nil` represents actual empty
bytes/hash after blanking, while `Absent` means missing fetched material.
`Replacement` represents another canonical transaction with the same sender and
nonce, and `Ord` ordinary unrelated body content. Tokens assume injective hashes;
there is no actual transaction decoding, EVM execution, zk metering or cryptography.

A completed result is a deterministic table of raw token, actual parent and
budget. Infrastructure status is separate: `Transient` is not an empty result;
`Pruned` creates a safety halt. Only `RestoreParent` clears that halt. Recovery
preserves it even if it rewinds to an older parent that could already be
available: this is an explicit conservative single-participant/manual-restoration
projection, not a claim that every newly selected validator lacks the state.
Restoration/restart mechanics and consensus-message scheduling are not modeled.

Every produced block is observed, including delta-zero blocks. The independent
oracle requires the head entry's storage witness whenever the anchor tail exceeds
the pre-block cursor, even before due. Only an exact canonical body transaction
at position 0 counts as inclusion. Position 1, a sender/nonce replacement and an
absent/zk-aborted transaction cannot count. A due visible entry must be included
or legally skipped; absence of a successful consume record cannot hide ordinary
blocks that improperly postpone it. An eligible skip requires the completed empty
singleton on the actual committed parent with full EVM and zk budgets.

Before due, missing raw material permits ordinary progress without consumption.
After due it does not create a skip result. Availability outcomes are environment
choices, not eventual-progress guarantees. A valid complete STF/body and valid
proofs are interfaces/premises; the model does not prove them from transaction
bytes or execute the VM.

A blanked entry automatically has known empty raw bytes. This is independent of
an internal candidate-body mode. The original raw transaction may still appear
as an ordinary transaction: at due time the blank entry can legally skip while
that transaction is in the body. No protocol-visible Include/Skip reason is
invented. The stale-hash negative trace instead advances a **pre-due** blank entry
with the old raw body, which is unambiguously invalid.

## Finite workloads and observation projections

All default cases use L2 height 2, one recovery, nonce bound 2, time bound 2 and
two queue entries. `MaxProduces=2` bounds the total number of externally requested
produced blocks **across generations**. Its separate workload counter wraps
`Produce`; it is not a protocol acceptance condition or an observation enabling
action. Candidate singleton queries are limited to that same finite production
workload. This covers two-block overlap and one-old-plus-one-new recovery, not
two complete two-block generations.

All selected wrapped action types remain in `AllFIActions`, including every
in-range authorization deadline, nonce invalidation, time, recovery, builds and
restoration. Source-valid executed prefixes make the default normal workloads
exhaustive; every intermediate prefix state is checked:

| Normal profile    | Actual setup prefix, then all selected actions                                                                                                                                               |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fi-mixed`        | Enqueue A/Bad in block 0; close blocks 0/1; include A at anchor 1. The remaining due ineligible entry, proofs and landing remain variable.                                                   |
| `fi-empty-revert` | Enqueue Empty/B in block 0; close blocks 0/1; observe transient then complete singleton on the same parent; legally skip Empty. Remaining B inclusion/revert and settlement remain variable. |
| `fi-fee-lag`      | Enqueue A at 0; close block 0; include A before due; enqueue B at block 1 while local cursor is 1 and L1 head remains 0. All later wrapped actions remain variable.                          |

The first two prefixes use the time budget and one production call; they cannot
publish a recovery anchor after a later recovery. The fee-lag profile ends at
block 1 and retains a time step, so new-generation root/blanking/production and
old-proof rejection are explored there. Full queues make later enqueue unavailable
in these profiles; both actual admission calls still execute in the prefixes.
Fee-lag admission must charge `1 + tail - L1head`, not `1 + tail - L2cursor`.
Currency, fee and threshold are normalized to 1. Sweeping/treasury failure,
overpayment refunds, force-sent ETH and numeric overflow are outside this model.

Two observation-only reductions avoid irrelevant history products. Produced block
records contain `EmptyBuild` when literal anchor/body predicates show no due
eligible non-inclusion decision needs singleton context; otherwise the actual
complete/transient/context record is preserved. This criterion does not call the
operational inclusion helper or a mutant switch. The live build cache and guards
are unchanged. The retry observer retains only the latest transient context and
an accumulated reached flag, sufficient for a genuine existential retry witness;
it is not a complete infrastructure-error history. Neither observer enables work.

## Validation and incomplete products

Normal assertions cover every block's FIFO predecessor/cut relation, raw historical
anchor equality, mandatory witness/due handling, position 0 and singleton context,
actual retained landing cursors, once-only suffix application, recovery preservation,
admission cash/identity, and new-generation anchor binding. Eleven deliberate
controls must fail exact invariants: shifted pre-cursor, forged closed anchor,
due omission, body position 1, timeout-as-empty, wrong parent, reduced budget,
stale pre-due blank hash, corrupted cursor write, replayed landing prefix and
L2-based admission fees. Six negated witnesses certify early inclusion, new-generation
blank skipping, eligible complete-empty skip, included revert, transient retry and
overlapping delayed landing. Existence is not liveness.

Broader raw-initialization and admission-prefix products exceeded 45-second limits,
including versions with the total production budget and observation projections.
They remain **INCONCLUSIVE**. Exact module/configuration snapshots, the unchanged
base dependency and observed intermediate progress are preserved outside the
default suite in `experiments/fi-*`; none is counted as a passing default case.
The exhausted prefix workloads are not claimed equivalent to these wider products.

This model proves no unconditional FI deadline or whole-protocol correctness.
Progress depends on consensus, advancing finalized anchors/time, available logs,
restorable historical state, proving resources and successful settlement. Atomic
calls, correct finalized headers/storage proofs, exact domain/configuration
binding, successful STF/proofs and ordinary recovery list authority are premises.
Verifier-failure rollback, registry/committee correctness, full EL/Comet cut hashes,
blob availability, larger loads and unbounded arithmetic are outside this increment.

The implementer ran the complete 20-case matrix on module SHA-256
`5f3e91f14e137449d04333174c1bf684001650273f5b41baa9f47aac629a8718`. All exact expectations passed: three normal exhaustive profiles, eleven
controls and six witnesses. Normal profiles finished with queue zero; controls and
witnesses exited 12 at their declared invariant.

| Normal profile    | Generated | Distinct | Final queue |
| ----------------- | --------: | -------: | ----------: |
| `fi-empty-revert` |    18,054 |    5,395 |           0 |
| `fi-fee-lag`      |   184,181 |   58,270 |           0 |
| `fi-mixed`        |     2,928 |    1,151 |           0 |

Independent review/verification and repository regression results are recorded
by the task owner in the main report before integration.
