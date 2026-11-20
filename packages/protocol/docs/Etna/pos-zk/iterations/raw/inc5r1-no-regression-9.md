# Increment 05 — round 1: no regression in the shipped artifact

Snapshot `1cd1dd6af`. Read first: `increments/05-governance-design.md` (966 lines, all sections and §11),
`DECISIONS.md` D-19/D-15/D-16, `DEFERRED.md` §§1–3, `iterations/raw/round6-gov-generations.md`, then the
current `spec/06` REC-01..REC-04/HALT/WH rows, `spec/08` GOV-01..GOV-04/MIG-02, `spec/02` CONS-01/04/05/
08/10/12/16, `spec/03` MEM-13/MEM-15, `spec/04` L1-05/L1-06/L1-13/FI-13/FI-14/MSG-03, `spec/05`
PRF-01..PRF-05, `spec/09`/`spec/10`/`spec/index.html`, and all 14 course pages.

**Severity counts: 0 Critical, 0 High, 2 Medium, 3 Low. The mechanism's shipped text is sound — the
un-tombstoning is exactly the named set, the state machine's arithmetic is right, and no v1/increment-2/
increment-4 rule changed semantics outside the delta's declared list — but the artifact is not yet clean:
the requirements/threat-model document still describes the pre-revival v1 (eight "no recovery path" and
eleven "deferred by D-16" statements, three of them about `GOV-04` and three about "no inclusion
obligation"), and the window relation's two named terms have no register rows. Fix the two Mediums; the
three Lows are copy edits.**

---

## R5R1-NR-01 — Medium — the requirements and threat-model document still states the pre-revival positions for both the stall resolution (increment 5) and narrow forced inclusion (increment 4, already shipped)

*Rationale: the document's own header says "Where this document and the specification disagree, the specification wins and this document must be corrected." It disagrees on two shipped mechanisms. Measured in the current file: **11** occurrences of "deferred by D-16", **3** of "`GOV-04` is deferred", **3** of "no inclusion obligation", **1** of "not normative in v1" and **8** of "no recovery path". These are not historical notes: they are the present-tense requirement, assumption and threat statements (A-GOV-1, A-GOV-2, R2, R10, the role list, the Mode B 4b table row, §6.3's threat list and §7's item-5 disposition).*

- **File + rule id.** `01-requirements-and-threat-model.md` (Phase-1 document; the specification's
  assumption set and R-rows reference it). Specifically: A-GOV-1 ("the stall resolution of `GOV-04` is
  deferred by D-16"), A-GOV-2 ("**Clearing a settlement stall depends on a future protocol update** …
  the former governance-liveness … assumption is withdrawn with the deferred `GOV-04`"; "v1 has no
  recovery path of any kind"), the DAO role line, table row 4b, §6.3 ("the governance replacement is
  deferred by D-16 — so the exposure is an unbounded halt"; "forced-inclusion exploitation … not
  applicable in v1, where the narrow forced-inclusion machinery is deferred by D-16"), R2, R10 ("v1 has
  **no inclusion obligation** … is not normative in v1 and MUST NOT be implemented"), and §7's Mode B
  item 5.
- **Assumptions.** None. **Attack trace.** None (documentation); the effect is that the requirements and
  threat model the review protocol still cites tells a reader that the two revived mechanisms do not exist.
- **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** The document's own correction rule; the split-brain check; the increment-4
  and increment-5 revivals' disclosure chain.
- **Evidence.** The measured counts above; the specific sentences quoted. **Fix:** re-base each statement to
  the shipped state (the one named runtime governance action is `GOV-04`, with its trigger, stored
  timelock, consumed entry and resume-only effect; a narrow inclusion obligation is live as `FI-10`–`FI-14`),
  or mark the document as the Phase-1 record with an explicit "superseded by increments 02/04/05" banner.

## R5R1-NR-02 — Medium — the window relation's terms `W_root` and `MARGIN` have no register rows (flag 2 confirmed)

*Rationale: the register's `T_GOV_RESUME` row states the constructor-asserted relation `T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`, and `GOV-04(f)/(g)` repeat it, but neither `W_root` nor `MARGIN` has a row in the parameter table. PARAM-01 requires every parameter to appear "with: its identifier, unit, proposed value or formula, the derivation or source, and a tag". `W_root` is a derived bound (the unregistered `itemGasBound`/`batchGasCapacity` are the precedent, so it is defensible), but `MARGIN` is described as "a stated, unmeasured margin whose contents … are left to Phase B" — a parameter, and the register's own treatment of the sibling margins `MARGIN_V` and `MARGIN_D` (both have rows, both unmeasured) shows the discipline it should follow.*

- **File + rule id.** `spec/09-parameters.html` (the `T_GOV_RESUME` row names the relation; no `W_root` or
  `MARGIN` row) against `PARAM-01`; `spec/08` GOV-04(f)/(g).
- **Assumptions.** None. **Attack trace.** None (register completeness). The consequence is that an
  implementer cannot find the unit, tag or fixing experiment for a term the constructor must assert.
- **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** PARAM-01's discipline; the "constructor-asserted relation" obligation of
  GOV-04(g).
- **Evidence.** Measured: `itemGasBound` no row, `batchGasCapacity` no row, `W_root` no row, `MARGIN` no
  row; `MARGIN_V` and `MARGIN_D` have rows. **Fix:** add a row for `MARGIN` (unit: seconds; unmeasured;
  the experiment that fixes it) and either a row or an explicit "derived, not registered" note for
  `W_root` alongside `itemGasBound`'s treatment.

## R5R1-NR-03 — Low — the index still says MIG-02 slot 268 holds "generation and paramVersion only" (flag 3 confirmed)

*Rationale: `spec/08` states that the revived entry fields — `recoveryGeneration`, `govResumeQueuedAt`, `govResumeQueuedHeight`, `govResumeExecutableAt` and `govResumeState` — are grouped at slot 268 and that the packing and the declaration count MUST be re-derived by the migration audit and MUST NOT be assumed. The index's parameter-map line still reads "MIG-02 slot 268 (generation and paramVersion only)", the pre-increment-5 shape, so the same page calls the entry records live and slot 268 unchanged.*

- **File + rule id.** `spec/index.html` (recoveryGeneration map row: "The govResume queued-entry records
  are live registrations of the revived action 09; **MIG-02 slot 268 (generation and paramVersion only)**")
  against `spec/08-migration-upgrades.html` MIG-02's re-derivation notes.
- **Assumptions.** None. **Attack trace.** None. **Fault-model verdict.** Not applicable. **Attacker cost.**
  None.
- **Requirement affected.** The flag-3 obligation ("slot 268's obligation must be stated consistently
  wherever the migration budget is described").
- **Evidence.** The two sentences quoted; `spec/09`'s `govResumeExecutableAt` row agrees with `spec/08`
  ("the migration audit owns its storage layout and MUST NOT assume it fits the preserved slot-268 packed
  word"). **Fix:** change the index line to "slot 268 (the generation, paramVersion and the live
  `govResume*` entry fields; layout to be re-derived)".

## R5R1-NR-04 — Low — the delta's two transition tables name the `executed`-state `execute()` differently (flag 1 confirmed)

*Rationale: §2(d)'s table (and the shipped rule, `spec/08` GOV-04(d)) use `EntryAlreadyExecuted` for `execute()` from `executed`, and `NoQueuedEntry` for `execute()` from `none`; §3.2's transition table groups "none, executed | execute() | — | reverts `NoQueuedEntry`". The two tables therefore give an implementer two names for the executed case. (The shipped spec is internally coherent — it uses the two names for two states — so this is a delta drift, not a rule contradiction.) `TimelockNotElapsed` compounds it: it is named only in §3.2, while the shipped rule's (c)/(d) state the revert without an error name.*

- **File + rule id.** `increments/05-governance-design.md` §3.2 vs §2(d); `spec/08` GOV-04(d).
- **Assumptions.** None. **Attack trace.** None. **Fault-model verdict.** Not applicable. **Attacker cost.**
  None. **Requirement affected.** The delta's "one obligation, one statement" discipline.
- **Evidence.** Measured counts: `EntryAlreadyExecuted` spec 1 / delta 1; `NoQueuedEntry` spec 1 / delta 2;
  `TimelockNotElapsed` delta 1 / spec 0. **Fix:** make §3.2's row "none → NoQueuedEntry; executed →
  `EntryAlreadyExecuted`" and name the too-early revert consistently in both.

## R5R1-NR-05 — Low — two live sentences still call the revived `REC-02` a tombstone

*Rationale: `REC-02` is live again (`spec/06`, 14,664 characters) and no longer in the tombstone set, but `spec/02`'s CONS-04 says in live prose "no element of the **tombstoned REC-02** is needed to state it" (the following sentence is a historical round-8 note, which is fine), and `spec/07`'s withdrawn-parameter list keeps "`REC-02` (withdrawn; D-16 tombstone) — Withdrawn as the sizing target of the non-refundable bond component".*

- **File + rule id.** `spec/02-consensus.html` CONS-04; `spec/07-economics-slashing.html` (withdrawn-parameter
  rows).
- **Assumptions.** None. **Attack trace.** None. **Fault-model verdict.** Not applicable. **Attacker cost.**
  None. **Requirement affected.** The un-tombstoning consistency of the revival.
- **Evidence.** The two sentences quoted; the tombstone classifier no longer lists `REC-02`. **Fix:** "the
  tombstoned REC-02" → "the former REC-02 tombstone (revived by increment 05)" in 02, and in 07 attach
  "withdrawn" to the sizing duty rather than to the rule id.

---

## Verified: the un-tombstoning is exactly the named set, and the arithmetic is right

- **Tombstone classifier (161 rule divs):** the remaining tombstone-classified rules are `CONS-16`,
  `L1-14`, `PRF-15` and the live rejected-alternatives rule `LIM-02` (text heuristic). `GOV-04`,
  `REC-02`, `REC-03` and `REC-04` have left the set — **exactly** the delta's named rule set; `CONS-16`
  stays a tombstone (and gained only the live-`queued`-only exclusion note), the withdrawn recovery-bond
  names stay withdrawn, and no other rule was un-tombstoned.
- **Headers and counts in the revived rules:** GOV-04(b) says "exactly three values: none, queued,
  executed" and names four stored fields; GOV-04(c) says the generation is incremented nowhere else and
  only on a successful `execute()`; the (d) table has the four state rows with generation unchanged / +1
  exactly once / unchanged / unchanged; the falsifier set is F-GOV-1…F-GOV-6 with the Open/disclosed split
  the delta records.
- **Scope of change since the increment-4 ship (`e6f650541`):** the rule-level diff lists the changed
  rules, and each maps to an item of the delta's §9 ("what this increment changes outside the revived
  rules", items 1–15 made, item 16 the review test obligation). Spot-checked by word diff: **FI-14** gained
  the "resolution non-interaction clause" only; **CONS-01** re-based the "v1 has no resumed chain" sentence
  to the revived linkage with no new offence; **MEM-13** gained the generation-independence note (§9 item 6
  says "no change; record in the rule's notes" — matched); **FI-13** gained only a review-round-5 note, no
  semantic change. No v1, increment-2 or increment-4 rule changed semantics outside that declared list.
- **Split-brain search:** outside the requirements document (R5R1-NR-01) and the two `REC-02` sentences
  (R5R1-NR-05), the spec, `DEFERRED.md` (which now counts two deferred mechanisms plus the rotation),
  `CONVERGENCE.md` (whose increment-5 note says one mechanism plus the rotation), `DECISIONS.md` D-19 and
  `spec/index.html` all describe the revival consistently; the remaining "deferred" mentions are historical
  records or the still-deferred `CONS-16`/aggregation.

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + 14 course pages) | **4,737 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier | 4 remaining (`CONS-16`, `L1-14`, `PRF-15`, heuristic `LIM-02`); the revived set is out, exactly as named |
| Register orphan audit (both directions) | 93 rows; **no** live-marked row without a live-rule consumer (the earlier `DRAIN_DEADLINE` case is now consumed) |
| Index rule-index and parameter map | every rule id indexed (0 missing); the `govResume*` names and `govResumeExecutableAt` present; one stale slot-268 line (R5R1-NR-03) |
| Course scan | **0 review identifiers**; the course teaches the revived action without the withdrawn "every user can exit" claim |

## Fault-model verdict

No Critical and no High: no seam pair is individually true and jointly false, and the state machine,
the generation write, the window scope and the two-case certificate rule are stated consistently in the
shipped rules. The findings are documentation and register completeness.

## Is the increment safe to ship?

**Not yet clean — but the mechanism is sound.** There is no Critical and no High, so the revival is not
blocked by the bar; fix the two Mediums (the requirements-document split-brain, R5R1-NR-01, and the
register rows for the window relation's terms, R5R1-NR-02) and the three Lows are copy edits.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 2 | R5R1-NR-01, R5R1-NR-02 |
| Low | 3 | R5R1-NR-03, R5R1-NR-04, R5R1-NR-05 |
