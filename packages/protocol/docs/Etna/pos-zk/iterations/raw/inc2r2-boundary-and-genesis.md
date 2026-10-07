# Increment 02 re-review — the boundary, the genesis exemption and the reconciled claims

**Reviewer:** independent adversarial reviewer, increment 02 round 2, angle `boundary-and-genesis`.
**Snapshot reviewed:** `7a995f179` (branch `etna-pos-zk`), extracted with `git archive`. Bases: `increments/02-heartbeat-design.md`, `DECISIONS.md` D-17, the round-1 reports `inc2-*.md`, and the implemented `spec/02`, `spec/03`, `spec/06`, `spec/07`, `spec/08`, `spec/09`, `spec/10`, the index and the course.

**Counts: Critical 0 · High 0 · Medium 1 · Low 2.**

**The round-1 High is genuinely closed and the increment is clean at the Critical/High line.** The evaluation instant is now derived and caller-independent (I verified the geometry, the clamp, the late-append direction and the grid-change rules), F5's reconciliation is exactly true, REC-01 / the exit / D-8 / D-9 / D-11 / no-weight-removal are untouched, and no live rule reads a withdrawn name. The Medium is confined to the **genesis transition**: because the clamp sends both of the first two post-genesis versions to the activation window, an adversary that is the first to attest and append can obtain those two rosters; the honest-side duty that prevents it is a runbook item, not a rule.

---

## F1 — The clamp sends the versions for `e_0 + 1` and `e_0 + 2` to the activation window, so the first attester can obtain both rosters before an honest cohort has any heartbeat

**Severity: Medium.** One-line rationale: `C(e) = max(e − LOOKAHEAD_EPOCHS, e_0)` makes both `C(e_0+1)` and `C(e_0+2)` equal `e_0`, so `I*(e_0+1) = I*(e_0+2) = floor(L1_0 / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` — the window containing the **activation block**; the predicate is a lower bound (`lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`), honest entries have no heartbeat before activation, and `commitSet()` is permissionless, so an adversary with active entries and registered keys that lands its own heartbeats and the first two appends before any honest entry's heartbeat is accepted gets two versions whose entire `TotalVP_k` is its own weight. From `e_0 + 3` the reference window advances a full epoch, so an honest cohort attesting once per window qualifies; the exposure is the launch transition, not the steady state.

**File + rule ids.** `spec/02#CONS-14`(1) ("The activation entry's roster is the active bonded set at that block, unfiltered by MEM-13 … The predicate therefore applies from the first `commitSet()` after activation — the entry for `e_0 + 1`, whose evaluation instant is the L1-block-height window containing `L1_first(e_0)` …"); `spec/03#MEM-13`(3) (the `C(e)` clamp and `I*(e)`), `#MEM-13`(2a)(b) (a heartbeat's named window must be the block's current window, so no heartbeat for the activation window can be recorded before it begins), `#MEM-13`(2b) (unset record = 0); `spec/03#MEM-09`(1) (`commitSet()` is permissionless, no arguments, lowest-missing; the first two calls both occur in epoch `e_0`); `spec/03#MEM-08`(5) (`n = 1` is a valid set); `spec/02#CONS-03` (quorum over the version's `W`); `increments/02-heartbeat-design.md` §9 item 8 (still Open: "Whether existing entries must produce a heartbeat before activation at T3 … the announcement must say so").

**Assumptions.** No assumption is broken. The adversary needs (i) one or more active entries at the activation block (public bonding/activation before T3 — the genesis roster is the active bonded set), (ii) its heartbeat key registered at bonding, (iii) its heartbeat transaction(s) accepted in the activation window before any honest entry's, and (iv) the first two `commitSet()` calls — one block of ordering influence (bundle/priority fee) or simply being first if the honest cohort has not started the duty.

**Concrete attack trace.**
1. Before T3 the adversary bonds and activates entries (they enter the genesis roster) and registers heartbeat keys.
2. At the activation block (or the first block after it, in the same heartbeat window `w(L1_0)`), the adversary lands a bundle ordered: `heartbeat(v_i, w(L1_0), …)` for each of its entries, then `commitSet()` twice. Both appends are legal (the lowest missing epochs are `e_0+1` then `e_0+2`, both coverable in epoch `e_0`), and both evaluate the same `I*`.
3. The predicate for each `v_i`: `lastHeartbeatAt(v_i) = w(L1_0) · HEARTBEAT_WINDOW ≥ I*(e) − HEARTBEAT_WINDOW` ✓. For every honest entry: `lastHeartbeatAt = 0` (acceptance requires the named window to be the current one, so no honest heartbeat for `w(L1_0)` can have been accepted earlier than the adversary's, and none exists from a previous window unless the honest side happened to attest pre-activation) → ineligible. The adversary may take the whole window, so honest heartbeats submitted in the same block but ordered later, or in later blocks of the window, are simply too late for these two already-committed versions.
4. The versions for `e_0+1` and `e_0+2` consist only of the adversary's entries: `n_k ≥ 1`, `TotalVP_k` = its own weight, so its share of each version's quorum denominator is 100%; it alone satisfies `3·s > 2·W'` and can finalize conflicting blocks at heights of those epochs — the class INV-01 exists to exclude — with stake below one third of the ledger. Nothing decays or slashes the excluded honest entries, and they re-enter from `e_0+3`; the capture is bounded to two epochs, but it is permanent for them.

**Why the steady state is not exposed (so this is not round 1's attack again).** For every later version `e`, `C(e) = e − 2`, so `I*(e)` is the window containing `L1_first(e−2)`, which lies at or before the first block in which the append may be made; the predicate's one-window slack means an entry that attested in the window before `I*(e)` — i.e. any entry following the registered per-epoch cadence — qualifies no matter which block carries the call, and a later call can only add entries. The caller's block, timestamp and position change nothing (MEM-13(3): "no account chooses it … timing the append can no longer compose the roster"). I verified the geometry for early, on-time and late (lowest-missing refill) appends and for a `HEARTBEAT_WINDOW` change; only the clamped first two versions are exposed.

**Fault-model verdict.** Inside: no assumption fails, no censorship is required (being the first attester and the first caller suffices), and the outcome is a legitimately committed version under the rules. Consequence class: adversarially composed rosters for two epochs and conflicting certified blocks within them. No fund loss through the L1 acceptance path (it stays proof-gated), and the exposure is bounded to the launch transition — hence Medium, not High. I record that if the launch is uncoordinated (no honest attestation before the first append), the capture is not even a race, and the two-epoch consequence is the Critical class; the fix below is one sentence.

**Attacker cost.** Minimum bonds for its entries (refundable), one key registration per entry (at bonding), one heartbeat transaction per entry per window, two `commitSet()` transactions, and one block of ordering influence.

**Requirement affected.** A-CONS-1's per-version framing and D-4/D-7 (voting power and set membership are stake-derived; here the first two post-genesis rosters are derivable by being first rather than by stake); the launch determinism the migration announcement is supposed to provide (delta §9 item 8).

**Suggested repair (any one closes it).** (i) State the duty as a rule/duty rather than an announcement item: every active entry MUST have an accepted heartbeat before the first `commitSet()` after activation (MIG/08 and the announcement), so the launch cannot proceed into a filtered version otherwise. (ii) Or make the first filtered version's reference the window **after** the activation window — `I*(e_0+1) = (w(L1_0) + 1) · HEARTBEAT_WINDOW` — giving an honest cohort a full window to attest before any roster is fixed. (iii) Or have the activation transaction write the first filtered entry as well (a single per-epoch write, which the realisation deliberately avoids — least attractive). I would take (i) with (ii) as a belt-and-braces.

**Evidence.** `spec/02#CONS-14`(1); `spec/03#MEM-13`(2a)(b),(2b),(3); `spec/03#MEM-09`(1); `spec/03#MEM-08`(5); `spec/02#CONS-03`; `spec/09` `HEARTBEAT_WINDOW` (L1 blocks, relation in blocks); `increments/02-heartbeat-design.md` §9 item 8; `spec/08` T3 row (the staking contract reports a non-zero epoch-0 root before T3).

---

## F2 — MEM-13(3) says the reference block is "in the future when the entry is appended"; for a late lowest-missing refill it is in the past, and read as a precondition that sentence would break the boundary-halt recovery

**Severity: Low.** One-line rationale: the sentence is false in exactly the case F5's reconciliation relies on (an entry appended late under the lowest-missing rule), and the same paragraph states the correct invariant later, so an implementer who takes the sentence as a precondition would revert the late append that clears a missing-entry boundary halt.

**File + rule id.** `spec/03#MEM-13`(3): "`L1_first(C(e)) = L1_0 + (C(e) − e_0) · EPOCH_LEN_L1` … a block number fixed once by the schedule the activation transaction records … **and in the future when the entry is appended**, so it is computed from L1 state by arithmetic and never read from a past block"; and, three sentences later in the same paragraph: "Because `L1_first(C(e))` is at or before every block in which the append may be made, `I*(e)` never follows the call". Against them: `spec/03#MEM-09`(1) (the append may be late; the lowest-missing rule refills a skipped epoch later) and `spec/02#CONS-13`(5) (the late append is what clears a missing-entry boundary halt).

**Assumptions.** None.

**Attack trace (no adversary).** An implementer reads "in the future when the entry is appended" as an invariant of the formula and asserts `L1_first(C(e)) > block.number` in `commitSet()`; a refill append for a skipped epoch — the mechanism F5's reconciliation depends on — then reverts, and the boundary halt no longer clears without a protocol update. The semantics themselves are fine: for a late append the reference is simply further in the past, which broadens eligibility (a lower bound) and cannot exclude anyone.

**Fault-model verdict.** N/A (wording/implementability).

**Attacker cost.** None.

**Requirement affected.** MEM-09(1)'s restoration rule; CONS-13(5)'s reconciliation; GEN-03 (one statement, no false invariant).

**Suggested repair.** Delete "and in the future when the entry is appended" (or replace with "a block number fixed by the schedule, computed by arithmetic and never read from a past block"); keep the later, correct "at or before every block in which the append may be made".

**Evidence.** `spec/03#MEM-13`(3); `spec/03#MEM-09`(1),(5); `spec/02#CONS-13`(5).

---

## F3 — CONS-14(1)'s justification for the unfiltered genesis asserts that every record is unset at activation; the migration's own sequencing does not establish that

**Severity: Low.** One-line rationale: T3 requires the staking contract to report a non-zero epoch-0 set root, so the bonding/key surface is live before activation, and no rule disables the heartbeat acceptance path before T3; if it is live, heartbeats can be accepted pre-activation and the stated reason ("at the activation block every record is unset") does not hold. The normative choice (unfiltered genesis) is unaffected — only its rationale is.

**File + rule id.** `spec/02#CONS-14`(1): "no heartbeat can be accepted before the heartbeat key and the acceptance path that MEM-13(1) requires exist, so at the activation block every record is unset and applying the eligibility predicate to the entry for `e_0` would leave `n = 0` — an invalid activation under clause (4)". Against it: `spec/08` T3's precondition "the staking contract reports a non-zero epoch-0 set root" (the staking contract and its entry point exist before the activation transaction); no rule states that heartbeat acceptance is disabled until activation.

**Assumptions.** That the staking contract's heartbeat path is deployed and callable before T3 (implied by T3's own precondition, not stated as enabled or disabled).

**Attack trace (no adversary).** A reader reconciles the justification with the migration sequence and cannot tell whether pre-activation heartbeats are possible; an implementer that enables the heartbeat path with the staking contract makes the justification false (records may be set at the activation block), and one that disables it until activation turns the justification into an extra unstated rule.

**Fault-model verdict.** N/A (rationale).

**Attacker cost.** None.

**Requirement affected.** CONS-14(1)'s precision; the migration's stated sequencing; F2's genesis exemption (which the round-1 review asked to be stated — it is, but with a reason that does not follow).

**Suggested repair.** Replace the causal reason with the policy one: "the activation entry is deliberately exempt: it is the only version with no prior attestation history, and requiring eligibility for it would leave `n = 0`; the predicate applies from `e_0 + 1`", and state in MIG/08 whether heartbeat acceptance is enabled before T3 (which F1's duty also needs).

**Evidence.** `spec/02#CONS-14`(1),(4); `spec/08` T3 row; `spec/03#MEM-13`(1); `increments/02-heartbeat-design.md` §9 item 8.

---

## Checklist charged to this re-review (all confirmed)

1. **The round-1 F1 attack is closed.** The evaluation instant `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` is derived inside `commitSet()` from the activation record, the target epoch and the parameter value in force — no per-epoch write, no oracle, no keeper, no past-block read, and no dependence on the call's block, timestamp or position. The predicate's one-window slack makes it monotone in time, so a call can never remove an entry that was eligible when the entry became coverable; the cadence relation (`HEARTBEAT_WINDOW ≥ EPOCH_LEN_L1 + ceil(T_L1_include(p)/L1_BLOCK_INTERVAL) + margin`, all in L1 blocks) matches the slack, so an entry attesting once per epoch is eligible at every evaluation instant (I checked the geometry for one-per-window and one-per-epoch cadences at the earliest legal call). F8 is sharpened accordingly ("ordering the append ahead of a heartbeat in the same window no longer excludes anyone"), and MEM-13(5)'s exclusion claim now requires suppressing the entry's heartbeat **throughout the window immediately before the fixed instant**.
2. **The clamp and the genesis transition are analysed; only F1 remains.** `C(e)` is exact for `e ≥ e_0 + 3`; for `e_0+1` and `e_0+2` it resolves to `e_0`, which is the launch exposure of F1. A late or refilled append only moves the lower bound further into the past (broader eligibility), never excludes; `L1_first(C(e))` is at or before every block in which the append may be made, so `I*(e)` never follows the call (modulo F2's phrasing); the genesis entry itself is unfiltered by rule.
3. **F5's reconciliation is exactly true.** `spec/02#CONS-13`(5): "a missing-entry boundary halt is not permanent and needs no protocol update: the absent entry stays appendable by any caller under MEM-09(1)'s permissionless lowest-missing rule, and the halt ends when that append is made, the entry is Ethereum-final and the restart rules of HALT-02 let the chain resume — **conditional on an active entry being eligible (MEM-13(3)) and on no block of the affected epoch having been produced**. A block of that epoch produced but not finalized is the one case above the checkpoint that still needs the deferred replacement path". Both conditions are stated; the "no block produced" condition is automatic for a missing-entry halt (MEM-09(5) forbids entering without a final entry) and harmless; the in-epoch quorum-loss halt is separately and correctly stated as clearing on the committed cohort's return or by a future update (MEM-13(5), HALT-01, LIVE-05).
4. **REC-01 unchanged.** Its normative text and guarantee are intact; the increment adds annotations only ("heartbeat eligibility is live but is a selection filter on future set versions, not a history-replacing path … no replacement path is added and REC-01's guarantee is unchanged").
5. **The exit is untouched and reads no membership record.** MEM-15 and L1-13 are unchanged; MEM-13(7)(c) cites MEM-15 only to say the exit is unaffected; no eligibility term enters the withdrawal-root path.
6. **D-8/D-9 and D-11 untouched.** MEM-13(4): "D-7, D-8 and D-9 are untouched"; no heartbeat term, fee or reward appears in 07; the ECON-02(5) participation accumulator is unchanged and remains the reward condition. D-11's publication/deadline rules have no heartbeat interaction.
7. **No weight is removed.** Exclusion is a selection filter (MEM-13(3)–(4)); no decay, discount, zeroing, slashing or offence; the decay tombstones (`T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved`) stay withdrawn; re-attestation restores eligibility with no re-entry, bond or penalty.
8. **No rule reads a withdrawn name.** All occurrences of `T_ROTATE`/`T_ROTATE_DELAY` are withdrawal statements, the D-16 tombstone list, or the register rows (09:356/358 "MUST NOT be used", the change-order-06 note, MEM-13(6) "its own T_ROTATE/T_ROTATE_DELAY relations stay withdrawn … no rule of this page reads it"); `CONS-16` appears only as a gated tombstone; `HEARTBEAT_MIN_INTERVAL` is a live registered non-normative bound the contract does not read; the mechanical scan found no live-context read of any withdrawn name.
9. **The block-height grid is consistent in units.** `HEARTBEAT_WINDOW` and `HEARTBEAT_ANCHOR_AGE` are registered in L1 blocks; `lastHeartbeatAt` is a block number; acceptance compares absolute block heights (2a)(d), so a grid change can never lower a record; the wall-clock variability of the window is stated as an unmeasured honest cost ((7)(g)); and the change-in-flight residual is a disclosed Open with a falsifier and two named closures (MEM-13(6)) — a governance-conduct dependency (A-GOV-1), disclosed rather than hidden.
10. **Round-1 fixes in force.** The absolute-instant acceptance guard ((2a)(d): named window's start strictly later than the record, compared on block heights), the non-zero key and retirement rules, one live entry per bonding address — all present and consistent with the new grid.

## Verdict

**Clean at the Critical/High line: 0 Critical, 0 High, 1 Medium, 2 Low.** The caller-timing composition attack is genuinely repaired — the instant is derived, caller-independent and monotone-safe — and the F5 reconciliation, REC-01, the exit, D-8/D-9, D-11 and the no-weight-removal property all hold exactly as charged. **Safe to ship?** Yes for the mechanism; ship the genesis duty with it: F1 is a launch-transition exposure that one sentence in MIG/08 (or the `I*(e_0+1)` shift in (ii)) removes, and F2/F3 are wording. I would not treat F1 as a reason to hold convergence — it is a launch procedure the design already contemplated (delta §9 item 8) and the rules are self-consistent — but I would not launch without it stated.
