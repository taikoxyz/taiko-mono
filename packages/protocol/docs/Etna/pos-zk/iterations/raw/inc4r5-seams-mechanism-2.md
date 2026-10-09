# Increment 4 round 5 — the round-4 seams, the quotes and the counts

**Reviewer:** r6-gov-generations (task-57), independent adversarial reviewer.
**Snapshot:** `930b1edee` (working tree clean at claim). **Charge:** read both sides of every seam the round-4
repairs touched; verify every "in full / verbatim / word for word / exactly" claim by stripped-tag normalised
comparison (reporting the compared length) and every count/enumeration against the thing it counts; walk the
full test set and decide whether any producer admissibility choice leaves a position unresolvable.
**Method:** the specification is authoritative. Citations: `NN:line` = `spec/NN-*.html` at the snapshot;
`RC-n` = the delta's closure sections; report lengths are normalized (tags stripped, entities unescaped,
whitespace collapsed, space-before-punctuation removed).

**Counts: Critical 0 · High 0 · Medium 1 · Low 2.**
**Verdict: the round-4 repairs are real, the four test-set shapes resolve, and the round-3/4 halt classes are
closed — this is the first round with no Critical and no High.** One Medium remains: the mirrored no-room
discharge ground states two different conditions in one sentence in both the rule and the guest check
("no block of the range at or after the turn had room" versus the em-dash gloss "the remaining gas, at that
turn, of the block in which the turn lies"); under the summary reading a producer can leave a position
unresolved with no rule breach — the round-4 S-02 halt — while under the gloss it resolves. Two Lows: the
delta's falsifier enumeration is stale by one (`F-FI-1…F-FI-7` against the artifact's eight), and class (E)'s
rationale claims an uncarryability the registered floor does not have. **Safe to ship only after the Medium's
one-clause wording fix**; nothing else found.

---

## Finding R4R5-S-01 — Medium: the no-room discharge ground's summary phrase and its definitional gloss are different conditions, and the summary reading re-opens the S-02 halt

**Severity: Medium.** One-line rationale: the discharge ground reads "at that turn, **no block of the range at
or after the turn** had room to carry it — **the remaining gas, at that turn, of the block in which the turn
lies** was below the gas limit t declares"; these are different tests — one quantifies over every block from
the turn onward, the other reads one block — and they differ exactly when the turn's block is full but a later
block of the range has room, which is the ordinary state of a range with more than one block. Under the gloss
the transaction is discharged and the position resolves; under the summary the transaction is not discharged,
the walk requires it, and the per-block duty — turn-scoped, "at the transaction's turn and only there" — does
not compel any later block to carry it, so a producer may omit it with no rule breach and the range that must
resolve the position becomes unprovable: the round-4 S-02 halt, now reachable through the wording of its own
repair.

**File + rule id.**
- `04:740` (**FI-13(1)(a)**): "or, at that turn, no block of the range at or after the turn had room to carry
  it — the remaining gas, at that turn, of the block in which the turn lies was below the gas limit t
  declares, the same remaining gas the per-block duty of CONS-01(v) and FI-11(4) reads at the same turn, so a
  block that had room and omitted t is a breach and leaves the position unresolved".
- `04:740` (**FI-13(1)**, restatement): "A transaction that can execute at its turn and does not appear in
  the executed payload is neither executed nor discharged unless, at its turn, no block of the range at or
  after the turn had room to carry it — the mirrored discharge ground of (1)(a) — in which case it is
  discharged".
- `05:271` (**PRF-04(vi)**): the same sentence, word for word ("or no block of the range at or after the turn
  had room to carry it — the remaining gas, at that turn, of the block in which the turn lies was below the
  gas limit t declares … a claimed discharge that fails any one of these four conditions at that turn").
- `04:736` (**FI-11(4)**, CONS-01(v)): the duty fires only at the transaction's turn ("the duty applies at
  the transaction's turn and only there"), so no later block is obliged to carry the transaction.
- The delta already carries the intended reading: "a forceable transaction can be discharged only **where its
  block at that point had no room**" (`04-forced-inclusion-design.md`, S-02 closure).
- **Missing rule / correction:** replace the summary phrase in both places with the gloss — "the block in
  which the turn lies had no room at the turn to carry it (its remaining gas there was below the gas limit t
  declares)" — or define the summary as that condition; and state that a later block's room neither rescues
  nor condemns a transaction whose turn has passed (consistent with the turn-scoping).

**Assumptions.** None beyond the rules: the range has at least two blocks; the turn lies in a block whose
remaining gas at the turn is below the transaction's gas limit; a later block of the range has room (a fresh
block's gas limit is at least `FI_RECORD_GAS_MAX` by the register relation); the producer omits the
transaction.
**Concrete attack trace.**
1. Publish a record `[t (index 0, sender A, nonce n), s (index 1, sender B, nonce m)]` with both senders
   funded, both transactions within the bounds. `s` executes in a later block of the range; `t`'s turn is the
   pre-state immediately before `s`'s position.
2. At that turn the block in which it lies has no room (remaining gas below `t`'s gas limit) — the producer
   fills it with ordinary transactions, which "a block that cannot [carry forced work] is not [invalid]"
   permits. A later block of the range has room.
3. Under the gloss, `t` is discharged: the record resolves as (a) with `s` executed and `t` discharged ✓.
   Under the summary phrase, "no block of the range at or after the turn had room" is false (the later block
   has room), so `t` is not discharged, and since it does not appear the walk requires it executed; the duty
   does not demand it in the later block (its turn has passed), so the producer's omission breaches nothing —
   the position is unresolved and FI-11(3)(c) makes the proof invalid. The range cannot be settled, and
   because batches are contiguous the frontier stops at the position until the record dies.
4. A guest implementation that follows the summary phrase therefore rejects batches the gloss makes provable
   — a client-level liveness bug from a purely textual seam.

**Fault-model verdict.** Inside: no assumption failure, no rule breach by any party under the summary reading;
under the gloss there is no attack at all. The harm is a normative ambiguity whose one reading is the round-4
Critical.
**Attacker cost.** One block's gas to fill the turn's block (or none under congestion); the omission itself is
free.
**Requirement affected.** FI-13(1)(a); PRF-04(vi); FI-11(4)'s "the two checks MUST agree"; FI-13(5)'s
totality. If the summary phrase is the operative norm this is the round-4 S-02 Critical and must be treated as
such; the fix is mandatory before shipping either way.
**Evidence.** `04:740`, `04:736`, `05:271`; delta S-02 closure.

---

## Finding R4R5-S-02 — Low: the delta's falsifier enumeration is stale by one

**Severity: Low.** One-line rationale: the artifact now carries **eight** falsifiers (`F-FI-1…F-FI-8`; spec/10
says "the eight falsifiers `F-FI-1…F-FI-8`", FI-11's footer lists all eight, and the delta itself defines
`F-FI-8` at line 1012 as "New (review round 4, finding S-01; RC-7)"), but the delta's reconciliation note
still tells the register/index/disclosure implementers the set is `F-FI-1…F-FI-7`: "the censorship row and the
rejected-alternatives row move from 'no inclusion obligation' to the revived obligation with its falsifiers
(`F-FI-1…F-FI-7`: RC-6 adds F-FI-7 …)" (delta line 1181).
**File + rule id.** `increments/04-forced-inclusion-design.md` line 1181; against `10-assurance.html` (four
occurrences of `F-FI-1…F-FI-8`, one "eight falsifiers"), `04:736` (FI-11 footer: "`F-FI-1, F-FI-2, F-FI-3,
F-FI-4, F-FI-5, F-FI-6, F-FI-7 and F-FI-8` are the named falsifiers"), and the delta's own `F-FI-8` row.
**Missing rule / correction:** update the note to `F-FI-1…F-FI-8` and name `F-FI-8` as the enumeration
residual.
**Assumptions.** None. **Attack trace.** None (a count in the implementation source; the count is what the
round asked to check). **Fault-model verdict.** Inside (documentation). **Attacker cost.** None.
**Requirement affected.** The delta's register/index/disclosure instructions; the eight-falsifier count.
**Evidence.** delta:1181, delta:1012; `10` (eight); `04:736`.

---

## Finding R4R5-S-03 — Low: class (E)'s stated ground is not an uncarryability, and the sentence says it is

**Severity: Low.** One-line rationale: class (E) voids a live record whose transaction declares
`maxFeePerGas` below `FI_MIN_EXEC_FEE_CAP` and justifies it with "so a transaction that declares less is
executable by no valid block"; under the registered premise the floor is at or above the **maximum** base fee
the schedule can produce, so a cap below the floor can still be at or above the **current** base fee and the
transaction is carryable — the floor is a policy floor (declare at least the floor, or be void), not an
uncarryability class. The register row states the policy and the Open premise correctly (`09:195`), so the
rule text's "so" is the only false step.
**File + rule id.** `04:740` (FI-13(1)(b)(E) and the same wording in PRF-04's enumeration); against
`09:195` ("the registered floor on a forced transaction's declared maxFeePerGas: a transaction whose declared
cap is below it is not forceable under FI-13(2)(vi) and is the byte-invalid void ground of FI-13(1)(b)(E) … the
floor is at or above the maximum execution base fee the L2 fee schedule can produce in any window … a schedule
that can exceed the floor makes a transaction the predicate calls forceable one no valid block can carry, i.e.
the review round 4 finding F1 Critical again").
**Missing rule / correction:** say what the floor is — a registered policy floor whose premise bounds the
schedule (F-FI-7) — rather than claiming that a below-floor cap is uncarryable; keep (2)(vi) and the class.
**Assumptions.** The current base fee is below both the floor and the declared cap. **Attack trace.** None
(a user who declares a low cap loses the record to void and re-publishes with a compliant cap; the direction
is conservative, not exploitable). **Fault-model verdict.** Inside (documentation precision).
**Attacker cost.** None. **Requirement affected.** FI-13(1)(b)(E), FI-13(2)(vi), 09:195, F-FI-7.
**Evidence.** `04:740`, `09:195`.

---

## The "in full" claim, verified

**FI-11(4)'s "CONS-01(v) reads, in full:" is verbatim.** Normalized comparison (HTML tags stripped, entities
unescaped, whitespace collapsed, space-before-punctuation removed) between the quote embedded in FI-11(4) and
the `CONS-01` block in spec/02: **quoted length 6,819 = source segment length 6,819, equal: true** (the only
prior mismatch was my own normalization artifact — a space before a comma produced by tag stripping). The
quote includes the whole turn-scoped clause, its order requirement and its closing italic annotation, so the
"in full" claim holds as of this snapshot. The delta repeats the same clause as a markdown blockquote; I did
not treat the delta as a clause for this test. (Other "verbatim/in full" claims in the touched files —
spec/02's CometBFT quotation, the vault-sweep "in full" uses in spec/05 — are outside this angle; the
CONS-01(v) pair is the one the FI family depends on.)

## The counts and enumerations, checked

| Claim | Count in the artifact | Verdict |
|-------|----------------------|---------|
| "the three resolution modes" (c)/(b)/(a) | 3 | ✓ |
| (b)'s "three limbs" (over-bound; byte-invalid; all discharged) | 3 | ✓ |
| "exhaustive classes" (A)–(G) | 7 (A decode, B chain id, C signature, D intrinsic gas, E fee floor, F fee order, G initcode cap); (E) is called "the fifth class" ✓ | ✓ |
| forceability conditions (i)–(viii) | 8 | ✓ |
| "these four conditions" of the discharge ground (nonce, balance, sender code, no room) | 4 in FI-13(1)(a) and 4 named in PRF-04(vi) ("a claimed discharge that fails any one of these four conditions") | ✓ |
| falsifiers "F-FI-1…F-FI-8" | 8 in spec/10 ("the eight falsifiers"), 8 in FI-11's footer; **7** in the delta's note | ✗ delta (R4R5-S-02) |
| "the same exhaustive list is named at PRF-04(vi)" | PRF-04 names the classes wholesale ("classes (A)–(G) cover") and carries the fee floor, fee-order, initcode, intrinsic-gas, chain-id, decode and sender-code conditions | ✓ (named, not enumerated letter-for-letter — acceptable for a guest clause that references the rule) |
| "no transaction exists that (2) calls forceable and no valid block can carry" | scoped: "for a reason this predicate or the enumerated classes (A)–(G) cover, and none at all within that enumeration under the Open fee-schedule premise"; the residual is `F-FI-8` Open | ✓ honest (the round-4 denial is gone) |

## The round-5 test set, walked against the current text

| Shape | Mode | Can a producer's admissibility choice change it? |
|-------|------|--------------------------------------------------|
| `[t1 idx0 nonce n+1, t2 idx1 nonce n]` (descending) | (a) mixed: `t2` appears and executes; `t1` does not appear and its turn is the pre-state before `t2`'s position, where its nonce is ahead → discharged. An admissible payload cannot carry both (the consensus order rule forbids `t1` after a higher-index appearance, and `t1` cannot execute first) | No — the record's own order and the sender's nonce decide |
| `[t1 idx1 nonce n+1, t2 idx0 nonce n]` (mirror: index order = nonce order) | (a): both execute in index order | No |
| same-nonce pair `[s idx0, t idx1]` with `s` in the last block | (a) mixed: `s` executes; `t`'s turn is the state after the record's last earlier appearing transaction (the last block's body end) where the nonce is consumed → discharged | No |
| earlier sibling appears in the last block, later transaction does not | (a) or (b): the tail turn is the state after the sibling, the duty reads that block's own remaining gas there — room → the block must carry the later transaction (index order fine); no room → discharged | Yes — room vs no room decides executed vs discharged; **disclosed** as the filling cost of F-FI-2/F-FI-4 |
| `maxFeePerGas` below the floor | (b) class (E), live-only; dead → (c) first | No (record's own bytes) |
| malformed fee market (`maxPriorityFeePerGas > maxFeePerGas`) | (b) class (F) | No |
| oversized initcode | (b) class (G) | No |
| sender with code | (a)/(b) by discharge at the turn (EIP-3607; L2 state, not a byte class) | The sender's own state; no producer can put code at another's address by block contents |
| zero-transaction record | (b) (nothing to execute), live-only | No |
| exact byte/tx bound | Not over-bound ("at most") → walk applies; (a) or (b) | No |
| exact deadline | (c) first and unconditionally (`≤ A` dead, `> A` live) | No |
| two records of one sender | One executes; the other's transaction is discharged at its turn (nonce consumed) → (a) or (b) | No (both are the sender's own signatures) |
| reorg across the window | Recomputed from the reorged L1 state; a reorged publication has no position, a reorged `land` undoes its settlement record | No |
| uncarryable for a reason outside (A)–(G) | `F-FI-8` Open, disclosed — no longer denied. One byte-decidable instance the owner may want inside the enumeration rather than in the residual: a transaction of a type the L2's execution rules do not accept | n/a (Open) |

**Joint property.** With the turn scoped to the transaction's turn in both clauses, the turn pinned by
position (including the re-pinned tail), the consensus-side order requirement and the proof-side index
condition, **no admissible block makes a position unresolvable under the definitional reading of the no-room
ground** — and the round-3 and round-4 halts are closed. The remaining hole is the wording of that ground
(R4R5-S-01).

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | R4R5-S-01 (the no-room ground's summary phrase is a different condition from its gloss; the summary reading is the round-4 S-02 halt) |
| Low | 2 | R4R5-S-02 (the delta's falsifier list is stale by one: `F-FI-1…F-FI-7` vs the artifact's eight) · R4R5-S-03 (class (E) claims an uncarryability the registered floor does not have; it is a policy floor) |

**Strongest attack: R4R5-S-01.** It is the only surviving seam of the round-4 repairs: one sentence states the
no-room discharge twice, once as a quantification over every block at or after the turn and once as the
remaining gas of the turn's own block; they differ whenever the turn's block is full and a later block has
room, and on the summary reading a producer may omit the transaction with no rule breach — the per-block duty
is turn-scoped — leaving the position unresolved and the range unprovable. It is one clause to fix, in two
files, and the delta already carries the intended reading.

**Is the increment safe to ship?** **Not quite as written, but this is the first round with no Critical and
no High.** Fix R4R5-S-01's wording in FI-13(1)(a) and PRF-04(vi) (mandatory — the summary reading is a
halt), correct the delta's falsifier count, and re-word class (E)'s rationale; with those the mechanism's
walk, turn pinning, order rule, enumeration, fee floor and falsifier set are consistent, the "in full" quote
of CONS-01(v) is verbatim, and every shape in the round-5 test set resolves by exactly one mode. I would ship
after that pass, with F-FI-7 and F-FI-8 carried Open as the artifact states.
