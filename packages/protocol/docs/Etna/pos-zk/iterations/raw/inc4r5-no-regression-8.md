# Increment 04 — round 5: no-regression (verified by reading)

Snapshot `930b1edee` (the tree moved to `5887d600a` during this round — the round-5 quotations-and-counts
angle's repair commit; where that matters it is called out). Read first: all `inc4r3-*` and `inc4r4-*`
reports, then `spec/02` CONS-01(v), `spec/04` DA-07/FI-10..FI-14/L1-08, `spec/05` PRF-04(vi)/PRF-07,
`DECISIONS.md` D-18, the delta's RC-5..RC-8, `spec/09`, `index.html`, all 14 course pages; plus
rule-level character comparisons against `94255e9df` and clause-vs-quotation comparisons at the snapshot.

**Severity counts: 0 Critical, 0 High, 0 Medium, 2 Low. No Critical and no High: the increment is clean at
the bar for this angle, and safe to ship once the two Lows are applied as copy edits.**

Round 4's four repairs are all in the predicate, the four discharge conditions and the seven byte classes are
counted correctly everywhere they are stated, and every round-4 seam I re-read on both sides holds. The two
Lows are documentation drift: a stale falsifier count in the index (and the delta's plan line), and a
discharge-ground phrase that is wider than its own definition.

---

## R4R5-NR-01 — Low — the index still counts the forced-inclusion falsifiers as F-FI-1…F-FI-6 and F-FI-1…F-FI-7, while the set is F-FI-1…F-FI-8 and F-FI-8 is Open

*Rationale: the round-4 repairs added F-FI-7 (the fee floor's schedule premise) and F-FI-8 (the enumeration residual), and `spec/10` now says "the eight falsifiers F-FI-1…F-FI-8". The index states two older ranges and under-reports which are Open, contradicting its own FI-13 row (which names "the Open fee-schedule premise F-FI-7 and the enumeration residual F-FI-8").*

- **File + rule id.** `spec/index.html`: the deferral/revival note ("increment 04 has revived narrow forced
  inclusion (FI-10–FI-14 are live again in narrow form, with the **F-FI-1…F-FI-6** falsifiers carried in
  10)") and the **LIM-01** rule-index row ("the live inclusion obligation's limits and the **F-FI-1…F-FI-7**
  falsifiers (**F-FI-2, F-FI-4 and F-FI-7 open**, not fixed…)"). The design delta's §7.6 plan line repeats
  "F-FI-1…F-FI-7".
- **Assumptions.** None.
- **Attack trace.** None (map accuracy); the consequence is that a reader of the index under-counts the
  disclosed residuals and does not learn that F-FI-8 is Open — the residual the S-01 repair deliberately
  carries rather than denies.
- **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** The index's own contract ("Registry of every normative rule and the page that
  states it in full"); the round-4 disclosures (F-FI-7, F-FI-8) reaching the map.
- **Evidence.** `grep` at both the snapshot and HEAD: `F-FI-1…F-FI-6` **true**, `F-FI-1…F-FI-7` **true**,
  `F-FI-1…F-FI-8` **false**; `spec/10-assurance.html` says "the eight falsifiers F-FI-1…F-FI-8, which are
  carried Open with F-FI-2 unfixed — the seventh, F-FI-7 …; the eighth, F-FI-8 …". **Fix:** update both index
  statements to F-FI-1…F-FI-8 (and F-FI-8 in the Open list), and the delta's §7.6 line.

## R4R5-NR-02 — Low — the mirrored no-room discharge ground is stated wider than the test it defines, so read literally it demands an inclusion no rule requires

*Rationale: the ground reads "no block of the range at or after the turn had room to carry it — the remaining gas, at that turn, of the block in which the turn lies was below the gas limit t declares". The em-dash defines the test as the turn's block; the leading phrase asserts something about every later block as well. A later block of the range usually has room and does not contain t (the per-block duty fires only at the turn, so no rule demands it there) — under the leading phrase the discharge fails, PRF-04(vi) then rejects a "discharge claimed for a transaction that could have executed at its turn", and the position is unresolved although every block is valid: exactly the certified-but-unprovable shape the round-4 repair closed.*

- **File + rule id.** `spec/04` **FI-13(1)(a)** (fourth discharge condition) and **PRF-04(vi)** ("or no block
  of the range at or after the turn had room to carry it — the remaining gas, at that turn, of the block in
  which the turn lies was below the gas limit t declares …"); the same phrase is taught in
  `learn/11`, `learn/glossary` and `learn/limitations`.
- **Assumptions.** A producer fills the turn's block (no room at the turn) and later blocks of the range
  have room and omit the transaction — both consensus-valid, since CONS-01(v) demands the transaction only
  at its turn and only if there is room there.
- **Attack trace.** (1) Publish a record with one transaction that is executable but not included by the
  turn's block (which is full). (2) The duty does not demand it (no room at the turn), so every block of the
  range is valid and the range is certified. (3) The walk: the transaction does not appear; the em-dash test
  (no room at the turn) discharges it; the leading phrase does not (a later block had room) — under the
  literal reading the transaction must appear, the position is unresolved, and no proof can cover the range
  while the record is live. (4) No rule ever required any block to carry it, so this is a halt created by
  the wording alone.
- **Fault-model verdict.** Not reachable if the em-dash definition is applied (the intended reading, and the
  one the clause asserts when it says the duty and the walk "read one turn and the same remaining gas");
  reachable as a reading of the shipped sentence.
- **Attacker cost.** One publication plus a filled turn block, under the literal reading only.
- **Requirement affected.** FI-11(4)'s own agreement requirement ("the two checks MUST agree; a disagreement
  is a protocol defect"); the round-4 S-02 repair's intent.
- **Evidence.** The quoted condition in FI-13(1)(a) and PRF-04(vi); CONS-01(v)'s narrow statement of the
  same ground ("a forceable transaction can be discharged only where its block at that point had no room").
  **Fix:** state the ground as the turn's block alone ("the block in which the turn lies had no room at that
  turn"), dropping "no block of the range at or after the turn had room", in FI-13(1)(a) and PRF-04(vi) and
  the course pages that repeat it.

---

## Corroborated and already closed (not counted)

**FI-11(4)'s "CONS-01(v) reads, in full" was false at the snapshot.** Compared at `930b1edee` after
tag-stripping and punctuation normalisation: the CONS-01(v) clause body is **10,196** characters and the
FI-11(4) quotation **9,627**; they diverge at character **7,588**. Three clause pieces were absent from the
quotation — the normative enforcement/no-offence sentence ("The obligation itself is enforced in the proof,
never in the admission rules of land(data, proof) … the rejected proof is the whole enforcement."), the
`(increment 04: …)` note, and the round-4 S-01/S-02 note — while the quotation supplied its own review
notes instead. The round-5 quotations-and-counts angle found the same, and `5887d600a` repaired it: at HEAD
the quotation reproduces the whole clause and appends only the repair note ("the quotation now reproduces the
whole clause, heading and notes included, word for word"), which I verified (clause present, then the note).
The delta's RC-8 phrase "the verbatim quotation" now matches.

## The round-4 repairs, verified in the predicate

Rule-level character deltas against the round-3 snapshot `94255e9df`: **CONS-01 +8,846** (6,675 → 15,521),
**FI-11 +9,095** (9,143 → 18,238), **FI-13 +20,988** (12,901 → 33,889), **DA-07 +1,534** (7,562 → 9,096),
**PRF-04 +9,373** (11,896 → 21,269); FI-10, FI-12, FI-14, L1-08 and PRF-07 are unchanged, so nothing outside
the repaired clauses moved.

1. **The block-validity order rule is present, in CONS-01(v) and inside FI-11(4)'s quotation.**
   CONS-01(v): "**Order of appearance — the block-validity counterpart.** A block MUST NOT contain a
   transaction of a forced record once a higher-index transaction of that same record has already appeared
   in the executed payload of the range … is invalid … This is a block-validity condition of this clause: a
   correct validator MUST NOT sign a prevote or a precommit for a block that violates it." The quotation in
   FI-11(4) contains that text (verified by membership at both the snapshot and HEAD), and FI-13(1)(a) names
   it as the consensus-side counterpart with the joint property spelled out. My round-4 Critical (R4R4-NR-01)
   is closed: the appearances a certifiable range can present are increasing by construction, so the walk's
   index-order condition is never unsatisfiable by the record's own order.
2. **The re-pinned tail turn is identical in content across the four places.** FI-13(1)(a), CONS-01(v),
   FI-11(4) (inside its quotation of CONS-01(v), so identical by construction) and PRF-04(vi) all carry: own
   position when it appears; otherwise immediately before the record's next transaction in the record's own
   order that appears; otherwise the state after the record's last earlier appearing transaction — the next
   transaction's pre-state, the next block's initial pre-state, or the range's last block's end-of-body
   state where that block's own remaining gas is read; otherwise, when no earlier transaction appears
   either, the pre-state immediately before the last block's body; and the "when the record's last
   transaction appears, the first case applies" clause. The two older failure modes the round-4 S-02 repair
   names (the stale pre-state read and the immediately-before-the-last-block form) are gone.
3. **The four discharge conditions are named in the rule and in the guest check.** FI-13(1)(a): nonce ≠ the
   sender's nonce at the turn; balance < `gasLimit × maxFeePerGas + value`; the sender has code at that
   pre-state (EIP-3607); and no room at that turn (the mirrored ground, same remaining gas as the duty).
   PRF-04(vi) names all four and says "a claimed discharge that fails any one of these four conditions at
   that turn … invalidates the proof", with the old "either condition" form retracted in place. CONS-01(v)
   lists the same four, and `learn/11`/`glossary` teach "any of four grounds".
4. **The seven byte classes are enumerated in both places and counted correctly.** FI-13(1)(b) (A)–(G):
   decode failure under PRF-07(0), chain-id mismatch, unrecoverable signature, below intrinsic gas,
   `maxFeePerGas` below `FI_MIN_EXEC_FEE_CAP` (class E, with the Open premise F-FI-7), malformed fee market
   (`maxPriorityFeePerGas > maxFeePerGas`, EIP-1559), and the EIP-3860 initcode cap; PRF-04(vi) names the
   same seven in the same order and refers to "the enumerated classes (A)–(G)"; the index's FI-13 row says
   "the seven classes". The predicate carries the matching requirements in (2)(ii), (iv), (vi), (vii),
   (viii). "Fifth byte class" survives only inside historical review notes that record the round-4 F1
   addition, which is accurate for that step.
5. **F-FI-7 and F-FI-8 are carried Open where the guarantee is stated.** `spec/10` names both and says
   "eight falsifiers"; the course teaches both (F-FI-7 the fee floor's schedule premise, F-FI-8 the
   enumeration residual); the index's FI-13 row names both. Only the two older index statements are stale
   (R4R5-NR-01).
6. **S-03 is written.** DA-07(1) pins the record's published byte string as the PRF-07(0) batch payload of
   its own stored claimed range — "one register, one identity, one object" — with the decode failure mapped
   to class (A); FI-13(2)(i) and (1)(b)(A) read the same object.

## Seams read on both sides (round-5 charge)

- **Order rule × walk.** A decreasing appearance can only arise within a range (caught by the block rule,
  including earlier positions in the same block) or across ranges (a lower index appearing in a later range:
  the higher index was already executed there, so its nonce is consumed and the walk discharges it at its
  tail turn — the position resolves). No residual.
- **Mirrored no-room ground × per-block duty.** Exact complement at the turn (room ⇒ must contain; no room ⇒
  discharged), both reading the same remaining gas — subject to R4R5-NR-02's wording.
- **Fee floor (E)/(2)(vi) × F-FI-7.** The floor is a predicate requirement and a byte class; the Open premise
  is disclosed in `spec/10`, `spec/09`'s `FI_MIN_EXEC_FEE_CAP` row (present and live), the index and the
  course.
- **Code ground (EIP-3607) × the duty's conditional sentence.** The conditional sentence says "forceable
  there ⇒ MUST contain t" without repeating "and no discharge ground holds", but the clause's own scoping
  sentence is explicit — "it applies to exactly the transactions the proof-side walk of FI-13(1)(a) would
  execute and never to one the walk discharges" — so the code ground and the no-room ground cannot turn the
  duty into an unsatisfiable demand. Noted, not filed.
- **Counts.** Three modes ✓, seven classes ✓, four discharge conditions ✓, four blockers ✓, three limbs of
  (b) ✓; eight falsifiers in `spec/10` and the course ✓; stale only in the index and the delta (§R4R5-NR-01).

## Mechanical checks (results, working tree at `5887d600a`)

| Check | Result |
|---|---|
| Links/anchors (spec + 14 course pages) | **4,556 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | deferred tombstones intact (`CONS-16`, `REC-02..REC-04`, `GOV-04`; the text heuristic also flags the live rejected-alternatives rule `LIM-02`) |
| Register orphan audit (both directions) | 93 rows; the only live-marked row with no live-rule consumer is `DRAIN_DEADLINE`, the known migration-only row; `FI_MIN_EXEC_FEE_CAP` present and consumed; `FI_PREFIX_CAP` read by no live rule |
| Index rule-index | every rule id indexed (0 missing) |
| Course scan | **0 review identifiers**; four set-aside grounds taught; no stale record-level or pre-increment reading |

## Fault-model verdict

No Critical and no High. R4R5-NR-01 is map accuracy and R4R5-NR-02 is an ambiguity whose definitional branch
is explicit and safe; the round-4 repairs close the four round-4 Criticals, including my R4R4-NR-01.

## Is the increment safe to ship?

**Yes, at this angle — clean at the bar** (no Critical, no High). Apply the two Lows as copy edits: the
index's falsifier ranges (and the delta's plan line), and the no-room ground's leading phrase in
FI-13(1)(a), PRF-04(vi) and the three course pages that repeat it.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 2 | R4R5-NR-01, R4R5-NR-02 |
