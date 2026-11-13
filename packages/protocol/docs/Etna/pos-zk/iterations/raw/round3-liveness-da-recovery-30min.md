# Round 3 — raw adversarial review: liveness, data availability, censorship, recovery, the 30-minute pipeline

**Reviewer:** fresh independent adversarial reviewer, round 3, assigned angle (iii).
**Snapshot reviewed:** working tree at the round-3 freeze (commit `3b0821f2fbbc21427ed2dee2575db4ad32deecc3`); change order 03 / D-6 applied in place.
**Method:** rules judged as written. In-text `(review round N, finding X)` italics are treated as claims, not evidence. Where a fixed finding could not be re-broken it is listed once as "checked, holds" and not re-litigated.
**Pages attacked:** `spec/06-recovery-exceptions.html` (REC/HALT/WH), `spec/04-l1-integration.html` (L1/DA/FI), `spec/10-assurance.html` (INV/LIVE/LIM), `spec/01-system-model.html` (SYS/ROLE). Cross-read for consistency: `spec/02-consensus.html`, `spec/03-membership-staking.html`, `spec/07-economics-slashing.html`, `spec/09-parameters.html`, `spec/index.html`.

**Counts:** Critical 0 · High 2 · Medium 4 · Low 3.

**Headline:** no Critical could be built. The forced-inclusion removal itself is clean (checked below), the two-epoch lookahead is coherent, and the consensus-only cap does still bound finalized depth under A-CONS-1. The two Highs are in the halt/restart and cap-parameterisation areas: (1) a halt longer than the evidence window silently destroys the economic security of the epochs the chain resumes into and can wedge it permanently; (2) no rule states the joint parameter inequality that keeps a *normal* 30-minute proof from triggering the cap, and one parameter is defined two contradictory ways.

---

## Finding R3-LIV-01 — a halt longer than the evidence window strips the resumed epochs of slashable stake and can wedge the chain permanently

**Severity: High.** One-line rationale: the epoch schedule is a pure function of L2 height while set commitments, exit effectiveness and evidence windows run on the L1 wall clock, and no rule re-anchors or re-derives them when the two clocks diverge across a halt; the resumed heights are then voted by a committed set whose stake may already be withdrawn and whose offences are unpunishable, and an epoch with >1/3 of its weight gone cannot be passed under Mode A.

**Exact rules / missing rule.**
- `spec/02-consensus.html` CONS-13(2): `epoch_of(H)` is a pure function of L2 height; the L2 returns to the epoch it halted in.
- `spec/03-membership-staking.html` MEM-09(1) (03:461-464): "The contract derives the epoch `e` from the L1-committed schedule and **L1 block time alone**", appending the lowest-missing entry (so during a halt the mapping keeps filling with entries for epochs the L2 has not reached). MEM-09(2) (03:476-477): the entry is immutable.
- `spec/07-economics-slashing.html` ECON-07(1) as registered in `09`: `evidenceClose(e) = t_root(e) + W_EVIDENCE`, where `t_root(e)` is the wall-clock `block.timestamp` of the set-root commit (09:109).
- `spec/07-economics-slashing.html` ECON-04 equivocation row (07:304): admissible only if "inclusion block's timestamp ≤ `evidenceClose(epoch_of(H))`, **and the offender still exposed**".
- `spec/03-membership-staking.html` MEM-05(2)-(3) (03:282-298): exit is effective at a later set version; withdrawal requires only that `D_WITHDRAW` has passed **and** that "the evidence window `W_evidence` has closed for every epoch the entry was in". MEM-06(2) (03:344-346): "Slashing is bounded by the bonded balance: the protocol has no claim on assets outside the custody contract."
- `spec/10-assurance.html` INV-03 (10:53-57): "Voting power exists only for stake that is bonded in the L1 staking contract and active in the epoch's set."
- `spec/02-consensus.html` CONS-13(5) / `MEM-09`(5): the halt condition is the entry for the epoch being **entered**; a present-but-stale entry is not a halt condition.
- **Missing rule:** no rule re-anchors, extends or re-derives an epoch's evidence window when the epoch's heights are produced after `evidenceClose(e)`; no rule forbids withdrawal of stake that is still committed to an epoch whose heights have not been produced; no rule lets a resumed chain skip or re-derive a stale committed epoch (REC-01/HALT-02 forbid both rewriting and skipping).

**Assumptions and preconditions.** A settlement halt (F1: prover outage, sustained L1 censorship of `land` transactions) that lasts longer than `W_EVIDENCE` (ECON-07(4)'s lower bound is already `≥ 3·E_EPOCH + T_PROOF_MAX_PERMITTED + …` ≈ 2.5 h at the proposed `E_EPOCH = 1800 s`, so this is a single shift-length outage). Permissionless exits are then requested and become effective at later set versions. Nothing else is assumed; no adversary is needed for the liveness half.

**Worked trace.**
1. Epoch `e0` is in progress at `t0`; `mapping[e0]`, `mapping[e0+1]` exist and `mapping[e0+2]` was appended during `e0` on the L1 clock (CONS-13(3), MEM-09(1)). Each has `t_root(e) ≈ t0 − 30/60 min`.
2. Settlement stops (no batch lands). The L2 keeps producing until the unsettled-depth cap binds, then halts (HALT-01(e), HALT-03). The halt lasts **24 h**; Mode A fixes no maximum halt duration and HALT-02 forbids discarding the finalized prefix.
3. During the halt `commitSet()` is still permissionless and L1-clock driven, so entries for `e0+1, e0+2, …` have long been appended (MEM-09(1) "lowest-missing"). Every one of those epochs now satisfies `t_root(e) + W_EVIDENCE < t0 + 24 h`, i.e. its admissible-evidence interval has closed **before any of its heights exist** (ECON-07(1), ECON-04 row).
4. A validator in `e0+1` requests exit during the halt; the exit is effective at a later set version and, because every window is closed and no exposure remains, the stake is withdrawable (MEM-05(2)-(3), MEM-06(2)) — while `mapping[e0+1]` still lists it (MEM-09(2), immutable).
5. Settlement resumes at `t0 + 24 h`. The chain resumes at the halted height and, per CONS-13(2), must next enter `e0+1` and collect `>2/3` of **that committed set's** weight (CONS-03). New, healthy validators who bonded during the halt are in the entries for `e0+3` and later; the L2 cannot reach them until `e0+1` and `e0+2` finalize, and no rule permits skipping (REC-01, CONS-13(2)). MEM-11(2) independently blocks fresh entry and fresh-node bootstrap once the L1 checkpoint is older than `WS_MAX ≤ T_PROOF_MAX_PERMITTED + M − M_ws` (i.e. after a halt of this length).
6. **Liveness outcome:** if >1/3 of `e0+1`'s committed weight has exited and gone offline, no quorum can ever form at `e0+1`, and the chain is permanently halted although the current L1 stake ledger holds a healthy, fully-bonded validator population. The safe halt is not caused by an assumption failure at the resumed epoch; it is caused by the design's own two-clock divergence.
7. **Security outcome (same bug, malicious variant):** if instead that >1/3 stays online, it can sign conflicting values at a post-halt height of `e0+1`; the same-`(H,R)` conflicting pair is exactly the evidence object CONS-11 admits, but its inclusion timestamp cannot be `≤ evidenceClose(e0+1)`, so ECON-04 makes it inadmissible and MEM-06(2) has no claim on the withdrawn stake. INV-03's "no consensus without TAIKO at risk" and CONS-09/M2's "objectively slashable" are false for every height produced after a window closes.

**Inside/outside the claimed fault model.** Liveness branch: **inside**. The trigger is a permitted F1 halt plus exits that MEM-05 explicitly permits; the failure is that a rule-legal halt destroys resumability, which is a design defect, not an assumption failure. Security branch: **at the boundary** — it needs >1/3 of one committed epoch's weight to equivocate, but that weight is no longer bonded, so A-CONS-1's premise ("the stake that counts toward quorum") is void rather than satisfied; the specification itself claims the stake is slashable (INV-03, ECON-04), so the claim is broken inside the regime the spec describes.

**Attacker resources and cost.** Liveness branch: zero — a prover outage and ordinary exit requests suffice. Security branch: keys of >1/3 of one committed epoch's weight, obtainable from validators who exercised the exit path the rules permit; cost = forgone future rewards, **no slashable exposure** (the evidence window is closed and the assets are outside custody). Compare A-ECO-1: the deterrence term E[Slash] is zero in this state.

**Harm and affected requirements.** Permanent safe halt with a healthy bonded set (R6's "exact conditions where liveness ends" is not stated for this case); unpunishable equivocation and loss of the slashable-collateral guarantee (R11); broken `INV-03`, `ECON-04`'s "offender still exposed", `ECON-07(4)` (which already calls an empty admissible interval "a defect, not a tuning choice"), and the Mode A promise that halting is *safe* (D2): halting is exactly what removes the economic security of the resumed epochs.

**Evidence.** `spec/03-membership-staking.html`:461-464, 476-477, 282-298, 344-346; `spec/07-economics-slashing.html`:304, 470-473, 487-500, 539-542; `spec/09-parameters.html`:108-109; `spec/02-consensus.html`:416-452, 441-448; `spec/10-assurance.html`:53-61; `spec/06-recovery-exceptions.html`:49-90.

---

## Finding R3-LIV-02 — the D_MAX derivation and LIVE-02's 30-minute promise are not jointly constrained, and `T_PROOF_MAX_PERMITTED` is defined two contradictory ways

**Severity: High.** One-line rationale: HALT-03's cap formula and LIVE-02's normative sentence "a normal proof inside the D6 envelope must never trigger (a)" are satisfiable together only under an inequality that is stated nowhere, while `09` explicitly decouples (and MEM-05 explicitly equates) `T_PROOF_MAX_PERMITTED` from the D6 envelope — so a conforming parameter choice halts production on a normal 30-minute proof and breaks D6/D1.

**Exact rules / missing rule.**
- `spec/06-recovery-exceptions.html` HALT-03 (06:92-123): `D_MAX = floor((RETENTION_WINDOW − T_PROOF_MAX_PERMITTED − T_SETTLE_PIPELINE) / L2_BLOCK_INTERVAL)`; validators "must not prevote or precommit a block whose unsettled depth would exceed `D_MAX − MARGIN_V`"; `MARGIN_V` "is at least the number of L2 blocks produced during one Ethereum finality depth".
- `spec/10-assurance.html` LIVE-02 (10:105-113): "A normal proof inside the D6 envelope (up to 30 minutes, 900 blocks at 2 s) **must never trigger (a)**, (b) or any recovery action."
- `spec/09-parameters.html`:104 (`T_PROOF_ENVELOPE = 1,800`), :106 (`D_MAX` formula, "No numeric value is proposed: the inputs are unmeasured"), :119 (`T_PROOF_MAX_PERMITTED` "Unset; the maximum proving latency the protocol permits … it is not D6's `T_PROOF_ENVELOPE`, which is a planning assumption and not a bound"), :124 (`MARGIN_V` unset), :120 (`RETENTION_WINDOW` unset).
- `spec/03-membership-staking.html`:319 defines the **same parameter** as "sourced as a design constraint D6 (minutes up to 30 min = 900 L2 blocks at 2 s, derived)".
- **Missing rule:** no inequality tying `T_PROOF_MAX_PERMITTED` to `T_PROOF_ENVELOPE`, and no lower bound on `RETENTION_WINDOW` (or on `D_MAX`) that makes a full-envelope proof fit below `D_MAX − MARGIN_V`. The relation needed is approximately `D_MAX − MARGIN_V ≥ (T_PROOF_ENVELOPE + T_SETTLE_PIPELINE)/L2_BLOCK_INTERVAL` (plus the batch length), equivalently `RETENTION_WINDOW ≥ 2·(T_PROOF_ENVELOPE + T_SETTLE_PIPELINE) + 2·MARGIN_V·L2_BLOCK_INTERVAL`.

**Assumptions and preconditions.** Only D6-compliant values and rules already written. Every input is marked `unmeasured`, so the choice below conforms to PARAM-01's discipline; ECON-07(7)(a) (07:536-539) confirms that for ECON-04's closed catalogue no backlog term couples `D_MAX` to the evidence window.

**Worked counterexample (two parameter sets).**
- `Δ = 2 s`, `T_PROOF_MAX_PERMITTED = 1800 s`, `T_SETTLE_PIPELINE = 900 s`, `MARGIN_V = 384` (one Ethereum finality depth ≈ 64 slots × 6 L2 blocks/slot, which HALT-03 mandates as a minimum).
 - `RETENTION_WINDOW = 3600 s` (a natural "the window must cover the envelope" choice): `D_MAX = floor((3600−1800−900)/2) = 450` and validators stop at depth **66**. A single batch whose proof consumes the permitted 30 minutes leaves the checkpoint `1800/2 = 900` blocks behind the tip; honest validators therefore refuse to vote after ~2 minutes, production halts for ~25 minutes, and LIVE-02's own sentence is false. Recovery happens when the proof lands, so the harm is a repeated, rule-legal production stop, not loss of funds.
 - `RETENTION_WINDOW = 3000 s`: `D_MAX = 150 < MARGIN_V = 384`, so `D_MAX − MARGIN_V` is negative and **no block at depth > 0 may ever be voted**. The chain cannot produce its second block. Nothing in HALT-03/09 states `D_MAX > MARGIN_V`.
 - The smallest `RETENTION_WINDOW` that honours LIVE-02 with these numbers is ≈ 6,240 s (≈ 104 min); that requirement appears in no rule.

**Inside/outside the claimed fault model.** **Inside.** No adversary and no assumption failure: a normal-operation 30-minute proof (D6) plus parameters chosen within the written constraints.

**Attacker resources and cost.** None. A griefer is not needed; ordinary slow-but-normal proving triggers the halt.

**Harm and affected requirements.** Breaks **D6** ("L2 keeps producing 2 s blocks and reaching the selected mode's PoS confirmation throughout" a 30-minute proof) and **D1/R4** cadence; contradicts **LIVE-02** and the HALT-03 claim that a full-envelope proof "is not misconduct and not grounds for any recovery action"; leaves the joint satisfiability the reader is told to rely on to be invented by the implementer (R13).

**Evidence.** `spec/06-recovery-exceptions.html`:92-123; `spec/10-assurance.html`:105-117; `spec/09-parameters.html`:94-135; `spec/03-membership-staking.html`:316-321; `spec/07-economics-slashing.html`:530-557.

---

## Finding R3-LIV-03 — the censorship statement leans on an inclusion policy that no rule defines

**Severity: Medium.** One-line rationale: LIVE-04/FI-REMOVED-01 and the rotation argument assert that a transaction reaching honest validators "is included by the first honest proposer with room for it" and that "lateness is bounded by the selection rule", but no rule imposes any inclusion duty, block-space reservation, ordering or fee policy, and the disclosed limitation covers only network isolation; an implementer must invent the policy the statistical claim presupposes.

**Exact rules / missing rule.**
- `spec/10-assurance.html` LIVE-04 (10:136-148) and `spec/04-l1-integration.html` FI-REMOVED-01 (04:531-536) plus the rotation argument (04:538): "A transaction that reaches honest validators is included by the first honest proposer with room for it … The coalition's residual power is to make inclusion *late*, not to prevent it, and lateness is bounded by the selection rule".
- `spec/01-system-model.html` ROLE-01(b) (01:374): "No inclusion duty attaches to a validator: a proposer includes what the objective rules admit, and omitting a particular transaction is neither a proposal-validity failure nor an offence."
- `spec/02-consensus.html` CONS-01 (02:72): proposal validity has no inclusion condition; CONS-06 line 207 repeats the same claim.
- **Missing rule:** nothing defines "room", what an honest proposer must include, or how block space/fees are allocated; `LIM-01`'s censorship row discloses only the network-isolation adversary.

**Preconditions / counterexample.** No adversary assumption beyond the fault model. A coalition with, say, 30 % of the stake never needs to isolate the victim: it occupies the block space it proposes (a fifth of the chain under K=32-block batches) with its own fee-paying transactions and outbids the target, and any congested period has the same effect. Because omission is expressly not an offence and proposal validity contains no inclusion condition (ROLE-01(b), CONS-01), "the first honest proposer with room for it" is undefined and inclusion can be prevented indefinitely at a cost far below the network-isolation scenario the specification discloses. The claim "lateness is bounded by the selection rule" is therefore unsupported: lateness is bounded by block space and the (unspecified) mempool policy, not by proposer rotation.

**Inside/outside.** Inside (no assumption is needed; congestion or a paying coalition suffices). **Attacker cost:** the fees for the block space it already controls, or zero under congestion. **Harm:** R10's relaxed obligation is to state the resistance honestly, including what it is conditional on; R13 (implementer must invent the inclusion/ordering policy that the claim depends on). **Evidence:** `spec/10-assurance.html`:136-154, 173; `spec/04-l1-integration.html`:531-538; `spec/01-system-model.html`:374, 507-544; `spec/02-consensus.html`:64-82, 196-210.

---

## Finding R3-LIV-04 — LIM-01, the "stated once" limitations register, is missing the rows other rules delegate to it

**Severity: Medium.** One-line rationale: LIM-01 claims to be the single register of known limitations, yet three normative rules delegate a disclosure to it and the corresponding rows do not exist, so the register is incomplete in exactly the places that qualify R10's and R5's honesty.

**Exact rules / missing rule.**
- `spec/10-assurance.html` LIM-01 (10:158-186): "The following limitations are accepted and disclosed … none may be presented elsewhere as a strength, and none may be silently dropped". Its table has crypto/consensus (2 rows)/availability/liveness/censorship/performance/economic/governance/migration/scope rows.
- `spec/06-recovery-exceptions.html` HALT-03 (06:106-110) states the cap "cannot be enforced at L1 … a quorum that ignores it is **not** objectively punishable at L1 … disclosed rather than a slashing offence (`WH-02`, `LIM-01`)" — no LIM-01 row mentions the cap, `D_MAX`, or unpunishable cap violations.
- `spec/02-consensus.html` CONS-06 (02:207): "the next proposer is predictable far in advance; the disclosure obligation for that predictability, and any mitigation, belong to `LIM-01`" — no LIM-01 row mentions predictability or slot-buying.
- `spec/02-consensus.html`:286-287 and :397-399: cross-round/cross-epoch divergence under withholding may be unpunishable and "the limitation row for it is **owed** to the `LIM-01` register" — again no row.
- **Missing rule/row:** the three limitations above (and, adjacent to this angle, the halt-induced evidence-window lapse of R3-LIV-01) are absent from the register.

**Assumptions and preconditions.** None; a text-level check.
**Trace:** a reader who accepts LIM-01 as complete (its own norm says limitations are stated once there) will not learn that cap violations have no penalty, that proposer slots are predictable and purchasable, or that some divergences are unpunishable — all of which qualify how much resistance R10 and R5 actually provide.
**Inside/outside.** Inside (documentation/honesty defect). **Attacker cost:** n/a. **Harm:** R10 (honest statement of the relaxed resistance), R13, LIM-01's own completeness claim. **Evidence:** `spec/10-assurance.html`:158-186; `spec/06-recovery-exceptions.html`:99-110; `spec/02-consensus.html`:204-207, 283-287, 394-399.

---

## Finding R3-LIV-05 — Mode B contradicts L1-04/L1-06/REC-01 and no rule scopes those MUSTs to Mode A

**Severity: Medium.** One-line rationale: the fallback the architecture decision requires to remain implementable cannot be selected without violating unconditional normative rules ("any account MUST be able to land an unsettled range"; "no function in any mode — including a recovery path — may decrease `lastLandedHeight`"), and REC-02 does not say which Mode A rules it supersedes.

**Exact rules.**
- `spec/04-l1-integration.html` L1-04 (04:98-103): "For any unsettled range, any account that can produce a valid `(data, proof)` pair MUST be able to land it."
- `spec/04-l1-integration.html` L1-06 (04:202-203): "No function in **any mode** — including an upgrade initialiser, **a recovery path**, or a governance call — may decrease `lastLandedHeight`, replace or delete a checkpoint record at a height ≤ the current one…".
- `spec/06-recovery-exceptions.html` REC-01(b) (06:34-35): "no admission rule may reject a batch that extends the current L1 checkpoint (L1-04)".
- `spec/06-recovery-exceptions.html` REC-02 (06:245-253): "Late proofs: A proof whose batch lies above the restored checkpoint is void: its predecessor no longer exists"; recovery restores the L1 checkpoint and history above it is replaced.
- **Missing rule:** REC-02 does not state that L1-04/L1-06/REC-01(b) are Mode-A-only, nor does any rule give the Mode B admission predicate that must replace L1-04.

**Preconditions.** Selecting Mode B under the D2 procedure (not selected today; `04-architecture-decision.md` §5.4 requires that Mode A not be designed so the fallback is unimplementable).
**Trace.** A settlement stall triggers recovery; the restored checkpoint is `C`. A prover holds a valid `(data, proof)` batch extending the pre-recovery checkpoint `C' > C` (its range starts at `C'+1`). L1-04 says L1 **must** accept it; REC-02 says it is void. Both are normative. Likewise L1-06 forbids the pointer movement that any replacement of already-accepted records would require.
**Inside/outside.** Conditional on Mode B selection; outside the active mode. **Attacker cost:** n/a. **Harm:** D2's fallback-readiness obligation; R13 (an implementer selecting Mode B must invent the scope of L1-04). **Evidence:** `spec/04-l1-integration.html`:98-110, 197-208; `spec/06-recovery-exceptions.html`:28-45, 236-258; `04-architecture-decision.md` §5.4.

---

## Finding R3-LIV-06 — ECON-07(7) still describes an L1 rejection of over-depth batches, which HALT-03/L1-06 forbid

**Severity: Medium.** One-line rationale: a normative-looking clause states that HALT-03 "rejects a batch whose depth exceeds `D_MAX`", i.e. the L1 admission check that was deleted and that L1-04/L1-06 explicitly prohibit; an implementer following it strands legitimately finalized history.

**Exact rules.**
- `spec/07-economics-slashing.html` ECON-07(7) (07:531-532): "`HALT-03` permits production to run ahead of the highest L1-accepted checkpoint by up to `D_MAX − MARGIN_V` L2 blocks **and rejects a batch whose depth exceeds `D_MAX`**…".
- `spec/06-recovery-exceptions.html` HALT-03 (06:96-98): "**Exactly one enforcement point: the validators.** `land` MUST NOT reject an over-depth batch, because doing so could make a legitimately finalized range permanently unlandable and would violate L1-04".
- `spec/04-l1-integration.html` L1-06 (04:199-201) and L1-04 (04:104-105): the same prohibition; the change order claims "the L1 rejection [was] deleted".

**Preconditions.** An implementer derives the admission checks from the coupling clause (it is the only place ECON-07 mentions the cap's enforcement).
**Trace.** A batch is finalized at depth `D_MAX + 1` by a quorum that ignored the cap (the same quorum HALT-03 says is not punishable). Under L1-04/L1-06 it must land; under ECON-07(7) it is rejected at `land`, and the range becomes permanently unsettleable — the Mode A violation (D2) that HALT-03 exists to prevent.
**Inside/outside.** Inside (design-text contradiction). **Attacker cost:** none; the harm occurs through honest implementation of the wrong clause. **Harm:** D2, R9, L1-04; a security-relevant rule with two contradictory readings. **Evidence:** `spec/07-economics-slashing.html`:530-542; `spec/06-recovery-exceptions.html`:92-110; `spec/04-l1-integration.html`:98-110, 197-208.

---

## Finding R3-LIV-07 — HALT-03's mandated cap/evidence-window coupling is vacuous for every offence in the closed catalogue

**Severity: Low.** One-line rationale: the coupling inequality is conditioned on "an offence that requires the accepting batch's own data", but ECON-04's closed catalogue contains no such offence, so HALT-03's instruction to reduce `D_MAX` "until it holds" (P-R2-08) has no object.

**Rules.** `spec/07-economics-slashing.html` ECON-07(4) (07:498-500) and (7)(b) (07:539-542); ECON-04 (07:300-335) lists exactly equivocation (same-`(H,R)` conflicting pair), the lock-rule pair (defined as the same object) and invalid evidence. `spec/06-recovery-exceptions.html` HALT-03 (06:111-114) says the cap "must also be jointly satisfiable with the evidence window: the coupling inequality is stated normatively in ECON-07(7), and `D_MAX` must be reduced until it holds". **Preconditions:** none. **Trace:** read literally, the reader is sent to reduce `D_MAX` for an inequality that (a) is discharged automatically for the catalogue (ECON-07(7)(a)) and (b) applies only to a hypothetical offence class. **Inside/outside:** inside (reviewability). **Harm:** R13 (misleading normative instruction), traceability of the round-2 fix. **Evidence:** as above.

---

## Finding R3-LIV-08 — DA-06's window comparison depends on a fixed L1 slot duration that GEN-06 forbids

**Severity: Low.** One-line rationale: DA-06 requires `RETRIEVABILITY_WINDOW` (L1 blocks) to be "converted to seconds at Ethereum's **fixed** slot cadence" to dominate `W_EVIDENCE` (seconds), while GEN-06 forbids any normative rule depending on a fixed L1 slot duration; a change in Ethereum's slot timing silently breaks the bound.

**Rules.** `spec/04-l1-integration.html` DA-06 (04:519-521); `spec/index.html` GEN-06 (index:122-127); `spec/09-parameters.html`:122 (`L1_BLOCK_INTERVAL` "a parameter, not a rule: GEN-06 forbids depending on a fixed L1 slot duration … no validation rule may read a hard-coded slot length"). **Preconditions:** Ethereum changes its slot duration (or its blob-retention epoch length); the registered value must then be re-derived, which no rule ties back to DA-06. **Trace:** `RETRIEVABILITY_WINDOW` fixed at N L1 blocks; the slot interval halves; N·interval < W_EVIDENCE; the archive duty no longer covers the evidence window, and nothing in the design detects it. **Inside/outside:** inside (R12/GEN-06 compliance). **Harm:** R12, R8-adjacent auditability; the bound is stated in a unit whose conversion is mutable. **Evidence:** as above; compare DA-05(a) (04:495).

---

## Finding R3-LIV-09 — HALT-03's MARGIN_V justification is inverted and the depth definition is view-dependent

**Severity: Low.** One-line rationale: SYS-02 forces validators to consume only Ethereum-final L1 facts, so the newest checkpoint a validator may use is the same as or **older** than the true `lastLandedHeight`; measuring depth from it therefore **over**-estimates depth, not under-estimates it as HALT-03 claims, and the rule never says which checkpoint the bound is evaluated against.

**Rules.** `spec/06-recovery-exceptions.html` HALT-03 (06:103-106): "`MARGIN_V` is mandatory and is at least the number of L2 blocks produced during one Ethereum finality depth, because a validator's view of the L1 checkpoint is itself only usable at that depth (SYS-02); without the margin a validator can **systematically under-estimate** depth and overshoot the cap." `spec/01-system-model.html` SYS-02(b) (01:182-188): only Ethereum-final facts are admissible. **Preconditions:** none. **Trace:** the validator's usable checkpoint `C_final ≤ lastLandedHeight`; its estimate `H − C_final ≥ H − lastLandedHeight`; the error direction is conservative. An implementer cannot tell whether to measure from `lastLandedHeight` (unknowable without finality) or from `C_final`, so the numeric halt point differs per validator. **Inside/outside:** inside (clarity/liveness). **Harm:** R13; the only exposure-bounding rule's evaluation point is not fixed. **Evidence:** as above.

---

## Checked and confirmed fixed (not re-listed)

- **Forced inclusion removed (D-6) — R2-LIV-01, R2-LIV-03, R2-LIV-04 closed by deletion.** No residual rule assumes an inclusion guarantee or imposes an inclusion duty: `CONS-01` has no inclusion clause (02:72), `ROLE-01`(b) says so explicitly (01:374), the admission loop bounds list no coverage list (04:103), L1-05 keeps row 20 vacant and no drift/dueness rule remains (04:142, 160), ECON-04's closed catalogue has no censorship/omission offence (07:324-330), `WH-02` states it (06:168-171), and `index.html` records the tombstone (index:259-263). The only defect found is the unstated inclusion *policy* behind the statistical claim (R3-LIV-03).
- **R2A-01 two-epoch lookahead holds as written.** CONS-13(3) keys the commit to the L1 clock and forbids keying it to the Inbox height; MEM-09(1) repeats it; CONS-13(5)/MEM-09(5) make only the *entered* epoch's entry a halt condition. I could not re-break the boundary stall. (The genesis one-epoch-short boundary is disclosed in CONS-14(3) and is a one-time, resumable halt.)
- **R2-LIV-07 / R2-LIV-08 one cap, one unit, one enforcement point holds** in HALT-03/L1-06/DA-06; `MAX_UNSETTLED_AGE` is deleted and `RETRIEVABILITY_WINDOW` is correctly a different object in a different unit (04:507-527). The remaining defects are the ECON-07(7) contradiction (R3-LIV-06) and the vacuous coupling (R3-LIV-07).
- **The consensus-only cap still bounds finalized depth under A-CONS-1:** a block past `D_MAX − MARGIN_V` cannot obtain >2/3 precommits while correct validators obey HALT-03, and `land` accepting a deeper batch does not retroactively increase the finalized depth; the honest cost (no objective evidence, no penalty) is stated correctly in HALT-03 and is consistent with L1-04/L1-06. Only its LIM-01 row is missing (R3-LIV-04) and its parameterisation is unconstrained (R3-LIV-02).
- **LIVE-03(i) parity/deadlock:** the former round-2 open item does not survive as written — at rate parity the cap stops production, so the backlog drains (LIVE-02(a)/HALT-03); no deadlock could be built.
- **REC-02's derived rollback depth ≤ `D_MAX`** is consistent with `MARGIN_V` ≥ one Ethereum finality depth (the accepted-but-not-final range plus the unsettled depth is ≤ `D_MAX`), and its "conditional, not a bound on loss" caveat is honest.
- **HALT-04 / REC-01 no-rescue and no-data-first structure, and LIM-02's rejection of Mode B with REC-03's blocker**, are internally consistent; the D5 obligations are preserved in REC-02's "obligations it must still satisfy" row.
