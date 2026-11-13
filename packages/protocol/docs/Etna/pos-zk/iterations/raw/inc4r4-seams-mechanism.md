# Increment 4 round 4 — both sides of the repair seams

**Reviewer:** r6-gov-generations (task-53), independent adversarial reviewer.
**Snapshot:** `d94117998` (working tree clean at claim). **Charge:** every Critical so far was created by a
repair, so read **both sides of every seam the round-3 repairs touched** and ask of each pair of clauses
whether they are individually true and jointly false.
**Angle:** (a) the turn-scoped duty against the walk, (b) the forceability predicate against block validity,
(c) record ordering against the turn pre-state, (d) the two pinned-turn definitions.
**Method:** the specification is authoritative. Citations: `NN:line` = `spec/NN-*.html` at the snapshot;
`RC-5` = the delta's closure section.

**Counts: Critical 2 · High 0 · Medium 1 · Low 0.**
**Verdict: the round-3 repairs are real and the round-3 trap is closed — but two seams remain, both of the
same shape as the earlier Criticals: the proof-side walk demands transactions that the per-block side does
not compel (R4R4-S-02) or that no valid block can carry (R4R4-S-01).** R4R4-S-01 is the sharpest: FI-13(2)
now claims "no transaction exists that (2) calls forceable and no valid block can carry", and that claim is
false — a transaction whose `maxPriorityFeePerGas` exceeds its `maxFeePerGas` (or whose initcode exceeds the
EIP-3860 cap, or whose fee cap is below the base fee, or whose sender has code) is forceable under (2) and
uncarryable in every block, so one permissionless publication makes the record's position unresolvable and
stops settlement. R4R4-S-02: the duty's third turn case ("the end of the batch's execution") is not a
pre-state of any block, and its remaining-gas condition has no counterpart in the walk, so a producer that
omits a forced transaction — with no rule violated, including by merely filling blocks — makes the resolving
range unprovable. R4R4-S-03 (Medium): DA-07's publication byte string is a batch payload of PRF-07(0)
frames while FI-13(2)(i)/09:192 bound and decode the record as a transaction list, and the register has no
type flag.

---

## Finding R4R4-S-01 — Critical: the predicate still calls forceable transactions no valid block can carry; one publication stops settlement

**Severity: Critical.** One-line rationale: FI-13(2) asserts "no transaction exists that (2) calls forceable
and no valid block can carry", but (2) checks only the record's bytes, the registered constants, the chain id,
signature recovery, the nonce and the declared charge — it deliberately excludes the block's base fee — and it
does not check the byte-decidable EIP-1559 fee-cap ordering or the initcode size cap; a record containing one
such transaction is neither void nor discharged at its turn, so the walk (FI-13(1)(a), PRF-04(vi)) demands an
execution no valid block can perform, the per-block duty (FI-11(4)) demands an inclusion no valid block can
make, and the position can never resolve: the frontier stops at it until the record dies, and one publication
per deadline period sustains the halt.

**File + rule id.**
- `04:740` (**FI-13(2)**): "(ii) t's gas limit is at most `FI_RECORD_GAS_MAX` and **at least the intrinsic
  gas of t's own data** — …; (iii) the chain id matches; (iv) t's **signature recovers to a sender** … and
  t's nonce equals that sender's nonce at that pre-state; and (v) the sender's balance … is at least
  `t.gasLimit × t.maxFeePerGas + t.value`. **So the predicate calls no unexecutable transaction forceable**
  … **no transaction exists that (2) calls forceable and no valid block can carry.**" The predicate adds
  "the including block's base fee, its gas limit and its remaining gas are not inputs to forceability".
- `04:740` (**FI-13(1)(b)**): the void limbs are the **exhaustive** classes (A) decode failure, (B) chain-id
  mismatch, (C) unrecoverable signature, (D) declared gas limit below the intrinsic gas — a fee-cap inversion
  or an oversized initcode is in none of them, so the record is not void.
- `04:740` (**FI-13(1)(a)**): a transaction that does not appear is discharged only if "its declared nonce
  does not equal the sender's nonce at that pre-state …, or the sender's balance at that pre-state is below
  `t.gasLimit × t.maxFeePerGas + t.value`" — neither holds for the shapes below.
- `04:736` (**FI-11(4)**, CONS-01(v)): the duty "MUST contain t if its remaining gas at that point is at
  least the gas limit t declares" — an inclusion no valid block can make.
- `05:271` (**PRF-04(vi)**): "MUST reject a proof in which a transaction that can execute at its turn does
  not appear or is claimed discharged although it could execute".
- **Missing rule:** the predicate (and the void/discharge grounds) must cover every block-validity condition
  that the rule relies on. Byte-decidable ones are the easy half and are missing today: `maxFeePerGas ≥
  maxPriorityFeePerGas`, and the initcode size cap for create transactions (the intrinsic-gas floor covers
  the per-word cost, not the cap). The block-context one — `maxFeePerGas ≥` the block's base fee — is the
  deliberate exclusion (R6-D12-05) and needs an explicit decision: either a discharge ground for a fee cap
  below the base fee at the turn (which returns producer influence and must be bounded, e.g. by a registered
  base-fee ceiling or by requiring the record to declare a cap at least the maximum base fee over the
  window), or a rule that makes a record whose cap is below the reachable base fee void from its own bytes.

**Assumptions.** Publication is permissionless (DA-07) and the publisher chooses the record's bytes; the
record is live and due; no producer, validator or prover cooperation is needed — indeed no producer behaviour
can help, because no block may carry the transaction.
**Concrete attack trace.**
1. The attacker signs a normal EIP-1559 transaction for its own account with
   `maxPriorityFeePerGas = 2 wei`, `maxFeePerGas = 1 wei` (the ordering is byte-decidable and the transaction
   is rejected by every execution client), `gasLimit` = the intrinsic gas of its data, `value` chosen so the
   declared maximum charge is covered, chain id correct, nonce = its current nonce.
2. It publishes that transaction's bytes as a publication record (one record, one identity, one entry point,
   no "forced" flag). The record decodes (it is a well-formed transaction), is within `FI_ITEM_MAX_BYTES`
   and `FI_MAX_TX_PER_RECORD`, so (2)(i) holds; (ii)'s gas bounds and intrinsic floor hold; (iii) and (iv)
   hold; (v) holds — **the transaction is forceable at every pre-state under FI-13(2)**.
3. It is not void: none of the exhaustive (1)(b) classes applies (the record decodes; the chain id matches;
   the signature recovers; the gas limit is above the intrinsic gas). It is not discharged at its turn: the
   nonce matches and the balance covers the declared maximum charge. No valid block can include it, so it can
   never appear.
4. When the record's position enters `[c, c + R)`, the walk finds a transaction that can execute at its turn
   and does not appear → the position is unresolved → the proof is invalid (FI-13(5), FI-11(3)(c)); the
   per-block duty simultaneously demands an inclusion no block can make. Because the range containing the
   position can never be proven and batches are contiguous, settlement stops there until the record is dead
   (`l1BlockNumber + T_PROVE_DEADLINE`); the attacker repeats with a fresh record.
5. Variants: an oversized-initcode create transaction (EIP-3860) is byte-decidable the same way; a
   transaction whose fee cap is below the base fee in force is uncarryable while the base fee exceeds it (the
   attack then depends on the base fee, which the attacker can also keep elevated by filling blocks); a
   transaction whose recovered sender has deployed code is uncarryable under EIP-3607 while the predicate
   only requires that a sender be recovered.

**Fault-model verdict.** Inside. One permissionless publication, no assumption failure, no producer or
validator cooperation; the halt is bounded per record by `T_PROVE_DEADLINE` and repeatable, and no rule is
violated by anyone.
**Attacker cost.** One L1 publication (fees only); no stake, no bond.
**Requirement affected.** FI-13(2)'s carryability claim; FI-13(1)(a) and PRF-04(vi) (the walk demands the
impossible); FI-11(4) (an unsatisfiable duty); FI-12(5)'s "a compliant batch always exists"; D-12/D-18's
fixed decision that the obligation must not halt the chain.
**Evidence.** `04:740` (FI-13(1)(a),(b),(2)), `04:736` (FI-11(4)), `05:271` (PRF-04(vi)), `09:192`
(`FI_ITEM_MAX_BYTES` row); delta `RC-5`.

---

## Finding R4R4-S-02 — Critical: the per-block duty is weaker than the walk, so a forced transaction can be omitted with no rule violated and the resolving range becomes unprovable

**Severity: Critical.** One-line rationale: the walk treats a transaction that is forceable at its turn and
does not appear as unresolved (invalid proof), but the duty only compels a block to contain a transaction
when the transaction **is at its turn at one of that block's pre-states** *and* the block's remaining gas at
that point reaches its gas limit; the duty's third turn case — a transaction that never appears and has no
later appearing transaction in its record — is "the pre-state at the end of the batch's execution", which is
a pre-state of **no block of the range**, so the record's tail transactions are demanded by the proof and by
no block; and a producer that fills each block's gas (the ordinary case under congestion, and the thing the
rule explicitly blesses: "a block that cannot [carry forced work] is not [invalid]") makes the remaining-gas
condition false for every transaction. Either way the omitted transaction is forceable at its turn, the
position is unresolved, and the range that must resolve it can never be proven — a halt that needs no
offence, no invalid block and, in the congestion route, no attacker at all.

**File + rule id.**
- `04:740` (**FI-13(1)(a)**, the turn): "A transaction that appears in the executed payload has its turn at
  the pre-state immediately before its own position; a transaction that does not appear has its turn at the
  pre-state immediately before the record's next transaction in the record's own order that appears …, and
  **at the pre-state at the end of the batch's execution when no later transaction of the record appears**."
- `04:736` (**FI-11(4)**, CONS-01(v)): "For every block h of the range, **at every pre-state of h**: if a
  forced transaction t … **is at its turn at that pre-state** and forceable there … then h's body MUST contain
  t … and **MUST contain t if its remaining gas at that point is at least the gas limit t declares**." Plus
  "the duty applies at the transaction's turn and only there" and "A block that can carry forced work and
  carries none is invalid; **a block that cannot is not**."
- `05:271` (**PRF-04(vi)**): a transaction that can execute at its turn and does not appear is rejected.
- **Missing rule:** the walk needs a discharge ground that mirrors the block-level escape (for example, "a
  transaction that is forceable at its turn but that no block of the batch could carry — because every block's
  remaining gas at and after its turn was below its gas limit — is discharged, with re-publication as the
  remedy"), or the per-block side must regain a *reservation* that guarantees forced work a place (the
  per-block quota/count that the increment removed in round 1), or the tail turn must be pinned to a real
  block pre-state (for example, the last block of the range, whose pre-states the duty can reach) with a duty
  that compels the tail there. The current split — walk strict, duty excusable — is what produces the halt.

**Assumptions.** Route 1 (tail): the publisher uses a record with at least one transaction after the last one
the batch executes — the simplest case is a single-transaction record that the producer does not include.
Route 2 (gas): blocks are full at the transactions' turns, which any producer can arrange and which ordinary
congestion produces. Neither route requires any party to violate a rule; in the tail route the producer need
not even fill anything.
**Concrete attack trace.**
1. Route 1. Publish a single-transaction record `[t]` for a funded sender. `t` does not appear; "no later
   transaction of the record appears", so its turn is the end of the batch's execution. No block of the range
   has that state as a pre-state — except in the degenerate shape where the range's last block is empty, whose
   initial pre-state *is* the end of the batch's execution and the duty would fire there; a producer that ends
   the range with a non-empty last block (the normal case, which it controls) leaves the duty with no pre-state
   to fire at, so omitting `t` violates nothing.
   When the record's position enters the window, the walk finds `t` forceable at its turn (nonce and balance
   fine) and absent → unresolved → the proof is invalid for that range, and because ranges are contiguous the
   frontier cannot advance past the position (until the record is dead; repeat with a fresh record).
2. Route 2. For any record whose transaction is at its turn at a block pre-state, a producer that fills that
   block's gas (with ordinary transactions, its own included) makes the remaining gas below the
   transaction's gas limit at the one pre-state that is the transaction's turn — a turn is a single pre-state
   per batch (in the block holding the record's next appearing transaction, or in the last block), so filling
   that one block is enough — and the duty's second clause then does not apply — exactly what "a block that cannot
   [carry forced work] is not [invalid]" permits. The transaction is omitted, the walk finds it forceable at
   its turn → the position is unresolved → the resolving range is unprovable. Under sustained congestion this
   happens with no adversary at all: forced work has no reserved space, and the proof does not accept the
   block-level excuse.
3. Route 3 (the summary sentence). Reading "a block that can carry forced work and carries none is invalid"
   as an independent, broad duty ("any block whose pre-state admits a forceable forced transaction must carry
   one") would restore the round-3 trap: in the nonce-descending record `[t1 (idx 0, nonce n+1), t2 (idx 1,
   nonce n)]`, t1 becomes forceable after t2 executes, so a later block of the range would be compelled to
   carry t1, whose execution after t2 violates the increasing-index condition → unprovable. The two readings
   of the same clause therefore disagree, and each leaves a halt; the turn-scoped reading is the one the rule
   states in detail, so R4R4-S-02's routes 1–2 are the operative ones.

**Fault-model verdict.** Inside: route 1 is a censoring producer (or any producer indifferent to the record)
acting within the rules; route 2 is a censoring producer or mere congestion. No assumption failure, no
invalid block, no offence. The halt is bounded per record and repeatable.
**Attacker cost.** Route 1: none (omit); route 2: the gas of the blocks it would fill anyway.
**Requirement affected.** FI-11(4)'s "the two checks MUST agree"; FI-13(5)'s totality; FI-12(5)'s compliant
batch; D-12/D-18 (forced inclusion must be compelled, not merely provable); L1-04's no-gate property is not
at issue.
**Evidence.** `04:740` (FI-13(1)(a),(5)), `04:736` (FI-11(4)), `05:271` (PRF-04(vi)); round-3 report
`inc4r3-totality-2.md`.

---

## Finding R4R4-S-03 — Medium: the record's object type is defined twice and differently (DA-07's batch payload against FI's transaction list)

**Severity: Medium.** One-line rationale: DA-07 says a publication publishes "a batch's data — the whole
committed byte string of PRF-07(0)" (the framed block payload), while FI-13(2)(i) bounds "the record's
published byte string" by `FI_ITEM_MAX_BYTES` and decodes it "under PRF-07(0) to at most
`FI_MAX_TX_PER_RECORD` transactions" and 09:192 calls that string "one publication record's published byte
string" — a small transaction list; FI-10(1) insists it is **one register with one identity and no flag**, so
a reader cannot tell which object a record carries, and the walk's transaction recovery (every per-transaction
decision) is defined over an object whose framing is not pinned.
**File + rule id.** `04:695-700` (DA-07(1): "publish a batch's data — the whole committed byte string of
PRF-07(0)"; DA-07(2): the record stores the blob range, claimed batch range, data commitment, daMode, block
number, sequence); `04:734` (FI-10(1): "the same one register, the same identity, the same entry point, and
no 'forced' flag"); `04:740` (FI-13(2)(i)); `09:192`. **Missing rule / correction:** say explicitly what
byte string a record carries and how it is framed — e.g. "the published byte string of a record is the
canonical RLP list of its transactions, and a publication used as batch data is not a forced record" — or give
the register the distinguishing fact the FI walk needs. Note that this does not change R4R4-S-01/S-02: on
either reading the walk runs over the record's transactions and the carryability and omission seams remain.
**Assumptions.** None (specification coherence). **Attack trace.** None directly; the risk is an
implementation that frames a published batch payload as a transaction list (or the reverse), so the same
publication is a forced record in one implementation and batch data in another.
**Fault-model verdict.** Inside (specification defect, no adversary). **Attacker cost.** None.
**Requirement affected.** DA-07, DA-08's referenced path, FI-10(1), FI-13(2)(i), 09:192, PRF-04(vi).
**Evidence.** the four citations above.

---

## The seams, both sides read

**(a) The turn-scoped duty against the walk.** The round-3 shape `[t1 (idx 0, nonce n+1), t2 (idx 1,
nonce n)]` now resolves: `t2` appears and executes; `t1` does not appear, and its turn is "the pre-state
immediately before the record's next transaction … that appears", i.e. immediately before `t2`'s position,
where the sender's nonce is still n and `t1`'s nonce is n+1 → discharged; the duty fires only at that turn
(where `t1` is not forceable), so no block is required to carry `t1`; and the index-order condition governs
only `t2`, which appears alone, so it holds. **The round-3 trap is closed** ✓. Mirrors: `[t1 (idx 0, n),
t2 (idx 1, n+1)]` → both appear in index order → (a) ✓; `[t1 (idx 1, n), t2 (idx 0, n+1)]` → `t2` does not
appear and its turn is before `t1`'s position (nonce n ≠ n+1) → discharged, `t1` executes → (a) ✓;
`[t1 (idx 0, n+2), t2 (idx 1, n), t3 (idx 2, n+1)]` → `t1` discharged before `t2`'s position, `t2`, `t3`
execute in index order → (a) ✓; two records of one sender with the same nonce → one executes, the other's
transaction is discharged at its turn (nonce consumed) → (a) or (b) ✓; a record whose first transaction
appears and whose later one does not → **the later one's turn is the end of the batch** → the walk demands it
if forceable, the duty never fires → R4R4-S-02 route 1. Every shape resolves by exactly one mode; the duty
fires only where the walk would execute, **except** the end-of-batch turn.
**(b) The predicate against block validity.** Answered by R4R4-S-01: the intrinsic-gas floor and signature
recovery closed two classes, but a fee-cap inversion, an oversized initcode, a fee cap below the base fee and
a sender with code are all forceable under (2) and uncarryable — the rule's claim to the contrary is false.
**(c) Record ordering against the turn pre-state.** The producer cannot insert, reorder or drop a transaction
*of the record* (the record's bytes are fixed), and the walk follows the record's own order ✓. A carried
competing transaction of the same sender can move the turn's pre-state and cause a **justified discharge**
(nonce consumed), never a no-mode position ✓; a credit can only enable (raise the balance), never discharge ✓,
and the rule's corrected wording (nonce immovable, balance movable, a credit only enables) is right ✓. The
residual is F-FI-3 (the sender's own superseding transaction), disclosed ✓. The no-mode risk comes from the
two seams above (an uncarryable transaction, or an omitted one), not from the credit edge.
**(d) The two turn definitions.** FI-13(1)(a)'s pin and CONS-01(v)'s repetition agree word for word in
effect (appears → before its own position; absent → before the record's next appearing transaction; no later
appearing transaction → the end of the batch), so a guest and a proposer compute the same turn ✓ — the defect
is not disagreement but that the shared third case names a state no block owns (R4R4-S-02).

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 2 | R4R4-S-01 (the predicate calls uncarryable transactions forceable — one publication stops settlement; the duty becomes unsatisfiable) · R4R4-S-02 (the duty is weaker than the walk: the end-of-batch turn is no block's pre-state and the remaining-gas clause excuses omission, so a forced transaction can be omitted with no rule violated and the resolving range is unprovable) |
| High | 0 | — |
| Medium | 1 | R4R4-S-03 (DA-07's publication byte string versus FI's transaction list; one register, no type flag) |
| Low | 0 | — |

**Strongest attack: R4R4-S-01.** Publish one record whose transaction has `maxPriorityFeePerGas >
maxFeePerGas` (or an oversized initcode, or a fee cap below the base fee). It is forceable under FI-13(2) —
the round-3 repair's own claim that no such transaction exists is false — but no valid block can ever carry
it, so it can never appear and is never discharged: the position is unresolved for every proof, the frontier
stops there, and the per-block duty demands an inclusion that cannot be made. The predicate must add the
byte-decidable validity conditions and the owner must decide how to handle the base fee without returning to
the steerable-void hole.

**Is the increment safe to ship?** **No, and this round is not clean.** The round-3 repairs are genuine and
the round-3 trap is closed, but the same class of seam remains in two places: the proof-side walk demands
what the block side does not compel (R4R4-S-02) and what no block can carry (R4R4-S-01). Both must be fixed
before shipping — S-01 by extending the predicate/void classes and deciding the base-fee treatment, S-02 by
giving the walk a discharge ground that mirrors the block-level escape or by restoring a per-block
reservation for forced work — and R4R4-S-03 should be pinned in the same pass. With those, the mechanism's
per-transaction walk, its turn pinning, its index-order scoping and its anti-steering wording are otherwise
sound.
