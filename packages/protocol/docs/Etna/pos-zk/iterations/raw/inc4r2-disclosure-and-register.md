# Increment 4 round 2 — disclosures and register after the fix

**Angle.** Confirm the round-1 closures are real, then attack the disclosures and the register: F-FI-3's
restatement against the new resolution semantics and whether a discharge is ever described as a censoring
instrument; F-FI-1, F-FI-2, F-FI-4, F-FI-5 and F-FI-6 still accurate and carried; the register matching the
rules (FI_MIN_DRAIN's row, the FI units, `L2_BLOCK_GAS_LIMIT` as a live anchored-view input with no
preimage change, the settlement pair riding the checkpoint record with MIG-02 still at 15 declarations and
28 free, the deferral set of three with the ratified membership); F-FI-2 open and unfixed with the
guarantee's condition and the not-a-latency-guarantee headline; and no disclosure promising more than the
rules deliver.

**Snapshot.** `ba0bb3532`; working tree at the same commit. Read first: all four `inc4r1-*` reports,
spec/04 FI-10–FI-14, spec/05 PRF-04(vi), spec/08, spec/09, spec/10, the index, CONVERGENCE.md, the delta
and D-18.

**Result: 1 Critical, 0 High, 0 Medium, 0 Low. NOT CLEAN — the increment must not ship.** The round-1
Critical **R4R1-M-01 is not closed**: the per-transaction resolvability repair described as the closure does
not exist anywhere in the artifact, and FI-13's three modes are still not jointly exhaustive, so a
permissionless publication still freezes settlement chain-wide. Four of the five other round-1 closures are
real and verified below, all of my angle's items otherwise hold, and F-FI-3 was not restated (there are no
new semantics for it to describe).

---

## INC4R2-RD-01 — Critical — R4R1-M-01 is not closed: no per-transaction resolvability exists in the artifact, so FI-13's modes are still not jointly exhaustive and one publication still halts settlement chain-wide

**One-line rationale.** The claimed closure ("a position resolves by executing the record's transactions in
the record's own order, each transaction either executing or being discharged as non-executable at its
turn") appears in no rule, no delta clause and no commit; the current FI-13 has exactly the round-1 text,
under which a live record with one forceable and one never-forceable transaction is neither executed
(FI-13(1)(a) needs **all** its transactions in the executed payload), nor void (FI-13(4): void needs a
record "none of whose transactions is forceable at any block's pre-state"), nor dead (FI-13(1)(c)) — while
FI-11(2)(4)/(3)(c) require **every** position in `[c, c + R)` to be resolved and `R = min(d(A) − c, FI_MAX_PER_BATCH)`
is computed, not chosen.

**File + rule id.**
- `spec/04-l1-integration.html` **FI-13(1)** (line 740), current text, identical to the round-1 snapshot:
  "(a) **executed** — the record at j is live at A and **all of its transactions** appear in the batch's
  executed payload, each exactly once …; (b) **void** — the record at j is over-bound or non-forceable
  under (2)–(3); or (c) **dead** — the record at j is dead at A".
- `spec/04` **FI-13(4)**: "A record above any registered bound, **or one none of whose transactions is
  forceable at any block's pre-state in the batch**, is void".
- `spec/04` **FI-13(5)**: "A record that is neither executed, void nor dead cannot be passed: FI-11(3)(c)
  makes the proof invalid", and FI-13(1)'s last sentence: "A record that was forceable somewhere in the
  batch and was not executed is (b) or invalid" — the "(b)" ground fails for a mixed record, so the
  "invalid" branch applies.
- `spec/04` **FI-11(2)(4)**: "require that every position in `[c, c + R)` is resolved under FI-13's three
  modes, and recompute `c' = c + R`"; **FI-11(3)(a)**: `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **unconditional**;
  **FI-11(3)(c)**: every position in `[c, c')` resolved.
- `spec/04` **FI-12(2)**: "`R` = `min(d(A) − c, FI_MAX_PER_BATCH)` — the resolved count, the size of the
  required window"; `spec/05` **PRF-04(vi)** (line 48) still enforces "the three modes of FI-13(1)".

**Why the closure is absent (evidence, not inference).**
1. `git log --oneline 169480a56..ba0bb3532` lists six commits — PRF-02(5) reconcile, CONVERGENCE.md
   correction, the reconciliation pass (ratified clause forms, anchored-view binding, settlement pair,
   register preamble, migration initialiser), the delta status, the activation-initialiser fix, the genesis
   pair. **None touches FI-13, the resolution walk or the delta's FI-13 clause**, and no commit message
   claims to.
2. `git diff 169480a56 ba0bb3532 -- spec/04-l1-integration.html` has three hunks only: L1-03(6)'s
   settlement record, L1-07's settlement pair, and an interface row. FI-13 is byte-identical to round 1.
3. The delta's own FI-13 clause (`increments/04-forced-inclusion-design.md` lines 408–419) is identical to
   the rule; its new "Review corrections" block contains **RC-1 … RC-4 only** (resolved count, floor,
   per-block bound, preimage), and the delta's FI-13 summary row (line 951) still reads "executed, void, or
   dead; void = over-bound or no transaction forceable at any pre-state".
4. A tree-wide search for the described semantics — `non-executable`, `in the record's own order`,
   `at its turn`, `every one of its transactions has executed or been discharged`,
   `transaction-by-transaction` — returns **nothing** in any live or design artifact.

**Assumptions.** Publication is permissionless (DA-07); no fault-model assumption is violated; the record
is inside the computed window (it is at or after `c` and due); `FI_INCLUSION_DELAY` has passed.

**Attack trace (unchanged from round 1, re-verified against the current text).**
1. The attacker publishes one record whose decoded payload carries `t1` (its own next transaction: nonce
   equal to its current nonce, balance covering the declared maximum charge) and `t2` of any account whose
   nonce is far ahead of that account's current nonce (or whose balance cannot cover it). Publication is
   permissionless and takes no bond, fee or escrow (FI-10(1)).
2. When the frontier `c` reaches that position, `R = min(d(A) − c, cap)` includes it. `t1` is forceable, so
   the record is not void under FI-13(4); `t2` can never appear in an executed payload (its nonce can never
   equal the account's nonce at any pre-state the batch can reach), so the record is not executed under
   FI-13(1)(a); it is live, so not dead.
3. FI-11(2)(4) requires every position in `[c, c + R)` resolved; FI-11(3)(a) forbids `c' = c`. Every proof
   over a range containing that position is invalid, so `land` cannot succeed and settlement stops
   chain-wide until the record is dead — `T_PROVE_DEADLINE` after publication (FI-13(1)(c) then resolves it).
4. The grief is repeatable at one publication per `T_PROVE_DEADLINE`, at no slashable cost: ECON-04(6) stays
   a tombstone and "the rejected proof is the whole enforcement" (FI-11(1), D-18).

**Fault-model verdict.** Inside the fault model: a single account with no crypto break, no key compromise,
no governance capture and no code bug can halt settlement chain-wide, repeatably. This falsifies FI-12(5)'s
no-permanent-halt argument ("Why this cannot produce a permanent halt") in the bounded-but-repeatable form
the round-1 report describes, and it breaks the increment's own hard requirement that every due record be
resolvable — the increment cannot be claimed clean while it stands.

**Attacker cost.** One L1 publication per `T_PROVE_DEADLINE` (the record must be inside the window; the
record's own gas/blob cost, `C_PUBLISH`, unmeasured) — no stake, no bond, no fee, no offence.

**Requirement affected.** FI-13(1)/(4)/(5); FI-11(2)(4)/(3)(a)/(c); FI-12(2)/(5); PRF-04(vi); the
increment's no-halt disclosure; D-18's "the obligation is total" claim for the resolution walk.

**Evidence.** `ba0bb3532` FI-13 (04:740) and FI-13(4) text; `git show ba0bb3532:…/spec/04-l1-integration.html`
vs `git show 169480a56:…`; the three-hunk diff; the delta's RC block (RC-1…RC-4 only) and its FI-13 row;
`spec/05-proof-statement.html` line 48; the four `inc4r1-*` reports' convergent finding.

---

## The four closures that ARE real (verified)

1. **FI-12(5)(ii) no longer claims the `paramVersion = 2` preimage commitment.** The clause now reads:
   "the capacity relation reads `L2_BLOCK_GAS_LIMIT` from the anchored L1 view the proof already fixes —
   the value is bound by that view, **no config preimage commits it, no enumeration changes, and no new
   `paramVersion` and no new preimage is introduced**; PRF-02(5)'s live (version-3) field list is
   untouched, and the historical `paramVersion = 2` enumeration is valid only for an epoch already entered
   under it and MUST NOT be used for a new epoch", with an RC-4 reconciliation note. `spec/09` line 195 and
   `spec/05` PRF-02(5) agree; the delta's RC-4 is the matching design text. This closes my round-1 High.
2. **The register's PARAM-01 preamble now states the live set.** `spec/09` line 20: "The forced-inclusion
   names left the tombstone with the mechanism (increment 04): `FI_INCLUSION_DELAY`, `FI_RECORD_GAS_MAX`,
   `FI_MAX_TX_PER_RECORD`, `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT`, `FI_MAX_PER_BATCH`,
   `FI_ITEM_MAX_BYTES` and the capacity relations are live again and registered in the rows below …
   **only the withdrawn spelling `FI_PREFIX_CAP` stays tombstoned** with a MUST-NOT-USE reason".
3. **The activation initialiser writes only live state, and the genesis checkpoint carries the pair.**
   `spec/08`: "at T3 the contract MUST initialise `nextSeq = 0` and `pruneCursor = 0` — the register's whole
   mutable clock; **no deleted due-queue field is initialised**" (closing my round-1 Medium), and the
   genesis literal now carries `settledCount: 0` and `anchoredL1Block: uint64(block.number)` (= `L1_0`),
   with the (264) row updated to "the ten L1-07 fields … the four packed `uint64` fields … complete one
   32-byte word, so the pair consumes no gap slot and no per-height mapping is added".
4. **CONVERGENCE.md and the delta status are corrected without rewriting the converged record.**
   CONVERGENCE.md's note now counts the deferred set "**by mechanism with its own rule id**" as the
   rotation/stall-resolution/aggregation, records increment 4 as **in review** with the same clean-round
   bar, and marks the "no inclusion obligation" sentence as the converged-state record. The delta's status
   line reads "**IMPLEMENTED, IN REVIEW** … It has NOT shipped".

Noted: round 1's F2 (`ForcedViewStale` not declared) is indeed disproved — the error is declared with its
three conditions in `spec/04` line 425 (L1-08's error block); no change was needed.

## The angle's items, verified

1. **F-FI-3 was not restated, and there are no new semantics for it to describe.** Its text is still the
   round-1 wording — delta line 658: "A record voided because no transaction was forceable in this batch may
   become forceable later — the user tops up, or the nonce that was consumed frees nothing. Remedy is
   re-publication; the void decision itself is objective and irreversible for that record";
   `spec/10` line 353: "F-FI-3 (a record voided here may become forceable later; the remedy is
   re-publication)"; `DEFERRED.md` line 62 and D-18 line 674: "(a voided record may become forceable later;
   re-publication is the remedy)"; `learn/11` line 188: "F-FI-3 — void now, forceable later". That wording
   is *consistent with the rules as written* (whole-record void), so it is not an overpromise — but it is
   not the "discharged transaction may become executable later only through the sender's own further
   transactions" restatement, because that semantics does not exist in the artifact. When the FI-13 repair
   lands, F-FI-3 must be restated then, and the anti-manufacture property must be stated for the new
   discharge ground exactly as FI-13(3) states it for void ("no producer … can make a due record void by
   choosing block contents").
2. **A discharge is never described as a censoring instrument, and the ground is stated as objective.**
   FI-13(2)/(3) keep the predicate to the record's immutable bytes, the registered constants and the two
   producer-immovable pre-state facts (nonce, balance); FI-13(1) forbids any other ground ("not a
   proposer's claim, not a validator's vote, not a DAO or operator action, not a recovery, not the record's
   own age while it is still live, and not a pruned slot"); the failure-mode line names the opposite risk
   explicitly ("a discharge rule with any subjective or unbounded ground becomes a censorship instrument").
   The one residual named for the producer's own environment is F-FI-3 (a top-up or the sender's own
   transaction consuming the nonce).
3. **F-FI-1, F-FI-2, F-FI-4, F-FI-5 and F-FI-6 are still accurate and carried wherever falsifiers are
   collected.** `spec/10` line 353 lists all six with their meanings; `spec/10` 35, 260 and 286 name
   F-FI-1/F-FI-2/F-FI-3/F-FI-4/F-FI-5/F-FI-6 and the headline; the index 397, 526 and 528 carries them;
   `DEFERRED.md` 60–66 carries all six; the delta's §6.1 table is the canonical statement; `spec/09` line
   196 tags the capacity relation "unmeasured relation (Open: F-FI-1)" and line 266 reinstates the
   measurement line including the F-FI-1 schedule check. F-FI-1 (capacity relation + schedule premise),
   F-FI-4 (expiry is a discharge, not inclusion), F-FI-5 (non-censoring L1 + at least one honest or
   rational producer) and F-FI-6 (deliberate delay past the anchor-age envelope) read exactly as the delta
   defines them.
4. **The register matches the rules.** `FI_MIN_DRAIN` (09:190) states the ratified form — "`R ≥ 1` whenever
   the outstanding obligation at A is non-empty, and because the capacity condition gives
   `cap(batch) = FI_MAX_PER_BATCH ≥ FI_MIN_DRAIN`, that is `R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a live
   record is outstanding" — and never claims the floor drives the advance; FI-11(2)(3), FI-12(2) and index
   458 match. Units are unchanged and single: `FI_MAX_PER_BATCH` positions per batch in the obligation, the
   cap, the frontier bound and the capacity relation (09:189, FI-12(1)/(4)); no live page reads a per-block
   count. `L2_BLOCK_GAS_LIMIT` (09:195) is a live anchored-view input, "**NOT** committed through any config
   preimage and no preimage enumeration changes". The settlement pair rides the checkpoint record with the
   word exactly filled (four `uint64` = 32 bytes), so 08's arithmetic is untouched: 15 declaration slots
   (258–269, 275–277) of 43 sourced (258–300), 28 free (270–274, 278–300).
5. **The deferral set reads three with the ratified membership everywhere.** `DEFERRED.md` 5–9, index 42,
   92, 118, 355–356, 367, 528, 584, 593, `spec/10` 31 and 418–419, PLAN.md 29–36, and now CONVERGENCE.md;
   `FI-PLANNED-01` covers only the general list and `FI-REMOVED-01` stays its tombstone.
6. **F-FI-2 is still open and unfixed, with the guarantee's condition and the headline.** "open and not
   fixed by increment 04; the guarantee's condition is that arrivals stay within the drain the obligation
   can force" (`spec/10` 353), "This is not a latency guarantee. What it gives is exclusion per unit of a
   censor's L1 spending" (`spec/10` 260), the same in `spec/01` 530, 09:46, index 397/526/584,
   `DEFERRED.md` 55–59, D-18 665–677 and the course (learn/01, 02, 08, 09, 11, index, glossary,
   limitations). No per-publisher bound was added and no page claims one.
7. **No disclosure promises more than the rules deliver — except that the round's own closure claim is not
   in the artifact.** Every qualifier the increment states (conditional guarantee, expiry as discharge,
   F-FI-2 open, no preimage change, one unit, proof-side enforcement, no new offence, no FI state gating an
   exit) is backed by rule text. The one place where a claim outruns the artifact is the status claim
   itself: the increment is presented as having closed R4R1-M-01, and no text, commit or delta clause
   supports that. That is INC4R2-RD-01.

## Ship decision

**Not clean: 1 Critical.** The register, the units, the anchored-view fix, the settlement-slot arithmetic,
the deferral count, the four verified closures and the falsifier disclosures all hold, but the round-1
Critical is still open in the specification: FI-13's three modes remain non-exhaustive, and one
permissionless publication still freezes settlement chain-wide and repeatably. **Do not ship.** The repair
must be written into FI-13 (and mirrored in the delta's FI-13 clause and its §6.1 F-FI-3 row), reviewed
again, and only then is the increment clean at the bar. The round-1 report's "clean form" remains the
requirement: every payable record must be resolved by exactly one mode, with a resolvability ground that is
total.
