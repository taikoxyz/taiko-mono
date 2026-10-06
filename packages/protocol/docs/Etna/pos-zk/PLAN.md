# Plan to convergence, then to the add-ons and Phase B

Owner: design lead. Budget: generous (up to ~5 days). Nothing here stops for budget.

## Phase 1 - converge v1 (in progress)

1. **Round 8** on snapshot `fb67df660` (four reviewers, all committed material frozen).
2. **Adjudicate** every finding: accept, reject with evidence, or escalate. A finding already fixed during the round is recorded as such.
3. **Repair** what survives, then re-verify integrity (links, tags, rule index, register both directions).
4. **Round 9 - the confirmation round.** Convergence = two consecutive clean rounds, so a clean
   round 8 needs round 9 to confirm it. The original eight-round cap is treated as a budget the
   design owner has extended; rounds continue until two consecutive clean ones are recorded.
5. **Declare convergence** with the evidence: round numbers, counts, and the residual list.

## Phase 2 - revive the deferred mechanisms, one at a time

Each gets its own design pass and its own review round; none returns by reverting a tombstone.
Order is by value and by readiness, not by size.

1. **Heartbeat eligibility (D-14)** - simplest unlock. Its round-5 Critical (a heartbeat signature
   as a permanent credential) was fixed with the window-and-sequence payload; that fix has never
   been re-reviewed. Revive criteria: a review of the window-bound payload and a decision on the
   pre-signing horizon.
2. **Aggregation (D-13)** - gated on Phase B: n and m cannot be fixed before S1 measures the
   aggregation cost. Design work can proceed, parameterisation cannot.
3. **Narrow forced inclusion (D-12)** - four named blockers: one unit of account for the
   obligation, a mandatory frontier advance with no waiver, a void predicate computed from the
   record's immutable bytes and registered constants only, and expiry as an objective proof-side
   discharge ground. All four are specified in DEFERRED.md section 1.
4. **The governance stall resolution (D-15)** - last, because it was the newest and least
   reviewed. Its blockers: an entry state machine with an `executed` state, the resolved exit
   contradiction (already fixed for v1 by MEM-15(2b)), and a generation rule for the anchor
   certificate.

Reviving a mechanism must not reopen a v1 decision: the boundary, the exit, D-8/D-9, D-11 and the
"no rule removes weight" property (D-14) stay as they are unless the owner changes them.

## Phase 3 - Phase B measurements

The spike specifications are written and ready in `phase-b/`: S1 proving throughput (whose
headline output `b` converts the DA-bound target into a gas rate), S2 round timing, S3 L1 cost and
the reward floor, S4 blob binding with its independent cryptographic review, plus the measurement
report template.

These need hardware and people; they cannot be executed here. What this repository owes Phase B
is the *interpretation*: which rule or parameter changes for each measurement, and which
parameter stays a tagged placeholder until then. `phase-b/README.md` and each spike's section on
what it unblocks carry that mapping.

## Standing rules for every phase

- No finding is closed by reverting a decision; the decision owner changes decisions.
- Every repair is re-checked against what it changed: three of five Criticals in rounds 4-6 were
  introduced by repairs.
- A round is clean only if it produced no Critical and no High.
- The register, the index and the course move with the specification, or the round is not clean.
- Anything unmeasured stays tagged unmeasured; nothing is invented.
