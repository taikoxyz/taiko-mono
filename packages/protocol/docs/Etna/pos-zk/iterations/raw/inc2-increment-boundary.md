# Increment 02 review — the increment's boundary and its interaction with the converged v1

**Reviewer:** independent adversarial reviewer, increment 02, angle `increment-boundary`.
**Snapshot reviewed:** `cea431c37` (branch `etna-pos-zk`), extracted with `git archive`. Bases read: `increments/02-heartbeat-design.md` (design delta), `DECISIONS.md` D-17, `CONVERGENCE.md`, `DEFERRED.md` §2, and the implemented `spec/02`, `spec/03`, `spec/06`, `spec/07`, `spec/08`, `spec/09`, `spec/10`, the index and the course.

**Counts: Critical 0 · High 1 · Medium 1 · Low 3.**

The increment itself is coherent and does not reopen a v1 decision — every item on the charge list holds (see the checklist). The High is a **new interaction between the revived predicate and the commit's timing** that no rule or falsifier covers; it is not a defect of MEM-13's payload, storage or exclusion rules, which I could not break.

---

## F1 — The commit instant is chosen by whoever calls `commitSet()` within a one-epoch append window, and eligibility is window-scoped, so a caller can append at the first block of a heartbeat window with its own entries' heartbeats ordered first and make its entries the only eligible roster

**Severity: High.** One-line rationale: MEM-13 makes the roster "the active entries whose last accepted heartbeat named the window containing `t_root(e)`", and `t_root(e)` is the timestamp of the `commitSet()` transaction, which any account may place anywhere in a one-epoch-wide append window (the append's enforcement is an unfunded Open); a heartbeat for window `w` cannot be recorded before `w` begins, so a caller that appends in the first block of a new window with its own entries' heartbeats ordered ahead of `commitSet()` and honest heartbeats ordered behind it gets a version whose entire `TotalVP_k` is its own weight — the composition lever the mechanism's own safety claim says does not exist.

**File + rule ids.** `spec/03-membership-staking.html` `#MEM-13`(3) (the predicate and its equivalence to the window containing `t_root(e)`), `#MEM-13`(2a)(b) (a heartbeat's named window must be the current one), `#MEM-13`(2), `#MEM-13`(5) ("excluding an honest validator requires preventing or delaying its own L1 heartbeat"), `#MEM-08`(5) (n = 1 is a valid single-leaf set); `spec/03#MEM-09`(1) (the append is due "no later than one EPOCH_LEN_L1 after it becomes coverable", `commitSet()` is permissionless, "the caller chooses nothing", and "a ledger mutation in a later transaction of the same block does not affect R_k"), `#MEM-09`(2) (`setVersionBlock(e) = N(k)` is the evaluation instant; `rootCommittedAt` is the commit transaction's `block.timestamp`), `#MEM-09`(6) and `spec/02#CONS-13`(3) (the append-obligation window); `spec/02#CONS-03` (quorum over the version's `W`).

**Assumptions.** No assumption is broken. A-CONS-1 is stated per committed version; the adversary's stake stays below one third of the *ledger*. The attack needs (i) the append for the epoch to still be pending at a heartbeat-window boundary — which is the state the specification itself leaves Open, because the append call is unrewarded and its enforcement is undecided ("Who pays for the append call and whether a keeper bounty exists is Open", MEM-09(1); the disclosed consequence of no one calling is a late append) — and (ii) one block's intra-block ordering (a builder bundle or priority fees), which MEM-09(1) makes decisive by rule.

**Concrete attack trace.**
1. Let window `w` begin at `t_w = w · HEARTBEAT_WINDOW`. The adversary holds one or more active entries `v_i` (bonded, activated) with registered heartbeat keys, and it has produced a signature for `w` for each (a signature naming `w` and binding a fresh anchor may be produced before `t_w`; it is *accepted* only from `t_w`, MEM-13(2a)(b), and the delta's residual F9 says exactly this).
2. The append for the target epoch `e` (in steady state `e = current + 2`) is pending: coverable from the start of the L1-side epoch and due only one `EPOCH_LEN_L1` later, with no rule forcing an early call and no funded keeper.
3. In the first L1 block with `block.timestamp > t_w` — block `B`, whose `block.timestamp` is strictly inside `w` — the adversary lands a bundle ordered: `heartbeat(v_i, w, …)` for each `v_i`, then `commitSet()`. Honest entries' last accepted heartbeats name `w−1` (their `w`-heartbeat cannot have been recorded before `t_w`, and if it is in `B` it is ordered after the bundle).
4. Inside `commitSet()`, the predicate `lastHeartbeatAt(v) ≥ t_root(e) − HEARTBEAT_WINDOW` is evaluated at `t_root(e) = B.timestamp`. For the adversary's entries, `lastHeartbeatAt = w·HEARTBEAT_WINDOW` (recorded earlier in `B`), which satisfies it. For every honest entry, `lastHeartbeatAt = (w−1)·HEARTBEAT_WINDOW`, and `(w−1)·HW ≥ t_root − HW` holds only when `t_root = w·HW` exactly; since `B.timestamp > t_w`, they are all ineligible. (The specification's "commit timestamp exactly on a window boundary is covered by the window that ends there" clause covers only the boundary instant, not the block after it.)
5. The committed version for `e` therefore contains only the adversary's entries: `n_k` can be 1 (a valid single-leaf set, MEM-08(5)), `TotalVP_k` is the adversary's own weight, and `W_e = TotalVP_k`. Its share of the quorum denominator is 100%, so it alone satisfies `3·s > 2·W`; honest nodes cannot vote (they are not in the set) and must judge the epoch under the L1-committed root (MEM-09(3)–(5)).
6. The adversary can now finalize conflicting blocks at a height of that epoch — the class INV-01 exists to exclude — and it can repeat the manoeuvre in any later epoch whose append is still pending at a window boundary. Every epoch has a window boundary inside its append window with probability ≈ `E_EPOCH_L1 / HEARTBEAT_WINDOW` (≈ 0.9 under the registered relation `HEARTBEAT_WINDOW ≥ E_EPOCH_L1 + …`), so the opportunity is the common case, not a corner.

**Why the existing falsifiers do not cover it.** F8 is "an adversary able to **censor, delay past the window, or price out** honest entries' L1 heartbeat transactions" — the attack neither censors nor delays a heartbeat past its window; it simply orders the *commit* before honest heartbeats that land in the same window (or waits for a block in which they have not yet landed). MEM-13(5)'s sentence "excluding an honest validator requires preventing or delaying its own L1 heartbeat" is therefore false as written: the heartbeat is not prevented or delayed, it is merely later than the caller's chosen commit instant. MEM-09(1)'s "the caller chooses nothing" is likewise false in the one dimension that now matters — the caller chooses the block, hence `t_root(e)`, hence which heartbeat window the roster is evaluated in. The delta's §4.1 asserts "the caller chooses nothing; the roster is the active entries that are eligible at that instant" without noticing that the instant is inside the caller's control.

**Fault-model verdict.** Inside. A sub-threshold-stake, permissionless participant (any active entry) exploits a rule, not an assumption; no cryptography fails; no L1 censorship is needed (ordering influence for one block, or the append simply being late). Consequence class: a committed version whose quorum denominator is adversarially composed, and — for that version — two conflicting certified blocks at one height, i.e. the safety-invariant class. No funds are lost through the L1 acceptance path (it stays proof-gated), which is why I rate this High rather than Critical; **if the append is systematically late (the Open's natural outcome with no funded keeper), the capture is repeatable and the consequence is the Critical class**, and the fix is cheap either way.

**Attacker cost.** One active entry's bond (S_min), one heartbeat transaction per adversary entry per captured window, one `commitSet()` transaction, and one block's ordering influence (builder bundle/priority fee) per captured version. No stake above the minimum, no censorship, no collusion beyond the builder of one L1 block.

**Requirement affected.** D-4/D-7 (voting power is stake-weighted and the set is derived from committed stake — here the set is selected by commit timing, not by stake or attestation alone); A-CONS-1's per-version framing as the mechanism's own safety premise (MEM-13(5)); MEM-13(5)'s exclusion claim; F8's completeness; MEM-09(1)'s "the caller chooses nothing".

**Suggested repair (any one closes it; the first is smallest).** (i) Make the evaluation instant caller-independent: evaluate the predicate against the heartbeat window containing `L1_first(e)` (the L1-side epoch start) or against the window containing the epoch's first coverable block, instead of `t_root(e)`; `t_root(e)` may keep its ECON-07 role. (ii) Or require the append to be made in the first block in which the entry is coverable (with a funded keeper, since the obligation is currently Open). (iii) Or, if the design keeps `t_root(e)`, extend F8 to name the commit-timing lever and state the honest cadence as "a heartbeat for the *current* window must be recorded as early as possible in that window, and an operator that has not yet attested in it is excluded from any commit that lands first" — and correct MEM-13(5)'s sentence — but disclosure alone does not remove the capture.

**Evidence.** `spec/03#MEM-13`(1),(2),(2a)(b),(2c),(3),(5),(6),(7); `spec/03#MEM-08`(5); `spec/03#MEM-09`(1),(2),(3),(4),(5),(6); `spec/02#CONS-03`, `#CONS-13`(3),(5); `spec/09` `HEARTBEAT_WINDOW`, `APPEND_WINDOW_L1`, `LOOKAHEAD_EPOCHS`; `spec/10#LIVE-05` (attrition/simultaneous-stop rows); `increments/02-heartbeat-design.md` §§2.2–2.3, 4.1, 5.3, 6.2 (F8), 9.3, 9.8; `learn/04-staking-and-epochs.html` "an operator that attests once per L1-side epoch has a signing occasion in every window".

---

## F2 — The activation (genesis) roster's treatment under the predicate is unstated: the literal reading makes activation invalid

**Severity: Medium.** One-line rationale: `CONS-14` writes the first per-epoch entry for `e_0` from the staking contract's state, `MEM-13`(3) makes eligibility a condition on the version committed for an epoch, and `MEM-08`(5)/`CONS-14`(4) make `n = 0` an invalid activation — but no heartbeat can be recorded before the staking contract and its entry points exist, and no rule says whether the activation entry is filtered or exempt; the design delta leaves this as an Open runbook item, so the specification currently has two readings with opposite launch outcomes.

**File + rule ids.** `spec/02#CONS-14`(1) (the activation transaction computes `set_root(e_0)` "from the L1 staking contract's state at that block, with the MEM-08 encoding"), `#CONS-14`(4) ("An activation with `n = 0` or `W_0 = 0` is invalid"), `spec/03#MEM-08`(5) ("n = 0: invalid set, never published"), `#MEM-09`(1) ("The entries it commits are exactly the ledger entries that are active … and eligible …"), `#MEM-13`(3); `spec/08` T3's precondition "the staking contract reports a non-zero epoch-0 set root"; `increments/02-heartbeat-design.md` §9 item 8 ("Whether existing entries must produce a heartbeat before activation at T3 (proposed: the key is registered with bonding and the normal window applies from the first commit point after activation; the announcement must say so)").

**Assumptions.** None.

**Concrete attack trace (no adversary).** An implementer follows MEM-13(3) literally and applies the predicate to the activation entry: every entry's `lastHeartbeatAt` is 0 (the heartbeat path and the keys are created by/with the same activation), no entry is eligible, the roster is empty, and `n = 0` is an invalid activation — the chain cannot activate. An implementer that reads CONS-14(1)'s enumeration instead takes the active bonded set unfiltered — the delta's proposal — but no rule authorises that, and a second implementer may differ, so the first boundary of the chain is not deterministically specified. The delta's item 8 shows the authors know the question is open; the specification does not state the answer in any rule, register row or index entry.

**Fault-model verdict.** N/A (specification ambiguity; launch-critical). No fund loss and no conflicting histories — but a launch that cannot proceed if implemented one way, and a non-deterministic first roster if implemented the other way.

**Attacker cost.** None.

**Requirement affected.** D-16's "the increment ships only after its own review round is clean"; the activation path's determinism (CONS-14); the index's claim that every rule-referenced behaviour is stated once.

**Suggested repair.** One sentence in `CONS-14`(1) or `MEM-09`(1): "the activation entry's roster is the active bonded set, unfiltered by MEM-13; the predicate applies to every entry the contract appends from the first `commitSet()` after activation" — or the opposite duty ("every active entry MUST have an accepted heartbeat before the activation entry is computed") with the migration runbook and announcement carrying it. Either is fine; silence is not.

**Evidence.** `spec/02#CONS-14`(1),(4); `spec/03#MEM-08`(5); `#MEM-09`(1),(2); `#MEM-13`(3); `spec/08` T3 row (L1 block `N` precondition "the staking contract reports a non-zero epoch-0 set root"); `increments/02-heartbeat-design.md` §9 item 8.

---

## F3 — Three register rows in `spec/03` still describe MEM-13 as deferred

**Severity: Low.** One-line rationale: with MEM-13 live, the tombstones for the withdrawn decay carry a parenthetical that contradicts the increment.

**File + rule id.** `spec/03-membership-staking.html`, the quantity/reservation table rows `T_INACTIVE withdrawn`, `D_LAPSE_MAX withdrawn` and `lastObserved(v) withdrawn`, each reading "… it MUST NOT be used by any rule, client, parameter or migration text **(MEM-13, deferred by D-16)**" and carrying "MEM-13 (withdrawal)" as the recording rule; `spec/03#MEM-13` is now "L1 heartbeat eligibility (no rule removes weight)", live. The substantive parts of the rows are correct (the decay and its names stay withdrawn); only the attribution is stale.

**Assumptions.** None.

**Attack trace.** None (documentation). A reader of the membership page's table is told MEM-13 is deferred by D-16 — the state before increment 02 — and may look for a live owner of the withdrawal elsewhere.

**Fault-model verdict.** N/A.

**Requirement affected.** PARAM-01/GEN-03 (one rule, one place, current owner); D-17.

**Suggested repair.** Replace "(MEM-13, deferred by D-16)" with "(MEM-13(4), live; the decay remains withdrawn)".

**Evidence.** `spec/03` rows at the table's tombstone block (the three rows above); `spec/03#MEM-13`(4); `spec/09` `T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved(v)` rows; `DECISIONS.md` D-17.

---

## F4 — The authoritative design delta still says it is "NOT APPLIED"

**Severity: Low.** One-line rationale: the increment is applied in this snapshot, but the delta that the round treats as authoritative opens with a status line claiming no specification, register, index, course or decision file has been edited — the opposite of what the snapshot contains.

**File + rule id.** `increments/02-heartbeat-design.md` lines 3–6: "**Status: design delta, NOT APPLIED.** No specification, register, index, course or decision file has been edited by this pass." Against it, the snapshot's own commits (`e135656f4` course + DEFERRED + D-17, `75b960652` register/index/assurance/migration/interface, `cea431c37` implemented) and the applied artifact: `spec/03#MEM-13` live, the 09 heartbeat rows live, `learn/04` teaching the mechanism, D-17 recorded.

**Assumptions.** None.

**Attack trace.** None. A reader (or a future increment reviewer) treats the delta as a pending proposal and re-litigates decisions D-17 has already made.

**Fault-model verdict.** N/A.

**Requirement affected.** The review discipline (the frozen snapshot is the artifact under review); D-17's "status: decided; specification, register, index and course changes in flight".

**Suggested repair.** Update the header to "applied at `cea431c37`; the review round owns sign-off", keeping the delta's normative text as the clause-by-clause record.

**Evidence.** `increments/02-heartbeat-design.md` header; `git log` commits above; `spec/03#MEM-13`; `spec/09` heartbeat rows; `learn/04`; `DECISIONS.md` D-17.

---

## F5 — The boundary-halt wording contradicts the in-protocol append/restore path the increment leans on

**Severity: Low.** One-line rationale: the increment's note says a boundary-halt resumption consumes a filtered version, but the sentence immediately after it says the boundary halt "stands until a future protocol update", and LIVE-05's boundary row says "No in-protocol bound … no in-protocol rule can manufacture an entry", while MEM-09(1)/CONS-13(3) make the append permissionless with a lowest-missing restore and CONS-13(5) itself provides the resumption at `h_first(e+1)`. *(Pre-existing converged-v1 wording — it is byte-identical in `cd8386c2c` — but the increment adds its note into the same clause, so the contradiction is now side by side.)*

**File + rule id.** `spec/02#CONS-13`(5) closing sentences: "A late entry may only be used to resume at `h_first(e+1)` if no block of epoch e+1 was ever produced … so the boundary halt stands until a future protocol update whose procedure is not yet specified", next to "(increment 02: … a boundary-halt resumption consumes a version from which a cohort that stopped attesting is already excluded …)"; `spec/10#LIVE-05` "Missing epoch-set entry … No in-protocol bound (CONS-13(5), HALT-01(d)); no in-protocol rule can manufacture an entry"; against `spec/03#MEM-09`(1) ("commitSet() stays permissionless … every entry remains appendable and restorable, so the state is recoverable without a rule change") and `spec/02#CONS-13`(3).

**Assumptions.** None.

**Attack trace.** Not an attack: an interface or runbook tells users a missing-entry boundary halt is permanent until an upgrade and does not surface the permissionless append; or a reader concludes the increment's boundary-halt benefit cannot exist because "the halt stands".

**Fault-model verdict.** N/A (disclosure).

**Requirement affected.** GEN-03; LIVE-05's honesty about halt classes; the increment's boundary-halt claim.

**Suggested repair.** In CONS-13(5), keep "no path may roll back the prefix" but replace "the boundary halt stands until a future protocol update" with "the halt ends when any caller performs the append obligation and the entry becomes Ethereum-final (Open: who pays); only the replacement of unsettled history above the checkpoint needs a future update"; and change LIVE-05's row to "bounded by the permissionless append and its Ethereum finality, conditional on an active entry being eligible; Open who pays".

**Evidence.** `spec/02#CONS-13`(3),(5); `spec/03#MEM-09`(1),(5); `spec/06#HALT-01`(d), `#HALT-02`(b); `spec/10#LIVE-05`.

---

## Checklist charged to this review (all confirmed)

1. **REC-01 unchanged** — its normative text is intact; the increment added an annotation only ("heartbeat eligibility is live but is a selection filter on future set versions, not a history-replacing path"), and the guarantee is explicitly stated unchanged. 06:40-51.
2. **The exit reads no membership record** — MEM-15 and L1-13 are untouched by the increment; MEM-13's own honest-cost note cites MEM-15 only to say the exit is unaffected ((7)(c)); the withdrawal root is a k-attestation of an accepted checkpoint statement, with no eligibility input. The exit's two dependencies remain funding and retrievable inputs (MEM-15(2b)) — unchanged.
3. **D-8/D-9/D-11 untouched** — no heartbeat term, reward or fee appears in 07; the ECON-02(5) participation accumulator is unchanged and remains the reward condition, no longer read for liveness; the publication/deadline rules of D-11 are untouched; the relayer's heartbeat cost is disclosed as unreimbursed (MEM-13(7)(a), 09 unmeasured row).
4. **No weight removed** — MEM-13(4) (exclusion is selection, never decay/discount/zero/removal), the decay tombstones (`T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved`) stay withdrawn, and no offence attaches to not attesting.
5. **No recovery path added** — GOV-04/REC-02 remain tombstones, CONS-16 remains a gated tombstone, and the increment's notes say so repeatedly (CONS-13(5), REC-01, HALT-01, HALT-04, LIVE-05, LIM-01).
6. **Boundary-halt resumption consumes the filtered roster** — stated in CONS-13(5)'s increment note and consistent with MEM-09(1)/(5) and HALT-02(b); **an in-epoch quorum-loss halt is still unrepaired** — HALT-01 and LIVE-05's attrition/simultaneous-stop rows state that the committed roster is immutable and only its return to vote (or a future update) clears it; **the CONS-16 gate is honestly stated** — MEM-13(5)/(6), the CONS-16 tombstone in 02, 09's withdrawn `T_ROTATE`/`T_ROTATE_DELAY` rows, the index rows and DEFERRED §2 all say `h_close` has no L1 referent and the rule MUST NOT be implemented.
7. **Two-epoch lookahead, single evaluation instant** — MEM-09(1) evaluates the predicate "once inside this call, from L1 state at N(k), against the `t_root(e)` this same call writes"; MEM-09(2) stores `setVersionBlock(e) = N(k)` as the roster instant; MEM-13(3) says there is "no second evaluation instant". The instant is single — but caller-selected, which is F1.
8. **No rule reads a withdrawn name** — every occurrence of `T_ROTATE`, `T_ROTATE_DELAY` and `CONS-16` in the snapshot is a tombstone, gating or withdrawal statement (12 + 10 + 55 occurrences checked in context); `T_INACTIVE`, `D_LAPSE_MAX` and `lastObserved` are withdrawn with MUST-NOT-USE reasons (F3 is the stale attribution inside those rows); `HEARTBEAT_MIN_INTERVAL` is registered as a non-normative cadence bound the contract does not read, consistently in 09 and the index.

## Checked, and holds (attacks I ran and could not break)

- **The replay/pre-signing surface.** Every vector in the delta's Appendix B maps to a check: wrong/foreign key and unregistered entry (2a)(a); past/future window (2a)(b); duplicate, replay, out-of-order sequence (2a)(c); re-recorded window (2a)(d); stale, future, zero or forged anchor (2a)(e); partial batch atomicity (2a closing); and the recorded instant is the named window's start, never the carrier's time (2b). The tag bump to `ETNA_HEARTBEAT_V2` closes cross-version replay. I could not find a replay or freshness hole.
- **Key rotation.** Forward-only with a stored rotation block, no reset of the eligibility records, no two entries per key — a rotation cannot launder a stale record into freshness.
- **Exclusion semantics.** Excluded from `R_k`, `TotalVP_k` and `n_k`; effective stake untouched; `SlashBase` per epoch un-restated; re-attestation restores at the next commit point; n = 0 reverts `commitSet()` and is restorable by the lowest-missing rule.
- **The empty-roster revert and the boundary halt.** MEM-13(3)/(7)(e) disclose that an all-ineligible window makes the append miss and the MEM-09(5) halt reachable; F9 names the term that makes it reachable; this is a disclosed liveness cost, not a hidden one.
- **The increment's claimed non-reopening.** The boundary, the exit, D-8/D-9/D-11, no-weight-removal and no-recovery all hold as stated (items 1–5 above).

## Verdict

The increment is safe to ship **only after F1 is repaired**: with the predicate keyed to the caller-chosen commit timestamp, a permissionless caller can compose a version's roster by timing the append at a heartbeat-window start, and the mechanism's own claim that excluding an honest validator requires preventing or delaying its heartbeat is false. F2 must be resolved before activation (one sentence). F3–F5 are wording and status repairs. Everything else on the charge list — REC-01, the exit, D-8/D-9/D-11, no weight removed, no recovery path, the boundary-halt/heartbeat interaction, the single evaluation instant, the CONS-16 gate and the withdrawn names — checks out.
