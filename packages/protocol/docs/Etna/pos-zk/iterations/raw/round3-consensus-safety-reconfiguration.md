# Round 3 — adversarial review, angle A: consensus safety, hidden certificates, reconfiguration

**Reviewer:** fresh independent adversarial reviewer (round 3, angle A). No part of this specification was written by me.
**Frozen snapshot under review:** `3b0821f2fbbc21427ed2dee2575db4ad32deecc3` (change order 03 applied in place).
**Diff base for re-attack:** `f67458b45` (the snapshot the round-2 fixes landed on); round-2 snapshot `5e4129913` used for history only.
**Scope:** `spec/02-consensus.html` (CONS-01..15), `spec/03-membership-staking.html` (MEM-01..12), `spec/06-recovery-exceptions.html` (REC/HALT/WH), with the supporting rules they consume (`spec/04` L1-04..L1-06/DA-05/DA-06/FI-REMOVED-01, `spec/05` PRF-02..PRF-08, `spec/09`, `spec/10`).
**Method:** diffed every page between `f67458b45` and the frozen snapshot and re-attacked the changed text first. In-text italics of the form *"(review round N, finding X)"* were treated as claims; where a claim of closure is contradicted by another page I say so. Round-2 findings that the round-3 text did not fix are re-tested and reported as still open, not as new discoveries.

**Verdict up front.** I did **not** find a new Critical in this angle, and I could not re-break the core safety argument inside the fault model: the single quorum predicate, the per-height lock, leader selection and the L1 epoch→root resolution hold (see "Checked and holds"). The risks I found are in **liveness/reconfiguration and in the epoch-handoff machinery**: the two-epoch lookahead (the R2A-01 fix) replaces a gate keyed to L2 progress with a clock that no rule defines and that silently assumes a cadence and an uptime the protocol does not enforce; the lookahead is not self-healing after a single missed append; the mandated withholding argument (WH-04) still asserts the lock carry-over that CONS-04/CONS-09 explicitly retracted; and the round-2 proof-side handoff gaps (R2A-03/04/05) are not closed and are not listed as open.

**Counts (this report): Critical 0, High 4, Medium 5, Low 2.**
All Highs are inside the claimed fault model (three of the four need no adversary at all; the fourth is the unclosed R2A-03/04/05 shortcut class). No Critical/High yields two conflicting finalized histories; the cross-epoch component remains **Assumed-with-argument** exactly as CONS-09(5)/F1 states.

---

## R3A-01 — High — the two-epoch lookahead's L1-side epoch clock is undefined, and its only permitted reading silently assumes a cadence and an uptime that the protocol does not enforce

**Severity (one line):** the R2A-01 fix removed the Inbox-height gate but never defined how the staking contract knows *which* epoch it is in; the target epoch of every append, the anti-pre-commit bound and the halt condition all depend on a rule no page states, so an implementer must invent a security-relevant rule, and the intended reading (L1 block time) decouples from the height-derived `epoch_of` at any realised cadence other than exactly 2.000 s and after every legitimate Mode A halt.

**Exact rule / missing rule.**
- `spec/03-membership-staking.html` **MEM-09(1)** (lines 451–470): the append chooses "the entry for the lowest epoch in the L1-committed schedule (CONS-13(2)) that has no entry — in steady state that is the entry for epoch `e+2`, appended during the current epoch `e`"; "A call MUST revert … if the entry it would append is for an epoch later than `e+2`, where `e` is **the epoch the L1-committed schedule has currently reached**"; and, in the same clause, "**The contract derives the epoch `e` from the L1-committed schedule and L1 block time alone**, so during epoch `e` the entry for epoch `e+2` is appended".
- `spec/02-consensus.html` **CONS-13(1)–(2)** (lines 416–430): the schedule is `L = 900` **heights**, `epoch_of(H) = floor((H − H_genesis)/L) + e_0`; "no L2-derived view, no header, no witness and no proof participates in it".
- `spec/02-consensus.html` **CONS-13(3)** (line 434): "The commitment is an obligation of the L1 staking contract on its own schedule and **MUST NOT be keyed to the Inbox's last accepted L2 height or to any other L2-derived progress signal**".
- `spec/02-consensus.html` **CONS-14(1)** (lines 453–455): the activation record is "chain_id, H_0, the epoch schedule's offset e_0, genesis_block_hash, genesis_state_root, L, and the first per-epoch mapping entry" — **no activation timestamp, no wall-clock anchor, no E_EPOCH**.
- **Missing rule:** no rule defines the map L1 time → epoch index used by `commitSet()`, and no rule fixes an anchor from which it is computed. `spec/09-parameters.html` defines `E_EPOCH = EPOCH_LEN_L2 · L2_BLOCK_INTERVAL` (line 127) and `EPOCH_LEN_L1 = E_EPOCH / L1_BLOCK_INTERVAL` (line 96) but never states where either is read or how the current epoch is obtained; `t_root(e)` (line 109) assumes the append for `e` happens "in epoch `e−2`", which *presupposes* the answer.

**Assumptions / preconditions.** None. This is a rule-completeness defect. The two readings are:
(A) epoch index from **L1 block time** with a nominal `E_EPOCH`; then the L2's height-derived epoch index and the L1-time index agree only while 900 heights take exactly 1800 s.
(B) epoch index from an **L2 progress signal** (the old Inbox-height gate, or the last accepted epoch); then MEM-09(1)'s own MUST NOT is violated and R2A-01 returns unchanged.
Both are forbidden or broken; the spec does not say which is normative.

**Concrete worked counterexample (reading A; no adversary, no assumption failure).**
1. `spec/02-consensus.html` **CONS-07(4)(b)** lets a height complete as soon as a PoLC is seen: "MUST advance to (H,R+1) when … it has received a PoLC at (H,R) and has completed its own precommit step". Nothing enforces a 2 s spacing. The specification's own happy-path trace (lines 527–541) completes a height in **1.5 s** inside the 2 s interval, and `spec/01-system-model.html` **SYS-03(a)** calls the cadence "a production cadence, not a guarantee".
2. Let the realised cadence be `c < 2` s. The L2 reaches `h_first(e+2)` at wall time `T_0 + 900(e+2)c`; the L1-time schedule reaches epoch `e+2` at `T_0 + 1800(e+2)`. The L2 outruns L1 by `(e+2)(1800 − 900c)` seconds. For `c = 1.9` s the drift is 90 s per epoch, so after ≈20 epochs (≈10 h) the L2 arrives at `h_first(e+2)` before `commitSet()` for `e+2` has even been *appended* — let alone become Ethereum-final. `spec/03` **MEM-09(5)** ("a validator must not produce the first block of epoch `e` unless `mapping[e]` is already Ethereum-final") and `spec/02` **CONS-13(5)** then force a halt at the boundary. For `c = 1.99` s the same halt arrives after ≈400 epochs (≈8 days). This is a permanent 2 s-cadence stop at every later boundary until the cadence is slowed or the clock is re-anchored, and it breaks D1/D6/R4/R6 with no attacker.
3. The mirror case: any halt (Mode A's first-class outcome, HALT-01) freezes height progress while L1 time advances. The L1 contract continues appending entries up to the time-derived `e+2`; after a halt of `N` epochs, entries for up to `N+2` epochs beyond the L2's position may be appended (one entry per call, all in one L1 block if desired), each computed from the *same* frozen ledger snapshot. The anti-pre-commit bound "later than `e+2`" then bounds nothing in L2-height terms: an epoch's set can be fixed arbitrarily many L2 epochs before that epoch starts, excluding every activation, exit or churn event in between, and cannot be amended (MEM-09(4)). Whether that is read as a freeze or as a feature, it is not what MEM-09(1) claims ("the two-epoch lead is therefore the maximum").

**Inside or outside the claimed fault model.** Inside: no adversary, no failed assumption. The cadence deviations are ordinary operation (the trace itself); the halt is a legitimate Mode A outcome.

**Attacker resources and cost.** None for the drift case. In the halt case, an actor that is first to call may fill the pre-commit run for L1 gas only; no stake.

**Harm and the exact requirement / fixed decision affected.** R13 (implementable without inventing a security-relevant rule: the rule decides which set governs which epoch, the A-CONS-4 premise); R4/R6 and **D1/D6** (boundary production halt); R1 (activation can be frozen out for an unbounded run of epochs after a halt); the R2A-01 fix's own claim that the boundary no longer waits on anything.

**Evidence.** MEM-09(1)(5); CONS-13(1)–(3), CONS-14(1); CONS-07(4)(b) and the timing trace; SYS-03(a); 09 PARAM-02 (`E_EPOCH`, `EPOCH_LEN_L1`, `t_root(e)`). Diff `f67458b45..3b0821f2f` shows the gate sentence replaced by "L1 block time alone" with no clock rule added.

---

## R3A-02 — High — the two-epoch lead is not self-healing, and no rule obliges, schedules or rewards the append: one missed `commitSet()` permanently reduces the design to a one-epoch lead in which only an early call avoids the boundary halt

**Severity (one line):** CONS-13(3) calls the append "an obligation of the L1 staking contract on its own schedule" — a contract has no schedule — and MEM-09(1) appends exactly one entry per call with a lowest-missing rule that does not restore the lead after a miss, so the inequality the fix relies on (`2·E_EPOCH`) is silently replaced by `E_EPOCH` after a single skipped epoch, and the design then halts at every boundary whose append is not made in the first ≈17 minutes.

**Exact rule / missing rule.**
- `spec/03` **MEM-09(1)**: "each successful call appends **exactly one** entry … namely the entry for the lowest epoch … that has no entry — in steady state that is the entry for epoch `e+2` … the lowest-missing rule exists only to refill an epoch whose append was skipped." There is **no rule** that says who must call, by when, what happens if no one calls, or that the lead must be restored after a skip. `commitSet()` is "anyone; takes no arguments" (custody sketch, line 123); the only reward-related ledgers are the prover reward ledger (L1-11) and the validator pool (ECON-02) — there is no keeper reward.
- `spec/02` **CONS-13(3)**: "The commitment is an **obligation of the L1 staking contract on its own schedule**".
- `spec/10` **LIVE-01(L6)** lists "the L1 staking contract commits each epoch's set root before the epoch begins" as a *liveness assumption*, i.e. something the protocol does not ensure; but no participant is named as its performer, and MEM-09(1) states it as if the contract acted.

**Assumptions / preconditions.** None beyond the specification's own steady-state description. No adversary is needed for the first trace.

**Concrete worked counterexample.**
1. No `commitSet()` call occurs during epoch `e` (L1 congestion, all keepers idle, or simply nobody — no rule forbids it). Entries exist through `e+1`.
2. Epoch `e+1` runs normally. The lowest missing epoch is now `e+2`; a single call in `e+1` appends it. **Lead = 1 epoch**, not 2. A second call in the same epoch would append `e+3` and restore the lead (allowed: `e+3 ≤ e+1+2`), but nothing requires, schedules or rewards that second call, and an operator calling once per epoch — the natural reading of "in steady state … the entry for `e+2`" — never restores it. Every subsequent epoch therefore runs with lead 1 indefinitely.
3. With lead 1, the entry for `e+2` is Ethereum-final before `e+2` starts only if the call lands at least `L1_FINALITY` before the end of `e+1`, i.e. within the first `E_EPOCH − L1_FINALITY` of the epoch. At the project's own derived numbers (`E_EPOCH = 1800` s, `L1_FINALITY` ≈ 2 Ethereum epochs ≈ 768 s, `spec/09` PARAM-02) that window is ≈1032 s (17.2 min). A call after it leaves `mapping[e+2]` non-final when the L2 reaches `h_first(e+2)`; MEM-09(5)/CONS-13(5) force the halt. The inequality that is actually in force in this state is `E_EPOCH ≥ L1_FINALITY + margin`, **not** the stated `2·E_EPOCH ≥ T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + margin`, so the fix's stated reason ("The inequality is why two epochs suffice") does not cover the state the protocol can be in.
4. Attacker variant (T-7/T-4/T-13, inside the model): after one missed append, an adversary that is the only caller simply calls late in each subsequent epoch; the halt recurs at every boundary for L1 gas and no stake. While the chain is halted, the caller also chooses *when* to refill the missing entry, and therefore the ledger snapshot that defines the set of the epoch being entered (see R3A-06), subject only to "no block of that epoch was ever produced" (CONS-13(5)).

**Inside or outside the claimed fault model.** Inside: trace 1–3 need no adversary; trace 4 uses only L1 inclusion ordering and withholding.

**Attacker resources and cost.** L1 gas and the willingness to be first; no stake, no validator key, no slashing exposure.

**Harm and the exact requirement / fixed decision affected.** D1/D6 and R4 (2 s production and PoS confirmation throughout the D6 envelope), R6 (liveness ends at a condition the design itself leaves unowned), R13; it directly contradicts the round-3 claim that the two-epoch lookahead removes the R2A-01 boundary stall, and it makes `spec/09`'s `LOOKAHEAD_EPOCHS = 2` ("normative and not tunable") unenforceable.

**Evidence.** MEM-09(1)/(5); CONS-13(3)/(5); the custody sketch row for `commitSet()`; LIVE-01(L6); 09 PARAM-02 (`E_EPOCH`, `L1_FINALITY`, `LOOKAHEAD_EPOCHS`, `margin`); diff `f67458b45..3b0821f2f`.

*Severity note:* I keep this High rather than Critical because at the nominal cadence with a punctual first call per epoch it does not bite; if a reviewer weighs the missing obligation as an unconditional D6 break, this is the finding to escalate.

---

## R3A-03 — High — WH-04 still requires the epoch boundary to "carry forward the closing epoch's lock", contradicting CONS-04(1) (which forbids exactly that reading), CONS-09(3), INV-01(P5) and LIM-01

**Severity (one line):** the mandatory answer to the withholding schedule (01-requirements §6.2) rests on three mechanisms, and its third — reconfiguration — states the cross-height lock carry-over that the R2A-10 rewrite deleted and explicitly banned as non-normative text, so an implementer following WH-04 reproduces the permanent-lock liveness failure R2A-10 identified, while one following CONS-04/CONS-09 gets a different protocol.

**Exact rule / missing rule.**
- `spec/06-recovery-exceptions.html` **WH-04** (lines 208–211): "**Reconfiguration.** At an epoch boundary the new set must **carry forward the closing epoch's lock** (CONS-09), and certificates are epoch-scoped and permanent (CONS-08). A stakeholder that rotates keys or changes its stake cannot thereby escape a lock it established in the previous epoch."
- `spec/02-consensus.html` **CONS-04(1)** (lines 144–154): the lock is per height, "released by (a) the commit of H … or (b) the unlock of (2)"; "**The two readings of a lock MUST NOT coexist.** … The competing reading — a lock that persists across heights and is never cleared at a height boundary — is **not normative and MUST NOT appear in any client, contract or later text**".
- `spec/02` **CONS-09(3)** (lines 266–273): "Locks are per height (CONS-04(1)): the lock at a height is released by that height's commit, so **a validator carries no lock state from a height of epoch `e` into `e+1`** … A lock formed at a height of `e` on a value that did not finalize there is resolved at that height … and the lock is **not carried forward** as an independent constraint."
- `spec/10` **INV-01(P5)** (line 27) and **LIM-01** (line 168) both state the per-height lock / parent-validity version, so WH-04 is the only remaining text asserting the retracted mechanism.

**Assumptions / preconditions.** None; the contradiction is textual. Reachable harm requires an implementer to take WH-04 (a normative rule, and the only answer to 01 §6.2's item 3) at face value.

**Concrete failure trace.** Implement the "carry forward" reading: every validator that precommits a block becomes locked at that height; the only unlock is a same-height strictly-later PoLC (CONS-04(2)); a height that ends without a commit (or a validator locked on a non-finalized value) therefore carries a lock that no future height can release. One third of the set in that state contributes no valid votes, and the chain cannot finalize another height — a **permanent halt from a rule**, not from an assumption failure (R6). This is precisely the failure CONS-04(1)'s own paragraph describes and claims to have removed; WH-04 re-introduces it one page away, and CONS-04(1)'s explicit "MUST NOT appear in … later text" is violated.

**Inside or outside the claimed fault model.** Inside: a rules-only defect (R13); the harmful reading is a liveness failure reachable with no adversary, the benign reading contradicts a normative rule.

**Attacker resources and cost.** None for the defect. Under the harmful reading, any validator locked on a value that does not finalize (reachable under an ordinary T-1 partition) becomes a permanent non-voter.

**Harm and the exact requirement / fixed decision affected.** R13 (two normative readings of the lock, one of which CONS-04(1) forbids), R5/F1 (WH-04's third mechanism is a textual assertion, not a rule; the mandated §6.2 conclusion no longer has the mechanism it names), R6 (a permanent halt produced by a rule), INV-01(P5) consistency.

**Evidence.** WH-04 bullet 3 (06, lines 208–211); CONS-04(1) (02, lines 144–154); CONS-09(3) (02, lines 266–273); INV-01(P5) (10, line 27); LIM-01 consensus row (10, line 168); 01-requirements §6.2. The round-3 diff does not touch WH-04.

---

## R3A-04 — High — the round-2 proof-side handoff gaps (R2A-03/04/05) are not closed and are not listed as open: the anchor check is still conditional on a prover-chosen batch length, `set_version_commit` still has no public input, the closing epoch's set root is still witness-chosen, and no header's `next_validators_hash` has any L1-pinned input

**Severity (one line):** PRF-05's epoch-boundary checks remain unenforceable at L1 acceptance for exactly the batches that cross a boundary (the prover chooses the batch length), one of them is "recomputed … against the same public input" that does not exist in the authoritative journal, and the set transition CONS-10(3)/(4) relies on cannot be checked against any L1 fact — so the statement's completeness claim (R7) and the "forbidden shortcut" of CONS-09(5)(i) remain unbacked.

**Exact rule / missing rule.**
- **R2A-03 (still open).** `spec/05-proof-statement.html` **PRF-05(ii)**: "**if the batch's head is the first block of its epoch**, the head header MUST carry the `epoch_anchor` field … and the guest MUST recompute it from the anchor certificate it verifies"; the opening batch starts at `h_first(e+1)` (L1-06 contiguity) and its head is `h_first(e+1)+k−1`, which is the first block only when `k = 1`. Nothing fixes `k = 1` (PRF-05 only forbids spanning; L1-04 lets any account land any contiguous range), so a prover picks `k > 1` and no guest rule recomputes the boundary block's `epoch_anchor`. The "forbidden shortcut" of CONS-09(5)(i) therefore still produces proofs indistinguishable from correct ones at L1. (The parent *linkage* to `prevBlockHash` is separately enforced by PRF-04(v)+L1-05 row 4, so the harm is the false completeness claim and the missing certificate/set-root binding, not a directly forged fork.)
- **R2A-04 (still open).** `spec/05` **PRF-05(iii)**: when the head opens its epoch, `set_version_commit` MUST equal "the CONS-10(6) commitment to the L1 mapping entry `(set_version(e), N(set_version(e)))` …, **recomputed by the guest against the same public input**". The authoritative journal (PRF-02, lines 65–117) contains no `setVersion`, no `N`, and no transition-tuple field; `spec/04` L1-05's closed table (rows 1–26) has no such row either. The check is unimplementable, and `spec/03` **MEM-09(3)** ("a first block that commits a lower version than its predecessor is invalid") has no proof-side or L1-side enforcement.
- **R2A-05 (still open).** The anchor certificate's `set_root` is verified against the witness set only: the journal carries one set root (the batch epoch's), the parent header at `prevHeight` is not part of the checked range `[prevHeight+1, lastHeight]`, and no L1-05 row exposes the closing epoch's root. Nothing compares `cert.set_root` to an L1 fact, so the claim that the guest verifies "the epoch-e commit certificate" is, in substance, "a certificate under a witness-chosen set".
- **Additional, same class (not previously listed):** `next_validators_hash` has no L1-pinned input for **any** header. For a batch in epoch `e`, the header field is `R_{setVersion(e)+1}`, which is not in the journal (which carries `R_{setVersion(e)}` only, and PRF-05 forbids spanning); for the batch ending at `h_last(e−1)`, `spec/02` **CONS-10(3)** requires that header's `next_validators_hash` to equal `set_root(e)`, again not in that batch's journal. `spec/05` **PRF-03(c)** nonetheless requires the guest to check "each header's `validators_hash` and `next_validators_hash` — both MUST be the single canonical MEM-08 root of the set they commit to". A witness-supplied root is not a binding under PRF-13 ("A binding that consists only of 'the caller passed it' is not a binding").

**Assumptions / preconditions.** A permissionless prover (L1-04) and a batch that opens an epoch with `k > 1` blocks (or any implementation that performs the checks). No stake, no key, no consensus fault.

**Concrete attack trace.** Epoch `e` closes at `h_last(e)`; the checkpoint lands there. The prover builds the next batch as `[h_first(e+1), h_first(e+1)+31]` (the placeholder `K = 32`), gives the boundary block an `epoch_anchor` that was never recomputed and a `set_version_commit` that does not recompute; PRF-05(ii)/(iii) do not apply because the head is not the boundary; the proof verifies and L1 accepts. CONS-09(5)(i)'s shortcut is invisible at settlement, and a light client cannot conclude from the proof that the boundary was anchored to the real previous epoch's set.

**Inside or outside the claimed fault model.** The defects are specification defects (R7/R13); the shortcut they leave open is inside the fault model exactly as CONS-09's own failure mode states (proposer T-3 plus a fresh epoch-e+1 set).

**Attacker resources and cost.** Zero extra stake; a batch-range choice and (for the shortcut) an implementation that omits the field.

**Harm and the exact requirement / fixed decision affected.** R7 (complete proof statement, both backends), R13, CONS-09(5)(i) "forbidden shortcut", F1; the round-3 ledger does not list R2A-03/04/05 as open although `03-change-order.md` §4 required every remaining round-2 finding to be closed or explicitly dispositioned.

**Evidence.** PRF-05(ii)/(iii); PRF-02 journal; PRF-03(c)/(d); PRF-13; L1-05 rows 1–26 and §2.1; CONS-09(5)(i); CONS-10(3)/(4)/(6); MEM-09(2)/(3). Diff `f67458b45..3b0821f2f` shows no change to these clauses.

---

## R3A-05 — Medium — there is still no canonical commit certificate, so `cert_hash(e)`/`epoch_anchor` is not a function of public facts and correct validators can reject each other's epoch-opening header

**Severity (one line):** every quorum subset of signers yields a different but equally valid certificate, hence a different `cert_hash`, a different `epoch_anchor`, and a different first block of the next epoch; CONS-10(6) tells a verifier to reject a header whose anchor "does not recompute from the certificate it presents", so two correct validators holding two valid certificates disagree about the same boundary block.

**Exact rule.** `spec/02` **CONS-09(1)** (lines 259–263): the first block commits to "`cert_hash(e)` … the **canonical certificate hash** of `B_anchor`'s epoch-e commit certificate". **CONS-05** accepts *any* certificate satisfying `quorum_block` (line 179); **CONS-10(6)** (lines 331–339) fixes the encoding of a given certificate but not which certificate is canonical; nothing in CONS-11 or the object table selects one. C(n, quorum) valid certificates exist for one `(H,R,B)`.

**Worked case.** Validator V1 holds certificate A (signers 1…700) for `B_anchor`; V2 holds B (signers 2…701); both valid. The proposer builds the boundary block with A; V2 recomputes `epoch_anchor` from B and rejects the header (CONS-10(6), CONS-09(2)); V2 prevotes NIL. The round is lost and the boundary churns, or stalls if V2 never obtains A. A malicious proposer can weaponise this by anchoring an obscure valid certificate. No validator misbehaved and nothing is slashable.

**Assumptions / preconditions.** Two valid certificates for one block — trivially reachable, since certificates are aggregates of gossiped signatures and no canonical-selection rule exists. No adversary needed for the split; a proposer can cause it deliberately.

**Inside/outside.** Inside (liveness/reviewability). Not a safety break: only one block can gather >2/3 precommits.

**Attacker resources and cost.** None; a liveness/churn surface, plus a griefing lever for any proposer.

**Harm and requirement.** R13 (the field's value is not a function of public state), R5/F1, CONS-09(2), MEM-09's set authentication at the boundary. (Round-2 R2A-07, Medium, unclosed.)

**Evidence.** CONS-05 (02, 177–195); CONS-09(1) (02, 259–263); CONS-10(6) (02, 327–339); the absence of any canonical-certificate rule in CONS-11 or the object table.

---

## R3A-06 — Medium — "the caller chooses nothing" remains false about *when*: the first caller after the append window opens picks the snapshot moment, and after a skipped entry it picks the set of an epoch that has already begun

**Severity (one line):** MEM-09(1) fixes the *content* of an entry from the ledger at call time but leaves the call time free (and, after a skip, leaves the refill time free), so an unauthenticated caller chooses which activations, exits, churn deferrals and slashes are reflected in the set that will govern epoch `e+2` — or, for a late refill, an epoch that was already due.

**Exact rule.** `spec/03` **MEM-09(1)**: "The caller chooses nothing — not the epoch, not the entries, not the total, not the block's position in the block". Its contents are "the root, the total and the commit timestamp of the ledger state **at the moment of the call**". Compare MEM-02(1) (`effStake_k(v) = LedgerState(N(k)).active[v]`), MEM-05(2) (exit effectiveness is a function of the snapshot), MEM-07(3) (rotations take effect at a snapshot), ECON-03(6) (churn deferral in request order) — all time-varying. With the two-epoch lookahead the choice is *more* consequential than in round 2: the entry appended during `e` governs `e+2`. If an entry was skipped, the lowest-missing rule appends it later (during the epoch that is already due, or after a halt), i.e. the set of an epoch is fixed after that epoch's nominal start — permitted only because no block of it was produced (CONS-13(5)).

**Concrete case.** Honest validator H lands `requestExit()` in L1 block `b`. Its exit becomes effective at the first snapshot at/after `b` that the churn cap does not exclude — and that snapshot is whoever calls `commitSet()` next. An adversary that is the first caller chooses to call in `b` (H still in the set governing `e+2`) or after `b` (H out). The same lever applies to an activation crossing ACTIVATION_DELAY, a pending slash, or a key rotation. After a missed entry the adversary can also wait until the ledger reaches the composition it wants before calling, because the L2 cannot enter the epoch until the entry is Ethereum-final.

**Assumptions / preconditions.** Being first in the L1 ordering (priority fee, T-1/T-6) and/or the R3A-01/R3A-02 delay levers. No stake.

**Inside/outside.** Inside (T-1/T-6, T-7, T-9); no safety break — all nodes read the same L1 entry once written, so A-CONS-4 holds — but the composition bias is real and undisclosed, and MEM-09(1)'s "chooses nothing" is false as written.

**Attacker resources and cost.** L1 gas plus being first; or the cost of delaying the append.

**Harm and requirement.** R1/R5 (the set is a security input chosen by timing rather than by a rule), A-CONS-1's premise ("the stake that counts toward quorum"), R13. (Round-2 R2A-09, Medium, unclosed; the two-epoch change widens the window.)

**Evidence.** MEM-09(1)/(2)/(5); MEM-02(1); MEM-05(2); MEM-07(3); ECON-03(6); CONS-13(5).

---

## R3A-07 — Medium — the censorship-resistance statement's premise set is incomplete: no rule requires an honest proposer to include anything, and ROLE-01(b) says so explicitly

**Severity (one line):** LIVE-04/FI-REMOVED-01/(09 glossary)/CONS-06 all state that "a transaction that reaches honest validators is included by the first honest proposer with room for it" under A-CONS-2 alone, while ROLE-01(b) states that no inclusion duty attaches to a validator and that omitting a particular transaction "is neither a proposal-validity failure nor an offence" — so the only mechanism the resistance claim names is a behavioural assumption that is nowhere listed and nowhere defined ("room" is undefined, and D4 lets the proposer order and select freely).

**Exact rule.** `spec/10` **LIVE-04** (lines 136–154), `spec/04` **FI-REMOVED-01** (lines 531–536) and the rotation argument (line 538), `spec/02` **CONS-06** "what this does not claim" (line 207), `spec/09` glossary (line 45) vs `spec/01` **ROLE-01(b)** (line 374): "No inclusion duty attaches to a validator: a proposer includes what the objective rules admit, and omitting a particular transaction is neither a proposal-validity failure nor an offence … and the offence catalogue of ECON-04 contains no censorship offence." CONS-01 now imposes no inclusion condition at all (the D-6 edit).

**Preconditions / trace.** A proposer is selected (deterministically, CONS-06(d)); it receives a user transaction and builds a block without it. This violates no rule and is not misconduct. Nothing in LIVE-04's premise list (A-CONS-2) or in CONS-06's rotation arithmetic changes this: proposer rotation bounds *who* proposes, not *what* a proposer must include; "room" is not a defined quantity, and no rule requires a proposer to include a received transaction even when there is room. The claim that a coalition below one third "can only make inclusion late, not prevent it" therefore rests on an unstated assumption about honest proposer behaviour, not on a protocol guarantee or a named assumption.

**Inside/outside.** Inside; no adversary needed beyond one scheduled proposer omitting a transaction, which the rules permit.

**Attacker resources and cost.** Zero for a scheduled proposer; a sub-threshold coalition can make inclusion late within its own slots, as CONS-06 already concedes.

**Harm and requirement.** R10 in its relaxed form ("state censorship resistance **honestly**": the statement must name its premises); R13; the D-6 disclosure obligation ("Any user-facing material that implies otherwise is a defect" — the material implies a mechanism the rules do not provide). Not a violation of the original R10, which D-6 removed.

**Evidence.** LIVE-04; FI-REMOVED-01 and the rotation paragraph; CONS-06(b)/(d) and its "does not claim" paragraph; ROLE-01(b); CONS-01 (no inclusion condition); 09 glossary "Censorship resistance".

---

## R3A-08 — Medium — CONS-03 and L1-05 row 12 require the L1 Inbox to evaluate `3·s > 2·W` over an authenticated `s`, but no binding carries `s`: the normative claim about *where* the predicate is evaluated is unimplementable

**Severity (one line):** the single-predicate requirement itself is met in all three texts, but the sentence that assigns the comparison to the L1 contract cannot be implemented — the contract sees only `W` (as `quorumThreshold = 2·W`, PRF-02) and never the signer set or `s` — so an implementer must either violate the MUST or invent a submitter-supplied `s`, which L1-05 explicitly forbids for derived rows.

**Exact rule.** `spec/02` **CONS-03** (lines 114–120): "the L2 client, the zkVM guest and the **L1 Inbox** MUST each evaluate exactly `3 * s > 2 * W` over the same authenticated `s` and `W`, with checked arithmetic." `spec/04` **L1-05 row 12** repeats "... evaluated identically by the L2 client, the zkVM guest and this contract", while defining the journal's `quorumThreshold` as only `checked_mul(2, validatorSetTotalPower)`. `spec/05` **PRF-02** has no `s` and no signer set (only `signerBitmap`, claimed, proof-bound); `finalityCommitment` (L1-05 row 15) commits to the bitmap/signature-set hashes inside the guest and cannot be opened on L1.

**Trace.** An implementer taking the MUST literally adds a submitter-supplied `s` to the statement so the contract can compare; that value is not bound to any authenticated signer set (the bitmap is inside a hash the contract cannot open), so the contract-side check is meaningless — worse than absent, because it reads as assurance. An implementer who correctly has the guest do the comparison produces a design that violates the literal MUST in CONS-03 and row 12.

**Inside/outside.** Specification defect (R13/R7), no adversary; the misleading contract-side check is a false-assurance surface.

**Harm and requirement.** R7/R13; reviewability of the quorum rule (which CONS-03 itself calls a protocol defect when it diverges). (Round-2 R2A-08, Medium, unclosed.)

**Evidence.** CONS-03; L1-05 row 12; PRF-02 journal; PRF-04(i)–(iv); 09 PARAM-02 "Quorum predicate".

---

## R3A-09 — Medium — ECON-07(7) still says `land` "rejects a batch whose depth exceeds `D_MAX`", the enforcement point the round-3 change deleted as forbidden

**Severity (one line):** the cap now has exactly one enforcement point — validators (HALT-03, L1-06, DA-06) — but a surviving sentence in the economics page states the deleted L1-side rejection, so two normative texts assign opposite enforcement, and an implementer following ECON-07(7) builds the admission condition that L1-04/L1-06 forbid.

**Exact rule.** `spec/07-economics-slashing.html` **ECON-07(7)** (lines 530–533): "HALT-03 permits production to run ahead of the highest L1-accepted checkpoint by up to `D_MAX − MARGIN_V` L2 blocks and **rejects a batch whose depth exceeds `D_MAX`**". Against: `spec/06` **HALT-03** (lines 92–98): "**Exactly one enforcement point: the validators.** `land` MUST NOT reject an over-depth batch"; `spec/04` **L1-06** (lines 197–201) and **L1-04** (lines 101–105); `spec/04` **DA-06** (lines 507–515).

**Preconditions / harm.** No adversary. The forbidden check is the round-2 R2-LIV-07 defect: an over-depth batch is refused at admission even though it is a validly PoS-finalized extension, which is the Mode A outcome L1-04 exists to prevent; the depth only shrinks as *earlier* batches land, so the range is not permanently stranded, but the design becomes dependent on the L1 contract's view of production depth — exactly what the round-3 edit removed. Which rule wins is left to the implementer.

**Inside/outside.** Inside (rules alone); R9/Mode A obligations, R13.

**Attacker resources and cost.** None for the defect.

**Harm and requirement.** D2/Mode A (L1-04), R9, R13. (This is a residual of the R2-LIV-07 fix, created by an un-updated cross-reference.)

**Evidence.** ECON-07(7) (07, lines 530–533); HALT-03 (06, lines 92–123); L1-04/L1-06/DA-06 (04); 03-change-order §3 "single enforcement point".

---

## R3A-10 — Low — stale summaries/titles now contradict the normative text (index map), the GEN-05 tag notation is still ambiguous in the one place where it is a header value rule, and `cert_hash`'s field types are not restated

**Severity (one line):** clarity/citation defects on the most load-bearing rules, each of which can mislead a reader who uses the map or the shorthand as normative.

- `spec/index.html` rule map: **CONS-05** row says "≥ 2/3 precommits finalizes the block" while CONS-05/STATUS-04 require strictly more than 2/3 (`3·s > 2·W`) — the very off-by-one class CS-09 closed; **CONS-09** row still says "Epoch handoff and **lock carry-over**" after the carry-over was retracted; **ROLE-04** row says "User rights: **inclusion**, exit, disclosure" while the rule states there is no inclusion guarantee and no L1 path. `index.html` says the table "is a map, not a second copy", but these three summaries state the opposite of their rules.
- `spec/02` **CONS-10(6)** writes its domain tags as string literals (`abi.encode("TAIKO_ETNA_ANCHOR_V1", …)`) while `spec/index.html` **GEN-05** requires a right-padded ASCII domain tag as a typed field, and `spec/03` MEM-08's table uses the `bytes32` form. CONS-10(6) is the one place where the encoding *is* the value rule for a header field, and the two readings give different preimages and different header hashes (round-2 R2A-12, unclosed). The `cert_hash` field list is exhaustive but does not restate the types of `block_id_kind` (width) or the signature ordering beyond "ascending signer index".
- **LIM-01** liveness row (10, line 172): "A cartel of at least one third can halt the chain, **though it cannot censor selectively while quorum exists**". Once a cartel holds ≥1/3, honest power is ≤2/3, so its precommits are needed for *any* certificate: it can refuse the blocks containing a target transaction while finalizing blocks that exclude it — that is selective censorship while the chain progresses. The clause is an over-reassurance in a limitation row (read either as a category error — the case is outside A-CONS-1 — or as a false statement about that case).

**Inside/outside.** Inside; no adversary.

**Harm and requirement.** R13/R14 consistency, reviewability; GEN-07 (controlled vocabulary) for the map rows.

**Evidence.** index.html lines 292, 298, 302; GEN-05 (index.html lines 112–120); CONS-10(6) (02, lines 327–339); MEM-08 table (03, lines 429–448); LIM-01 (10, line 172); CONS-03/CONS-05.

---

## Checked and actually holds (not re-listed as findings)

These were re-attacked on the frozen text and the attack no longer succeeds; recording them is part of the verdict.

- **The single quorum predicate (round-1 CS-09).** CONS-03, PRF-04(iii), PRF-02 and L1-05 row 12 all state exactly `checked_mul(3, s) > checked_mul(2, W)`; `quorumThreshold` is defined as the right-hand product only; the `floor(2W/3)+1`, "threshold + 1" and division forms are explicitly deleted. No off-by-one remains. (The separate claim that the *Inbox* evaluates it is R3A-08.)
- **The per-height lock (round-2 R2A-10).** CONS-04(1) is now unambiguous — a per-height triple, released by that height's commit or by a strictly later same-height PoLC, with the two readings forbidden to coexist — and this is the form the quoted CometBFT Proof of Safety actually uses (a same-height argument). CONS-09(3), INV-01(P5) and LIM-01 all state the same reading. The only surviving contrary text is WH-04 (R3A-03). Nothing else in `spec/` still relies on a lock surviving a height.
- **Leader selection (CONS-06).** `pos = uint256(keccak256(abi.encode(DOMAIN_PROPOSER, chainId, epoch, H, R))) mod W` is a pure function of committed inputs; the half-open cumulative-weight intervals partition `[0, W)`, the lower-index tie rule is stated, modulo bias is bounded by `W/2^256`, and the fairness step is honestly labelled **Assumed** (random-oracle uniformity) and an expectation, not a per-window bound. I could not make the residue-counting argument fail in the committed integers.
- **Epoch → set-root identity (round-1 CS-01).** L1 resolves `epoch → (setRoot, totalVotingPower, rootCommittedAt)` from an append-only, never-overwritten mapping (MEM-09(2)); the header fields are the MEM-08 root; the journal's `validatorSetRoot` is L1-derived and checked against that mapping (L1-05 row 10, PRF-02(2)). A proposer or prover cannot *name* the root. The residual is the *clock and timing* (R3A-01/R3A-06), not the identity.
- **Single validator-set encoding (round-1 CS-04/B R1-05).** MEM-08 owns the only encoding; CONS-10(1)/(2) and PRF-03(c)/PRF-05(iv) defer to it with the same tags, canonical order and promoted-odd-node rule. No second encoding found.
- **Churn cap wiring (round-2 R2A-06).** MEM-05(2) now makes effectiveness "the first set version … **that the churn limit does not exclude**", MEM-03 §2.1 row 4 carries the same qualification, and ECON-03(6) states the same condition and order; the previous contradiction is gone.
- **Removal of forced inclusion (D-6).** No live rule depends on FI-01..FI-05; CONS-01 has no inclusion condition; L1-04's permitted bounds no longer mention a coverage list; HALT-04/WH-02 no longer contain the omission offence; the rotation argument is consistently re-based on CONS-06. The round-2 Criticals R2-LIV-01/03/04 are closed by deletion (their attack traces no longer exist).
- **Within-epoch safety (CONS-12).** Two quorums at one height intersect in more than 1/3; the published CometBFT argument transfers for a fixed epoch set. I found no new two-conflicting-finalized-histories attack inside the fault model. The cross-epoch case analysis of CONS-09(4)(a)/(b) reduces case (b) to case (a) via the anchor duty, and case (a)'s evidentiary gap is disclosed and correctly labelled Assumed. **F1 remains open exactly as stated**, and no new argument closes it.

## Answers to the four assigned re-attack questions (short form)

1. **Does the two-epoch inequality remove the boundary stall, and can any node still choose the set?** It removes the *guaranteed* R2A-01 stall only in an idealised steady state. The inequality is not the operative constraint: under the new rule the append no longer waits on proving or settlement (so `T_PROOF_MAX_PERMITTED` and `T_SETTLE_PIPELINE` are vestigial in it), while the term that does bind — *when* in the epoch the call is made, and whether anyone makes it — is unstated and unenforced (R3A-02); and the L1-side epoch clock the whole schedule needs is undefined, with its only permitted reading assuming an exact 2.000 s cadence and no halt (R3A-01). On "can any node choose the set": the root's *identity* is L1-determined and safe, but an unauthenticated caller chooses the *snapshot moment* for an epoch two ahead (and, after a skip, for an epoch already due) — R3A-06, unclosed from R2A-09.
2. **Per-height lock (CONS-04 / R2A-10): unambiguous, and does anything still rely on a lock surviving a height?** Unambiguous and correctly aligned with the published proof; WH-04 is the only text still relying on the retracted cross-height lock, and it does so in a normative rule (R3A-03).
3. **Epoch handoff (CONS-09, F1): are the anchor fields encodable and checkable?** Encodable: yes, CONS-10(6) gives exhaustive canonical encodings (with the GEN-05 tag-notation ambiguity of R3A-10 and the missing canonical-certificate rule of R3A-05 — two valid certificates give two valid header hashes). Checkable: not as claimed — the guest check is conditional on a prover-chosen batch length, `set_version_commit` has no public input, the closing epoch's root is never pinned to L1, and `next_validators_hash` has no L1-pinned input at all (R3A-04). F1 therefore remains Assumed on the client duty, not backed by the proof as the page asserts.
4. **Single quorum predicate.** The predicate is single and consistent across the client, guest and contract texts (holds). The claim that the L1 Inbox *evaluates* it over an authenticated `s` is unimplementable (R3A-08).
5. **Did removing forced inclusion leave an argument without a premise?** No liveness premise was lost (removal only widens the valid-proposal set), but the censorship-resistance statement now rests on an inclusion behaviour that no rule imposes and that ROLE-01(b) expressly declines to impose (R3A-07).

## Verdict for the parent

Nothing in this angle yields two conflicting finalized histories inside the fault model, and I could not re-break the round-1/round-2 safety fixes (single quorum predicate, per-height lock, leader selection, epoch→root identity, churn wiring, D-6 removal). The round is **not clean** for this angle: the R2A-01 fix is a partial fix whose clock, keeper obligation and self-healing behaviour are unspecified (R3A-01/R3A-02, both High, both reachable with no adversary), WH-04 re-asserts the retracted lock carry-over (R3A-03, High, rules-only), and the proof-side handoff gaps R2A-03/04/05 are neither fixed nor listed as open (R3A-04, High, plus the `next_validators_hash` generalisation). Five Mediums and two Lows remain. Round 3 should not count toward the two-consecutive-clean-round rule on this angle.
