# Increment 4 round 3 — the per-transaction ground, totality against the round-2 test set, and a new seam

**Reviewer:** r6-gov-generations (task-49), independent adversarial reviewer.
**Snapshot:** `94255e9df` (working tree had only `learn/11-forced-inclusion.html` modified when I started; all rule
quotations are from the snapshot). **Angle:** attack the new per-transaction resolution ground — totality for
every published record, the round-2 test set, and the two extensions (the immutable-half void ground and the
batch-wide turn pre-state).
**Method:** the specification is authoritative. Citations: `NN:line` = `spec/NN-*.html` at the snapshot;
`RC-5` = the delta's ruling/closure section; `R1/R2` = `iterations/raw/inc4r1-mechanism.md`,
`inc4r2-*.md`.

**Counts: Critical 1 · High 0 · Medium 0 · Low 1.**
**Verdict: the per-transaction rewrite is real, and it resolves every round-2 shape except one — but the seam
it opens between the walk and the per-block duty is a new, permissionless trap.** FI-13(1)–(5) now walk each
transaction in the record's own order and discharge it at its turn; every round-2 construction (one forceable
plus one never-forceable, shared nonce, unaffordable-first, conflicting nonce pair, the producer-replacement
shape, zero transactions, exact bounds, exact deadline, later-record dependency) resolves by exactly one mode.
The exception is a record whose transactions are ordered in the payload **opposite to their sender-nonce
order** (`[t(nonce+1), t(nonce)]`): the walk must discharge the first and execute the second, but the
unchanged per-block duty CONS-01(v) (FI-11(4)) *mandates* the first transaction's inclusion in any block with
room once the second executes — and a block that contains them in that order cannot be resolved by the walk
("in increasing transaction index"), so **following the per-block rule produces a certified range that no
proof can settle**, permanently, because ranges are contiguous. One publication triggers it (R4R3-T-01). A
second, smaller item: the turn pre-state is neither pinned for a transaction that never appears nor fully
producer-independent (third-party funding), so FI-13(2)–(3)'s producer-independence claim is slightly
overstated (R4R3-T-02).

---

## Finding R4R3-T-01 — Critical: a nonce-descending record makes the per-block duty and the resolution walk mutually unsatisfiable — one publication can trap a certified range

**Severity: Critical.** One-line rationale: FI-13(1)(a)/PRF-04(vi) require a record's executed transactions to
appear "in increasing transaction index", so a record `[t1 (index 0, nonce n+1), t2 (index 1, nonce n)]` can
only be resolved as (a) mixed — `t1` discharged at the batch's start (nonce n+1 ≠ n) and `t2` executed — but
CONS-01(v) is unchanged and still demands that **any** block with room contain `t1` ("MUST contain t if its
remaining gas at that point is at least the gas limit t declares") as soon as `t2` executes and `t1` becomes
forceable under FI-13(2); a block that obeys the duty contains `t2` then `t1` and therefore **cannot be
resolved** (executed out of index order), so the range containing it is unprovable for ever, and because
batches are contiguous (`firstHeight = prevHeight + 1`) settlement stops there — the exact
permissionless-publication halt the last two rounds were about, now arriving through the per-block rule.

**File + rule id.**
- `04:740` (**FI-13(1)(a)**): executed — "walking its transactions in the record's own order each one either
  executes (appears in the batch's executed payload, each exactly once, **in increasing transaction index
  within the record**) or is discharged — it does not appear, and at the pre-state its turn reaches in the
  batch's own execution, after the record's own preceding transactions have executed and after every
  transaction the batch executes before that point, it cannot execute …".
- `05:271` (**PRF-04(vi)**): the guest "MUST require that every position in `[c, c + R)` is resolved … or
  executed (… each of the record's transactions either appears in the batch's executed payload, each exactly
  once, **in increasing transaction index**, … or does not appear and is verified as discharged at its turn
  …)" and "MUST reject a proof in which a transaction that can execute at its turn does not appear or is
  claimed discharged although it could execute".
- `04:736` (**FI-11(4)**, CONS-01(v), **unchanged by this round**): "For every block h of the range, at
  every pre-state of h: if a forced transaction t of a record j that is due at the batch's anchored view A,
  live at A, and not dead at A **is forceable at that pre-state under FI-13(2)**, and t has not been executed
  in an earlier block of the range, then h's body MUST contain t before it contains any forced transaction of
  a record k > j, **and MUST contain t if its remaining gas at that point is at least the gas limit t
  declares**." The same clause states "the two checks MUST agree; a disagreement is a protocol defect".
- **Missing rule:** the per-block duty must be scoped to the walk's own semantics — e.g. apply CONS-01(v)
  only to transactions the resolving walk can execute (those forceable at their turn in the record's own
  order), or evaluate the duty at the transaction's turn rather than against the raw FI-13(2) predicate, or
  drop the "in increasing transaction index" payload-order requirement in favour of a set/record-level
  condition, or make the index order a block-validity rule so a batch that violates it is unbuildable rather
  than unprovable. Any one of the four removes the trap; leaving the two rules as written does not.

**Assumptions.** The publisher may order its payload freely (nothing in DA-07/PRF-07 requires nonce-ascending
order); the proposer builds a block that has room after `t2` and follows CONS-01(v) (the normative block
rule); the prover proves the contiguous range the L2 produced (PRF-04(v)). No key, stake or validator
cooperation is assumed; the attacker needs one publication and one ordinary L2 transaction.

**Concrete attack trace.**
1. An attacker (any account) publishes a record at position `j` whose payload is
   `[t1 = A → X, nonce n+1], [t2 = A → Y, nonce n]`, both signed by A, both within the per-record gas and
   byte bounds, chain id matching, both affordable in sequence. The record is live and becomes due.
2. When `j` enters the window `[c, c + R)`, the walk needs `t2` executed: at `t2`'s turn it is forceable, so
   the guest rejects a proof in which it does not appear (PRF-04(vi)). The first block of the range that has
   room therefore contains `t2`.
3. After `t2` executes in block `h`, `t1` (nonce n+1) is forceable at the next pre-state of `h` (nonce and
   balance now match), and `t1` has not been executed. CONS-01(v) then mandates `t1` in `h` whenever `h`'s
   remaining gas at that point is at least `t1`'s gas limit — the ordinary case, where the block has room.
4. `h`'s payload is therefore `t2` then `t1` (the only executable order: `t1` cannot run before `t2`'s nonce
   is consumed). At the walk, both appear → both executed; but FI-13(1)(a)/PRF-04(vi) require the executed
   transactions to appear "in increasing transaction index", and `t2` (index 1) appears before `t1`
   (index 0). The record is not (a); it is not (b) (not over-bound, no byte-invalid transaction, not every
   transaction discharged) and not (c) while live → the position is unresolved, the proof is invalid
   (FI-13(5), FI-11(3)(c)), and since the range containing `h` must be proven before any later range, the
   frontier can never pass `j` — settlement stops permanently (HALT-03 stops production at the depth cap,
   and v1 has no recovery path).
5. The only escape is to leave no room for `t1` in `h` (remaining gas below `t1`'s gas limit) **and** end the
   range at `h`, so that no later block of the range is obliged to include `t1`. That is exactly what the
   rules do *not* require: they require the opposite when there is room, and a proposer or validator that
   follows CONS-01(v) literally chooses the trap. (If the proposer instead omits `t1` with room available,
   the block violates FI-11(4) — a disagreement the same clause calls a protocol defect.)
6. The milder limb of the same seam, independent of any reading: CONS-01(v) keys on a transaction being
   forceable under FI-13(2) and keeps demanding the inclusion of transactions the walk has already
   **discharged** — the same `t1` in a later block or range, a transaction of a byte-invalid record that the
   walk resolves void without execution, and the F-FI-3 case where a transaction is discharged because the
   sender's own later-signed transaction consumed its nonce or its balance. The per-block check and the
   proof-side check then apply different predicates to the same transaction, which FI-11(4) forbids.

**Fault-model verdict.** Inside: one permissionless publication, no assumption failure, no producer or
validator corruption required. The trap needs a rule-following proposer with room in the block; a proposer
that deliberately pads the block avoids it, but the rules state no such duty — so the protocol defect stands
between the two rules, and the halt is reachable whenever the rule-following behaviour is taken.
**Attacker cost.** One L1 publication plus one ordinary L2 transaction (fees only); no stake.
**Requirement affected.** FI-11(4)'s "the two checks MUST agree; a disagreement is a protocol defect";
FI-12(5)'s "a compliant batch always exists"; FI-13(5)'s totality claim; D-12/D-18's fixed decision that the
narrow obligation must not halt the chain.
**Evidence.** `04:736` (FI-11(4)), `04:740` (FI-13(1)(a),(5)), `05:271` (PRF-04(vi)); delta `RC-5` ("the
walk is total"), which states the totality but does not reconcile the per-block duty with it.
**Reading note.** The finding is Critical on the text's natural reading, in which "in increasing transaction
index" constrains the order in which the executed transactions appear in the payload. If the owner reads it
as a set condition (the executed indices are distinct and increasing as a set, regardless of payload order),
the unprovable-range limb disappears and what remains is the milder limb in step 6 — a High-severity
disagreement between the two must-agree checks, which still blocks a clean round. Either way the seam needs
the fix above.

---

## Finding R4R3-T-02 — Low: the turn pre-state is not pinned, and FI-13(2)–(3)'s producer-independence claim is overstated for third-party funding

**Severity: Low.** One-line rationale: for a transaction that does **not** appear, the text's turn ("the
pre-state its turn reaches in the batch's own execution, after the record's own preceding transactions have
executed and after every transaction the batch executes before that point") has no referent — the
transaction's place in the execution is what is being decided — so two conforming guests can compute
different pre-states for the same batch and disagree on whether a discharge is justified; and the claim that
"the two L2-state facts the producer cannot move (a nonce and a free balance)" / "the only things that can
move an account's nonce or balance are that account's own signed transactions" is false for **credits**: any
third party, including the producer, can fund the account with an ordinary transfer, and the producer's
ordering decides whether that transfer precedes the turn (the transaction must then execute) or follows it
(the transaction is discharged as unaffordable).
**File + rule id.** `04:740` (FI-13(1)(a) turn wording; FI-13(2): "two L2-state facts the producer cannot
move (a nonce and a balance)"; FI-13(3): "the only things that can move an account's nonce or balance are
that account's own signed transactions"); `05:271` (PRF-04(vi): "the guest MUST recompute the pre-state its
turn reaches in the batch's own execution"). **Missing rule / correction:** define the turn recursively —
the pre-state immediately after the record's preceding transaction that executes, and the batch's initial
state when none precedes, with a non-appearing transaction evaluated there — and say that affordability is
tested at that point, so a transaction funded later in the same batch is discharged at its turn (re-publication
is the remedy), rather than claiming producer-independence that credits falsify.
**Assumptions.** The sender's transaction is unaffordable at its turn and would be affordable later in the
same batch through a third party's transfer. **Attack trace.** A producer that dislikes a published
transaction orders the funding transfer after the transaction's turn; the transaction is discharged
(FI-13(3)'s residual, "F-FI-3") and, if it was the record's only transaction, the record is void and the
frontier passes. The direction is bounded — the transaction must already be unaffordable at its turn, and the
sender can re-publish — but it is a producer choice, not the sender's, in the credit direction.
**Fault-model verdict.** Inside (bounded; no fund or history effect). **Attacker cost.** One L2 transfer plus
block timing. **Requirement affected.** FI-13(2)–(3)'s producer-independence statements; F-FI-3's
attribution. **Evidence.** `04:740`, `05:271`.

---

## The round-2 test set, resolved

| # | Shape | Mode(s) | Producer/counterparty choice changes the mode? |
|---|-------|---------|------------------------------------------------|
| 1 | One forceable + one never-forceable (far nonce) | (a) mixed: the forceable one executes, the other is discharged at its turn | No — only the sender's own txs move the nonce/balance (debit direction) |
| 2 | Two transactions sharing a nonce (same sender) | (a) mixed: the first executes, the second is discharged (nonce consumed) | No in outcome; which of the two executes is decided by the sender's own signatures and the producer's order among them |
| 3 | Unaffordable first, affordable later (same or different senders) | (a) mixed (discharged + executed) or (b) all-discharged | Only via credits in the batch — R4R3-T-02 |
| 4 | Two records of one sender with conflicting nonces | One record (a) executed, the other (b) void (its transaction discharged) | No — both are the sender's own signatures |
| 5 | Producer includes the sender's own replacement mid-batch (no crafted record) | (b) void: the record's transaction is discharged at its turn, not left unresolved (round 2's hole is closed here) | The replacement is the sender's own signature (F-FI-3) |
| 6 | Transaction executable only after a **later** record's transaction | (a): if the later record's tx executed before the turn, this one executes; otherwise it is discharged and the later one executes | Ordering among the sender's own txs; both resolve |
| 7 | Transaction executable only after an **earlier** record's transaction | (a): discharged if its turn precedes that execution, executed otherwise; either way resolved | Same |
| 8 | Chain-id-mismatch transaction, otherwise funded | (b) limb 2 (immutable half): the whole record is void, live-only | No — the record's own bytes; see the extension check below |
| 9 | Zero-transaction record | (b) limb 3 (nothing to execute; live-only); dead → (c) first | No |
| 10 | Record exactly at the byte/tx bound | Not over-bound ("at most") → walk applies; (a) or (b) | No |
| 11 | Record at the exact deadline boundary | (c) dead iff `l1BlockNumber + T_PROVE_DEADLINE ≤ A`, tested first and unconditionally | No — stored block + registered constant |
| 12 | Two records for the same position | Impossible: one register entry per position, append-only | — |
| 13 | Reorg across the window | The walk is recomputed from the reorged L1 state; a reorged publication has no position and a reorged `land` undoes its settlement record | No |
| 14 | **Nonce-descending record `[t(n+1), t(n)]` with the per-block duty** | **Unresolvable in the rule-following block** — R4R3-T-01 | **Yes — the producer's inclusion decision (room) decides between an unprovable range and a block that violates FI-11(4)** |

**Extension checks.** (i) *The immutable-half void ground* (chain id mismatch) is decidable from the record's
own bytes plus one registered constant, with no producer-set input, and it opens no new *steerable* ground: a
third party cannot inject the bad transaction into the victim's record (the record is the publisher's own
payload), so the guarantee that a user's own publication is forceable is preserved; the note that a single
bad transaction voids the user's whole record is disclosed in FI-13(4) (re-publication is the remedy). Its one
rule-set consequence is the milder limb of R4R3-T-01: the record's *other* transactions are still forceable
under FI-13(2), so CONS-01(v) demands their inclusion while the proof resolves the record void without
execution. (ii) *The batch-wide turn pre-state* is decidable (the guest re-executes the batch and recomputes
each turn) and adds no new void ground — the limbs remain bytes, registered constants and liveness; but see
R4R3-T-02 for its producer-dependent edge and its missing definition for non-appearing transactions.

**Verified as fixed / sound.** FI-13(1)–(5) genuinely implement per-transaction resolvability with dead-first
and void-limb-first precedence, so the three modes partition their cases; the record-level forms "all of its
transactions" and "none of whose transactions is forceable" are gone; PRF-04(vi) makes the guest recompute
each turn pre-state, accept a discharge only on the nonce or balance condition, and reject a claimed discharge
that fails it or an executable transaction that does not appear; a mixed record is recorded per transaction;
the zero-transaction and dead-at-A cases are explicit; the delta's RC-5 matches the rule; and every round-2
shape except #14 resolves by exactly one mode.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 1 | R4R3-T-01 (a nonce-descending record makes CONS-01(v)'s mandated block content unprovable — one publication traps a certified range; milder limb: the two must-agree checks apply different predicates to discharged transactions and to byte-invalid records' other transactions) |
| High | 0 | — |
| Medium | 0 | — |
| Low | 1 | R4R3-T-02 (the turn pre-state is unpinned for a non-appearing transaction and credits are producer-orderable, so FI-13(2)–(3)'s producer-independence claim is overstated) |

**Strongest attack: R4R3-T-01.** Publish a record whose two transactions are in the order
`[nonce+1, nonce]`. The walk can only resolve it by discharging the first and executing the second, but
CONS-01(v) — untouched this round — orders any block with room to include the first as soon as the second
executes; obeying the duty puts the two executions in the wrong index order, which the walk cannot resolve, so
the range is unprovable and contiguous settlement stops there for ever. The escape (leave no room, end the
range) is behaviour the rules do not ask for, so a rule-following producer builds the trap. The fix is to
reconcile the per-block duty with the walk's turn semantics or to relax the payload-index requirement.

**Is the increment safe to ship?** **Not yet, and this round is not clean.** The rewrite genuinely closed the
round-1/round-2 hole and every shape the reviewers listed except the nonce-order seam it opened; that seam is
one publication away from an unrecoverable settlement halt and must be fixed in the same pass (the four
options in the finding). With R4R3-T-01 fixed and R4R3-T-02's wording corrected, nothing else in this round's
test set or the two extensions stands in the way of a clean round.
