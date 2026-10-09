# Increment 4 round 6 — confirmation: disclosures, register and course

**Angle.** Confirm the disclosures, register and course after five passes: every live FI name registered
with unit, owner and tag; the nine-name set and the eight falsifiers consistent across the register, the
index, spec/10, DEFERRED.md, D-18, the delta and the course; the course teaching the shipped rule
(four set-aside grounds with the no-room condition on the turn's block alone, dead-first live-only void,
the block-validity order rule, the credit route and its honest limit, the not-a-latency headline with both
conditions, the falsifiers and which are Open) with zero review identifiers and no stale form; the
migration budget exact and the settlement pair riding the checkpoint word; and no disclosure promising
more than the rules deliver. Round charge: both sides of every seam the round-5/6 repairs touched, every
quotation measured, every count checked.

**Snapshot.** `e6f650541`; working tree at the same commit. Read first: all four `inc4r5-*` reports, then
spec/02 CONS-01(v), spec/04 FI-11(4)/FI-13, spec/05 PRF-04(vi), spec/09's FI rows, spec/10's falsifier
carry, DEFERRED.md, D-18's addenda, the delta's RC-5…RC-8 and the course.

**Result: 0 Critical, 0 High, 2 Low — a CLEAN round at the bar; the increment is safe to ship.** Both
quotations measure whole (10 876 / 10 876 characters each), every count matches the thing it counts, the
nine-name set and the eight falsifiers are consistent across all seven carriers, and the Open convention
is applied. Both Lows are in the course and are text-only: the glossary still carries the wide no-room
form, and the course teaches the order requirement without its consensus-side invalidity.

---

## The two charged items

1. **The Open falsifier convention — applied, and the operative/disclosed distinction is explicit.**
   `spec/10` LIM-01's register is headed "known limitations, **stated once**, with their consequence …
   Each is a statement about what the design does not establish; none may be presented elsewhere as a
   strength, and none may be silently dropped" (line 325–328) — that is the disclosed-limits set — while
   the rules are stated with MUST/MUST NOT on their owner pages — the operative set. The statuses are
   applied consistently: the delta's §6.1 table marks all eight falsifiers Open ("Open (carried)",
   "Open — NOT fixed by this increment", "Open (carried, sharpened)", "Open (new)", "Open (new premise)");
   `spec/10` line 353 says "Its limits are named and must not be smoothed over" and marks F-FI-2 "open and
   not fixed by increment 04"; the index names the open-unfixed subset ("F-FI-2, F-FI-4, F-FI-7 and F-FI-8
   open, not fixed"); `spec/09` line 46 and DEFERRED.md carry the same list. I found no place where an
   Open is presented as a guarantee or an operative requirement as a disclosed limit. Noted, not filed:
   no single sentence defines the four labels, so the index's parenthetical must be read as "open **and**
   not fixed", not as the exhaustive open list; the delta's per-row statuses resolve it.
2. **The wide no-room form — one survivor, in the course glossary (INC4R6-CD-01).** Every normative
   carrier reads the turn's block alone (FI-13(1)(a), FI-13(3), CONS-01(v), FI-11(4)'s quotation,
   PRF-04(vi), `spec/09` 46, the index 459, `learn/11` 111–116, `learn/09` 123–124,
   `learn/limitations` 198–199), and the spec occurrences of the deleted phrase are correction notes that
   quote it as deleted. The glossary's two entries still state it as the rule.

## INC4R6-CD-01 — Low — the course glossary still states the WIDE no-room ground in two entries, the form the rules narrowed to the turn's block alone.

**File + rule id.** `learn/glossary.html` entry "Forceable (transaction)" (line 132): "… or **no block of
the range at or after the turn had room to carry it** — the remaining gas at that turn was below the gas
limit the transaction declares …"; entry "Resolution (executed, void, dead)" (line 149): "… or, at that
turn, **no block of the range at or after the turn had room to carry it**, judged on the same remaining gas
the per-block duty reads …". The rules say the turn's block alone: FI-13(1)(a) — "at that turn, the block
in which the turn lies had no room to carry it — the remaining gas, at that turn, of the block in which the
turn lies was below the gas limit t declares … (a later block's room neither rescues nor condemns a
transaction whose turn has passed)"; CONS-01(v) and PRF-04(vi) state the same; `learn/09` 124 and
`learn/11` 115–116 already carry the corrected sentence.

**Assumptions.** The course must teach the shipped rule (the standing rule that the register, the index and
the course move with the specification); the glossary is a learner-facing carrier.

**Attack trace (reader-facing, no adversary).** A reader who takes the glossary's definition learns a
discharge ground the rules no longer state: under the wide form a transaction whose turn's block had room
but which was omitted is *not* discharged (because a later block had room), so the position is unresolved
and the proof invalid — the exact halt the round-5 S-01 repair removed, and the round-6 repair list item
(f) said the glossary was fixed. The normative rule is correct, so no implementation that follows the
rules is affected.

**Fault-model verdict.** Not applicable: course wording; no rule, event or proof check reads the glossary.

**Attacker cost.** None.

**Requirement affected.** FI-13(1)(a)/(3); CONS-01(v); FI-11(4); PRF-04(vi); course-to-rule consistency.

**Evidence.** `learn/glossary.html` 132 and 149; FI-13(1)(a); CONS-01(v); FI-11(4); PRF-04(vi);
`learn/11` 111–116; `learn/09` 123–124; `learn/limitations` 198–199. (This corroborates, independently,
the round-6 seams report's F1.) Fix: reword both sentences to the turn's block and add the rule's sentence
that a later block's room neither rescues nor condemns.

## INC4R6-CD-02 — Low — the course teaches the payload-order requirement but not the consensus-side block-validity rule that makes an out-of-order inclusion invalid.

**File + rule id.** `learn/11-forced-inclusion.html` line 78: "Every transaction that runs appears in the
batch's executed payload exactly once, **in that order**" — the walk's requirement — and lines 194 /
`learn/09` 121–122 ("a block never executes a later record's forced transaction ahead of an earlier one")
— the across-record prohibition. What is absent from `learn/` is the rule's consensus counterpart: **"A
block MUST NOT contain a transaction of a forced record once a higher-index transaction of that same
record has already appeared in the executed payload of the range: a block whose body contains a transaction
of record j when a transaction of j with a higher index has already appeared earlier in the executed
payload of the same range, including earlier positions in the same block, is invalid"** (FI-11(4), "Order
of appearance — the block-validity counterpart"; CONS-01(v); FI-13(1); the index 457/459). A grep of the
course for that requirement's language (higher-index, index order, out-of-order inclusion) returns nothing.

**Assumptions.** The round-4 NR-01 repair made the order condition a block-validity rule so that the
appearances a certifiable batch can present are exactly the record's own order; the course is expected to
teach the shipped rule (the round's own charge names this rule).

**Attack trace (reader-facing).** A learner takes away the pre-NR-01 model: the payload must be in order
(the walk's condition) but a block that presents it otherwise is not said to be *invalid*, only that the
walk would not settle the record — precisely the reading NR-01 corrected, under which an out-of-order
inclusion left the range unprovable instead of the block invalid.

**Fault-model verdict.** Not applicable: course completeness; the rule pages and the index carry the
consensus rule.

**Attacker cost.** None.

**Requirement affected.** CONS-01(v)'s block-validity order rule; FI-11(4); FI-13(1); index 457/459.

**Evidence.** `learn/11` 78, 194; `learn/09` 121–122; FI-11(4) ("Order of appearance"); CONS-01(v);
FI-13(1); `spec/index.html` 457, 459. Fix: one sentence in lesson 11's per-block duty: a block containing a
forced transaction after a higher-index transaction of the same record is invalid.

## Verified

1. **The register and the nine-name set.** `spec/09` line 96 names the live forced-inclusion set and both
   new parameters — "with the new `FI_MIN_DRAIN` and the new fee floor `FI_MIN_EXEC_FEE_CAP` (unmeasured,
   its Open premise F-FI-7) and the four envelope relations", closing with "the live forced-inclusion set
   is complete at **nine names**"; the index's parameter map (553) lists the same nine; every row
   (09:189–200) carries a unit, an owner rule and a tag, including `FI_MIN_EXEC_FEE_CAP` — "**wei per gas**
   (the unit of a transaction's declared `maxFeePerGas`) … not forceable under FI-13(2)(vi) and … the
   byte-invalid void ground of FI-13(1)(b)(E) … Open premise (F-FI-7) … **a policy floor, not an
   uncarryability class** … unmeasured (Open premise: F-FI-7)". `FI_PREFIX_CAP` remains the withdrawn
   spelling only; the class list is carried in the index's FI-13 row ("the seven classes", all seven
   named) and per class in the register rows.
2. **The eight falsifiers, consistent across every carrier.** F-FI-1…F-FI-8 in the delta's §6.1 (eight
   rows, each with a Status and a closing condition) and its §7.6 note ("with F-FI-2, F-FI-4, F-FI-7 and
   F-FI-8 carried Open"); `spec/10` 286 ("F-FI-1…F-FI-8") and 353 (all eight with their meanings);
   `spec/index.html` 528 ("the F-FI-1…F-FI-8 falsifiers (F-FI-2, F-FI-4, F-FI-7 and F-FI-8 open, not
   fixed)"); `spec/09` 46; DEFERRED.md 109–140 ("falsifiers F-FI-1–F-FI-8"); D-18 807–815 ("the set runs to
   F-FI-8"); the course (learn/11 228–269, limitations 220). Each is Open where it should be; none is
   presented as fixed, and no carrier claims a wall-clock or inclusion guarantee.
3. **The course sweep.** Four set-aside grounds on the turn's block alone in lesson 11 (111–116, 365–366,
   389–390) and lessons 09/01/limitations; dead-first and live-only void (learn/11 75–94, 175, 192,
   244–248, 308–315); the credit route with its honest limit (learn/11 118–130, 380–382; learn/01 171;
   limitations 202–203); the not-a-latency headline with both conditions (learn/11 211–214, 219–223,
   284–285; learn/09 51–53; limitations 53–58, 198–203); F-FI-1…F-FI-8 with F-FI-2 "carried open; not
   fixed" and F-FI-8 "carried open" (learn/11 228–269); zero review identifiers in `learn/`; no
   "free balance", no "void individually", no record-level "all/none" phrasing, no stale `DISCARDED`
   status. The two exceptions are CD-01 and CD-02.
4. **Quotations measured, not read.** Stripping tags and entities, blockquote markers, code spans and all
   emphasis, then normalising whitespace and rule-id spacing: `spec/04` FI-11(4)'s "CONS-01(v) reads, in
   full:" reproduces the clause body at **10 876 / 10 876 characters (100%)**, and the delta's §2 "reads,
   in full:" transcription measures the same **10 876 / 10 876 (100%)**. The clause grew from round 5's
   10 178 and both quotations grew with it.
5. **Counts against their referents.** Three resolution modes; three limbs of void; seven byte classes
   (A)–(G), with the index saying "the seven classes"; four discharge conditions (nonce, balance,
   EIP-3607 sender-with-code, no-room at the turn), named in full by FI-13(1)(a), PRF-04(vi), the index and
   the course ("any of four grounds" / "the other three set-aside grounds"); five byte-decidable predicate
   requirements; eight falsifiers; nine parameter names. All match.
6. **The migration budget is exact and the settlement pair rides the checkpoint word.** `spec/08`
   line 273 — the checkpoints map holds "the ten L1-07 fields … the four packed `uint64` fields —
   `l1BlockNumber`, `lastAcceptedBatchTime`, `settledCount` and `anchoredL1Block` — complete one 32-byte
   word, so the pair consumes no gap slot and no per-height mapping is added"; 15 declaration slots
   (258–269, 275–277) of 43 sourced (258–300), 28 free (270–274, 278–300) — unchanged, and `spec/08` was
   not touched by the round-5/6 repairs.
7. **No disclosure promises more than the rules deliver**, apart from the two course Lows: the fee floor is
   stated as a policy void with its Open premise F-FI-7 (FI-13(1)(b)(E), FI-13(2)(vi), 09:195, the delta),
   the enumeration residual is carried Open as F-FI-8, the credit-ordering edge is the disclosed residual
   F-FI-3, the room ground is disclosed as the one a producer's own blocks reach, the guarantee is
   exclusion per unit of the censor's L1 spending with both conditions, and no FI state gates an exit.

## Ship decision

**Clean at the bar: 0 Critical, 0 High, 2 Low — the second consecutive round with no Critical and no
High, and the increment is safe to ship.** The register is complete at nine names with units, owners and
tags; the eight falsifiers are consistent across all seven carriers and Open where they should be; both
"in full" quotations measure whole; every count matches; the migration budget and the settlement pair are
unchanged; and the course teaches the shipped rule except for the two text-only items above (one surviving
wide no-room sentence-pair in the glossary, and the consensus-side invalidity of an out-of-order inclusion).
Neither depends on a rule change: two sentences close both.
