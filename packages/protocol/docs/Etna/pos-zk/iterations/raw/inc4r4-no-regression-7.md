# Increment 04 — round 4: no-regression

Snapshot `d94117998`. Read first: all `inc4r1-*`, `inc4r2-*` and `inc4r3-*` reports; then the current
`spec/02` CONS-01(v), `spec/04` FI-11(4)/FI-12/FI-13(1)–(5), `spec/05` PRF-04(vi) and PRF-07(0),
`spec/04` DA-07, `DECISIONS.md` D-18 (with its addenda), `increments/04-forced-inclusion-design.md`
RC-5 addendum 2, `spec/09`, `index.html`, all 14 course pages; plus rule-level character comparisons
against `94255e9df`.

**Severity counts: 1 Critical, 0 High, 0 Medium, 0 Low. The increment is NOT clean and NOT safe to ship.**

Every round-3 repair is genuinely in the predicate — I verified each by reading and by character-level
change, and the partition, the byte classes, the turn pin, the intrinsic-gas floor, the signature recovery
and the producer-influence correction are all written where they belong. The Critical is one seam the
round-3 repair created: the walk's index-order condition is a **proof-only** condition, and nothing at the
consensus layer stops a block from containing the record's transactions in the only order they can execute,
which makes the range unprovable — the same "certified range no proof can cover" class as rounds 1–3, now
entered through *inclusion* instead of omission.

---

## R4R4-NR-01 — Critical — the index-order condition is unenforced at consensus, so a block that contains a nonce-descending record's transactions in their only executable order makes the range unprovable

*Rationale: FI-13(1)(a)/PRF-04(vi) resolve a record only if the transactions that appear do so "each exactly once and with increasing indices along the payload order". For a record `[t1 (index 0, nonce n+1), t2 (index 1, nonce n)]` the only order in which a block can execute the two transactions is t2 then t1 — t1 is a nonce-gap transaction at the start. A block that contains both is consensus-valid: CONS-01(v) is scoped to the transactions at their turns and demands exactly those, and it contains no prohibition on including others; the block's own execution (t2 then t1) is valid; and the duty is satisfied for both transactions (t2 at its turn before its position, t1 at its turn before its position, both forceable there). But the batch's executed payload then shows the record's indices as 1 then 0 — not increasing — so the record is in no mode, the position is unresolved, and no proof can cover the range. The round-3/4 closure argues "the executed set `{t2}` is in increasing index order, so the halt cannot be derived" — that argument assumes the batch contains only the transactions the walk would execute, and nothing enforces that assumption.*

- **File + rule id.** `spec/04-l1-integration.html`, **FI-13(1)(a)** ("walking its transactions in the
  record's own order each one either executes (appears in the batch's executed payload, each exactly once,
  **in increasing transaction index within the record** …) or is discharged"), and its round-4 clarification
  ("it applies to the transactions that appear, **each exactly once and with increasing indices along the
  payload order**"); `spec/05-proof-statement.html` **PRF-04(vi)** (the same condition: "each of the
  record's transactions either appears in the batch's executed payload, each exactly once, in increasing
  transaction index, … the 'increasing transaction index' condition constrains only the transactions that
  appear and execute"); `spec/02-consensus.html` **CONS-01(v)** / `spec/04` **FI-11(4)** (the per-block
  duty, which demands inclusion of the transactions at their turns and states no prohibition on additional
  inclusions); `increments/04-forced-inclusion-design.md` RC-5 addendum 2 ("the executed set `{t2}` is in
  increasing index order, so the halt cannot be derived").
- **Assumptions.** Publication is permissionless (DA-07(1)); a published record's transaction list need not
  be nonce-ascending (PRF-07(0) fixes only the frame/height framing; DA-07 imposes no internal order); the
  publisher controls the account that signs both transactions (or uses two signed transactions of one
  account obtainable from the mempool); a block may contain any valid transactions within the gas, DA and
  block-size bounds; the completing actor is a block producer that includes a valid, fee-paying transaction
  (or a malicious one that does so deliberately). No stake, key or validator cooperation is assumed, and no
  assumption of the fault model is violated.
- **Attack trace.** (1) The attacker publishes one record whose decoded transactions are
  `[t1: A, nonce n+1]` and `[t2: A, nonce n]`, both within the record's byte, count and gas bounds, both
  affordable in sequence, with fees set to make them attractive to include. (2) At t1's turn (index 0,
  pinned at the pre-state immediately before its own position when it appears; before the record's next
  appearing transaction when it does not), t1 cannot execute while A's nonce is n; at t2's turn
  (index 1, nonce n) it can — so any batch that resolves the record must contain t2 somewhere. (3) When a
  block producer includes both transactions, the only possible order is t2 then t1 (t1 before t2 is a
  nonce-gap transaction and no valid block can carry it). The block is valid: its execution is valid,
  CONS-01(v) demands t2 (it is at its turn before its own position and forceable there) and t1 (it is at its
  turn before its own position, forceable there after t2 executed) — the block contains both — and no rule
  forbids including a transaction the walk would not count. (4) In the batch's executed payload the record's
  appearances are index 1 then index 0: the "increasing indices along the payload order" condition fails, so
  (a) does not apply; (b) does not apply (the record is live, not over-bound, contains no byte-invalid
  transaction, and is not all-discharged — t2 executed); (c) does not apply while the record is live. (5) The
  position is unresolved, FI-13(5)/FI-11(3)(c)/PRF-04(vi) make the proof invalid, and because every accepted
  batch is a contiguous range the position cannot be left behind: no range containing that block can ever be
  proven while the record is live at the range's anchored view. Settlement stops at that height; production
  then stops at the unsettled-depth cap, and v1 has no recovery path. (6) The only escape is time: a range
  whose anchored view reaches the record's deadline may resolve it as (c) dead — which requires the chain to
  keep producing blocks (and a provable range) until then; if the depth cap binds before the deadline, the
  halt is permanent.
- **Fault-model verdict.** Inside. The completing block violates no rule — it satisfies the per-block duty
  and is a valid block — so honest validators must certify it; the trigger is one permissionless publication
  by any account, and the two transactions are ordinary fee-paying transactions (so the trap can be completed
  by a profit-motivated producer with no malice, and deliberately by a malicious one). It is therefore a
  chain-wide halt reachable without a Byzantine coalition, and it breaks D-12's no-halt property.
- **Attacker cost.** One L1 publication (plus its own two L2 transactions, which execute and pay their own
  fees); if the timing misses the window, the attempt costs the publication and can be repeated. The halt,
  once created, costs nothing further.
- **Requirement affected.** D-12's no-halt guarantee and FI-12(5) ("why this cannot produce a permanent
  halt"); FI-13(5)'s totality claim; the round-3 repair's own closure argument; FI-14(1)'s principle that no
  party may be able to delay a forced-data record (the walk lets a producer make a record unresolvable by
  including its own transactions).
- **Evidence.** The quoted clauses above; the delta's RC-5 addendum 2 reasoning ("the executed set
  `{t2}`"); a sweep of the artifact for any prohibition on block contents (`MUST NOT contain a
  transaction`, `MUST NOT include`, `no block may`, `may not contain` — **none**), so the assumption the
  closure relies on is nowhere enforced; and the course and register never mention the extra-appearance case.
  **Fix (any one closes it):** make per-record payload index order a **block-validity** condition (a block
  MUST NOT contain a transaction of record `j` once a higher-index transaction of `j` has already appeared
  in the range), so such a block can never be certified; or drop the index-order condition and let the
  position-pinned turn semantics alone decide execution and discharge; or make the guest treat an appearance
  of a transaction whose turn has already passed as not executing it (needs care so it cannot be used to
  smuggle an unexecuted transaction past the obligation).

---

## The round-3 repairs are present in the predicate (verified by reading and by character-level change)

Rule-level character deltas against `94255e9df`: **CONS-01 +2,222**, **FI-11 +2,299**, **FI-13 +9,635**,
**PRF-04 +3,201**; FI-12, FI-14 and PRF-07 are unchanged (so nothing outside the repaired clauses moved).

1. **CONS-01(v)'s turn scoping, and its equality with FI-11(4)'s quotation.** CONS-01(v) now reads "the
   per-block order and non-omission duty, **scoped to the transaction's turn**", with the turn pinned by
   position and the explicit statement that the duty "applies to exactly the transactions the proof-side
   walk of FI-13(1)(a) would execute and never to one the walk discharges … the per-block duty and the
   proof-side walk MUST share one predicate — a disagreement is a protocol defect". FI-11(4) quotes the
   clause body **verbatim** ("CONS-01 (v) reads, in full: …"): I compared the two strings after tag
   stripping — identical except for the clause's own heading (not quoted), the trailing `(increment 04: …)`
   and `(review round 3, …)` notes (not part of the clause), and one comma/space artifact
   ("only there , so" vs "only there, so").
2. **FI-13(2)'s intrinsic-gas floor and signature recovery.** (2)(ii): "t's gas limit is at most
   `FI_RECORD_GAS_MAX` and **at least the intrinsic gas of t's own data** … so a transaction that declares
   less is executable by no valid block"; (2)(iv): "t's signature **recovers to a sender** … and t's nonce
   equals that sender's nonce at that pre-state". The clause states the consequence explicitly ("no
   transaction exists that (2) calls forceable and no valid block can carry") and the per-block duty
   inherits the corrected predicate.
3. **Record ordering versus the turn's pre-state.** FI-13(2) now separates them: the record's own ordering
   enters "only through the sender's own signed order … a producer cannot insert a transaction into the
   record, reorder its transactions, or drop one from the walk", while "the pre-state each turn is judged
   against is a different thing: it is the batch's own executed state, whose content the producer does
   choose", with the credit-ordering edge named as the disclosed residual F-FI-3 — and the immovability
   claim corrected to "only the nonce is producer-immovable; the balance … anyone can move — a third-party
   credit can only make a transaction executable, never discharged". The same correction is carried in
   FI-13(3), D-18's addendum, `spec/10` and `spec/09`.
4. **FI-13(1)(a)'s position-pinned turn.** "A transaction that appears in the executed payload has its turn
   at the pre-state immediately before its own position; a transaction that does not appear has its turn at
   the pre-state immediately before the record's next transaction in the record's own order that appears …
   and at the pre-state at the end of the batch's execution when no later transaction of the record
   appears." The same pin appears verbatim in CONS-01(v) and in PRF-04(vi) ("the turn pinned by position in
   FI-13(1)(a) … the guest MUST recompute that pre-state from the batch's own execution, never from a
   witness-supplied position").
5. **The byte-invalid classes, enumerated in both places.** FI-13(1)(b) lists (A) decode failure under
   PRF-07(0), (B) chain-id mismatch, (C) signature that does not recover to a sender, (D) declared gas
   limit below intrinsic gas — "each decided by the record's published byte string, the registered constants
   and the chain id alone"; PRF-04(vi) names the same four in the same order and adds that the same two
   byte-decidable requirements are part of the forceability predicate.
6. **Copy edits.** "void individually" survives only inside the `INC4R3-DF-01` correction note that retracts
   it; the live-only qualifier on the over-bound limb is present in the register ("is live-only, so a dead
   over-bound record is dead, not void"), the index and the course; the FI text now uses **BALANCE** (the
   remaining "free balance" hits are the economics term `free_before(e)` on page 07 and historical
   DECISIONS entries that record the correction); and the **course carries 0 review identifiers** (32 at
   `94255e9df`, 0 now), so round 3's Low R4R3-NR-02 is closed.

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + 14 course pages) | **4,477 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | deferred tombstones intact (`CONS-16`, `REC-02..REC-04`, `GOV-04`; the text heuristic also flags the live rejected-alternatives rule `LIM-02`) |
| Register orphan audit (both directions) | 92 rows; the only live-marked row with no live-rule consumer is `DRAIN_DEADLINE`, the known migration-only row consumed by MIG-03; `FI_PREFIX_CAP` is read by no live rule |
| Index rule-index | every rule id indexed (0 missing); the FI family, the per-transaction walk and the live-only void limbs are indexed |
| Course scan | 0 review identifiers; per-transaction resolution taught; no stale record-level or pre-increment reading |

## Considered and dismissed (not filed)

- **The omission-side / full-block route.** A producer that fills its blocks leaves no room at the duty's
  turn, so CONS-01(v) does not demand the omitted transaction; the batch is unprovable. I re-derived this
  and it still needs a *run* of full blocks covering the admissible range (an honest block with room must
  include the transaction by the duty and resolves the record), i.e. control of many consecutive slots —
  outside A-CONS-1's <1/3 and the disclosed F-FI-5 producer condition. The inclusion-side route above needs
  **one** block, which is why it is the finding.
- **The end-of-batch turn for a never-appearing transaction** is a pre-state of the range's last block; its
  consensus check is range-relative, but the same "needs a run of filled blocks" reasoning applies to any
  halt derived from it, and the proof-side effect is the intended enforcement. Noted, not filed.
- **The credit-ordering edge** is disclosed as F-FI-3 in the rule, D-18, `spec/10`, `spec/09` and the
  course, and a credit can only enable, never discharge — consistent.

## Fault-model verdict

R4R4-NR-01 is inside the fault model and needs no adversarial assumption beyond one permissionless
publication: the completing block is consensus-valid, so honest validators certify it, and the range it
belongs to can never be proven while the record is live. The two Lows of round 3 are closed and I found no
other drift.

## Is the increment safe to ship?

**No.** Add the consensus-side counterpart to the index-order condition (or remove the condition), then the
increment is clean: every other round-3 repair is present and consistent, and the mechanical surface is
clean.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 1 | R4R4-NR-01 |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
