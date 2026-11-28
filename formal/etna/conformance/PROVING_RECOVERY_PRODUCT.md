# Live proving, recovery, and the current settlement cut

This product uses the current Etna SPEC §§6 and 8, Appendix A ENC-A-29 through ENC-A-35, and ACCEPTANCE §1 item 5 at `2e6763e21bc236cfcda6011d164b32040f9e0c8d`. The historical M07 operational dependencies are in `EtnaProvingProgress.tla` (Produce through Recover). The overlap and generation-origin rules also occur in `EtnaSettlement.tla`. Those historical modules have different state and commitment types. The current model keeps its operational record, assertions and profiles in a separate namespace.

## Operational state and finite inputs

The Etna start is 6. Successive blocks have consecutive heights. Produce takes a candidate's published anchor, its generation, reference age, origin/parent monotonicity and two-block headroom into account. Capture freezes the complete locally produced interval from the retained origin p to h, the reference, generation, original blob hashes and statement. Real resources can arrive or disappear. Complete selects a source job for each target and backend. Publish can offer the entire original range or its remaining suffix. Neither loss of a resource nor recovery edits existing jobs, backend results or publications.

Land reads the current L1 generation, fixed generation origin, retained origin and checkpoint records, current FI head, clock, two proof bindings and the complete publication. It records actual c as the landing parent and applies only the newly settled heights. Ordinary L1 finalization chooses the highest recorded checkpoint at the end of a strictly past block. PublishAnchor makes that block available to a later Produce. Recovery is the **trusted completed macro**. Execution at R = now + 1 installs the fixed origin, retained checkpoint and recovery anchor. Bootstrap observes it at R + 1. The macro leaves the old canonical table beyond the reset live head, existing records, cached work, resources, and last landed committee snapshot intact. Fresh Produce replaces heights on the new branch. With no committee rotation, fresh capture binds R as the governing snapshot. Fresh Land writes R.

The state includes full original cuts at p through h. Its structural 21-word statement carries the ordered *interior* cuts in its range slot. Finite EL and Comet word representatives differ between generations. The genesis Comet hash is zero. The fixture consumes one FI entry per produced block, assumes an adequate queue tail, and uses one ordered versioned blob hash per block. The domain, deployment addresses, chain IDs, committee configuration, EL roots, canonical L1 references and guest-valid blocks are fixture inputs or finite representatives. The graph has no anchorless or validator-state proof input.

## Concrete byte projection

`current_settlement.py` encodes each raw Cut(height, EL, Comet, FI) in four standard static ABI words. It uses the existing legacy Keccak-256 implementation from `run_comet_apphash.py`. Each leaf covers one cut. The range commitment encodes the right-padded ETNA_LAND_CUTS_V1 tag, generation, p, h and the hash of the concatenated interior leaf hashes. A single-block interval has zero calldata leaves. For c > p, the current checkpoint occupies zero-based leaf index c − p − 1. The 21-word TAIKO_ETNA_LAND_V1 statement binds the supplied original data, endpoints, range, reference and authenticated committee snapshot. Capture validates the bounded lengths before materializing inputs and stores immutable copies. Land independently rebuilds the bound statement from the supplied complete original hashes and current origin. Its caller supplies the latest specific L1 checkpoint and FI cursor. Local head/fork data do not enter this interface.

Run `python -B proving_recovery.py CASE NATIVE_LOG --workspace-root WORKSPACE` to
emit a JSON receipt for the fixed `proof-progress-model/arbitrary-height-landing`
claim. The emitter reads the exact SPEC, ACCEPTANCE and SWITCH bytes in WORKSPACE,
requires the reviewed current bundle and records all three identities, the
selected scope, case, raw-log SHA-256 and verified transition count. The optional
`--expect-claim` asserts the expected claim ID. The receipt covers the observed
trace. Queue exhaustion, source restoration and engine status require their
separate native records.

The source-independent `audit(text, case)` decodes the ordered raw TLC frames for the live witnesses. It checks complete Init and adjacent frames, reconstructs each numeric milestone and verifies the named endpoint against the final state. It re-captures actual produced ranges with the byte implementation, assigns concrete statements from the source chosen by each observed backend result and uses actual publications on Land. At overlap, the suffix alone must fail, and a later successful Land must match the full actual record. On a stale-generation fault, ordinary byte Land must refuse. Rebinding only the generation on that PRE demonstrates that every other tested admission condition holds. Concrete coverage applies to the decoded synthetic inputs of the replayed traces. It does not establish binding for all possible byte inputs, authenticates no real block or KZG sidecar, and does not measure a guest or run an EL, verifier or contract.

## Profiles

The free graph starts from empty jobs, absent resources and the actual start checkpoint. At every state the scheduler offers independent operations. The main profile reserves slot 1 for generation 0 and slot 2 for generation 1 only at Capture. Both slots remain offered at Complete, Publish and Land in both generations. Capacity and independent variants are explicit.

| Profile | Height depth, produces, time, capacity | Scope |
| --- | --- | --- |
| smoke | 1, 1, 1, 1 | Small full-frame smoke |
| safety-small | 1, 2, 3, 1 | Free small two-generation safety |
| safety-full | 3, 5, 5, 2 | Free main two-generation graph |
| two-old-safety | 2, 2, 1, 2 | Two freely captured old jobs, clock too short for completed recovery |
| unit, late-capture | 1, 1, 1, 1 | Existence of a unit landing and positive-time late capture |
| recovery-c0 | 3, 5, 4, 2 | Cached old long job through recovery; fresh long capture, landing, finalization, published anchor and third production |
| recovery-c1 | 2, 3, 4, 1 | Settled old short record, discarded second block, fresh capture and replacement landing |
| two-old-overlap | 2, 2, 1, 2 | Old long and short from the same origin, interior frontier, suffix refusal, original transaction lands |
| old-authority | 2, 2, 2, 2 | Actual prepared old source remains offered and fully poised after recovery |
| fixed-safety, fixed-7/8/9, fixed-interior-long, fixed-last-short/long | 4, fixed transactions, 4, 4 | Unchanged long transaction and exact one-block competitors |

Existential profiles have freely interleaved, static subsets of the full offer alphabet. C0 offers old (6,8,0) and fresh (6,8,2); C1 offers old (6,7,0) and fresh (7,8,3); the overlap pair offers old (6,8,0) and (6,7,0). The stale guard profile uses the C0 capture arguments. These profiles offer matching backend sources and full publication, with suffix publication also offered in the overlap case. The source lists the small fixed anchor alphabet and only ordinary finalization block 3 in C0. Resources may arrive or disappear freely. The main safety profile offers any p,h in the declared height range at the current capture time, any available anchor, all target/backend/source combinations and past finality blocks. There is no simultaneous third job in any live profile.

The fixed companion assumes one immutable long range (6,10] and a book of immutable one-block alternatives under fixed complete proof/data availability and capacity. The long transaction retains reference 0 and all five cuts. The fixed branch has four-block headroom (U=4). Each exact one-block competitor uses a causal reference at the inclusion block of its just-settled parent, and the next frontier is tested in the following L1 block. Thus the original long reference stays readable even at the last interior. A successful shortest competitor strictly decreases 10 − c. Both individual offers and actual dispatched successors are checked for enabledness, using a bounded receipt containing the actual choice, immutable job, two backend inputs and publication, together with full landing frames. At c=9 both choices write the same checkpoint, so separate witnesses bind actual long and shortest offers and their distinct references. The interior-frontier witnesses are separate existence claims. No scheduling fairness or actual proving latency follows.

Native queue-zero exhaustion with successful exit establishes universal assertions only at the exhausted profile's bounds. A named invariant counterexample establishes existence only after checking its particular state frames. A timeout leaves that profile inconclusive. The W07 authorization/reset relation, full Q01/P02 end-to-end obligations, production implementations and deployment remain separate.
