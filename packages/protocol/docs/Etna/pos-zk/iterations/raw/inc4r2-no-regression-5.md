# Increment 04 — round 2: no-regression

Snapshot `ba0bb3532`. Read: `iterations/raw/inc4r1-*.md` (all four round-1 reports), the current
`spec/04` FI-10..FI-14, `spec/05` PRF-04(vi), `DECISIONS.md` D-12/D-16/D-18, `CONVERGENCE.md`,
`DEFERRED.md`, `increments/04-*`, `spec/09`, `index.html`, all 14 course pages, and a rule-level
comparison of the round-1 and round-2 snapshots (`git show 169480a56:…`).

**Severity counts: 1 Critical, 0 High, 0 Medium, 0 Low. The increment is NOT clean and NOT safe to
ship: the round-1 Critical (R4R1-M-01) is not fixed in the artifact — the per-transaction resolution
ground the closure describes appears nowhere in the specification, the decision record, the design
delta, the register, the index or the course, and `FI-11` and `FI-13` are byte-identical to the
round-1 snapshot.**

(Independent corroboration: the round-2 report `iterations/raw/inc4r2-proof-enforcement.md` reaches the
same conclusion from the proof-enforcement angle, with the same byte-identical evidence. My finding
below is derived from my own rule-level comparison and artifact-wide search and stands on its own.)

---

## R4R2-NR-01 — Critical — the total per-transaction resolution walk does not exist anywhere in the artifact, so the round-1 settlement-halt attack still lands verbatim

*Rationale: the closure says a position now resolves by executing the record's transactions in the record's own order, each executing or being discharged as non-executable at its turn. No such rule, predicate, guest clause or teaching exists in this snapshot: the resolution modes are the same three non-total ones the round-1 Critical falsified. One permissionless publication therefore still pins the computed window and invalidates every proof chain-wide until the record's deadline.*

- **File + rule id (round-2 snapshot).** `spec/04-l1-integration.html`, **FI-13(1)**: "(a) **executed** — the
  record at j is live at A and **all of its transactions appear** in the batch's executed payload, each
  exactly once, in increasing transaction index within the record …; (b) **void** — the record at j is
  over-bound or non-forceable under (2)–(3); or (c) **dead** …"; FI-13(4): "A record above any registered
  bound, **or one none of whose transactions is forceable at any block's pre-state in the batch**, is
  void"; FI-13(5): "A record that is neither executed, void nor dead cannot be passed: FI-11(3)(c) makes
  the proof invalid." `spec/05-proof-statement.html`, **PRF-04(vi)**: "It MUST require that every
  position in `[c, c + R)` is resolved under FI-13(1)'s three modes — **executed (all of the record's
  transactions in the batch's executed payload, each exactly once, …)**, void (the record is over-bound
  or non-forceable under FI-13(2)–(3) …), or dead …". `spec/04` **FI-11(2)(4)**: "require that **every
  position in `[c, c + R)`** is resolved under FI-13's three modes, and recompute `c' = c + R`";
  **FI-12(2)**: "`R = min(d(A) − c, FI_MAX_PER_BATCH)` — the resolved count". **D-18** states the same
  non-total rule ("the walk that resolves every position in `[c, c')` as **executed**, **void** or
  **dead**", with void over the record's bytes/constants/nonce/balance), and `learn/11` teaches it
  ("Executed — all of the record's transactions appear in the batch's executed payload … nothing else
  resolves this position"; "Void — … **none of its transactions** is forceable at any pre-state of the
  batch").
- **Evidence that no fix landed.** (a) Rule-level comparison of the two snapshots
  (`git show 169480a56:…` vs the working tree): **FI-11 is byte-identical (7,950 characters) and FI-13
  is byte-identical (4,667 characters)**; the only `spec/04` rules that changed are L1-03, L1-07, L1-08
  and FI-12, and the only `spec/05` rule is PRF-02. (b) The vocabulary of the claimed fix is absent
  artifact-wide: "non-executable", "at its turn", "resulting nonce", "unaffordable", "executes or is
  discharged" return no hit in `spec/`, `learn/`, `increments/`, `DEFERRED.md` or `DECISIONS.md`;
  "per-transaction" and "own order" occur only in unrelated contexts (historical reports, DA-03's
  challenge ordering). (c) The delta's review corrections are RC-1 (the R/W forms), RC-2 (the floor),
  RC-3 (the per-block bound) and RC-4 (the anchored-view gas limit) — none touches resolution totality.
- **Assumptions.** Permissionless publication (DA-07(1)); the attacker's record is an ordinary record.
  No fault-model assumption is needed.
- **Attack trace (unchanged from round 1, and still exact).** 1. Publish one record whose decoded payload
  has two transactions: `t1` — the attacker's own next transaction (nonce equal to its current nonce,
  balance covering `gasLimit × maxFeePerGas + value`), forceable at the batch's first pre-state; and
  `t2` — any signed transaction whose declared nonce is far above its sender's current nonce, so no
  batch can make it current. Both fit `FI_ITEM_MAX_BYTES`, `FI_MAX_TX_PER_RECORD` and
  `FI_RECORD_GAS_MAX`, so the record is not over-bound. 2. Once due, `R` is computed
  (`= min(d(A) − c, FI_MAX_PER_BATCH)`) and every position in `[c, c + R)` must be resolved. 3. Mode
  (a) fails because `t2` cannot appear; mode (b) fails because `t1` **is** forceable (FI-13(4) voids
  only a record "none of whose transactions is forceable"); mode (c) fails while the record is live.
  FI-13(5)/FI-11(3)(c)/PRF-04(vi) then make **every** proof invalid, for every batch and every submitter.
  4. Settlement stops chain-wide until the record's deadline passes; re-publication repeats it at one
  publication per `T_PROVE_DEADLINE`, and v1 has no recovery path, so the halt is only cleared by
  waiting. `FI-12(5)`'s "why this cannot produce a permanent halt" is falsified as before.
- **Fault-model verdict.** Inside: a plain publisher, no assumption failure, no validator or producer
  cooperation, no L1 censorship. This is the round-1 Critical, unfixed.
- **Attacker cost.** One permissionless L1 publication (plus ordinary publication gas); repeatable once per
  `T_PROVE_DEADLINE`. The chain-wide settlement halt costs the attacker nothing else.
- **Requirement affected.** D-12's no-halt guarantee and FI-12(5); D-18's own decision text; the
  increment's own review bar ("two consecutive rounds with no Critical and no High"); FI-13's totality
  ("the three modes are jointly exhaustive" is what it must guarantee).
- **Evidence.** As above: the byte-identical FI-11/FI-13 comparison, the artifact-wide vocabulary search,
  the current quotes from FI-13(1)/(4)/(5), PRF-04(vi), FI-11(2)(4), FI-12(2), D-18 and `learn/11`.
  **Fix:** write the per-transaction resolution ground into the normative rules — FI-13(1)(a) resolves a
  position when each of the record's transactions, in the record's own order, either executes or is
  discharged as non-executable at its turn (nonce ahead of the account's resulting nonce, or the declared
  maximum charge unaffordable at that pre-state), with execution of the preceding transactions simulated;
  FI-13(1)(b)/(4) covers only a record no transaction of which can execute; PRF-04(vi) and FI-11(2)(4)
  restate the same walk; and D-18, the design delta, the register's void row and `learn/11` are aligned
  with it.

---

## Round-1 repairs that ARE present (verified)

- **FI-12(5)(ii) — the anchored-view correction (round-1 High, mine among four).** Closed: the clause now
  reads "the capacity relation reads `L2_BLOCK_GAS_LIMIT` from the anchored L1 view the proof already
  fixes — the value is bound by that view, no config preimage commits it, no enumeration changes, and no
  new `paramVersion` and no new preimage is introduced … the historical `paramVersion = 2` enumeration
  is valid only for an epoch already entered under it and MUST NOT be used for a new epoch (increment 04
  reconciliation — RC-4 …)", with the `09` PARAM-04 and `L2_BLOCK_GAS_LIMIT` rows and PRF-02(5) agreeing.
- **The register's PARAM-01 preamble (round-1 Medium, mine).** Closed: "The forced-inclusion names left
  the tombstone with the mechanism (increment 04): … are live again and registered in the rows below …
  only [`FI_PREFIX_CAP`] stays a name tombstone".
- **The settlement pair's storage home (round-1 Medium, R4R1-M-03).** Closed: L1-07's checkpoint struct
  carries `settledCount` and `anchoredL1Block` in the packed word with `l1BlockNumber`/
  `lastAcceptedBatchTime`; L1-08's `forcedSettlementAt` comment says "read from that height's checkpoint
  record … no per-height mapping"; the spec states the pair is not an input to L1-07's canonical record
  hash; `MIG-02` stays 15 consumed / 28 free.
- **The activation initialiser (round-1 Medium, INC4R1-RD-02).** Closed: "at T3 the contract MUST
  initialise `nextSeq = 0` and `pruneCursor = 0` — the register's whole mutable clock; no deleted
  due-queue field is initialised (finding F3 …)", and the genesis checkpoint carries
  `settledCount = 0`, `anchoredL1Block = L1_0` with the stated derivation.
- **`FI_MIN_DRAIN` row wording (round-1 Low) and `CONVERGENCE.md`/`delta` status (round-1 Low).** Closed:
  the row now says the floor "removes the reachable cap-of-zero of the preserved text" via the `R ≥ 1`
  clause; `CONVERGENCE.md` carries an increment note preserving the converged-state record and counting
  the deferred set by mechanism; the delta's status is "IMPLEMENTED, IN REVIEW".
- **Round-1 F2 (ForcedViewStale) is correctly retracted, not re-raised:** the error is declared at
  `spec/04` line 429 (`error ForcedViewStale(uint64 anchoredL1Block, uint256 landingBlock)` with the
  FI-11(3)(e) comment).

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (12 spec + 14 course pages) | **4,442 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 25 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | the deferred-mechanism tombstones are present (`CONS-16`, `REC-02..REC-04`, `GOV-04`, plus the live `LIM-02` flagged by the classifier's text heuristic); `FI-10..FI-14` are live; no tombstone is missing its MUST-NOT/pointer text |
| Live references to still-tombstoned names | 19 hits, all the known benign historical/withdrawal sentences |
| Course scan | 0 review-process language; no surviving "forced inclusion is deferred" claim |
| Scope | the increment-4 changes stay within the pages the revival must reach; no rule id added or removed (161); increment-2 and v1 rules unchanged except where inch 4 must touch them |

## Fault-model verdict

R4R2-NR-01 is inside the fault model: a plain permissionless publisher, no assumption failure, produces a
chain-wide settlement halt in a v1 with no recovery path. Nothing else I checked is a finding.

## Is the increment safe to ship?

**No.** The round-1 Critical is still open in the normative text; the claimed repair must actually be
written into FI-13/FI-11/PRF-04(vi) (and aligned in D-18, the delta, the register and `learn/11`), not
only described in the closure summary. Everything else in this round's residue is genuinely closed and
the mechanical surface is clean.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 1 | R4R2-NR-01 |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
