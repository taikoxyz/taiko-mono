# Increment 04 — round 3: no-regression

Snapshot `94255e9df` (the tree has since moved to `a0f909bd2`; the later commits are the round-3 report
commits, not rule changes I needed). Read: `inc4r1-mechanism.md` (R4R1-M-01) and all `inc4r2-*` first, then
the current `spec/04` FI-11/FI-12/FI-13/FI-14, `spec/02` CONS-01(v), `spec/05` PRF-04(vi) and PRF-07(0),
`spec/04` DA-07, `DECISIONS.md` D-18, `increments/04-forced-inclusion-design.md` RC-5, `spec/09`,
`index.html`, all 14 course pages, and a rule-level character comparison against the round-2 snapshot
`ba0bb3532`.

**Severity counts: 1 Critical, 0 High, 0 Medium, 2 Low. The increment is NOT clean and NOT safe to ship.**

The round-2 Critical IS now genuinely in the predicate — I verified the written text and the
character-level change — and the three modes do partition. But the rewrite left the **per-block duty
unreconciled with the new walk**, and that seam is a fresh instance of the same halt class: a record whose
transactions cannot appear in the order the walk requires traps a rule-following producer into a certified
range that no proof can ever cover. This is the same defect reported independently in
`inc4r3-totality-2.md` (R4R3-T-01); I derived and verified it myself before reading that report.

---

## R4R3-NR-01 — Critical — the per-block duty and the new walk are mutually unsatisfiable for a record whose transactions cannot appear in increasing index order, so one permissionless publication still pins the frontier

*Rationale: FI-13(1)(a)/PRF-04(vi) resolve a record only if each of its transactions, walked in the record's own order, either executes — "appearing in the batch's executed payload, each exactly once, in increasing transaction index" — or is discharged, where discharged requires that it "does not appear". CONS-01(v)/FI-11(4) — unchanged by this round — independently demands that any block with room contain a transaction that is forceable at that block's pre-state under FI-13(2). For a record holding `[t1: nonce n+1, t2: nonce n]` of one account, t1 can only be forceable after t2 executes, so once t2 executes the duty mandates t1's inclusion after t2 in the batch payload; but then t1 appears (so it cannot be discharged) and it appears after t2 (so the executed set is not in increasing index order). The record is in no mode, the position is unresolved, and the range containing it can never be proven — while the blocks that produced it were valid and certified. This is the round-1/2 halt class, reached through the per-block rule.*

- **File + rule id.** `spec/04-l1-integration.html` **FI-13(1)(a)** ("walking its transactions in the
  record's own order each one either executes (appears in the batch's executed payload, each exactly once,
  **in increasing transaction index within the record** …) or is discharged — it does not appear, and at the
  pre-state its turn reaches in the batch's own execution … it cannot execute …") and **FI-13(5)** ("a
  live record with a transaction that can run at its turn cannot be skipped … the position cannot be
  passed"); `spec/05-proof-statement.html` **PRF-04(vi)** (same "each exactly once, in increasing
  transaction index … or does not appear and is verified as discharged at its turn", plus "MUST reject a
  proof in which a transaction that can execute at its turn does not appear"); `spec/02-consensus.html`
  **CONS-01(v)** and `spec/04` **FI-11(4)** (the per-block duty, quoted in full there, "at every pre-state
  of h … is forceable at that pre-state under FI-13(2) … then h's body MUST contain t … and MUST contain t
  if its remaining gas at that point is at least the gas limit t declares", with the same clause stating
  "the two checks MUST agree; a disagreement is a protocol defect").
- **Assumptions.** Publication is permissionless and a published body may order its transaction list
  freely: PRF-07(0) fixes only the frame/height framing and calls a body "the RLP list of the block's
  transactions in execution order"; DA-07(1) lets any account publish the committed byte string. The
  publisher controls the account that signs both transactions, so nothing outside its own keys is needed.
  A rule-following proposer builds a block with room; the prover proves the contiguous range the L2
  produced (PRF-04(v)). No stake, key or validator cooperation is assumed.
- **Attack trace.** (1) An attacker controlling account A publishes one record whose decoded payload is
  `[t1: A, nonce n+1], [t2: A, nonce n]`, both within `FI_ITEM_MAX_BYTES`, `FI_MAX_TX_PER_RECORD` and
  `FI_RECORD_GAS_MAX`, chain id matching, both affordable at their turns. (2) At the walk's t1 turn (index
  0, evaluated before any of the record's transactions execute) t1's nonce is ahead → it cannot execute.
  The walk then reaches t2 (nonce n) — forceable → the proof requires t2 to appear somewhere in the batch
  (PRF-04(vi): a transaction that can execute at its turn that does not appear makes the proof invalid).
  (3) Once t2 executes in a block h, A's nonce is n+1, so **t1 is forceable at a later pre-state of h under
  FI-13(2)** and has not executed: CONS-01(v) mandates that h's body contain t1 (it has room), and no other
  order is executable — t1 before t2 is a nonce-gap transaction and cannot be a valid block body entry.
  (4) The batch's executed payload for the record is therefore t2 then t1. At the walk: t1 appears, so it is
  not discharged; the executed set is not "in increasing transaction index within the record", so (a) fails.
  (b) fails (the record is not over-bound, has no transaction that can never execute from its own bytes, and
  is not all-discharged), (c) fails while it is live → the position is unresolved, FI-13(5)/FI-11(3)(c) make
  the proof invalid, and because a batch is the contiguous range from the previous height, no later range
  can pass the position either. Settlement stops at that height permanently (HALT-03 then stops production
  at the depth cap; v1 has no recovery path). (5) The only escapes are not duties: pad h so t1 has no room
  **and** never give t1 room in any later block of the range — the rules require the opposite whenever there
  is room — or let a proposer violate CONS-01(v) and hope validators certify an invalid block.
- **Milder limb, independent of the ordering reading.** CONS-01(v) keys on raw FI-13(2) forceability at
  *every* pre-state, while the walk discharges at the transaction's *turn* in the record's own order. The
  two predicates therefore disagree for any transaction the walk discharges that becomes forceable later in
  the same block (this record's t1), for a byte-invalid record's transactions the walk voids without
  execution, and in the F-FI-3 case (the sender's own later transaction consumes the nonce or the balance).
  FI-11(4) itself declares that disagreement "a protocol defect"; the round-3 rewrite changed the resolution
  side and left the per-block side as it was, so the disagreement is in the shipped text.
- **Fault-model verdict.** Inside: one permissionless publication, two transactions of the attacker's own
  account, an ordinary rule-following proposer with room, and honest validators certifying a block that
  satisfies CONS-01(v) as written. No assumption failure, no corrupted validator, no L1 censorship.
- **Attacker cost.** One L1 publication (plus their own two L2 transactions); the halt persists with no
  further spending, and re-publication makes it repeatable.
- **Requirement affected.** D-12/FI-12(5)'s no-halt property and the "no published record can pin the
  frontier" claim the increment rests on; FI-11(4)'s own agreement requirement; the round-1/2 Critical's
  property (totality must survive the per-block rule, not only the batch-level walk).
- **Evidence.** The quoted clauses above; the walk's "increasing transaction index" appears in both
  FI-13(1)(a) and PRF-04(vi); CONS-01(v)/FI-11(4) are unchanged from the round-2 snapshot (FI-11's rule text
  changed only in its (2)–(3) walk wording; the per-block clause text is identical); PRF-07(0)/DA-07 impose
  no nonce-ascending order on a body's transaction list. **Fix:** reconcile the two checks — scope
  CONS-01(v) to the transactions the walk can execute at their turn (evaluating forceability at the turn,
  not at every raw pre-state), or drop the "increasing transaction index" payload-order requirement in
  favour of a set-level condition in FI-13(1)(a)/PRF-04(vi), or make payload index order a block-validity
  rule so such a batch can never be certified. Any one closes it; leaving both as written does not.

---

## R4R3-NR-02 — Low — the course sweep imported review-process identifiers into six learner-facing pages

*Rationale: the course is learner-facing and every prior snapshot of every increment had zero review-process language in it (verified at `ba0bb3532`: 0 across all seven touched pages). The round-3 course sweep added 32 occurrences of the review identifier "(R4R1-M-01: …)" to six pages, which is editorial history rather than content and breaks the artefact's own convention (the spec pages carry such notes; the course did not).*

- **File + rule id.** `learn/11-forced-inclusion.html` (20), `learn/09-censorship-and-the-bridge.html`
  (5), `learn/05-the-proof.html` (1), `learn/glossary.html` (4), `learn/limitations.html` (3), plus the
  same construction in `learn/01-what-is-etna.html`/`08` (2 each of the per-transaction vocabulary); the
  identifier form is `(R4R1-M-01: …)`.
- **Assumptions.** None. **Attack trace.** None (documentation hygiene).
- **Fault-model verdict.** Not applicable. **Attacker cost.** None.
- **Requirement affected.** The course's established no-review-process convention (checked every round
  since round 9).
- **Evidence.** `git show ba0bb3532:…/learn/*` → 0 matches of `R4R1|review round|finding [A-Z]\d+` in all
  seven pages; the current working tree → 32, introduced by commits `26d8bea7c` and `2a0cd48cb`. **Fix:**
  drop the parentheticals from the course (the same statements are already in the running text) or replace
  them with a plain-language clause.

## R4R3-NR-03 — Low — the byte-invalid void limb names only one decision class, so a guest that implements the example leaves a narrow unresolved-record pin

*Rationale: totality depends on every never-executable transaction falling into either the two discharge conditions or the record-level byte-invalid limb. FI-13(1)(b) states the limb generally ("a transaction that cannot be executed from the record's own bytes (for example its chain id does not match (2)(iii))") and PRF-04(vi) mirrors it, but the only named example is the chain-id mismatch; a guest that implements "chain id only" leaves a transaction that is byte-invalid for another reason — an unrecoverable signature, or a declared gas limit below the intrinsic gas of its own data — neither executable nor discharged, so the position is unresolved and the proof invalid. Publisher-triggered, decidable from the bytes, no producer-set input, and the fix is one parenthetical.*

- **File + rule id.** `spec/04` FI-13(1)(b) second limb; `spec/05` PRF-04(vi) ("a transaction that can
  never be executed from its own bytes").
- **Assumptions.** The limb is read as the example rather than as the general criterion.
- **Attack trace.** A publisher (including a griefer) publishes a record whose transaction has, say, a gas
  limit below the intrinsic gas of its data, a matching nonce at its turn and a sufficient balance; a guest
  with only the chain-id check finds no discharge ground and no execution → the position is unresolved → the
  range is unprovable. The correct reading of the rule voids it, so this is an implementer-alignment gap,
  not a gap in the criterion.
- **Fault-model verdict.** Publisher-side only, inside the model if a guest implements the example literally.
- **Attacker cost.** One L1 publication (bounded by the record's own deadline once void is implemented).
- **Requirement affected.** Totality of the walk (FI-13(5)); guest-implementation determinism (GEN-05-class
  agreement).
- **Evidence.** The quoted limb; corroborated independently by `inc4r3-partition-and-proof.md` F1. **Fix:**
  name the classes (invalid signature, intrinsic-gas shortfall, chain-id mismatch) in FI-13(1)(b) and
  PRF-04(vi).

---

## The round-2 Critical is now real in the predicate (the round-deciding check)

- **Character-level change against `ba0bb3532`:** FI-13 **4,667 → 12,901** chars (+8,234), FI-11
  **7,950 → 9,143** (+1,193), FI-12 **8,081 → 8,612** (+531), FI-14 **7,069 → 7,215** (+146), PRF-04
  **10,065 → 11,896** (+1,831) — the round-2 bytes are gone, not re-described. The divergence in PRF-04
  begins exactly at the resolved-walk sentence.
- **The walk is written, not implied:** FI-13(1)(a) now resolves per transaction in the record's own order
  with execute-or-discharge, the exact-complement discharge (nonce ≠ the sender's nonce at the turn, or
  balance < `gasLimit × maxFeePerGas + value`), the mixed case recorded as executed/discharged, and
  PRF-04(vi) requires the guest to recompute each turn pre-state and to reject a false discharge or a
  missing executable transaction.
- **Partition verified by reading:** dead tested first and unconditionally; (b)'s over-bound and
  byte-invalid limbs live-only and tested before (a); (a) requires at least one execution, the all-discharged
  limb requires none; a zero-transaction record is (b). Every overlap I enumerated (dead + over-bound, dead
  + byte-invalid, over-bound + executable transaction, all-discharged + at least one executable) lands in
  exactly one mode.
- **Record-level forms superseded:** "all of its transactions", "none of whose transactions is forceable",
  and the F-FI-3 sentence are marked MUST-NOT-be-restored in FI-13, D-18, the delta and `spec/04`; the only
  surviving occurrences of those phrases in the artifact are the historical notes saying they are
  superseded. No live record-level reading remains.

## The two extensions, checked rather than assumed

- **Immutable-half void ground (chain-id mismatch).** Decidable from the record's own published bytes plus
  registered constants — no producer-set input; a producer cannot manufacture it (it is fixed at publication,
  DA-07(3)); it opens no new void ground against a third party, because a record that contains such a
  transaction voids only itself and resolves cheaply (the arrival/register cost is the disclosed F-FI-2
  dimension, not this limb). Verified at the text level. The only residual is R4R3-NR-03.
- **Batch-wide turn pre-state.** Decidable: the guest re-executes the batch's own committed payload
  (PRF-07(0)) and the turn pre-state is a deterministic function of that execution and the anchored state —
  no witness-supplied value enters. No manufactured ground: only the sender's own signed transactions can
  move its nonce or balance, which FI-13(3) states and qualifies with F-FI-3. It opens no new void ground.
  What it does **not** fix is the per-block clause, which still tests raw FI-13(2) forceability at every
  pre-state (R4R3-NR-01).

## Considered and dismissed (not filed)

**"Fill the block" as a halt vector.** A proposer can fill a block with its own transactions so that
CONS-01(v)'s remaining-gas condition permits omitting a due forced transaction, and the block is valid. I
worked the route through: resolution is a *batch*-level property, so a later block of the range with room
resolves the record (honest proposers must, by duty), and a range is the prover's choice of length. To make
an admissible range unprovable the attacker would have to leave no room in *every* block the range can
reach, i.e. fill a run of blocks up to the batch bound — control of many consecutive slots, outside
A-CONS-1's <1/3 and the disclosed F-FI-5 producer condition. Not filed. (This is why the *nonce-descending*
variant of the same seam, which a single rule-following proposer triggers, is the Critical above.)

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + 14 course pages) | **4,452 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | deferred tombstones intact (`CONS-16`, `REC-02..REC-04`, `GOV-04`; the classifier's text heuristic also flags the live rejected-alternatives rule `LIM-02`); `FI-10..FI-14` live; none missing its MUST-NOT pointer |
| Register orphan audit (both directions) | 92 rows, 1 live-marked row with no live-rule consumer: `DRAIN_DEADLINE`, the known migration-only row consumed by MIG-03; `FI_PREFIX_CAP` is read by no live rule |
| Index rule-index | every rule id indexed; the only deferred rule not marked as such is the live `LIM-02`; the FI family and the per-transaction walk are indexed |
| Course scan | per-transaction resolution taught in 6 pages (16 hits in lesson 11); 0 stale record-level phrases; see R4R3-NR-02 for the review-language regression |
| Round-1/2 repairs still present | FI-12(5)(ii)'s anchored-view form (RC-4) with the V2 clause historical; the register preamble's live FI set; the checkpoint-record settlement pair; `nextSeq = pruneCursor = 0` and the genesis pair; CONVERGENCE/delta status |
| Scope | round-3 changes are confined to FI-11..FI-14, PRF-04, the register/index/course, D-18 and the delta; 161 rules, no id added or removed; no v1 or increment-2 rule changed semantics |

## Fault-model verdict

R4R3-NR-01 is inside the fault model: a plain publisher and a rule-following proposer produce a certified
range that can never be proven, halting settlement permanently in a v1 with no recovery path. The two Lows
are documentation/alignment items.

## Is the increment safe to ship?

**No.** The round-2 Critical is genuinely closed in the predicate, and the partition is real, but the
per-block duty was not reconciled with the new walk: the nonce-descending record traps a rule-following
producer, and this is the same permanent-halt class the last two rounds were about. Fix R4R3-NR-01 by
making CONS-01(v) and the walk share one predicate (the turn semantics), or by removing the payload-index
order requirement, or by making index order a block-validity rule; then apply the two Lows as copy edits.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 1 | R4R3-NR-01 |
| High | 0 | — |
| Medium | 0 | — |
| Low | 2 | R4R3-NR-02, R4R3-NR-03 |
