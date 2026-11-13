# Increment 04 — round 6, the confirmation round: no regression, by reading and measurement

Snapshot `e6f650541`. Read first: all four `inc4r5-*` reports, then the current `spec/02` CONS-01(v),
`spec/04` FI-11(4)/FI-13, `spec/05` PRF-04(vi), `spec/09`'s FI rows and preamble, `spec/10`'s falsifier
carry, `spec/index.html`'s FI rows, the delta and all 14 course pages.

**Severity counts: 0 Critical, 0 High, 0 Medium, 2 Low. No Critical, no High — the increment is clean at the
bar for this angle, and this is the second consecutive clean round: it ships.** The two Lows are wording
drift in the glossary (a surviving wide form of the no-room ground) and in the index's falsifier row (the
Open convention stated with a different extension than `spec/10`). **Strongest attack: none** — I found no
pair of clauses in the repaired seams that is individually true and jointly false.

---

## R4R6-NR-01 — Low — the wide form of the no-room discharge ground survives in the glossary, twice

*Rationale: the round-5 repair narrowed the ground in the rules to the turn's block alone ("the block in which the turn lies had no room to carry it … this is the single condition, and it reads the block of the turn alone, so a later block's room neither rescues nor condemns a transaction whose turn has passed"). The glossary still teaches the old wide form — "no block of the range at or after the turn had room to carry it" — in both of its FI entries, so a reader of the learner-facing page meets the two-condition wording the rule just removed.*

- **File + rule id.** `learn/glossary.html`, entry **Forceable (transaction)** (line 132: "…or no block of
  the range at or after the turn had room to carry it — the remaining gas at that turn was below the gas
  limit the transaction declares…") and entry **Resolution (executed, void, dead)** (line 149: "…or, at that
  turn, no block of the range at or after the turn had room to carry it, judged on the same remaining gas
  the per-block duty reads…").
- **Assumptions.** None. **Attack trace.** None (teaching text; the normative rules are correct).
- **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** The course's agreement with FI-13(1)(a)/PRF-04(vi); the round-5 S-01 repair's
  intent that no wide form survives anywhere.
- **Evidence.** Artifact-wide search for `no block of the range at or after the turn had room`: **2 hits, both
  in `learn/glossary.html`**; `spec/04` FI-13(1)(a) and `spec/05` PRF-04(vi) contain only the narrow form
  (verified: wide form absent in both), and the other three course pages that carried it (lesson 11,
  limitations, censorship) are clean. **Fix:** replace both glossary phrases with "the block in which the
  turn lies had no room".

## R4R6-NR-02 — Low — the Open falsifier convention is stated with two different extensions, so the reader cannot tell from the index which falsifiers are Open

*Rationale: the lead's item (a). The operative vs disclosed-limits distinction **is** stated in `spec/10` (the guarantee "holds only while … at least one honest or rational producer lands batches (F-FI-5) and while the arrival rate … stays within the drain (F-FI-2, open and unfixed)"; the limits are F-FI-4 in prose plus "the registered relation and gas-schedule premise, the discharged-then-executable residual, the deliberately-delayed-landing residual, the registered fee floor's schedule premise and the enumeration residual are F-FI-1, F-FI-3, F-FI-6, F-FI-7 and F-FI-8"). But the **Open marking is applied inconsistently**: `spec/10` says "the eight falsifiers F-FI-1…F-FI-8, which are carried Open with F-FI-2 unfixed", while the index's LIM-01 row says only "F-FI-2, F-FI-4, F-FI-7 and F-FI-8 open, not fixed" — omitting F-FI-1, which the same page's FI-11 row calls "the **Open** schedule premise (F-FI-1)", and leaving F-FI-3/F-FI-5/F-FI-6 unmarked.*

- **File + rule id.** `spec/10-assurance.html` (guarantee-class/censorship rows) against `spec/index.html`
  (**LIM-01** rule-index row) and the index's **FI-11** row.
- **Assumptions.** None. **Attack trace.** None (disclosure map).
- **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** The round-6 requirement that the convention be stated once and applied
  consistently, distinguishable from the text rather than inferred.
- **Evidence.** The quoted sentences; the register's own row for F-FI-1 calls the schedule premise Open, and
  `spec/10` says all eight are carried Open. **Fix:** one convention sentence ("the guarantee's conditions
  are F-FI-2 and F-FI-5; F-FI-1, F-FI-3, F-FI-4, F-FI-6, F-FI-7 and F-FI-8 are disclosed limits carried
  Open") stated in `spec/10` and echoed in the LIM-01 row, or drop "open, not fixed" from the map.

---

## Every round-5 repair is IN the text (measured, not read)

Character-level deltas against the round-4 snapshot **`d94117998`**: CONS-01 8,897 → **16,227** (+7,330);
FI-11 11,442 → **19,966** (+8,524); FI-12 **8,612 (unchanged)**; FI-13 22,536 → **36,494** (+13,958);
FI-14 **7,215 (unchanged)**; PRF-04 15,097 → **22,309** (+7,212); index FI-13 row +218, index LIM-01 row
+150. Against the round-5 snapshot `930b1edee`: CONS-01 +706, FI-11 +1,728, FI-13 +2,605, PRF-04 +1,040.

1. **The narrowed no-room ground.** FI-13(1)(a): "or, at that turn, **the block in which the turn lies had
   no room to carry it** — the remaining gas, at that turn, of that block was below the gas limit t
   declares: **this is the single condition**, and it reads the block of the turn alone, so a later block's
   room neither rescues nor condemns a transaction whose turn has passed…". PRF-04(vi) carries the same
   narrow form and the same "no block of the range at or after the turn" wide phrase is **absent** from both
   (measured); the round-4 two-condition sentence is gone.
2. **The whole CONS-01(v) quotation.** Measured after tag-stripping and normalisation: the CONS-01(v) clause
   body is **10,902** characters and the FI-11(4) quoted clause is **10,902** — **equal** (the quotation then
   appends only the "increment 04 consistency repair" note). The delta's blockquote measures **10,883** with
   the same text; its only residual differences are markdown markup and anchor-spacing artifacts
   (`FI-13(1)(a)` vs `FI-13 (1)(a)`, `h's` vs `h 's`), i.e. the transcription is whole.
3. **The eight falsifiers.** The index's deferral note and LIM-01 row now both read **F-FI-1…F-FI-8**, the
   delta reads F-FI-1…F-FI-8, and `spec/10` says "the eight falsifiers" — the round-5 stale
   F-FI-1…F-FI-6 / F-FI-1…F-FI-7 forms are gone (only the Open-set extension differs: R4R6-NR-02).
4. **The nine-name FI set.** `spec/09`'s registration preamble names all nine
   (`FI_INCLUSION_DELAY, FI_RECORD_GAS_MAX, FI_MAX_TX_PER_RECORD, FI_ANCHOR_MAX_AGE, L2_BLOCK_GAS_LIMIT,
   FI_MAX_PER_BATCH, FI_ITEM_MAX_BYTES, FI_MIN_DRAIN, FI_MIN_EXEC_FEE_CAP` — measured 9/9) and says "the
   live forced-inclusion set counts nine names"; the index's parameter-map preamble enumerates the same nine
   and says it "enumerates the live forced-inclusion set completely at nine names".
5. **Class (E)'s corrected rationale.** FI-13(1)(b)(E): "this is a **policy floor that makes the record void
   by rule**, not a class of transaction no valid block could carry, because a cap below the floor can still
   exceed the current base fee and be perfectly carryable"; FI-13(2)(vi) repeats it as "a deliberate policy
   requirement"; the register's `FI_MIN_EXEC_FEE_CAP` row says "This is a policy floor, not an
   uncarryability class…"; PRF-04(vi) qualifies the agreement to the reasons the predicate or the classes
   cover under the Open premise F-FI-7. No carrier still claims an uncarryability for the floor.
6. **The course and glossary narrowing.** Lesson 11, limitations and the censorship lesson carry the narrow
   form; **the glossary does not** (R4R6-NR-01). Course review identifiers remain **0**.

## Seams read on both sides (round-6 charge)

- **No-room ground × per-block duty.** Now one condition at one turn, with the same remaining gas read by
  both, and the "later block's room" reading explicitly excluded — the round-5 Medium is closed in the rules.
- **Quotation × clause.** Measured equal (10,902 = 10,902); the delta's blockquote equal modulo markup. No
  "in full"/"verbatim"/"word for word" claim in the FI scope is false.
- **Class (E) × predicate × classes.** The floor is a policy requirement in the predicate (2)(vi) and a void
  class (1)(b)(E), and the "no valid block can carry" claim is now qualified to the predicate/classes with
  F-FI-7 (schedule premise) and F-FI-8 (enumeration residual) carried Open — consistent.
- **Counts.** Three modes ✓, seven classes (A)–(G) ✓ (measured), **four** discharge conditions ✓ in
  FI-13(1)(a) and PRF-04(vi), eight falsifiers ✓, nine FI names ✓, four envelope relations ✓, three limbs of
  (b) ✓. The round-4 block-validity order rule is still present in CONS-01(v) **and** inside FI-11(4)'s
  quotation ✓; my round-4 Critical R4R4-NR-01 stays closed.
- **Open convention.** Stated in `spec/10` (conditions F-FI-2/F-FI-5; limits F-FI-1/F-FI-3/F-FI-4/F-FI-6/
  F-FI-7/F-FI-8) but marked with two different extensions in the index — R4R6-NR-02.

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + 14 course pages) | **4,559 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | deferred tombstones intact (`CONS-16`, `REC-02..REC-04`, `GOV-04`; the text heuristic also flags the live rejected-alternatives rule `LIM-02`) |
| Register orphan audit (both directions) | 93 rows; the only live-marked row with no live-rule consumer is `DRAIN_DEADLINE`, the known migration-only row; `FI_MIN_EXEC_FEE_CAP` present and consumed; `FI_PREFIX_CAP` read by no live rule |
| Index rule-index and parameter map | every rule id indexed (0 missing); the FI set enumerated at nine names; falsifier range F-FI-1…F-FI-8 |
| Course scan | **0 review identifiers**; no stale record-level or pre-increment reading; wide no-room form only in the glossary (R4R6-NR-01) |

## Fault-model verdict

Nothing implicated: no Critical and no High, no seam pair that is individually true and jointly false, and
both Lows are documentation wording with no rule effect.

## Is the increment safe to ship?

**Yes — clean at the bar, and this is the second consecutive round with no Critical and no High.** The
increment reaches 2 of 2. The two Lows are copy edits: the glossary's two wide no-room phrases
(R4R6-NR-01) and the index's Open-set wording (R4R6-NR-02).

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 2 | R4R6-NR-01, R4R6-NR-02 |
