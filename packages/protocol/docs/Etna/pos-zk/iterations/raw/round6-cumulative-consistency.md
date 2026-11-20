# Round 6 — raw adversarial review: cumulative consistency across the specification and the course

**Reviewer:** fresh independent adversarial reviewer, round 6, angle `cumulative-consistency` (cross-cutting).
**Snapshot reviewed:** `7917ba264` (branch `etna-pos-zk`, PR #22262). Worktree at review time: `a483083ab68c4fc9fca9ed65159be4573bbf4d21`, which `git diff --stat` shows differs from the snapshot only by the 18 added lines of `iterations/06-freeze.md`.
**Method.** Every artifact was read as written; in-text `(review round N, finding X)`, `(S5 §n)` and `D-n` notes are claims, not evidence. Mechanical cross-checks were run so the counts are reproducible: all anchored rule ids vs all rule-index rows (**161 / 161, exact match**); all 3,918 internal `href`s vs existing files and anchors (**0 broken**); every parameter-table first-column identifier vs its use on pages 01–08 and 10 (**only two rows are read by no rule, both disclosed**); the course was scanned for every tombstoned name (T_STALL, T_RECOVERY_*, B_REC*, REC_*, ALLOC_REC_PPM, T_INACTIVE, D_LAPSE_MAX, lastObserved) and for the withdrawn contiguity form `max(lastLandedHeight + 1, resumeHeight)`.

**Counts: Critical 0 · High 2 · Medium 5 · Low 2.** Both Highs need no adversary and no assumption failure; neither is a safety break (no two canonical histories, no fund loss). The single most serious result is F1: the freeze's own sweep claim is false for the course, on the exact mechanism D-15 withdrew and forbade "under any name" — and `LIM-01`'s own test of that withdrawal fails.

---

## F1 — Five course pages still teach the withdrawn permissionless bonded recovery and the retired-height floor as live mechanisms; `LIM-01`'s own test of the D-15 withdrawal fails

**Severity: High.** One-line rationale: decision D-15 withdrew the permissionless bonded recovery and `GOV-04` forbids reintroducing it "under any name", yet `learn/01`, `learn/02`, `learn/03`, `learn/05` and `learn/07` — five pages with **zero `D-15` markers** — present that mechanism, its bond, its clock, its retired heights and the withdrawn `max(...)` contiguity form as the design, and they are the pages a user reads to size what a provisional confirmation can lose.

**Exact rule / missing rule.** `spec/08-migration-upgrades.html` **GOV-04** (opening paragraph): "The former Mode B recovery — the invocation, its bond and escalation, the certificate bundle, the completion transition, the retirement floor and the completion reward — is withdrawn and **MUST NOT be reintroduced under any name**". `spec/10-assurance.html` **LIM-01**, "Recovery — withdrawn by decision D-15" row: "A test of the withdrawal is a demonstration that no rule, client, parameter or migration text still invokes the recovery path." `spec/09-parameters.html` tombstone rows for `T_STALL`, `T_RECOVERY_DELAY`, `B_REC*`, `REC_*`, `resumeHeight`: each "MUST NOT be used by any rule, client, parameter or migration text". `spec/06-recovery-exceptions.html` **REC-04(2)** withdraws "the `max(lastLandedHeight + 1, resumeHeight)` contiguity form". `learn/index.html` states the course's own contract: "If this course ever claims more than the specification does, treat that as a bug in the course." **Missing:** a swept course — the sweep named in `iterations/06-freeze.md` item 3 did not reach pages 01, 02, 03, 05 and 07.

**The stale text, verbatim (all live, non-commented HTML).**
- `learn/02-life-of-a-transaction.html:207-213` — "the stall passes the `T_STALL` threshold. **Anyone may now start a recovery by posting a bond on L1.** The bond splits at invocation … a cooldown follows the attempt, and a further attempt costs a larger bond. The recovery waits `T_RECOVERY_DELAY`; if a valid batch … is accepted at any time before the completion transaction is included, the recovery is cancelled and the whole bond goes to the protocol treasury."
- `learn/02:224, 230, 259-261, 273, 286, 299` — "Recovery started: someone posts a bond …"; "Heights 801–832 are retired: they can never be certified or landed again"; "Anyone may start a bonded, delayed recovery that replaces that history and permanently [retires it]"; "The recovery trigger, bond split, delay, escalation, cooldown and cancellation values are unmeasured placeholders".
- `learn/02:176` — the status ladder's *withdrawal-eligible* row: "Nothing on the protocol's own side, except that a settlement stall delays the path for later messages until a batch lands **or a recovery completes — and a recovery can replace an unsettled message**." (The actual rule is a governance-queued, timelocked resume; nothing "completes" it on its own.)
- `learn/07-timing.html:175` — "If the settlement stall passes `T_STALL`, **a permissionless, bonded, delayed recovery may replace** the unsettled range … and it permanently retires the heights it discards".
- `learn/01-what-is-etna.html:58, 76-77, 166` — "a permissionless, bonded, delayed recovery may still replace that history"; "(REC-02) may replace it"; "permanently retires the heights it discards, so the replaced range can never be re-certified or landed again".
- `learn/03-consensus.html:178, 237, 266` — "governed by the recovery rules"; "what may be replaced above the latest checkpoint accepted on Ethereum is decided by the recovery rules"; "**only recovery** may replace history above the latest accepted checkpoint".
- `learn/05-the-proof.html:164-170` — "the property that a discarded branch cannot be reinstated rests on the **retired heights**: a batch must start at `max(lastLandedHeight + 1, resumeHeight)`, so a batch that starts below `resumeHeight` can never be landed or certified, at any generation … **locks at retired heights are void**." This is the mechanism REC-04(2) withdraws; the live binding is the *signed generation*, and `resumeHeight` is derived (`lastLandedHeight + 1`), not recorded.

**Assumptions.** None. The pages are viewable deliverables; no adversary, key, stake or L1 condition is needed.

**Concrete attack trace (no adversary).** A user's transaction sits in a certified provisional range above the checkpoint; a stall begins. (1) The user reads `learn/02`'s status ladder and worked example, which is the page the course itself designates for "the status ladder" and "what each status really guarantees": it says a third party can start a bonded recovery, that the bond/escalation/cooldown price abuse, and that the restart "permanently retires" the discarded heights. (2) The user therefore believes (a) the restart does not depend on governance acting, (b) it is priced by a bond (so an adversary must post capital), and (c) the discarded range can never be re-certified. (3) Under D-15 all three are false: the restart is queued by a DAO transaction with no bond and no permissionless invoker, it happens **only if governance acts** (A-GOV-2, `GOV-04(a),(g)`, `LIM-01`), and the discarded branch is excluded by a *signed generation*, not by a retirement floor. (4) The user holds a provisional position through the window on a risk model the specification withdrew; `learn/08` and `learn/limitations` state the correct model, so the course contradicts itself across pages, and the two pages that teach the status ladder and the timeline are on the wrong side. (5) An integrator wiring a "withdrawable" badge from the ladder gets the guarantee class wrong in the direction of *more* safety than exists.

**Inside / outside the claimed fault model.** Inside the disclosure model; outside any attack model (no attacker exists, no assumption is broken). The defect is that the design's own disclosed limitation (governance liveness, no permissionless recovery) is contradicted by the material written to disclose it.

**Attacker resources and cost.** None. The harm is misstated risk, not stolen value.

**Requirement / fixed decision affected.** Fixed decision D-15 and `GOV-04`'s "MUST NOT be reintroduced under any name"; D-7's supersession; `GEN-01`/`GEN-02` (no deliverable may misdescribe the design); the project requirement that the course and specification agree (R14); `STATUS-11`'s disclosure discipline, which the ladder page fails; `LIM-01`'s own withdrawal test; the freeze's claim that "the course … [was] swept for withdrawn mechanisms".

**Evidence.** `learn/02-life-of-a-transaction.html:176,207-213,224,230,259-261,273,286,299`; `learn/07-timing.html:121,158,175`; `learn/01-what-is-etna.html:58,76-77,166`; `learn/03-consensus.html:178,237,266`; `learn/05-the-proof.html:164-170,193-196`; `grep -c "D-15"` = 0 for all five files; `spec/08…#GOV-04`; `spec/10…#LIM-01` (Recovery row); `spec/09#T_STALL`; `spec/06#REC-04`(2); `learn/index.html` ("a bug in the course").

---

## F2 — The exit guarantee that D-15 substituted for recovery is still stated in two mutually exclusive ways; the `T_GOV_RESUME` obligation can be unsatisfiable for a whole epoch of signals

**Severity: High.** One-line rationale: `MEM-15`(1) promises that a signal at or below the checkpoint is executable "subject only to WITHDRAWAL_DELAY, measured from the checkpoint's `l1BlockNumber`", and `LIVE-01`/`LIVE-05` repeat "no new L2 block, no quorum, no validator", while `MSG-03`, `L1-13`(1)–(2) and `STATUS-08` require a **withdrawal root at an epoch-boundary checkpoint** with ≥ `K_PROOF_BACKENDS` distinct families and measure the delay from **that root's** `l1BlockNumber`; under D-15 this contradiction is load-bearing, because `GOV-04`(d) and `REC-03` rest "every user can exit" on it. *(Round-5 findings F1/F2 of the liveness/UX angle, re-verified unchanged; reported again because they are not fixed and because D-15 has since made them the justification of a fixed decision.)*

**Exact rule / missing rule.**
- `spec/03-membership-staking.html#MEM-15`(1) (raw line 344): "the L1 authentication path MUST remain executable on L1 with (i) no new L2 blocks, (ii) no L2 consensus participation, quorum or validator set … It is subject only to `WITHDRAWAL_DELAY`, measured from the checkpoint's `l1BlockNumber` on the L1 clock (MSG-03)". Its own tag (line 356) concedes: "**The reconciliation of MSG-03's 'a settlement halt delays withdrawals — indefinitely' sentence with this rule is owed by page 04.**"
- `spec/04-l1-integration.html#L1-13`(1) (line 529): "**A withdrawal root is an epoch-boundary checkpoint**"; (2): "A checkpoint that is not a withdrawal root MUST NOT anchor any value release, however many ordinary proofs it carries"; (5) (line 533): "If fewer than k families have a live accepted route for every subsequent epoch, no new root is formed and signals above the last root cannot be released … the exit is delayed **indefinitely**."
- `spec/04#MSG-03` (line 812 ff.): a withdrawal "MUST require a withdrawal root (L1-13) whose stateRoot covers the signal … plus the delay `WITHDRAWAL_DELAY` measured from that root's `l1BlockNumber`".
- `spec/index.html#STATUS-08`: "a withdrawal root at a height not below the signal's height — an epoch-boundary checkpoint carrying an aggregation proof that attests at least `K_PROOF_BACKENDS` … the delay required by MSG-03 measured from **the root's** `l1BlockNumber`".
- `spec/10-assurance.html#LIVE-01` (line 151): the exit is "Independent of every clause above, and therefore not conditional on (L1), (L2), (L4) or (L6)"; `LIVE-05` rows repeat "no L2 block, no quorum and no validator".
- `spec/04#L1-13`(3) (round-5 F2, unfixed): the attach path "Otherwise any account MAY call `attestWithdrawalRoot(height, …)` … When the count holds, the height MUST be marked a withdrawal root" never restates the epoch-boundary conjunct that (1) and STATUS-08 make definitional. **Reading (a)**: mid-epoch signals cannot exit during a halt (F2's trace). **Reading (b)**: (1), (5) and STATUS-08 are false. Either way a normative rule is violated, and no rule chooses.
- `spec/08#GOV-04`(d): "`T_GOV_RESUME` MUST be long enough that every user can exit via MEM-15 … before it executes"; `spec/06#REC-03` residual (7) carries this as an Open *measurement* ("whether `T_GOV_RESUME` is long enough … is not established here"), and `spec/09#T_GOV_RESUME` registers the same Open item.

**Missing rule.** Either (i) `MEM-15` is restated as conditional on a withdrawal root at a height ≥ the signal and on k live families (`L1-13`(5) already discloses the residual), with `WITHDRAWAL_DELAY` measured from the root, and the "not conditional on (L1),(L2),(L4),(L6)" claim is scoped accordingly; or (ii) `L1-13`(3), `L1-13`(1)/(5) and STATUS-08 are amended to admit any landed height as a root and the "epoch-boundary" definition and its unbounded-wait disclosure are withdrawn. And `REC-03` falsifier (c) must be restated: for a signal above the last root the timelock cannot be made sufficient by **any** measurement while settlement is stalled.

**Assumptions.** None beyond the stated liveness assumptions. No adversary: the trigger is an ordinary settlement stall — the exact case D-15's replacement exists for — or even a single epoch that fails to form a root while families are unavailable.

**Concrete attack trace (no adversary).** (1) Let `C` be the last L1-accepted checkpoint and `B ≤ C` the last epoch-boundary withdrawal root. (2) A user's L2→L1 withdrawal signal lands at height `h` with `B < h ≤ C` (any height in an epoch whose boundary has not yet been settled; up to `E_EPOCH` = 1,800 s of blocks). (3) Settlement stalls for `T_STALL_GOV`; the checkpoint freezes at `C`; no later boundary exists, so no root covers `h`. (4) Governance queues the `GOV-04` action and waits out `T_GOV_RESUME`, but the user cannot exit: `L1-13`(2) forbids a release against a non-root checkpoint, and the only routes to a root are a new epoch boundary (needs settlement to resume) or the attach path — which under reading (a) requires a boundary too. (5) The action executes, discards everything above `C`, and the user's value remains stuck below a preserved checkpoint: not lost, but the "exit window" `T_GOV_RESUME` was never usable, whatever its measured value. (6) Under reading (b) the inverse failure occurs: an interface or relayer releases value against a mid-epoch checkpoint and `L1-13`(1)/(5) and STATUS-08 are false.

**Inside / outside the claimed fault model.** Inside. The premise is the L2 settling nothing for one window while the chain may keep producing — the case `LIVE-01`(L4), `LIM-01` and `REC-03` all name — and no assumption beyond the stated set is broken. This is a specification contradiction, not an attack.

**Attacker resources and cost.** None. In the adversarial reading, a sub-threshold coalition that simply does not produce the next epoch boundary holds value at no cost — but the defect needs no adversary at all.

**Requirement / fixed decision affected.** D-15 ("Users are protected by the existing exit guarantee, not by a recovery mechanism"; the timelock "long enough that every user can exit via MEM-15"); `REC-03`'s claim within P1–P4; `LIVE-01`'s "independent of every clause above"; `LIM-01`'s "load-bearing mitigation"; `MSG-03`(5)'s disclosure duty; `STATUS-08`/`STATUS-11` (the public facts an interface must expose); `MEM-15`'s own "Open" tag.

**Evidence.** `spec/03#MEM-15`(1),(4),(5) and its tag (03 lines 344–356); `spec/04#L1-13`(1),(2),(3),(5) (04 lines 529–533); `spec/04#MSG-03` (04 line 812 ff., disclosure paragraph at 819); `spec/index.html#STATUS-08`; `spec/10#LIVE-01` (10 line 151), `#LIVE-05` rows (10 lines 275, 279); `spec/08#GOV-04`(d); `spec/06#REC-03` residual (7); `spec/09#T_GOV_RESUME`, `#W_ROOT_WAIT_MAX`; round-5 `iterations/raw/round5t-liveness-ux-migration.md` F1/F2.

---

## F3 — The rule index declares REC-02/REC-03/REC-04 tombstones that "MUST NOT be used to describe any live mechanism", while page 06 states all three as live normative rules and ~20 other rules reference them as live

**Severity: Medium.** One-line rationale: the index rows and the normative text disagree about whether the stall-resolution rules exist, on the one id family an implementer must find to build the only replacement for history, and the contradiction survives the freeze's claim that "every withdrawn row carr[ies] a MUST-NOT-USE reason" and that the audit "passes in both directions".

**Exact rule / missing rule.** `spec/index.html` rule index: REC-02 — "Withdrawn by decision D-15 … The stall resolution is GOV-04 on page 08; the id is retained as a tombstone and **MUST NOT be used to describe any live mechanism**"; REC-03 — "Withdrawn by decision D-15 … the id is a tombstone and MUST NOT be used to describe any live mechanism"; REC-04 — "Withdrawn … The id is a tombstone". Page 06, same ids: `id="REC-02"` heading "**REC-02 — timelocked, resume-only governance stall resolution (user decision D-15)**" with a normative element table (objective trigger, timelock, void-on-progress, generation fix, late certificates); "**REC-03 — resistance analysis, residuals and falsifiers for the governance path (user decision D-15)**", tagged "Assumed unmeasured Open", and cited as the owner of the Open timelock item by page 06's own header (line 30: "whether it does is Open in REC-03") and by `spec/09#T_GOV_RESUME`; "**REC-04 — restart linkage after an executed stall resolution**" with normative clauses (1)–(4). Live cross-references to REC-02/REC-03 as the stall-resolution path include `REC-01`(b),(d), `HALT-01`, `HALT-02`, `HALT-03`, `HALT-04`, `WH-02`, `WH-04`, `MEM-15`(5), the page-06 scenario table, `MSG-03`'s disclosure paragraph ("the timelocked, resume-only stall resolution of REC-02/GOV-04"), and the index's own D2/D5 fixed-decision rows. **Missing rule:** one authority — either REC-02/03/04 are live and the index rows are wrong, or the live text is GOV-04/HALT-02 and page 06 must stop stating REC-02/03/04 as rules (GEN-03: "Every normative rule has exactly one stable identifier … stated in full on exactly one page").

**Assumptions.** None.

**Concrete attack trace.** A fresh implementer follows the specification's own reading map: index → Rule index → "REC-02 … tombstone … MUST NOT be used to describe any live mechanism", and builds the stall-resolution queue from GOV-04 alone, treating page 06's REC-02 element table as withdrawn text (its trigger/timelock/void clauses are the only place several of them are stated — GOV-04 does not restate the "derived discard depth", the "repeated action" rule or the late-proof replay rules of REC-02's table). The resulting implementation omits rules the index told it were dead. The reverse reader treats the index rows as stale and cannot tell whether a "MUST NOT" applies to the mechanism or only to the id.

**Inside / outside the claimed fault model.** Not an attack; inside the "leaves a security-relevant rule to invent or to skip" class, at the delivery-risk end.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** `GEN-03` (one rule, one place, stable ids); the round-6 freeze's register-audit claim; D-15's requirement that the replacement be specified, not inferred; `GOV-04`'s "this rule replaces the withdrawn REC-02 mechanism" is itself consistent only if REC-02 is *not* live text.

**Evidence.** `spec/index.html` rule-index rows for REC-02/03/04; `spec/06-recovery-exceptions.html` anchors `id="REC-02"`, `id="REC-03"`, `id="REC-04"` and lines 30, 394, 451, 470; `grep -c "REC-02"` = 101 occurrences across spec (mostly live cross-references); `iterations/06-freeze.md` item 3.

---

## F4 — L1-05 row 32 and L1-07 state the stall trigger with the tombstoned `T_STALL` and attribute it to REC-02; the register says that name MUST NOT appear in any rule text and is not a rename of the live `T_STALL_GOV`

**Severity: Medium.** One-line rationale: the acceptance-critical description of the checkpoint record names the withdrawn parameter as the trigger the contract reads, so an implementer building the only stall clock gets the wrong name and the wrong quantity.

**Exact rule / missing rule.** `spec/04-l1-integration.html` L1-05 row 32 (raw line 164): "`lastAcceptedBatchTime` … the stall clock's source for REC-02's objective trigger (`block.timestamp − lastAcceptedBatchTime ≥ T_STALL`)"; L1-07 (raw line 247): "`lastAcceptedBatchTime` … the source of REC-02's settlement-stall clock, whose trigger reads it back from this record (`block.timestamp − lastAcceptedBatchTime ≥ T_STALL`)". Live rule: `spec/08#GOV-04`(a) — "`block.timestamp − lastAcceptedBatchTime ≥ T_STALL_GOV`". Register: `spec/09#T_STALL` tombstone — "Withdrawn with the mechanism it gated (D-15; formerly REC-02). **It MUST NOT be used by any rule, client, parameter or migration text**"; `spec/09#T_STALL_GOV` — "It is **not a rename** of the withdrawn `T_STALL`: the predicate has the same shape, but the action it gates is a queued governance action, not a bonded invocation", and its derivation is different (`T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE` versus the former `T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + T_RECOVERY_MARGIN`). `PARAM-01` makes the register "the single naming authority". **Missing rule:** the two locations must read `T_STALL_GOV` and `GOV-04`(a).

**Assumptions.** None.

**Concrete attack trace.** Not an attack: an implementer copies row 32's field semantics into the Inbox and implements/references the tombstoned name; a reviewer diffing the register finds a name the register forbids in a normative field table, and the freeze's "register audit passes in both directions" is falsified in the rule→register direction. If the tombstoned formula were used instead of `T_STALL_GOV`'s, the trigger's margin (envelope + pipeline) is wrong — a trigger below the envelope can open the governance action on a normal slow proof, which `GOV-04`(a) explicitly forbids.

**Inside / outside the claimed fault model.** Specification-completeness defect; no adversary.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** `PARAM-01` (one registered spelling; MUST NOT use the withdrawn one); D-15's replacement semantics; the round-6 freeze's audit claim.

**Evidence.** `spec/04-l1-integration.html` lines 164 and 247; `spec/08#GOV-04`(a); `spec/09#T_STALL`, `#T_STALL_GOV`, `#PARAM-01`; `spec/06#REC-02` objective-trigger row (which correctly says `T_STALL_GOV`).

---

## F5 — GOV-01 still carries the D-6-era claim that "no inclusion rule exists", contradicting D-12's live narrow forced-inclusion rules and misstating LIVE-04

**Severity: Medium.** One-line rationale: a normative rule that enumerates the protocol's mechanisms asserts a whole live rule family does not exist, and describes LIVE-04 as only the conditional statistical half.

**Exact rule / missing rule.** `spec/08-migration-upgrades.html` **GOV-01**, final parenthetical: "(user decision D-6: forced inclusion is removed, **so no inclusion rule exists** and none appears in this enumeration; **inclusion resistance is the conditional property of LIVE-04**.)" Live rules: `FI-11` is titled "the inclusion obligation and its enforcement point"; `FI-10`–`FI-14` define the record, due set, capped prefix, void predicate and no-discretion rule; `CONS-01`(v) makes omission a proposal-validity failure; `ECON-04` clause (6) is the breach; `LIVE-04`(1) is the *proof-enforced, non-conditional* inclusion obligation over published data, and (2) is the conditional statistical half. The index's own preamble says "D-12 supersedes D-6 and D-10: v1 carries a narrow forced inclusion over published data". **Missing rule:** the parenthetical must be restated to the D-12 posture (no *general* inclusion list and no DAO-dependent inclusion lever; the narrow obligation exists and is proof-enforced).

**Assumptions.** None.

**Concrete attack trace.** Not an attack. A reader building the DAO-authority model from GOV-01 (the rule that fixes what governance may touch) is told no inclusion rule exists and therefore does not audit the `publish`/due-set records for DAO-reachable state; conversely, a reviewer reconciling the offence catalogue with GOV-01 finds two rules that cannot both be true. The related `spec/08` MIG-04 note is correctly scoped to "no inclusion path or inclusion lever … in the post-migration ABI", which is true because D-12 adds no request entry point — the defect is confined to GOV-01's "no inclusion rule exists" and its LIVE-04 misstatement.

**Inside / outside the claimed fault model.** Documentation/consistency defect; no adversary.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-12 (narrow forced inclusion ships in v1) and `GEN-02` (the decision log and the specification must not diverge); `LIVE-04`'s two-part structure.

**Evidence.** `spec/08-migration-upgrades.html` GOV-01 (final parenthetical); `spec/04` FI-10–FI-14 and CONS-01(v); `spec/07` ECON-04 clause (6); `spec/10` LIVE-04 (1) and (2); `spec/index.html` rule-index preamble.

---

## F6 — Two normative-looking derivations still argue from the un-relaxed D5 ("data and proof in one transaction", "no data-first window"), which D-11 superseded

**Severity: Medium.** One-line rationale: the blob-quantisation ceiling and the validator-unbonding detection argument are justified by the premise D-11 removed, so a bound that may still hold is derived from a false reason, and one detection argument is unsound as stated.

**Exact rule / missing rule.**
- `spec/09-parameters.html` "Blob-quantisation bound on batch length" row (raw line 119): "because **D5 requires a batch's data and its proof in one L1 transaction** (L1-01), the per-L1-block blob ceiling is a ceiling on K and on `MAX_BATCH_BLOCKS`", and the fleet-sizing conclusion ("the fleet sizing of LIVE-03 and the per-batch reward floor of S3 must be read at 6") is tied to it. Under D-11 the landing transaction may carry a *reference* to an earlier publication; the ceiling now applies to the **publication** transaction (DA-07 requires the whole claimed range's blobs in one publication), so the number survives but its stated derivation does not — and the row's own "6 vs 9" arithmetic is presented as a consequence of a rule that no longer exists in that form.
- `spec/03-membership-staking.html` **MEM-05**(5): "**D5 lands a batch's data and its proof in one L1 transaction, so there is no data-first window** in which a third party could inspect a published batch and object before settlement. Detection therefore cannot rely on 'the data sat on L1 for N hours before the proof arrived'". Under D-11 exactly such a window exists (bounded by `T_PROVE_DEADLINE`), which is the entire point of the publication register; the clause's conclusion about the evidence clock is still defensible for *offence* evidence, but its stated ground is false. (Round-5 finding F10 of the liveness/UX angle, unchanged.)

**Missing rule.** Both clauses must be re-based on D-11: the ceiling on DA-07's one-publication-holds-the-range rule, and MEM-05(5)'s argument on the publication window it now actually has.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: a parameter reviewer recomputes the blob ceiling from "data and proof in one transaction" and rejects D-11's referenced path as non-conforming ("the batch's blocks plus the data must fit one landing transaction"), or, in the other direction, reads MEM-05(5) and concludes that data published before the proof can never be inspected on L1, so the forced-inclusion due set has no observable anchor — the opposite of DA-10.

**Inside / outside the claimed fault model.** Documentation/derivation defect; no adversary.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-11/`GEN-02` (the recorded relaxation must be reflected wherever the old rule is used); `PARAM-01` (derivations must be the rule's).

**Evidence.** `spec/09-parameters.html` line 119; `spec/03-membership-staking.html` MEM-05(5); `spec/04` DA-07, DA-09, DA-10; `spec/index.html` fixed-decision D5 row ("the original 'no data-first/proof-later path' wording is superseded in that one respect"); round-5 `round5t-liveness-ux-migration.md` F10.

---

## F7 — The required Inbox interface names no queue/execute/cancel entry point for GOV-04, although three clauses make them normative and MIG-02 budgets their state

**Severity: Medium.** One-line rationale: the only runtime governance action in the design has fixed state (slot 268) and three normative transitions but no ABI, so the void-on-progress race that STATUS-11 requires an interface to observe has no named function to read or call — the adapted form of round-5's R5T-D2-06 against the replacement mechanism.

**Exact rule / missing rule.** `spec/04-l1-integration.html` **L1-08**: "Every function named below MUST exist with a compatible ABI"; the sketch enumerates `publish`, `publicationAt`, `publicationCount`, `forcedSettlementAt`, `pruneExpiredPublications`, `land`, `checkpointAt`, `lastCheckpoint`, `verifierRoute`, `verifierRouteEnabled`, `attestWithdrawalRoot`, `withdrawRootAt`, `contestProof`, `withdrawalVeto` — and no queue/execute/cancel. `spec/08#GOV-04`(b): "Queueing is a DAO transaction through the authority of GOV-01 and is **the only runtime governance entry point this protocol has**"; (c): "Execution is **permissionless**: once the timelock has elapsed and the entry is not void, **any account may execute it**"; (e): "**any account may cancel it**". `spec/08` MIG-02 budgets the packed slot 268. `spec/index.html#STATUS-11`(iii) requires the interface to expose "whether a stall-resolution entry is queued and when it was queued (`govResumeState`, `govResumeQueuedAt`)". **Missing rule:** the named entry points with their payable/authorisation semantics (queue = DAO authority; execute/cancel = permissionless) and the view functions STATUS-11 presumes.

**Assumptions.** Implementation time only.

**Concrete attack trace.** Delivery risk, not an exploit: two implementations pick different selectors and authorisation models for the only action that can replace history; a wallet cannot tell whether "any account may execute" is implemented (no named function to call), and an interface cannot satisfy STATUS-11(iii) without inventing a reader. In the worst case an implementer makes execution DAO-gated "for safety", which silently converts the timelocked resume into a second governance transaction and changes the disclosed model (A-GOV-2 says governance queues; the rule says anyone executes).

**Inside / outside the claimed fault model.** N/A (completeness). Inside the "leaves a security-relevant interface to invent" class, at the lower end.

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** L1-08's completeness claim; `GOV-04`(b),(c),(e); `STATUS-11`(iii); D-15 (the replacement must be specified far enough to build).

**Evidence.** `spec/04-l1-integration.html` L1-08 function sketch (lines 339–430); `spec/08` GOV-04(b),(c),(e) and MIG-02 slot 268; `spec/index.html#STATUS-11`(iii); round-5 `round5t-d2-recovery.md` R5T-D2-06.

---

## F8 — PARAM-01 calls `T_PROCESS` a registered canonical spelling, but the table has no row for it

**Severity: Low.** One-line rationale: a smaller both-directions register gap — the name is consumed by two registered formulas and named in the naming-authority rule, yet carries no unit, derivation or tag.

**Exact rule / missing rule.** `spec/09-parameters.html` **PARAM-01**: "Every parameter appears in the table below with: its identifier, unit, proposed value or formula, the derivation or source, and a tag … in particular `W_EVIDENCE` (not `W_evidence`), **`T_PROCESS` (not `T_process`)**". `T_PROCESS` is a term of `D_WITHDRAW` ("≥ … + `T_L1_final` + `T_PROCESS` + M") and of `W_EVIDENCE` ("… + `T_detect` + `T_evidence_submit`"; "`W_EVIDENCE + T_PROCESS + CORR_DELAY + M_ev < D_WITHDRAW`"). A mechanical scan of every first-column identifier in the register (106 tokens) against pages 01–08 and 10 finds only `value_at_risk(D_MAX)` and `T_RECOVERY_MARGIN` unread — both disclosed — so `T_PROCESS` is in the opposite direction: used, declared registered, and absent as a row. **Missing rule:** a row with unit, owner and tag, or the removal of the parenthetical's claim.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: an implementer sizing `D_WITHDRAW`/`W_EVIDENCE` has no registered definition of one of their terms, and PARAM-03's unmeasured register carries no experiment for it, so the term can silently be set to zero.

**Inside / outside the claimed fault model.** N/A.

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** `PARAM-01`, `PARAM-03`; the freeze's "register audit … passes in both directions".

**Evidence.** `spec/09-parameters.html` line 20 (PARAM-01), lines 122–123 (`D_WITHDRAW`, `W_EVIDENCE`); `spec/07` ECON-07; mechanical scan described in Method.

---

## F9 — The course glossary names the validator unbonding delay "Withdrawal delay (D_WITHDRAW)", the alias collision PARAM-01 forbids

**Severity: Low.** One-line rationale: the register forbids substituting `D_WITHDRAW` and `WITHDRAWAL_DELAY`, and the course's glossary gives the bridge-facing phrase "withdrawal delay" to the validator-side parameter.

**Exact rule / missing rule.** `spec/09#PARAM-01`: "`WITHDRAWAL_DELAY` (the L2→L1 release delay owned by MSG-03) and `D_WITHDRAW` (the validator unbonding delay owned by MEM-05 clause 4) are distinct parameters with distinct consumers, and **no rule may substitute one for the other**." `learn/glossary.html` entry "Withdrawal delay (D_WITHDRAW)" defines it as the wait before an owner withdraws unbonded stake; the glossary's *withdrawal-eligible* entry and `learn/02`/`learn/07`/`learn/09` use "withdrawal delay" for the bridge release. A user searching the reference for "withdrawal delay" gets the validator parameter. **Missing rule:** the glossary must carry both entries under their canonical names, or title the validator one "unbonding delay (D_WITHDRAW)".

**Assumptions.** None.

**Concrete attack trace.** Not an attack: an integrator reads "Withdrawal delay (D_WITHDRAW)" as the delay gating a bridge release and sizes the exit window against the wrong quantity (validator unbonding, in the tens of epochs, instead of the bridge release delay measured from a root).

**Inside / outside the claimed fault model.** N/A.

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** `PARAM-01`'s alias discipline; `GEN-07` (controlled vocabulary — a document may not introduce a synonym for a defined term); R14.

**Evidence.** `learn/glossary.html` rows "Withdrawal delay (D_WITHDRAW)" and "Withdrawal-eligible"; `spec/09#PARAM-01`, `#WITHDRAWAL_DELAY`, `#D_WITHDRAW`.

---

## Checked, and holds (not re-listed as findings)

- **The freeze's quantitative audit is reproducible and true for ids and links.** 161 anchored rule ids, 161 rule-index rows, exact bijection (including `FI-REMOVED-01` and `FI-PLANNED-01`); 3,918 internal links, 0 broken targets or anchors. No rule id is referenced without an anchor and no anchor lacks an index row.
- **The parameter register passes in the rule→register direction except F8/F4.** Scanning all 106 register first-column identifiers against pages 01–08 and 10, the only names read by no rule are `value_at_risk(D_MAX)` (retained "disclosure only", explicitly read by nothing) and `T_RECOVERY_MARGIN` (tombstoned); `MIN_BATCH_BLOCKS`, `SUBSIDY_CAP`, `SUBSIDY_END` and `FI_REGISTER_MAX` are explicitly moved to non-normative notes with reasons.
- **D-11/D-12/D-13 are consistently reflected in the machinery I sampled**: `L1-01`–`L1-04` (no entry point advances the checkpoint without a proof; no second queue), `DA-01`/`DA-07`–`DA-10` (publication record, identity, deadline, one register), `FI-10`–`FI-14` with the enforcement point at the proof, `L1-13`/`L1-14`/`PRF-15` (one object per purpose, per-purpose counts), and `ECON-02` clause 5(e) (the allocation policy has exactly two shares; `ALLOC_REC_PPM` withdrawn). I found no live rule that assumes a completion reward, an escalation, a cooldown, a recovery bond or a retired height **inside the specification**.
- **The D-14 heartbeat set is internally consistent** across `MEM-13`, `CONS-16`, `09` (the window/sequence payload, the recorded window start, `T_ROTATE ≥ HEARTBEAT_WINDOW`) and the course glossary; the withdrawn decay names (`T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved`) carry tombstone rows and are not used as live. I did not re-attack the eligibility predicate's soundness (another angle owns it).
- **The governance-liveness dependency is disclosed in the specification wherever it matters**, by name or by rule: `GOV-01`, `GOV-02`, `GOV-04`(g), `REC-03` residuals, `HALT-04`, `SYS-04`(a), `ROLE-05`, `STATUS-04`, `STATUS-11`, `LIVE-01`, `LIVE-05`, `LIM-01` (A-GOV-2 row) and `09`. The failure is in the *course* (F1), not in the specification.
- **The round-5 mechanism findings against the withdrawn recovery are moot by construction, not by repair.** The bundle-maximality Critical, the L1-unverifiable completion evidence and the bond-pricing findings targeted REC-02/03/04 machinery that `GOV-04`(c) replaces with a boundary fixed by L1 state alone; I re-checked that no live rule still needs a bundle, a completer, maximality or per-signer weights on L1. The naming residue is F3/F4.

## Round-5 items I re-verified as still open (not newly discovered; one line each)

- **Round-5 R5T-D2-05 / F7 — the `CONS-16` rotation can strand finalized-but-unsettled heights above the checkpoint by a path other than `GOV-04`.** Still open and still contradictory on its face: `REC-01`(a)/(d), `HALT-04`, `INV-01` and `LIM-01`'s guarantee-class row say "and by nothing else", while `CONS-16`(5) and `LIM-01`'s F7 row state a rotation can replace that history and call it "a REC-01 defect". D-15 did not touch it. It remains disclosed as Open, so it is a known contradiction rather than a concealed one; I could not re-break it further in this round.
- **Round-5 R5T-D2-03 — the "exactly three ways" enumeration in REC-03 still omits a rule-legal L2-only path to the trigger** (one proposer slot certifying a block whose proof no one completes inside `T_PROOF_MAX_PERMITTED`, with strict sequential acceptance blocking the checkpoint). The text is unchanged; the falsifier list still has no row for it. Reported here only as persisting; the consensus-liveness angle owns its substance.
- **Round-5 F6 — the course's withdrawal path omits the withdrawal root, the k-family count and the veto.** Now part of F1's sweep failure: `learn/09` (raw lines 111, 184-185, 258-259, 284-285, 337-342) still teaches "checkpoint + message path + `WITHDRAWAL_DELAY` measured from the checkpoint's `l1BlockNumber`" as the minimum evidence for a release, with no root and no `T_VETO`, against `MSG-03`(5)'s MUST-disclose obligation and `L1-13`(5). It is not fixed by the D-15 sweep (that page has a `D-15` marker but was only partially updated).
