# Plan to convergence, then to the add-ons and Phase B

Owner: design lead. Budget: generous (up to ~5 days). Nothing here stops for budget.

## Standing instruction from the design owner: Phase B goes on a NEW branch and a NEW PR

**Do not add Phase B work to the current PR (#22262, branch `etna-pos-zk`).** When Phase B starts - the four
measurement spikes S1-S4 plus the independent cryptographic review of the blob binding - it gets its own
branch created **on top of** this one, and its own pull request. The reason is that this PR is a design
artifact with its own review history, and measurement results are a different kind of change: they carry
numbers, hardware, and conclusions that revise parameters, and mixing them would make the design PR's
history unreadable and its review unrepeatable. Until that branch exists, Phase B material stays in
`phase-b/` as specification only.

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
The list is in increment order; the status on each item says what is actually moving, and the work
order is by value and by readiness, not by size.

1. **Increment 2 - heartbeat eligibility (D-14): SHIPPED.** Its round-5 Critical (a heartbeat
   signature as a permanent credential) was fixed with the window-and-sequence payload, the fix was
   reviewed, and the increment reached the convergence bar - two consecutive rounds with no Critical
   and no High - with round 4 re-confirming the fixed artifact
   (`increments/02-ship-record.md`). `MEM-13` is live; the rotation that consumes it stays deferred
   and tombstoned (`DEFERRED.md` section 2).
2. **Increment 3 - aggregation (D-13): gated on Phase B's S1 measurement.** n and m cannot be fixed
   before S1 measures the aggregation cost. Design work can proceed; parameterisation cannot.
3. **Increment 4 - narrow forced inclusion (D-12): IN REVIEW.** Its four named blockers - one unit
   of account for the obligation, a mandatory frontier advance with no waiver, a void predicate
   computed from the record's immutable bytes and registered constants only, and expiry as an
   objective proof-side discharge ground - are closed by
   `increments/04-forced-inclusion-design.md`, and `DEFERRED.md` section 1 is the revival record.
   The implementation and the increment's own review round are in flight; it ships only after two
   consecutive clean rounds. F-FI-2 (arrivals exceeding the drain) ships **Open** and unfixed by design:
   no per-publisher bound on `publish()` is added, because a condition on publication is outside what
   D-12 authorises. Open is what the design says of a premise no rule closes whose falsification would be
   a defect; disclosed is what it says of an inherent limit, and F-FI-2 is the former. *(correction: this
   line read "ships open and disclosed"; the two classes are exclusive and F-FI-2 is Open, not disclosed.)*
4. **Increment 5 - the governance stall resolution (D-15): IMPLEMENTED, IN REVIEW.** Its three
   blockers are closed by `increments/05-governance-design.md` against the converged v1: the entry
   state machine with a consuming `executed` transition (one execution per entry, one generation
   increment, no other writer), the exit contradiction resolved by withdrawing the "every user can
   exit" claim and scoping the window to signals already at or below the last accepted checkpoint
   (value above it is stated unprotected), and a two-case generation rule under which the anchor
   certificate is judged under the restored block's own header generation while the batch's
   certificate carries the current one. `DEFERRED.md` section 3 is the revival record, D-19 records
   the decision, and the F-GOV-1-F-GOV-6 falsifiers are stated with their classes. The implementation
   and the increment's own review round are in flight; it ships only after two consecutive clean
   rounds. Its parameters and window relation remain unmeasured.

Order of work: increment 2 is shipped; increments 4 and 5 are implemented and in review while
increment 3 waits on S1.

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
