# L2 staking draft: source delta and quorum-constrained traces

This selected round follows unmerged design PR22425 at
`178d7a7a66b14305c2f6467ae77163f93dd677cf`, based on
`3602629758beb653423a23608fd1960810efcfac`. The preceding
[L2 review](L2_STAKING_REVIEW.md) and its model/source manifest retain the
historical69 revision and their original evidence limits. The new
[source manifest](draft_rules/quorum_source.json) grants no runtime admission.

## Source correspondence

The exact delta from69 contains eight commits and20 changed files. All71 files
changed from the actual360 base to178 were authenticated by their Git blob
identities and SHA256. Both complete review views use actual360 documentation
plus the applicable overlays: a PR-changed-file cache alone omits unchanged
base files. The original caches and failed assembly diagnostics were preserved;
the documentation AGENTS symlink was not followed during archive materialization.
An independent source reviewer checked all20 delta files and their normative
context. No blocking normal-model protocol contradiction was confirmed.

| Changed surface | Current meaning | Remaining evidence |
| --- | --- | --- |
| CONS-3.2-12/13, STAKE-4.2-8 | One30M message-call frame, fresh transient/access state, no intrinsic gas/cap/fee/receipt; node I/O failure is not an EVM-call failure | Actual EL and both guests at frame limits, reverting writes/logs, no-code success, infrastructure failure, ordinary discard and FI trial |
| STAKE-4.1-31, ENC-A-44/45 | Nil means empty hashes and zero total; a present32-byte all-zero hash is not empty | Actual stock serialization, signature and slashing consumers |
| START-10-1/5, PARAM-11-10b | On switching networks, atomic CREATE2 deployment of the fixed staking proxy and implementation with proxy initialization, followed by pre-schedule proof of owner/code/immutables. New networks install staking in L2 genesis | Concrete release artifacts, deployment and readiness rehearsal |
| START-10.1-2b | An EL-changing future ruleset must define its EL selection before scheduling or recovery names it | Actual future-ruleset mechanism and cross-client behavior |
| PROOF-6.2-11/33/47 | Full proof-origin witness verification, exceptional278/279 use only for p+2, ordinary ancestry for inherited/new-block anchors | Full MPT/guest provenance and source-substitution vectors |
| DATA-5.4-2/3 | Landed proofs cover bitmap validity throughout the authenticated window (w,s], including s. The importer checks the window commits and derives s+2. The s+1 bitmap is checked against the actual s post-state | Authenticated native importer, raw live mappings and first-successor tests |
| COMM-4.3-8b, ENC-A-36d/e/-55 | Each signer set has1..128 keys independent of n_max; explicit fallback events and uint256 snapshot-height view | Raw128-record, ABI/event and historical-list consumers |

The unchanged rule checker passed634 live markers,101 retired markers, assets,
links and tables in the exact-base178 disposable view. Migration purity was
explicitly SKIP; this structural checker does not test normative behavior.

One independently observed P3 is non-blocking: rules/INDEX.md's
PROOF-6.2-11 summary says "never the p-anchor alternative" without the two-value
exception. The controlling SPEC and positive11.f/33.d/47.a vectors permit it.
No upstream text/comment was changed. This illustrates why green index/link
checks cannot substitute for a source-derived acceptance oracle.

## Proof-origin interpretation

When p>o, verify all seven ordered slot/value/proof tuples of p's anchor witness,
including the MPT integrity of values not otherwise consumed. Expose only278
and279 from the p-only authenticated-root path for the p+2 selection. All other
semantic Inbox inputs use roots with ordinary authentication. If p+1 inherits
the same anchor, its ordinary ancestry check still applies. A two-slot witness,
an unchecked non-consumed tuple, unrelated slot282/293 reliance, or universally
requiring historical p ancestry does not implement the combined rules/vectors.
The initially suspected wording conflict is rebutted by this two-layer reading;
no competing conforming acceptance verdict was established.

## Historical block-start abstraction

The preserved model6065102a projects state updates or stale call-owned state.
Its boolean is not an EVM return-status oracle. A no-code message call succeeds
without effects in178: its stale snapshot may be projected by the old false
branch, but that branch's returned call_succeeded=False is not its EVM status.
The new quorum wrapper does not add no-code, frame gas, access-list/transient,
receipt or node-fault semantics and must not claim those cases were executed.

## Quorum projection and observed verification

The separate wrapper requires a strict >2/3 parent block-commit power and
independent strict >2/3 possible current voting power using each height's own
keys and weights. Nil and absent flags both feed the live-seat miss projection,
but neither contributes block power. Optional previous availability constrains
nil and commit to keys available in that parent-height premise. It does not
turn abstract flags into signatures or prove consistent rounds, locks or
message delivery. A rejected/stalled step retains the entire predecessor and
cannot apply its anchor, penalty or action to reach a later fallback set.

The independently frozen oracle predates implementation. Its primary seven
advances use Q=10^27/4, four bonds and deployment-compatible supply/unit/seat
arithmetic. It includes two consecutive misses, penalty, seat release and
two-height activation; branches cover same-key reseating, power-only changes,
failed calls, delayed fallback, incompatible domains and stalled retry.
Execution results and exact finite bounds follow below.

## Evidence boundary

This is a symbolic power/domain projection from trusted checkpoint premises.
It is not an actual consensus trace, signature verifier, full-protocol proof,
or a deployment-unit quotient. All old models, config inputs, source bundles,
runtime classifiers and claims retain their meanings. The14 source360 runtime
rows remain WAITING and19 archived searches INCONCLUSIVE. Source correspondence
and another finite bank cannot close absent staking/EL/guest/importer code,
canonical128-record witnesses, cryptography, real proving cost or operational
and public/private-history budgets.

## Why the initial self-check missed an input-integrity error

The first16 source-derived tests passed normally and under -O, including7380
power/flag combinations. Independent review nevertheless found that the new
public helpers reused an old shape validator without checking source versus
power: source=fallback or origin with members A:3,B:1 admitted A alone. Those
sources require unit powers. A malformed pending set could also shift into the
successor pipeline before either operative power gate used it.

The malformed-selection bank covered zero, duplicate, overflow, shape and key
validity but labeled every finite-power example candidate. The exhaustive
arithmetic bank deliberately used candidate labels as well. Thus both banks
omitted the same independent semantic relation. Root's separate two-test probe
produced five ValueError-not-raised assertion failures, zero errors, on the
original candidate. This is a verification-interface defect, not a normal
protocol trace. The old generated pipelines already give origin/fallback keys
unit power. Repair is confined to the new wrapper and regression bank;
the historical model and its validation contracts retain their recorded pin.

## Accepted candidate and independent checks

The accepted new wrapper SHA256 is
`eef2a65bcd56bb56e455618bc4960f9775f2856421ed3ae15e5374fc359cc8e3`;
its18-test module is
`58a8e84fe981c0193e310f8daa32d89e83c36895b0c7b83292f012e9b893e4d4`.
Both public power gates enforce unit weights for origin/fallback sources;
before advancing, all three predecessor pipeline sets receive that check,
including the intentionally empty origin current set. A weighted candidate
still passes the appropriate power gates. Root's unchanged two-method
counterexample passes after the repair, and the original finder rechecked
the complete fix with spec-compliance and quality PASS.

All18 tests passed normally and under optimization. Their finite arithmetic
bank enumerates exactly7380 combinations:1..4 members, individual powers1..3,
and each flag commit/nil/absent. It checks accepted contributions and refused
quorums, including exact2/3. This is not an exhaustive multi-height exploration.
The author's deployment-compatible trace takes seven advances, reaching H17
from origin10 with Q=10^27/4; its fallback branch includes a stalled retry.
Small-unit reseating, power-switch and failure probes are separate conditional
traces and establish no production-unit quotient.

An independently frozen oracle predates implementation. Its unchanged bridge
passed nine tests normally and optimized; the post-finding independent
source/power supplement passed two more in each mode. The old67ef candidate
failed all ten supplemental rejection subcases. The independent numerical
baseline starts at generation7/origin100 and takes seven advances; its same-key
reseating branch takes eight. It uses at most four active signers, five seat
slots and four additional fallback keys. Previous availability is retained
across admitted heights and unchanged across each refusal. These are bounded
power-compatible witnesses, without verified rounds/locks or signatures.

Six actual private-copy faults were detected by semantic assertions: inclusive
2/3, counting nil power, skipping current availability, allowing offline nil,
reusing parent weights when keys stay the same, and running the historical
transition before the current gate. Every counted fault had zero setup/errors,
and each byte-exact restoration passed the full nine-plus-two checks. An
initial unconditional wrong-set edit instead broke fixture setup; it was
retained, excluded from the six results and replaced by the intended same-key,
changed-power fault. Canonical code was never mutated by the verifier.

Fresh complete ordinary suites passed804 checks in each supported360/f556
document context:618 main,166 conformance and20 sensitivity, zero failures,
errors or skips, with all discovered tests executed. Snapshot hashes remained
unchanged during each run. Direct calls to the unchanged runtime classifier
accepted its exact known context and rejected the actual178 draft bytes;
the product pin and five accepted bundles were unchanged.

Of919 pre-existing tracked formal files,916 remain byte-identical. The three
intentional documentation edits preserve the complete old REPORT/README as
prefixes and the old WORKLIST after removing only the new section. All52 TLA
and603 CFG files, including experimental configurations, retain their bytes;
the default executed TLC bank is493, not603. No TLC input or runner changed,
so this local round retains the prior493 raw result rather than re-running it.
Exact new-head hosted results and publication are observed after commit and
recorded separately in the owned PR status prefix and monitor ledger.

The independent complete-stage review checked all nine changed files, exact
source identities, preserved old bytes and these evidence boundaries. Its
two non-blocking summary clarifications were corrected: CREATE2 deployment
and pre-schedule proof apply to switching networks, while a new network installs
staking in genesis; bitmap proof coverage is (w,s], including s, before the
importer checks s+1 from s's actual state. No normative source was changed.
