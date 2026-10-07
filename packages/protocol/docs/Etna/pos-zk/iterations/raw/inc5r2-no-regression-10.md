# Increment 05 — round 2, the confirmation round: no regression, by reading and measurement

Snapshot `f29e33cc1`. Read first: all four `inc5r1-*` reports, then `spec/06` GOV-04/REC-01..REC-04/HALT,
`spec/02` CONS-05(2)/CONS-12, `spec/05` PRF-05(ii), `spec/08` GOV-01..GOV-04/MIG-02, `spec/09`'s stall
rows, `spec/10`'s F-GOV carry, `DEFERRED.md` §3, `DECISIONS.md` D-19, `CONVERGENCE.md`, `PLAN.md`,
`01-requirements-and-threat-model.md` and the 14 course pages.

**Severity counts: 0 Critical, 0 High, 0 Medium, 3 Low. No Critical and no High — this is the second
consecutive clean round at the bar: increment 5 reaches 2 of 2 and ships, with the three Lows as copy
edits.** **Strongest attack: none** — no pair of clauses in the repaired seams is individually true and
jointly false. Every round-1 repair is in the text and every quoted or counted claim I measured holds.

---

## R5R2-NR-01 — Low — the course still carries two pre-revival sentences ("no v1 rule discards the unsettled range")

*Rationale: the live `GOV-04` is exactly a rule that discards the provisional range above the last accepted checkpoint. Two learner-facing pages still state the pre-revival absolute, so the course contradicts the shipped rule and the rebased requirements document.*

- **File + rule id.** `learn/08-when-things-go-wrong.html` ("no v1 rule discards this range, and none makes
  it settled; the chain simply stops producing … until a future update") and `learn/glossary.html` ("nothing
  at or below the accepted checkpoint changes, **no v1 rule discards the unsettled range either** …").
- **Assumptions.** None. **Attack trace.** None. **Fault-model verdict.** Not applicable. **Attacker cost.**
  None. **Requirement affected.** The course's agreement with `GOV-04` and `REC-01`.
- **Evidence.** The two sentences, both untouched at this snapshot (the round-1 sweep reached lesson 11 but
  not these two); the course's review-identifier count is **0**, so this is content, not a stray note.
  **Fix:** "the chain stops producing until governance queues and someone executes a `GOV-04` entry
  (F-GOV-1), and that executed action discards the range above the checkpoint and touches nothing at or
  below it."

## R5R2-NR-02 — Low — PLAN still marks increment 4 "IN REVIEW" although it has shipped

*Rationale: `increments/04-ship-record.md` exists and `CONVERGENCE.md` records increment 4 as SHIPPED (rounds 5 and 6 clean), but `PLAN.md` still reads "**Increment 4 - narrow forced inclusion (D-12): IN REVIEW**" and "increments 4 and 5 are implemented and in review while increment 3 waits on S1".*

- **File + rule id.** `PLAN.md` (work-status list). **Assumptions.** None. **Attack trace.** None.
  **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** The plan's status discipline; the ship/plan split-brain check.
- **Evidence.** The quoted lines; `increments/04-ship-record.md` present; `CONVERGENCE.md`'s increment-4 note
  says it "has since SHIPPED". **Fix:** increment 4 SHIPPED; increment 5 implemented, in review.

## R5R2-NR-03 — Low — the spec pages and the index drop the Open class for F-GOV-5 and F-GOV-6

*Rationale: the canonical status is "**Open** (implementation-verified)" — so in the delta's §7.1 table, D-19 and `DEFERRED.md` §3 — but `spec/06`'s REC-03 status line, `spec/10`'s summaries and the index's rule-index row give only "implementation-verified", which a reader takes as closed rather than Open-pending-vectors. This is the residue of round 1's INC5R1-RDC-03; the convention is now defined, but its application in the spec pages and the map still varies.*

- **File + rule id.** `spec/06-recovery-exceptions.html` (REC-03: "F-GOV-5 (anchor-generation pinning,
  implementation-verified) and F-GOV-6 (…, implementation-verified)"); `spec/10-assurance.html` ("F-GOV-5 and
  F-GOV-6 close only with the acceptance and conformance vectors…" / "(implementation-verified anchor and
  non-interaction)"); `spec/index.html` ("F-GOV-5 and F-GOV-6 implementation-verified") against
  `increments/05-governance-design.md` §7.1, D-19 and `DEFERRED.md` §3 ("**Open**, implementation-verified").
- **Assumptions.** None. **Attack trace.** None. **Fault-model verdict.** Not applicable. **Attacker cost.**
  None. **Requirement affected.** The F-GOV Open/disclosed convention stated once.
- **Evidence.** The five carriers quoted. **Fix:** write "Open (implementation-verified)" in REC-03, the
  LIM-01 row and the index row.

---

## Round-2 charge, item by item (measured)

1. **D-19 reproduction.** `DECISIONS.md`'s D-19 is **10,651 characters / 8,992 non-space**; the delta's §11
   is **12,216 / 10,317**, and D-19's non-space text is **contained character-for-character** in §11. The
   1,325 non-space characters beyond it are the section heading, the R5R1-G-02 measurement note, the
   `BEGIN/END QUOTED D-19` markers, the note that the former four-item summary "is superseded by the quoted
   block and MUST NOT be cited as D-19", and "Nothing above reopens D-15, D-16 or any v1 decision" — all
   outside the markers, with the delta stating "If this block and `DECISIONS.md` ever differ, `DECISIONS.md`
   governs and this block is stale." **The delta states no decision D-19 does not.**
2. **`TimelockNotElapsed`.** One name, one condition: `spec/08` GOV-04(c) ("MUST revert before the stored
   `govResumeExecutableAt` with the error `TimelockNotElapsed`") and (d)'s table, `spec/06` REC-02
   ("reverts `TimelockNotElapsed` before the stored deadline"), and the delta (4 occurrences). Searched for
   stray second names (`DeadlineNotReached`, `TimelockActive`, `NotYetExecutable`, `ResumeNotReady`):
   **none**. (`L1-08` is the acceptance-surface sketch and carries no gov entry points or errors; noted,
   not filed.)
3. **`W_root` / `MARGIN` rows.** Both exist: unit **seconds**, "Unset — no value is proposed", each stating
   the relation `T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`; `MARGIN`'s row states it "is
   distinct from the HALT-03 margins `MARGIN_D` and `MARGIN_V`, which size the unsettled-depth inequality
   and are not aliases of it". With `T_GOV_RESUME` and `WITHDRAWAL_DELAY` and `T_VETO` already registered,
   every operand of GOV-04(g)'s constructor assertion now has a row and one unit — **the assertion has
   evaluable operands** (all values symbolic/unmeasured, as the register states).
4. **The requirements document.** "no recovery path" → **0** occurrences. The single remaining "no inclusion
   obligation" is about **unpublished** data and is correct; the single "deferred by D-16" is explicitly
   marked "(history)"; `GOV-04` appears 24 times as the live action. The five added threats are visible and
   marked "(R5R1-NR-01: added threat — …)": governance liveness unbounded (F-GOV-1, named rule `GOV-04`(i)/
   `REC-03`), the unprotected class above the checkpoint (`GOV-04`(f), `REC-02`/`REC-03`), governance churn
   (F-GOV-3), the arrivals-exceeding-drain falsifier (F-FI-2) and the enumeration residual (F-FI-8). The
   document now describes the design that exists, including increment 4's live obligation.

## Round-1 repairs, verified in the text

- `spec/02`'s live "no element of the tombstoned REC-02" sentence is fixed; only the historical round-8
  sentence retains the phrase.
- `spec/07`'s "REC-02 (withdrawn; D-16 tombstone)" is gone (0 occurrences).
- The index's slot-268 line now reads "MIG-02 slot 268 — the generation, paramVersion and the live
  `govResume*` entry fields …, grouped there; the packing and the declaration count MUST be re-derived by
  the migration audit" — matching `spec/08` and `spec/09`.
- The course's review-identifier count is **0**; `PLAN`'s increment-5 mark is "IMPLEMENTED, IN REVIEW"
  (its increment-4 mark is R5R2-NR-02).
- Scope since the round-1 snapshot: 11 artifact files changed (requirements, `CONVERGENCE`, `PLAN`, the
  delta, `spec/02`, `spec/06`, `spec/07`, `spec/08`, `spec/09`, `spec/index.html`, plus the reports) —
  sentence and row fixes only; **no v1, increment-2 or increment-4 rule changed semantics**.
- Un-tombstoning is exactly the named set: the tombstone classifier leaves `CONS-16`, `L1-14`, `PRF-15`
  and the heuristic-flagged live `LIM-02`; `GOV-04`, `REC-02`, `REC-03`, `REC-04` are live and the
  withdrawn recovery-bond names stay withdrawn.
- Arithmetic in the un-tombstoned rules: `GOV-04`(b) "exactly three values" with four stored fields;
  (c)/(d) the generation written once, only on a successful `execute()` from `queued`; six F-GOV falsifiers
  (1–2 Open, 3–4 disclosed, 5–6 Open (implementation-verified)).

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + requirements document + 14 course pages) | **4,744 links, 0 broken** files or fragments |
| Markdown links (whole artifact, incl. the requirements doc) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | 4 tombstones (`CONS-16`, `L1-14`, `PRF-15`, heuristic `LIM-02`); the revived set is out, exactly as named |
| Register orphan audit (both directions) | 94 rows; **no** live-marked row without a live-rule consumer |
| Index rule-index and parameter map | every rule id indexed (0 missing); the stall names and `govResumeExecutableAt` present (the map omits `W_root`/`MARGIN`, which its own "a map, not a second register" statement permits — noted, not filed) |
| Course scan | **0 review identifiers**; two pre-revival sentences remain (R5R2-NR-01) |

## Fault-model verdict

No Critical and no High; nothing in the repaired seams is individually true and jointly false. The three
Lows are content/status wording with no rule effect.

## Is the increment safe to ship?

**Yes — clean at the bar, second consecutive round with no Critical and no High: increment 5 reaches 2 of 2
and ships, with R5R2-NR-01, R5R2-NR-02 and R5R2-NR-03 applied as copy edits.**

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 3 | R5R2-NR-01, R5R2-NR-02, R5R2-NR-03 |
