# Bounded held-candidate handoff

`EtnaCandidateHandoff` extends the actual `EtnaRulesSchedule` (M11) public-call
engine and its `EtnaSettlement` proof interface. It adds one held candidate,
local recovery knowledge, and observation receipts. It does not implement a
client, signer, consensus engine, STF, or proof producer.

## Frozen sources and workload

The normative baseline is SPEC commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`; contract baseline is
`89f419915de4b73bb57c53bf970f6dea9e8e8c8c`. The source requirements are
CONS-3.3-3a/4/5, CONS-3.4-4/5/8/11a/12, START-10.1-3e/f/14/14a/b/d,
RECOV-8-14/15/16, RECOV-8.2-4/5, RECOV-8.4-2/7/12/13 and SYNC-9-10/11/13/14.
The existing M11 contract abstractions and environmental premises remain.

Two finite programs execute inherited `Setup`, `PrepareCall`, and `Invoke`:

- `Promote`: schedule rules 1 at timestamp 2 in L1 call 1; then schedule rules 2
  at timestamp 4 in L1 call 2. This existing raw program is unchanged.
- `HandoffRecovery`: seed checkpoint 12 through inherited `LandFresh(1)`;
  schedule rules 1 at timestamp 2 in L1 call 1; recover at time 3 with expected
  generation 0, checkpoint 12, nonce 0, validUntil 6, and rules 2. This is the
  only added M11 raw program and `NeedsLanding` entry. Existing 23 programs,
  public-call actions, and C05 schema remain unchanged.

Between the two calls, hold candidate timestamp 2, parent height 12, parent time
1, generation 0 and the time-1 historical anchor. Supported rules initially are
`{0}`, so rule 1 waits. The held candidate is captured at `Ready/index=1` before
preparing the next call. Support installation may occur before recovery, after
recovery but before authentication, or after authentication. Retry takes place
at `Ready/index=2`. Bounds are two public calls, one held candidate, one support
installation and one authenticated knowledge transition; all distinct receipt
combinations are explored without fairness assumptions.

## Three separate observations

1. Historical derivation uses original candidate and parent timestamps, original
   generation and retained anchor. `HeldIdentity` compares against an independent
   capture and the inherited history audit. `HistoricalDerivation` uses M11's
   independent `ExpectedRule`/`ExpectedStop`, plus candidate-minus-anchor freshness.
   It never applies current-generation `ValidCandidate` to the retained candidate.
2. Signing stays in session generation 0. A separate `AuthenticateRecovery` action
   raises the learned generation floor and revokes current trust/app confirmation.
   L1 recovery alone is not local knowledge. Every exposure records the knowledge,
   trust, app confirmation and session at that moment. `SignatureFence` checks
   those captured values; authentication cannot retroactively invalidate a past
   signature. Support does not authenticate a new signing session. Crash/restart,
   HRS persistence and app implementation are outside this model.
3. Before recovery, inherited `PrepareProof(2)` queues one otherwise-valid proof
   from the seeded checkpoint. `ObserveProof` evaluates `ENABLED Land(pendingProof)`
   after the public call. The old proof is refused by the inherited current
   generation check. It is an opaque queued-proof premise, not a proof generated
   from the held candidate. The observer does not execute a landing, so it does
   not disturb M11's current public-state receipt. `ObserveFresh` separately shows
   acceptance of a new generation-1 candidate anchored at/after recovery; it
   neither relabels the old candidate nor authenticates a new signing session.

`OriginalCallPreserved`, `HistoryProvenance`, public call/state/event invariants
remain enabled in every case. The held audit, history audit, receipt sets and
proof enabledness never feed back into public calls or authorization. Receipt
membership only bounds duplicate observation actions. The normal models omit
later L1 ticks; recovery time 3 already distinguishes current-clock freshness
from candidate time 2. Parent validity and complete block validity remain
explicit premises inherited from M11.

## Checks and limitations

Two normal configurations exhaust each bounded program. Six negative controls
require exact invariant failures: latest schedule and current clock fail
`HistoricalDerivation`; rewriting held generation or anchor fails `HeldIdentity`;
cached authorization fails `SignatureFence`; bypassing proof generation fails
`ProofGenerationFence`. Parser errors, timeouts and unrelated failures do not count.

Eleven deliberately false reachability invariants witness hold before the second
call, retry after it, unsupported waiting, all three support/recovery/knowledge
orders, refusal after authentication, signing before authentication, preservation
of that past signature after authentication, proof refusal, and a separate fresh
recovery candidate. These witnesses establish existence only, not eventual
support, eventual authentication or recovery liveness.

This finite composition checks the listed interface premises and interleavings.
It does not prove unbounded protocol safety, real cryptography/proof soundness,
complete L1 trust authentication, stock CometBFT behavior, or client/guest refinement.

Both selected handoff programs have `stopTime=0`. Historical stop is therefore
checked only for the no-stop case in this composition. Positive-stop and
stop-clear/recovery handoff interleavings remain UNASSESSED in the sensitivity
inventory; separate M11 stop coverage does not close this composition gap.
