# Review round 8 - frozen snapshot

**Snapshot:** `fb67df660` - **Rounds used:** 8 of 8 (the design owner has extended the budget; convergence still requires TWO consecutive clean rounds, so a clean round 8 will be confirmed by a round 9).

## State

Decision D-16 (Option A) is fully implemented: v1 ships the core and four mechanisms are deferred and tombstoned - narrow forced inclusion (FI-10..FI-14, CONS-01(v)), heartbeat eligibility (MEM-13, CONS-16), the governance stall resolution (GOV-04, REC-02..REC-04), and aggregation (PRF-15, L1-14).

**Round 7 closed 2 Critical, 10 High, 12 Medium, 6 Low.** Both Criticals were rollback fallout and both are repaired: the live slashable forced-inclusion offence in spec/07 is a tombstone, and the exit's unfunded proving obligation now has a payer (attestRewardPaid from the proving share via L1-11, best-effort, never gating) plus an honest restatement in MEM-15(2b) with its falsifier. The pool solvency defect (one inflow promised in every open epoch) is fixed by a free-balance/reservation decomposition with the exact identity pool_balance = free + sum(outstanding).

**Verified:** 161 rule ids, every id indexed, 0 broken links or anchors, 0 tag mismatches, register consistent in both directions, no live rule reads a tombstoned rule or parameter, and the course no longer teaches any deferred mechanism in the present tense.

## What round 8 must decide

This is the first review of the COMPLETE v1 core with no known Critical outstanding. It must answer: is the design, as written, implementable and sound; is every absence disclosed where a guarantee used to be promised; and does the artifact contain any remaining contradiction?