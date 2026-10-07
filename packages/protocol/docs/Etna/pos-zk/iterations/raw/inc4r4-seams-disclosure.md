# Increment 4 round 4 — both sides of the disclosure seams

**Angle.** Read both sides of every seam the round-3/4 repairs touched, as disclosures: does F-FI-3 state
the credit-ordering edge accurately and consistently wherever it is carried (spec/10, the index, spec/09,
DEFERRED.md, D-18 and all its addenda, the delta, the course); is the producer-influence claim nowhere
overstated as producer-independence; are F-FI-1/-2/-4/-5/-6 still accurate; does the course teach the
shipped rule with no review identifiers, no "free balance", no "void individually" and no stale
record-level phrasing; and does any summary promise more than the rules deliver.

**Snapshot.** `d94117998`; working tree at the same commit. Read first: `inc4r3-*` and the round-1/2
reports, then the current spec/02 CONS-01(v), spec/04 FI-11(4)/FI-12/FI-13(1)–(5), spec/05 PRF-04(vi),
the delta's RC-5/RC-6, `04-coordination.md` §5, and every F-FI carrier.

**Result: 0 Critical, 0 High, 1 Medium, 1 Low — clean at the bar, and the increment is safe to ship after
one text-only sweep.** Every rule-side seam I read on both sides holds (the turn is pinned identically in
CONS-01(v) and FI-13(1)(a); the per-block duty and the proof-side walk share one predicate; the
byte-decidable void classes and the forceability predicate agree, so no block is ever asked for a
transaction it cannot carry; the credit-ordering edge is disclosed consistently in the spec, the index,
the register, the decision log and the delta). The seam that fails is the **course**: it was not swept with
R4R3-T-02, so it still teaches producer-independence and the sender-only F-FI-3 — a security property the
round's own repair superseded — and two glossary entries still omit the live-only qualifier on the
over-bound limb.

---

## Seams read on both sides — verified

1. **CONS-01(v) ↔ FI-13(1)(a): one predicate, one turn.** `spec/02` CONS-01(v) fires only when the
   transaction "is **at its turn** at that pre-state and forceable there", and defines the turn by exactly
   the same positions FI-13(1)(a) pins — "the pre-state immediately before t's own position when t
   appears, the pre-state immediately before the record's next transaction in the record's own order that
   appears when t does not appear, and the pre-state at the end of the batch's execution when no later
   transaction of the record appears" — and adds that a transaction the walk has discharged "is not
   demanded here at any later pre-state, even when it has become forceable there". FI-13(1)(a)'s "The
   turn, pinned by position" paragraph says the same and excludes "a witness-supplied position, a block
   boundary, or a producer's claim about where 'that point' is", so two guests agree. The "increasing
   transaction index" condition is stated in both places to govern only the transactions the walk
   executes. Jointly: the duty can never demand a discharged transaction, so no range is unprovable for
   nonce-descending records — the round-3 seam is closed on both sides.
2. **FI-13(2)(ii)/(iv) ↔ the void enumeration ↔ CONS-01(v) ↔ PRF-04(vi): the same byte-decidable
   classes.** (2)(ii) now carries the intrinsic-gas floor (a fixed function of the transaction's own
   bytes), (2)(iv) the signature-recovery requirement; the void limb of (1)(b) enumerates decode failure,
   chain-id mismatch, an unrecoverable signature and an intrinsic-gas shortfall; CONS-01(v) states that
   "a transaction this clause demands is one a valid block can carry"; PRF-04(vi) names the same list.
   Jointly: nothing is forceable that no valid block can carry, and nothing void is demanded.
3. **The producer-influence seam in the rules: corrected on both sides.** FI-13(2) now separates the
   record's own ordering ("a producer cannot insert a transaction into the record, reorder its
   transactions, or drop one from the walk") from the turn's pre-state ("the batch's own executed state,
   whose content the producer does choose"), states that a credit placed before a turn enables and the
   transaction must execute while one placed after cannot rescue it, and names the credit-ordering edge
   as the residual F-FI-3; FI-13(3) is retitled "cannot be manufactured — and the producer-set inputs that
   steer it are disclosed"; the voidness paragraph says only the nonce is producer-immovable while the
   balance is movable by anyone and a credit can only enable. All of my angle's non-course carriers match:
   `spec/10` 353 and 420, the index 459, `spec/09` 46 and 192, `DEFERRED.md` 69–94, D-18 621 and
   746–769, the delta 858/1185/1354–1360/1423–1427. D-18 and the delta explicitly mark the superseded
   forms ("two facts a producer cannot move", "non-steerable", "only the sender's own signed
   transactions") as superseded, which is the right way to keep the history.
4. **F-FI-3 across the carriers.** The credit-ordering edge is stated consistently everywhere outside the
   course: a credit **before** the turn makes an unaffordable transaction forceable and it must execute; a
   credit **after** the turn cannot rescue that turn and it is discharged as unaffordable; a credit can
   only enable, never discharge; only the nonce is producer-immovable; the producer's ordering of the
   credit is the one producer-set input that decides a discharge, named as this residual and not denied;
   re-publication is the remedy (`spec/10` 353, 420; index 459; `spec/09` 46; `DEFERRED.md` 89–94;
   D-18 746–769; delta 858 and 1185 and 1354–1360). The compressed forms ("may become executable later
   through a credit arriving after its turn") are read as the transaction's future executability in a new
   attempt, which is consistent with the "cannot rescue it" clause in the same sentence.
5. **F-FI-1, F-FI-2, F-FI-4, F-FI-5, F-FI-6 after the rewrites.** Unchanged in the delta's §6.1 table and
   accurate in every carrier: capacity relation + the Open schedule premise (F-FI-1), arrivals over the
   drain, "open and not fixed", guarantee's condition (F-FI-2), expiry as a discharge rather than
   inclusion (F-FI-4), non-censoring L1 + at least one honest or rational producer (F-FI-5), deliberate
   delay past the anchor-age envelope (F-FI-6) — `spec/10` 35, 260, 353, `spec/09` 46, 196, 266, the
   index 397, 526, 528, `DEFERRED.md` 60–94, D-18 665–677, and the course (learn/11 211–233).
6. **The not-a-latency headline and its condition.** Stated at every summary point with both conditions —
   `spec/10` 35, 260, 286, 353; `spec/09` 46; `spec/01` 530, 543, 571; index 397, 526, 584;
   `DEFERRED.md` 55–66; D-18 665–677; `learn/limitations` 53–58 and 199–204; `learn/09` 51–53 and
   292–296; `learn/11` 204–206, 217–218, 284–285; `learn/01` 225; `learn/02` 260; `learn/08` 124. No
   summary claims a wall-clock bound, an inclusion guarantee, or that a credit can ever discharge a
   transaction.
7. **Course hygiene.** No review identifiers anywhere in `learn/` (the matches on `M-01`/`T-02` are
   `LIM-01`/`HALT-02`); "free balance" is gone; "void individually" is gone; the resolution walk, the
   live-only void limbs, the dead-first precedence and the "each transaction recorded for what it did"
   wording are per transaction in `learn/11` 68–102 and 175, `learn/glossary` 130 and 148, `learn/01`
   168, `learn/05` 200, `learn/08` 438, `learn/09` 47–53.

## INC4R4-SD-01 — Medium — the course still teaches producer-independence and the sender-only F-FI-3, which the round's own repair (R4R3-T-02) superseded in every other artifact.

**File + rule id.** `learn/11-forced-inclusion.html` line 111 ("the producer's ordering are not inputs"),
lines 112–113 ("**the only things that move an account's nonce or balance are that account's own signed
transactions**, so a producer cannot manufacture a set-aside ground for someone else's transaction"), line
260–261 ("a producer cannot manufacture the set-aside ground: **only the sender's own signed transactions
move its nonce or balance**"), line 279 ("A set-aside ground **no producer's block contents can
manufacture or steer**"), lines 319–321 ("it cannot discharge a transaction that the sender has not itself
superseded or defunded"); `learn/11` lines 119–120 and 220–222 (F-FI-3: "may become runnable later, **but
only through the sender's own further signed transactions** … and **nothing a producer sets can**");
`learn/limitations.html` 199–200 ("may become runnable later **only through the sender's own further
transactions**"); `learn/09-censorship-and-the-bridge.html` 294–295 (same); `learn/glossary.html` 131
("only the sender's own signed transactions move its nonce or balance, **so no producer can manufacture a
set-aside ground by choosing block contents**") and 148 (same sender-only F-FI-3); `learn/01-what-is-etna.html`
168 ("a producer cannot manufacture the set-aside ground: only the sender's own signed transactions move
its nonce or balance") and 225 (sender-only F-FI-3). The rule says the opposite in three places:
FI-13(2) — "the sender's **balance**, which anyone can move — a third-party credit can only make a
transaction executable, never discharged, and **the producer's ordering decides** only whether such a
credit precedes the turn (the transaction is forceable there and must execute) or follows it (the
transaction is discharged as unaffordable at its turn, the residual F-FI-3)"; FI-13(3) — "What it does
choose is the batch's own executed state, and so the pre-state each turn is judged against"; and
`spec/10` 420 — "the one producer-set input that can decide a discharge, disclosed as the residual
F-FI-3". The delta's F-FI-3 row and every non-course carrier state the same correction (see seam 3/4).

**Assumptions.** The course is the teaching artifact for the guarantee class and the standing rule
requires it to move with the specification; FI-13(2)/(3) own the predicate and the disclosure; a credit is
an ordinary incoming transfer any account can make.

**Attack trace (reader/reviewer-facing, no adversary).** A reader who takes the course as the current
statement of the mechanism learns that a producer cannot decide a discharge and that only the sender's own
signed transactions can move the state the walk reads. Both are false under the shipped rule: a
third-party credit moves the balance, and the producer's ordering of that credit relative to a turn
decides whether an unaffordable transaction is rescued (and must then execute) or discharged. That is
exactly the residual F-FI-3 the specification names as the producer-set edge, so the course understates
the producer's power in the one place the mechanism's honest bound is taught — the same class of
overstatement D-18 exists to record as superseded, and the same class of course residue as round 3's
"void individually".

**Fault-model verdict.** Not applicable: the course is non-normative and no rule, proof check or fund path
reads it; the rule and every normative carrier are correct. It is a disclosure defect, not an exploitable
one.

**Attacker cost.** None.

**Requirement affected.** FI-13(2)/(3); the F-FI-3 row (`spec/10` 353, delta §6.1); D-18's completed
addendum; the standing rule that the course moves with the specification; the guarantee's stated conditions
(F-FI-2/F-FI-5).

**Evidence.** `learn/11` 111–115, 119–120, 220–222, 260–261, 279, 319–321; `learn/glossary` 131, 148;
`learn/01` 168, 225; `learn/limitations` 199–200; `learn/09` 294–295; `spec/04` FI-13(2) (balance
movable by anyone; credit-ordering edge) and FI-13(3); `spec/10` 353, 420; index 459; `spec/09` 46;
`DEFERRED.md` 69–94; D-18 746–769; delta 858. Fix: mirror the corrected FI-13(2)/(3) sentences and add
the credit path to the four F-FI-3 summaries in the course.

## INC4R4-SD-02 — Low — the glossary still states the over-bound void limb without the live-only qualifier (the round-3 DF-02 residual in the course).

**File + rule id.** `learn/glossary.html` line 130: "or void (over a registered bound, or a live record
every one of whose transactions is set aside at its turn)"; line 148: "Void: the record is over a
registered bound, or it is live and every one of its transactions is set aside at its turn". FI-13(1)
makes every record-level limb of (b) live-only and tests (c) first and unconditionally, and the round-3
fix already carried "live" into `spec/09` 192/197, the index 459 and `learn/11` 81–87, 309–310, 332; the
two glossary entries were missed.

**Assumptions.** Same as round 3's DF-02: the register/index/course must agree with the owner rule; the
precedence is normative.

**Attack trace (reader-facing).** A reader learns that an over-bound record is void rather than dead. Since
void is decided from the record's published bytes and dead from the stored `l1BlockNumber`, the gloss
invites a mode that needs bytes which may be past retrievability — the same failure the dead-first
precedence exists to prevent — and it disagrees with FI-12(6)'s corrected "a **live** record above the
bound is void".

**Fault-model verdict.** Not applicable (course wording; the rule is correct).

**Attacker cost.** None.

**Requirement affected.** FI-13(1)(b)/(c) precedence; FI-12(6); the glossary's Void and Forced-inclusion
entries.

**Evidence.** `learn/glossary.html` 130, 148; `spec/04` FI-13(1), FI-12(6); `spec/09` 192, 197;
index 459; `learn/11` 81–87, 309–310, 332.

## Ship decision

**Clean at the bar: 0 Critical, 0 High.** Every rule-side seam the round-3/4 repairs touched holds on both
sides — the turn is pinned identically in CONS-01(v) and FI-13(1)(a), the per-block duty and the
proof-side walk share one predicate (so a discharged transaction is never demanded and no range is
unprovable), the intrinsic-gas and signature requirements close the last forceable-but-uncarryable class,
and the credit-ordering edge is disclosed consistently in the specification, the index, the register, the
decision log and the delta. **The increment is safe to ship.** One text-only sweep is owed before the
ship record: the course must be brought to the corrected producer-influence and F-FI-3 statements
(INC4R4-SD-01) and the two glossary entries must gain "live" (INC4R4-SD-02).
