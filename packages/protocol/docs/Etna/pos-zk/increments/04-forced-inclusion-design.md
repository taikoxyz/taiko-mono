# Increment 04 — Narrow forced inclusion (D-12): design delta

**Status: IMPLEMENTED, IN REVIEW.** The rules are written into the specification (FI-10..FI-14 live, PRF-04(vi) enforcing, the register and the course updated) and the increment is going through its own review rounds. It has NOT shipped: it ships only when two consecutive rounds come back with no Critical and no High, and its ship record will follow, exactly as `increments/02-ship-record.md` did for increment 2. This file began as a design delta, NOT APPLIED - No specification, register, index, course or decision file has
been edited by this pass. This document is what the implementation and its adversarial review round are
built from; the review round is the authority that closes the four blockers named in
[DEFERRED.md](../DEFERRED.md) §1.

**Scope.** This increment re-derives the **FI-10–FI-14** family so that v1 gains an **inclusion
obligation**: after a publication record's due point, the capped FIFO prefix of the due set must be
resolved by every accepted batch, and a record's exclusion beyond that point is a breach. It does
**not** add a general inclusion list (no queue of arbitrary transactions, no escrow, no
forced-inclusion fee, no L1 entry point for unpublished data — `FI-PLANNED-01`, D-12). The obligation
is enforced **in the proof**, never as an admission gate on `land` (`L1-04` survives unchanged).

**Bases.**

- Preserved rule text at `7917ba264`: `FI-REMOVED-01` and `FI-10`–`FI-14`
  (`spec/04-l1-integration.html`), the `forcedBoundary` journal field and `PRF-04(vi)`
  (`spec/05-proof-statement.html`), `CONS-01(v)` (`spec/02-consensus.html`), the `FI_*` register
  rows (`spec/09-parameters.html`). The revival is a **re-derivation against the converged v1, not a
  revert of the tombstone**: the tombstone text is not restored, and nothing here reads a deferred
  mechanism.
- Current v1 anchors this delta was written against (line numbers): `spec/04-l1-integration.html`
  L1-03 (~L83), L1-04, L1-05 rows 35–36 (~L167, ~L212), L1-08 (~L256); `spec/05-proof-statement.html`
  PRF-02 row withdrawal (~L164), PRF-04(vi) (~L269); `spec/02-consensus.html` CONS-01(v) (~L72);
  `spec/09-parameters.html` withdrawn `FI_*` rows (~L189–198) and the `L2_BLOCK_GAS_LIMIT` row
  (~L232); `spec/08-migration-upgrades.html` (~L377).
- [DECISIONS.md](../DECISIONS.md) D-11 (publication before proof), D-12 (narrow forced inclusion),
  D-16 (§1 defers it); [CONVERGENCE.md](../CONVERGENCE.md) (v1 converged; the censorship gap is a
  disclosed absence); [PLAN.md](../PLAN.md) Phase 2 item 3 (the four blockers).
- Findings actually closed here: `R6-D12-01` (Critical — expiry has no proof-side ground; L1-08
  mandates the prune FI-14 forbids), `R6-D12-02` (High — the anchor-age gate can reject an in-envelope
  batch for ever), `R6-D12-03` (High — per-block vs per-batch unit), `R6-D12-04` (High — the cap has
  no enforcement point; `cap = 0` reachable), `R6-D12-05` (High — environment-steered void),
  `R6-DPE-01` (High — the frontier's lower bound is waived by an exception with no referent),
  `R5T-PDE-01`, `R5T-PDE-03`, `R5T-PDE-04`, `R5T-PDE-06`, `R5T-PDE-07`, `R5T-PDE-10`,
  `R5T-C-1`, `R5T-H-4`/`F4`/`F5`.
- [iterations/raw/round8-*.md](../iterations/raw/) is the last review round before this increment. It
  contains no new forced-inclusion finding: it confirms the FI family is tombstoned consistently
  (`round8-artifact-consistency.md` ~L118–125, `round8-data-proof-economics.md` ~L306). The defects
  carried out of rounds 5–6 are therefore exactly the ones disposed of below.

---

## 0. What this increment decides

| # | Decision | Where |
|---|---|---|
| 1 | **One unit of account: the batch, counted in register positions.** A batch resolves a **contiguous prefix of the due set**; the obligation, the capacity relation and the no-halt argument are all stated in *positions per batch* backed by *gas per batch*. The per-block requirement is demoted to a **local order-and-non-omission duty** with no per-block count and no per-block gas quota (this closes R6-D12-03). | FI-12(1)–(3), §3.2 |
| 2 | **The frontier advance is mandatory and unconditional.** The waived lower bound of FI-11(5)/PRF-04(vi) is replaced by a two-sided bound with **no exception**: `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **and** every position in `[c, c')` resolved, where resolved means *executed*, *void* or ***dead***. There is no waiver clause, so no reading makes the obligation vacuous (this closes R6-DPE-01 and R6-D12-04). | FI-11(3) |
| 3 | **A per-transaction resolution ground with no producer-set input to the predicate.** The includability test loses the base fee and the block gas limit entirely; each transaction is executed or **discharged** at its turn, the pre-state pinned by position in FI-13(1)(a) so that a guest and a block producer compute the same one, and a live position is **void** only when the record is over-bound, contains a transaction that can never be executed from its own bytes, or every one of its transactions is discharged (*dead-first and void-limb-first precedence, so the three modes partition — RC-5 addendum*). The ground reads the record's **immutable bytes**, **registered constants** (including the registered fee floor `FI_MIN_EXEC_FEE_CAP`, whose Open schedule premise is F-FI-7 — RC-6, and the byte-decidable fee-order and initcode classes of FI-13(2)(vii)–(viii)/(1)(b)(F)–(G) — S-01) and the facts read at the turn (the sender's nonce, which only its own signed transactions can move; its balance, which anyone can move — a credit can only make a transaction executable, never discharged; and its code, which no producer can set by block contents), so it excludes every producer-set quantity from the predicate (the credit's ordering relative to the turn is the disclosed **F-FI-3** residual; this closes R6-D12-05 and corrects R4R3-T-02) and is **total**, so no mixed-forceability record can pin the frontier (this closes R4R1-M-01 — RC-5); the duty and the walk read one turn and the same remaining gas, the walk discharging a transaction no block of the range at or after its turn had room for, with the tail turn pinned to the state the batch reaches after the record's last earlier appearing transaction — so no earlier appearing transaction can execute after it, and a forceable transaction can be omitted only where its block at the turn had no room (S-02; S-02 follow-up, RC-8). | FI-13(1)–(3), FI-13(5) |
| 4 | **Expiry is an objective proof-side discharge ground keyed on the record's own deadline.** A record is *dead* at the anchored view `A` iff `deadlineBlock ≤ A`, and dead-at-`A` is a third resolution mode the proof applies with no execution, no witness and no L1 call. The pruning is made consistent by making it **deletion only, behind the settlement frontier** — the prune returns no frontier and advances nothing (this closes R6-D12-01). | FI-10(2)/(7), §4.2 |
| 5 | **The forced-data record is the D-11 publication record: one register, no flag.** The register is `publish(...)`/`publicationAt(...)`; the FI family adds a settlement record per accepted height, the `forcedBoundary` commitment, the prune, the frontier event and the errors — **no second entry point, no "forced" flag, no escrow and no fee**. | FI-10(1) |
| 6 | **Enforcement is the proof, never the gate.** `land` gains no rejection that depends on the register being non-empty; the capacity check is part of proof validity; the single expiry prune is not an acceptance condition (this preserves L1-04's no-gate property). | FI-11(1) |
| 7 | **Recovery-free survival.** With D-15/D-16 there is no recovery path and no generation of forced data to re-derive: the register and the settlement frontier are **monotone L1 state**, no rule may lower the frontier, and the two clauses of the preserved FI-14 that read the withdrawn stall resolution are **deleted** rather than carried. | §4 |
| 8 | **The exit is never blocked.** No forced-inclusion obligation attaches to the withdrawal root, its attestation, the veto, or exit eligibility; the reason is structural (the register is a settlement-side queue, not an exit dependency). | §5 |
| 9 | **Falsifiers narrowed and named.** F-FI-1 (capacity), F-FI-2 (arrival > drain — **not fixed**), F-FI-3 (discharged-then-executable), **F-FI-4 new** (deadline expiry during a stall), **F-FI-5 new** (the publication race that makes the guarantee conditional on a non-censoring L1), **F-FI-7 new** (review round 4, finding F1 — RC-6: the fee floor's schedule premise; a schedule that can exceed `FI_MIN_EXEC_FEE_CAP` makes a demanded transaction one no valid block can carry) and **F-FI-8 new** (review round 4, finding S-01 — RC-7: the enumeration residual; a transaction the predicate calls forceable and the discharge grounds do not cover, yet no valid block of the range can carry). | §6 |
| 10 | **The increment does not reopen a v1 decision**: the boundary, the exit, D-8/D-9, D-11 and "no rule removes weight" are untouched; no recovery path returns. | §8 |

---

## 1. What blocked the mechanism, and what this delta does about each blocker

**(a) The unit mismatch (`R6-D12-03`, carried from round 5's F5).** The preserved `CONS-01(v)` imposed
the prefix *per block* "up to `FI_MAX_PER_BATCH` records", while `FI-12` computed the cap *per batch*
from `batchGasCapacity`. The registered relation was batch-level, so a legal registration
(`FI_MAX_PER_BATCH = 10`, `itemGasBound = 30M`, `MAX_BATCH_BLOCKS = 10`, `L2_BLOCK_GAS_LIMIT = 30M`)
required 300M gas in one 30M block: no block satisfies (v), correct validators vote NIL, and one L1
publication halts the chain. Reading "up to" as an upper bound instead made the consensus clause say
nothing. **Resolution:** FI-11(3) with FI-12(1)–(3) — the obligation is stated **once, per batch, in register positions**;
the per-block rule keeps only the FIFO order and the non-omission duty, and has no count and no gas
quota. The capacity relation, the frontier rule and the no-halt argument are all in the same unit
(FI-12(1)–(3), §3).

**(b) The waived frontier lower bound (`R6-DPE-01`, "the Critical carried unrepaired from round 5").**
The preserved `FI-11(5)` read "`c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **unless the window is shorter
and c' ≤ nextSeq(A)**". Under the only non-vacuous reading, "the window is shorter" is the ordinary
steady state (`d(A) − c < cap`), so the lower bound was waived exactly when it mattered and
`c' = c` passed every surviving check — the frontier never advances and the obligation is dead for
the deployment's life. **Resolution:** FI-11(3)(a) — the lower bound is unconditional and the exception is
deleted; the upper bound `c' ≤ nextSeq(A)` is kept as the separate guard R5T-PDE-03 added, and the
"every position in `[c, c')` is resolved" walk is what makes an advance past an unresolved record
impossible. Nothing is waived. The drain requirement of FI-11(2)(3) — `R ≥ 1` whenever the
outstanding obligation is non-empty, which the capacity condition turns into
`R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding — independently forbids
`R = 0`, which is the reachable `cap = 0` of `R6-D12-04`.

**(c) The steerable void predicate (`R6-D12-05`, carried from round 5's F4).** The preserved
includability test was "the sender's balance covers the maximum charge the transaction can impose **at
that block's base fee**" and "its gas limit fits the block's gas limit". The producer builds the block,
so it sets the base fee and the block gas limit: fill the blocks during `FI_INCLUSION_DELAY`, push the
base fee above the published transaction's `maxFeePerGas`, and the guest voids the record — the
obligation discharged with nothing executed, repeatable at one L1 publication per cycle. The
"non-steerability" paragraph was scoped only to the per-record bounds, and the alternative reading
("a full block does not admit the transaction") gave the same outcome by ambiguity.
**Resolution:** FI-13(1)–(3) — **every producer-set term is removed from the predicate.** Whether a
position resolves is a function of the record's immutable byte string, the registered constants, and two
L2-state facts read at the transaction's turn (the sender's nonce, producer-immovable; the sender's balance, movable by anyone — a credit can only make a transaction executable, never discharged): each transaction executes,
or is **discharged** at its turn because it cannot execute there, and a live position is void only when
it is over-bound, contains a transaction that can never be executed from its own bytes (the five
byte-decidable classes FI-13(1)(b) enumerates, the fee-cap floor `FI_MIN_EXEC_FEE_CAP` among them —
RC-6), or every one of its transactions is discharged — a record dead at `A` is dead first and alone (RC-5 addendum). Base fee, block gas limit and block space are
not inputs to any execution, discharge or due test. The "block full" excuse is removed by the per-block
duty (FI-11(4)) plus the proof-side resolution walk, not by an argument about room. **The walk is total**
(FI-13(5)): because execution follows the record's own order, only the sender's own signed
transactions can move its nonce, and a credit can only make a transaction executable (never discharged),
no producer can leave a transaction unresolved by its own choices, and a record with one executable and one never-executable transaction is resolved by
discharging the second — the record-level ground that left exactly that record unresolved is R4R1-M-01's
Critical, superseded here (RC-5). *(The dead-first and void-limb-first precedence keeps the three modes a partition — RC-5 addendum.)*

**(d) Expiry with no proof-side ground, and the prune that contradicts it (`R6-D12-01`).** The
preserved `FI-10` said a record past its deadline "MUST be discarded from the due set … and no proof
may be required to include it", but the only two rules that move the guest-visible frontier accepted
only *included or void*, and `FI-13`'s only void ground was non-includability — expiry was no ground.
Meanwhile `L1-08` mandated `pruneExpiredPublications(uint32) returns (uint64 settledFrontier_)`, an
entry point returning a frontier no accepted proof had advanced: horn A (implement the prune) moves
enforcement off the proof, horn B (implement FI-14) makes a dead record unexecutable and unvoidable and
blocks the prefix for ever, and a pruned or blob-expired record cannot even be evaluated.
**Resolution:** FI-10(7) (a record dead at `A` is resolved-by-expiry, computed from the record's own
stored `l1BlockNumber` and the registered `T_PROVE_DEADLINE`, needing no bytes) and §4.2 (the prune
becomes **deletion only**, returns nothing, and may delete only positions at or below a stored prune
cursor that the settlement frontier already covers — so a pruned position is never a position the
proof still has to resolve). The interface text and the event semantics are re-based accordingly (§7).

---

## 2. Revived rules — exact text

> Normative text below. It replaces the tombstones in `spec/04-l1-integration.html` (FI-*) and the
> register/index/proof entries listed in §7; it is written as the rules will read in the specification,
> with identifiers the register and index must match. `R` below is the **resolved count of this batch**
> and `W` the **work count**; both are defined in FI-12(2).

### FI-10 — the forced-data record, the due point, the due frontier, and the expiry ground

**(1) One register, no flag.** The forced-data record **is** the publication record of DA-07: the same
one register, the same identity, the same entry point, and **no "forced" flag**. A record is forceable
from the moment it is written, and the obligation's anchor is the record's own stored
`l1BlockNumber` and nothing else (DA-10). The FI family adds no register, no queue, no escrow, no bond
and no fee.

**(2) The record's stored clock.** A publication record stores its `l1BlockNumber` and `sequence`
(DA-07(2)–(3)); those two are the record's whole clock. The rule reads the deadline as the derived
value

> `deadlineBlock(record) = record.l1BlockNumber + T_PROVE_DEADLINE` (L1 blocks, registered),

and **MUST NOT** store, mutate or re-clock it. The derived form keeps DA-07(3)'s identity preimage
unchanged — the deadline is a function of a field already inside the identity — and it keeps the record
immutable once written. A record is **live at view `A`** iff `record.l1BlockNumber + T_PROVE_DEADLINE >
A`, and **dead at `A`** otherwise. Dead is a function of the record's own stored block number and one
registered constant: it is decidable from the anchored register state alone, without the record's
bytes, its blobs, its status or any account's action. *(This owns the R5T-PDE-10 conflict: the record
is immutable, and it carries **no mutating status field**. "Live/dead" replaces the withdrawn
`PUBLISHED | PROVEN | DISCARDED` status flag. The one lifecycle fact the mechanism still needs — whether
a batch ever referenced the record — is carried by the settlement frontier itself, FI-10(5), so no
second mutable field is required.)*

**(3) Order and the register's view.** Records are ordered by the stored monotone `sequence`
(DA-07(2)–(3)). The register MUST expose, at any view, (a) its **next position** `nextSeq(A)` — the
number of records written at `A` — and (b) a storage-proof-supported read of any position
`j < nextSeq(A)`, returning the record's stored fields. `l1BlockNumber` MUST be non-decreasing in
`sequence`, so the due frontier below is a **bounded binary search** over the register's own monotone
stored blocks (L1-05 row 36), never a scan.

**(4) The due point.** A record is **due at L1 view `A`** iff

> `record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A`, `FI_INCLUSION_DELAY` in L1 blocks (registered),

and `FI_INCLUSION_DELAY` MUST be at least the SYS-02 finality requirement. The obligation's clock is
L1 state plus two registered constants and nothing else: a batch's certification time, landing time, a
proposer's clock, a node's local receipt time, an off-chain view and any caller-supplied timestamp MUST
NOT enter it (DA-10, GEN-06). Before its due point no batch is required to resolve a record, and
resolving one earlier is always permitted; **the rule fixes no height or time by which inclusion must
begin and is never a lower bound on inclusion**. From the due point on, exclusion is a breach (FI-11(3)).

**(5) The due frontier and the due set.** Let

> `d(A)` = the number of records with `record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A`,

i.e. the **due frontier** — a count over the register at `A`, **with no status or liveness filter**,
monotone in `A` and recomputable from the anchored register state by a bounded binary search. The
**due set at `A`** is the record positions `[0, d(A))`. The **settlement frontier** `c` of a batch is
the predecessor checkpoint's own recorded `settledCount` (written atomically by that height's accepting
`land`, L1-03(6)), and the positions `[c, d(A))` are the **outstanding obligation** at `A`. A record's
deadness does not remove it from the due set: a dead record is still a position the frontier must pass,
and the proof passes it by applying FI-13(1)(c).

**(6) Due point before expiry — a registered constraint.**

> `FI_INCLUSION_DELAY + L1_FINALITY_DEPTH < T_PROVE_DEADLINE` **MUST** hold (all terms L1 blocks).

Every admissible view satisfies `A ≤ block.number − L1_FINALITY_DEPTH`, so a record published at L1
block `b` is due at the first admissible view of every landing at or after height
`b + FI_INCLUSION_DELAY + L1_FINALITY_DEPTH`, and by the inequality that height is strictly below its
deadline `b + T_PROVE_DEADLINE`. Hence **a window in which the obligation can fire while the record is
live is guaranteed to exist**; a configuration that inverts the two discards every record before it can
ever be due, `d(A)` counts nothing, the required prefix is always empty and the whole rule is
structurally vacuous. The stronger latency form is **not** closed here and is recorded as unmeasured at
FI-12(5) (F-FI-2).

**(7) Expiry.** A record that is **dead** at the anchored view `A` has passed its deadline without
being referenced by an accepted batch: `land` permits `block.number ≤ deadlineBlock` (DA-09(1)), and
every admissible view satisfies `A ≤ block.number`, so **no batch can be accepted against a record
that is dead at its own view**. Expiry is therefore an objective, permissionless, proof-side discharge
ground (FI-13(3)(c)): it uses the record's own stored `l1BlockNumber` and the registered
`T_PROVE_DEADLINE`, needs no bytes, no blobs, no execution and no L1 call, and cannot be moved by any
party. Re-publication creates a new record with a new sequence and a fresh clock (DA-09(2)); this rule
does not extend, replace or weaken `T_PROVE_DEADLINE`, and nothing in expiry touches a height,
checkpoint or batch record.

**(8) No fee.** A forced-data record carries no escrow, bond, refund or protocol fee; a forced
transaction pays its own L2 gas when executed, the reward terms of L1-10 and L1-11 are unchanged, and a
publication's cost is ordinary L1 gas.

*(FI-10 keeps the preserved rule's substance and changes four things: the due-set clock is unchanged;
the status flag is replaced by the derived live/dead predicate (2); the settled frontier's own
settlement record is named once (5); and expiry gains the proof-side ground it lacked (7). The
registered parameters are `FI_INCLUSION_DELAY`, `T_PROVE_DEADLINE` and the relation (6).)*

### FI-11 — the inclusion obligation, the mandatory frontier advance, and the enforcement point

**(1) Enforcement point — the proof, not `land`.** The obligation is on the **batch** and is enforced
by the guest, in the clause PRF-04(vi). It is **not** an admission gate: `land(data, proof)` MUST NOT
reject a proof because the register is non-empty, MUST NOT require any coverage list, frontier or
due-set claim from the submitter as a condition of acceptance, and MUST NOT treat the register as a
structural bound of L1-04. Acceptance writes the settlement record of FI-10(5) only after verification
succeeds (L1-03(6)): the write is an **effect** of acceptance, never a precondition for it. The one
capacity condition of FI-12(1) is part of **proof validity**, not an admission rule: a proof that does
not show the capacity the relation guarantees is invalid, and no submitter-supplied list can satisfy
it.

**(2) What the guest recomputes.** In PRF-04(vi) the guest MUST:

1. recover the batch's anchored L1 view `A` by re-executing the SYS-02 anchor facts of every block of
   the range, set `A` to the greatest anchored L1 view any block of the range commits to, and reject
   the proof unless the journal's `anchoredL1Block` equals it (PRF-04(vi)(1)) — so the submitter
   cannot choose a batch range to shrink the obligation;
2. verify the required prefix against the **anchored register state** through the storage proofs the
   anchor step's own state root supports, rejecting any witness-supplied due list, frontier or set that
   does not verify; `c` is the predecessor checkpoint's recorded `settledCount`, `d(A)` is
   recomputed over the anchored register (a bounded binary search, FI-10(3)–(5)), and the contract's
   L1-derived view reaches the guest only as the single `forcedBoundary` commitment (L1-05 row 36) —
   the guest recomputes that commitment and requires the journal's value to match;
3. recompute `W`, `R` and the capacity condition of FI-12(1) from the batch's own headers and the
   anchored state, and reject the proof unless the condition holds and `R ≥ 1` whenever the
   outstanding obligation at `A` is non-empty (the capacity condition turns this into
   `R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding — RC-2; the walk of FI-13(1)
   is total, so `W` is the live prefix of the window and a live position's work is bounded by its own
   record's transactions — RC-5);
4. require that every position in `[c, c + R)` is **resolved** under FI-13(1)'s three modes, applied
   in the precedence (1) states (a record dead at `A` is (c) first, whatever its size, contents or
   discharge state; otherwise a live over-bound or byte-invalid record is (b) void from its own bytes
   before the walk, each of the record's transactions is then executed or discharged at its turn by the
   per-transaction walk, a position with at least one execution is (a) executed, with its executed
   transactions recorded as executed and its discharged ones recorded as discharged, and a live
   position all of whose transactions are discharged is (b) void; no position can be left unresolved
   because the walk is total — RC-5 addendum), and recompute `c' = c + R`; and
5. require that **every** position in `[c, c')` holds a record at `A` — a position with no record at
   `A` (a hole in the register) is neither executed, void nor dead and MUST make the proof invalid —
   and that the journal's `settledAfter` equals `c'`.

**(3) The frontier advance — no waiver.** The guest MUST require:

> **(a)** `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` — **unconditional**; the exception of the preserved
> text is deleted and MUST NOT reappear in any form, because "the window is shorter" is the ordinary
> steady state and reading it as a waiver makes the obligation dead;
> **(b)** `c' ≤ nextSeq(A)` — a proof cannot write the frontier past the register;
> **(c)** every position in `[c, c')` is resolved by FI-13 — so `c'` can advance only past records
> that exist at `A` and are each executed, void or dead, and **can never skip an outstanding due
> record**;
> **(d)** `c' ≥ c` — the frontier never decreases; and
> **(e)** the contract MUST reject a view that is not Ethereum-final at landing
> (`A ≤ block.number − L1_FINALITY_DEPTH`), a view older than the predecessor's recorded
> `anchoredL1Block`, and a frontier below the predecessor's `settledCount`
> (`ForcedFrontierRegression`), and MUST reject `settledAfter > nextSeq(A)`
> (`ForcedFrontierBeyondRegister`).

*There is no other clause and no exception. (a) is the binding sentence FI-11 always had in its
"exclusion deadline" paragraph; the preserved hedge ("unless the window is shorter…") is deleted, and
with it R6-DPE-01. (b)–(d) are the preserved repairs R5T-PDE-03 and the monotonicity bar.*

**(4) The per-block rule — order and non-omission at the transaction's turn, and nothing else.** The
same predicate is the per-block clause `CONS-01(v)`, and the two checks MUST agree; a disagreement is a
protocol defect. `CONS-01(v)` reads, in full:

> (v) **Forced-data inclusion — the per-block order and non-omission duty, scoped to the
> transaction's turn.** For every block `h` of the range, at every state `h`'s own execution
> reaches — every pre-state of `h` and, when `h` is the range's last block, the state its body
> ends in: if a forced transaction `t` of a record `j` that is due at the batch's anchored view
> `A`, live at `A`, and not dead at `A` **is at its turn at that state and forceable there** —
> `t`'s turn is the state FI-13(1)(a) pins by position: the pre-state immediately before `t`'s own
> position in the executed payload when `t` appears, the pre-state immediately before the record's
> next transaction in the record's own order that appears in the executed payload when `t` does
> not appear, and, when no later transaction of the record appears, the state the batch reaches
> immediately after the record's last earlier transaction that appears in the range has executed —
> the pre-state of the next transaction the batch executes, or the initial pre-state of the next
> block of the range when it executes none after it, or, that transaction being the last
> transaction of the range's last block, the state that block's body ends in, at which that
> block's own remaining gas is read — so no earlier transaction of the record can execute after
> the turn and leave `t` judged on a state from before that earlier transaction's effect; and,
> when no earlier transaction of the record appears either, the pre-state immediately before the
> last block of the range's body — a state a real block of the range reaches in its own execution,
> never a state no block of the range reaches; when the record's last transaction appears, the
> first case applies and its turn is the pre-state immediately before its own position, as before
> — and `t` has not been executed in an earlier block of the range, then `h`'s body MUST contain
> `t` before it contains any forced transaction of a record `k > j`, and MUST contain `t` if its
> remaining gas at that point is at least the gas limit `t` declares. **The duty applies at the
> transaction's turn and only there**, so it applies to exactly the transactions the proof-side
> walk of FI-13(1)(a) would execute and **never** to one the walk discharges: at the turn the walk
> reaches `t` with every earlier transaction of `j` already resolved, its verdict on `t` is
> *executable* exactly when `t` is forceable there under FI-13(2) and no discharge ground of
> FI-13(1)(a) holds at that state — the predicate carries the same byte-decidable requirements the
> void limb enumerates: the intrinsic-gas floor of (2)(ii), the registered fee-cap floor of
> (2)(vi) — a declared `maxFeePerGas` below `FI_MIN_EXEC_FEE_CAP` is void under (1)(b)(E) — the
> malformed-fee-market and initcode-cap classes of (2)(vii)–(viii) — a declared
> `maxPriorityFeePerGas` above the transaction's own `maxFeePerGas`, or a create transaction whose
> declared initcode exceeds the EIP-3860 cap, is void under (1)(b)(F)–(G) — and signature recovery
> in (2)(iv), so a transaction this clause demands is one a valid block can carry for a reason the
> predicate or the enumerated classes (A)–(G) cover — none at all within that enumeration under
> the Open fee-schedule premise the register records with `FI_MIN_EXEC_FEE_CAP` (the floor is at
> or above the maximum execution base fee the L2 fee schedule can produce; F-FI-7), with the
> residual the enumeration does not decide carried Open and falsified by F-FI-8 — while the
> discharge grounds it inherits from the walk are the nonce, the balance, a sender that has code
> at that pre-state (EIP-3607), and a turn at which no block of the range at or after it had room
> to carry the transaction — and *discharged* otherwise, and this clause fires only in the first
> case. A transaction the walk has discharged at its turn is not demanded here at any later
> pre-state, even when it has become forceable there, and no transaction of a record resolved
> **(b) void** is ever demanded, because the walk does not reach it. The per-block duty and the
> proof-side walk MUST share **one predicate** — a disagreement is a protocol defect — and a duty
> that demanded a transaction the walk has discharged would be unsatisfiable by construction,
> because a discharge is fixed by the record's own order and the batch's own execution, never by a
> block's contents. The **"increasing transaction index"** condition of FI-13(1)(a) governs only
> the transactions the walk **executes**: a discharged transaction does not appear at all, so it
> cannot violate that order and no block is ever required to include one. **Order of appearance —
> the block-validity counterpart.** A block MUST NOT contain a transaction of a forced record once
> a higher-index transaction of that same record has already appeared in the executed payload of
> the range: a block whose body contains a transaction of record `j` when a transaction of `j`
> with a higher index has already appeared earlier in the executed payload of the same range,
> including earlier positions in the same block, is **invalid**, exactly as a block that had room
> to carry a transaction this clause demands and omitted it is invalid, so the inclusion order a
> batch may use is the record's own payload order. The rule and the proof-side condition of
> FI-13(1)(a) are the two halves of one requirement: FI-13(1)(a) resolves a record only when the
> appearances it sees are in increasing index order, and this clause makes any block that would
> present them in any other order un-certifiable, so a batch built by a rule-following producer
> satisfies the condition the walk checks. The rule is scoped to the record's own transactions and
> the range's executed payload: it does not forbid a block from carrying a record's transaction
> whose higher-index record transactions have not appeared yet — the walk resolves those at their
> own turns — and it does not touch a discharged transaction, which does not appear at all. A
> transaction that appears out of the record's own order is handled by this block-validity rule —
> the block is invalid — and never silently by the walk: the discharge grounds of FI-13(1)(a) —
> the nonce, the balance, a sender with code at that pre-state (EIP-3607) and the mirrored no-room
> ground — and the tail-turn pin govern only a transaction that does not appear, and the walk MUST
> NOT read an out-of-order appearance as an execution or resolve it as a discharge. This is a
> block-validity condition of this clause: a correct validator MUST NOT sign a prevote or a
> precommit for a block that violates it, exactly as for any other failure of (i)–(viii), and no
> new slashable offence attaches to it. *(review round 4, R4R4-NR-01: the index-order condition
> was proof-only, so a producer could include a nonce-descending record's two transactions in the
> only order they can execute — the higher index first — making the executed payload's indices
> descend and leaving the position in no mode; the order requirement above is the consensus-side
> counterpart, and this clause, FI-13(1)(a) and PRF-04(vi) name each other.)* The clause has **no
> per-block record count, no per-block gas quota and no per-block capacity constant**: the number
> of records a batch must resolve is FI-12's cap, in **positions per batch**. **A block that can
> carry forced work and carries none is invalid; a block that cannot is not. **One rule, one
> predicate, both sides read the same quantity:** a block with room to carry the transaction MUST
> carry it, and the walk discharges the transaction only when, at its turn, no block of the range
> at or after the turn had room to carry it — the block's own remaining gas at that turn, the same
> quantity this clause reads. A transaction the walk so discharges is not demanded here, and a
> block that had room and omitted it leaves the position unresolved and makes the proof invalid.**
> The obligation itself is enforced in the proof, never in the admission rules of `land(data,
> proof)` (FI-11(1), PRF-04(vi)), and **no new slashable offence is created**: a validator that
> signs a block violating this clause commits no new offence, the forced-inclusion offence rows of
> ECON-04 stay tombstoned and MUST NOT be implemented, and the rejected proof is the whole
> enforcement. *(increment 04: the clause is revived as the order-and-non-omission duty, in one
> unit with FI-12; the per-block count that R6-D12-03 found unpayable is deleted, and no per-block
> gas floor is added.)* *(review round 3, R4R3-T-01/R4R3-NR-01: the duty is scoped to the
> transaction's turn, so the per-block check and the proof-side walk are one predicate; the seam
> that made a nonce-descending record unprovable — a duty demanding a transaction the walk had
> already discharged — is closed, and the "increasing transaction index" condition constrains only
> the transactions the walk executes.)* *(review round 4, finding F1: the round-3 intrinsic-gas
> floor left the fee dimension out, so a low- or zero-cap transaction was demanded while no valid
> block can carry it — the same settlement-halt class the increment exists to close; the fifth
> void class of FI-13(1)(b)(E) and the registered floor of FI-13(2)(vi) close it from the record's
> own bytes, and the agreement stated above now holds for the reasons the predicate or the
> enumerated classes cover, and unconditionally only under the Open fee-schedule premise F-FI-7.
> (review round 4, findings S-01 and S-02: this clause's agreement now also carries the
> byte-decidable fee-order and initcode classes of FI-13(2)(vii)–(viii) and (1)(b)(F)–(G); the
> walk's discharge ground gains the sender-with-code case (EIP-3607) and the mirrored no-room
> case, and the tail turn is pinned to a state of a real block of the range, so the duty and the
> walk read the same turn and the same remaining gas; the enumeration residual is Open with
> falsifier F-FI-8.)* *(review round 4 follow-up, S-02 edge: the immediately-before-the-last-block
> form of the tail turn let a producer place an earlier transaction of the record in the last
> block and have the later omitted transaction judged on the pre-state before that earlier
> transaction executed — a stale read that discharged it without filling any block, and under
> which the same-nonce shape made this duty's demand unsatisfiable for that batch; the tail turn
> is now the state the batch reaches after the record's last earlier appearing transaction, and
> this duty reads that state and the same remaining gas, the range's last block's final state
> included.)*

*(increment 04 consistency repair: the quotation previously stopped at the R4R4-NR-01 note and restated the clause's remaining sentences outside it, so "reads, in full" was false; it now reproduces the specification's CONS-01(v) from its heading to the clause's end, word for word.)*

*(This is the
single-unit restatement R6-D12-03 asked for: the obligation lives at the batch, the ordering lives at
the block, and no registered constant is used in two units.)* *(Review round 3,
R4R3-T-01/R4R3-NR-01: the duty is scoped to the transaction's turn so that it and the walk share one
predicate — the seam that made a nonce-descending record unprovable, a duty demanding a transaction the
walk had already discharged, is closed, and the "increasing transaction index" condition constrains
only the transactions the walk executes. Review round 4, findings S-01 and S-02 — RC-7: the duty's
predicate also carries the byte-decidable fee-order and initcode classes of FI-13(2)(vii)–(viii), the
discharge grounds of FI-13(1)(a) include the sender-with-code and no-room cases, and the tail turn is pinned to the state the batch reaches after the record's last earlier appearing transaction (S-02 follow-up, RC-8), so the duty and the walk read the same turn and the same remaining gas. Review round 4, R4R4-NR-01: the clause also carries the block-validity order requirement above — a block MUST NOT contain a record's transaction once a higher-index transaction of that record has appeared — the counterpart of FI-13(1)(a)'s index-order condition, so the condition is not proof-only.)*

**(5) What the guest may rely on.** Only: the anchored L1 view written into L2 state by the anchor step
it re-executes; the register's fields and identity as fixed by DA-07 and DA-10; the opening checks the
contract performed on-chain for the forced records, carried as the forced-opening list the journal's
`forcedBoundary` commits; and the batch's own committed payload (PRF-07). It MUST NOT rely on any
off-chain index, list or archive (DA-04), on any witness-supplied frontier, or on L1 state later than
`A` — the last point is what makes a normally produced batch never unprovable by a publication that
arrives later.

**(6) Why the age bound is enough, and what it bounds.** Every admitted view satisfies
`block.number − FI_ANCHOR_MAX_AGE ≤ A ≤ block.number − L1_FINALITY_DEPTH`. Hence a record published in
L1 block `b` is due at every view admissible for a landing at any height
`H ≥ b + FI_INCLUSION_DELAY + FI_ANCHOR_MAX_AGE`: such a view satisfies
`A ≥ H − FI_ANCHOR_MAX_AGE ≥ b + FI_INCLUSION_DELAY`. No producer's choice of anchor, and no choice of
batch range, can postpone the point at which a due record is required beyond that registered age —
the postponement is bounded by `FI_ANCHOR_MAX_AGE` blocks, never by a producer's clock. The invariant
`FI_ANCHOR_MAX_AGE ≥ L1_FINALITY_DEPTH` guarantees a view that is both final and admissible always
exists.

**(7) The anchor-age collision with L1-04 (R6-D12-02), and its resolution.** `block.number − A >
FI_ANCHOR_MAX_AGE` is a time condition in the admission rules, and L1-04 forbids a condition "that can
make a range permanently unacceptable". The collision is resolved without weakening the no-gate rule,
by two registered relations instead of a new gate: **(i)** `FI_ANCHOR_MAX_AGE` converted to seconds
MUST be at least `T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY_DEPTH` — the same term list
as DA-09(1)'s usability inequality — so **no batch produced and proven inside the registered envelope
can be rejected for staleness**; and **(ii)** `T_PROVE_DEADLINE + FI_ANCHOR_MAX_AGE` converted to L1
blocks MUST be at most the retrievability window of DA-05, so the age bound never outlives the data the
proof needs. The residual — a certified range whose landing is deliberately delayed past both bounds —
is disclosed as F-FI-6 and is **not** repaired here; the three candidate repairs and why none is
adopted are recorded in §9.2.

### FI-12 — the capped FIFO prefix, the batch's capacity, and why this cannot halt

**(1) The cap is in positions per batch, and it is enforced.** Let `batchGasCapacity` be the sum of the
gas limits of the batch's own headers, which the guest reads while verifying the header chain. Let

> `itemGasBound = FI_MAX_TX_PER_RECORD × FI_RECORD_GAS_MAX` — the per-record work bound, gas.

The obligation of FI-11 is over **positions per batch**, and the cap is

> `cap(batch) = min(FI_MAX_PER_BATCH, floor(batchGasCapacity / itemGasBound))`.

FI_MAX_PER_BATCH × itemGasBound`, **either** because every header it commits to states at least the
per-block bound `FI_MAX_PER_BATCH × itemGasBound` (FI-12(1)(i)) **or** because the batch contains a
block whose header gas limit is at least `FI_MAX_PER_BATCH × itemGasBound` (FI-12(1)(ii)). In both
cases `cap(batch) = FI_MAX_PER_BATCH`.
a non-empty outstanding obligation and `batchGasCapacity < FI_MAX_PER_BATCH × itemGasBound` is
**invalid**: the guest rejects it under FI-11(2)(3). *(This is the enforcement point R6-D12-04 found
missing. `cap = 0` is now unreachable: FI-11(2)(3) requires `R ≥ 1` whenever the outstanding
obligation is non-empty — with the capacity condition, `R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live
record is outstanding — RC-2.)*

**(2) The two counts.** With `c` and `d(A)` as in FI-10(5), let

> `R` = `min(d(A) − c, FI_MAX_PER_BATCH)` — the **resolved count**, the size of the required window,
> positions, zero when nothing is outstanding; and
> `W` = the number of positions in `[c, c + R)` whose record is **live** at `A` — the **work count**,
> positions, the only positions whose resolution can demand gas.

The batch MUST satisfy `batchGasCapacity ≥ W × itemGasBound`, and MUST resolve exactly `R` positions
(`c' = c + R`). Dead positions in the window are resolved by expiry without gas, which is why the gas
condition is stated against `W` and not against `R`.

*(Ratified correction — RC-1: `R` is the **window**, `min(d(A) − c, FI_MAX_PER_BATCH)`, not the live count. `d(A)` counts dead records and FI-11(3)(a) demands the advance unconditionally, so the earlier `R = min(W, cap)` made any window containing a dead record unsatisfiable. `W` is the live positions in `[c, c + R)` — the work and gas count — so dead positions cost no gas.)*

**(3) The two claims, in one unit.** (1) A batch that resolves the window
`[c, min(d(A), c + FI_MAX_PER_BATCH))` is compliant even when the backlog is arbitrarily large: the
obligation is the minimum of the outstanding count and the cap, never the due set, and the gas it can
demand is `W × itemGasBound`, whose registered ceiling is the batch's own capacity (the relation in
(4)). (2) No batch is ever required to resolve more than `FI_MAX_PER_BATCH` positions, to execute more
than `FI_MAX_PER_BATCH × FI_MAX_TX_PER_RECORD` forced transactions, or to read more than
`FI_MAX_PER_BATCH` register positions plus one binary search.

**(4) The registered relation.** The register MUST carry, as the capacity relation consumed by (1)–(3):

> `FI_MAX_PER_BATCH × FI_MAX_TX_PER_RECORD × FI_RECORD_GAS_MAX ≤ MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT`,
> together with `FI_RECORD_GAS_MAX ≤ L2_BLOCK_GAS_LIMIT` (a single transaction fits one block) and
> `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`.

*See §3 for why the relation, its per-block companion and the no-halt argument are all in this one
unit. The relation and its inputs stay tagged unmeasured, and the constructive-schedule premise stays
an Open assumption, exactly as the preserved text had it (F-FI-1).*

**(5) Why this cannot produce a permanent halt.** (i) The required work is bounded per batch by (3).
(ii) A compliant batch always exists **given the two premises this specification states rather than
maintains**: the registered relation (4) holds, and the L2 gas-limit schedule permits a batch of
`MAX_BATCH_BLOCKS` blocks whose headers each carry at least `L2_BLOCK_GAS_LIMIT` gas. Under both, such
assumption**, not an invariant any registered rule maintains: no rule registered here constrains the
L2 gas-limit schedule, and the capacity relation reads `L2_BLOCK_GAS_LIMIT` from the **anchored L1
view** the proof already fixes — the value is bound by that view, needs no config-preimage
commitment, and no preimage changes; PRF-02(5)'s live (version-3) field list is untouched, and the
historical `paramVersion = 2` enumeration remains valid only for an epoch already entered under it
and MUST NOT be used for a new epoch. F-FI-1
is its named falsifier and the FI capacity relation row of 09 records it as Open.

*(Ratified correction — RC-4: this clause claimed PARAM-04 commits `L2_BLOCK_GAS_LIMIT` through the
`paramVersion = 2` preimage of PRF-02(5). That is wrong and MUST NOT be implemented: V2 is historical,
valid only for epochs already entered under it, and the live preimage is V3, whose field list does not
contain the value. The relation reads it from the anchored view, so it is bound without any preimage
change.)*
is its named falsifier and the FI capacity relation row of 09 records it as Open. (iii) On acceptance
the frontier advances by at least `min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding, so
the frontier can never be held by a dead or void position and the queue always drains at a rate of at
least one position per accepted batch. (iv) The due set is finite at every L1 state — it is a set of
records in L1 storage — so no unbounded object is required for progress. The argument's remaining
premise is the existing pipeline assumption: batches must be produced and accepted at all (A-DA-2,
A-CONS-5, HALT-03).

**(6) The round-1 critical is not repeated.** Review round 1 found exact equality between the required
set and the whole due set, combined with a per-batch cap below it: a backlog then made every proposal
invalid and the halt permanent. Here the required set is `min(d(A) − c, cap)` positions, a batch that reaches
the cap is compliant, and everything above the cap stays outstanding for later batches. The content
route (round 1's class arriving through record content) remains closed by FI-13's per-record bounds: a
record above the bound is void in every block of every batch from its own immutable bytes, consumes no
gas, and the prefix advances past it.

**(7) Named falsifiers.** *F-FI-1*: a registration (or a fork that changes `L2_BLOCK_GAS_LIMIT`) that
breaks the relation of (4), **or** a gas-limit schedule under which a `MAX_BATCH_BLOCKS`-block batch
whose headers each carry at least `L2_BLOCK_GAS_LIMIT` gas cannot be produced, makes (ii) false and can
re-open a halt. *F-FI-2*: the bound on **time**, not on work — if the arrival rate of livable records
exceeds `FI_MAX_PER_BATCH` per accepted batch, the queue grows without bound and the wait of a given
record grows without bound; the mechanism still does not halt, but the deadline is then an exit, not a
latency guarantee. **F-FI-2 is not fixed by this increment** (§6.3).

### FI-13 — resolution: executed, void, or dead — the predicate and its grounds

**(1) The three resolution modes, walked per transaction in the record's own order — and their
precedence.** A position `j` is **resolved** by a batch iff exactly one of the following three modes
applies, and the modes are applied in the stated precedence so that **they partition the cases**:
**(c)** is tested first and unconditionally; otherwise the record is live at `A`, and the over-bound and
byte-invalid limbs of **(b)** are tested before **(a)**; and **(a)**'s walk and the discharge limb of
**(b)** are disjoint, because **(a)** requires at least one transaction to execute and that limb requires
none to execute.

- **(a) executed** — the record at `j` is live at `A`, not over-bound under FI-13(2)(i)–(ii) and
  containing no transaction that cannot be executed from the record's own bytes, and walking its
  transactions in the record's own order each one either **executes** (appears in the batch's executed payload, each exactly once, in
  increasing transaction index within the record, with the record's transactions recovered from its
  published byte string as FI-13(2) fixes) or is **discharged** — it does not appear, and at the pre-state
  **its turn** reaches in the batch's own execution it cannot execute: its
  declared nonce does not equal the sender's nonce at that pre-state (ahead of it, or already consumed);
  or the sender's balance at that pre-state is below `t.gasLimit × t.maxFeePerGas + t.value`; or the
  sender has code at that pre-state — no valid block may execute a transaction from a sender with code
  (EIP-3607); or, at that turn, **no block of the range at or after the turn had room to carry it** —
  the remaining gas, at that turn, of the block in which the turn lies was below the gas limit `t`
  declares, the same remaining gas the per-block duty of CONS-01(v)/FI-11(4) reads at the same turn, so
  a block that had room and omitted `t` is a breach and leaves the position unresolved — with at least
  one of them executing; a position all of whose transactions executed is **executed**, and the
  mixed case is **resolved** with the executed transactions recorded as executed and the discharged ones
  recorded as discharged. **The turn, pinned by position:** a transaction that appears in the executed
  payload has its turn at the pre-state immediately before its own position; a transaction that does not
  appear has its turn at the pre-state immediately before the record's next transaction in the record's
  own order that appears in the executed payload, and, when no later transaction of the record appears,
  at the state the batch reaches immediately after the record's last earlier transaction that appears in
  the range has executed — the pre-state of the next transaction the batch executes, or the initial
  pre-state of the next block of the range when it executes none after it, or, that transaction being the
  last transaction of the range's last block, the state that block's body ends in, at which that block's
  own remaining gas is read — so no earlier transaction of the record can execute after the turn and
  leave the transaction judged on a state from before that earlier transaction's effect; and, when no
  earlier transaction of the record appears either, at the pre-state immediately before the last block of
  the range's body — a state a real block of the range reaches in its own execution, never a state no
  block of the range reaches; when the record's last transaction appears, the first case applies and its
  turn is the pre-state immediately before its own position, as before. The turn is a function of the record's own
  order and the batch's own executed payload alone — never of a witness-supplied position, a block
  boundary, or a producer's claim about where "that point" is — so two guests computing the same batch
  reach the same pre-state for a transaction that never appears, and its forceability and its discharge
  are judged at exactly that pre-state. **The "increasing transaction index" condition governs only the
  transactions the walk executes**: it applies to the transactions that appear, each exactly once and
  with increasing indices along the payload order, while a discharged transaction does not appear at
  all, so it cannot violate the order and no block can be required to include one. *(Review round 3,
  R4R3-T-01/R4R3-NR-01 and R4R3-T-02: the turn of a transaction that never appears is pinned by
  position, so two conforming guests compute the same pre-state; and the index-order condition
  constrains only the transactions the walk executes, so the nonce-descending record
  `[t1 (index 0, nonce n+1), t2 (index 1, nonce n)]` resolves with `t1` discharged at its turn before
  `t2` executes and `t2` executed, never with both appearing, and no block is required to include
  `t1`.)*
- **(b) void** — the record at `j` is **live at `A`** and satisfies one of these three limbs (the
  limbs may hold together; all of them are mode (b), never separate modes): it is
  over-bound under FI-13(2)(i)–(ii) (this limb is tested **before (a)**, so a live over-bound record is
  void even if one of its transactions appears in the batch's executed payload, and its mode is fixed by
  its own immutable bytes, never by the producer's inclusion choice); it contains a transaction that
  cannot be executed from the record's own bytes, in one of these exhaustive classes, each decided by
  the record's published byte string, the registered constants and the chain id alone — and, for (E), the
  Open fee-schedule premise its register row records — so no batch can
  execute it at any pre-state: (A) the record's published byte string does not decode under PRF-07(0)
  as the frame sequence of its own stored claimed range (DA-07(1)) — a length prefix past the committed
  end, a frame count other than the claimed range's, or trailing bytes — so its transactions cannot be
  recovered at all (FI-13(2)(i)); (B) a transaction's chain id does not
  match FI-13(2)(iii); (C) a transaction's signature does not recover to a sender, so the transaction
  has no sender for FI-13(2)(iv)–(v); (D) a transaction's declared gas limit is below the intrinsic
  gas of its own data, a fixed function of that transaction's own bytes; (E) a transaction's declared
  `maxFeePerGas` is below the registered floor `FI_MIN_EXEC_FEE_CAP` — one registered constant compared
  against the transaction's own declared cap, under the Open fee-schedule premise its register row
  records (F-FI-7), so a transaction that declares less is executable by no valid block; (F) a
  transaction's declared `maxPriorityFeePerGas` exceeds its declared `maxFeePerGas` — a malformed fee
  market, a property of the transaction's own bytes, so no valid block can carry it (EIP-1559); or (G)
  a create transaction whose declared initcode exceeds the EIP-3860 initcode size cap — its own bytes,
  and (D)'s intrinsic-gas floor prices initcode per word without capping it, so no valid block can
  carry it; a transaction that fails only
  FI-13(2)(iv)–(v) is not in this limb: whether it executes is decided at its turn by the discharge
  ground of (a), not by the record's own bytes; or every one of its transactions is
  discharged (a record with no transactions at all is void under this limb: there is nothing to
  execute), so none of them executes; or
- **(c) dead** — the record at `j` is **dead at `A`** (FI-10(2), FI-10(7)): this test is **first and
  unconditional**, so a record that is dead at `A` is dead whatever its size, its contents or its
  discharge state, and (a) and every limb of (b) never apply to it.

No other ground resolves a record, at any layer: not a proposer's claim, not a validator's vote, not a
DAO or operator action, not a recovery, not the record's own age while it is still live, and not a
pruned slot. A transaction that can execute at its turn and does not appear in the executed payload is
neither executed nor discharged: the position is then unresolved, and FI-11(3)(c) makes the proof
invalid — that is the obligation of FI-11. *(R4R1-M-01: the ground is per transaction, in the record's
own order; the record-level forms "all of its transactions" and "none of whose transactions is
forceable" are superseded and MUST NOT be restored. A transaction that can never be executed from the
record's own bytes — any one of the exhaustive classes (1)(b) enumerates, of which the chain id is one
— is a record-level void ground, not a discharge at a turn, so the walk stays total over both halves of
FI-13(2). F1: the classes are the exhaustive list (1)(b) states, so a reader who takes the chain id for
the whole set leaves the other classes unresolved.)* *(Dead-first and
void-limb-first precedence: the three modes partition every record at every anchored view — a dead record
is (c) alone, whatever its size, contents or discharge state (the reviewer's edge case); a live
over-bound record is (b) alone, never also (a); a record with no transactions is (b); and a position in
no mode is unresolved only because a transaction that can execute at its turn was omitted, which
FI-11(3)(c) makes invalid.)* *(Review round 3, finding F1: the byte-invalid limb's decision classes are
enumerated in (1)(b) — decode failure, chain-id mismatch, an unrecoverable signature, a declared
gas limit below the intrinsic gas of the transaction's own data, a declared `maxFeePerGas` below
`FI_MIN_EXEC_FEE_CAP` (review round 4, finding F1 — RC-6), a declared `maxPriorityFeePerGas` above the
transaction's own `maxFeePerGas` and a create transaction whose declared initcode exceeds the EIP-3860
cap (review round 4, finding S-01 — RC-7) — and PRF-04(vi) names the same
exhaustive list, so the rule and a guest implementation agree on the whole set; each class is decided
by the record's own bytes, the registered constants and the chain id, never by L1 state, a producer
input or an oracle.)*

**(2) The predicate — record bytes, registered constants, pre-state, and nothing else.**

> A transaction `t` of a record is **forceable** at a pre-state iff all of: (i) the record's published
> byte string is at most `FI_ITEM_MAX_BYTES` bytes and decodes under PRF-07(0) as the frame sequence of
> the record's own stored claimed range (DA-07(1)) to frames whose block bodies carry at most
> `FI_MAX_TX_PER_RECORD` transactions in total — those are the record's transactions, recovered in
> frame order; (ii) `t`'s gas limit is at most `FI_RECORD_GAS_MAX` and **at
> least the intrinsic gas of `t`'s own data** — a fixed function of the transaction's own bytes, so a
> transaction that declares less is executable by no valid block — and the record's transactions' gas
> limits sum to at most `FI_MAX_TX_PER_RECORD × FI_RECORD_GAS_MAX`; (iii) the chain id matches; (iv)
> `t`'s **signature recovers to a sender** — a transaction whose signature does not recover has no
> sender, so no valid block can execute it — and `t`'s nonce equals that sender's nonce at that
> pre-state; (v) the
> sender's balance at that pre-state is at least
> `t.gasLimit × t.maxFeePerGas + t.value` — **`t`'s own declared maximum charge**; and (vi) `t`'s
> declared `maxFeePerGas` is at least the registered floor `FI_MIN_EXEC_FEE_CAP` — one registered
> constant compared against the transaction's own declared cap, under the Open fee-schedule premise its
> register row records (F-FI-7), so a transaction that declares less is executable by no valid block;
> (vii) `t`'s declared `maxPriorityFeePerGas` is at most its declared `maxFeePerGas` — a malformed fee
> market is a property of the transaction's own bytes, and no valid block can carry it (EIP-1559); and
> (viii) `t` is not a create transaction whose declared initcode exceeds the EIP-3860 initcode size
> cap — the cap is decided by the transaction's own bytes, and (ii)'s intrinsic-gas floor prices
> initcode per word without capping it.

**So the predicate calls no unexecutable transaction forceable:** a transaction that fails (ii)'s
intrinsic-gas floor, (vi)'s fee-cap floor, (vii)'s fee-order test, (viii)'s initcode cap or (iv)'s signature recovery is not forceable at any pre-state, exactly as one that
fails (iii)'s chain-id test, and those are the same byte-decidable classes that void the record under
(1)(b) — no transaction exists that FI-13(2) calls forceable and that no valid block can carry **for a
reason this predicate or the enumerated classes (A)–(G) cover**, and none at all within that
enumeration under the Open fee-schedule premise its register row records with `FI_MIN_EXEC_FEE_CAP` (the floor is at or above the maximum
execution base fee the L2 fee schedule can produce; F-FI-7). **The residual is stated, not denied:** a
predicate over the record's bytes and the turn pre-state cannot rule out a reason that depends on
neither — the enumerated instance is F-FI-7's fee-schedule premise, and any execution-validity rule
outside the classes (A)–(G) and the turn pre-state this rule fixes is carried as an **Open** with
falsifier **F-FI-8**: a transaction that (2) calls forceable and (1)(a) does not discharge at its turn,
yet no valid block of the range can carry it.
*(04-coordination.md §5, closing the seam the round-3 F1 enumeration left: the predicate carries the
intrinsic-gas floor of (1)(b)(D), the fee-cap floor of (1)(b)(E) and the signature-recovery requirement
of (1)(b)(C) itself, so the per-block duty inherits the corrected predicate and the two agree by
construction. Review round 4, finding F1 — RC-6: the round-3 repair left the fee cap out of both the
predicate and the void classes, so a zero- or low-cap transaction was called forceable and demanded
while no valid block can carry it; the registered floor closes the seam from the record's own bytes,
and reading the block's actual base fee instead would reopen R6-D12-05's producer steering.)*

The predicate has **no other input**. In particular the including block's **base fee**, its **gas
limit** and its **remaining gas** are **not** inputs to forceability, voidness or dueness, and a
producer's own transactions are never part of the record. The registered fee floor of (vi) is **not** the including block's base fee: it is one registered constant compared against the transaction's own declared cap, so the exclusion of the block's fee environment stands — registered, unmeasured and fixed, never read from the block (review round 4, finding F1 — RC-6). The **record's own ordering** enters the
walk only through the sender's own signed order: the record's transactions are recovered from its
published byte string and walked in that order, so a producer cannot insert, reorder or drop one of
them from the walk. The **pre-state** each turn is judged against is a different thing: it is the
batch's own executed state, whose content the producer does choose, so a third-party credit it places
**before** a turn can make a transaction that is unaffordable there without it executable at that turn
(it is forceable there and must execute), while one placed **after** the turn cannot rescue it and it
is discharged as unaffordable at its turn; a competing transaction of the sender that the batch carries
can likewise consume the nonce or spend the balance before the turn. That credit-ordering edge is the
disclosed residual **F-FI-3** — the producer's ordering does decide that discharge — and the delta does
not claim otherwise. Whether a record is void is a function of the record's own published byte string
— fixed at publication and immutable (DA-07(3)) — of registered constants, and of the L2-state facts
read at the transaction's turn (1)(a) pins: the sender's **nonce**, which only that account's own
signed transactions can move, and the sender's **balance**, which **anyone can move** — a third-party
credit can only make a transaction executable, never discharged, and the producer's ordering decides
only whether such a credit precedes the turn (the transaction is forceable there and must execute) or
follows it (the transaction is discharged as unaffordable at its turn, the residual F-FI-3) — together
with the record's own liveness at `A`, which its stored block number and one registered constant decide
(FI-10(2)). Apart from the sender's own further signed transactions and the arrival time of third-party
credits, which the producer's own ordering places relative to a turn (the residual **F-FI-3**), and
the anchored view's relation to that stored number, no batch-to-batch movement in the walk's verdict
comes from anything **else** the producer sets. *(Liveness: voidness is a function of the record's
own bytes, registered constants, the sender's own state and the record's own clock — the live-only
limbs of (1)(b) add no producer-set input. R4R3-T-02: "two facts the producer cannot move" was false
for the balance — anyone can credit it, and the producer's ordering of that credit decides whether it
precedes or follows the turn; only the nonce is producer-immovable, and an incoming credit can only
make a transaction executable, never discharged.)* *(correction, R4R3-T-02: the record's own ordering is producer-proof, but the turn pre-state is the batch's own executed state — a credit placed before a turn can rescue an otherwise-unaffordable transaction and one placed after cannot, so the producer's ordering does decide that discharge, the disclosed residual F-FI-3.)*

**(3) The discharge ground cannot be manufactured — and the producer-set inputs that steer it are disclosed.**
No producer, prover, validator or submitter can manufacture a discharge ground by choosing block
contents: it cannot move a nonce, reduce a balance, alter the record's own bytes, or change the order
in which the record's transactions are walked; the terms it could previously move (base fee, block
gas limit) are gone from (2); the terms the walk reads are the record's own bytes, the registered
constants, and the sender's nonce, balance and code at the transaction's turn, pinned by position as
(1)(a) fixes — the code, like the nonce, is the account's own state, and no producer can put code at
another account's address by block contents — while the room the mirrored discharge ground reads is the
block's own remaining gas at that turn, the same quantity the per-block duty reads, so that ground
cannot be manufactured for a transaction a block with room could carry. What it does choose is the batch's own
executed state, and so the **pre-state** each turn is judged against: a third-party credit placed before
a turn can rescue a transaction that is unaffordable there without it (which must then execute), one
placed after the turn cannot, and a competing transaction of the sender that the batch carries can
consume the nonce or spend the balance before the turn — the disclosed residual **F-FI-3**. *(correction,
R4R3-T-02: the original sentence said no producer can make a due record void by choosing block contents;
that is false in the credit-ordering case — a record whose only transaction a credit placed before its
turn would rescue is discharged, and so void, when the credit is placed after the turn — while the
shortfall itself is not producer-manufactured.)* Execution follows the record's own
order. Of the facts the walk reads, only the **nonce** is producer-immovable — only that account's
own signed transactions can move it — while the **balance** can be moved by anyone: an incoming credit
can only make a transaction **executable**, never discharged, and what a producer's ordering decides is
only whether a credit lands before the turn (the transaction is forceable there and must execute) or
after it (the transaction is discharged as unaffordable at its turn). So a producer cannot manufacture
the nonce half of a discharge ground for someone else's transaction: if the sender has signed no other
transaction that supersedes or defunds it, a transaction that can execute at its turn must be executed,
never discharged, and a producer that omits it makes the proof invalid. Nor can the ground be steered
in the other direction: a transaction that genuinely cannot execute at its turn (its nonce ahead and
unreachable, or its balance short of its own declared maximum charge) is discharged in every batch, at
every view, in every producer's hands. *(R4R1-M-01: the per-transaction ground keeps R6-D12-05's
removal of the environment half and makes the walk total; the residual for a transaction discharged by
the sender's own further signed transaction, or unaffordable at its turn — including where a
third-party credit arrived only after the turn — is F-FI-3. R4R3-T-02: "the only things that can move
an account's nonce or balance are that account's own signed transactions" was false for credits; the
nonce is the producer-immovable half, the balance is movable by anyone, and a credit's position
relative to the turn is the disclosed residual, not a new ground.)*

**(4) What a record that genuinely cannot execute does.** A **live** record above any registered bound,
or a live one containing a transaction that cannot be executed from the record's own bytes at any
pre-state (any one of the exhaustive classes (1)(b) enumerates), is **void** — a record that is
dead at `A` is resolved by (c) whatever its bounds or contents, and is discharged even more cheaply
below — and so is a live record every one of whose transactions is discharged at its turn, so that none
of them executes: in both cases the frontier advances past the position, the proof requires **no
execution and no re-supply of its bytes**, and the published bytes remain on L1. A record with some
transactions executed and some discharged is resolved as (a): the executed ones are recorded as
executed, the discharged ones as discharged, and the sender may re-publish any discharged transaction. A dead record (mode (c)) is
discharged the same way and even more cheaply: only its stored `l1BlockNumber` is read. In every case
the remedy is **re-publication** under DA-09(2), which creates a new record with a new sequence and a
fresh clock; the user's own permissionless re-publication is the exit, and nothing about any path
touches any height, checkpoint or batch. *(R4R1-M-01: a record whose remaining transactions cannot
execute is fully discharged by that discharge, not left unresolved.)* *(Dead-first precedence: the
record-level limbs of (1)(b) are live-only, so this clause's "a record above any registered bound is
void" is corrected here to agree with (1)(b). F1: this clause's byte-invalid classes are the exhaustive
ones (1)(b) enumerates, not the chain-id example.)*

**(5) The walk is total; the discharge is bounded.** **Totality is a rule property:** for every live
position `j`, either a limb of (1)(b) resolves it as void from its own bytes, or the walk of (1)
executes or discharges each of the record's transactions, so every
position resolves in the batch that reaches it — in a bounded number of batches, because the frontier
advances at least one position per accepted batch and a record's transactions are finite — and **no
published record can pin the frontier or halt settlement**: a record whose remaining transactions cannot
execute is fully discharged by that discharge, not left unresolved, and a batch exists that resolves it.
The three modes of (1) are mutually exclusive under their stated precedence — a dead record is (c) even
when it is also over-bound or byte-invalid, and a live over-bound or byte-invalid record is (b), never
also (a) — and a batch that does the work of FI-11(4) puts every position it reaches in exactly one of
them.
The property holds because execution follows the record's own order and the turn is pinned by position
(3): only that account's own signed transactions can move its nonce, and an incoming credit can only
make a transaction executable, never discharged, so a producer cannot manufacture a discharge ground
for a transaction the sender's own state makes executable at its turn, and it cannot make such a
transaction unexecutable by its own choices. The one producer-set ordering that can decide a discharge
is where a third-party credit lands relative to the turn of a transaction that is unaffordable there
without it — the residual F-FI-3, disclosed — and it cannot leave a position unresolved that the
record's own bytes and the sender's own state do not already discharge. Void is
proven, not judged: the guest checks (1)–(2) over the record's bytes and the batch's own execution,
which is `O(FI_MAX_PER_BATCH × FI_MAX_TX_PER_RECORD × MAX_BATCH_BLOCKS)` bounded work, and dead is
checked by one comparison per position. A record that is neither executed, void nor dead **cannot be
passed**: FI-11(3)(c) makes the proof invalid. *(The preserved rule's sentence "A voided record is
settled: the frontier advances past it" is kept; its ground list gains (c), the exact fix R6-D12-01
asked for, and R4R1-M-01 adds the totality property so no live record can pin the frontier.)*
*(Dead-first and void-limb-first precedence: the modes partition, so totality holds without any record
qualifying for two modes or for none.)*

### FI-14 — no discretion, monotonicity, and the recovery-free survival clause

**(1) No discretion.** The protocol MUST NOT contain any rule, entry point, upgrade initialiser, veto
or governance action by which an owner, the DAO, an operator, a validator, a proposer, a relayer, a
prover or any other party can suppress, reorder, delay, extend, shorten or remove a forced-data record
or its due point. In particular there MUST NOT exist a function that clears the register, rewrites a
record's `l1BlockNumber` or identity, lowers the settlement frontier, **skips a prefix element except
by executed, void or dead under FI-13(1)**, extends a record's due point or deadline, or makes the
resolution of a required record conditional on any account's approval. The rule is stated in the same
form as L1-04's prohibitions: the construct must not exist, not merely remain unused. An upgrade may
change the mechanism's parameters only through the registered configuration of PARAM-04, and MUST NOT
weaken the obligation for a record that is already outstanding.

**(2) Monotone L1 state, no recovery interaction.** v1 has **no recovery path of any kind** (D-15
withdrawn, D-16): there is no permissionless recovery, no governance stall resolution, no generation
increment and no checkpoint restore that this or any other rule executes. The register and the
settlement frontier are therefore **monotone L1 state**: the frontier never decreases (FI-11(3)(d)),
no path may lower it, and no path may re-clock a record. The preserved FI-14's second half — its four
"across an executed stall resolution" clauses, which read REC-02/REC-04 and a restored checkpoint —
is **deleted, not carried**: they name a mechanism that no longer exists, and leaving them would keep a
dormant read of a deferred name in a live rule. The obligation survives an **L1 reorganisation**
exactly as any other L1 fact does (L1-12): the register, the settlement records and the frontier are
carried with the reorged L1 state, so a record written by a reorged publication has no position and no
due point, and a settlement record written by a reorged `land` is undone with its checkpoint.

**(3) The record cannot outlive its usefulness.** The register MUST NOT prune or hide a record before
its position is settled by the frontier (§4.2); the retention floor `PUB_RECORD_RETENTION ≥
T_PROVE_DEADLINE` (DA-09(1)) keeps a referenceable record readable, and a record that is dead is
resolvable by one stored number, so expiry never needs bytes the protocol has stopped storing.

---

## 3. The unit of account, the frontier, and the no-halt argument — one derivation

### 3.1 The unit is the register position, at the batch

Everything the mechanism does is counted in **positions of one register per batch**:

| Object | Unit | Boundary |
|---|---|---|
| the obligation | positions per **batch** | `R = min(d(A) − c, FI_MAX_PER_BATCH)` (`FI-12`(2)) — the window; `W`, the live positions in `[c, c + R)`, is the work and gas count |
| the cap | positions per **batch** | `FI_MAX_PER_BATCH` |
| the frontier advance | positions per **batch** | `c' = c + R`, `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` |
| the work bound per position | gas | `itemGasBound = FI_MAX_TX_PER_RECORD × FI_RECORD_GAS_MAX` |
| the capacity relation | gas per **batch** | `FI_MAX_PER_BATCH × itemGasBound ≤ MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT` |
| the drain rate | positions per **batch** | `≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding |
| the per-block duty | order and non-omission | **no count, no gas quota** |

`FI_MAX_PER_BATCH` is used in exactly one unit — positions per batch — in all four places it appears
(the obligation, the cap, the capacity relation, the frontier bound). No rule of this increment uses it
per block.

### 3.2 The restated per-block obligation, and how the two checks agree

The preserved `CONS-01(v)` demanded "the FIFO prefix of P **up to `FI_MAX_PER_BATCH` records**" in
**one block**, which is where the unit mismatch lived: with `FI_MAX_PER_BATCH × itemGasBound >
L2_BLOCK_GAS_LIMIT` — permitted by the old batch-level relation — no block can carry the prefix, and
validators applying the clause literally must vote NIL for ever. The revived clause demands only:

1. **order** — a block never executes a forced transaction of a later required record while an earlier
   required record still has an unexecuted, forceable forced transaction (FI-11(4)); and
2. **non-omission** — if the block's remaining gas is at least the gas limit the forced transaction
   itself declares, the block must contain it.

The walk mirrors that escape exactly: a transaction that does not appear is **discharged** at its turn only if no block of the range at or after the turn had room for it — the same remaining gas the duty reads, at the same turn — and the tail turn is the state the batch reaches after the record's last earlier appearing transaction, a state of a real block where this duty can fire *(review round 4, finding S-02 — RC-7; S-02 follow-up, RC-8)*.

Neither requirement is a count or a quota, and both are decidable from the block's own body and its
pre-state. The proof-side check (FI-11(2)(4)) is what makes the duty bite: a batch whose execution
omits a forced transaction of a live, non-dead record must have the transaction **discharged at its
turn** under FI-13(1)(a) — the nonce, the balance, the sender's code, or a turn no block at or after it
had room for — so a producer that omitted a transaction executable at its turn cannot obtain a valid
proof. **The two checks agree by construction**: both read
the same three resolution modes from the same anchored register state, one per block and one per batch.

### 3.3 Why the obligation cannot halt (the counting argument, in one unit)

1. **Work is bounded.** By FI-12(3)(2), at most `FI_MAX_PER_BATCH` positions, `FI_MAX_PER_BATCH ×
   FI_MAX_TX_PER_RECORD` forced transactions.
2. **A compliant batch exists** whenever the registered relation holds and the schedule premise is
   real (FI-12(5)(ii)): a `MAX_BATCH_BLOCKS`-block batch at `L2_BLOCK_GAS_LIMIT` per header has
   `batchGasCapacity ≥ FI_MAX_PER_BATCH × itemGasBound`, satisfies the capacity condition, and its
   execution can resolve the whole window (bounding the gas a live position may demand by
   `itemGasBound` — the sum of its transactions' declared gas limits, each `≤ FI_RECORD_GAS_MAX` — and
   counting void and dead positions at zero).
3. **The frontier always advances** when a live record is outstanding: `R ≥ min(W, FI_MIN_DRAIN) ≥ 1`,
   and positions that are dead or void cost no gas, so they cannot pin the frontier. A record at
   outstanding position `j` is reached after at most `ceil((j+1)/FI_MIN_DRAIN)` accepted batches whose
   anchored view has passed its due point.
4. **The due set is finite** at every L1 state — records in L1 storage — so no unbounded object is
   required for progress.
5. **The remaining premise is the pipeline assumption** the design already states: batches must be
   produced and accepted at all (A-DA-2, A-CONS-5, HALT-03).
6. **The resolution walk is total** (FI-13(5), RC-5): either the record's own bytes void it first —
   over-bound, or carrying a transaction that can never be executed — or each of its transactions either
   executes or is discharged at its turn, so a live position — including one carrying an executable
   transaction and one whose nonce is unreachable — is resolved by the first batch that reaches it, and
   no publication can pin the frontier. This is the property R4R1-M-01 found missing from the
   record-level ground. *(Dead-first and void-limb-first precedence: the modes partition, so no record
   needs two of them or falls outside all three — RC-5 addendum.)*

The round-1 critical (required set = the whole due set, with a cap below it) cannot return: the
required set is a **prefix of the outstanding set capped by a constant**, and a batch that reaches the
cap is compliant.

### 3.4 The two failure modes the frontier rule is built to exclude

- **Frontier regression** — `c' < c` — is impossible: FI-11(3)(d), plus the L1-side
  `ForcedFrontierRegression` check against the predecessor's own `settledCount`.
- **Frontier skipping** — advancing past a position that is neither executed, void nor dead — is
  impossible: FI-11(3)(c) walks `[c, c')` and rejects any position that is not resolved, and
  FI-11(2)(5) rejects any position with no record at `A`. A producer cannot shrink the window by
  choosing an anchor (the greatest-anchored-view rule), by choosing a short batch (the capacity
  condition and `FI_MIN_DRAIN`), or by producing a batch that omits the work (the discharge ground is per
  transaction and reads only the record's own bytes, the registered constants and the sender's state at
  the pinned turn — only the nonce is producer-immovable, and a credit can only make a transaction
  executable, never discharged — and the walk is total, so a record the sender has not itself superseded
  must be executed and no position can be left unresolved — RC-5; R4R3-T-02).

---

## 4. Recovery survival, and the pruning made consistent with expiry

### 4.1 The recovery-free v1

D-15 withdrew the permissionless recovery; D-16 withdrew the governance stall resolution as well, so v1
has **no history-replacing path** — the last L1-accepted checkpoint is the boundary and nothing above
it is recoverable by rule. The obligation therefore needs no interaction with a recovery: there is no
generation increment an L1 action performs, no restored checkpoint record, and no discarded branch
whose settlement records could be reinstated. The consequences for the FI family are stated as rules:

1. the register and the settlement frontier are **monotone L1 state**; no rule, upgrade initialiser or
   governance action may lower the frontier or re-clock a record (FI-14(1)–(2));
2. forced data published but not proven **stays due** — it was never settled — and every batch is
   judged against the predecessor's own settlement record (FI-10(5));
3. a record whose resolution lived only in a batch that never landed was **not** settled, so the
   obligation survives; an **L1 reorganisation** undoes the record and the settlement record together
   with the checkpoint (L1-12), and there is no other path by which a settled record re-opens;
4. no stall-resolution queue entry, execution, timelock or generation change exists to create,
   discard, reorder or re-clock a record — the clauses that named them in the preserved text are
   deleted (FI-14(2)).

### 4.2 The pruning, made consistent with expiry

The preserved `pruneExpiredPublications(uint32) returns (uint64 settledFrontier_)` was the interface
half of R6-D12-01: it returned a frontier no accepted proof advanced, and implementing it either moved
enforcement off the proof (horn A) or made a dead record unexecutable and unvoidable while
`FI-11(5)` refused a position with no record (horn B). The revived interface is:

> `prunePublications(uint32 _maxRecords) external;` — **deletion only**. The call MUST NOT return a
> frontier, MUST NOT write a settlement record, MUST NOT change `nextSeq`, and MUST NOT be a
> precondition, an effect or a substitute for any check of `land(...)`. It may delete only positions
> `j` with `j < pruneCursor`, where `pruneCursor` is stored in the register and MUST satisfy
> `pruneCursor ≤ settledCount` of the **latest accepted checkpoint's** settlement record; it advances
> `pruneCursor` by at most the number of positions it deletes, and it MUST delete at most
> `_maxRecords` entries.

Why this makes a pruned position harmless: the settlement frontier never decreases (FI-11(3)(d)) and
`pruneCursor ≤ settledCount`, so a position the proof may still need to walk is never deleted. A
pruned position is *already settled*: it was executed or void in the batch that carried the frontier
past it, or it was dead and discharged by expiry. The proof therefore never needs to read a pruned
position, and a pruned slot is not "a position with no record at A" in the sense of FI-11(2)(5) —
that clause is about holes in the live register, and the prune is constrained to be strictly behind
the frontier the proof starts from.

The storage consequence is bounded and explicit: the register keeps at least `PUB_RECORD_RETENTION`
blocks of entries (DA-09(1)), and the retention floor keeps every record resolvable by the proof while
it is live or unresolved. A record that is dead needs only its stored `l1BlockNumber`, so expiry is
decidable even when the record's blobs have left retrievability and even after the bytes stop being
served by any archive — the obligation's discharge does not depend on the data's availability, only
its own clock.

---

## 5. The exit: an obligation must never block a withdrawal root

**The rule.** No forced-inclusion obligation, frontier condition, resolution mode, capacity condition or
prune may attach to: a withdrawal root's formation, `attestWithdrawalRoot`, the k-family verification
of L1-13, the withdrawal veto of MSG-04, or a user's eligibility to withdraw (MEM-15, MSG-03). The
withdrawal path MUST NOT read the forced-data register, the settlement frontier, `forcedBoundary`, or
any FI record, and MUST NOT be gated, delayed, accelerated or conditioned by any of them. This is
structural, not a promise: the register is a settlement-side queue of *publication* records, the
withdrawal path reads stored signals and stored checkpoints (MEM-15(1)), and this increment adds **no
entry point** to the acceptance surface other than the settlement record, the view, the prune and the
event (§7.1).

**The two directions of the interaction, stated so the review can attack them.**

1. *Can the obligation block an exit?* No. A due record freezes only the **settlement frontier**
   (§3.4) — which is where the batch pipeline is judged — and it can always be discharged by inclusion,
   by void or by expiry, so the freeze is bounded by `T_PROVE_DEADLINE` at the outside; the withdrawal
   root, its attestations and the veto never read that frontier. If no batch lands at all, the exit is
   still available from the last settled state, which is precisely the exit's purpose (D-15's fallback:
   "users are protected by the existing exit guarantee, not by a recovery mechanism").
2. *Can an exit block the obligation?* No. A withdrawal is an L2 transaction; if it is published, its
   record is forceable exactly like any other. The rule fixes no obligation on the exit and no rule
   reads one. A user who wants the obligation to carry a withdrawal-starting transaction publishes its
   data (DA-07) — that is the disclosed route of §6.4.

---

## 6. Falsifiers, honest costs, and what this increment does not fix

### 6.1 Falsifiers

| ID | Statement | Status | What would close it |
|---|---|---|---|
| **F-FI-1** | A registration or fork that breaks `FI_MAX_PER_BATCH × FI_MAX_TX_PER_RECORD × FI_RECORD_GAS_MAX ≤ MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT`, **or** an L2 gas-limit schedule under which a `MAX_BATCH_BLOCKS`-block batch whose headers each carry at least `L2_BLOCK_GAS_LIMIT` gas cannot be produced, makes FI-12(5)(ii) false and can re-open a halt. | Open (carried) | A registered rule that constrains the L2 gas-limit schedule constructively (not merely committing the value), or a consensus-enforced per-block floor on header gas limits. Neither exists; the relation is a value constraint, and the schedule premise is an assumption this specification states rather than maintains. |
| **F-FI-2** | The bound on **time**, not on work: if the arrival rate of livable records permanently exceeds `FI_MAX_PER_BATCH` per accepted batch, the queue grows without bound and the wait of a given record grows without bound. The mechanism does not halt, but the deadline is then an exit, not a latency guarantee. | **Open — NOT fixed by this increment** | A bounded arrival rate or a bounded live-register depth. §9.1 specifies the candidate (a per-publisher live-record bound) and recommends it to the review round; it is not adopted here because it is a publication-time admission condition not in D-12's scope, and because "the user publishes first" is a partial counter (§6.3). |
| **F-FI-3** | A transaction discharged at its turn may become executable later through the sender's own further signed transactions — the sender tops up, or a later nonce reaches it; the sender's own competing transaction can consume the nonce first — or through a credit from any account, ordered by anyone: only the nonce is producer-immovable, while the balance can be moved by anyone, the producer included, and the credit's position relative to the turn decides the outcome — a credit landing before the turn makes a transaction that is unaffordable there without it forceable and it must execute, while a credit landing after the turn cannot rescue it and it is discharged as unaffordable at its turn; a credit can only ever enable a transaction, never discharge one. Remedy for a record whose transactions were discharged is re-publication; the discharge itself is objective and irreversible for that record. *(R4R3-T-02: the sender-only form was incomplete — a third-party credit is a second route, the discharge is judged at the turn FI-13(1)(a) pins by position, and the credit-ordering edge is the disclosed residual F-FI-3, not a new ground and not a producer-manufactured discharge for someone else's transaction.)* | Open (carried, sharpened) | Nothing in-protocol; this is the disclosed price of an objective discharge ground. A predicate that could "un-discharge" a position would need a mutable status, which R5T-PDE-10 and FI-10(2) forbid, and a producer could never be given the power to revive an obligation the sender's own state discharged. |
| **F-FI-4** | **New.** A record whose deadline passes before the frontier reaches it is discharged by expiry, not included: a settlement stall longer than `T_PROVE_DEADLINE`, or a queue that drains slower than records age, means a user can pay one L1 publication per deadline window and still never be included while the chain runs. Expiry is a *discharge*, not a guarantee. | Open (new) | A longer `T_PROVE_DEADLINE` (bounded above by blob retrievability, DA-05) or a faster pipeline; both are Phase B measurements, not rule changes. This is the honest consequence of blocker 4: the expiry ground that makes a dead record deterministically dischargeable is the same ground that lets a stale record be discharged without inclusion. |
| **F-FI-5** | **New.** The guarantee is conditional on a non-censoring L1 and on at least one honest or rational batch producer: a censor that can front-run a user's publication with its own records, or that is the only producer, reduces the obligation to "the frontier may not advance". This increment bounds exclusion against a *producer* that must land batches, not against an L1-level adversary (`A-L1-1`). | Open (new) | Nothing in-protocol; this is the disclosed boundary of the narrowed R10 form (Fi-REMOVED-01(b)) and the same assumption LIVE-04 already owns. |
| **F-FI-6** | **New.** A certified range whose landing is delayed past `FI_ANCHOR_MAX_AGE` (and past blob retrievability) is permanently unacceptable outside the sanctioned stall resolution. Bound (i) of FI-11(7) makes this impossible inside the registered envelope; the residual is deliberate delay past both registered bounds. | Open (new) | The three candidate repairs in §9.2; the recommended one is the registered relation of FI-11(7)(i), which is what this delta writes. A consensus anchor-freshness duty would close it more strongly and is left to the review round. |
| **F-FI-7** | **New (review round 4, finding F1; RC-6).** The registered fee floor's schedule premise: `FI_MIN_EXEC_FEE_CAP` is at or above the maximum execution base fee the L2 fee schedule can produce in any window, and no registered rule maintains that. A schedule that can exceed the floor makes a transaction the predicate calls forceable — and the per-block duty demands — one no valid block can carry: the record is live, none of the byte classes' complement applies, every proof in `[c, c + R)` is rejected, and settlement freezes until the record dies, one permissionless publication per `T_PROVE_DEADLINE`. | Open (new premise) | A registered rule that constrains the L2 fee schedule (not merely reading its value), or a schedule bound demonstrated at or below the floor. The floor itself closes only the classes the predicate can decide from the record's bytes; as with the capacity relation's gas-schedule premise (F-FI-1), this one is stated rather than maintained. |
| **F-FI-8** | **New (review round 4, finding S-01; RC-7).** The **enumeration residual**: a transaction that FI-13(2) calls forceable at its turn and that no discharge ground of FI-13(1)(a) covers, yet that no valid block of the range can carry for a reason outside the classes (A)–(G) and outside the turn pre-state this rule fixes. The class list is the exhaustive set this specification enumerates; an execution-validity rule it does not enumerate is a counterexample to any claim stronger than the enumeration. | Open (new) | A further byte-decidable class, a pre-state-decidable discharge ground, or an argument that no such rule exists for the L2's Ethereum-equivalent execution; the rule states the boundary instead of re-asserting a universal claim. |

### 6.2 Costs and honest accounting

1. **One L1 publication per record per attempt**, paid by whoever publishes; a forced transaction pays
   its own L2 gas if executed (FI-10(8)). No protocol fee, no escrow, no bond, no refund.
2. **Bounded proof work**: at most `FI_MAX_PER_BATCH` positions, `FI_MAX_PER_BATCH ×
   FI_MAX_TX_PER_RECORD` forced transactions, and one bounded binary search per batch; no unbounded
   structure and no witness-supplied list is accepted.
3. **One extra commitment in the journal**: `forcedBoundary` (L1-05 row 36), one `bytes32` field
   carrying the boundary, not individual frontier values.
4. **A publication can cost its publisher and no one else**: a record with wrong claims can never be
   accepted (DA-07(4)), and a void or expired record costs no batch any gas.

### 6.3 The arrival-exceeds-drain case, stated exactly

The FIFO queue is filled by permissionless publications, so **arrival is unbounded** while the drain is
`min(W, FI_MIN_DRAIN)`…`FI_MAX_PER_BATCH` positions per accepted batch (at least one whenever a live
record is outstanding — RC-2). Three consequences, all honest:

1. **A record can be forced to age out.** A publisher that puts `q` records ahead of a target delays
   the target by at least `ceil(q / FI_MAX_PER_BATCH)` accepted batches; if that exceeds the deadline
   window, the target is discharged by expiry and the user must re-publish. This is F-FI-4 and F-FI-2.
2. **The censor's cheapest lever is the queue, not the frontier.** Because the frontier cannot skip an
   outstanding live record, a producer that simply refuses to include the front record **stops its own
   settlement** rather than censoring the record — the frontier does not move and no later range can
   settle. Censorship therefore has a cost in the mechanism, but the cost is a halt of the honest
   pipeline, not a fee paid to the censored user.
3. **The user's counter is to publish first.** A user that publishes before the censor's next batch can
   take the front of the queue; the censor must then either resolve the record or halt, and a censor
   that publishes its own records to push the queue ahead of the user must spend **at least one L1
   publication per deadline window** to keep the user's re-publications behind it. The mechanism thus
   bounds *exclusion per unit of the censor's L1 spending*, not exclusion per unit of time. That is the
   honest form of D-12's "upper bound on exclusion", and the increment states it in those words rather
   than claiming a latency guarantee it does not have.

### 6.4 What this increment does NOT fix

1. **An L1-censored publication cannot be forced.** If a network-level adversary can prevent the user's
   data from ever being published — or can isolate the user from every honest proposer — the obligation
   never starts. The same adversary can prevent the user from *starting* a withdrawal, because a
   withdrawal is initiated by an L2 transaction. No rule of this increment reaches that case, and
   `FI-REMOVED-01`'s disclosure stays true in its narrowed form. The general inclusion list (an
   obligation over transactions that were never published) remains deferred.
2. **Inclusion is not execution success.** The obligation delivers a forceable transaction to L2
   execution; whether it succeeds is the L2 execution rules' business. A producer can order a block so
   a forced transaction reverts; this is a reordering outcome, not an exclusion, and no rule here
   addresses it.
3. **No latency guarantee.** The deadline is an upper bound on how long a record may remain
   *outstanding*, not a promise that it is *included* before that bound (F-FI-2, F-FI-4).
4. **No measurement.** Every `FI_*` parameter, the capacity relation, the gas-schedule premise and
   the fee floor's own schedule premise (F-FI-7) are placeholders; Phase B measures them, and `FI_ANCHOR_MAX_AGE`'s calibration is the term that trades
   F-FI-6 against re-anchoring cost.

---

## 7. What the increment changes outside the revived rules (listed, not made)

Every item below is a required change for the increment to be consistent; **none has been made**. Line
anchors refer to the converged snapshot this delta was written against.

### 7.1 `spec/04-l1-integration.html`

- **`FI-REMOVED-01` (~L687)**: tombstone replaced by the revived statement: v1 has the narrow
  obligation, the general inclusion list stays absent, and the R10 disclosure is narrowed, not
  withdrawn.
- **`FI-10`–`FI-14` (~L691–699)**: tombstones replaced by §2's text — with FI-13's resolution ground as
  corrected in place by RC-5 (per-transaction execution or discharge at the transaction's turn, and
  FI-13(5)'s totality property) and by F1 (the byte-invalid limb's decision classes are the exhaustive
  list of FI-13(1)(b)); RC-6 extends that list with the fifth class, the fee-cap floor
  `FI_MIN_EXEC_FEE_CAP`, carries the same floor in FI-13(2)(vi) and registers the Open schedule premise
  F-FI-7. `FI-14`'s four stall-resolution clauses are dropped (no mechanism
  reads them in v1).
- **`DA-07`(2) (~L654)**: restate the register's ordered view: each record carries `l1BlockNumber` and
  `sequence`; `deadlineBlock` is derived (`l1BlockNumber + T_PROVE_DEADLINE`), never stored; the
  record carries **no status flag**, and the register exposes `nextSeq(A)` and a
  storage-proof-supported read of any position.
- **`DA-09`(1)/(2) (~L673, DA-09)**: delete the mutable `PUBLISHED | PROVEN | DISCARDED` status; state
  the derived live/dead predicate and keep the reference check as it is. This is the text that owns the
  status question R6-D12-01 left open (R5T-PDE-10).
- **`DA-10` (~L707)**: unchanged in substance (the anchor is the record's `l1BlockNumber`); add the
  pointer that the exclusion obligation and its discharge are stated in FI-10–FI-14 and that expiry is
  a proof-side ground (FI-13(1)(c)).
- **`L1-03`(6) (~L83)**: the settlement record becomes the pair `(settledCount, anchoredL1Block)` as
  already stated; add that the record is written **after** verification and is never read as an
  admission condition (already true; keep the sentence explicit).
- **`L1-04` (~L1-04)**: add one sentence: the proof-side capacity condition of FI-12 is part of proof
  validity and is not an admission rule, and a registration that satisfies FI-11(7)(i)–(ii) cannot make
  an in-envelope range permanently unacceptable for staleness.
- **`L1-05` row 35 (~L167)**: keep as the L1-local publication reference; add the derived deadline
  statement (no stored status).
- **`L1-05` row 36 (~L212)**: un-withdraw `forcedBoundary`; restate the commitment as
  `keccak256(abi.encode(bytes32("TAIKO_ETNA_FORCED"), chainId, l2ChainId, anchoredL1Block,
  settledFrontier, dueFrontier, settledAfter, forcedOpeningsHash))` with the guest recomputation of
  FI-11(2). Keep the "one bytes32, no individual frontier values" interpretation.
- **`L1-08` (~L256)**: replace `pruneExpiredPublications(uint32) returns (uint64)` with
  `prunePublications(uint32)` (deletion only, §4.2); add the register's view/next-position function;
  restate `ForcedFrontierAdvanced` to be emitted **only** by an accepted `land`, carrying
  `(height, settledFrontier, anchoredL1Block)`, with a companion
  `ForcedRecordsResolved(height, settledFrontier, resolvedCount, voidCount, deadCount)` for
  observability; add the errors of FI-11(3)(e) (`ForcedFrontierRegression`,
  `ForcedFrontierBeyondRegister`, `ForcedViewStale`, `ForcedCapacityInsufficient`,
  `ForcedRecordMissing`). No function that advances a frontier outside `land` may exist.
- **Page intro (~L13) and the R10 row (~L793)**: rewrite the "no inclusion obligation" disclosure.

### 7.2 `spec/05-proof-statement.html`

- **PRF-02 journal (~L164)**: un-withdraw the `forcedBoundary` field (L1-05 row 36), keeping the row
  numbering and the "one commitment" form.
- **PRF-04(vi) (~L269)**: replace the clause with FI-11(2)'s five checks and FI-11(3)(a)–(d), including
  the three resolution modes of FI-13(1) — restated as the per-transaction walk and its totality (RC-5),
  with the exhaustive byte-invalid classes named as FI-13(1)(b) lists them (F1) — including, by RC-6, the
  fifth fee-cap class below `FI_MIN_EXEC_FEE_CAP` — never the record-level
  "none of whose transactions is forceable" ground — and the capacity condition
  of FI-12(1)–(2). The clause MUST NOT contain the deleted exception.
- **PRF-04's other clauses**: unchanged; the new clause reads only data PRF-04 already re-executes.

### 7.3 `spec/02-consensus.html`

- **`CONS-01(v)` (~L72)**: tombstone replaced by FI-11(4): the order-and-non-omission duty, with no
  per-block count and no per-block gas quota. *(Amended in place by RC-5 addendum 2: the duty is scoped
  to the transaction's turn, so the per-block check and the walk are one predicate and a discharged
  transaction is never demanded — R4R3-T-01/R4R3-NR-01. RC-6: the predicate the duty inherits also
  carries the registered fee-cap floor of FI-13(2)(vi), so a below-floor-cap transaction is never
  demanded; the agreement claim is qualified to the reasons the predicate or the classes cover, and
  holds unconditionally under the Open premise F-FI-7. Review round 4, R4R4-NR-01: the clause also carries the block-validity order requirement — a block MUST NOT contain a record's transaction once a higher-index transaction of that record has appeared in the range's executed payload — the consensus-side counterpart of FI-13(1)(a)'s index-order condition, so the condition is not proof-only and no producer's inclusion order can defeat it.)*
- **M3 (~L522)**: restated as revived in narrow form, with the unit of account and the F-FI-1/F-FI-2
  falsifiers.

### 7.4 `spec/09-parameters.html`

- **Un-withdraw rows ~L189–198** and restate with the revived semantics and units:
  `FI_INCLUSION_DELAY` (L1 blocks, unmeasured), `FI_MAX_PER_BATCH` (**positions per batch**, not per
  block — the row must say so), `FI_MAX_TX_PER_RECORD`, `FI_RECORD_GAS_MAX`, `FI_ITEM_MAX_BYTES`,
  `FI_ANCHOR_MAX_AGE` (L1 blocks).
- **New row `FI_MIN_DRAIN`** (positions per accepted batch; registered relation
  `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`; the floor that makes `R = 0` impossible).
- **New row `FI_MIN_EXEC_FEE_CAP`** (wei per gas; unmeasured; the fee-cap floor of FI-13(2)(vi) and
  the fifth byte class of FI-13(1)(b)(E), carrying the **Open premise F-FI-7** that the floor is at or
  above the maximum execution base fee the L2 fee schedule can produce — RC-6). The `FI_RECORD_GAS_MAX`
  row's agreement note is reworded to the full class list and the qualified claim (F2).
- **Restate the FI capacity relation row (~L195)** as FI-12(4), with its two companions
  (`FI_RECORD_GAS_MAX ≤ L2_BLOCK_GAS_LIMIT`, `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`), and with the
  schedule premise tagged **Open / F-FI-1**.
- **Registered relations row (~L198)**: add `FI_INCLUSION_DELAY + L1_FINALITY_DEPTH < T_PROVE_DEADLINE`,
  `FI_ANCHOR_MAX_AGE ≥ L1_FINALITY_DEPTH`, `FI_ANCHOR_MAX_AGE(s) ≥ T_PROOF_MAX_PERMITTED +
  T_SETTLE_PIPELINE + L1_FINALITY_DEPTH`, and `T_PROVE_DEADLINE + FI_ANCHOR_MAX_AGE ≤` the
  retrievability window of DA-05.
- **`L2_BLOCK_GAS_LIMIT` row (~L232)** and the withdrawn-spelling row `FI_PREFIX_CAP` (~L190): keep
  the gas-limit row live (it is the capacity relation's input); retire `FI_PREFIX_CAP` as a withdrawn
  spelling.
- **Deferred-set notes (~L265)** and the measurement line: forced inclusion leaves the deferred list;
  the `FI_*` measurement line (publication gas, `forcedBoundary` recomputation gas, per-batch
  capacity under a target batch size, and the L2 gas-limit schedule check) is reinstated.

### 7.5 `spec/index.html`

- Rule-index rows ~L457–461: `FI-10`–`FI-14` become live descriptions with the new unit, the three
  resolution modes and the mandatory advance; `FI-REMOVED-01` and `FI-PLANNED-01` reworded. RC-6 names
  the fifth byte class and the fee floor in the FI-13 row and carries F-FI-7 into the LIM-01 range.
- Parameter map ~L554 and the "four mechanisms are deferred" front matter: forced inclusion leaves the
  deferred four (heartbeat was revived in increment 02; three remain: heartbeat's rotation, aggregation,
  the governance stall resolution).
- The line ~L586 prohibition ("no artifact may claim … that forced inclusion … exist in v1"): reworded
  for the new status, with the narrowed-R10 disclosure kept.

### 7.6 `spec/10-assurance.html`, `spec/07-economics-slashing.html`, `spec/01-system-model.html`, `spec/08-migration-upgrades.html`

- `10-assurance.html` (~L260, ~L358, ~L394, ~L420): the censorship row and the rejected-alternatives row
  move from "no inclusion obligation" to the revived obligation with its falsifiers (F-FI-1…F-FI-7: RC-6 adds F-FI-7, the fee floor's Open schedule premise, owed to spec/10's LIVE-04/LIM-01 rows by the owner of those files) and
  the narrowed disclosure; `LIVE-04`'s statement gains the distinction between the published case
  (this rule) and the unpublished case (proposer rotation only).
- `07-economics-slashing.html` (~L489, ~L526–551, ~L1110): **no forced-inclusion offence row is
  revived and no slash is added** — a signer that signs a block violating FI-11(4) is not subject to a
  new offence, a batch whose proof omits the resolution of a required position simply fails
  verification rather than being slashed, and the rejected proof is the whole enforcement; ECON-04's
  forced-inclusion offence row and ECON-13's forced-inclusion reference stay tombstoned exactly as
  D-16 left them and MUST NOT be implemented, and the no-fee terms of FI-10(8) are restated.
  *(Appended decision 6.)*
- `01-system-model.html` (~L532): the D-16 sentence naming the whole `FI-*` machinery as withdrawn is
  reworded for the revival.
- `08-migration-upgrades.html` (~L377): the storage-budget note for the register and the removed
  `FI_*` parameters is re-derived (the register now needs `pruneCursor` and `nextSeq`; the settlement
  record needs its pair).
- `spec/06-recovery-exceptions.html`: an explicit non-interaction sentence — the FI obligation reads no
  recovery mechanism, because v1 has none — placed where the recovered/settled distinction is stated.

### 7.7 `DEFERRED.md`, `DECISIONS.md`, course pages, `PLAN.md`

- **`DEFERRED.md` §1**: narrow forced inclusion leaves the register of deferred work; §2–§4 stay. The
  cross-cutting note ("three mechanisms remain deferred") is re-counted.
- **`DECISIONS.md`**: a new append-only entry (D-18) recording the revival, the four blocker
  dispositions, the one-unit decision, the three resolution modes, the monotone-frontier rule and the
  fact that D-12's *text* is unchanged where it is consistent and superseded only where its preserved
  rules were defective (the waiver, the status flag, the per-block unit, the environment predicate and
  the prune's return value).
- **`learn/`**: lessons that teach the censorship gap as absolute must be re-synced (the trigger is any
  change to a live rule, per DEFERRED.md's cross-cutting note); the course must not teach the
  general inclusion list.
- **`PLAN.md`** Phase 2 item 3: the four blockers are closed by this delta; the review round is still
  owed.

### 7.8 What this increment does NOT change

No change to: REC-01's boundary, MEM-15's exit, MSG-03/MSG-04, L1-13's k-family rule, ECON-02's funding
shares, D-8/D-9's destinations, DA-01–DA-06, DA-08's binding checks, PRF-01–PRF-03, PRF-05–PRF-15, the
consensus core (CONS-02–CONS-16), membership rules, or the recovery-free statement.

---

## 8. Why the increment does not reopen a v1 decision

- **The boundary (REC-01).** The register and the frontier are L1 state; the obligation reads no L2
  history and writes none. Nothing at or below the latest L1-accepted checkpoint is read, written,
  re-judged or delayed by the FI rules, and a proof that does not satisfy a boundary condition simply
  does not land — the boundary's text is unchanged.
- **The exit (MEM-15, MSG-03).** §5 states the non-interaction and the reason it is structural. The
  exit reads no FI state; no FI condition gates, delays or conditions a withdrawal root or its
  attestations; the veto is untouched.
- **D-8 / D-9.** No fee, reward, penalty or destination is introduced or moved: a forced record carries
  no escrow or bond (FI-10(8)), a forced transaction pays its own L2 gas, and L1-10/L1-11's terms are
  unchanged. The forced-inclusion offence rows in 07 stay tombstoned exactly as D-16 left them: no
  *signing* offence is revived and no slash is added — the rejected proof is the whole enforcement
  *(appended decision 6)* — so no funding path is created and D-9's destinations are untouched.
- **D-11.** The forced-data record **is** the D-11 publication record (FI-10(1)); this increment adds a
  derived deadline, a view, a settlement record and a prune whose semantics change, and it changes no
  data-binding check, no identity preimage field, and no publication rule. It is the D-11 mechanism
  being *used*, as D-12 intended.
- **No rule removes weight (D-14).** Nothing here decays, discounts, zeroes, confiscates or exits a
  validator's stake; no new offence is created anywhere in this increment *(appended decision 6)*.
- **No recovery path (D-15/D-16).** FI-14(2) *deletes* the preserved text's recovery clauses rather
  than carrying them; the increment adds no history-replacing path and no generation increment. If a
  recovery is ever revived (PLAN.md Phase 2's last item), FI-14(2) is the rule that must be re-derived
  with it, and this delta says so explicitly.

---

## 9. What this increment could not decide (for the review round and the owner)

### 9.1 The headline: F-FI-2 is carried, not repaired

The increment cannot bound a user's **wait** without bounding **arrival**, and bounding arrival means a
publication-time admission condition. Two candidates were considered and one is recommended:

- **Recommended to the review round — a per-publisher live-record bound.** Publish a record only if the
  publishing address has no *live, unresolved* record outstanding (or at most `p` of them). This
  bounds the queue by the number of distinct publishers, makes front-running a target O(publishers ×
  `T_PROVE_DEADLINE`) rather than unbounded, and costs a legitimate user nothing except serialization
  of their own publications. It is **not adopted here** because (i) it is a condition on `publish`,
  which D-12 does not authorise and which changes DA-07(1)'s "any account MUST be able to publish";
  and (ii) a censor with many funded addresses bypasses it, so its guarantee is economic, not
  structural. The owner should decide whether that trade is acceptable.
- **Rejected — a per-publisher or protocol fee.** It would fund nothing and would need an escrow, which
  `FI-PLANNED-01` forbids in the narrow rule.
- **Rejected — a rate limit on publication per L1 window.** It moves the censorship surface to the
  publisher and can be captured by whoever publishes first in a window.

### 9.2 The anchor-age residual (F-FI-6) and its three candidate repairs

1. **The registered envelope relation (written here, FI-11(7)(i)–(ii))**: `FI_ANCHOR_MAX_AGE` spans
   `T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY_DEPTH`, and
   `T_PROVE_DEADLINE + FI_ANCHOR_MAX_AGE` stays inside retrievability. Cost: a wider window than the
   pure anti-postponement argument needs. This is the recommendation.
2. **A consensus anchor-freshness duty** (`CONS-01` gains "produce against the freshest final view"),
   with the `land`-side age check deleted. Stronger for L1-04, but it is a new consensus rule whose
   enforcement the guest must check, and it does not help a range that was *already* certified before
   the duty existed. Left to the review round.
3. **A re-anchor path for a certified range.** Rejected: the anchor is committed inside the batch's own
   header bytes, so re-anchoring a certified range requires re-producing heights at or below a
   certification the boundary forbids rewriting. It would reopen REC-01/CREC-01.

### 9.3 Smaller open calls

1. **`FI_MIN_DRAIN`'s value** and whether it should be a registered parameter or derived from
   `FI_MAX_PER_BATCH`. This delta registers it, with `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`.
2. **Whether the per-block clause needs a gas floor at all.** The delta states order + non-omission only;
   a reviewer may prefer "the block must fill remaining gas with forced work", which is stronger but
   needs a definition of "remaining" the guest can check.
3. **The exact retention floor for the register's view.** §4.2 states `PUB_RECORD_RETENTION` and the
   prune-behind-the-frontier guard; whether a *ring* (overwriting old slots) or an *append* (unbounded
   storage) is used is an implementation decision with a storage-budget consequence (§7.6), and the
   migration audit must derive it.
4. **The offence's exact boundary in 07 — settled by appended decision 6.** A *validator* that signs
   a block violating FI-11(4) is not subject to a new slashable offence: only the prover's invalid
   proof is rejected. The delta leaves the enforcement on the proof (D-12's chosen point), revives no
   offence row, and the forced-inclusion rows in 07 stay tombstoned exactly as D-16 left them.
5. **Whether the FI family needs a measurement line for the register's binary search** (one row per
   batch's `dueFrontier` recomputation) — recommended yes, with S1/S3's gas work.

---

## Appendix A — Clause-by-clause difference from the preserved text (`7917ba264`)

| Clause | Preserved | Revived | Why |
|---|---|---|---|
| FI-10 "One register" | publication record is the forced-data record | kept in substance, **not** verbatim: retitled "(1) One register, no flag.", the identity sentence rewritten, and the stored-anchor and no-new-register sentences added *(repair: this cell claimed "kept verbatim"; the preserved and current clause texts differ)* | D-11/D-12 already right |
| FI-10 "Order and the due point" | due at `l1BlockNumber + FI_INCLUSION_DELAY ≤ A` | kept; adds `nextSeq(A)`, the live/dead derived predicate, and `deadlineBlock` derived not stored | R5T-PDE-10; the status flag is gone |
| FI-10 "Due point before death" | `FI_INCLUSION_DELAY < T_PROVE_DEADLINE` | strengthened to `FI_INCLUSION_DELAY + L1_FINALITY_DEPTH < T_PROVE_DEADLINE` | views are final-lagged; the window must be nonempty in *view* time |
| FI-10 "Expiry and discard" | "MUST be discarded … no proof may be required to include it" with no ground | expiry is resolution mode (c), keyed on `deadlineBlock ≤ A` | R6-D12-01 Critical |
| FI-11(1) enforcement point | proof not `land` | kept, with the capacity condition explicitly *proof validity* | R6-D12-04; L1-04 |
| FI-11(2) guest recomputation | 5 clauses | kept; (2) reads the anchored register, (3) computes the cap, (4) walks the three modes per transaction (RC-5) | R6-D12-01/-04; R4R1-M-01 |
| FI-11(5) lower bound | `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **unless the window is shorter…** | **(a) unconditional**, plus (b)–(e) | R6-DPE-01: the exception had no referent |
| FI-11 L1-side checks | view final, non-stale, age-bounded; frontier regression/overshoot | kept, plus the registered envelope relations (7) | R6-D12-02 |
| FI-11 "greatest anchored view" | kept | kept | R5T-PDE-07; no shrink by range choice |
| CONS-01(v) | per-**block** prefix up to `FI_MAX_PER_BATCH` records | per-**block** order + non-omission **at the transaction's turn** (scoped to the walk's verdict — RC-5 addendum 2); no count, no quota | R6-D12-03/-04 (unit mismatch); R4R3-T-01/-NR-01 (the duty and the walk are one predicate); review round 4, finding F1/RC-6 (the inherited predicate carries the fee-cap floor, and the agreement claim is qualified to the reasons the predicate or the classes cover, unconditionally under F-FI-7; the block-validity order requirement (no transaction of a record after a higher-index one has appeared — review round 4, R4R4-NR-01) |
| FI-12 cap | `min(FI_MAX_PER_BATCH, floor(batchGasCapacity/itemGasBound))` | kept **and enforced** in the guest, with `R ≥ 1` whenever the outstanding obligation is non-empty (`R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding — RC-2) | R6-D12-04: no enforcement point existed |
| FI-12 claims (1)–(4) | counting argument | restated in positions per batch with `W` (live) and `R` (resolved) | one unit; dead records cost no gas |
| FI-13 predicate | chain id, nonce, balance **at that block's base fee**, gas limit **fits the block** | chain id, nonce, balance against `t`'s **own declared maximum charge**, gas limit `≤ FI_RECORD_GAS_MAX`, `≥` the intrinsic gas of its own data and a declared `maxFeePerGas` `≥` the registered floor `FI_MIN_EXEC_FEE_CAP`, and a signature that recovers to a sender; **base fee and block gas limit removed** | R6-D12-05 (environment steering); F1/`04-coordination.md` §5 (no transaction is forceable that no valid block can carry for a reason the predicate or the classes cover); review round 4, finding F1/RC-6 (the fifth fee-cap class and its Open schedule premise F-FI-7) |
| FI-13 discharge | included or void "only if not includable in any block of the batch" | executed, void, **or dead**; a transaction is executed or **discharged at its turn**, and void = a **live** record over-bound, containing a transaction that can never be executed from its own bytes, or with every transaction discharged; dead is tested first (RC-5 + addendum) | R6-D12-01; R4R1-M-01; the "block full" ambiguity removed |
| FI-13 "no other ground" | "not the record's own age while it is still live" | dropped; age is now a named ground when dead | the qualifier implied a ground no rule had |
| FI-14 no discretion | list forbids "skips a prefix element except by include-or-void under FI-13" | "except by executed, void or dead under FI-13(1)" | blocker 4 |
| FI-14 across a stall resolution | four clauses reading REC-02/REC-04 | **deleted**; replaced by monotone L1 state, L1-reorg carry, and the explicit no-recovery non-interaction | D-15/D-16: v1 has no recovery |
| FI-REMOVED-01 | tombstone of D-6, narrowed by D-12 | revived statement of what v1 guarantees | increment's purpose |
| L1-08 prune | `pruneExpiredPublications(uint32) returns (uint64 settledFrontier_)` | `prunePublications(uint32)`, deletion only, behind the settlement frontier | R6-D12-01 horn A/B |
| L1-05 row 36 | withdrawn | restored with the guest recomputation | the boundary must be a public input again |
| L1-04 | no gate, no expiry | unchanged; plus the proof-validity distinction and the envelope relation | preserves the v1 decision |

## Appendix B — Every previously-found attack vector against the check that now rejects it

| # | Vector (finding) | Now rejected by |
|---|---|---|
| 1 | Required set = whole due set with a cap below it: one publication halts the chain (R2-LIV-01, round 1) | FI-12(3)(1): the required set is `min(d(A) − c, cap)` **positions**; a batch at the cap is compliant |
| 2 | A record carrying `FI_MAX_PER_BATCH + 1` includable transactions halts the prefix (R5T-PDE-01) | FI-13(2)(i)–(ii): over-bound records are void from their own immutable bytes; they consume no gas |
| 3 | One proof writes the frontier past the register and empties the prefix (R5T-PDE-03) | FI-11(3)(b): `c' ≤ nextSeq(A)`, plus `ForcedFrontierBeyondRegister` at L1 |
| 4 | A stale anchored view postpones the due set without limit (R5T-C-1/F3/R5T-PDE-07) | FI-11(2)(1) greatest-anchored-view + FI-11(6) age bound + FI-10(4) |
| 5 | The frontier's lower bound is waived by the "unless the window is shorter" exception, so `c' = c` passes and the rule is dead (R6-DPE-01) | FI-11(3)(a): unconditional bound, no exception exists in the text |
| 6 | `cap = 0` by choosing a one-block batch; the drain rate is the submitter's choice (R6-D12-04) | FI-12(1)–(2) and FI-11(2)(3): capacity condition is proof validity; `R ≥ 1` whenever the outstanding obligation is non-empty (`R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding — RC-2) |
| 7 | The per-block clause demands more records than a block can carry (R6-D12-03) | FI-11(4): order + non-omission, no per-block count or quota; FI-11(3)(a) carries the count at the batch |
| 8 | The environment (base fee, block gas limit, block room) makes a due record void without executing anything (R6-D12-05, R5T-H-4/F4) | FI-13(2)–(3): those terms are removed from forceability; the void ground is producer-independent. (Review round 4, finding S-02: the block's own remaining gas is read by the mirrored **discharge** ground at the turn, never by forceability or voidness — the walk discharges only a transaction no block of the range at or after the turn had room for, the same quantity the duty reads.) |
| 9 | A full block is read as "not a member of its body", so the record can be neither included nor voided (R6-D12-05 alternative reading) | FI-11(4) non-omission + FI-13(1)(a)/(b): a transaction that can execute at its turn must be executed; one that cannot is discharged, and the walk is total (RC-5). (Review round 4, finding S-02: a turn at which no block of the range at or after it had room is itself a discharge ground, mirroring the duty's escape, so a block that had room cannot use this route.) |
| 10 | A dead record has no proof-side discharge; it blocks the prefix for ever, or the prune moves enforcement off the proof (R6-D12-01 horns A/B) | FI-13(1)(c) + FI-10(7): dead-at-`A` is a resolution mode; §4.2: the prune deletes only behind the frontier and returns nothing |
| 11 | A pruned or blob-expired record cannot be evaluated at all, and `FI-11(5)` rejects a position with no record (R6-D12-01 step 4) | §4.2: the prune is behind the frontier, so a needed position is never deleted; and a dead record needs only its stored `l1BlockNumber` |
| 12 | The record must be immutable yet must carry a mutating `PUBLISHED/PROVEN/DISCARDED` status (R5T-PDE-10) | FI-10(2): no status flag; live/dead is derived from the stored block number and a registered constant |
| 13 | The interface mandates a prune that FI-14 forbids (R6-D12-01) | §4.2 + FI-14(1): the prune is deletion only, writes no frontier, and is not a resolution ground |
| 14 | A certified in-envelope batch ages out of `FI_ANCHOR_MAX_AGE` and is permanently unacceptable (R6-D12-02) | FI-11(7)(i)–(ii): the registered envelope relations; the residual is F-FI-6 and §9.2 |
| 15 | A record voided here may be includable later (F-FI-3) | FI-13: discharge is evaluated at the transaction's turn; only the sender's own further signed transactions can move its nonce, while its balance can be moved by anyone — a credit can only make a transaction executable, never discharged, and the producer's ordering of that credit relative to the turn is the disclosed residual; the remedy is re-publication (DA-09(2)) |
| 16 | Arrival exceeds drain, so waits grow without bound (F-FI-2) | **Not rejected** — carried Open; §6.3 and §9.1 state the candidate bound and its cost |
| 17 | A record ages out of its deadline before the frontier reaches it (F-FI-4, new) | **Not rejected** — expiry is the discharge; disclosed in FI-10(7) and §6.1 |
| 18 | A user's data never reaches L1, or the L1 layer censor excludes it (A-L1-1, Fi-REMOVED-01(b)) | **Not rejected** — disclosed; the narrow rule begins at publication, and the withdrawal-start case stays disclosed |
| 19 | A stall resolution or an owner path clears, voids or re-clocks pending records (the preserved FI-14 interaction) | FI-14(1)–(2): no such path exists in v1; the clauses that named it are deleted |
| 20 | A reorg resurrects a settled record or drops an unsettled one inconsistently (L1-12) | FI-14(2): the register, the settlement record and the frontier carry with the reorged L1 state |
| 21 | A forced-inclusion obligation blocks a withdrawal root | §5: the exit path reads no FI state; the obligation freezes only the settlement frontier, which is bounded by expiry |
| 22 | A submitter supplies its own due list or frontier to shrink the obligation (FI-11) | FI-11(2)(2): only storage-proof-supported reads at `A`; witness-supplied lists are rejected; `forcedBoundary` is recomputed |
| 23 | A proposal omits a required record and the proof accepts it (FI-11/FI-13) | FI-11(2)(4), FI-11(3)(c): every position in `[c, c')` must be resolved; an unconditional walk |
| 24 | A per-block count forces validators to vote NIL, halting certification (R6-D12-03) | FI-11(4): the block duty is decidable from the block's own body; no count is imposed |
| 25 | A live record with one executable and one never-executable transaction is neither executed, void nor dead, so every proof in the window is invalid until expiry — a permissionless, repeatable, chain-wide settlement halt (R4R1-M-01, round 1 Critical) | FI-13(1) + FI-13(5): the resolution ground is per transaction and total — the executable transaction must execute, the non-executable one is discharged at its turn, and no published record can pin the frontier (RC-5) |
| 26 | A live record with one executable transaction and one that can never be executed from its own bytes (a chain id that does not match FI-13(2)(iii)) is neither executed nor discharged at a turn — the same halt in its immutable half | FI-13(1)(b)/(4): the immutable half of the forceability predicate is a live record-level void ground, so the record resolves void and the frontier advances (R4R1-M-01; RC-5 addendum) |
| 27 | An over-bound or byte-invalid record that is also dead satisfies (b)'s unconditional record-level limbs **and** (c), so "exactly one mode" fails and the position is unresolvable; every proof in the computed window is invalid until expiry — the same halt, repeatable for one publication per deadline | FI-13(1)'s stated precedence: (c) dead is tested first and unconditionally, and (b)'s record-level limbs are live-only; FI-13(1) states that the modes partition, FI-13(4) is corrected to agree, and FI-11(2)(4) and PRF-04(vi) restate the same order (RC-5 addendum — the reviewer's edge case) |
| 28 | A live over-bound record one of whose transactions appears in the executed payload satisfies both (a) and (b) under the old wording, so "exactly one mode" fails again and the payload's contents decide whether the record executed or voided | FI-13(1): the over-bound limb is tested before (a) and (a) requires the record not be over-bound, so an over-bound record is (b) void from its own immutable bytes whatever the payload contains — the classification keeps no producer-set input (RC-5 addendum) |
| 29 | A live, byte-valid record whose transaction declares a fee cap below the block's base fee (`maxFeePerGas = 0` or 1 wei) is called forceable by FI-13(2) and demanded by FI-11(4) while no valid block can carry it, so every proof in the computed window is rejected and settlement freezes until expiry — one permissionless publication per `T_PROVE_DEADLINE` (review round 4, finding F1, Critical) | FI-13(1)(b)(E) + FI-13(2)(vi): a declared `maxFeePerGas` below the registered floor `FI_MIN_EXEC_FEE_CAP` is void from the record's own bytes and not forceable, so the predicate, the void classes and the per-block duty agree; the block's base fee stays out of the predicate, and the floor's schedule premise is the Open falsifier F-FI-7 (RC-6) |
| 30 | A live, byte-valid record whose transaction declares `maxPriorityFeePerGas` above its own `maxFeePerGas` is called forceable by FI-13(2), demanded by FI-11(4), is not void under the old classes, and is rejected by every valid block — the same settlement halt, byte-decidable (review round 4, finding S-01, Critical) | FI-13(1)(b)(F) + FI-13(2)(vii): a malformed fee market is void from the record's own bytes and not forceable, so the predicate and the classes agree (RC-7) |
| 31 | A create transaction whose declared initcode exceeds the EIP-3860 cap is forceable and demanded but carried by no valid block — the same halt, its own bytes (review round 4, finding S-01, Critical) | FI-13(1)(b)(G) + FI-13(2)(viii): the cap is a byte-decidable class, and the intrinsic-gas floor does not cap initcode (RC-7) |
| 32 | A transaction whose sender has code at its turn pre-state passes FI-13(2) but no valid block may execute it (EIP-3607), so the walk would demand it while no inclusion is possible (review round 4, finding S-01, Critical) | FI-13(1)(a): a sender with code at the turn pre-state is a discharge ground alongside the nonce and the balance — L2 state, not a byte class — and the duty's scoping inherits the discharge grounds, so the two checks agree (RC-7) |
| 33 | A transaction that does not appear and has no later appearing transaction of its record has its turn at the end of the batch's execution — a pre-state of no block — so the walk demands what no block is required to carry; and a producer that fills the one block holding a transaction's turn omits it with impunity while the walk rejects the range (review round 4, finding S-02, Critical) | FI-13(1)(a): the tail turn is pinned to the state the batch reaches after the record's last earlier appearing transaction — so no earlier appearing transaction can execute after it — and the walk gains the mirrored discharge ground (a turn at which no block of the range at or after it had room), so the duty and the walk read the same turn and the same remaining gas; the immediately-before-the-last-block form is superseded by RC-8 (S-02 edge: a sibling placed in the last block was read before it executed) (RC-7; RC-8) |
| 34 | The record's object type is defined twice and differently: DA-07 publishes a PRF-07(0) batch payload while FI-13(2)(i) and the 09 row read a transaction list, so the walk's transaction recovery is unpinned and one register has no type flag (review round 4, finding S-03, Medium) | DA-07(1): the record's published byte string is pinned as the PRF-07(0) batch payload of its own claimed range, and its transactions are the transactions of its frames' block bodies; FI-13(1)(b)(A)/FI-13(2)(i) and the 09 rows read that same object (RC-7) |
| 35 | A nonce-descending record `[t1 (index 0, nonce n+1), t2 (index 1, nonce n)]` is included in the only order that executes both (`t2` then `t1`), so the executed payload's indices descend, FI-13(1)(a)'s index-order condition fails, no mode resolves the position and no proof can cover the range — no rule is violated and the transactions are ordinary fee-paying ones (review round 4, finding R4R4-NR-01, Critical) | `CONS-01(v)`/FI-11(4): the block-validity order requirement — a block MUST NOT contain a transaction of a forced record once a higher-index transaction of that record has appeared in the range's executed payload — makes such a block invalid, and FI-13(1)(a)/PRF-04(vi) keep the proof-side condition the guest checks, so the certified-range-no-proof halt cannot be entered through inclusion (R4R4-NR-01) |

---

*End of increment 04. The review round owns the fresh adversarial pass; nothing here claims it has
happened, and nothing here has been applied to the specification.*

---

## Owner decisions on the open items

**Appended decision record.** This section records the owner's dispositions of §9's open calls. It
changes nothing above it: the rule text of §2, the derivations of §§3–5, the falsifiers of §6 and
the change lists of §7 stand as written — except where the review-corrections block at the end of
this document corrects them against the owner-ratified readings. The one open call not named here — §9.3's measurement-line
question — keeps its recorded recommendation for the review round.

**1. The per-publisher live-record bound (F-FI-2) is not adopted in this increment.** F-FI-2
(publish arrivals exceeding the drain rate) stays an **open, unfixed falsifier**, with the candidate
remedy of §9.1 recorded for a future increment. A bound on `publish()` is a new restriction on the
publication path; D-12 authorises an inclusion **obligation**, not a new publish-time condition, and
§9.1 already records that the candidate would change DA-07(1)'s "any account MUST be able to
publish". Adding a constraint on users to rescue an unfixed falsifier is the failure mode this
project has already been caught by three times: the honest resolution is to state the guarantee's
condition rather than engineer around it with an admission rule. The guarantee therefore holds only
while arrivals stay within the drain the obligation can force, and the text MUST say so wherever the
guarantee is summarised — §6.3(3) and the F-FI-2 row are the places that do.

**2. The anchor-age residual (F-FI-6) is closed inside the envelope by the registered relation, with
the residual disclosed** — the option the delta already writes at FI-11(7)(i)–(ii). There is **no
consensus anchor-freshness duty** and **no re-anchoring path**: both would add a rule to the
consensus path — the duty at `CONS-01`, the re-anchor path through the certified batch header, which
§9.2 records as reopening REC-01/CREC-01 — to buy back an edge the envelope relation already bounds.
§9.2's candidate 1 is the disposition; candidates 2 and 3 are closed rather than left to the review
round, and F-FI-6 stays disclosed as the deliberate-delay residual.

**3. `FI_MIN_DRAIN` is a registered parameter, not a derived term.** Its value is unmeasured, as
every `FI_*` value is; it satisfies `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`, as FI-12(4) already
registers it; and it exists to remove the reachable cap-of-zero case — the `R = 0` that R6-D12-04
found reachable under a one-block batch. A derived form would require a quantity the specification
does not compute; the registered relation is the form the rules consume. §9.3's first open call is
settled: registered, unmeasured, floor of one.

**4. The per-block clause gets no gas floor.** FI-11(4)/`CONS-01(v)` stays a per-block **order and
non-omission** duty — scoped to the transaction's turn (RC-5 addendum 2) — with no per-block gas quota,
as §2 and §7.3 write it. Any gas floor — the "fill
remaining gas with forced work" option of §9.3 — would reintroduce exactly the steerability that
blocker 3 (§1(c), the void predicate's environment half) exists to remove: a producer able to move a
threshold can move the obligation, and the guest would need a definition of "remaining" it can
check. The duty stays decidable from the block's own body and its pre-state; §9.3's second open call
is settled against the floor.

**5. The register is append-with-a-prune-cursor, not a ring.** The register appends, and the prune
of §4.2 deletes only positions behind the settlement frontier through the stored `pruneCursor`, with
`PUB_RECORD_RETENTION ≥ T_PROVE_DEADLINE` (FI-14(3), DA-09(1)) keeping a referenceable record
readable. Append matches the D-11 publication record already specified (FI-10(1)), keeps the
frontier monotone, and its migration budget is the one §7.6 already states. A ring would add
wraparound state and a migration risk for no gain the prune cursor does not already give. §9.3's
third open call is settled in favour of append.

**6. A validator signing a block that violates FI-11(4) is not subject to a new slashable offence.**
The proof is rejected, and that rejection is the whole enforcement: no new offence is created,
consistent with D-16's disposition that tombstoned the forced-inclusion offences. The consequence is
stated where the enforcement is described — FI-11(1)'s proof-side point and PRF-04(vi) — so an
implementer does not invent a penalty. This settles §9.3's fourth open call; to that extent the
"revived offence row" wording in §7.6 and §8 is superseded by this decision, and no signing slash
is to be implemented.

**The guarantee, in the delta's own honest terms.** This mechanism is **not a latency guarantee**.
A pure censor that refuses to include the front record halts its own frontier rather than censoring:
the frontier cannot skip an outstanding live record, so settlement stops with it (§6.3(2)). A
publishing censor can front-run a user's re-publications at roughly one L1 publication per deadline
window (§6.3(3)), and an L1-censored publication still cannot be forced (§6.4(1)). The guarantee is
therefore **exclusion per unit of the censor's L1 spending**, conditional on at least one honest or
rational batch producer (F-FI-5) and on a non-censoring L1 — D-12's upper bound on exclusion in the
only form this mechanism delivers.

**Ship condition.** This increment ships only after its implementation and its own review round are
clean; **two consecutive clean rounds are required, exactly as increment 2 was reviewed**. These
owner decisions close the open calls they name; they do not substitute for that review, and the
closing note above stands — the fresh adversarial pass has not happened and nothing here has been
applied to the specification.


---

## Review corrections (reconciliation pass, increment 4)

The rules implementer did not transcribe two clauses of §2 literally, because as written they are
unsatisfiable. The owner ratified both implemented readings (`04-coordination.md` §4): **the delta is
what is corrected here, not the rule.** These corrections are part of the delta; a later reader MUST
NOT restore the superseded forms.

**A fifth entry, RC-5, is not a transcription correction:** it is the design owner's ruling on review round 1's Critical
R4R1-M-01, and it supersedes the record-level resolution ground of §2's FI-13 (corrected in place below)
and the old F-FI-3 wording.

**RC-1 — FI-12(2): the resolved count is the window, not the live count.** The clause wrote
`R = min(W, FI_MAX_PER_BATCH)` with `W` the live count. `d(A)` counts **dead** records (FI-10(5))
and FI-11(3)(a) demands `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **unconditionally**, so that form makes
any window containing a dead record unsatisfiable: no proof could land, and the frontier would be
pinned by expiry positions — the obligation would be dead in exactly the case expiry exists to
discharge. Corrected to `R = min(d(A) − c, FI_MAX_PER_BATCH)` (the resolved count, the window), with
`W` the **live** positions in `[c, c + R)` (the work and gas count). Then `c' = c + R` meets the
advance condition with equality and dead positions cost no gas. (§2 FI-12(2); §3.1 table; Appendix A;
Appendix B rows 1 and 6.)

**RC-2 — FI-11(2)(3): the floor is a floor of one, not a rejection threshold.** The clause wrote
"reject the proof unless … `R ≥ FI_MIN_DRAIN`". That is a deadlock when fewer than `FI_MIN_DRAIN`
positions are outstanding — the obligation would become unsatisfiable precisely when little is owed.
Corrected to require `R ≥ 1` whenever the outstanding obligation at `A` is non-empty; the capacity
condition turns it into `R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live record is outstanding.
`FI_MIN_DRAIN` remains the registered floor `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`, whose purpose is to
remove the reachable cap-of-zero. (This is the reading 09's `FI_MIN_DRAIN` row states; the update to
09 is the register-row reconciliation.)

**RC-3 — FI-12(1)(i)/(ii): the per-block bound is `FI_MAX_PER_BATCH × itemGasBound`.** The clause left
the per-block bound unnamed. It is `FI_MAX_PER_BATCH × itemGasBound`, the only reading under which
"in both cases `cap(batch) = FI_MAX_PER_BATCH`" holds; it is now written explicitly in the clause.

**RC-4 — FI-12(5)(ii): `L2_BLOCK_GAS_LIMIT` is bound by the anchored L1 view, not by a config
preimage.** The clause claimed the per-epoch configuration of PARAM-04 commits the value through the
`paramVersion = 2` preimage of PRF-02(5). That is wrong and MUST NOT be implemented: V2 is historical,
valid only for epochs already entered under it, and the live preimage is V3, whose field list does not
contain the value. Corrected: the capacity relation reads the value from the anchored L1 view the proof
already fixes, so it is bound without any preimage change; PRF-02(5)'s field list is left alone, and
PARAM-04's text and 09's un-withdrawn `L2_BLOCK_GAS_LIMIT` row state that no preimage enumeration
changes.

**RC-5 — the owner's ruling on R4R1-M-01 (Critical, review round 1): the resolution ground is per
transaction, and the walk is total.** The record-level ground was not total, so one permissionless
publication halted all settlement. Attack trace, fixed in full: publish one record whose payload has two
transactions within every registered bound — `t1`, the publisher's own valid next transaction (forceable
at the batch's first pre-state), and `t2`, any signed transaction whose declared nonce is unreachable
(for example `current + 10^6`). Mode (a) failed because not all of the record's transactions could
execute; mode (b) failed because `t1` *is* forceable; mode (c) failed while the record was live.
FI-11(2)(4)/PRF-04(vi) made every position in the computed window `[c, c + R)`,
`R = min(d(A) − c, FI_MAX_PER_BATCH)`, mandatory, so once the frontier reached the position every
batch's proof was invalid: no new checkpoint, no new withdrawal root, and the L2 halted at the depth cap
until the record was dead — one fresh poison per `T_PROVE_DEADLINE` kept it frozen indefinitely for the
cost of one L1 publication and one valid L2 transaction. The opposite reading ("any transaction
non-forceable implies void") was also rejected: a producer could then void a record by including or
ordering the sender's own competing transactions.

**The ruling (design owner, 2026-10-07): per-transaction resolvability.** A position resolves by
executing the record's transactions **in the record's own order**. Each transaction either (i)
**executes**, or (ii) is **discharged** as non-executable at its turn — after the record's own preceding
transactions have executed, it cannot execute at that pre-state (its nonce is ahead of, or already
consumed past, the account's resulting nonce, or it is unaffordable there). A position is **resolved**
when every one of its transactions has either executed or been discharged; it is **executed** when at
least one executes, with the discharged ones recorded as discharged, and **void** when none executes;
**dead** is unchanged. **Totality is a rule property**: every position resolves in a bounded number of
batches, so no published record can pin the frontier and halt settlement — a record whose remaining
transactions cannot execute is fully discharged by that discharge, not left unresolved. **The anti-void
property is preserved exactly**: a producer still MUST NOT be able to make a forceable transaction
unexecutable by its own choices, because execution follows the record's own order; only that account's
own signed transactions can move its nonce, and an incoming credit can only make a transaction
executable, never discharged, so a producer cannot manufacture the nonce half of a discharge ground for
someone else's transaction. The one producer-set ordering that can decide a discharge is where a credit
lands relative to the turn of a transaction that is unaffordable there without it — the disclosed
residual F-FI-3. **F-FI-3 is restated** for the new semantics: a discharged transaction may become
executable later through the sender's own further signed transactions, or, where it was unaffordable at
its turn, through a credit arriving after that turn, and the remedy for a record whose transactions were
discharged is re-publication (DA-09(2)).

**RC-5 addendum — the dead/over-bound overlap (review pass, 2026-10-07): the modes partition.** Mode (b)
read its record-level limbs unconditionally — over-bound under FI-13(2)(i)–(ii), or containing a
transaction that can never be executed from the record's own bytes — while mode (c) read "the record at
`j` is dead at `A`". A record that was over-bound (or byte-invalid) **and** dead therefore satisfied
both (b) and (c): the "exactly one" test failed, and under the rule as written the position was resolved
by no single mode. That is the same failure class as R4R1-M-01: FI-11(2)(4)/PRF-04(vi) make every
position in the computed window `[c, c + R)` mandatory, so an unresolvable position invalidated every
proof in the window, and one fresh publication per `T_PROVE_DEADLINE` kept settlement frozen. The fix,
written in place: **(c) dead is tested first and unconditionally** — a record dead at `A` is dead
whatever its size, contents or discharge state — and the record-level limbs of (b) are **live-only**
("live at `A` and over-bound…", "live at `A` and contains a transaction that can never be executed…",
"live at `A` and every one of its transactions is discharged"). FI-13(1) states that the three modes
**partition** every record at every anchored view, and that (a)'s walk and (b)'s discharge limb are
disjoint (at least one executes versus none executes).

**Two further overlaps in the same class, closed with it.** (i) A **live** over-bound record one of whose
transactions appears in the executed payload satisfied both (a) and (b) under the old wording — again no
single mode, with the producer's inclusion choice deciding the classification. The over-bound limb is now
tested **before (a)** and (a) additionally requires the record not be over-bound, so such a record is
(b) void from its own immutable bytes whatever the payload contains. (The limbs of (b) may still hold
together — a live, over-bound, fully discharged record — and that is one mode, not two; a record with
**no** transactions is void under the discharge limb, since there is nothing to execute, and is stated
so no zero-transaction record falls outside all three.) (ii) The reported edge case also held with the
**byte-invalid** limb: a dead record containing a transaction that can never be executed from its own
bytes satisfied that limb and (c); the live-only correction closes it the same way, and FI-13(4)'s
unconditional "a record above any registered bound is void" is corrected to "a **live** record…" so the
clause agrees with (1)(b). FI-11(2)(4) (the window walk) and PRF-04(vi) restate the same precedence, and
FI-13(2), FI-13(5) and FI-12(6) are aligned with it.

**The precedence MUST NOT be inverted or dropped.** The superseded forms are: any reading in which (b)'s
over-bound or byte-invalid limb is available to a record that is dead at `A`, any reading in which (a)
can apply to a live over-bound record or to a record containing a transaction that can never be
executed, and any reading in which a dead over-bound record is (b) rather than (c). A later reader who
restores any of them restores an unresolvable position and, with it, the window-wide halt.

**RC-5 addendum 2 — the per-block duty is scoped to the walk's turn (review round 3, R4R3-T-01 /
R4R3-NR-01, derived independently twice, and R4R3-T-02).** `CONS-01(v)`/FI-11(4) as first written kept
the raw FI-13(2) predicate at *every* pre-state of a block while the walk of FI-13(1)(a) discharges a
transaction only at *its turn*. For a record ordered `[t1 (index 0, nonce n+1), t2 (index 1, nonce
n)]` the two checks then disagreed on the same transaction: the walk discharges `t1` at its turn before
`t2` executes (its nonce is ahead there), while the per-block duty demanded `t1` in the block that
contains `t2` as soon as `t2` executed and `t1` became forceable — and a block obeying the duty
contains the two executions in the wrong index order, which FI-13(1)(a)/PRF-04(vi) cannot resolve. One
permissionless publication, a rule-following producer with room and honest validators then certified a
range that no proof can ever cover, and because ranges are contiguous settlement could never pass it.
**The fix, written in place:** the duty applies **at the transaction's turn** — the pre-state
FI-13(1)(a) pins by position — and only where the walk's own verdict there is *executable*; it never
demands a transaction the walk discharges, and never a transaction of a record resolved (b) void. The
per-block duty and the proof-side walk are therefore **one predicate** (the clause's own requirement —
a disagreement is a protocol defect), and a duty that demanded a transaction the walk had discharged
would be unsatisfiable by construction, because a discharge is fixed by the record's own order and the
batch's own execution, never by a block's contents. The **"increasing transaction index"** condition
now states its scope explicitly: it governs only the transactions the walk **executes**; a discharged
transaction does not appear, so it cannot violate the order and no block is required to include it. In
the example `t1` is never demanded — the walk discharges it at its turn, before `t2` executes — and
the executed set `{t2}` is in increasing index order, so the halt cannot be derived. *(Corrected, review round 4, R4R4-NR-01.)* That closure argument rested on an assumption nothing enforced: that the batch contains **only** the transactions the walk would execute. No rule forbade a block from containing `t1` after `t2` — the artifact had no `MUST NOT contain` clause for a forced record's transactions — and the two transactions are ordinary fee-paying ones, so a producer with no malice could include both in the only order in which a block can execute them (`t2` then `t1`; `t1` first is a nonce gap). The executed payload then shows the record's indices as 1 then 0: FI-13(1)(a)'s index-order condition fails, (b) fails while the record is live, (c) fails, the position is in no mode, and no proof can cover the range — the same certified-range-no-proof-can-cover class as rounds 1–3, entered through **inclusion** instead of omission. **The fix, written in place:** per-record payload index order is a **block-validity rule** in `CONS-01(v)`/FI-11(4) — *a block MUST NOT contain a transaction of a forced record once a higher-index transaction of that same record has already appeared in the executed payload of the range*, so a block that includes a record's transaction out of the record's own order is invalid, exactly as one that had room to carry a demanded transaction and omitted it — and the index-order condition of FI-13(1)(a)/PRF-04(vi) is **kept** as the guest's check on the executed payload (it is not dropped: without it the producer's own ordering would decide whether a transaction executes or is discharged). The consensus-side rule and the proof-side condition name each other, and the discharge grounds of FI-13(1)(a) — including the mirrored no-room ground of RC-7 — and the tail-turn pin govern only a transaction that does not appear, so an out-of-order appearance is excluded by the block-validity rule and is never silently resolved by the walk. **The joint property:** with (i) the per-block duty scoped to the turn, (ii) the turn pinned by position, (iii) the consensus-side order requirement and (iv) the proof-side index-order condition, the record `[t1 (index 0, nonce n+1), t2 (index 1, nonce n)]` can only be resolved as `t1` discharged at its turn and `t2` executed: `t1` cannot execute before `t2`, the order requirement makes the only order in which both can appear (`t2` then `t1`, indices 1 then 0) invalid, and with `t2` appearing `t1`'s turn is the pre-state immediately before `t2`'s position, where its nonce is still ahead, so the walk discharges it and the duty never demands it. No admissible block can make the position unprovable, and no producer choice decides which resolution applies. **The hole cannot be restored:** a later reader who drops the order requirement, or who reads the index-order condition as proof-only or as governing only admitted appearances while inclusion stays unordered, restores the Critical. The **turn of a
transaction that never appears** is pinned by position at the same time (R4R3-T-02): the pre-state
immediately before the record's next transaction in the record's own order that appears, and the
pre-state at the end of the batch's execution when no later transaction of the record appears (superseded by RC-7 and RC-8: the tail turn is now the state the batch reaches after the record's last earlier appearing transaction), so two
conforming guests compute one pre-state, not two. **The producer-independence claim is corrected for
credits** (R4R3-T-02): only the account's own signed transactions can move its **nonce**; its
**balance** can be moved by anyone, and the producer's ordering decides whether an incoming credit
precedes the turn (the transaction is forceable there and must execute) or follows it (the transaction
is discharged as unaffordable at its turn). An incoming credit can only make a transaction executable,
never discharged, and the credit-ordering edge stays the residual **F-FI-3** — it is not a new ground.

**The F1 seam is closed with it (`04-coordination.md` §5).** The byte-class enumeration left
FI-13(2) able to call a transaction forceable that no valid block can carry — one whose declared gas
limit is below the intrinsic gas of its own data, or whose signature does not recover. The predicate
now carries both requirements: (2)(ii)'s intrinsic-gas floor and (2)(iv)'s signature recovery. The
per-block duty inherits the corrected predicate, so the duty and the walk agree by construction and no
transaction is demanded that no valid block can carry. Round 4 must verify the three properties §5
names: a below-intrinsic-gas transaction is neither forceable nor demanded; an unrecoverable-signature
transaction is likewise neither; and no transaction exists that (2) calls forceable but which no valid
block can carry.
*(Review round 4, finding F1 — RC-6: the third property was false as written, because the fee cap was
missing from both the predicate and the void classes and a self-signed transaction with
`maxFeePerGas = 0` was called forceable and demanded while no valid block can carry it. RC-6 adds the
fifth class of FI-13(1)(b)(E) and the forceability floor of FI-13(2)(vi), registers
`FI_MIN_EXEC_FEE_CAP` with its Open schedule premise F-FI-7, and qualifies this paragraph's third
property to the reasons the predicate or the enumerated classes cover.)*

**Where the ruling is written.** `spec/04-l1-integration.html` FI-13(1) (the modes and the per-transaction
walk), FI-13(3) (the anti-manufacture and anti-void property, with the producer-set steering
edges disclosed), FI-13(4) (the void and mixed cases),
FI-13(5) (totality as a rule property) and its F-FI-3 disclosure, FI-11(2)(3)–(4) (the window walk), the
per-block duty of `CONS-01(v)`/FI-11(4) (scoped to the transaction's turn — addendum 2), and the exit
non-interaction paragraph; `spec/05-proof-statement.html` PRF-04(vi) (the turn pinned by position); and
this delta — §0 row 3, §1(c), §2's FI-11(2)(4) and FI-13, §3.3, §3.4, §6.1's F-FI-3 row, §7.1–7.2,
Appendix A and Appendix B rows 25–28. The addendum above writes the precedence at the same places (FI-13(1), FI-13(4), FI-13(5),
FI-11(2)(4), PRF-04(vi), and FI-12(6)'s over-bound sentence), and Appendix B rows 27–28 record the
overlaps it closes. The immutable half of FI-13(2) is kept as a record-level void ground: a transaction that can
never be executed from the record's own bytes — any one of the exhaustive classes FI-13(1)(b)
enumerates, of which the chain id is one — is not discharged at a turn but voids the record
(FI-13(1)(b), FI-13(4)), so the walk stays total over both halves of the forceability predicate.

**F1 — the byte-invalid limb's decision classes are enumerated (review round 3, partition-and-proof).**
The limb was stated by example ("for example its chain id does not match FI-13(2)(iii)"), so a guest
implementation that checked only the chain id left a transaction that is byte-invalid for another reason
— a byte string that does not decode under PRF-07(0), an unrecoverable signature, or a declared gas
limit below the intrinsic gas of its own data — neither executed nor discharged, and FI-11(3)(c)
rejected every proof in the window until the record was dead. The classes are now enumerated in
FI-13(1)(b) and named identically in PRF-04(vi): decode failure (FI-13(2)(i)), chain-id mismatch
(FI-13(2)(iii)), an unrecoverable signature, and a declared gas limit below the transaction's own
intrinsic gas. Every class is decided by the record's published byte string, the registered constants
and the chain id — no L1 state, no producer input, no oracle — and the nonce and balance tests of
FI-13(2)(iv)–(v) are deliberately not in the list: they are not byte-decidable and are the discharge
ground of FI-13(1)(a). Written at `spec/04-l1-integration.html` FI-13(1)(b) and FI-13(4),
`spec/05-proof-statement.html` PRF-04(vi), and this delta's §2 FI-13(1)(b) and (4).

**Closed with the predicate tightening of `04-coordination.md` §5:** the two classes that repair added — the
intrinsic-gas floor and signature recovery — are part of the forceability predicate itself
(FI-13(2)(ii)/(iv)), so a below-intrinsic-gas or unrecoverable-signature transaction is not forceable
either; the per-block duty and the walk agree by construction, not only through the void limb, and no
transaction exists that FI-13(2) calls forceable but which no valid block can carry **for a reason the
predicate or the enumerated classes cover** — the unqualified form was false and is superseded by RC-6
below, because the fee cap was missing.
 
**RC-6 — the owner's ruling on review round 4's Critical F1: the fee seam is closed with a registered fee floor, not with the live base fee.**

The round-3 repair added the intrinsic-gas floor so that no transaction is forceable that no valid block can carry *on gas grounds*, but it left the **fee cap** out of both the forceability predicate and the void classes. A well-formed self-signed transaction with `maxFeePerGas = 0` (or 1 wei), nonce equal to the sender's at its turn, a balance covering its declared charge `gasLimit × maxFeePerGas + value`, gas at or above the intrinsic floor, a matching chain id and a recoverable signature was therefore: not dead; not over-bound; in none of the classes (A)–(D); and at its turn **not discharged**, because FI-13(1)(a)'s discharge ground then had exactly two conditions — the nonce is unequal, or the balance is below `gasLimit × maxFeePerGas + value` — and neither held. *(correction: this count records the ground as it stood when the finding was made; RC-7's S-01 and S-02 add the sender-code (EIP-3607) and no-room grounds, so FI-13(1)(a) now carries four discharge conditions.)* The walk called it executable and FI-11(4)/PRF-04(vi) demanded it appear, while no valid block can carry it: the L2 charges the execution base fee, and an Ethereum-equivalent block — and the guest's own re-execution — reject a transaction whose fee cap is below the base fee. **Attack trace.** (1) The attacker signs such a transaction with `maxPriorityFeePerGas = maxFeePerGas = 0` (or 1 wei), value 0 and a balance that trivially covers the declared charge. (2) The attacker publishes the record; the contract stores the payload unvalidated (DA-07, permissionless). (3) After `FI_INCLUSION_DELAY` the record is due, live and not dead, and no limb of FI-13(1)(b) applies. (4) At the transaction's turn the walk finds the nonce equal and the balance sufficient, so it is not discharged and must execute. (5) No valid block can include it while its cap is below the base fee, and no registered rule makes the base fee fall to that cap. (6) The position is thus unresolvable while the record is live; once the frontier reaches it every proof in `[c, c + R)` is rejected — `R` is computed, not chosen, and FI-11(3)(a)'s advance is unconditional — so `land` can never succeed and settlement freezes chain-wide until the record dies at `T_PROVE_DEADLINE`, repeatable with one publication per cycle and no key, stake or producer cooperation.

**The fix, written in place.** (a) FI-13(1)(b) gains a **fifth exhaustive byte class (E)**: a transaction whose declared `maxFeePerGas` is below the registered floor `FI_MIN_EXEC_FEE_CAP` is void while live, decided from the record's own bytes and one registered constant, with no L1 state, producer input or oracle. (b) FI-13(2)(vi) carries the same floor in the forceability predicate, so the predicate, the void classes and the per-block duty all agree that a below-floor-cap transaction is never forceable. (c) `spec/09` registers `FI_MIN_EXEC_FEE_CAP` with its unit, owner rule and unmeasured tag, together with the **Open premise F-FI-7** — the floor is at or above the maximum execution base fee the L2 fee schedule can produce — recorded as the capacity relation's gas-schedule premise is (F-FI-1), with the falsifier that a schedule exceeding the floor makes a transaction demanded that no valid block can carry, i.e. this same Critical again. The three claims this finding names are corrected at the same time: FI-13(2)'s 'no transaction exists that (2) calls forceable and no valid block can carry' now reads '...for a reason this predicate or the enumerated classes cover', CONS-01(v)'s 'a transaction this clause demands is one a valid block can carry' likewise, and the `spec/09` row's 'the two checks agree on a transaction no valid block can carry' likewise.

**The alternative was rejected.** Extending the discharge ground to the block's actual base fee would reopen R6-D12-05: a producer can push the base fee up with block contents, so the verdict would be producer-steerable. The floor is therefore a function of the record's own bytes plus one registered constant, exactly as the intrinsic-gas floor already is.

**The superseded forms MUST NOT be restored.** A forceability predicate or void list without the fee-cap floor; a 'no valid block can carry' claim stated without the reasons the predicate or the classes cover; and a discharge ground read from the live base fee. Written at `spec/04-l1-integration.html` FI-13(1)(b)(E), FI-13(2)(vi), FI-13(2)'s corrected sentences and the FI-11(4) quotation; `spec/02-consensus.html` CONS-01(v); `spec/05-proof-statement.html` PRF-04(vi); `spec/09-parameters.html` the new `FI_MIN_EXEC_FEE_CAP` row, the reworded `FI_RECORD_GAS_MAX` row and the measurement line; `spec/index.html` the FI-13 and LIM-01 rows; and this delta (§0 rows 3 and 9, §1(c), §2's FI-13, §6.1's F-FI-7, §6.4 item 4, §7.1–7.5, Appendix A's CONS-01(v) and FI-13 rows, and Appendix B row 29).

**The record-level ground MUST NOT be restored.** The superseded forms are: FI-13(1)(a)'s requirement
that **all** of the record's transactions appear, FI-13(4)'s "a record none of whose transactions is
forceable at any block's pre-state in the batch is void", and the F-FI-3 sentence "a record voided in
this batch may become forceable later; the remedy is re-publication". A later reader who restores any of
them restores the Critical. Discharge is not a censoring instrument: it never removes the duty to
execute a transaction that can execute at its turn.

**RC-7 — the owner's ruling on review round 4's mechanism findings S-01, S-02 and S-03.**

**(a) S-01 — the byte-decidable EIP validity conditions, and what is left.** The round-3 repair enumerated the intrinsic-gas floor, and RC-6 added the fee-cap floor, but two further byte-decidable conditions make a transaction uncarryable by every valid block: a declared `maxPriorityFeePerGas` above the transaction's own `maxFeePerGas` (EIP-1559 — a malformed fee market is a property of the transaction's own bytes) and a create transaction whose declared initcode exceeds the EIP-3860 initcode size cap (its own bytes; the intrinsic-gas floor prices initcode per word without capping it). FI-13(1)(b) gains classes **(F)** and **(G)** and FI-13(2) gains the matching predicate clauses **(vii)** and **(viii)**, so the predicate and the classes agree exactly as the intrinsic-gas floor already did. EIP-3607 (a sender with code) is **not** a byte class: it is L2 state, decided at the turn from the batch's own execution, so it joins the discharge ground of FI-13(1)(a) alongside the nonce and the balance — and the duty's scoping sentence now inherits the discharge grounds, not the bare predicate, so the two checks still agree. The base-fee dimension stays RC-6's registered floor with its Open premise F-FI-7; no live base-fee input enters the discharge ground, so R6-D12-05's producer steering is not reopened. The three former "no valid block can carry" claims are corrected at the same time: FI-13(2)'s now reads "...for a reason this predicate or the enumerated classes (A)–(G) cover, and none at all within that enumeration under the Open fee-schedule premise", CONS-01(v)'s reads "a transaction this clause demands is one a valid block can carry for a reason the predicate or the enumerated classes (A)–(G) cover", and the `spec/09` row's version likewise. **The residual is stated as an Open, not re-asserted:** a predicate over the record's bytes and the turn pre-state cannot rule out a reason that depends on neither — carried as **F-FI-8**, falsified by a transaction that (2) calls forceable and (1)(a) does not discharge at its turn, yet no valid block of the range can carry it.

**(b) S-02 — the tail turn and the mirrored discharge.** The turn of a transaction that does not appear and has no later appearing transaction of its record was "the pre-state at the end of the batch's execution", a pre-state of no block, so the walk demanded what no block-level duty could compel. It is now pinned to **the state the batch reaches after the record's last earlier appearing transaction** — a state of a real block, where the duty of `CONS-01(v)`/FI-11(4) fires (the range's last block's final state when that transaction is its last) — superseding the S-02 repair's immediately-before-the-last-block form, on which a producer that placed an earlier transaction of the record in the last block had the later transaction read before that earlier transaction executed (RC-8); when the record's last transaction appears in that block, the first case applies and its turn is immediately before its own position, as before. The walk gains the mirrored discharge ground: a transaction that does not appear is discharged at its turn when **no block of the range at or after the turn had room to carry it** — the block's own remaining gas at the turn, the same quantity the duty reads — so the duty compels a block with room and the walk discharges only a transaction no block with room could carry: one predicate, the same rule as round 3's turn scoping. A producer can omit a transaction forceable at its turn only by leaving the block at that turn without room for it — filling blocks, the disclosed cost dimension of F-FI-2/F-FI-4 — and a block that had room and omitted it is a breach under `CONS-01(v)`.

**(c) S-03 — the record's one object.** A publication record's published byte string is pinned in DA-07(1) as the batch payload of PRF-07(0) — the framed block payload of the record's own claimed range — never a bare transaction list and never a second object behind a flag; the record's transactions are the transactions of its frames' block bodies, recovered in frame order, at most `FI_MAX_TX_PER_RECORD`, with `FI_ITEM_MAX_BYTES` bounding the payload. FI-13(2)(i), FI-13(1)(b)(A) and the `spec/09` `FI_ITEM_MAX_BYTES` and `FI_MAX_TX_PER_RECORD` rows now read that same object, so the walk's transaction recovery is pinned and no reader has to guess which object a record carries.

**RC-8 — the owner's ruling on the S-02 edge: the tail turn is pinned after the record's own earlier-appearing transactions, not immediately before the last block.**

The S-02 repair (RC-7(b)) pinned the turn of a transaction that does not appear and has no later appearing transaction of its record to the pre-state immediately before the last block of the range's body. That pin is a stale read when the record's own earlier-indexed transaction appears in that last block: at the later transaction's turn the earlier sibling has not executed, so its nonce and balance effects are not yet visible. **Edge case.** Record `[s, t]`, `s` earlier-indexed, `s` appears in the last block, `t` does not appear at all. Under the RC-7(b) pin `t`'s turn is the pre-state before the last block, where `s` has not run: with `s` carrying the sender's next nonce and `t` the one after it, `t` is "nonce ahead" there and is discharged even though `s`'s execution in that same block made it executable — omission **without filling blocks**, which contradicts the rule's own claim that a producer can omit a forced transaction only by filling blocks at or after its turn; with `s` and `t` sharing a nonce, `t` is forceable at that pin, so the per-block duty demands it while the walk cannot resolve it — an unsatisfiable-for-that-batch duty of the same class as this increment's Criticals. A compliant batch still exists (place `s` earlier: `t` is then discharged at its turn because the nonce is consumed), so the totality and no-halt argument stands; what was not exact was the omission claim, not the totality. **The fix, written in place.** For a transaction that does not appear and has no later transaction of the record appearing, the turn is the state the batch reaches immediately after the record's last earlier transaction that appears in the range has executed — the pre-state of the next transaction the batch executes, or the initial pre-state of the next block of the range when it executes none after it, or, that transaction being the last transaction of the range's last block, the state that block's body ends in, at which that block's own remaining gas is read. No earlier transaction of the record can then execute after the turn, so a producer cannot place a sibling in the last block and have the later transaction discharged on a state from before that sibling's effect. The pin is a state of a real block of the range (the block holding the last earlier appearing transaction; the range's last block's final state when that transaction is its last), and the per-block duty reads the same state: its state set is now every state a block's execution reaches — each pre-state and, for the range's last block, the state its body ends in — so the duty and the walk still share one turn and the same remaining gas. The omission-by-filling claim is now exact: a transaction forceable at its turn can be discharged only where its block at that point had no room for it, the disclosed fill cost of F-FI-2/F-FI-4. **The same-nonce shape `[s, t]` resolves.** With `s` in the last block and `t` omitted, `t`'s turn is after `s`, so its nonce is consumed there and it is discharged: the walk and the duty agree (the duty does not demand a transaction that cannot execute at its turn), and the batch resolves with `s` executed and `t` discharged; the alternative presentation (`t` appears, `s` omitted) is refused on both sides consistently, because `s` is forceable at its turn before `t` and the block must have no room for it there. **Totality is unaffected.** The turn remains a function of the record's own order and the batch's own executed payload alone, the walk still executes or discharges every transaction at its turn, the three modes still partition, and the compliant batch of FI-12(5)/FI-13(5) still exists. **Where RC-8 is written.** `spec/04-l1-integration.html` FI-13(1)(a) (the turn and the room ground), FI-13(5) (the totality sentence), FI-11(4) (the verbatim quotation and its note); `spec/02-consensus.html` CONS-01(v) (the turn, the duty's state set and the follow-up note); `spec/05-proof-statement.html` PRF-04(vi) (the turn, the room ground and the follow-up note); `spec/index.html` the FI-11 row; and this delta (§0 row 3, §2's CONS-01(v) and FI-13, §3.2, RC-5 addendum 2's note, RC-7(b), Appendix B row 33, and the closing paragraphs). **The superseded forms MUST NOT be restored.** A tail turn at the pre-state immediately before the last block of the range's body — the RC-7(b) form — and any reading in which an earlier-indexed transaction of the record that appears in the last block is not yet executed at the later transaction's turn, or in which the per-block duty does not read the range's last block's final state when a turn falls there.

**Where RC-7 is written.** `spec/04-l1-integration.html` DA-07(1), FI-13(1)(a)–(b), FI-13(2)(i), (vii)–(viii) and the corrected claims, FI-13(3), FI-13(5), FI-11(4); `spec/02-consensus.html` CONS-01(v); `spec/05-proof-statement.html` PRF-04(vi); `spec/09-parameters.html` the `FI_ITEM_MAX_BYTES`, `FI_RECORD_GAS_MAX` and `FI_MAX_TX_PER_RECORD` rows and the censorship row's falsifier list; `spec/index.html` the FI-10, FI-11 and FI-13 rows; and this delta (§0 rows 3 and 9, §2's FI-11 and FI-13, §3.2, §6.1's F-FI-8, and Appendix B).

**The superseded forms MUST NOT be restored.** A tail turn at "the end of the batch's execution"; a tail turn at the pre-state immediately before the last block of the range's body, on which an earlier transaction of the record that is placed in that block has not yet executed (RC-8); a duty that compels a transaction no block of the range at or after its turn had room for; a walk that demands a transaction the per-block duty excuses; an unqualified "no valid block can carry" claim; a predicate or void list without the fee-order and initcode classes; a discharge ground read from the live base fee; and a record object that is not DA-07(1)'s PRF-07(0) payload; and an index-order condition that is proof-only, or a consensus rule that leaves the inclusion order of a record's transactions to the producer — the block-validity order requirement of `CONS-01(v)`/FI-11(4) is what closes the inclusion-side halt (R4R4-NR-01).

*Owner decisions 1–6 above are unchanged by these corrections; RC-1 … RC-4 reconcile the delta's clause
text with the ratified, implemented rules and 09's register row, and RC-5 is the design owner's ruling
on review round 1's Critical R4R1-M-01: it corrects §2's FI-13 text in place, so a later reader cannot
restore the record-level ground, the old F-FI-3 wording, or the superseded mode-precedence forms its
addendum names; RC-6 is the design owner's ruling on review round 4's Critical F1 (the fee seam): it extends §2's FI-13 text in place with the fifth byte class of (1)(b)(E) and the predicate floor of (2)(vi), registers the fee floor's Open premise F-FI-7, and qualifies the 'no valid block can carry' claims to the reasons the predicate or the classes cover. RC-7 is the design owner's ruling on review round 4's mechanism findings S-01, S-02 and S-03: it adds the byte-decidable fee-order and initcode classes (1)(b)(F)–(G)/(2)(vii)–(viii) to the predicate and the void limb, puts EIP-3607 and the mirrored no-room escape in the discharge ground of (1)(a), pins the tail turn immediately before the last block of the range's body, and pins the record's object and framing in DA-07(1); **RC-8** subsequently supersedes that tail pin with the state the batch reaches after the record's last earlier appearing transaction, because a sibling placed in the last block left the later transaction judged on a pre-state from before the sibling executed (the S-02 edge). RC-5 addendum 2's closure argument is corrected in place (review round 4, R4R4-NR-01): it assumed the batch contains only the transactions the walk executes, and the block-validity order requirement of `CONS-01(v)`/FI-11(4) now enforces that assumption, so including a nonce-descending record's transactions in their only executable order makes the block invalid instead of the range unprovable. A later reader MUST NOT restore a predicate or void list without the fee-cap floor, an unqualified 'no valid block can carry' claim, a discharge ground read from the live base fee, or any superseded form RC-7 or RC-8 names.*
