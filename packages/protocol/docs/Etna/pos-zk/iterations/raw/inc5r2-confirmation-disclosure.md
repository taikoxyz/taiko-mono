# Increment 5 round 2 (confirmation) — register, disclosures and course

**Angle.** Confirm the round-1 sweep: every live name registered with a unit, an owner and a tag; the
register passing in both directions; the six F-GOV falsifiers carrying the two-class convention (no
"implementation-verified" read as a third class); the window relation and the trigger floor symbolic and
unmeasured everywhere; the course teaching the shipped rule with no review identifiers, finding names or
decision-log language and no surviving pre-revival sentence; the deferred set one mechanism plus the
rotation everywhere; and the rebased requirements document keeping every added threat visible with its rule
or limitation entry named. Round charge: the four named seams measured, not read.

**Snapshot.** `f29e33cc1` (tree at the snapshot; the working tree has since moved — `d7a1d67b5` and later
round-2 commits, with `learn/04` and `learn/08` still modified in flight). Every measurement below is taken
at `f29e33cc1` and I state where the tree has since closed an item.

**Result: 0 Critical, 0 High, 3 Low — a CLEAN round at the bar; the increment is safe to ship.** The three
Lows are text-only and all three are already on the lead's sweep list or a one-clause fix: the course's
pre-revival sentences (in flight), the F-GOV class carry in two summaries, and one stale justification
sentence in `spec/06`. All four charged seams measure clean.

---

## The four charged seams, measured

1. **The reproduced D-19 agrees with `DECISIONS.md` character for character.** `DECISIONS.md`'s D-19 entry
   (122 lines) against the delta's marked block (`<!-- BEGIN QUOTED D-19 -->` … `<!-- END QUOTED D-19 -->`,
   lines 990–1109): whitespace-stripped **8,992 non-space characters on both sides**, markdown-emphasis
   -stripped **8,632 on both sides**, and the block **contains D-19 character-for-character and is contained
   by it** (the normalised strings are identical). The one disclosed difference is the four-space
   indentation of D-19's heading line, stated as such (delta 982–987), with "if they differ,
   `DECISIONS.md` governs". Nothing about the decisions is added inside the markers; outside them the
   delta carries only the R5R1-G-02 measurement note (1,636 and 1,613 characters before the correction),
   the governance rule above, and the supersession of the old four-item paraphrase — no decision content
   and no contradiction.
2. **`TimelockNotElapsed` is one name across rule and delta.** Delta §2(c) line 270, the §2(d) transition
   table line 292 and the §3.2 matrix line 512; `spec/06` REC-02 (line 460, "reverts `TimelockNotElapsed`
   before the stored deadline"); `spec/08` GOV-04(c) (line 805) and its transition table (line 811). No
   second name for the pre-deadline case appears in any carrier; the other five errors
   (`NoQueuedEntry`, `EntryAlreadyExecuted`, `EntryPending`, `EntryNotVoid`, `NothingToCancel`) name other
   cases, and the §3.2 matrix now distinguishes `none` → `NoQueuedEntry` from `executed` →
   `EntryAlreadyExecuted`. Note, not a finding: the six error names are L1-contract errors and appear in
   `spec/06`/`spec/08` only — `spec/04`'s interface sketch lists none of them, which is consistent because
   `GOV-04` is owned by `spec/08`; the guest journal carries no error names.
3. **The new `W_root` and `MARGIN` rows give GOV-04(g)'s assertion evaluable operands, and are distinct
   from `MARGIN_D`/`MARGIN_V`.** `spec/09` 185 (`W_root`) and 186 (`MARGIN`): unit *seconds*, owner
   `REC-02` with the relation and the Phase-B measurement named, tag "unmeasured (constructor-asserted
   relation)", and the `MARGIN` row states it "is distinct from the HALT-03 margins `MARGIN_D` and
   `MARGIN_V`, which size the unsettled-depth inequality and are not aliases of it" (`MARGIN_D` 09:148
   seconds; `MARGIN_V` 09:154 L2 blocks). `spec/08` GOV-04(g) (line 818) asserts both constructor
   relations — `T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE` and
   `T_GOV_RESUME ≥ W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` — with every operand now registered; the
   register's measurement row (09:264) names the Phase-B measurement.
4. **The rebased requirements document describes the design that exists, with every added threat visible.**
   `01-requirements-and-threat-model.md`: "no recovery path"/"no recovery of any kind" occurrences = **0**;
   `A-GOV-2` re-scoped ("clearing a settlement stall depends on governance queueing and executing the
   `GOV-04` action, with no protocol-level bound … the procedure is specified", line 135); the added
   threats are visible with their entries named — governance liveness (`GOV-04`(i), `REC-03`, **F-GOV-1**,
   line 205), the unprotected class above the checkpoint (`GOV-04`(f), `REC-02`/`REC-03`, line 206),
   governance churn (**F-GOV-3**, `GOV-04`(i), line 207), arrivals exceeding the forceable drain
   (**F-FI-2**, `LIVE-04`/`LIM-01`, line 208) and the enumeration residual (**F-FI-8**, `LIVE-04`/`LIM-01`,
   line 209) — plus the forced-inclusion restatement (line 204). The `(R5R1-NR-01: …)` provenance notes are
   that document's established style, not the course's.

## Findings

### INC5R2-RDC-01 — Low — the course still carries the three pre-revival sentences at the snapshot (round-1 RDC-02; the fix is in flight in the working tree).

**File + rule id.** `learn/08-when-things-go-wrong.html` 100 — "**no v1 rule discards this range**, and none
makes it settled; the chain simply stops producing" — and 103, "no progress … **until a future update**", in
the halt figure whose other lines already describe the resolution (106, 111–113); `learn/04-staking-and-epochs.html`
352–354 — "… has no replacement set in v1, and **clears only if that cohort returns or a future update
changes the rules**". Rule: `spec/08` GOV-04; `spec/06` 460–465; the same course page's own lines
(`learn/08` 82, 258) say the opposite.

**Assumptions.** The course moves with the specification and teaches the shipped rule in the present tense.

**Attack trace (reader-facing).** A learner reads in one figure that no v1 rule discards the range and that
progress waits for a future update — the withdrawn claim the increment removed from the spec — while the
figure's own caption says an executed resolution advances the generation and the discarded branch can never
land.

**Fault-model verdict.** Not applicable (course text; the normative rule is correct).

**Attacker cost.** None.

**Requirement affected.** GOV-04; REC-02; course-to-rule consistency.

**Evidence and status.** Snapshot `git show f29e33cc1:learn/08…` lines 100/103 and `…learn/04…` line 353.
In the working tree the sweep rewrites both: `learn/08` line 102 now reads "the range is never settled; an
executed stall resolution is the one rule that replaces it, and nothing at or below the checkpoint is
touched" and line 105 "until a resolution runs"; `learn/04` 353–357 now states the committed roster is
immutable and the range above the checkpoint is "replaced only by an executed stall resolution", followed by
a sentence beginning "Corrected: this sentence previously said…" that carries no review identifier. Fix:
land that sweep; optionally drop the "Corrected:" sentence in `learn/04`, which is history rather than
teaching (no rule requires it, and it is the only meta-text in `learn/`).

### INC5R2-RDC-02 — Low — the F-GOV class carry still drops `Open` for F-GOV-5/F-GOV-6 in two summaries (round-1 RDC-03, still open at the snapshot).

**File + rule id.** `spec/index.html` 448 — "(F-GOV-1 and F-GOV-2 Open; F-GOV-3 and F-GOV-4 disclosed;
**F-GOV-5 and F-GOV-6 implementation-verified**)" — and `spec/06-recovery-exceptions.html` 488 —
"`Open` on F-GOV-1 and F-GOV-2, disclosed on F-GOV-3 and F-GOV-4, **implementation-verified on F-GOV-5 and
F-GOV-6**". The carriers say otherwise: `spec/10` 314 — "F-GOV-5 (**Open**, implementation-verified)",
"F-GOV-6 (**Open**, implementation-verified)"; the delta §7.1 (717–718) — both "**Open**
(implementation-verified)"; `DEFERRED.md` 262 — "**F-GOV-5**, **F-GOV-6** (Open, implementation-verified)".
The convention is stated once and is two-class (`PLAN.md` 47–49: "**Open** is what the design says of a
premise no rule closes whose falsification would be a defect; **disclosed** is what it says of an inherent
limit, and F-FI-2 is the former"), so "implementation-verified" is a closure means, not a third class.

**Assumptions.** The index and REC-03's status line summarise the classes; `spec/10` and the delta are
canonical for the six.

**Attack trace (reader-facing).** A reader takes F-GOV-5/6 as a third class, so the two
implementation-verification requirements drop out of the Open set the increment claims to carry — the
reading the lead's charge asks to exclude.

**Fault-model verdict.** Not applicable (summary class word).

**Attacker cost.** None.

**Requirement affected.** The F-GOV class carry; `LIM-01`; `PLAN.md` 47–49's convention.

**Evidence.** `spec/index.html` 448; `spec/06` 488; `spec/10` 314; delta 709–718 and 1091; `DEFERRED.md`
257–264. Fix: "F-GOV-5 and F-GOV-6 Open (implementation-verified)" in both summaries.

### INC5R2-RDC-03 — Low — one live sentence gives a false reason for a true rule: "the live inclusion obligation reads no recovery mechanism, because v1 has none".

**File + rule id.** `spec/06-recovery-exceptions.html` 100. The conclusion (the FI family reads no recovery
mechanism) is true and stated operatively by `FI-14`(2)'s non-interaction clause; the justification is now
false, because v1 has the executed stall resolution of `GOV-04` — the obligation simply does not read it.

**Assumptions.** Current-state sentences must match the shipped design; D-19 revives `GOV-04`.

**Attack trace (reader-facing).** A reader who follows the reason concludes v1 has no recovery mechanism at
all, contradicting `GOV-04`, `REC-02`–`REC-04` and the index's REC-03 row (the "no recovery path"
survivor class the lead asked to be driven to zero — this is the last live specimen in the rule pages).

**Fault-model verdict.** Not applicable (prose justification; the normative clause is `FI-14`(2)).

**Attacker cost.** None.

**Requirement affected.** `FI-14`(2); `GOV-04`; the "no recovery path" sweep.

**Evidence.** Snapshot `spec/06` 100 (unchanged in the tree). Fix: "…reads no recovery mechanism: the
forced-data register, the settlement frontier and the deletion-only prune … no rule of the FI family reads,
writes or is discharged by a recovery, a stall resolution or a restored checkpoint".

## Round-1 items re-checked (status at the snapshot, and where they are now)

| Round-1 item | At `f29e33cc1` | In the tree |
|---|---|---|
| Delta's D-19 reproduction (R5R1-G-02) | **closed** — 8,992/8,992 non-space, contained character-for-character | closed |
| Delta's two error tables (R5R1-NR-04) | **closed** — §3.2 now `none`→`NoQueuedEntry`, `executed`→`EntryAlreadyExecuted` | closed |
| `TimelockNotElapsed` name | **closed** — delta + `spec/06` + `spec/08` | closed |
| `W_root`/`MARGIN` rows | **closed** — 09:185/186 with unit, owner, tag | closed |
| Requirements rebase (`R5R1-NR-01`) | **closed** — five threats added, "no recovery path" = 0 | closed |
| Index slot-268 line (`R5R1-NR-03`) | **closed** | closed |
| `CONVERGENCE.md` 68–69 sentence | **closed** ("The second absence is now addressed in draft") | closed |
| `PLAN` increment-4 marks and order line | open (39 "IN REVIEW"; 62 "increments 4 and 5 … in review") | **closed** (39 "SHIPPED"; 62 "increments 2 and 4 are shipped") |
| `DEFERRED.md` §1 body under its SHIPPED header | open (10–11 "The increment is in review") | **closed** |
| Course pre-revival sentences (RDC-02 above) | open | fix in flight (`learn/04`, `learn/08` modified) |
| F-GOV class carry (RDC-03 above) | open | open |
| `spec/06` 100 reason (RDC-04 above) | open | open |

## Verified (my angle, at the snapshot)

1. **The register passes in both directions for every increment-5 name.** Rows exist with a unit, an owner
   rule and a tag: `lastAcceptedBatchTime` 182, `T_STALL_GOV` 183, `T_GOV_RESUME` 184, `W_root` 185,
   `MARGIN` 186, the entry fields `govResumeQueuedAt`/`govResumeQueuedHeight`/`govResumeState` 187 (one
   row, three names, units "unix seconds, L2 height, enumeration"), `govResumeExecutableAt` 188,
   `recoveryGeneration` 179; the withdrawn names keep their tombstone rows with MUST-NOT-USE reasons
   (`T_STALL` 164, `T_RECOVERY_MARGIN` 165, `T_RECOVERY_DELAY` 166, `B_REC_BASE` 167, `resumeHeight`
   180); the index's gov map (511) lists the six live names; the owner citations resolve to rule text
   (`GOV-04` clause letters exist in `spec/06`; `REC-02`, `L1-13`(2)–(3), `MIG-02`, `PRF-02` are live).
   No orphan and no unregistered read found; the `k` in `W_root`'s prose is the registered
   `K_PROOF_BACKENDS` shorthand (09:205).
2. **The window relation and the trigger floor are symbolic and unmeasured everywhere, with no value
   invented.** `spec/09` 183–186, `spec/06` 463, `spec/08` 817–818, `spec/10` 314 (F-GOV-2), the index
   511 ("stated symbolically only"), `DEFERRED.md` 214–264, D-19 (872), the delta (§4.2, §7.1, §11) and the
   course all carry the two relations as constructor-asserted and unmeasured; a search for numeric values
   near the parameters (days, weeks, 604800, 172800, 86400) returns nothing in the spec.
3. **The six F-GOV classes are otherwise consistent and the convention is applied**: F-GOV-1 Open, F-GOV-2
   Open, F-GOV-3 Disclosed, F-GOV-4 Disclosed, F-GOV-5/F-GOV-6 Open (implementation-verified) in `spec/10`
   314, the delta 709–718, `DEFERRED.md` 257–264, and the course — subject only to RDC-02 above; the
   two-class convention is stated once (`PLAN.md` 47–49) and the Open entries are premises no rule closes.
4. **The deferred set is one mechanism plus the rotation everywhere**: `DEFERRED.md` 5 ("**Two deferred
   items remain** … the heartbeat rotation (`CONS-16`, §2) and aggregation (§4)"), the index 42, `spec/10`
   31 ("Two mechanisms remain deferred … the heartbeat's rotation … and aggregation: the governance stall
   resolution is instead live"), `CONVERGENCE.md` 76 ("ONE mechanism plus the rotation within increment 2"),
   `PLAN.md` 27–28, D-19 (842–843) and the rebased requirements document; the course says it too
   (`learn/04` 278: "Rotation is not a recovery path, and it stays deferred: the one rule that can replace
   history above the latest checkpoint accepted on Ethereum is the stall resolution").
5. **The course is otherwise present-tense and clean of decision-log language.** `learn/08` 64–84, 106,
   111–115 ("One rule can clear a stall, and it is not automatic"; "Nothing obliges governance to act";
   "nothing at or below 800 is ever rewritten"), `learn/04` 350–356, `learn/01`, `learn/09`,
   `learn/limitations`, and the glossary's Settlement stall / Stall resolution / Recovery generation / Safe
   halt entries; a grep of `learn/` for review identifiers (`R5R1`, `R5R2`, "finding", "review round"),
   `D-15`/`D-19`, "decision log" and "increment 05" returns **no review identifiers, finding names or
   decision-log language**; no "free balance", no "void individually" and no record-level stale forms.

## Ship decision

**0 Critical, 0 High, 3 Low — clean at the bar, and the increment is safe to ship.** The four charged seams
measure exact: D-19 is reproduced character-for-character (8,992 = 8,992 non-space) with nothing added about
the decisions, `TimelockNotElapsed` is one name across the delta and both rule pages, the `W_root`/`MARGIN`
rows make `GOV-04`(g)'s constructor assertion evaluable and are explicitly distinct from
`MARGIN_D`/`MARGIN_V`, and the requirements baseline is rebased with the five added threats visible and
"no recovery path" at zero. The three Lows are text-only: one course sweep in flight, one class word in two
summaries, and one stale justification clause in `spec/06`. No rule, proof or fund path depends on any of
them, and no specification file was edited by this review.
