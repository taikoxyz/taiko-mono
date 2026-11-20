# Two recoveries with intervening checkpoint identity overlap (J01)

This thin companion extends the unchanged `EtnaCheckpointIdentity` and executes
its actual actions. It covers the repeated recovery/overlap sub-obligation of
S01/Q01. Concrete client/EL/guest comparison and broad runtime closure remain
WAITING. Injective symbolic tokens, otherwise-valid proofs and cuts, same chain,
atomic authorized recovery, and the finite grid are inherited premises.

## Dispatch and literal observer contract

The exact bounds are height4/generation2/nonce4/time2, Val difference at fork3,
Full boundary checks and every original correctness switch TRUE. `S` means
`(c,generation,nonce,startHeight,now)`; the initial S is `(0,0,0,0,0)`.
`C(g,h,t)` denotes the literal record `{height:h, el:[EL,g,h,Shared],
comet:[Comet,g,h,Shared], fi:0, val:[Val,g,h,t]}`. `P(g,p,h)` is the
present proof record. These are notation for fixed expected data, not engine
oracle getters. The public origin at Prepare3 is C(0,1,Shared); its execution
origin changes only Val to `[Genesis,1]`. Prepare4's public and execution origins
both equal C(1,3,A), since c3 differs from the first generation start1.

| #   | Exact inherited dispatch                  | S before  | S after   | Enabled/executed | Other actual write / frame                                                                                                                                                                               |
| --- | ----------------------------------------- | --------- | --------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | IdentityLandFresh(1,A,A,FALSE)            | 0,0,0,0,0 | 1,0,0,0,0 | T/T              | landing1=(g0,parent0), record/prefix1=C(0,1,Shared), prefixGeneration1=0; lastLanding=(origin0,previous0,terminal1,parent0)                                                                              |
| 2   | Authorize(1)                              | 1,0,0,0,0 | 1,0,0,0,0 | T/T              | authorization=(present,g0,c1,nonce0,deadline1); every identity local unchanged                                                                                                                           |
| 3   | Tick                                      | 1,0,0,0,0 | 1,0,0,0,1 | T/T              | only time; every identity local unchanged                                                                                                                                                                |
| 4   | IdentityRecover                           | 1,0,0,0,1 | 1,1,1,1,1 | T/T              | checkpoint, landed records, retained/prefix cuts, prefix generations, proof/identity unchanged; equality deadline1; recovery audit bits may advance                                                      |
| 5   | PrepareIdentityProof(3,A,A,FALSE)         | 1,1,1,1,1 | 1,1,1,1,1 | T/T              | pending=P(1,1,3); identity as literal above; only prepared inputs change                                                                                                                                 |
| 6   | IdentityLandFresh(2,A,A,FALSE)            | 1,1,1,1,1 | 2,1,1,1,1 | T/T              | landing2=(g1,parent1), record/prefix2=C(1,2,Shared); queued proof/identity immutable; public Val(0,1,Shared) differs from execution Genesis1                                                             |
| 7   | IdentityLand(pendingProof,queuedIdentity) | 2,1,1,1,1 | 3,1,1,1,1 | T/T              | proof parent1<c2<terminal3; actual landing3=(g1,parent2); only prefix3 newly settled C(1,3,A); queued bytes immutable                                                                                    |
| 8   | PrepareIdentityProof(4,A,A,FALSE)         | 3,1,1,1,1 | 3,1,1,1,1 | T/T              | pending=P(1,3,4); identity public=execution=C(1,3,A); only prepared inputs change                                                                                                                        |
| 9   | Authorize(2)                              | 3,1,1,1,1 | 3,1,1,1,1 | T/T              | authorization=(present,g1,c3,nonce1,deadline2); every identity local unchanged                                                                                                                           |
| 10  | Tick                                      | 3,1,1,1,1 | 3,1,1,1,2 | T/T              | only time; every identity local unchanged                                                                                                                                                                |
| 11  | IdentityRecover                           | 3,1,1,1,2 | 3,2,2,3,2 | T/T              | retained landed records and complete settled prefix unchanged; prepared bytes unchanged; equality deadline2                                                                                              |
| 12  | IdentityLand(pendingProof,queuedIdentity) | 3,2,2,3,2 | 3,2,2,3,2 | F/F              | complete original state unchanged; base Land rejects old proof gen1 against current gen2; ExecutionOriginMatches separately requires Genesis1 (proof.generation=1), which differs from queued Val(1,3,A) |
| 13  | IdentityLandFresh(4,B,B,FALSE)            | 3,2,2,3,2 | 4,2,2,3,2 | T/T              | public origin3 remains C(1,3,A), execution uses Genesis2; landing4=(g2,parent3), record/prefix4=C(2,4,B); queued bytes unchanged                                                                         |

The table plus the following complete initial values and deltas reconstructs all
15 raw before/after fields, including unchanged and prepopulated fields:

- `authorization` initially `(present=FALSE,generation=0,checkpoint=0,nonce=0,deadline=0)`;
  its only changes are rows2/9 above.
- `pending` initially `(present=FALSE,generation=0,parent=0,terminal=0)`;
  its only changes are rows5/8 above.
- `landings` initially has height0 present with `(generation=0,parent=0)` and
  heights1..4 absent with those same zero scalar fields. Only rows1/6/7/13
  install the stated present records. All other slots remain byte-identical.
- `lastLanding` initially has `present=FALSE` and all four scalar fields zero.
  Rows1/6/7/13 respectively install present `(proofOrigin,previousC,terminal,recordedParent)`
  tuples `(0,0,1,0)`, `(1,1,2,1)`, `(1,2,3,2)`, `(3,3,4,3)`.
- `records` and `prefix` initially map heights0..4 to
  `[C(0,0,Shared),C(0,1,Shared),C(0,2,Shared),C(0,3,A),C(0,4,A)]`.
  Each accepted row writes only its stated terminal slot in both maps; row7
  writes prefix3 only, and row13 prefix4 only. `prefixGeneration` initially is
  zero at every height; only row6 height2 becomes1, row7 height3 becomes1,
  and row13 height4 becomes2. Prepopulated heights are not historical receipts.
- `queued` initially is A/A with public origin C(0,0,Shared) and execution
  origin equal to it except Val=`[Genesis,0]`. Only rows5/8 replace it.
- The base `audit` initially has all eight bits FALSE. Row4 sets only
  `deadlineEquality=TRUE`; row7 sets only `overlap=TRUE`. Every other row
  retains those bits; `staleGeneration,staleCheckpoint,staleNonce,expired,
oldProof,recoveryChangedC` remain FALSE throughout.
- `identityAudit` initially has all nine bits FALSE. Row4 sets
  `recoveredPositive=TRUE`, row6 sets `reusedOrigin=TRUE`, and row7 sets
  `goodOverlap=TRUE`; all remain TRUE thereafter. The six other fields
  `originFault,cutFault,boundaryFault,recoveryFault,prefixFault,divergentSuffix`
  remain FALSE. Every unspecified field in every row retains its prior value.

For landings, the inherited base audit records overlap/old-proof observations and
the identity audit records its actual observations; these full raw values are
receipted rather than used as the expected history. Frame means every raw field
not assigned by that exact inherited action is unchanged. `RepeatedRaw` explicitly
captures all ten original settlement variables and all five identity variables,
including both audit records, before and after every attempt. Receipts retain the
actual ENABLED result and executed result. The scheduler always executes an enabled
call unless the selected omission explicitly suppresses that action; no expected
mask is consulted by dispatch. Refusals stutter all original variables.

At the full terminal there are exactly13 receipts, two real recoveries, four real
landings, one actual refused old proof, and S=(4,2,2,3,2). Landed heights1..4 have
(generation,actual parent)=[(0,0),(1,1),(1,2),(2,3)]. Their prefix generations are
[0,1,1,2]. Record and prefix EL/Comet tokens use those exact generations, height
and Shared; FI=0. Val tokens are (0,1,Shared),(1,2,Shared),(1,3,A),(2,4,B).
Unlanded prepopulated candidate slots are never accepted as landed evidence.
The old proof refusal does not isolate the generation guard: base Land compares
proof generation1 against current generation2, while ExecutionOriginMatches
compares the unchanged execution-origin Val(1,3,A) against Genesis1 because
proof.parent equals current startHeight and that guard uses proof.generation.
The fresh generation2 proof at step13 instead uses Genesis2. The exact proof/identity remain immutable during both
competing windows (steps5..7 and8..13).

## Profiles and omission semantics

`normal` checks original safety invariants, raw receipt continuity, literal
history and complete terminal. `witness` deliberately violates only
`RepeatedTerminalNotReached` at the complete terminal. `raw-positive` deliberately
violates `RepeatedEndNotReached` after attempt13 to retain the complete history.
`end12` is a PASS absence control: it stops after refusal, before final landing.
The sourcefault profile checks only the immediate raw generation audit, so an
unrelated generic invariant cannot intercept the intended mutation.

| Suppressed call | Actual enabled mask differences from positive                                                  | Expected partial final S and landed evidence                                                                                                                                                          | Required result                                                                |
| --------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| OverlapLand (7) | step7 remains enabled but unexecuted; step12 still disabled; every other call enabled/executed | S=(4,2,2,2,2); no actual landing3; Prepare4 has parent2 and retained C(1,2,Shared), execution C(1,2,Shared); final landing4 parent2; prefix generations [0,1,2,2], prefix3=C(2,3,B), prefix4=C(2,4,B) | complete witness absent; retain real scalar terminal using raw-missing-overlap |
| Recover1 (4)    | step4 remains enabled but unexecuted; step12 still disabled; every other call enabled/executed | S=(4,1,1,3,2); landings1/2/3 use g0, landing4 uses g1; prefix generations [0,0,0,1]                                                                                                                   | complete witness absent                                                        |
| Recover2 (11)   | step11 remains enabled but unexecuted; step12 now enabled/executed; step13 now disabled        | S=(4,1,1,1,2); step12 actually lands A terminal4 in g1 with parent3; prefix generations [0,1,1,1]                                                                                                     | complete witness absent; never force the positive refusal mask                 |

These PASS absence profiles establish witness loss only. They do not certify
successful protocol progress. They still execute every subsequent enabled call.

## Actual-source sensitivity and limits

In a disposable copy of the actual `EtnaSettlement.Recover`, uniquely replace
`generation' = generation + 1` with `generation' = 1`. The first actual
recovery must remain 0->1. The second must execute 1->1 and immediately violate
`RepeatedSecondGenerationAudit`. Run the original and same-copy-restored full
positive/raw histories. Parse, setup, timeout, type and wrong-property failures
have no behavioral credit. An independent behavioral verifier chooses a different
source fault and missing-action challenge; `RepeatedSecondNonceAudit` is an
available immediate nonce oracle, not evidence of a run.

The existing check.py runner recognizes each config's exact expected invariant.
Use the existing offline namespace supervisor with a read-only snapshot and
read-only pinned Java17/TLC1.7.4, clean environment and disposable output. Exact
commands, input/source/tool hashes and actual histories belong in the task report;
no production engine, old config, canonical SPEC or deployment is modified.
