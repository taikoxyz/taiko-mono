# Independent oracle correction and manual re-audit, v2

This is a material oracle defect caught by the root reviewer before code or GO,
not a protocol defect. No model, oracle program, test, or TLC history was run.

## Preserved evidence and single behavioral correction

The v1 files remain unchanged:

* contract.md: e886214d7948e31dfb5a78859f534a7d0a8922d66e78e996529317b565369e59
* oracle.json: 7cabb4cdbe98e4c4bdcfe54a01e934405ed34e6d7bf8a4d3c0d097ed0668082d

The v1 initial threshold was4Q, but old-generation h5 recorded total3Q and
selected C3. COMM-4.3-3a requires snapshotTotalStake>=M, and3>=4 is false.
Consequently the v1 h5 decision and its claimed C3 future pending could not
follow from its own parameter. The output table was accidentally authored as
if M=3Q, while the parameter retained an earlier4Q choice.

The one behavioral correction is initial M=3Q, preserved until the atomic max
change or an explicitly listed later L1 change. This makes the intended h5
decision valid without changing any snapshot, principal, quorum, header,
pipeline, recovery checkpoint or environmental premise. Contract thresholds
are now{2Q,3Q,max}; the recovery-without-disable branch starts at3Q. Monetary
supply and initial principal remain4Q. The new files record their v1 hashes.

## Independent source predicate used for this manual audit

For each deciding H: if M=max, use F. Otherwise require snapshotHeight=H,
valid nonempty member set and snapshotTotalStake>=M. Every fresh snapshot in
this selected ledger has distinct valid symbolic keys, unit powers, <=4 members
and sum<=4, so its explicit freshness/threshold relation determines selection.
Origin o+1,o+2 are F independently of this predicate. Decision(H) governs H+2;
header(H).current=S(H), header(H).next=S(H+1); updates diff S(H+1) to S(H+2).
Here h values are the JSON offsets; actual H=10+h as before.

## Every main recorded snapshot and decision

| Record | Stored height | Total | Anchor M | Audit result / intended authority |
| --- | --- | --- | --- | --- |
| Initial state | actual0, offset-10 |0Q|3Q|No decision at initialization; origin fixes S1=S2=F. |
| g0 h1 |1|4Q|3Q|Fresh,4>=3; C4 governs h3. |
| g0 h2 |2|4Q|3Q|Fresh,4>=3; C4 governs h4. |
| g0 h3 |3|4Q|3Q|Fresh,4>=3; C4 governs h5. |
| Land c3 saved snapshot |3|4Q|3Q at its block|Copy of actual g0 h3 post-state; Land does not re-elect. |
| g0 h4, before Exit D |4|4Q|3Q|Fresh,4>=3; C4 governs h6. Exit D afterward preserves this snapshot. |
| g0 h5 |5|3Q|3Q|Fresh,3>=3; C3 governs h7. This is the corrected equality. |
| g0 stalled h6 attempt |still5|3Q|No adopted h6 anchor|No block/snapshot/decision. Current S6=C4 lacks quorum. |
| Recover c3 restored snapshot |3|4Q|max on L1 after batch|Historical c3 snapshot is restored, not relabelled as a new height. Origin forces new S4=S5=F. |
| g1 h4, before Forfeit A/B |4|4Q|max|Max sentinel disables candidate; F governs h6. |
| g1 h5 |5|2Q|max|Max sentinel disables candidate; F governs h7. |
| g1 h6 |6|2Q|2Q|Fresh,2>=2; C2 governs h8. |
| g1 h7 |7|2Q|2Q|Fresh,2>=2; C2 governs h9. |
| g1 h8 |8|2Q|2Q|Fresh,2>=2; C2 governs h10. |

## Every snapshot-bearing branch

| Branch/record | Snapshot compared at H | M | Result |
| --- | --- | --- | --- |
| Threshold-only retry of old h6 |No new snapshot; retained h5,total3Q|max now on L1|No h6 adopted block; no election, pending untouched, head stays5. |
| Recover without disable, g1 h4 |Fresh h4,total4Q, before forfeits|3Q|C4 governs h6 despite live ledger becoming C2 afterward. |
| Same branch, g1 h5 |Fresh h5,total2Q|2Q, changed before its anchor|C2 governs h7; header h5.next remains C4 for h6. |
| Same branch stalled h6 |No new snapshot; retained h5,total2Q|No adopted h6 anchor|S6=C4 has2/4 online, so no decision/activation can skip to S7=C2. |
| No-code/revert at main g1 h6 |Retained h5,total2Q, compared against h6|2Q|5!=6; F governs h8 even though2>=2. |
| Same delayed branch, h7 |Fresh h7,C2,total2Q|2Q|C2 governs h9. |
| Same delayed branch, h8/h9 |Ordinary successful calls inherited from main continuation; fresh C2,total2Q|2Q|C2 governs h10/h11; headers h8=F/C2, h9=C2/C2. |
| First recovery call no-code, h4 |Restored h3,total4Q, compared against h4|max|Both stale height and max disable candidate; F governs h6; stored generation stays0. |
| That branch's next success h5 |Fresh h5,C2,total2Q|max|F governs h7; stored generation becomes1. |
| Snapshot-after-transactions fault comparator, h4 |Correct fresh C4,total4Q; incorrect fresh C2,total2Q|max|Both happen to select F. Raw snapshot property is required to expose this ordering fault. |
| Single-A penalty profile h4 |Fresh C4,total4Q|3Q|C4 governs h6. |
| Single-A penalty profile h5 |Fresh B/C/D,total3Q after full penalty|3Q|BCD governs h7. |
| Exit-retained-counter profile h4 |Fresh C4,total4Q before Exit A|3Q|C4 governs h6; live seat0 empties but retains miss1. |
| Exit-retained-counter profile h5 |Fresh B/C/D,total3Q|3Q|BCD governs h7; empty seat0 counter1 is ignored and retained. |

The stale-expected-c batch branch contains no independently chosen snapshot:
it lands actually produced old h4 (snapshot total4Q at M=3Q, post-state retains
Exit D and3Q seated live stake), then refuses expectedC=3 against actual c4.
There is no recovery snapshot to validate because the complete batch fails.
The current live ledger at head5 and the saved c4 ledger are separate records.

The without-disable branch is an on-chain/certificate-level counterfactual for
the recovery-readiness requirement, not a claim that the DAO followed
RECOV-8.1-7. It demonstrates why that requirement matters; no guaranteed
progress property may silently assume it for all owner-authorized calls.

## First-two, current/next and updates audit

| Path | Decisions at deciding h | Actual signing sets in height order |
| --- | --- | --- |
| Old g0 |d1=C4,d2=C4,d3=C4,d4=C4,d5=C3|S1=F,S2=F,S3=C4,S4=C4,S5=C4,S6=C4,S7=C3. |
| Main new g1 |d4=F,d5=F,d6=C2,d7=C2,d8=C2|S4=F,S5=F,S6=F,S7=F,S8=C2,S9=C2,S10=C2. |
| Without-disable |d4=C4,d5=C2|S4=F,S5=F,S6=C4,S7=C2; cannot commit h6. |
| No-code/revert h6 |d4=F,d5=F,d6=F,d7=C2,d8=C2|S4=F,S5=F,S6=F,S7=F,S8=F,S9=C2,S10=C2. |

Thus old header h1=F/F,h2=F/C4,h3..h5=C4/C4; old h5 updates onlyD->0
for h7. Recovery does not carry either old S6=C4 or old S7=C3 into the new
pipeline. New main headers h4..h6=F/F,h7=F/C2,h8=C2/C2. At new h6, the
FinalizeBlock updates compare S7=F with S8=C2: remove all F keys, add C/D.
The without-disable h5 header is F/C4, not F/C2. The no-code h6 branch's h7
header is F/F, h8 is F/C2. No first-two/current-next off-by-one found.

Every parent commit in main belongs to the previous height's actual set; new
g1 h4 has no LastCommit at all. Its old c3 Comet header is a proof boundary,
not a parent committee. Current admission at old h6 and no-max new h6 is2/4
and fails; F admission is4/4, final C2 is2/2, and single-A probes use3/4.
Rejected current quorum never applies an offered LastCommit's misses first.

Future-reference proof tables (not part of this stage) remain consistent with
the corrected sets: old p0..h3 requires commits2,3; new main p3/p5/p6..h8
requires7,8. Changing source labels origin-F to fallback-F adds no extra one.

No new external premise was introduced by this correction. The only behavior
parameter change is4Q->3Q for the initial threshold; the rest is manual
source arithmetic and full table inspection. Independent finder re-check is
still owned by the root before authoring begins.
