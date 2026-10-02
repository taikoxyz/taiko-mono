# Work orders

Agent A directs the convergence (decision D11): it assigns every task, sets the order and the due cycle, and records the outcome. A task is done when its pull request against `etna/converged-spec` carries the reviewer's explicit verdict and J's review, and the arbiter has merged it. Each agent's human relays the agent's orders to it; an agent that cannot do a task says so on #22191 instead of staying silent.

Status: open, in progress, review, done. Updated by the arbiter only.

## Cycle 1 (current)

| # | Owner | Task | Deliverable | Status |
|---|---|---|---|---|
| W1 | B | Revise C1 per A's verdict on #22195 (six blocking items, four non-blocking) and J's review (J-1 High, J-2 Medium), adopt C2-R21's epoch key into C1-R06 and C1-R10 (#22196 at `4ee1dd6`), merge the moved base in, then ping A and J on the PR. | #22195 updated | revision at `75616d5` reviewed by A (request changes, close: four blocking items, comment 5933727702); second revision owed, including the re-merge of D14 to D18 |
| W2 | J | Re-check the restated decomposition rows at `b311d1d` (D10): does the stall revision close R6H-1; do A's anchor-free rules match B's C1 draft. Post on #22191. | comment on #22191 | done: D10 discharged, DL-2 resolved to A's stall revision as the C3 base (D12) |
| W3 | J | Review #22195 (C1) as the third voice: blocking only for a Critical or High finding. | comment on #22195 | done: J's J-1 and J-2 closed at `75616d5` (comment 5933724570); A's second verdict pending B's next revision |
| W4 | A | Draft C2 (landing) and S2 (certificates and handoff), verified, as two PRs against the branch. | two PRs | review: C2 revised at `f67d4d4` (B's four Mediums, D15, D17, the rollback residual), B's re-verdict and J's re-check owed; S2 revision under D16 in progress |
| W5 | B | Submitted: #22205 at `451de65`, J cleared it; A's verdict owed (W15). Draft C4 (migration: the complete retained-surface change table per DL-4; the requeue versus the proof-backed drain argued per DL-3 with A's rule as input). | PR | open, after W1 |
| W6 | B | Draft the C6 dashboard and the unmeasured-numbers register, indexing every section's register by id (the index defines nothing, D12); submitted #22206 at `6a03ac0`, J cleared it, A's verdict owed (W15); carry L-PF with its restart cost, the D1 discharge scoped to the equivocation route (S2-R18), the per-term recording cost, the walk-gas figures each with their source and the quantity to measure (J on #22201), V_term and the fee and MEV inputs of B_SEAT each with their closure test (J on #22202), and the no-committee launch case beside the launch condition (J on #22201) in the accepted-limitations register. | PR | open, after W5 |
| W7 | A | Draft C3 (forced inclusion, base A's stall revision per D12, carrying J's accepted Medium with its numbers and the reveal's shape), C5, C7 (the validity predicate), C8 (interfaces, storage, messages, upgrade paths), S1, S3, S4, and the C6 threat-model half. | PRs, one per section | review: C7 #22199, C3 #22200, S1 #22201, S3 #22202 opened, each verified before opening; D14 applied (C7 `fa854f3`, C3 `13d0e11`); J's Mediums applied on S1 (`6751cb3`) and S3 (`181acf0`); B's W8 on C7 requests changes (D17, revision in progress on C7 and C3); B's W8 on C3 requests changes (D18, revision queued after D17); J cleared C7 (`fa854f3`) and C3 (`13d0e11`) after D14; B's W8 on S1 and S3 request changes (D19, D20, revisions in progress); C5, C8, S4 and the C6 threat-model half drafting |
| W8 | B | Review every A section PR adversarially with an explicit verdict within one cycle of its opening. | review comments | standing |
| W9 | J | Review every section PR as the third voice; give the verdict on each contested decision when the arbiter asks; audit the readiness checklist at the end of cycle 2. | comments | standing |

| W10 | A | Follow-up revision of C2 and S2 for the obligations the new sections place on them (C2 §12 reward constants quoted from S3; S3's self-landing exclusion against C2-R16; S2 §5's hold expiry revised to drop without verdict per D14; C2-R16's attester-share exclusion per D15), after B's verdicts on #22196 and #22197. | pushes to the two PRs | open |

| W11 | B | Now: attack the arbiter's decisions D21, D22 and D23 (DECISIONS.md) before the revisions land: for each rule they introduce, a counterexample or "holds". Post on #22191. | comment on #22191 | open |
| W12 | B | W8 on A's new sections: C5 #22209, C8 #22210, S4 #22211, C6 A-half #22212; then re-verdicts on C2, S2, C7, C3, S1 and S3 at the heads the recovery pass will cite. | comments | open |
| W13 | B | Cross-section consistency sweep over all fourteen sections at their current heads (C1 to C8, S1 to S4, C4 #22205, C6-B #22206): every rule stated in two places, every number quoted with two values, every dangling rule id, with the owning section for each. One list on #22191. | comment on #22191 | open |
| W14 | B | Apply A's one required C1 change (comment 5944641725, NB2: `__paused != _TRUE`) and ping; the arbiter then merges #22195 (D24). | #22195 updated | open |
| W15 | A | Recovery pass: D21 on S2, D22 on C7 and C3, D18 on C3, D23 on C2, finish D19 on S1 and D20 on S3; verify; push with heads cited. Review C4 #22205 and C6-B #22206 and arbitrate P-B-C4-01 to 04. | pushes; verdicts | recovery in progress; C4 reviewed (request changes, comment 5944782665, arbitration D25); C6-B reviewed (request changes, comment 5944784586) |
| W16 | B | Revise C4 #22205 per D25 and comment 5944782665 (four blocking items), and C6-B #22206 per comment 5944784586 (three blocking items); ping each. | pushes | open |

J is unreachable (reported by the user, 2026-10-02): W2, W3 and W9 items are queued per head; merges proceed under D24.

## Cycle 2

Red-team rounds on the merged specification: A and B run the three attack goals in alternation on different models, J judges; two consecutive rounds with no new Critical or High, then the readiness checklist (W9).
