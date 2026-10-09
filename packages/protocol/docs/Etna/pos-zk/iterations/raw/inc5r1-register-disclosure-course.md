# Increment 5 round 1 — register, disclosures and course

**Angle.** Every live name registered with a unit, an owner rule and a tag; the register passing in both
directions after the revival (no orphan, no unregistered read); the six F-GOV falsifiers carrying the right
Open/disclosed class with the convention stated once; the window relation symbolic and unmeasured with no
value invented; the course teaching the shipped rule in plain present tense with no review identifiers,
finding names or decision-log language; the deferred set reading one mechanism plus the rotation everywhere
with no surviving "no recovery path" claim; and the three flags carried into the round.

**Snapshot.** `1cd1dd6af`. The working tree moved during the round: peers' round-1 reports
(`inc5r1-boundary-and-shipped.md`, `inc5r1-governance-mechanism.md`, `inc5r1-no-regression-9.md`) and
commits `040684cc5`, `228f44f55`, `3c936e7bd` (which added the two `W_root`/`MARGIN` rows to
`spec/09`, ten PLAN lines and fifteen delta lines). Every measurement below is taken at the snapshot and
I state the post-snapshot state where it differs.

**Result: 0 Critical, 0 High, 1 Medium, 3 Low — clean at the bar; the increment is safe to ship.** The
Medium is the round's flag 2 (the window relation's terms with no register rows), real at the snapshot and
already closed in the working tree by the added rows. The three Lows are carrier text: the course's
pre-revival sentences, the F-GOV class carry in two summaries, and four stale post-revival/post-ship
sentences. No rule, proof or fund path depends on any of them.

---

## INC5R1-RDC-01 — Medium (flag 2, confirmed; closed post-snapshot) — `W_root` and `MARGIN` are terms of a constructor-asserted relation with no register rows at the snapshot, while the delta claims each has one.

**File + rule id.** `spec/09-parameters.html` at `1cd1dd6af`: no row begins `<code>W_root</code>` or
`<code>MARGIN</code>` (the only `margin` row is the lowercase lookahead margin, 09:112, owned by MEM-09/
CONS-13 and unrelated). The relation is live and constructor-asserted: `spec/09` 184 — "`T_GOV_RESUME ≥
W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`, where `W_root` is the worst-case time to produce and record
the checkpoint's k withdrawal-root attestations; every term is unmeasured and `MARGIN` is a stated,
unmeasured margin … The relation is a constructor-time assertion: an implementation MUST refuse to
initialise unless it holds" — and `spec/06` 463 states the same. The delta §4.2 goes further and claims
registration: "**Every term is registered in `spec/09`'s parameter table: `W_root` and `MARGIN` each have
their own row there, with `REC-02` as owner and an unmeasured tag**, alongside `WITHDRAWAL_DELAY` and
`T_VETO`" (delta lines 576–579) — false at the snapshot.

**Assumptions.** PARAM-01's discipline ("Every protocol parameter appears in the table below with: its
identifier, unit, proposed value or formula, the derivation or source, and a tag"; 09:16–20) covers terms
of registered relations, as the register's own practice shows (the lowercase `margin`, `E_EPOCH_L1`,
`free_before(e)` all have rows). `REC-02`/`GOV-04(f)` own the window.

**Attack trace (implementer/auditor-facing, no adversary).** An implementer who must assert the relation at
construction has no row to look up: no unit, no owner, no tag, and no measurement pointer for `W_root` or
`MARGIN` — the exact lookup the delta promises works. An auditor sweeping the register for unregistered
reads finds two; and `MARGIN` differs from the registered `margin` only by case, which is the
alias-ambiguity class PARAM-01 exists to prevent.

**Fault-model verdict.** Not applicable: register discipline and a false delta claim; no rule reads the
register and no value is invented.

**Attacker cost.** None.

**Requirement affected.** PARAM-01; `T_GOV_RESUME`'s constructor-asserted relation; `GOV-04(f)`;
`REC-02`; the delta's §4.2 registration claim.

**Evidence.** Snapshot `git show 1cd1dd6af:spec/09-parameters.html` — no `W_root`/`MARGIN` row;
09:184, 09:112, 09:262 (measurement row naming both terms); `spec/06` 463; delta 566–579; index 511 (the
gov set list omits both). **Post-snapshot:** `3c936e7bd` adds both rows (09:185 `W_root`, 09:186
`MARGIN`: unit seconds, tag "unmeasured (constructor-asserted relation)", owner `REC-02`, the relation and
the Phase-B measurement named, and `MARGIN` explicitly distinguished from `MARGIN_D`/`MARGIN_V`), so the
gap is closed in the working tree; the delta's claim is now true.

## INC5R1-RDC-02 — Low — the course still teaches the pre-revival model in three sentences: no v1 rule discards the provisional range, and a stall clears only by a future update.

**File + rule id.** `learn/08-when-things-go-wrong.html` line 100 (the halt figure): "**no v1 rule discards
this range**, and none makes it settled; the chain simply stops producing"; line 103: "no progress … **until
a future update**"; `learn/04-staking-and-epochs.html` lines 352–354: "a chain stalled inside an epoch whose
committed roster cannot form quorum has no replacement set in v1, and **clears only if that cohort returns or
a future update changes the rules**". The same figure's other lines are updated — 106 ("the recovery
generation advances only when a stall resolution executes … nothing is retired"), 111 ("A stalled chain
resumes only when a stall resolution is executed"), 113 ("an executed stall resolution advances it by one,
so the discarded branch can never land") — and `learn/08` 82 and 258 say the opposite of line 100 ("One rule
can clear a stall, and it is not automatic. The stall resolution is the only route …"; "the only rule that
discards it is an executed stall resolution, which discards the whole range and resumes from the
checkpoint"). The rule: `spec/08` GOV-04 and `spec/06` 460–465.

**Assumptions.** The course must teach the shipped rule in the present tense; the standing rule that the
course moves with the specification.

**Attack trace (reader-facing).** A learner reads in the same figure that no v1 rule discards the range and
that progress waits for a future update, contradicting the live DAO-queued resolution — the withdrawn
"clears only by a future protocol update" claim the increment removed from the spec. No adversary needed.

**Fault-model verdict.** Not applicable (course text; the normative rule is correct).

**Attacker cost.** None.

**Requirement affected.** GOV-04; REC-02; the course-to-rule consistency for the stall resolution.

**Evidence.** `learn/08` 100, 103 (vs 82, 106, 111–113, 258); `learn/04` 352–354; `spec/08` GOV-04;
`spec/06` 460–465. Fix: three sentences in the present tense — the stall resolution is the one v1 route,
and the range above the checkpoint is discarded by an executed resolution, not by a future update.

## INC5R1-RDC-03 — Low — the index and the recovery rule's status line drop the Open class for F-GOV-5 and F-GOV-6, implying a third class the convention does not have.

**File + rule id.** `spec/index.html` 448: "its falsifiers are the F-GOV-1…F-GOV-6 set carried in 10
(**F-GOV-1 and F-GOV-2 Open; F-GOV-3 and F-GOV-4 disclosed; F-GOV-5 and F-GOV-6
implementation-verified**)". `spec/06-recovery-exceptions.html` 488: "Open on F-GOV-1 and F-GOV-2,
disclosed on F-GOV-3 and F-GOV-4, **implementation-verified on F-GOV-5 and F-GOV-6**". The carriers say
otherwise: `spec/10` 314 — "**F-GOV-5 (Open, implementation-verified)** … **F-GOV-6 (Open,
implementation-verified)**"; the delta §7.1 (695–700) — both "**Open** (implementation-verified)"; DEFERRED
§3 — "F-GOV-5, F-GOV-6 (**Open**, implementation-verified)". The convention is stated once in `PLAN.md`
47–49: "**Open** is what the design says of a premise no rule closes whose falsification would be a defect;
**disclosed** is what it says of an inherent limit" — two classes, "implementation-verified" being a
closure means, not a class.

**Assumptions.** The index and the rule's status line summarise the classes; the deltas and 10 are
canonical for the six.

**Attack trace (reader-facing).** A reader takes F-GOV-5/6 as a third class ("implementation-verified",
i.e., not Open), so the two implementation-verification requirements drop out of the Open set the increment
says it carries. No rule reads the summary.

**Fault-model verdict.** Not applicable (summary class word).

**Attacker cost.** None.

**Requirement affected.** The F-GOV class carry; LIM-01; the Open/disclosed convention in PLAN 47–49.

**Evidence.** `spec/index.html` 448; `spec/06` 488; `spec/10` 314; delta §7.1; `DEFERRED.md` 262;
`PLAN.md` 47–49. Fix: "F-GOV-5 and F-GOV-6 Open (implementation-verified)" in both summaries.

## INC5R1-RDC-04 — Low — four stale post-revival/post-ship sentences in the sweep's own files.

**File + rule id.**
1. `PLAN.md` 29 — "**Increment 4 - narrow forced inclusion (D-12): IN REVIEW**" — and 52, "Order of work:
   increment 2 is shipped; **increments 4 and 5 are implemented and in review**", while increment 4 shipped
   (`increments/04-ship-record.md` exists; `DEFERRED.md` 7 "REVIVED AND **SHIPPED** (increment 04, see
   increments/04-ship-record.md)"; `CONVERGENCE.md` 60 "Increment 4 - narrow forced inclusion - has since
   SHIPPED").
2. `DEFERRED.md` §1's body under its SHIPPED header (lines 10–11): "The increment is **in review** and
   ships only after two consecutive clean review rounds" — the header was updated, the body was not.
3. `CONVERGENCE.md` 68–69 — the sentence is garbled: "\*\*The other two stand\n> \*\*now addressed in
   draft\*\*: the governance stall resolution (increment 5) is implemented and in review" (two sentences
   merged; the intended reading is "the other two stand unchanged, except that the first is now addressed in
   draft").
4. `spec/06-recovery-exceptions.html` 100 — "The live inclusion obligation reads no recovery mechanism,
   **because v1 has none**": the conclusion (the inclusion family reads no recovery mechanism) is true and
   FI-14(2) states it, but the justification is now false — v1 has the executed stall resolution; the
   obligation simply does not read it.

**Assumptions.** Status lines and current-state sentences must match the shipped state after each
increment; D-19 revives GOV-04 and the increment-4 ship record exists.

**Attack trace (reader-facing).** A reader of PLAN or DEFERRED believes increment 4 is still in review and
that the register's §1 revival is provisional; the 06 sentence gives a false reason for a true rule.

**Fault-model verdict.** Not applicable (status/prose text).

**Attacker cost.** None.

**Requirement affected.** PLAN's increment status; DEFERRED §1's revival record; CONVERGENCE's increment
note; FI-14(2)/06's non-interaction justification.

**Evidence.** `PLAN.md` 29, 52 (snapshot); `DEFERRED.md` 7, 10–11; `CONVERGENCE.md` 60, 68–69;
`spec/06` 100; `increments/04-ship-record.md`.

## Flag items confirmed (already filed by peers; not re-counted)

- **Flag 1 — the two transition tables name one case twice.** The delta §2(d) (line 291) gives the
  `executed`-state `execute()` the error `EntryAlreadyExecuted` ("for every caller, in every block, with
  every calldata"), while §3.2's matrix (line 506) groups "`none`, `executed`" under `NoQueuedEntry`. The
  spec has one scheme and it matches §2(d): `spec/08` 810 (`none` → `NoQueuedEntry`) and 813 (`executed` →
  `EntryAlreadyExecuted`); `spec/06` 460 states the behaviour without naming selectors. The delta's §3.2
  row is the outlier (peers' F2/R5R1-NR-04/R5R1-G-03).
- **Flag 3 — the index's slot-268 claim.** `spec/index.html` 512 says "MIG-02 slot 268 (**generation and
  paramVersion only**)", while `spec/08` 269, 281 and 921 say slot 268 carries the generation **plus the
  live entry fields** (`govResumeQueuedAt`, `govResumeQueuedHeight`, `govResumeExecutableAt`,
  `govResumeState`), with the layout an explicit migration-audit obligation (peer R5R1-NR-03).
- **Register rows for the new names otherwise pass both directions**: `T_STALL_GOV` (09:183),
  `T_GOV_RESUME` (184), `govResumeQueuedAt/QueuedHeight/State` (187), `govResumeExecutableAt` (186),
  `recoveryGeneration` (179) and `lastAcceptedBatchTime` (182) each carry a unit, an owner rule and a tag;
  the withdrawn names stay withdrawn (`T_STALL` 164, `T_RECOVERY_MARGIN` 165, `T_RECOVERY_DELAY` 166,
  `B_REC_BASE` 167, `resumeHeight` 180); the index's gov map (511) lists the six new names; GOV-04's
  clause letters exist in `spec/06`, so the register's owner citations resolve.

## Verified

1. **The window relation is symbolic and unmeasured everywhere, with no value invented.** `spec/09` 184
   and `spec/06` 463 and `spec/08` 817–818, `spec/10` 314 (F-GOV-2), the index 511 ("the window relation
   is stated symbolically only"), `DEFERRED.md` 244, D-19 (872), the delta (§4.2, §7.1, §11) and the course
   all state `T_GOV_RESUME ≥ W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` as a constructor-asserted,
   unmeasured relation; the trigger's floor `T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE` likewise.
   A search for numeric values near the two parameters (days, weeks, 604800, 172800, 86400) returns nothing
   in the spec; the only "days"/"weeks" hits are unrelated budgets.
2. **The six F-GOV classes are otherwise consistent**: F-GOV-1 Open, F-GOV-2 Open, F-GOV-3 Disclosed,
   F-GOV-4 Disclosed, F-GOV-5/F-GOV-6 Open (implementation-verified) in `spec/10` 314, the delta §7.1
   (695–700), `DEFERRED.md` 262 and the index 448 subject to finding RDC-03. The Open/disclosed convention
   is stated once (`PLAN.md` 47–49) and applied: the two Open entries are premises no rule closes
   (governance liveness; the unmeasured window), the two Disclosed entries are inherent limits (churn;
   future-entry parameter discretion).
3. **The deferred set reads one mechanism plus the rotation everywhere**: `DEFERRED.md` 5 ("**Two deferred
   items remain** … the heartbeat rotation (`CONS-16`, §2) and aggregation (§4)"), the index 42 ("two
   mechanisms remain deferred to the register: the heartbeat's rotation … and aggregation"), `spec/10` 31
   ("Two mechanisms remain deferred … the heartbeat's rotation … and aggregation: the governance stall
   resolution is instead live as the protocol's one runtime governance action"), `CONVERGENCE.md` 76 ("the
   deferred set is now ONE mechanism plus the rotation within increment 2"), `PLAN.md` 27–28 (increment 3
   gated on S1), D-19 (842–843: `CONS-16` and aggregation are not revived) and the course (`learn/04` 278
   "Rotation is not a recovery path, and it stays deferred: the one rule that can replace history above the
   latest checkpoint accepted on Ethereum is the stall resolution"; glossary entries 147, 152, 156, 157).
4. **No surviving "no recovery path" claim in the listed files**: `spec/10` 34 explicitly supersedes it
   ("so the earlier 'no recovery path of any kind' statement is superseded"), the index 544 states the one
   exception, DEFERRED §3 and D-19 record the revival, `CONVERGENCE.md`'s converged-state sentence is
   corrected by the note below it, and the course carries the live resolution. The remaining instances are
   the historical records (`DECISIONS.md` D-16, the increment-2/4 deltas) and the stale items in RDC-02/04.
5. **The course teaches the shipped rule and carries no decision-log language**: `learn/08` 64–84 and
   258, `learn/06`, `learn/02`, `learn/limitations`, the glossary's Settlement stall / Stall resolution /
   Recovery generation / Safe halt entries, all in the present tense, with "not automatic", "nothing obliges
   governance to act", the window's scope (class A), the unprotected value above the checkpoint, no bond and
   no new offence; a grep of `learn/` for `D-15`, `D-19`, "decision", "finding", "review round",
   "increment 05" and `F-GOV` returns **no review identifiers, finding names or decision-log language**.
6. **The migration budget and slot 268's obligation**: `spec/08` 269, 281, 325, 393 and 921 state the added
   `govResumeExecutableAt` consistently — the packed group's layout and the declaration count are an
   explicit open obligation of the migration audit, MUST NOT be assumed to fit the preserved 32-byte word,
   and MUST NOT reuse a deprecated slot; the 15-slot/28-free figures are the pre-increment figure. The only
   inconsistent statement is the index's (flag 3 above).

## Ship decision

**Clean at the bar: 0 Critical, 0 High.** The register passes both directions apart from the flag-2 terms,
which the working tree has already closed; the window relation is symbolic and unmeasured everywhere; the
F-GOV classes and the deferred set are consistent; the course is present-tense and free of decision-log
language. **The increment is safe to ship**, with the three Lows as text-only sweeps: three course
sentences (RDC-02), the two falsifier-class summaries (RDC-03), and four stale post-revival/post-ship
sentences (RDC-04) — plus the two open flag items the peers already filed (the delta's §3.2 error name and
the index's slot-268 claim).
