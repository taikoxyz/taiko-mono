# Current review corrections

Reviewed baseline: PR #22292 at `259e142364cbdcb60de116c6930a05e131ab9606`.
Authority: `1135c9b24fd03f50cb48eab250879435fd54f528`. The entire Etna directory,
including its rules subtree, has identical Git object IDs at the subsequently checked
main commit `4bcd0b45a46f6bcfcfd7de2c888033b0c80b9e3f`.

Most feedback identifies real weaknesses in the formal model, exported claims or evidence
mapping. The corrections below change the formal package and its documentation; they do
not change production contracts, clients or guests. No new Etna design defect was
confirmed. Remaining refinement and acceptance gaps are explicit deferred obligations.

## Critical: nonvacuous current premises

C1 is substantiated. A number-only reference identifier did not distinguish closed L1
histories with different Inbox balances. Together with globally quantified verifier
soundness, that allowed the primitive assumptions to rule out the intended accepting
executions when roots actually reflected financial state. Finite constant-root fixtures
did not establish satisfiability.

The reference now commits to the complete closed L1 prefix, with an explicit primitive
reference-binding condition. A forced ETH transfer before that reference changes the
commitment; a transfer after it leaves the committed prefix intact. Verifier soundness
still quantifies over all reachable Worlds and returns the accepted image's batch
certificate. It is not replaced by a per-World acceptance oracle.

`EtnaWitnesses/NonVacuity/Current.lean` constructs all thirteen current primitive premises
together. `premises_satisfiable` and `accepting_deployment` exhibit a real registered/funded
bond, nonzero FI fees, a reachable accepted landing and strictly advancing FI head. The
full decoded Snapshot state-root encoding is globally injective, including Inbox balance;
finite relabeling only makes its evaluation tractable and preserves injectivity.
The verifier accepts image 11 and two fixed statement templates. Global soundness derives
each template's context from the bound prefix and closed-machine invariants.

The same environment proves rejection after a pre-reference forced transfer, acceptance
after a post-reference transfer, rollback followed by another accepted landing, and an
actual successful landing followed by recovery and a generation-1 accepted landing
(`accepting_after_recovery`). This is a restricted new-network interpretation. It does
not realize arbitrary guests, production cryptography/EL or a switching deployment.
The audit now requires the accepting existential even if someone deletes its manifest row.

## Important feedback

| Review item                                   | Disposition and evidence                                                                                                                                                                                                                                                                                                                         | Remaining boundary                                                                                                                                                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1. Per-signal paths were not one chain        | Valid. H1 now exports `Custody.Coherent`: one header map, a literal retained parent chain, authenticated root and every signal's association with a retained record. Separate lifecycle theorems prove one-shot origin and permanent start freezing after landing. Stale-signal, reused-origin and post-landing correction mutants are rejected. | An individually redundant guard need not be used syntactically by an invariant proof. Legacy Unzen signals have separate authentication, not an asserted common Etna ancestor.                                     |
| 2. Weak exported Unzen root                   | Valid contract-strength gap. `FirstFence` retains the stored S/header match, finalized-proposal arithmetic, finalized hash/root, authenticated Unzen header and guest implementation check from the actual accepted first landing.                                                                                                               | Pre-fork Unzen cutoff validity is an upstream primitive refinement. This does not prove SWITCH margin arithmetic, originWriter duties or the whole switch procedure.                                               |
| 3. Accountability without backed stake/window | Valid. H2 derives issued-bond provenance, historical funded stake, reserve backing, funded remaining liability, no false slash and evidence-window retention from raw genesis, actual calls and primitive token/signature semantics. It also exports temporal agreement at an actual common closed cutoff within one generation.                 | It does not assert that legitimately withdrawn, expired historical stake remains escrowed forever. Complete SYNC-9-3 forkchoice/exit-coverage refinement remains deferred.                                         |
| 4. Early skip omitted by headline             | Valid. H3 uses `TimelyByteAction`; skipping requires due, while early consumption requires position-zero inclusion. A mutation removing the actual due guard is rejected.                                                                                                                                                                        | No liveness claim follows from conditional service on accepted landings.                                                                                                                                           |
| 5. Position zero and singleton adapters       | Valid. A block now carries the complete decoded transaction list; `first` must equal its head and the selected payload adapter receives the entire list. Missing-middle-image support is exercised across three rulesets.                                                                                                                        | Canonical raw EIP-2718/body parsing and full-budget singleton EL execution remain interpreter refinements. FI-7.2-10 is not advertised as proved by a constant fixture adapter.                                    |
| 6. Inflated traceability                      | Valid. Each rule now has an explicit reviewed theorem edge; shared clauses/modules infer no neighboring coverage. Supporting guards are separate from derived partial properties. Generic list/encoding helpers have no protocol evidence edges. `imageRules` is consumed by the actual accepted-image certificate.                              | The map exposes narrow conclusions only. Current inventory: 33 rule/partial, 27 rule/supporting, 543 rule/deferred; 32 assumption/limitation rows are deferred. No entire-rule verification percentage is claimed. |
| 7. Overstated README/report                   | Valid. Current documentation distinguishes global accepting witnesses, finite fixtures, conditional decoded safety, historical reports and production gaps. Successful landing before and after recovery now has a shared-premise witness.                                                                                                       | All 93 current ANCHORLESS and 45 ACCEPTANCE clauses remain deferred; SWITCH has eight narrowly sourced first-fence/root clauses.                                                                                   |

The originally cited wrong/missing rule edges were re-reviewed individually. Assumptions
do not count as derived consensus properties; generic slash-existence results do not cover
top-up/withdrawal policies; the uninitialized rule is not credited to an initialized
antecedent; unrelated proof/frontier rules do not inherit a whole-module source list.
The report records only actual theorem conclusions, including narrowly separated LAND
suffix/frontier evidence. It does not cover all LAND rules.

The independent final map review also removed custody-to-withdrawal and agreement-to-commit-
validation credits. Recovery pending-index evidence now points to sorted-list/range rules,
stop clearing to its actual stop rule, and forfeiture payment intent to the sink/no-bounty
rule. Import failure, signer preservation, numeric header range and operational availability
are separate rows; availability and independent execution remain deferred. These are
reviewed semantic corrections: schema validation alone cannot determine whether a theorem
actually proves a clause fragment.

## Earlier seven items

1. **Ruleset coverage:** per-block ruleset selection and actual-image support are now
   explicit. Three selected rulesets and a missing middle definition are exercised.
   The generic list-coverage lemma no longer supplies a protocol edge by itself.
2. **START-10-5c:** current lifecycle evidence and rejection/mutation fixtures replace
   reliance on the historical `Start.correct` example. Reachable post-landing start
   freezing is an H1 conclusion.
3. **Admission mutations:** exact nonzero fee, refund, state/accounting and failure
   contracts reject underpayment and failed-refund guard mutations.
4. **Import range/readiness:** import now closes readiness/trust, preserves signing
   anti-double-sign state and checks the complete original-generation number interval
   against the actual current origin. Actual header contents, indexes and stock stores
   remain an explicit SPEC 5.4 abstraction gap.
5. **Historical presentation:** every historical report has an entry banner; current
   README and CI comments identify the current/historical split.
6. **Rule links:** schema 2 requires exact reviewed rule/theorem/source matches and
   rejects shared-clause leakage, historical/unknown edges and plumbing evidence.
7. **Aligned versus verified:** the 251-clause concern is correct: SWITCH 113 +
   ANCHORLESS 93 + ACCEPTANCE 45. The README lists deferred operational, bridge,
   deployment and acceptance scope instead of implying complete verification.

## Minor feedback

| Review item                                 | Disposition                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Positive forced fee                         | Valid; required at initialization, with nonzero-payment fixtures and a guard mutant.                                                                                                                                                                                                                            |
| Slash sink                                  | Nonzero/binding checks added. The proposed `sink != registry` restriction is not required by PARAM-11-11 and was not invented; backing handles self-transfers.                                                                                                                                                  |
| Solvency                                    | Reserve/principal conservation and standard-token backing are derived from empty genesis and actual transactions. Initial zero registry self-allowance is an explicit raw premise: otherwise self-deposit can inflate principal without incoming cash. Future solvency is no longer an open funding antecedent. |
| One-way signatures                          | Added the reverse raw signature-soundness refinement and derived no-false-slash theorem. A key with no authentic conflicting pair cannot be successfully slashed.                                                                                                                                               |
| Agreement through time/same-block snapshots | Added closed registry-prefix preservation and temporal committee/commit agreement. The decision cutoff must actually be closed; an in-progress recovery block is not treated as finalized history.                                                                                                              |
| H3 head only `<=`                           | Kept for arbitrary nonlanding calls because rollback can rewind head. Accepted-landing service separately proves the exact consumed interval and cursor actions.                                                                                                                                                |
| Recovery membership guard                   | H3 now exports sorted clear indices and each index's `[head,tail)` bounds and pending status, in addition to exact queue transformation.                                                                                                                                                                        |
| Guest timestamp requirement                 | Removed from `Certifies`. The guest retains the required implementation check; pre-fork cutoff validity is distinguished as an upstream Unzen refinement.                                                                                                                                                       |
| Legacy signals                              | H1 now includes their separate decoded Unzen authentication theorem. No common Etna ancestor is inferred for pre-Etna signals.                                                                                                                                                                                  |
| Arbitrary rollback snapshot                 | Checkpoint writers save the associated committee snapshot; rollback requires that pair. A provenance theorem traces each pair to an actual reachable accepted writer. Arbitrary snapshot rejection was reproduced before repair.                                                                                |
| 48-bit/256-bit scheduling guard             | Not a behavioral defect: representable scheduled time and the lower deadline already imply the sum fits 48 bits. The different stop-cancellation arithmetic is tested separately.                                                                                                                               |
| Unused induction hypothesis                 | Not a proof defect: each successful call checks all resulting fields, so `trace_fields_fit` does not require its IH.                                                                                                                                                                                            |
| Namespace-only isolation                    | Historical theorem objects remain separately pinned, exact current types/roles and library placement are audited, and all shadow pairs require explicit reviewed reasons. This is not a production implementation boundary.                                                                                     |
| Late CI pin check                           | Authority/rule pins are now checked before the expensive Lean installation/build.                                                                                                                                                                                                                               |

An additional implementation-review correction removed an unsupported `minStake > 0`
guard: the spec permits a zero minimum, while strict slot admission still requires a
positive paid registration. This corrects the model, not the Etna design.

## Validation

The final-tree validation results are recorded in [latest alignment](latest-design-alignment.md).
The independent final C1 review found no correctness issue in the two-template global
soundness or post-recovery accepting trace; it caught a stale singular-template description,
which was corrected. Independent review is supplementary to exact kernel/type/axiom checks.
Independent H2/H3 reviews found no remaining formal correctness defect in their scoped
contracts and confirmed the stated funding, time, parser and store boundaries. Their
source-map findings were corrected before the final audit and 504-test green run.
