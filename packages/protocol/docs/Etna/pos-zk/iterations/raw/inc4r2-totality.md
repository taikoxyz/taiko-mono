# Increment 4 round 2 — is the new resolution ground total?

**Reviewer:** r6-gov-generations (task-45), independent adversarial reviewer.
**Snapshot:** `ba0bb3532` (`git rev-parse HEAD`; working tree clean). All quotations are from the snapshot
(`git show ba0bb3532:…` where it matters). **Angle:** attack the round-1 Critical's repair — per-transaction
resolvability — and try to make any published record pin the frontier for even one batch.
**Method:** the specification is authoritative; the round report and the Lead's closure list are claims.
Citations: `NN:line` = `spec/NN-*.html` at the snapshot; `R1` = `iterations/raw/inc4r1-mechanism.md`.

**Counts: Critical 1 · High 0 · Medium 0 · Low 0.**
**Verdict: the round-1 Critical is NOT closed in the artifact.** The resolution walk at `ba0bb3532` is still
the three-mode walk of round 1, with the same non-total ground: no per-transaction resolvability, no
"discharged at its turn", nowhere in `spec/04` FI-11/FI-13, `spec/05` PRF-04(vi), `spec/09`, `D-18`,
`increments/04-forced-inclusion-design.md`, the register or the course pages — and a pickaxe search across
**all** commits finds no such text anywhere in the repository. The poison-record attack therefore reproduces
verbatim, and three further adversarial record shapes break the same way (R4R2-T-01). The other four
closures this round reports (the `paramVersion = 2` claim, the register preamble, the migration initialiser
and the genesis settlement pair, and the disproved `ForcedViewStale` item) are **real and verified**. The
increment is not safe to ship and this round is not clean; the fix must land in the artifact first.

---

## Finding R4R2-T-01 — Critical: the round-1 resolution hole is still live — the walk is not total, and no per-transaction discharge exists in the artifact

**Severity: Critical.** One-line rationale: at the snapshot a position resolves iff **(a)** the record is live
and **all** of its transactions appear in the batch's executed payload, **(b)** it is over-bound **or none of
its transactions is forceable at any block's pre-state in the batch**, or **(c)** it is dead — so a live
record with at least one forceable and at least one never-forceable transaction (or whose transaction was
forceable at an earlier pre-state of the batch and is not executable later) is neither executed, void nor
dead, the proof is invalid (FI-13(5)/FI-11(3)(c)), and because the window `R = min(d(A) − c,
FI_MAX_PER_BATCH)` is computed and **every** position in `[c, c + R)` must be resolved, **no batch can land
while that record is in the window and live** — the same permissionless, repeatable, chain-wide settlement
halt round 1 reported. The round-2 closure describes a per-transaction discharge ground ("executing the
record's transactions in the record's own order, each transaction either executing or being discharged as
non-executable at its turn"), and **that rule does not exist in the artifact**.

**File + rule id (all at `ba0bb3532`, all unchanged from round 1).**
- `04:740` (**FI-13(1)**): "A position j is resolved by a batch iff exactly one of: **(a) executed** — the
  record at j is live at A and **all of its transactions** appear in the batch's executed payload, each
  exactly once, in increasing transaction index within the record …; **(b) void** — the record at j is
  over-bound or non-forceable under (2)–(3); or **(c) dead** …".
- `04:740` (**FI-13(4)**): "A record above any registered bound, **or one none of whose transactions is
  forceable at any block's pre-state in the batch**, is void".
- `04:740` (**FI-13(5)**): "A record that is neither executed, void nor dead cannot be passed:
  FI-11(3)(c) makes the proof invalid."
- `04:736` (**FI-11(2)(4)**): "require that **every position in `[c, c + R)`** is resolved under FI-13's three
  modes, and recompute `c' = c + R`."
- `05:271` (**PRF-04(vi)**): "It MUST require that every position in `[c, c + R)` is resolved under
  FI-13(1)'s three modes — executed (**all** of the record's transactions in the batch's executed payload,
  each exactly once …), void (the record is over-bound or non-forceable under FI-13(2)–(3) …), or dead …".
- `DECISIONS.md` **D-18**: "the walk that resolves every position in `[c, c')` as **executed**, **void** or
  **dead**" — no per-transaction discharge. The delta's FI-13 (`increments/04-forced-inclusion-design.md`,
  FI-13(1)–(5)) has the same three-mode text.
- **Evidence that the described fix is absent repo-wide:** `git log --all -S'discharged as
  non-executable'` and `-S'resulting nonce'` return no commit; `grep -rn` over
  `packages/protocol/docs/Etna/pos-zk/` for `own order`, `discharged as`, `resulting nonce`,
  `non-executable`, `unaffordable`, `at its turn`, `executed or discharged` finds no rule text (only the
  unrelated senses of "discharge" in `learn/` and the old FI-13(5) heading "The discharge is bounded").
- **Missing rule:** the totality ground itself — a per-transaction resolution: for position `j`, walk the
  record's transactions in the record's own order, execute each one that the batch's own payload executes,
  and discharge each one that is non-executable **at its turn** (its nonce not equal to the account's
  resulting nonce at that point, or its declared maximum charge not covered by the account's balance then),
  with the position resolved once every one of its transactions has executed or been discharged. Two
  details the landed text must also fix, or the hole resurfaces in a different shape: (i) the "none of whose
  transactions is forceable" ground must go — it is what makes a mixed record unresolvable; and (ii) the
  anchor "forceable at **any** block's pre-state in the batch" must go — a transaction that was forceable at
  the batch's first pre-state and became non-executable later (the F-FI-3 case) is currently **not** void and
  **not** executed, which is unresolvable by itself.

**Assumptions.** None beyond the published rules: publication is permissionless (DA-07), the payload is the
publisher's choice, and the resolution walk is deterministic over the register at `A` and the batch's own
payload. No producer, validator, prover or L1 behaviour is assumed adversarial beyond what the fault model
already contains.

**Concrete attack trace.**
1. *Crafted record (round-1 attack, verbatim).* Publish a payload with two transactions: `t1` = a valid
   transaction of the attacker (nonce equal to its current nonce, balance covering
   `gasLimit × maxFeePerGas + value`) and `t2` = any signed transaction whose declared nonce is
   unreachable (e.g. current + 10^6). The payload is within `FI_ITEM_MAX_BYTES` and
   `FI_MAX_TX_PER_RECORD`; both gas limits are within `FI_RECORD_GAS_MAX`; so the record is not
   over-bound. At every pre-state of every batch, `t1` is forceable and `t2` is not: the record is not
   "none forceable" (so not void under FI-13(4)), mode (a) needs `t2` executed (impossible), mode (c) needs
   the record dead (false while live). The proof is invalid — FI-13(5) — and since the position is inside the
   computed window once the frontier reaches it, no `land` succeeds until `A ≥ l1BlockNumber +
   T_PROVE_DEADLINE`. One publication freezes settlement; one per deadline period sustains it.
2. *Shared nonce.* A record whose two transactions carry the **same** nonce (a replacement pair, or two
   conflicting transactions of one account): both are forceable at the batch's first pre-state, only one can
   execute, the other never can — mixed, and by 1's argument unresolvable. The same holds for two records of
   one sender published together with conflicting nonces: the second record's transaction was forceable at an
   earlier pre-state, so it is not "none forceable", and it cannot be executed after the first — the second
   record is unresolvable.
3. *Unaffordable first transaction.* A record `[t1, t2]` where `t1`'s declared maximum charge exceeds its
   sender's balance at every pre-state but `t2` (same or another sender) is affordable: `t2` is forceable,
   `t1` can never execute — mixed, unresolvable. (Only if **every** transaction is unaffordable is the
   record void.)
4. *Producer- or sender-supplied replacement inside the resolving batch.* The record holds `t` (nonce `n`);
   the sender has also signed `t'` with the same nonce (an ordinary speed-up/cancel replacement), and the
   batch that must resolve the record includes `t'`. `t` was forceable at the batch's first pre-state, so
   the record is not "none forceable"; once `t'` executes, `t` can no longer execute; mode (a) fails →
   invalid proof. Unlike 1–3 this needs no crafted record at all: the attacker can self-supply the
   replacement and price it attractively, or a single Byzantine producer with one user's replacement in its
   mempool can produce a certified range that no prover can prove — a settlement halt from one producer slot.
   At the L2 level the certified blocks exist; only settlement stops, which is exactly the HALT-03 class.
5. *Consequences.* No checkpoint advances, the chain halts at the unsettled-depth cap, no new withdrawal root
   can form, and repeatability is one publication per `T_PROVE_DEADLINE` (or one replacement transaction per
   batch for the producer variant), all inside the fault model and at gas cost only.

**Other constructions on the charged list, and what they show.**
- *Executable only through a later record's execution* (record `j = [t(n+1)]`, record `j+1 = [t'(n)]`): the
  batch may execute `t'` and then `t`, so both appear in the executed payload and `j` is resolved as
  executed — **no hole**. This is also the case a per-transaction walk must not discharge: a transaction that
  is non-executable at the batch's first pre-state but executable later, after a later record's transaction,
  must be executed, not discharged, or the "totality" fix would skip includable transactions.
- *Empty transaction list*: PRF-07(0) decodes "at most `FI_MAX_TX_PER_RECORD`" transactions, so zero is
  admissible; all zero of them "appear in the executed payload" vacuously (or the record is void under the
  "none forceable" ground, also vacuously). Either reading resolves it — **no hole**, though the landed text
  should say which.
- *Exact deadline boundary*: live is `l1BlockNumber + T_PROVE_DEADLINE > A`, dead is `≤ A` — a strict
  partition with no gap and no double count, and `A` is a verified, Ethereum-final, age-bounded anchored
  view, so neither side can be moved — **no hole**.
- *Transaction count or byte size exactly at the bound*: the bounds are "at most", so a record exactly at
  `FI_MAX_TX_PER_RECORD` transactions / `FI_ITEM_MAX_BYTES` bytes is forceable, not over-bound — **no hole**.
- *Two records for the same sender published together*: with distinct, increasing nonces both are executable
  in order — **no hole**; with conflicting nonces see construction 2 — **hole**.
- *Can a producer cause a discharge for someone else's transaction by ordering or inclusion?* It cannot
  *void* another's record that way (FI-13(4)'s "none forceable" ground blocks it), but it can make it
  **unresolvable** by including the sender's own competing transaction in the same batch (construction 4) —
  which is strictly worse than a discharge. The discharge decision is therefore **not** independent of the
  producer's choices: the producer's inclusion decides between "void" (the transaction non-forceable at every
  pre-state) and "invalid proof" (forceable at the first pre-state, non-executable later).
- *Can a sender discharge their own record repeatedly to deny another sender (a new F-FI-2 route)?* Not a new
  route: void records occupy register positions and the frontier drains at most `R = min(backlog, cap)` per
  accepted batch, so `K` front-loaded void records delay a later record by about `K / FI_MAX_PER_BATCH`
  batches at one publication per position — this is F-FI-2's disclosed class, and D-18 already discloses
  front-running re-publications at roughly one publication per deadline window. What the sender *can* do
  under the current text is construction 1/3: one poison record halts everyone, which is not a latency trade
  but a halt.
- *Is the walk total for the FIRST position as well as the last, and across a reorg?* The first position `c`
  is treated by the same three modes with no special case, so a poison record at `c` halts the frontier at
  its first step; the last position behaves identically. A reorg does not repair it: the register and the
  walk ride the reorged L1 state, a reorged `land` undoes its checkpoint and settlement record, and the
  poison record persists unless its own publication block is reorged out — so the halt survives the reorg
  that spawned it.

**Fault-model verdict.** Inside. No assumption fails: any account can publish (DA-07), the payload is its
own, the resolution walk is deterministic and reads only the register at `A` and the batch's own payload,
and construction 4 needs one Byzantine producer slot (or one attacker-priced replacement transaction).
**Attacker cost.** One L1 publication (constructions 1–3; repeatable once per `T_PROVE_DEADLINE`), or one
ordinary replacement transaction plus the producer's inclusion (construction 4).
**Requirement affected.** FI-12(5)'s no-halt claim; FI-11(3)(c); **D-12** and **D-18**'s fixed decision that
the narrow obligation must not halt the chain; the increment's convergence claim; F-FI-3's accuracy.
**Evidence.** `04:736` (FI-11(2)(4)), `04:740` (FI-13(1)/(4)/(5)), `05:271` (PRF-04(vi)), D-18,
delta FI-13; the repo-wide search above (no per-transaction discharge exists in any commit).
**R1 cross-reference.** `inc4r1-mechanism.md` R4R1-M-01 — same rule ids, same trace; the round-2 change
described by the Lead is not present at `ba0bb3532`.

---

## Closures this round claims that I verified as real

- **R4R1-M-02 (FI-12's `paramVersion = 2` claim) — closed.** `04:738` now reads: the capacity relation's
  value "is bound by **the anchored L1 view the proof already fixes** — no config preimage commits it, no
  enumeration changes, and no new `paramVersion` and no new preimage is introduced; PRF-02(5)'s live
  (version-3) field list is untouched, and the historical `paramVersion = 2` enumeration is valid only for
  an epoch already entered under it and MUST NOT be used for a new epoch." This matches `coord §3` and
  `09:195`. ✓
- **R4R1-M-03 (settlement pair's home) — closed.** `08:422` initialises "nextSeq = 0 and pruneCursor = 0 —
  the register's whole mutable clock; no deleted due-queue field is initialised"; `08:405` writes the genesis
  checkpoint with `anchoredL1Block: uint64(block.number)` (= `L1_0`) and the derived `settledCount = 0`
  (`08:389`–`409`, closing MIG-02's (264) row leftover); the pair rides the L1-07 record and MIG-02's
  15 declarations / 28 gap slots are unchanged. ✓
- **Register preamble / `FI_PREFIX_CAP` — closed.** `09:191` registers "FI_PREFIX_CAP (withdrawn
  spelling) … MUST NOT be used. The former spelling of the canonical `FI_MAX_PER_BATCH`, which is live again
  with its unit fixed to positions per batch"; the FI set is otherwise live. ✓
- **Round-1 "ForcedViewStale not declared" — correctly disproved.** `04:429` declares
  `error ForcedViewStale(uint64 anchoredL1Block, uint256 landingBlock)` for FI-11(3)(e); no change was
  needed. ✓
- (The deferral-count and converged-state-record corrections (`CONVERGENCE.md`, delta status, F3) are outside
  my angle; I did not re-derive them.)

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 1 | R4R2-T-01 (the per-transaction resolution ground is absent from the artifact at `ba0bb3532`; the round-1 poison-record halt reproduces, with three additional record shapes and a producer/replacement route) |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |

**Strongest attack: R4R2-T-01.** The artifact still resolves by "all transactions executed, or none
forceable, or dead". A record with one forceable and one never-forceable transaction (a far-nonce
transaction; two transactions sharing a nonce; an unaffordable first transaction; or simply a record whose
transaction a producer makes non-executable mid-batch with the sender's own replacement) is none of the
three, so every proof that must resolve it is invalid and settlement stops chain-wide until it expires —
exactly round 1's finding, still live. Before writing this I checked the FI-13/FI-11/PRF-04(vi)/D-18/delta
text at `ba0bb3532`, the working tree, and every commit searchable by pickaxe for the described phrasing:
the per-transaction discharge rule is nowhere in the repository.

**Is the increment safe to ship?** **No, and this round is not clean.** The increment's own bar is two
consecutive rounds with no Critical and no High; round 2 still has the round-1 Critical. The fix described by
the Lead — per-transaction resolvability in the record's own order with discharge at each transaction's turn
— must actually land in `spec/04` FI-13 (and be reflected in FI-11(2)(4), PRF-04(vi), D-18, the delta and
the course pages that describe the walk), and it must remove both "none of whose transactions is forceable"
and the "forceable at any block's pre-state" anchor, or the hole returns in the F-FI-3 shape; after that a
round is needed to confirm totality, with the constructions above as the test set. Everything else this
round claims to have closed is real, and the rest of the mechanism survived round 1 unchanged.
