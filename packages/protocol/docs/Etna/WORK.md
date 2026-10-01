# Work orders

Agent A directs the convergence (decision D11): it assigns every task, sets the order and the due cycle, and records the outcome. A task is done when its pull request against `etna/converged-spec` carries the reviewer's explicit verdict and J's review, and the arbiter has merged it. Each agent's human relays the agent's orders to it; an agent that cannot do a task says so on #22191 instead of staying silent.

Status: open, in progress, review, done. Updated by the arbiter only.

## Cycle 1 (current)

| # | Owner | Task | Deliverable | Status |
|---|---|---|---|---|
| W1 | B | Revise C1 per A's verdict on #22195 (six blocking items, four non-blocking) and J's review (J-1 High, J-2 Medium), adopt C2-R21's epoch key into C1-R06 and C1-R10 (#22196 at `4ee1dd6`), merge the moved base in, then ping A and J on the PR. | #22195 updated | open |
| W2 | J | Re-check the restated decomposition rows at `b311d1d` (D10): does the stall revision close R6H-1; do A's anchor-free rules match B's C1 draft. Post on #22191. | comment on #22191 | done: D10 discharged, DL-2 resolved to A's stall revision as the C3 base (D12) |
| W3 | J | Review #22195 (C1) as the third voice: blocking only for a Critical or High finding. | comment on #22195 | done: request changes, one High (J-1, sharpening A's item 2: the conflict rule needs its consequence and a recovery, with C2's whole-range origin check as the obligation) and one Medium (J-2, the getter change on inherited records, for C4's table); carried into W1 |
| W4 | A | Draft C2 (landing) and S2 (certificates and handoff), verified, as two PRs against the branch. | two PRs | review: J cleared both after revision (C2 at `4ee1dd6`, S2 at `0403a54`: no Critical or High); B's verdict (W8) is the remaining gate on each |
| W5 | B | Draft C4 (migration: the complete retained-surface change table per DL-4; the requeue versus the proof-backed drain argued per DL-3 with A's rule as input). | PR | open, after W1 |
| W6 | B | Draft the C6 dashboard and the unmeasured-numbers register, indexing every section's register by id (the index defines nothing, D12); carry L-PF with its restart cost, the D1 discharge scoped to the equivocation route (S2-R18), the per-term recording cost, the walk-gas figures each with their source and the quantity to measure (J on #22201), V_term and the fee and MEV inputs of B_SEAT each with their closure test (J on #22202), and the no-committee launch case beside the launch condition (J on #22201) in the accepted-limitations register. | PR | open, after W5 |
| W7 | A | Draft C3 (forced inclusion, base A's stall revision per D12, carrying J's accepted Medium with its numbers and the reveal's shape), C5, C7 (the validity predicate), C8 (interfaces, storage, messages, upgrade paths), S1, S3, S4, and the C6 threat-model half. | PRs, one per section | review: C7 #22199, C3 #22200, S1 #22201, S3 #22202 opened, each verified before opening; J's C7 review (one High, D14) being applied across C7, C3 and C2; B's verdict (W8) and J's reviews of C3, S1, S3 pending; C5, C8, S4 and the C6 threat-model half drafting |
| W8 | B | Review every A section PR adversarially with an explicit verdict within one cycle of its opening. | review comments | standing |
| W9 | J | Review every section PR as the third voice; give the verdict on each contested decision when the arbiter asks; audit the readiness checklist at the end of cycle 2. | comments | standing |

| W10 | A | Follow-up revision of C2 and S2 for the obligations the new sections place on them (C2 §12 reward constants quoted from S3; S3's self-landing exclusion against C2-R16; S2 §5's hold expiry revised to drop without verdict per D14; C2-R16's attester-share exclusion per D15), after B's verdicts on #22196 and #22197. | pushes to the two PRs | open |

## Cycle 2

Red-team rounds on the merged specification: A and B run the three attack goals in alternation on different models, J judges; two consecutive rounds with no new Critical or High, then the readiness checklist (W9).
