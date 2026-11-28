# Positive-stop handoff verification

## Intent and authority

Continue the user-authorized Etna verification takeover from local commit
`2fbe8b366`. Independent experiments showed that disabling historical stop
decisions preserves all 19 existing handoff outcomes, while the same fault fails
the original M11 observation workload. This closes a declared coverage boundary;
it is not evidence of a production protocol defect.

Keep SPEC `d18357214fab30ea512ae9858a11699806d72ba1` / blob
`649548c58d6629dd85143b33efd3644a3bb71509`, and actual contracts
`89f419915de4b73bb57c53bf970f6dea9e8e8c8c`. No normative or production changes,
PR, merge, deployment, new dependencies, SDKs, or duplicate build caches.
The user subsequently authorized committing and publishing the verification
branch without a PR; this supersedes the initial local-only publication scope.
Stop on an independently supported actual protocol defect for discussion.

## Approach

Extend the existing handoff wrappers and raw M11 fixtures, reuse their actual
public action engine and independent history/stop observers, and replay the
new public calls through the existing Solidity rules adapter. This is the
implementation choice under the takeover authorization. A separate copied
state machine would duplicate guards; an unrestricted whole-module product
would exceed the bounded question. Neither is needed for this increment.

Three new programs have seeded checkpoint 12, generation/nonce 0, deadline 6:

| Program             | Stop call at 1  | Rules call at 2 | Hold after call 2             | Recovery at 3 |
| ------------------- | --------------- | --------------- | ----------------------------- | ------------- |
| StopDueRecovery     | time 2, grid 12 | rules 1, time 3 | timestamp 3, parent 18/time 2 | rules 2, c12  |
| StopFutureRecovery  | time 3, grid 12 | rules 1, time 3 | timestamp 3, parent 18/time 2 | rules 2, c12  |
| StopOffGridRecovery | time 2, grid 12 | rules 1, time 3 | timestamp 3, parent 13/time 2 | rules 2, c12  |

Capture the actual time-2 historical anchor. The original Etna start S=6 remains
the grid origin. Parents 18 and 13 are unlanded suffix metadata above c12; do
not relabel the already landed checkpoint12 with a later timestamp. Parent/block
validity remains an interface premise, not executed STF evidence.
The stop grid12 deliberately differs from K6: parent18 is on the S6-relative
stop grid but off a grid incorrectly rebased at recovery checkpoint12.
The future stop equals candidate time3 while parent time2 is earlier, isolating
the protocol's parent-time decision from an incorrect candidate-time decision.
Historical results are Stop, Wait, Wait before support, and
Stop, Accept, Accept after support. Recovery clears current stop state, but
does not rewrite the held candidate. Authentication separately fences old-session
signing; earlier permitted exposures remain historical. A fresh generation-1
candidate may proceed after support. Do not fabricate a proof of a stopped
candidate: the original opaque-proof experiment remains separately scoped.

## Required evidence

- Preserve all 314 existing config files and 19 incomplete historical profiles.
  Preserve old fixture payloads, schema and mappings; refresh provenance honestly.
- Exhaust new finite normal workloads; witness a genuinely stopped retained
  candidate after recovery, legal future/off-grid candidates, support/knowledge
  orders, fresh continuation, and refusal to sign a historically stopped candidate.
- Independently observe held identity, historical stop semantics, at-exposure
  authorization and actual current schedule clearing. An oracle must not call
  the operational stop helper or use current schedule as historical truth.
- Kill direct source faults for ignoring stop, treating all scheduled stops as
  due, using candidate time, ignoring grid alignment, rebasing the grid at recovery,
  using current stop after recovery, and bypassing
  the stopped-candidate signing gate. Require intended semantic failures and
  successful normal/restored runs; retain earlier diagnostic survivors.
- Export all 9 new public calls from actual TLC receipts and replay them through
  real pinned Inbox methods with full existing state/event/abort observers.
  No Python/Solidity duplicate acceptance algorithm. Keep original C05 38 calls.
- Use existing configured Python, Java17/TLC1.7.4 and Forge1.4.2/Solc0.8.30.
  Inspect execution entrypoints; isolated read-only source snapshots, no network
  or secrets, one common Foundry lock across baseline/mutant/restored runs.
- Independent adversarial review and behavioral verification; final accumulated
  regression, stable input hashes and explicit remaining assumptions.

## Mixed runtime execution

The expanded fault inventory has two disjoint exact Forge test sets: existing
Identity publication checks and new Rules stop-handoff checks. Keep exact test
identity checking. Execute compatible explicit `--only` cohorts with their own
external runtime selectors, and check that their disjoint union equals every
assessed required obligation. A portable cohort descriptor and regression pin
that coverage/compatibility relation. A cohort's ready flag is not full-inventory
readiness; the current mixed inventory cannot use one fixed Forge selector as a
default complete run. This bounded procedure avoids expanding the runner API.

## Limits

Finite candidate and public-call workloads, resolved authenticated anchors,
trusted parent/block metadata and statement-bound proof/initialization premises
remain. Actual client/CometBFT/EL, STF/guest/proving, structural K changes and
unbounded refinement remain outside this increment. Stop after this coherent
coverage repair and report results; do not invent another batch automatically.
