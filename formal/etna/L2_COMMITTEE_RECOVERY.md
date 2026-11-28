# L2 committee and recovery TLA: selected conditional histories

Ten scheduled histories reach their named observations on the corrected model.
**Free height14 exhaustive safety remains OPEN.** The default503 cases consist
of493 unchanged historical configurations and ten new witnesses; they exclude
the separately retained Free config. A green default CI is not Free safety or
whole-protocol verification. The [coverage assessment](PROTOCOL_COVERAGE.md)
retains approximately30percent (25–35 judgement range), not a test-count metric.

## Source and scope

This stage pins unmerged design PR22425 at178d7a7a/main360, baseline5abc1748c.
The [source profile](draft_rules/l2_committee_recovery_source.json) binds the
five normative documents, [independent contract](L2_COMMITTEE_RECOVERY_CONTRACT.md),
[main literal histories](draft_rules/l2_committee_recovery_oracle.json),
[budget regression oracle](draft_rules/l2_committee_recovery_budget_oracle.json)
and [actual verification digests](draft_rules/l2_committee_recovery_verification.json).
The main core was frozen before implementation; its v3 supplement followed
static review before full execution. The budget supplement was independently
frozen after discovering the missing transition and before inspecting its fix.

The finite instance usesQ=10^27/4, four Q-principal bonds, minStake=vpUnit=Q,
nMax4, missLimit2 and10000bps miss/forfeit deductions. Remaining principal plus the slash sink
stays at4Q in this exact instance; arbitrary rates, rounding, weights,
registration, funding, top-up and withdrawal are unverified. Exit releases a
seat while retaining principal and may leave a historical miss in the empty seat.
Four distinct continuously online fallback controllers satisfy the readiness
premise. The final C/D committee signs legally but is concentrated1/2 per
controller; it is not a launch-ready concentration result.

Origin10, actual saved landing, H/H+1/H+2 assignments, parent certificates,
live-key misses, snapshot-before-calls, old-suffix rollback and generation reset
share one transition kernel. Free ends at14 and witnesses at19. Witnesses
constrain external offers and never use observer/oracle values to enable steps.
The present model assumes authenticated latest finalized L1 adoption at each
block, code present with Effects/Revert, valid authority and abstract proofs.
Anchor lag, actual no-code/repair, full proof construction, stock Comet rounds,
locks/messages/signatures, client/EL/guest execution and temporal fairness or
leads-to remain outside this result. Infinite stuttering is allowed.

## Ten actual histories

| Profile | Source-qualified observation |
| --- | --- |
| OriginCandidate | Origin fallback for the first two blocks; candidate activation at H+2. |
| RecoverMax | Lost candidate quorum, max+recovery, fallback, forfeiture and delayed online candidate. |
| Restall | Recovery without max returns to an unavailable current set despite a future usable set. |
| ThresholdStall | Changing M cannot advance an already blocked current height. |
| SuffixRollback | Restore the actual checkpoint ledger, reverse suffix exit and discard old pending sets. |
| Penalty | Two parent misses deduct principal and affect the delayed committee. |
| EmptySeat | Exit retains principal and a historical miss in an empty seat. |
| StaleSnapshot | Reverted block-start snapshot delays fresh candidate selection. |
| StaleAuth | Captured c becomes stale after a later landing; the batch refuses atomically. |
| StaleAuthBudget | That refusal remains observable after two threshold updates, with complete frames. |

All ten actual named outcomes completed on model6de842a3. Together their raw
counterexample histories contain115 states. These are negative observation
invariants deliberately witnessing required paths, not ten protocol defects.
The independent reader checks actual predecessor receipts, source-derived
transitions and frozen literal values; summary counts alone are insufficient.

## Defects found in the verification work

The [first erratum](draft_rules/l2_committee_recovery_errata.md) preserves the
original oracle's3Q candidate under an incorrect4Q threshold. Corrected initial
M=3Q was rechecked before body implementation. The
[scope erratum](draft_rules/l2_committee_recovery_scope_errata.md) withdraws
no-code plus successful calls at the same proxy and unmodeled automatic repair.
Revert is the modeled delayed-snapshot case. Review also made immediate-anchor
and absent-fairness premises explicit. None established a protocol defect.

Whole-stage review then found a missing model transition: a threshold-update
budget guarded stale recovery refusal even though refusal applies no update.
The new eight-input budget profile first genuinely failed: TLC completed18
generated/8 distinct/0 queued states without the required refusal. After moving
the budget guard inside accepted recovery only, it reached the exact named
observation with18 generated/9 distinct/0 queued. The original finder checked
the fix and full chain/landing/environment frame. This closes a non-vacuity
blind spot: conditional assertions cannot detect transitions never offered.

## Actual behavioral controls

Eight private source faults were each run as normal PASS, exact named safety
failure, byte-exact restoration and actual PASS: snapshot after calls; one-height
activation; current-quorum bypass; old pending across recovery; suffix ledger
instead of checkpoint ledger; ignored disable tag; stale snapshot accepted as
fresh; and clearing an empty-seat counter on exit. Setup failures are not
semantic detections. An initial sandbox RMI setup refusal was retained and
excluded; the complete lifecycles then ran in the working isolated context.

The ignore-tag control uses Disabled.q=0, a tagged placeholder. It does not
distinguish a literal uint256 maximum treated numerically: all reachable stake
totals are at most4Q. Numeric MAX/corrupt-snapshot edges remain unverified.

A separate fixed-F parent-certificate corruption reached actual QuorumSafe
with2 generated/2 distinct/0 queued states. The two states have the same
operational projection and differ only in parentCert. It tests the actual VIEW
failure bits. Full Free Next remains present; private bytes were restored, but
no exhaustive baseline/restored Free PASS is claimed. See the
[first-failure/permutation argument](L2_COMMITTEE_SAFETY_PROJECTION.md).

## Incomplete safety and publication boundary

The original full-state, VIEW-only and symmetry searches timed out before the
budget correction. A fourth search on the corrected kernel timed out at45.067
seconds. They are revision-qualified attempts on one OPEN obligation. The
[unchanged EXPECT PASS config and reproduction](inconclusive/README.md),
[exact identities](inconclusive/results.json) and all four actual timeout logs
are retained. Periodic log samples are not final graph counts. There is no
smaller green graph substituted for the original height14 obligation.

Ordinary regression cohorts are624+173+20=817 on each source360/f556 background.
Actual final independent readbacks and immutable-head publication/CI receipts
are recorded in the monitor ledger after their gates finish. Old models,
configurations, fixtures, classifiers and source-admission claims are preserved.
The14 runtime WAITING and19 historical INCONCLUSIVE rows remain separate,
plus this new open Free obligation. Production, SPEC, Notion, live nodes/chains,
keys/signing and deployment were not changed. The PR remains a draft.
