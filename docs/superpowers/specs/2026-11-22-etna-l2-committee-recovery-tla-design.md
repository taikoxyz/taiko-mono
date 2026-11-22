# L2 committee and recovery TLA design

The user explicitly continued toward TLA plus verification of the entire
protocol. This stage addresses the missing latest-design committee/recovery
composition, at unmerged design PR22425 head178d7a7a/main360. It does not restart
any completed historical stage or make the draft a runtime-admitted source.

## Why this stage

The52 old TLA modules and603 configurations remain historical evidence. In
particular EtnaCommittee models L1 Registry epochs and activeCommitteeSnapshot;
it does not model the new L2 per-block selection. The newer Python boundary
and quorum banks have conditional inputs, no Recover transition and no
self-contained multi-height reachable graph. Existing wire conformance is a
separate completed library result.

Root initially estimated50percent from reusable accumulated work, then corrected
the estimate after independent source/coverage reconnaissance: approximately
30percent, with a25–35percent judgement range, for latest-source whole-protocol
TLA/spec verification. This is a risk-weighted working estimate, not measured
clause coverage, test-count division or implementation completion. Implementation,
proof execution, deployment and operational validation have separate evidence.

## Selected product

Build one separately pinned TLA state machine with a compact freely interleaved
safety profile and source-valid positive/risk witness profiles. Compose live
staking effects, parent-commit/current-availability gates, block-start snapshot,
the H/H+1/H+2 pipeline, trusted landing and recovery from the actually saved
latest checkpoint. Every witness predicate observes actual state; no target,
expected output, witness flag or literal oracle may authorize a transition.
Environment/profile restrictions must be explicit and cannot be reported as
exhaustion of the unrestricted protocol graph.

The initial candidate threshold is3Q, falling to2Q after recovery forfeitures.
The decisive circuit is candidate loss of quorum, threshold-only inability to
advance, atomic max-threshold plus recovery, origin-frozen first two sets,
continued fallback at the third block, L2 forfeiture of unavailable bonds,
lowering the threshold and delayed transition to an online candidate. A separate
risk witness must show recovery without max-threshold returning to an unavailable
candidate even after forfeiture, while a future healthy set cannot rescue the
blocked current height. These are specified behaviors, not protocol defects.
Recovery restores the real stored checkpoint's staking state, including suffix
exit rollback, and discards the old generation's pending validator updates.

## Exact finite instance and premises

Use4 registered stake keys, initiallyQ each, Q=10^27/4, minStake=vpUnit=Q,
nMax4, missLimit2 and missSlashBps=forfeitBps=10000. At these permitted parameters
full-principal deductions and integer powers have an exactQ-denominated finite
representation; this does not prove a quotient for arbitrary percentage rounding,
128 members, deployment parameters or arbitrary stakes. Initial supply is4Q.
Do not invent a fifthQ, top-up funding, variable powers or power-only reachability.
Ordinary exit retains principal but releases its seat immediately. An empty seat
may retain a historical miss counter; do not forbid that source-valid state.
Registration, top-up, withdrawal, general accounting and power-only traces remain
outside this selected product.

Use4 independent continuously online fallback keys, distinct from the4 stake
keys, to satisfy the recovery readiness concentration premise. An optional second
four-key fallback list tests origin freezing versus later L1 changes. Do not
label a two-key fallback recovery source-valid under RECOV8.1-7. The final two
online stake members can have a quorum and legally sign, while their concentration
shortfall remains disclosed; do not call that endpoint launch-ready.

Keys and authentication, canonical L1 finality/anchors, governance authorization
and message delivery, token validity and proof soundness/completeness remain
explicit contracts. A trusted abstract Land saves only an actually produced
current state and advances the latest checkpoint; it is not a guest/STF or
full-range/overlap proof implementation. No arbitrary checkpoint constructor
may stand in for recovery. Persistent availability and generation/height-bound
symbolic block certificates are required, but this is not a model of stock
Comet rounds/locks/messages/signatures or a BFT proof. The selected reverting block-start calls have unchanged call-owned state and
stale-height fallback, while other proxy entrypoints can still execute. True
no-code at the fixed proxy cannot also execute stateful staking calls without
modeled repair; no-code/code-availability/repair remains OPEN and is excluded
from this operational alphabet. Actual EVM status/gas is not executed here.
Every committed block adopts the latest authenticated finalized modeled L1
threshold/fallback/landing, so anchor lag remains OPEN. There is no fairness or
leads-to property checked; only finite safety and conditional witness existence
is claimed. Unconditional and fair-conditional progress remain unverified.

## Properties and negative controls

Check source-specific typing, snapshot-before-transactions, pipeline provenance
and two-height delay, per-height quorum domains, complete stalled-step framing,
miss/live-key identity, origin-frozen first-two sets, max-threshold disable,
checkpoint rollback/prefix retention and old-pending reset. Use independent
pre-implementation literal histories for positive and accepted-risk cases.

A stuttering inert model must first fail a source-required reachable witness
without parser/setup errors. Then root grants inspected bounded TLC smoke/full
execution. Use actual private-copy semantic faults for snapshot order, activation
delay, quorum bypass/pending rescue, max handling and recovery rollback/pending
reset; require the specific property and a complete positive restoration.
Hash/setup refusal or timeout is not a semantic detection. A normal supported
protocol contradiction stops for discussion; tool/model errors are fixed in scope.

## Alternatives and execution

Continuing historical R01 horizon3/8 or P01 timeouts first would give old-source
credit and cannot validate this replaced staking interface. Their possible
quotient proofs and original INCONCLUSIVE results remain preserved. Another
isolated helper bank would not close multi-height reachability. The chosen
current-source TLA composition directly addresses the missing central interface.
The user has repeatedly opted out of planning approval loops; root proceeds with
one implementation owner, independent adversarial source review and independent
behavioral verification under the existing isolated worktree.

Only formal artifacts, planned documents and the existing draft branch/status
prefix may change. Preserve every historical model/config/fixture/classifier/
claim/source receipt and14 runtime WAITING/19 archived INCONCLUSIVE dispositions.
No production, normative SPEC, Notion, comments/reviews, private keys/signing,
node/EL engines, live chain, dependency install, deployment, merge or mark-ready.
No new engine runs before root reviews entrypoints, isolation and exact inputs.

## Current delivered boundary

Ten conditional histories include an independently discovered stale-refusal
budget omission, repaired only after its required witness genuinely failed.
Eight actual source-fault/restoration lifecycles and a separate bad-state VIEW
diagnostic test the checks. Free height14 exhaustive safety remains OPEN;
three pre-fix and one corrected-kernel searches timed out. Its EXPECT PASS
configuration and original logs remain independently reproducible outside the
503 default cases. Default CI checks493 historical cases plus ten witnesses,
and grants no new Free safety credit. Whole-protocol progress stays a30percent
judgement, rather than a claim inferred from these test counts.
