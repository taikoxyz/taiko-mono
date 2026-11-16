# Etna: five increments after the self-check retrospective

The user authorized five further increments, then a report, on the existing
verification branch and draft PR22387. Start at56fc86d482c116df313aabc94ed87c53b537ce08.
Keep hourly feedback-first checks. No sixth increment, production/normative
change, merge, deployment or Notion write is authorized by this plan.

## Why the previous self-check missed defects

Internal consistency was mistaken for sufficient source correspondence. The
constructor and observer could agree on an invalid positive premise; mutation
checks exercised only the existing input domain; recorder success could refer
to the wrong failure reason. More repetitions do not add a missing property.
Use independent literal premise audits, required actual reachability, exact
fault semantics and selected upstream execution before strengthening claims.

## Sources and method

SPEC d18357214fab30ea512ae9858a11699806d72ba1, blob
649548c58d6629dd85143b33efd3644a3bb71509. Current main's SPEC blob was read back
identical before this batch. Contract pin89f419915de4b73bb57c53bf970f6dea9e8e8c8c;
CometBFT0.40.0 commit0880b4d378f347ab16e54ec677ff50d803f37d62. Reuse the existing
configured Python, Java17/TLA+ tools1.7.4(TLC2.19), Go SDK and physical caches.
Public dependency preparation is separate from offline read-only execution.
Never use keys/signing material. Pinned source copies remain unmodified.

Retain all350 prior main config bytes, old conformance payloads/pins and archived
incomplete experiments. M10 changes in F01/F02 are explicit reviewed changes;
their old source hashes/results become historical. Operational authentication
guards remain unchanged in F01/F02. Other original models remain unchanged.
Each increment gets independent source review and behavioral verification;
maximum two material fix waves. A supported actual protocol defect stops work
for discussion; verification-model/tool defects are repaired separately.

## F01 — audit positive checkpoint-import chronology

Reproduce the apparent invalid positive M10 fixture before repair: non-origin
header4 has time40 although generation1's genesis time is100. Stock Comet requires
the first block at height3 to use100 and later block times to increase. Observe
the actual published boundary, rather than merely checking a fixture constant.
Keep origin2's old-generation retained header separate from new-generation genesis.

The same premise audit checks stock genesis proposer initialization. With powers
3/2, NewValidatorSet stores proposer1 with priorities[-2,2]; the next increment
stores proposer2 with[1,-1]. Genesis must not inherit a landed fixture's values.
Independently compare both
genesis sets, app recorded state and selected stores to these literal source facts.

If confirmed, correct the non-origin fixture to102 and its independent literal
store expectation. Add an independent publication-premise audit, origin/non-origin
profiles and required successful reachability. An exact source fault restoring40
must fail the new audit. A second source fault restoring only the wrong origin
first proposer must also fail, despite the old shared observer agreeing with it.
State these necessary initialization/timestamp premises separately from
full STF/window validity; do not retrofit a new protocol timestamp guard.

F01 is reopened before F03 freezing for an additional confirmed necessary
priority premise. Both committed future validator sets are post-increment. For
two members, rescaling bounds the pre-step difference by2V and a priority step
gives an absolute difference at most V+|power1-power2|. Raw11's[7,-7] at powers3/2
violates6; Raw20's[6,-6] at2/4 violates8. Replace only these priority tuples with
individually stock-generated alternatives[-1,1]/proposer1 and[-2,2]/proposer2. Extend
the independent publication audit with these selected necessary bounds and add
two exact source faults restoring the invalid tuples. This is an explicit
exception to old Raw11/20 byte preservation, with actual published counterexamples
and source/Go evidence; all other raw cases and old config bytes remain unchanged.
It is a repair within F01, not a sixth increment or a full prehistory proof.

The final F01 fix wave checks the joint pair as well. Actual genesis plus two
stock updateState calls show the current/next sets are coupled: Validators copies
the prior NextValidators, while NextValidators applies the current updates and
one increment to that same set. Independently reachable sets can still form an
impossible pair. Use the selected actual two-block-prefix outputs below, indexed
by their public symbolic key identities; do not recompute stored proposer by argmax.

| Selected fixture | First powers; priorities; proposer | Second powers; priorities; proposer |
| ---------------- | ---------------------------------- | ----------------------------------- |
| Base             | 3,2; -1,1; 1                       | 2,4; 2,-1; 2                        |
| First alternate  | 3,5; 4,-4; 2                       | 2,4; -1,1; 2                        |
| Second alternate | 3,2; -1,1; 1                       | 3,4; 2,-2; 2                        |

First keys are1,2 and second keys2,3. The prefix uses only explicit public B/-B/2B
points and selected validator/parameter updates, with header3 time100 and header4
time102. Preserve exact floor-centering output, including base second priorities
whose sum is1. Decouple the fixed genesis literal, rebind positive raw commitments
consistently and retarget negative fixtures/source faults that would become no-ops.
Add a literal published-pair audit and a bounded-but-incoherent pair fault. This is
an explicit exception to the previous raw fixture preservation rule. The selected
prefix demonstrates validator-state correspondence; STF, execution, signatures,
full authenticated window and archive validity remain premises. The existing opaque
window token is retained and its selected concrete LastValidators mapping disclosed
by F04. No operational import guard is added or weakened.

## F02 — discriminate chain and height authentication

Append Raw28/29: change the non-origin peer header chain or height and rebind only
its L1 Comet commitment, leaving other commitments coherent. These deliberately
invalid classifier inputs must Reject, with no contradiction branch established.
They are not proof-valid authenticated landings. Healthy Raw0 accompanies each.
Remove each operational equality separately in a private copy and require an
exact Check/Classified false-Verified counterexample. Preserve Raw0..27 source
bytes as established by F01 and preserve the independent classifier.

## F03 — export actual checkpoint-import publication receipts

Export five actual M10 publication observations: origin Raw0/11 and non-origin
Raw0/11/20. Origin uses the new fixed genesis; non-origin preserves the distinct
landed first/second priorities and stored proposers. Capture raw L1/peer/origin
premises, actual complete selected EL/app/Comet/evidence stores, durability and
trust-at-publication. Include schema, source/tool provenance and exact IDs.

Python parses actual TLC values, never reconstructs the import transition.
The existing base parser is a provenance input to old fixtures and must remain
byte-identical. A minimal local subclass may add only signed-integer, bounded-range
and set tokens while inheriting its record/function/sequence grammar. Canonicalize
sets as sorted JSON arrays, preserve sequence order and compare fresh canonical
JSON bytes with exact scalar types, so bool/int equality cannot hide alterations.
Fresh comparison rejects missing/duplicate/altered receipts and provenance drift.
Independent literal audits and disabled-publication experiments must distinguish
missing progress from a green safety assertion. Do not claim a valid STF history,
full archive reconstruction or a concrete importer from these symbolic receipts.

## F04 — replay selected stock bootstrap/store semantics

Consume F03 receipts in a separate pinned Go test module. Exercise actual
state.Store.Bootstrap, Load, LoadValidators and LoadConsensusParams, and inspect
actual next-block construction where it does not require signing. Cover the
origin exception and non-origin Last/Validators/Next set positions, exact landed
priorities/proposers, InitialHeight, AppHash and change heights. Use only explicit
public points; symbolic hashes/keys have disclosed deterministic mappings.

Fresh in-memory databases and a reopened store wrapper provide stock serialization
readback, not power-loss durability. A private single-source bootstrap write fault
must fail its exact observer; original and actual restored source must pass.
Reuse existing source manifests, supervisor, isolation and canonical-layout checks.
Do not duplicate a runner framework or change the shared TLC/Forge engine API.
Any necessary shared helper change requires the existing seven-test native replay
and controller regression to be rerun. This is selected stock-store correspondence,
not an implemented Etna importer, verified commits/signatures or full consensus.

## F05 — nonzero settled recovery and proving resources

Add a small scripted companion calling unchanged M07 actions. Settle1, preserve
an unsettled suffix, authenticate ordinary finality, then use the existing trusted
completed-recovery macro at origin1. Separate programs cover resources preserved,
resources still absent then explicitly restored, and an outstanding old-generation
proof rejected even with a live reference and matching frontier. A fresh task uses
the remaining logical job slot in the first two programs; do not silently recycle
the model's once-used job IDs.

Use explicit bounded chronological inputs and raw pre/post audits. Require actual
terminal witnesses; exact source faults for wrong recovery origin, fabricated
resource availability and omitted generation binding must be detected. No new
acceptance engine, resource fairness, proof implementation, latency SLA or universal
recovery guarantee follows. The recovery macro's external authentication/finality
premise remains explicit.

## Final gate and publication

After exactly five increments, run one stable accumulated model/Python/shared-fault
gate plus affected actual-Go checks and fresh exports. Independently reclassify
raw logs and verify exact coverage, source/config/tool/mutant hashes and non-vacuity.
Retain unchanged old Solidity/export evidence as historical by byte identity;
rerun changed gates. Review the complete batch diff and report limits and any
withdrawn claims. Commit/push to the existing draft branch and read back exact
head/body/scope. Hourly monitoring continues; it does not authorize another batch.
