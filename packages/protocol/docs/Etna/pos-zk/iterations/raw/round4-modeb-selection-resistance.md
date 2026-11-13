# Round 4 — raw adversarial review: the Mode B selection (D-7) and REC-01/02/03 resistance analysis

**Reviewer:** fresh independent adversarial reviewer, round 4, assigned angle (v) — the decision-required review of the Mode B selection (D2 §7.1 step 5).
**Snapshot reviewed:** working tree at the round-4 freeze, commit `fe7373a1310900ffd66c72e63d682ce81359d6e0` (clean tree), i.e. change order 04 applied in place: D-7 Mode B selected, D-8 fee-funded security, D-9 treasury, D-10 forced inclusion deferred.
**Method:** rules judged as written. In-text `(review round N, finding X)` and `(D-7)` italics are treated as claims, not evidence. Citation convention: `NN:line` = `spec/NN-*.html` line; `01:line` = `01-requirements-and-threat-model.md`; `D-n` = `DECISIONS.md`.
**Pages attacked:** `spec/06-recovery-exceptions.html` (REC-01/02/03, HALT, WH-02/04), `spec/09-parameters.html` (recovery parameter rows), `spec/04-l1-integration.html` (L1-04/05/06/10/11/12, DA-06, MSG-03), `spec/10-assurance.html` (INV-01, LIVE-01, LIM-01), `spec/index.html` (STATUS-04/06/07/11), `spec/07-economics-slashing.html` (ECON-02, ECON-06, ECON-11). Cross-read: `01`, `DECISIONS.md` D-6–D-10, `iterations/03-round.md`, `iterations/04-change-order.md`.

**Counts: Critical 2 · High 4 · Medium 3 · Low 0.**

**Headline.** The D2 step-5 obligation is **not discharged**, and the specification itself shows why: REC-03's resistance claim is premise-contained (it holds only while A-DA-2 and A-L1-1 hold, and the trigger *is* their failure), it quantifies nothing, and it answers a question the trigger does not ask — the trigger needs prover-market or landing-market control, not one third of the L2 stake. On the mechanics, recovery has no defined completion entry point or L1 depth, so a rule-legal landing in the inclusion→finality window produces an L1 checkpoint that the recovery must revoke, or a recovery that is silently void — the two-canonical-histories case the D2 procedure exists to exclude. The bond schedule is mispriced the wrong way round (free on success, costly only on failure; unbounded 2^n on honest use). **Verdict: the selection is NOT adequately established; the D2 step-5 blocker still stands as a blocker.**

---

## Finding R4-MB-01 — the D2 step-5 resistance obligation is not met: REC-03 quantifies nothing and answers a different question than the trigger asks

**Severity: Critical.** One-line rationale: D2 §7.1(5) requires Mode B to *show*, with **quantified attacker resources, penalties and rollback exposure**, that a sub-threshold coalition cannot cheaply trigger a recovery that replaces honestly confirmed history, and it states that inability to establish this is a **blocker, not a disclosure item**; REC-03 supplies no quantity at all, every recovery parameter is tagged `unmeasured`, and the specification converts the blocker into LIM-01 disclosure rows — while REC-03's own text concedes that the only induction paths it recognises (suppress every prover, or censor the landing transaction at L1) are excluded by assumption.

**Exact rule / missing rule.**
- `01:264-267` (D2 step 5, normative procedure): "Mode B must additionally show that, within the stated normal-operation assumptions, an ordinary malicious leader or sub-threshold coalition cannot cheaply trigger a recovery that replaces honestly confirmed history — with **quantified attacker resources, penalties and rollback exposure**. Inability to establish this is a **blocker, not a disclosure item**."
- `01:256-257` (D2 step 2's evidential bar): "Missing research, **unmeasured performance**, elapsed time or review-budget exhaustion do not count."
- `iterations/04-change-order.md:11-15` (the change order that was applied): "Rewrite REC-03 … **quantify what it costs to induce the trigger**, show that within the L2 fault model a sub-threshold coalition cannot …".
- `06:384-418` (REC-03) contains no number, no inequality and no bound: "Therefore batches keep landing, T_STALL never elapses, and a sub-threshold coalition **cannot induce the trigger**"; "an attacker must suppress *every* prover or censor the landing transaction at L1 — both outside the L2 fault model"; "the escalating bond and the cooldown make this *expensive* but **do not bound**".
- `09:143-148`: T_STALL, T_RECOVERY_MARGIN, T_RECOVERY_DELAY, B_REC_BASE, REC_WINDOW, REC_COOLDOWN — every one `unmeasured`, with no relation to rollback exposure (the value that can be discarded is up to `D_MAX` blocks × per-block value; no rule and no parameter ties B_REC to it).
- Missing rule: a quantified bound of the form "the expected cost of an attempt that completes is ≥ X, and X ≥ the attacker's expected gain from any range within D_MAX blocks" — or, failing that, the D2 re-opening the procedure mandates.
- `10:238-240` (LIM-01) discloses recovery as a priced manipulation primitive and an unbounded "stop-and-restart" pattern. That is exactly the conversion D2 step 5 forbids.

**Assumptions and preconditions.** None beyond the spec's own parameter table and its own premise set.

**Concrete trace (why the claim is premise-contained).** (1) REC-03's premises are A-CONS-1, A-CONS-2, A-DA-2 and A-L1-1 (06:385-391). A-DA-2 asserts "at least one honest, adequately-resourced prover completes each committed batch's proof within the assumed envelope"; A-L1-1 asserts L1 includes valid transactions within a bounded time. (2) The trigger is "no batch extending the current L1 checkpoint has been accepted for T_STALL". (3) Under (1), a batch always lands within the envelope and T_STALL = T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + T_RECOVERY_MARGIN > the envelope, so the trigger never fires. (4) The conclusion "cannot induce the trigger" is therefore a restatement of the premises, not a resistance result: the adversary class for which recovery exists (prover outage, landing failure, unavailable data) is excluded *by definition* from the analysis. (5) The trigger's reachability is governed by the prover/landing market (threat T-9 in `01` §6.3, plus fee-market outbidding), not by the 1/3 stake threshold — a coalition with **zero** L2 voting power that controls proof supply or outbids landing can cause the discard of PoS-finalized history, and pays no bond at all when the recovery it causes completes (R4-MB-04).

**Inside/outside the claimed fault model.** The *claim* is inside by construction and therefore vacuous; the *induction paths* are outside (A-DA-2 / A-L1-1 failure), which is precisely why the claim cannot support D2 step 5. No Byzantine stake is needed at any point.

**Attacker resources and cost.** Unmeasured by the specification: B_REC_BASE, REC_WINDOW, T_RECOVERY_DELAY, REC_COOLDOWN and every T_STALL term are `unmeasured` (09:143-148). The only cost stated anywhere is qualitative ("expensive", 06:401).

**Harm and affected requirement.** The Mode B selection's mandatory pre-condition (D2, a fixed decision in `01` §1 and in `README`'s fixed-decision table) is not established; R5's "selected mode's confirmation guarantee" is therefore argued, not evidenced; `README` and `D-7` ("D2 procedure, completed", D-7:259-267) claim a completion the record does not support; change order 04 §1's explicit quantification requirement is unmet.

**Evidence.** `01`:256-257, 264-267; `DECISIONS.md`:259-267; `iterations/04-change-order.md`:11-15; `06`:384-418; `09`:143-148; `10`:238-240.

---

## Finding R4-MB-02 — no completion entry point and no L1 depth: a rule-legal landing in the inclusion→finality window yields an accepted checkpoint the recovery must revoke, or a recovery that is void

**Severity: Critical.** One-line rationale: REC-02 says the recovery "takes effect only after T_RECOVERY_DELAY" but never says *who* completes it, whether the effect is an L1 transaction, or at what depth L2 must adopt it; SYS-02 forces L2 to consume only Ethereum-final L1 facts, so there is a window in which L1 still accepts a batch for the discarded range (a fresh proof under the new generation is valid — the generation binds the proof, not the history, since block headers and certificates carry no generation) while the recovery requires the chain to be at the restored checkpoint; REC-01/STATUS-06 then forbid revoking that accepted batch and L1-06 forbids decreasing `lastLandedHeight`, so the two rule sets cannot both be satisfied.

**Exact rule / missing rule.**
- `06:359` (REC-02, Delay and cancellation): "The recovery takes effect only after `T_RECOVERY_DELAY`. During that window it is cancelled by the acceptance of **any** valid batch extending the current checkpoint." No completion caller, no atomicity with the bond refund and the generation increment, no L1 depth.
- `01-system-model.html`:179-199 (SYS-02): "An L2 block may consume an L1 fact only if … every validator that votes for the block has established that the fact is Ethereum-final for itself at vote time." A recovery-completion storage value/log is such a fact; its adoption is therefore at finality depth, i.e. up to L1_FINALITY after inclusion.
- `04:207-215` (L1-06): "`land(data, proof)` MUST require `firstBlockHeight == lastLandedHeight + 1` … No function in any mode — **including … a recovery path** — may decrease `lastLandedHeight`, replace or delete a checkpoint record at a height ≤ the current one …".
- `04:98-110` (L1-04): any account MUST be able to land; permitted admission bounds are exactly contiguity, non-emptiness and bounded loops.
- `06:363` (REC-02, Late proofs): "A proof whose batch lies above the restored checkpoint is **void**: its predecessor no longer exists." The stated reason is false (the restored checkpoint *is* the predecessor); the operative mechanism is the generation bump, and nothing in the rules binds the *history* to the generation.
- `09:164` (L1-05 row 31) / `09:149`: "incremented by exactly one per completed recovery (REC-02)" — REC-02 itself never states the increment or when it happens (see R4-MB-09).
- Missing rule: (a) the completion entry point, its caller and its atomic effect (generation increment + bond refund + the restored-checkpoint designation); (b) whether the recovery is satisfied at inclusion or at `L1_FINALITY`, and that acceptance of **any** batch extending the checkpoint at or before the completion's Ethereum finality cancels it (or, equivalently, that `land` is refused in that window — which L1-04's closed list of permitted bounds does not authorise).

**Assumptions and preconditions.** A settlement stall has occurred (the spec's own admitted trigger, 06:357) and a recovery has been invoked and reached `T_RECOVERY_DELAY`. The data and certificate of the unsettled range are available (the stall was a prover outage, an L1-congestion episode, or a deliberate delay — not a data loss). No Byzantine stake, no L1 censorship, no governance action.

**Concrete attack trace.**
1. Checkpoint C1 at height h1 is accepted. L2 finalizes the range h1+1 … h2; no batch is accepted for T_STALL (a slow-prover or L1-congestion stall). Any account invokes recovery (06:358).
2. `T_RECOVERY_DELAY` elapses with no acceptance. A completion transaction (whoever may send it — see the missing rule) is included in L1 block N: the generation becomes g+1, the bond is refunded (06:360, 07:535-545), and the restored checkpoint is C1. L2 nodes cannot yet adopt this: SYS-02 requires finality.
3. In (N, N + L1_FINALITY), a party lands the **discarded** range: `firstBlockHeight = h1+1` is contiguous with `lastLandedHeight = h1` (L1-06), the data is available in the transaction (D5 satisfied), and a fresh proof of the same blocks and the same certificate is generated under generation g+1. The guest's clause (viii) check is equality with the contract-supplied generation (05:273-283); it is satisfied. L1 accepts; the checkpoint record at h2 exists and `lastLandedHeight = h2`.
4. Now the completion becomes Ethereum-final. Nodes must adopt the recovery (REC-02: "the checkpoint after recovery is exactly that record" = C1) — but h2 > h1 is an **accepted batch**, and STATUS-06 says "no L2 rule — **including the recovery of REC-02** — can revoke an accepted batch" (index.html:240-245); REC-01(a) forbids replacing an accepted block hash at or below the latest accepted checkpoint; L1-06 forbids any function, including a recovery path, from decreasing `lastLandedHeight`.
5. Resolution A (recovery stands): an accepted batch is revoked by an L2 rule — STATUS-06, REC-01, L1-06 all broken, and the L1 anchor (h2, the record the bridge authenticates against, MSG-03) contradicts the L2 canonical chain (h1). Resolution B (the landing voids the recovery): a batch accepted *after* `T_RECOVERY_DELAY` silently cancels a completed recovery, which REC-02 does not permit ("Acceptance is the only cancellation" is scoped to the delay window).
6. The same race exists in its mirror form if the "effect" is on the wall clock without an L1 state change: the old-generation proof is still valid at L1 and lands verbatim while nodes have already rewound, producing the same L1/L2 split with no adversary at all.
7. Secondary, same root: because the generation binds the proof object and not the history, the discarded range can **always** be re-landed by any prover whenever its data and certificate exist — the rewind of a merely *unproven* range is reversible at will, and nodes that produced a fresh post-recovery chain must then abandon it when the old range lands. REC-02 permits this explicitly ("Its data commitment may be re-used only by a new batch proposed against the restored checkpoint, by any proposer", 06:363), so "recovery replaces history" is only ever a **transient** replacement; no rule states that.

**Inside/outside the claimed fault model.** **Inside the action model**: every step is a permissionless, rule-legal L1 transaction plus the L1 inclusion/finality gap; no Byzantine stake, no censorship, no key compromise. It is reachable only once a recovery is in flight, and the recovery's own trigger is outside the spec's fault model (R4-MB-01) — the defect is that the protocol's *sanctioned remedy* is self-contradictory when it runs.

**Attacker resources and cost.** L1 gas for one `land(data, proof)` (UNMEASURED, 04:382-383) plus the cost of one proof under generation g+1 — the same cost any honest prover/k landing already pays. No bond, no stake, no coordination. The attacker (or a victim wanting its provisional history restored) needs only data availability, which is the case whenever the stall was not caused by data loss.

**Harm and affected requirement.** Two conflicting canonical histories (L1 checkpoint h2 vs. recovery-restored h1) and the loss of the "no accepted batch is ever revoked" guarantee that D-7's own narrative rests on ("Ethereum-finalized checkpoints and every accepted batch remain untouchable", D-7:269-272); the bridge surface (MSG-03 releases against a landed checkpoint's state root) is exposed to whichever resolution is implemented if the window is long enough for a withdrawal; the recovery's effect is shown to be reversible, which invalidates the "wholesale replacement" language of STATUS-04 (`index.html`:208) and INV-01 (`10`:17-38). Fixed decisions affected: D2's "recovery of *unsettled* history" boundary and the D-7 guarantee class.

**Evidence.** `06`:356-363, 425; `04`:98-110, 207-215, 385-396, 649-659; `01-system-model.html`:179-199; `09`:149, 164; `05`:112-117, 273-283; `index.html`:195-245; `10`:17-38; `01`:27-30 (D5/D2).

---

## Finding R4-MB-03 — the trigger clock is undefined and never resets: "a fresh stall is required for each recovery" is not implementable as written

**Severity: High.** One-line rationale: T_STALL is defined as "no batch extending the current L1 checkpoint has been accepted for T_STALL" with no anchor instant and no reset rule, while a completed recovery restores the *same* record with its original acceptance time; after any recovery (and after an L1 reorg that drops the newest accepted batch) the stall predicate can be satisfied without any new failure, so repeated recoveries are invocable on a stale clock, each refunding its bond and bumping the generation, and no rule binds T_RECOVERY_DELAY to the honest landing time that falsifier (b) admits it depends on.

**Exact rule / missing rule.**
- `06:357` (REC-02, Objective trigger): "no batch extending the current L1 checkpoint has been accepted for `T_STALL`" — no anchor, no "measured from", no reset.
- `06:356` / `06:39-40` (REC-01/REC-02 invariant): "a completed recovery restores exactly that checkpoint" — the record keeps its original acceptance time and the generation moves but the record does not.
- `06:367` (REC-02, Repeated recovery): "**A fresh stall is required for each recovery**; … a cooldown `REC_COOLDOWN` follows each recovery."
- `09:148` (REC_COOLDOWN): "the minimum interval that follows each completed recovery before another recovery can take effect" — nothing about a fresh stall clock.
- `06:403-405` (REC-03 falsifier (b)): the argument fails if "T_RECOVERY_DELAY is shorter than the time an honest prover needs to land a batch"; `09:145` repeats this in a parameter-table note. It is a falsifier, not a rule: no normative constraint pins T_RECOVERY_DELAY ≥ honest landing time, and both terms are unmeasured.
- `04:385-390` (L1-12): an L1 reorg drops a `land` and "no checkpoint record exists" — the clock's last-acceptance instant moves backwards, which the trigger text does not account for.
- Missing rule: the clock's anchor (checkpoint acceptance time vs. last acceptance of any batch that ever extended it), whether discarded acceptances count after a recovery, and a reset at recovery completion (or an explicit "no recovery may be invoked within T_STALL of the previous completion").

**Assumptions and preconditions.** A completed recovery (any cause, including the no-op case where nothing was above the checkpoint). Optionally an L1 reorg below finality. No adversary needed for the arithmetic; an adversary is needed only to choose the moment.

**Concrete attack trace.**
1. The chain halts for any reason at the checkpoint (e.g. HALT-01(d), a missing epoch-set entry — HALT-01 explicitly routes this to the recovery path "if settlement nevertheless stalls past T_STALL", 06:98-100). Nothing is above the checkpoint; no batch can be landed because nothing new is finalized. The predicate is true and unfalsifiable by honest action.
2. Recovery 1 completes: no-op rewind to C1, bond refunded, generation g→g+1, REC_COOLDOWN starts, n = 1.
3. On the stale reading (the anchor is the *record's* acceptance time, which is unchanged and already older than T_STALL), the predicate is true again the moment the cooldown allows an invocation. If no batch lands within the second delay — plausible whenever the post-rewind pipeline (re-finalize, re-prove, land, and the delay itself) is longer than REC_COOLDOWN, and guaranteed in the no-op case where the halt persists — recovery 2 completes, refunded, g→g+2, n = 2. Repeat.
4. Each completion invalidates every proof in flight for the range above the checkpoint (the generation equality check, 05:273-283), so any honest prover work in that window is discarded; each completion doubles the bond for everyone, because B_REC(e) = B_REC_BASE · 2^n is a function of history, not of identity (06:358, 09:146). An honest recovery later is priced out by an attacker whose own bonds were all refunded.
5. The alternative reading (only acceptances of batches that extend the *restored* checkpoint count, discarded ones do not) gives the opposite answer for step 3 — which is the point: the rule does not say which.

**Inside/outside the claimed fault model.** The no-op variant needs no adversary and no assumption failure beyond the halt the protocol already declares a "correct outcome" (HALT-01). The adversary-assisted variant needs only timing plus capital that is returned.

**Attacker resources and cost.** Per attempt: L1 gas for invocation and completion (unmeasured), opportunity cost of B_REC_BASE · 2^n ETH locked for T_STALL + T_RECOVERY_DELAY, and the whole bond **only if cancelled**. On success the bond is returned in full (06:360; 07:535-545), so a well-timed chain of completed recoveries costs ≈ gas plus a refundable balance.

**Harm and affected requirement.** R6's exact end conditions (the remedy for a settlement stall can itself be consumed by stale-clock repetitions); R11's accounting of the recovery bond; the REC-03 claim that "a fresh stall is required for each recovery" (it is not enforceable); D2 step 5's "penalties" quantification.

**Evidence.** `06`:98-100, 356-360, 367, 403-405; `09`:143-148; `04`:385-390; `05`:273-283.

---

## Finding R4-MB-04 — the bond is mispriced: free on success, unbounded on honest use, and unrelated to the value that can be discarded

**Severity: High.** One-line rationale: the bond is refunded in full on completion, slashed only on cancellation, and the escalation exponent counts only *completed* recoveries, so the manipulation REC-03 prices is free for any attempt that succeeds; the escalation 2^n has no cap and penalises whoever invokes next — including an honest party invoking the sanctioned remedy — while no rule relates B_REC to the maximum value at risk (up to D_MAX blocks above the checkpoint).

**Exact rule / missing rule.**
- `06:358` (who may invoke): B_REC(e) = B_REC_BASE · 2^n, "n is the number of **completed** recoveries in the preceding REC_WINDOW".
- `06:360` (bond outcome): "returned in full when the recovery completes, and transferred to the protocol treasury when the recovery is cancelled by honest progress".
- `07:535-545` (ECON-06(6)): cancellation pays the treasury; completion returns the poster's own bond.
- `09:146`: "The escalation is not a cap: it makes repeated recovery more expensive, it does not bound it (REC-03)" — and neither the base nor the escalation is proposed.
- Missing rule: any relation between B_REC and rollback exposure (`D_MAX` × per-block value), any cap on 2^n, and any statement that a completed recovery leaves a residual cost (the current schedule leaves none).

**Assumptions and preconditions.** Permissionless invocation; a stall long enough for the delay to elapse; the invoker can afford the (refundable) bond.

**Concrete attack trace.** (1) Attacker wants an unfavourable provisional range discarded. (2) It waits for (or, per R4-MB-06, merely benefits from) a stall, or times an invocation so that the honest landing does not fit inside T_RECOVERY_DELAY. (3) The recovery completes: all effects above the checkpoint are discarded, the attacker's bond returns **in full**, and the attacker pays gas plus the time value of the bond. (4) In the same completed-recovery history the honest party later needs a recovery: n has grown, so the honest bond is B_REC_BASE · 2^n — an attacker who can afford k completed no-op recoveries (all refunded) has raised the honest price by 2^k with no net cost. (5) Any *cancelled* attempt (the honest case, where a batch lands in time) costs the full bond to the treasury — so the schedule taxes the party whose chain is working and rebates the party who wins.

**Inside/outside the claimed fault model.** The bond mechanics are inside the specification and do not need an adversary; the trigger remains the outside-model precondition (R4-MB-01).

**Attacker resources and cost.** Gas + refundable ETH (no penalty on success); a failed attempt costs the whole bond. The asymmetry is the defect.

**Harm and affected requirement.** D2 step 5 ("quantified … penalties"); R11 (collateral/penalties economics); the REC-03 conclusion "a manipulation primitive with a price" — for a successful attempt the price is ~0.

**Evidence.** `06`:358-360, 367, 399-402; `07`:535-545; `09`:143-148; `04`:353-365.

---

## Finding R4-MB-05 — "there is no selective rollback" is not established: the discard is wholesale, the outcome is not

**Severity: High.** One-line rationale: REC-03's defence against selective reversion is that a recovery "restores the checkpoint wholesale … destroying every L2 effect above that checkpoint, including their own"; but REC-02 also states that discarded transactions "are not replayed automatically and are not guaranteed inclusion", so the post-recovery history is rebuilt by voluntary resubmission, and the invoker (or an attacker) controls the resubmission of its own effects while the counterparty's are re-included only if that party notices; effects whose validity is contingent on the discarded state (order-dependent fills, oracle reads, deadlines, nonces, bridge message ordering) are selectively lost while others return.

**Exact rule / missing rule.**
- `06:396-398` (REC-03): "Because recovery restores the checkpoint wholesale, there is no selective rollback: an attacker cannot revert one unfavourable transaction without destroying every L2 effect above that checkpoint, including their own."
- `06:364` (REC-02, Transaction replay): "L2 transactions in discarded blocks are **not replayed automatically and are not guaranteed inclusion**."
- `06:363`: a discarded range's data commitment "may be re-used only by a new batch proposed against the restored checkpoint, by any proposer" — i.e. the discarded range can be re-proved and re-landed (R4-MB-02 step 7), so even the "destroyed" set is not finally destroyed.
- `index.html`:208 ("replace history wholesale, **never selectively**"), `10`:33 (INV-01: "within it history is replaced wholesale, never selectively"), `10`:238.
- Missing rule: any statement of what the rebuilt range must contain, any re-inclusion duty or mempool re-injection of discarded transactions, and any rule preventing the invoker from being the first lander of the rebuilt range.

**Assumptions and preconditions.** A completed recovery; honest proposers apply LIVE-04 inclusion; no forced-inclusion path exists (D-6/D-10) and no re-inclusion duty is stated.

**Concrete attack trace.** (1) Range R = [h1+1, h2] contains one unfavourable transaction T_u (a fill, a liquidation, a bridge message) and one attacker transaction T_a. (2) A stall lets a recovery complete; both are discarded. (3) The attacker re-signs and resubmits T_a (it holds the signed transaction and its own keys); the counterparty of T_u may be offline, may not monitor, or T_u's precondition (state, deadline, oracle price) no longer holds at C1, so T_u does not return. (4) The rebuilt range contains T_a and not T_u — a selective outcome obtained without censoring anyone: LIVE-04 guarantees inclusion only of transactions that *reach* honest proposers, and a discarded transaction has no rule putting it back in front of them. (5) The invoker additionally chooses *when* to invoke, which determines which provisional range is above the checkpoint, and (per R4-MB-02) nothing binds the restored checkpoint to a depth the invoker cannot exploit.

**Inside/outside the claimed fault model.** The *discard* step is a protocol rule (needs a stall); the *selectivity* is a consequence of rules that are inside the design (no replay, no inclusion duty) and holds regardless of how the recovery was triggered.

**Attacker resources and cost.** L1 gas to resubmit its own transactions; the recovery's bond is refunded on completion (R4-MB-04). The victim's loss is its provisional outcome, which the guarantee class discloses — but the *selectivity* claim is what is false, and it is the stated reason the manipulation is unattractive.

**Harm and affected requirement.** REC-03's central defence claim; STATUS-04/INV-01's "never selectively"; LIM-01 row 238 ("destroying every effect above it including the attacker's"); the D2 step-5 requirement to quantify the manipulation's value.

**Evidence.** `06`:363-364, 396-398; `index.html`:195-216; `10`:17-38, 238; `04`:552-558 (FI-REMOVED-01).

---

## Finding R4-MB-06 — the landing market is unpriced and the funding path is circular, so the trigger is reachable with no adversary: an empty pool means nobody is paid to land, and the fees that would fund rewards cannot arrive until batches land

**Severity: High.** One-line rationale: REC-03 infers "batches keep landing" from "proving is permissionless and rewarded (L1-10)", but L1-11 requires `land` to succeed with `rewardPaid = 0`, the only specified reward inflow is a sweep through the preserved Bridge whose L1 release itself requires an accepted checkpoint (STATUS-06 / MSG-03), and ECON-02 forbids the subsidy from being a second funding source — so before the first settlement there is no funded reward, nobody is paid to land, and the trigger (and a no-op recovery, which cannot fix an economics stall) follows with no attacker at all.

**Exact rule / missing rule.**
- `06:390-391` (REC-03 premise 4): "proving is permissionless and rewarded (L1-10)".
- `04:353-365` (L1-11): "land(data, proof) MUST NOT require a non-zero rewardPaid: if the reward ledger is empty, the batch still lands with rewardPaid = 0"; `rewardPaid = min(REWARD_QUOTE, proverReward_before + msg.value)` — the reward is at most the lander's own attached value plus a pool share.
- `07`:218-267 (ECON-02 clause 7): the only route is the L2 fee vault → sweep → preserved Bridge → release "after a checkpoint covering the sweep's own L2 block is accepted on L1 (STATUS-06) and the message is proven against that checkpoint (MSG-03)"; "An empty pool pays nothing" (clause 5(e), 07:206-211); `D_subsidy` "is a transfer of the protocol's own inflow, not a second funding source" (07:131-141). `POOL_TOPUP` is "any L1-side inflow … from a budgeted and recorded source", tagged `unmeasured / human decision` in `09`:119 — no rule requires one before launch.
- `09`:110, 119-121: REWARD_QUOTE, POOL_TOPUP, Alloc(e) unmeasured/Open; `04`:673-677 lists them as unmeasured.
- Missing rule: the bootstrap — a required, recorded pre-launch top-up, or the honest statement (and its consequence) that the first settlements and the first sweeps are unpaid work; and any rule tying a lander's reward to the marginal L1 cost (REWARD_QUOTE is explicitly not derived from it, 09:110).

**Assumptions and preconditions.** Deployment at launch, or any period in which the pool's realised inflow is zero/insufficient (a fee drought, a sweep failure, a bridge-release failure — ECON-02 clause 7(d) says rewards then stop rather than become a claim).

**Concrete attack trace (no adversary required).**
1. The chain starts (or a period begins) with an empty pool: no L2 fee ETH has arrived because arrival requires a checkpoint covering the sweep's own L2 block, which requires settlements.
2. A prover produces a valid proof; its expected reward is 0 (L1-11) and its L1 gas is not reimbursed.
3. No batch is landed for T_STALL (nobody is paid to do it). Honest validators keep finalizing until the cap binds, then halt.
4. The trigger is satisfied. Recovery completes: it restores the checkpoint, which is exactly where the chain already is — a no-op. The reason the chain is stalled (an unpaid landing market) is untouched, and the generation bump voids any proof in flight. Repetition escalates the bond (R4-MB-03/04) for the party who would fund the honest remedy.
5. An adversary can price the landing market directly: because the honest lander's budget is bounded by a reward quote that may be zero, bidding up blob/gas fees (or simply filling blob space during the window) delays the honest landing without any validator-level censorship and without violating "L1 includes valid transactions" — the honest transaction is valid but unlanded, or economically irrational to send.

**Inside/outside the claimed fault model.** The economics path needs **no** Byzantine stake and no L1 censorship; it is a consequence of specified rules (empty pool pays nothing; land succeeds unpaid). It is the class `01` §6.3 lists as "cheap attacker-triggered recovery that replaces honestly confirmed history (Mode B)" and "prover cartel / denial of proving (T-9)".

**Attacker resources and cost.** In the empty-pool case: zero. In the fee-market case: the fee overbid for the duration of the landing window (real cost, unquantified here because L1_FINALITY, T_STALL and the batch's blob/gas cost are all unmeasured). Compare the honest side's budget: REWARD_QUOTE, which may be 0.

**Harm and affected requirement.** R6/R9 liveness (a settlement stall whose cause recovery cannot fix), D-8's own honesty requirement (the funding path is Open, 09:119-121 / 07:218), A-ECO-1; and REC-03's inference "proving is permissionless and rewarded ⇒ batches keep landing" is false.

**Evidence.** `06`:385-391; `04`:340-365, 673-677; `07`:131-141, 142-217, 218-267; `09`:110, 119-121, 143; `10`:238-243.

---

## Finding R4-MB-07 — the falsifier list in REC-03 is incomplete, and falsifier (b) is not made normative

**Severity: Medium.** One-line rationale: REC-03 names three falsifiers (permissionless proving in practice; T_RECOVERY_DELAY shorter than an honest landing; a bond refundable on cancellation) but omits four conditions this review shows are load-bearing, and the one that the design's own parameter table repeats (delay vs. honest landing time) is stated only as a falsifier and never as a rule.

**Exact rule / missing rule.** `06:403-405` (REC-03 falsifiers); `09:145` (the note that the delay "MUST NOT be shorter than the time an honest prover needs to land a batch" — in a derivation column, owned by REC-02 which does not state it); `10`:240 (the register of falsifiers).
**Missing falsifiers:** (i) the landing market / reward pool being unable to pay for landing (R4-MB-06); (ii) the trigger clock being satisfiable without a fresh stall after a completed recovery or an L1 reorg (R4-MB-03); (iii) the absence of a completion entry point/depth making the recovery's own effect racy or void (R4-MB-02); (iv) the discarded range being re-provable and re-landable, so a recovery can be undone or a fresh post-recovery chain abandoned (R4-MB-02/05). Also missing: a normative statement (not a falsifier) of T_RECOVERY_DELAY ≥ the honest landing time.
**Assumptions/preconditions:** none.
**Attack trace:** N/A (analysis defect).
**Inside/outside:** N/A.
**Attacker resources and cost:** N/A.
**Harm and affected requirement:** R13 ("implementable without inventing rules") and D2 step 5's reviewability: an argument whose falsifiers omit the conditions under which it actually fails cannot be reviewed to a verdict.
**Evidence.** `06`:403-405; `09`:145; `10`:240.

---

## Finding R4-MB-08 — stale Mode A text and one invariant sentence now contradict the selected mode

**Severity: Medium.** One-line rationale: change order 04 §1 required every artifact to move from "halt, never roll back" to the new guarantee class, but several rules still assert the Mode A posture, and INV-01 forbids the very event that is the recovery's only trigger.

**Exact rules.**
- `04`:530-538 (DA-06): "When the cap binds, the honest outcome is a **safe halt (HALT-01), never a rollback**" — contradicts REC-02 (recovery exists precisely for the settlement-stall case).
- `04`:104-110 (L1-04): "This rule is required by **Mode A**, not merely compatible with it"; `04`:387 (L1-12): "The batch remains PoS-finalized in **Mode A**".
- `10`:33-34 (INV-01): "no timeout, rotation, admission rule, governance upgrade, operator action or **failure of a liveness assumption** may replace history" — the sole trigger is a settlement stall, i.e. a liveness failure (A-DA-2 / A-L1-1). As written, INV-01 forbids the recovery.
- `03-membership-staking.html`:48 ("No rule on this page can invalidate a PoS-finalized block in Mode A"), `04`:649-659 (MSG-03's "under Mode A …" and "exactly the rewrite that Mode A forbids" — the latter rationale is load-bearing for the F2 window).
- Missing rule: a consistency pass over the frozen pages after D-7, and a corrected INV-01 sentence that scopes the trigger's liveness failure explicitly.
**Assumptions/preconditions:** none.
**Attack trace:** N/A (text conflict).
**Inside/outside:** N/A.
**Attacker resources and cost:** N/A.
**Harm and affected requirement:** R13, R14; the invariant that R5 hangs on is self-contradictory.
**Evidence.** `04`:104-110, 387, 530-538, 649-659; `10`:33-34; `03`:48; `iterations/04-change-order.md`:17-18.

---

## Finding R4-MB-09 — the generation increment is attributed to REC-02 but stated nowhere in REC-02, and REC-02's stated reason for voiding late proofs is false

**Severity: Medium.** One-line rationale: three pages say the recovery generation is "incremented by exactly one per completed recovery (**REC-02**)", but REC-02 never states the increment, its timing, or its atomicity with the bond refund and the restored-checkpoint designation; REC-02's own justification for voiding late proofs ("its predecessor no longer exists") is wrong, because the predecessor is exactly the restored checkpoint — the real mechanism is the generation check, which the owner rule does not state.

**Exact rule / missing rule.** `06`:362, 363, 370 (REC-02's late-certificate/late-proof/authorization rows); `09`:149 and `04`:164, 203 and `05`:112-117 all assert the increment and attribute ownership to REC-02; missing from REC-02: the increment itself, its point in the completion flow, and its atomicity (see R4-MB-02).
**Assumptions/preconditions:** none. **Attack trace:** N/A. **Inside/outside:** N/A. **Attacker resources and cost:** N/A.
**Harm and affected requirement:** R13 (an implementer must invent when the counter moves and whether the bond refund is atomic with it); a wrong choice reopens the R4-MB-02 window.
**Evidence.** `06`:356-372; `09`:149; `04`:164, 203; `05`:112-117, 273-283.

---

## Checked, holds (not re-litigated)

- **No invoker discretion over the restored checkpoint.** REC-02's "No discretion" row (06:361) fixes the restored checkpoint to the current L1 checkpoint and the validator set to the L1 staking contract's existing epoch entry; no rule lets an invoker name a height, a state root or a set. The only influence is *timing* (when the stall is exploited), which R4-MB-05 treats as an outcome-selectivity issue, not as checkpoint choice.
- **L1-06 monotonicity vs. REC-01.** Given the intended reading — the restored checkpoint *is* `lastLandedHeight` at completion, so nothing below it moves — `lastLandedHeight` does not decrease and L1-06 is consistent with REC-01/02. This holds **only** while no batch lands between the completion's inclusion and its finality; R4-MB-02 is the case where it breaks.
- **D5 in recovery.** REC-02's "D5 is unchanged" row (06:369) plus L1-01/L1-03 keep data+proof atomic; recovery accepts no data and advances no checkpoint. Checked and holds.
- **D7 vs. the ETH bond.** The bond is an anti-spam deposit, not consensus collateral; D7 governs staking/slashable collateral only. The asset choice is conforming; the *schedule* is the defect (R4-MB-04).
- **Upgrade landing mid-recovery.** 08:169-181 and GOV-03(e) state that a pending recovery must survive an upgrade unchanged, may not be cancelled/accelerated/retargeted, and that the checkpoint record and generation counter must be preserved. Checked and holds at the normative level (its *parameters at invocation* are still unstated, but that is subsumed by R4-MB-09).
- **Withheld-certificate schedule (WH-04) / uniqueness (INV-01) under D-7.** The lock/view-change/reconfiguration argument is unaffected by the recovery rewrite; the round-3 conclusion that no *certificate*-level fork is constructible was not re-broken here. The D-7-specific gap is the L1/L2 boundary in R4-MB-02, not the certificate argument.

---

## Answers to the five required questions

1. **Is "a sub-threshold coalition cannot induce the trigger" true?** As a statement *inside the four premises*, yes — trivially, because A-DA-2 and A-L1-1 assert exactly the liveness the trigger measures. As a *resistance result*, no: it answers about 1/3 of L2 stake while the trigger is decided in the prover and landing markets. A coalition with zero voting power that supplies/withholds proofs (T-9), that outbids landing, or that simply acts while the reward pool is empty (R4-MB-06) reaches the trigger without any L2 misbehaviour, and a successful recovery costs it no bond (R4-MB-04). So the claim is premise-contained and does not discharge D2 step 5.
2. **Selective revert?** The *restore point* is not invoker-selectable (checked, holds). The *outcome* is not all-or-nothing in the sense REC-03 claims: discarded transactions are not replayed and not guaranteed inclusion (06:364), resubmission is voluntary, and effects contingent on the discarded state are selectively lost (R4-MB-05); the discarded range can also be re-proved and re-landed, undoing the rewind (R4-MB-02). The defence is real only for the discard step.
3. **Quantified cost.** Bond in ETH, escalating 2^n over completed recoveries in REC_WINDOW, refunded in full on completion, slashed whole to the treasury on cancellation, REC_COOLDOWN after each completion. **Unmeasured**: B_REC_BASE, REC_WINDOW, REC_COOLDOWN, T_RECOVERY_DELAY, T_RECOVERY_MARGIN, T_PROOF_MAX_PERMITTED, T_SETTLE_PIPELINE, L1_FINALITY, T_STALL, the gas of land, REWARD_QUOTE — and the value at risk (D_MAX × per-block value) has no relation to any of them. Attacker gain: whatever the discarded provisional range was worth, including off-chain profit; the protocol bounds none of it (LIM-01:237-238) and, on success, charges nothing.
4. **Are the falsifiers right?** They are necessary but not sufficient. Missing: landing-market/pool-empty (R4-MB-06), stale trigger clock (R4-MB-03), no completion depth (R4-MB-02), re-proving the discarded range (R4-MB-02/05). Falsifier (b) is correct but is a falsifier, not a rule (R4-MB-07).
5. **Two canonical histories?** Yes, in the window defined by R4-MB-02: an accepted checkpoint at h2 (from a rule-legal landing after the completion transaction) and the recovery's restored checkpoint at h1 cannot both be canonical, and every rule that would resolve the conflict (REC-01, STATUS-06, L1-06, L1-04) is broken by one of the two resolutions. During a pending (pre-completion) recovery there is one canonical chain plus one pending rule; a cancelled recovery leaves one chain and slashes the bond; an upgrade mid-recovery is handled by GOV-03(e).

## Verdict

**The D-7 Mode B selection is NOT adequately established, and REC-03 must not be recorded as passing independent review.** The selection remains an authorised user decision, but the D2 procedure the project claims to have completed at step 5 is not complete: no quantity, no penalty schedule and no rollback-exposure bound are given; the only resistance claim is definitional; and the mechanism has two concrete rule-level counterexamples — the completion/finality window (R4-MB-02, an L1-accepted batch that the recovery must revoke, plus a re-provable discarded range) and the stale trigger clock (R4-MB-03) — on top of a bond schedule that is free on success (R4-MB-04) and a landing market that can stall the chain with no adversary (R4-MB-06). REC-03's own falsifier (c) is not the only place the reasoning fails.

**Minimum fixes required before the selection can be treated as settled:** (1) state the completion entry point, its caller, and the L1 depth at which a completed recovery is canonical, and extend cancellation to any batch accepted before that depth (or forbid `land` in that window, with L1-04 amended accordingly); (2) anchor and reset the stall clock and make "a fresh stall" enforceable; (3) put a floor and a cap on the bond schedule and relate B_REC to the rollback exposure, with a real cost on success; (4) either state and enforce a re-inclusion rule and a landing-payment bootstrap, or disclose these as limitations and reopen the D2 step-5 record; (5) add the four missing falsifiers; (6) fix the stale Mode A text and INV-01's liveness-failure sentence.
