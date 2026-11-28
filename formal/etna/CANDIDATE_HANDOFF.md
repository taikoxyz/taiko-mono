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
CONS-3.2-3, CONS-3.3-3a/4/5, CONS-3.4-4/5/8/11a/12, START-10.1-3e/f/14/14a/b/d,
RECOV-8-14/15/16, RECOV-8.2-4/5, RECOV-8.4-2/7/10/12/13 and SYNC-9-10/11/13/14.
The existing M11 contract abstractions and environmental premises remain.

Two finite programs execute inherited `Setup`, `PrepareCall`, and `Invoke`:

- `Promote`: schedule rules 1 at timestamp 2 in L1 call 1; then schedule rules 2
  at timestamp 4 in L1 call 2. This existing raw program is unchanged.
- `HandoffRecovery`: seed checkpoint 12 through inherited `LandFresh(1)`;
  schedule rules 1 at timestamp 2 in L1 call 1; recover at time 3 with expected
  generation 0, checkpoint 12, nonce 0, validUntil 6, and rules 2. This is the
  original handoff's added M11 raw program and `NeedsLanding` entry. Existing 23 programs,
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
   acceptance of the first generation-1 candidate using the recovery anchor; it
   neither relabels the old candidate nor authenticates a new signing session.

### Exact fresh first-block fixture

The four recovering programs retain checkpoint 12 with its original L2 header
timestamp 1. `SeededParent` states that immutable bounded input premise explicitly;
the inherited settlement interface does not execute or authenticate this header.
Recovery at L1 time 3 does not change its L2 timestamp. The stop programs' held
suffix parents 18/13 at time 2 are distinct discarded history above checkpoint 12.

`ObserveFresh` extends that retained checkpoint, using parent height 12/time 1,
candidate generation 1/time 3, and the recovery-invocation anchor at time 3. Under
RECOV-8.4-7/10 the BFT genesis time is R.timestamp=3. The EL timestamp follows
CONS-3.2-3: max(parent time 1 + 1, BFT time 3, anchor time 3)=3. This concrete
coincidence does not assert that every possible first EL timestamp equals the
BFT genesis time independently of its parent and anchor.

An observation-only `freshAudit` captures the original parent premise separately
as raw height 12/time 1 at initialization. On accepted recovery it records the
original call's expected checkpoint, generation, time/block and exact independent
`historyAudit` entry. It never reads operational `SeededParent`, `originRecord` or
`Snapshot`, and operational actions never read it. `FreshIdentity`, enabled by
all 43 handoff configs, compares the complete candidate, origin and anchor against
these raw premises. Its `FirstRecoveryBlockUsesGenesisTime` clause independently
checks the concrete first-block timing rule. All 339 existing config bytes stay
unchanged.

PR22387 feedback exposed that the prior fresh fixture instead accepted timestamp
4/parent time 3. Those values describe neither this valid first block nor the
retained parent's original timestamp. The stronger oracle rejects that old trace;
three assessed source-only faults separately substitute candidate time 4, parent
time 2 (still below candidate time 3) or parent height 18. Each must fail exactly
`FreshIdentity` with successful original/restored normal runs in all four programs.
This repairs a verification fixture and observer, not a production protocol defect.

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

## Positive-stop composition

The original two programs and 19 configurations remain unchanged. An independent
source-only diagnostic showed that all 19 outcomes survived complete historical
stop removal; the original M11 candidate workload rejected that same fault.
That historical coverage gap is retained as evidence, not a protocol defect.

Three additional raw programs seed checkpoint 12, schedule Stop in call 1 at
time 1, schedule rules 1/time 3 in call 2 at time 2, hold, then recover in call 3
at time 3 with rules 2, expected generation/nonce 0, checkpoint 12 and deadline 6:

| Program             | Stop time/grid | Held timestamp | Parent height/time | Initial / supported result |
| ------------------- | -------------- | -------------- | ------------------ | -------------------------- |
| StopDueRecovery     | 2 / 12         | 3              | 18 / 2             | Stop / Stop                |
| StopFutureRecovery  | 3 / 12         | 3              | 18 / 2             | Wait / Accept              |
| StopOffGridRecovery | 2 / 12         | 3              | 13 / 2             | Wait / Accept              |

The retained anchor is the actual time-2 history entry, independently captured
as index 3/generation 0 in the raw audit. Parent 18 is an unlanded suffix beyond
the seeded checkpoint, so its time-2 metadata does not relabel the time-1 landed
checkpoint. Parent/block validity remains an explicit interface premise.
The original grid origin remains S=6. Grid 12 distinguishes it from recovery
origin 12; future stop time 3 distinguishes parent time 2 from candidate time 3.

Recovery clears the current stop but cannot rewrite held identity/history.
`HistoricalDerivation` independently observes the initial and retry outcomes;
`StoppedSignatureFence` uses frozen raw candidate/history and at-exposure support,
and refuses a historically stopped candidate even when the old session otherwise
remains authorized. Authenticated knowledge independently revokes that session.
Earlier permitted signatures for legal future/off-grid candidates stay historical.
The new pre-knowledge and preservation witnesses bind the exposure's own current
generation to 1: they require a signature after recovery and before learning it,
then retention of that same permitted historical exposure after authentication.
An exposure made before recovery cannot satisfy these two witnesses; it remains
a valid earlier historical exposure under the separate at-exposure signing fence.
The exact fresh generation-1 first candidate is a separate observation. No queued proof is
created for these three programs; the original opaque-proof premise stays scoped
to `HandoffRecovery` and is never a proof of a stopped candidate.

Three normal searches and 21 exact reachability witnesses cover retention after
current stop clearing, unsupported/supported stop, future/off-grid acceptance,
all support/knowledge orders, pre-knowledge refusal, past legal exposure and fresh
continuation. Seven source-only controls independently remove stop, due-time,
grid, retained schedule, signing gate, original grid origin or parent-time use.
They require the exact `HistoricalDerivation` or `StoppedSignatureFence` failure,
with successful original/restored runs. Tool/parser errors do not count.

The separate `stop-handoff` exporter profile reuses M11 public receipts and the
existing Solidity rules adapter for all nine real Stop/Rules/Recover calls.
This checks actual L1 state, raw slot/event, generation/origin and abort observers;
held-candidate execution, signing, real client/consensus and STF/proving remain
model-only. Broader stop programs and unbounded composition remain unassessed.
