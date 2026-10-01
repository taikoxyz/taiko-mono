# Work orders

Agent A directs the convergence (decision D11): it assigns every task, sets the order and the due cycle, and records the outcome. A task is done when its pull request against `etna/converged-spec` carries the reviewer's explicit verdict and J's review, and the arbiter has merged it. Each agent's human relays the agent's orders to it; an agent that cannot do a task says so on #22191 instead of staying silent.

Status: open, in progress, review, done. Updated by the arbiter only.

## Cycle 1 (current)

| # | Owner | Task | Deliverable | Status |
|---|---|---|---|---|
| W1 | B | Revise C1 per A's verdict on #22195 (six blocking items, four non-blocking), then ping A and J on the PR. | #22195 updated | open |
| W2 | J | Re-check the restated decomposition rows at `b311d1d` (D10): does the stall revision close R6H-1; do A's anchor-free rules match B's C1 draft. Post on #22191. | comment on #22191 | open |
| W3 | J | Review #22195 (C1) as the third voice: blocking only for a Critical or High finding. | comment on #22195 | open |
| W4 | A | Draft C2 (landing) and S2 (certificates and handoff), verified, as two PRs against the branch. | two PRs | review: C2 and S2 opened, B's verdict (W8) and J's review (W9) pending |
| W5 | B | Draft C4 (migration: the complete retained-surface change table per DL-4; the requeue versus the proof-backed drain argued per DL-3 with A's rule as input). | PR | open, after W1 |
| W6 | B | Draft the C6 dashboard and the unmeasured-numbers register, indexing every section's register by id. | PR | open, after W5 |
| W7 | A | Draft C3 (forced inclusion, base per DL-2 and W2), C5, C7 (the validity predicate), C8 (interfaces, storage, messages, upgrade paths), S1, S3, S4, and the C6 threat-model half. | PRs, one per section | open, after W4 |
| W8 | B | Review every A section PR adversarially with an explicit verdict within one cycle of its opening. | review comments | standing |
| W9 | J | Review every section PR as the third voice; give the verdict on each contested decision when the arbiter asks; audit the readiness checklist at the end of cycle 2. | comments | standing |

## Cycle 2

Red-team rounds on the merged specification: A and B run the three attack goals in alternation on different models, J judges; two consecutive rounds with no new Critical or High, then the readiness checklist (W9).
