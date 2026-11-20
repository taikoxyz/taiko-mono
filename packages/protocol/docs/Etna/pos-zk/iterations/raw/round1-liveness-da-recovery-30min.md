# Round 1 — adversarial review: liveness, data availability, censorship, recovery, 30-minute pipeline

Reviewer angle: **liveness / DA / censorship / recovery / pipeline** (independent adversarial).
Snapshot: commit `dfcf067a5b91a1b0bacd4470f5f5054d1f861a24` (branch `etna-pos-zk`); working tree unchanged.
Scope attacked: `spec/06-recovery-exceptions.html` (HALT-*, WH-*, REC-*), `spec/04-l1-integration.html` (L1-01..L1-12, DA-01..DA-06, FI-01..FI-05), `spec/10-assurance.html` (LIVE-01..03, LIM-01), `spec/01-system-model.html` (SYS-02, ROLE-0x), with cross-checks into `spec/02-consensus.html` (CONS-01, CONS-13..15), `spec/05-proof-statement.html` (PRF-02, PRF-04..08), `spec/09-parameters.html` (PARAM-01..03) and `04-architecture-decision.md` / `DECISIONS.md`.

Conventions: an attack is *inside the fault model* only if it needs at most (a) <1/3 Byzantine stake, (b) network/withholding capabilities T-1/T-4, (c) permissionless user actions, (d) L1-inclusion actions, or (e) failures of the stated liveness assumptions A-CONS-2/3, A-CONS-5, A-DA-1..4, A-L1-1/2, A-ECO-*. A prover that is merely slow (but honest) is **inside** the stated assumptions: D6 says the envelope is a planning assumption, A-DA-2 requires only eventual completion by some prover, and HALT-03 states no proving-latency bound exists.

Severity summary: **Critical 3 (R1-01..R1-03) · High 4 (R1-04..R1-07) · Medium 4 (R1-08..R1-11) · Low 0.**

---

## R1-01 — Forced-inclusion dueness is adversarial and the per-batch cap makes the halt permanent

**Severity: Critical** — any single user, with no stake and no fault-model violation, can drive the chain into a permanent safe halt; there is no rule-legal exit.

**Exact rule / missing rule.**
- `spec/02-consensus.html#CONS-01` (v): *"The block MUST contain each element of Due(H) exactly once, in the order FI-02 fixes … A block that omits a due request, duplicates one, includes one that is not yet due … is not valid at (H,R)."*
- `spec/04-l1-integration.html#FI-02` (b): `require(setEquals(coveredIds, due))` — **exact equality**, not containment.
- `spec/04-l1-integration.html#FI-05` (b): *"the number of requests a single batch can cover MUST be bounded by `MAX_FORCED_INCLUSIONS_PER_BATCH`"*.
- `FI-05` (c): *"the queue length MUST be bounded relative to `MAX_UNSETTLED_AGE`"* — stated as an obligation with **no mechanism, no parameter, and no enforcement rule anywhere in the specification**.
- **Missing rule:** there is no rule that bounds `|Due(H)|` by `MAX_FORCED_INCLUSIONS_PER_BATCH`, no queue-length cap in the Inbox, no deduplication requirement, no request expiry, and no rule that lets `land` accept a batch that covers *fewer* than all due requests. The three rules above are mutually unsatisfiable once a block's due set exceeds the cap.

**Assumptions / preconditions.** None beyond ordinary operation: L1 inclusion liveness (A-L1-1), one permissionless user with ETH. The dueness clock is L1 time (`eligibleAtL1Timestamp = block.timestamp + FORCED_INCLUSION_DELAY_SECONDS`, FI-01) and any L1 block may carry many `requestForcedInclusion` calls, so the arrival rate of due requests is attacker-controlled and effectively unbounded per L1 block, while the drain rate is `MAX_FORCED_INCLUSIONS_PER_BATCH` per **batch** (a batch spans 64 s at K=32, PARAM-02 ≈ 5.3 L1 slots).

**Concrete attack trace.**
1. Attacker posts `N = MAX_FORCED_INCLUSIONS_PER_BATCH + 1` requests in one or a few L1 blocks (cost: escalated fees, FI-05; all refundable later per FI-03(b), so the net cost is time-value of capital plus `CANCELLATION_COST` only if cancelled early).
2. After `FORCED_INCLUSION_DELAY_SECONDS` (and the SYS-02 finality delay), every request is eligible. L1's `due` set (FI-02 b) now has `N` elements; `N > MAX_FORCED_INCLUSIONS_PER_BATCH`.
3. Any proposal at any height `H` is invalid unless its block contains **all** `N` requests (CONS-01 v). If the proposer includes fewer than `N`, honest validators must prevote NIL; if the proposer includes more than the per-batch cap, it violates FI-05(b). Either way, no valid proposal exists → no block, no height advance.
4. L1 `land` cannot help: `setEquals(coveredIds, due)` requires the submitted batch to cover all `N` ids, and no L2 batch can legally contain all `N` (step 3). `coveredIds` is submitter-supplied but the proof binds the batch's blocks, so a fabricated coverage list does not by itself change the L2 content (see R1-02).
5. Production stops forever. The due set never shrinks (nothing lands, nothing executes), so step 3 remains true after any amount of waiting. HALT-01(e)/HALT-03 declare this a "safe halt"; HALT-04 forbids any operator, DAO or guardian rescue; FI-03(a) keeps the requests queued forever; FI-03(c) confirms `land` continues to reject. A governance upgrade is the only exit, and HALT-04 says `land`'s admission rules must not be relaxed.
6. The permanent halt is not "recoverable" as DA-06 claims: it is *priced* — the attacker's loss is bounded by refundable fees plus time-value, the chain's loss is unbounded.

**Inside / outside the claimed fault model.** **Inside.** The attacker is an ordinary user (threat T-13 griefing/DoS on permissionless entry; T-4/T-7 not even needed). No assumption fails: A-L1-1 holds, validators are honest, provers are irrelevant.

**Attacker resources and cost.** N requests × current fee. The fee formula (FI-05) makes the last request cost ≈ `BASE_FEE·(threshold+N)/threshold` (capped at `MAX_FEE`), so the burst costs O(N²·BASE_FEE/threshold) — for the baseline-shaped parameters (`baseFee = 1e6 gwei`, `threshold = 50`; `MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10` at `7718753c1`, recorded in `research/taiko-baseline-contracts.md:331,373-375`) the burst is ≈ 11 requests, low single-digit ETH, and **refundable**. All parameters are tagged `unmeasured`, so the specification cannot show the cost is prohibitive.

**Harm and requirement.** R6 (conditional liveness — the condition is met and liveness still ends permanently), R10 (censorship resistance / forced inclusion becomes the censorship weapon), and the HALT-01 claim that a halt is a *correct, preserve-Mode-A* outcome: here the halt preserves Mode A while destroying the chain. D2 is nominally respected (no rollback), but the design has produced a rule whose only remedies are forbidden.

**Evidence.** Worked trace above; the satisfiability contradiction is explicit in the two quoted clauses: CONS-01(v) demands the block contain every due element, FI-05(b) caps the count below what the attacker can make due. The baseline is instructive: today `_consumeForcedInclusions` processes *at least* `dueToProcess` (`00-baseline-and-lessons.md:108`, `research/taiko-baseline-contracts.md:388`) — backlog persists and is worked off later. The redesign's "exact equality over the whole due set" removes that safety valve without adding a substitute.

**What a rule must say (minimum fix).** Either (i) cap the queue so `|Due(H)| ≤ MAX_FORCED_INCLUSIONS_PER_BATCH` is invariant (queue cap + FIFO admission rejection or explicit backpressure on `requestForcedInclusion`), or (ii) replace exact equality with "all due requests up to the cap, and the covered set must be the FIFO prefix of `due`", so a backlog is drainable; plus a rule stating which of the two is normative and how `land` computes `due` in O(1)/O(covered).

---

## R1-02 — The L1 backstop does not verify that forced-inclusion payloads were included: the commitment never reaches the proof

**Severity: Critical** — the single mechanism the specification provides against a colluding quorum censoring a user is not bound by the proof; a >2/3 quorum can consume and discard an inclusion with every L1 check passing, and nothing objective is ever produced.

**Exact rule / missing rule.**
- `spec/04-l1-integration.html#L1-05` row 20: `forcedInclusionCommitment` — provenance *"L1-derived over the covered set"*, and the rule text says the statement *"MUST bind every value in the table"*.
- `spec/04-l1-integration.html#FI-02` (b): *"a proposer can neither omit a due request nor pad the batch … `require(setEquals(coveredIds, due))`"* — presented as the **L1 backstop** against a colluding quorum (*why*: *"without the L1 backstop, a colluding quorum can omit a request forever while continuing to land batches"*, failure mode (b)).
- `spec/05-proof-statement.html#PRF-02` — the **actual** journal has **no** forced-inclusion field: `domain, l1ChainId, l2ChainId, prevHeight, prevBlockHash, prevStateRoot, epoch, validatorSetRoot, totalVotingPower, quorumThreshold, configHash, firstHeight, lastHeight, headBlockHash, postStateRoot, dataCommitment, blobHashesHash, challengeZ, evaluationsY`.
- `PRF-04` and `PRF-06` — the consensus and execution checks — contain no check that a block contains any forced-inclusion payload; `PRF-01` defines the proven claims as W1 (finality), W2 (execution) and W3 (data binding) only.
- **Missing rule:** nothing requires the guest to prove that, for the batch's range, every due request's payload appears as a transaction in the executed blocks in the FI-02 order, and nothing binds `coveredRequestIds` into the journal.

**Assumptions / preconditions.** Byzantine stake ≥ 2/3 (or, more weakly, a colluding proposer plus a quorum that follows it). This is outside the *normal* fault model — that is precisely why FI-02(b) exists. The point of this finding is that the mechanism claimed to cover that case does not exist, so R10's anti-censorship guarantee has no backstop at all.

**Concrete attack trace.**
1. A user is censored on L2 and posts `requestForcedInclusion(payload)` on L1 (FI-01). `payload` is stored in Inbox storage; after the delay it is `due` in L1's sense.
2. A colluding quorum finalizes a batch of L2 blocks that **omit** `payload` entirely (CONS-01(v) violated; honest validators would reject, but they are <1/3 or offline — a halt, which the cartel prefers to avoid, so it keeps a bare quorum online and simply never builds the payload in).
3. The cartel collects the batch's proof. The guest proves W1 (head certificate), W2 (execution of *its* blocks from `prevStateRoot`) and W3 (`dataCommitment` = keccak of *its* payload). Nothing in the journal or the checks concerns `payload`.
4. The cartel calls `land(proof, input)` with `coveredRequestIds = due`. L1's checks: `keccak256(abi.encode("TAIKO_ETNA_FI", chainId, coveredIds)) == forcedInclusionCommitment` (trivially satisfied because the contract computes the commitment from the same list), `setEquals(coveredIds, due)` (true), drift bound (true). The proof verifies against the journal, which does not mention the coalesced ids.
5. `consume(coveredIds)` marks the request consumed and pays its fee to `feeRecipient` (L1-11). The request leaves the due set forever. The censored transaction is never executed, and no L1-verifiable evidence of the omission exists.

**Inside / outside the claimed fault model.** The *attack* (≥2/3 quorum censorship) is outside A-CONS-1 by construction. The **finding is inside**: a rule that the specification claims closes that case (`FI-02`(b), the "L1 backstop") does not close it, because the binding it relies on is absent from the statement the proof actually proves. A specification may declare a case out of scope; it may not declare it covered by a mechanism whose inputs do not include the fact.

**Attacker resources and cost.** ≥2/3 of staked TAIKO (outside A-CONS-1) — or, if the intent is the sub-threshold reading, note that the L2 rule (CONS-01 v) still protects honest-majority operation. The cost of exploiting the *absent backstop* is zero beyond the quorum itself.

**Harm and requirement.** R10 (censorship resistance and forced inclusion without an override violating D2); FI-02's own stated guarantee; R13 (a security-relevant rule is left for the implementer to invent — here, an implementer would have to guess whether to add the commitment to the journal, and if they add it inconsistently with PRF-02's "exact list, order is normative", the guest and the Inbox disagree and no proof ever verifies). D5 is not violated (data still travels with the proof), which is exactly why this is easy to miss: atomicity is not coverability.

**Evidence.** Direct rule comparison: L1-05 row 20 exists; PRF-02's journal (the normative "exact list") omits it; PRF-04/PRF-06 contain no force-inclusion check; DA-04's "no witness substitutes for on-chain data" is about the batch data, not about the forced payloads.

**What a rule must say.** Either add `forcedInclusionCommitment` (ordered ids **and** the payload hashes) to PRF-02's journal and add a guest check that every due payload appears in the executed blocks in the FI-02 order within the FI-02 gas limit, or make the Inbox verify the payload placement directly on `_batchData` (possible on the calldata path because the contract computes `dataCommitment` itself over the exact bytes). One of the two must be normative; leaving both implicit is the defect.

---

## R1-03 — HALT-03's unsettled-depth cap is unobservable, and its violation is not objectively detectable; D_MAX cannot bound retention exposure

**Severity: Critical** — a consensus rule the specification calls "consensus-enforced" and "objectively detectable" is neither; the mechanism intended to keep Mode A from becoming permanently unprovable does not bound the quantity it exists to bound.

**Exact rule / missing rule.**
- `spec/06-recovery-exceptions.html#HALT-03`: *"Define the unsettled depth at a height as the number of L2 blocks between the highest L1-accepted checkpoint and the block being considered. A correct validator must not prevote or precommit a block whose unsettled depth would exceed `D_MAX`. … The cap is a consensus rule: it is enforced by validators, not by an operator, and violating it is objectively detectable."*
- `spec/04-l1-integration.html#DA-06`: *"Define `unsettledAge` as the L1-block distance between the oldest PoS-finalized-but-not-landed L2 block and the current L1 block. Correct validators MUST refuse to vote for a block that would make `unsettledAge` exceed `MAX_UNSETTLED_AGE`, so that the oldest unsettled batch never leaves the retrievability window before it can be proven and landed."*
- `spec/09-parameters.html#PARAM-02`: `D_MAX` = *"(retention window seconds) / L2_BLOCK_INTERVAL, minus queueing and L1 inclusion margin"* — **no proving-throughput term**; placeholder 3,600 blocks.
- **Missing rules:** (i) no rule defines how a validator computes "the highest L1-accepted checkpoint" (L1 `lastLandedHeight` is L1 storage; SYS-02 and L1-12 forbid L2 from acting on unfinalised L1 facts, while a *validator's* cap check needs L1 state at L1 finality); (ii) no rule defines the relationship between the L2-block unit of `D_MAX` and the L1-block unit of `MAX_UNSETTLED_AGE` (they are never equated, and PARAM-01/02 contain no conversion); (iii) no offence, evidence rule or penalty exists for voting past the cap, so "objectively detectable" has no consumer; (iv) no rule bounds the wait time of an *already-committed* block, which is the quantity the retention window actually has to cover.

**Assumptions / preconditions.** Normal operation. The gap does not need an attacker at all; it needs only the observation lag that SYS-02 itself mandates.

**Concrete trace (a) — systematic overshoot, no attacker.**
1. L1 accepts a `land` for height `h_L` at L1 block `n`. SYS-02(b) makes that fact usable to L2 only when Ethereum-final (≈2 epochs ≈ 64 slots ≈ 12.8 min) plus observation time; GEN-06/R12 forbid any L1-lookahead shortcut and L1-12 forbids L2 rules from treating inclusion-depth L1 facts as settled.
2. During that window validators keep the *stale* checkpoint (`h_L`), so the depth they measure is smaller than the true depth. At 2 s per L2 block, 12.8 min of finality lag alone is 384 L2 blocks of unobserved advance (fixed-decision arithmetic, D1; the exact overshoot is a queueing function of `land` cadence, but it is ≥ the number of blocks produced while a landed checkpoint is not yet observable, and unbounded in the limit of a validator's L1 view being unavailable — see (b)).
3. The true `lastLandedHeight` can therefore sit arbitrarily far behind the head while every validator believes it is within `D_MAX`. Nothing in the specification makes the estimate conservative (a "count only L1 facts at finality depth" rule would make it conservative-but-stale; no such rule exists).
4. The declared property — "the oldest unsettled batch never leaves the retrievability window" — is false by up to the observation gap plus the tail of the queue, and the declared detection property ("objectively detectable") has no evidence encoding: a voter at depth `D_MAX + k` produces no signed object that proves the L1 checkpoint at that moment.

**Concrete trace (b) — the derivation gap is structural, not a parameter gap.**
1. Take a batch committed at depth `D_MAX − k` (1 block below the cap), the last block a validator is allowed to vote for.
2. Proving capacity is at its permitted worst case: D6/HALT-03 explicitly state that proving latency above 30 minutes is "not misconduct", A-DA-2 requires only that *a* prover completes each batch eventually, and A-DA-2's envelope is a planning assumption (PARAM-02: "explicitly not a worst-case bound").
3. If the head of that batch takes longer to prove than the interval it took the chain to produce it (or if its predecessor's proof is what is stuck), the oldest-unsettled-block lifetime is unbounded while `D_MAX` is respected at commitment time. When the retention window finally closes, the batch can no longer be proven *by anyone*, and Mode A forbids discarding it: the exact permanent-halt state HALT-03 exists to prevent.
4. The retention inequality `RETRIEVABILITY_WINDOW ≥ MAX_UNSETTLED_AGE + SETTLEMENT_PIPELINE + EVIDENCE_WINDOW` (DA-06) does not repair this: `MAX_UNSETTLED_AGE` bounds the distance from the frontier, not the wait of the oldest unsettled block, and the inequality is stated with all four terms unmeasured (PARAM-03 lists "Retrievability duration of L2 data held by validators and nodes" as unmeasured).

**Inside / outside the claimed fault model.** **Inside.** Slow-but-honest proving is explicitly inside (D6, HALT-03, A-DA-2); the L1-finality observation lag is *mandated* by SYS-02. No Byzantine party is required for (a) or (b).

**Attacker resources and cost.** Zero for (a). For (b), a prover cartel (T-9) can hold one batch's proof while continuing to prove later batches — that is *permitted* by the specification ("a proof that has not been submitted" is not evidence, WH-02), and it holds the retention clock.

**Harm and requirement.** R6 (liveness ends where the specification says it does not), R9/R8 (a legitimately finalized batch becomes unprovable and unsettleable), D5/D6 consistency (the cap is the only mechanism linking the 30-minute envelope to retention); R13 (the cap's computation, enforcement and evidence are left to the implementer).

**Evidence.** `HALT-03` text; `DA-06` text and its inequality; `PARAM-02`'s `D_MAX` formula (no throughput term) and `PARAM-03`'s admission that retention is unmeasured; SYS-02(b) finality definition; L1-12's ban on unfinalised L1 facts in L2 rules.

**What a rule must say.** Define the depth observable (e.g. the highest checkpoint whose accepting L1 transaction is at the configured finality depth for the validator's own L1 view), state that the observable is *conservative by construction*, define the `D_MAX` ↔ `MAX_UNSETTLED_AGE` conversion (or collapse them into one parameter), add a proving-side obligation whose breach is objectively evidenced (e.g. a batch-age evidence object) or an explicit statement that no such obligation exists and that the retention claim is conditional on measured proving throughput.

---

## R1-04 — Retention cannot be enforced at all: "retention duty" has no measurable, observable or sanctionable form

**Severity: High** — the guarantee the whole DA design rests on is an assumption with no runtime check, no evidence object, and no link to the cap that is supposed to enforce it.

**Exact rule / missing rule.** `spec/04-l1-integration.html#DA-05`: *"an `ARCHIVE_REQUIREMENT` fixing how many independent archive nodes must retain the full accepting-transaction calldata and full blob sidecars for at least that window, with the duty owned by ROLE-03"*; `ROLE-03`(b) assigns the duty to validators/archive nodes; `WH-01` (row "Execution witness") states that a failure to serve *"is why A-DA-4 is an economic and liveness assumption, not an enforceable duty"* and WH-02 says non-receipt is never evidence.
- **Missing rule:** no rule states what happens when `ARCHIVE_REQUIREMENT` is not met, how anyone determines whether it is met, what an operator must publish if it stops retaining, or what makes retention verifiable at the moment it matters (the moment a prover needs the bytes). No parameter in PARAM-01/02/03 fixes `ARCHIVE_REQUIREMENT`'s value or its unit ("how many" is not defined as a number that can be compared to anything).

**Assumptions / preconditions.** A-DA-1/A-DA-3/A-CONS-5. If they hold, this is only an auditability defect; if they fail even transiently (a single archive operator exiting, a blob-sidecar provider pruning early), the failure is detected only when a batch becomes unprovable — and per R1-03 the cap does not bound when that happens.

**Concrete trace.** A node that holds data and stops serving it is, per WH-01, not sanctioned and not provable; a light client or a prover discovering unavailability has *"local suspicion"* (WH-02) and may not escalate it. A total loss of the oldest unsettled batch's data therefore surfaces first as `land` being impossible for a batch that is already PoS-finalized — i.e. as the permanent-halt state, with the specification's only answer being the disclosed limitation in LIM-01 ("Retention is a duty, not a cryptographically enforceable property").

**Inside / outside the claimed fault model.** Inside for the *disclosure* part (LIM-01 lists it). **Outside the disclosure** for the specific claim that DA-06's cap makes the failure bounded and recoverable: retention is not tied to any observable, so the cap cannot be tied to retention.

**Attacker resources and cost.** None; failure can be spontaneous (node churn) or induced by cheap disk/bandwidth pressure.

**Harm.** R6, R8/A-DA-1: the "settlement depends on somebody retaining the data" limitation is disclosed, but the specification then claims a mechanism (the cap + DA-06's inequality) bounds the exposure; it does not, because neither the quantity retained nor the number of retainers is observable or enforced.

**Evidence.** DA-05 (a)-(c); ROLE-03(b); WH-01 witness row; WH-02; LIM-01 "Availability" rows; PARAM-03 (retention duration unmeasured).

**Required rule.** Either (i) state explicitly that retention is an unenforced assumption and remove the "the cap converts an unbounded failure into a bounded, recoverable halt" claim in DA-06, or (ii) make retention observable: e.g. require validators to publish signed retention attestations ("I hold and can serve batch b") whose absence is a *published fact* (not a slashable offence, which WH-02 forbids), and derive `D_MAX` from that published statistic.

---

## R1-05 — `D_MAX`/backpressure is unenforceable against a quorum and unobservable to L1, so retention exposure is not bounded by the cap

**Severity: High** — the backpressure rule is a validity rule only; there is no L1-side, proof-side or evidence-side expression of it, so the exposure the cap claims to bound is not bounded in the only case that matters (a colluding or misconfigured quorum).

**Exact rule / missing rule.** `HALT-03` (consensus rule, "violating it is objectively detectable"), `CONS-15`(5) (halting on cap exceedance), `LIVE-02`(a) (validators refuse to vote at `D_MAX`), `L1-04` (the cap *"MUST NOT be implemented as an admission condition on land"*).
- **Missing rule:** nothing in `L1-05`'s binding list, `PRF-02`'s journal or `PRF-04`'s checks commits to the unsettled depth or the checkpoint height in a way that would let an L1 observer or the proof detect a cap violation. A quorum that keeps voting past `D_MAX` (or votes with an over-optimistic checkpoint estimate) produces blocks whose proofs verify normally; the cap is invisible to L1 and to the guest. `CONS-01` (iv) makes execution validity slashable-in-principle only where objectively decidable; the cap is not in the "objectively decidable" list (CONS-01 lists (ii), (iii), (v)).

**Assumptions / preconditions.** A quorum (or a client bug, or a systematically stale L1 view as in R1-03) votes past the cap. Inside the fault model for the *client-bug* and *stale-view* variants (F3/F1); the Byzantine variant is outside A-CONS-1 but the specification claims the rule is *objectively detectable*, which is a claim about all cases.

**Concrete trace.** (1) Validators use a stale L1 observation (R1-03). (2) Production continues to head `h_L + D_MAX + g` where `g` is the gap of R1-03. (3) A batch whose head is the overshoot block lands normally: the header chain links, the certificate verifies, `land` has no depth condition (L1-04 forbids one). (4) The retention window now must cover `D_MAX + g` plus queue wait, not `D_MAX`; the DA-06 inequality and `D_MAX`'s derivation silently under-provision. (5) No evidence object exists, so no one can even establish afterwards that a violation occurred.

**Inside / outside the claimed fault model.** Inside for stale-view/client-bug variants (no stake required). The claim "objectively detectable" fails for every variant.

**Attacker resources and cost.** Zero to run the stale-view variant; no reward required.

**Harm.** R6, R13 (a security-relevant rule with no stated observable/evidence), and it compounds R1-03/R1-04: the retention guarantee has no enforcement point anywhere in the design.

**Evidence.** CONS-01's closed list of objectively decidable violations; L1-05's complete binding table; PRF-02/PRF-04; L1-04's explicit ban on implementing the cap as an admission condition (which removes L1 as an enforcement point but does not replace it).

**Required rule.** State the cap's observable (as R1-03 asks), and either make cap exceedance objectively evidenced (e.g. the checkpoint record or the journal carrying the committed checkpoint height, with a comparison to the batch's head in-guest and a published offence entry in ECON-04) or state explicitly that the cap is unenforceable and that retention exposure is not bounded.

---

## R1-06 — FORCED-INCLUSION DUE CLOCK: height-based dueness (CONS-01) vs timestamp-based dueness (FI-02), with undefined `include_by_height` and `land` loops that cannot satisfy both L1-04 and FI-05(d)

**Severity: High** — a security-relevant validity rule is left ambiguous; two implementers can disagree about the same signed proposal, which both breaks consensus liveness and weakens slashing.

**Exact rule / missing rule.**
- `spec/02-consensus.html#CONS-01`(v): `Due(H)` = *"requests whose `include_by_height ≤ H`"* — a **height** comparison. `include_by_height` appears **nowhere else** in the specification: the FI-01 struct defines `eligibleAtL1Timestamp`, not `include_by_height` (grep over `spec/` finds a single occurrence).
- `spec/04-l1-integration.html#FI-02`(b): `due = { r : r.eligibleAtL1Timestamp <= _input.firstBlockTimestamp && !consumed[r] }` — a **timestamp** comparison against a *claimed* L2 header field, with the L1 check being only `block.timestamp <= firstBlockTimestamp + FORCED_INCLUSION_MAX_DRIFT`.
- CONS-01(v) also requires inclusion *"within the per-request gas limit FI-02 fixes"* — **FI-02 fixes no per-request gas limit** (FI-01 fixes `MAX_FORCED_INCLUSION_BYTES`, a byte bound, not gas).
- `L1-04`: structural bounds permitted are *"exactly these: the range must be contiguous … the batch must be non-empty; and every loop in `land` must be bounded by the transaction's own contents … never by an unbounded external structure"*. But FI-02's `due` computation is `{ r in queue : … }` — a scan of the whole L1-stored queue — and FI-05(c) only says the queue *"MUST be bounded relative to MAX_UNSETTLED_AGE"*, with no cap, no mechanism, and no parameter value.
- **Missing rules:** the definition of `include_by_height`; the normative statement that L1's timestamp test and L2's dueness test are the same predicate (or how they differ); a queue-length cap that makes FI-02's scan legal under L1-04; the per-request gas limit.

**Assumptions / preconditions.** None: the defect is present in ordinary operation and bites at the first disagreement.

**Concrete trace (disagreement).** A request becomes eligible at L1 time `T` (`eligibleAtL1Timestamp = T`). Proposer A, reading `include_by_height` as "the first height whose timestamp exceeds `eligibleAtL1Timestamp`", includes the request at height `H`. Proposer B, reading dueness as "the request is due once the L1 event is Ethereum-final" (SYS-02 f), does not. B's proposal is valid to B and invalid to A, and vice versa: honest validators split on the same signed object. Depending on which interpretation the L1 backstop uses, either a valid proposal cannot land (A's batch has `coveredIds` that L1's `due` does not yet contain → `ForcedInclusionNotCovered`), or a censoring proposal *can* land (B's batch omits a request that CONS-01 already makes due → the L2 rule was violated, but L1's timestamp test says it was not due). Neither branch is specified, and the slashing scope in CONS-01 makes "(v) a due forced inclusion omitted" an offence — so the ambiguity converts honest disagreement into slashable behaviour.

**Inside / outside the claimed fault model.** Inside: no adversary is needed; the ambiguity is exercised by two honest implementers.

**Attacker resources and cost.** Zero; an adversary simply chooses the interpretation that favours omission and points at the specification.

**Harm.** R6 (halts from honest disagreement), R13 (implementer must invent the rule — exactly the failure mode CONS-01's own *why* warns about), R11 (slashing scope depends on the invented rule), and R10 (the L1 backstop's coverage depends on which clock L1 uses).

**Evidence.** Single-occurrence grep for `include_by_height`; FI-01 struct vs FI-02 predicate; CONS-01(v)'s reference to an FI-02 gas limit that does not exist; L1-04's "exactly these" structural bounds vs FI-02's queue scan.

**Required rule.** One predicate, stated once, with its clock named, its conversion from L1 time to L2 headers fixed (or an explicit statement that L1 checks only inclusion of ids and L2 checks placement), plus a queue bound and an O(covered) algorithm for `due`.

---

## R1-07 — The drift bound is an omission window: a quorum that skews `firstBlockTimestamp` can exclude eligible requests while every check passes

**Severity: Medium** — a systematic, cheap mechanism to omit forced inclusions for up to the drift bound, degrading R10 without breaking any literal rule; the parameter that bounds it is unmeasured.

**Exact rule.** `FI-02`(b): `require(block.timestamp <= _input.firstBlockTimestamp + FORCED_INCLUSION_MAX_DRIFT)` and `due` computed from `firstBlockTimestamp`. `FI-02` notes: *"the bound that stops a batch from back-dating `firstBlockTimestamp` to dodge requests that became eligible in the meantime … is UNMEASURED"*.

**Preconditions.** A quorum (or the proposer for a batch that validators accept) labels the batch's first block with a timestamp up to `FORCED_INCLUSION_MAX_DRIFT` in the past. Because the L1 check is one-sided in exactly this direction, the batch is *not* rejected for back-dating; it is accepted with a due set that excludes requests made eligible during the skew.

**Concrete trace.** (1) A request becomes eligible at L1 time `T`. (2) The proposer builds the next batch with `firstBlockTimestamp = T − δ`, `δ ≤ FORCED_INCLUSION_MAX_DRIFT`, and omits the request. (3) L1 computes `due` without the request (its `eligibleAtL1Timestamp = T > T − δ`) and `setEquals(coveredIds, due)` passes. (4) The proof binds the header timestamp (PRF-06) so this is not a prover choice, but it is a proposer choice for the whole quorum's view. (5) Repeat: every batch is back-dated by δ, so requests younger than δ relative to the chain's own clock are permanently excluded, and the drift parameter (a *liveness* parameter, per FI-02) has silently become the censorship bound.

**Inside / outside the claimed fault model.** Inside for a sub-threshold cartel that can get its proposals accepted (its blocks remain execution-valid; honest validators reject only if *they* consider the request due under the parent's own timestamp, which the skew also moves). The proposal's timestamp skew is bounded but not otherwise checked against wall-clock time — GEN-06 permits wall clocks only to pace signing, so no rule forces a validator to reject a 10-minute-old timestamp.

**Attacker resources and cost.** Control of proposal content, no extra stake beyond what is already needed to finalize a block; cost is zero beyond the drift parameter's uncertainty.

**Harm.** R10 (forced inclusion becomes delayable by the length of an unmeasured drift parameter — the "liveness parameter" the spec says only needs a *measured clock skew* to close), R13.

**Evidence.** FI-02's exact text and code block; GEN-06 (no wall-clock rule for validation); FI-02's own acknowledgement that the parameter is unmeasured.

**Required rule.** State `FORCED_INCLUSION_MAX_DRIFT` explicitly as the maximum systematic omission window it creates, and either bound it tightly (≪ the inclusion delay) or require the batch's first-block timestamp to be at least as large as the parent's timestamp plus a floor and within a tight window of L1 time.

---

## R1-08 — Recovery (Mode B) is triggerable by single-batch throughput degradation because `T_STALL` is defined per-batch, not per-queue

**Severity: Medium** — Mode B is not selected, so this is not currently live; but the REC-03 blocker is attached to a trigger whose stated derivation fails in the exact regime (throughput ≈ capacity) the design expects, and REC-02 defines *qualification*, not *profitability*.

**Exact rule.** `REC-02`: *"Only one trigger: a settlement stall — no batch extending the current L1 checkpoint has been accepted for `T_STALL`, where `T_STALL` is derived as the D6 proof envelope plus witness generation, queueing, L1 inclusion and a margin … `T_STALL` must be strictly larger than the envelope so that a normal slow proof, or one prover failure inside the envelope, can never trigger recovery."*

**Preconditions.** The fleet runs near the LIVE-03(i)/(ii) boundary (the only economically rational steady state: "≥ the L2's sustained execution rate" with "≥ L/Δ proofs in flight"). Any sustained-throughput deficit ρ<1 makes the queue wait between consecutive accepted batches grow like the queue length, so the inter-acceptance gap exceeds any *fixed* `T_STALL` even though every batch meets A-DA-2 (a prover does complete it) and no proof exceeds any rule. HALT-03/LIM-01 explicitly state that proving latency has no bound and that a slow proof is not misconduct.

**Concrete trace.** (1) The fleet's proven rate is 0.95× the L2 rate (permitted: LIVE-03 says this is an "Open" measurement gate, and nothing in the specification requires the inequality to hold at runtime — only "before launch"). (2) The backlog grows without bound (LIVE-03's own conclusion). (3) The gap between accepted batches grows past `T_STALL` while every individual proof is inside any envelope one cares to name. (4) `T_STALL` elapses with no accepted batch extending the checkpoint → the single objective trigger is satisfied. (5) Anyone posts the recovery bond (REC-02 "who may invoke": *anyone, permissionlessly, by posting a bond*); during `T_RECOVERY_DELAY` the only cancellation is acceptance of a batch, which the shortfall makes systematically late. (6) Recovery restores the L1 checkpoint, discarding up to `D_MAX` blocks of honestly PoS-certified history — the D2-step-5 blocker (REC-03) realized not by an attacker engineering a stall, but by the trigger being defined on a quantity with no bound.

**Inside / outside the claimed fault model.** Inside: A-DA-2 holds ("at least one prover completes each batch"), the D6 envelope was never exceeded by any individual proof, and the shortfall is exactly the *unmeasured* condition LIVE-03 flags as unverifiable. The invoker is any user; no quorum, no stake, no outage.

**Attacker resources and cost.** The bond (value unspecified — REC-02 says "a bond" with no magnitude, unit or loss condition; REC-03 requires the analysis to quantify "the penalties the attempt incurs", and no such penalty is defined anywhere). Since REC-02 defines no penalty for a *failed* recovery, the expected cost is the bond's time-value plus the delay.

**Harm.** R5/D2 (a mechanism that can discard unsettled PoS-certified history is arithmetically reachable in nominal degraded operation), REC-03's stated blocker (the trigger is not shown to be expensive to satisfy), and it is the *only* concrete path in the specification to a history replacement.

**Evidence.** REC-02's trigger text; LIVE-03's "if any inequality fails the backlog grows without bound"; HALT-03's "D_MAX is a bound on commitment creation, not on proving latency"; LIM-01's performance row ("the proving envelope, the in-guest blob evaluation and the fleet sizing are all unmeasured"); PARAM-02's `T_STALL` row ("inactive").

**Required rule (if Mode B is ever selected).** Define the trigger on an observable that cannot be satisfied by an ordinary throughput shortfall (e.g. no accepted batch **and** the unsettled-depth cap bound for a full `RETRIEVABILITY_WINDOW/2`, with a published prover availability statistic), state the bond's magnitude and forfeiture conditions, and quantify the trigger cost before REC-03 can be closed.

---

## R1-09 — LIVE-01's liveness claim is a mean-rate claim masquerading as a per-batch deadline

**Severity: Medium** — the headline liveness statement is not derivable from its listed conditions, so a reviewer cannot check it and an implementer cannot size against it.

**Exact rule.** `10-assurance.html#LIVE-01`: *"If (L1) … (L4) at least one adequately-resourced prover completes each committed batch inside the envelope, or another prover does … then L2 produces a block every 2 seconds, blocks reach STATUS-04 within the round budget, and committed batches reach STATUS-06 within the proof-queue envelope."* `LIVE-03`: sustainability is the *rate* inequality plus Little's-law concurrency `L/Δ`; every input is unmeasured and the rule is tagged Open.

**Why the implication fails.** (L4)'s "inside the envelope" is stronger than A-DA-2, which PARAM-02/A-DA-2 define as *"at least one honest, adequately-resourced prover completes each committed batch's proof within the assumed envelope"* — an assumption about the *mean* case, while LIVE-03 sizes the fleet by a *rate* identity. A fleet satisfying LIVE-03(i)-(ii) exactly (the stated design target) has a queue at critical utilisation, where the probability that every one of the (up to `D_MAX/Δ`) in-flight proofs completes within the envelope tends to zero; by D6/HALT-03 the overrunning proofs are *not* misconduct and *not* an assumption failure. So the antecedent can hold and the consequent (STATUS-06 "within the proof-queue envelope") still fail, without any clause of LIVE-01 failing.

**Inside / outside the claimed fault model.** Inside: this is the ordinary queueing regime of a fleet sized to the stated inequality, with honest provers.

**Attacker resources and cost.** None needed; it is a sizing/probability statement, not an attack.

**Harm.** R6 (the liveness claim's exact boundary is misstated), R13 (implementers cannot tell whether to provision a mean rate or a tail), LIM-01's performance row is the only place the gap is disclosed, and it discloses "unmeasured", not "the claim form is wrong".

**Required rule.** State (L4) as a tail condition — e.g. "the `p`-quantile per-batch proof latency is below `T_PROOF_ENVELOPE` and the fleet's rate exceeds the L2 rate by margin m" — and state the resulting probability bound on STATUS-06 latency, or downgrade LIVE-01's conclusion to "eventually reaches STATUS-06 while the backlog cap is not binding".

---

## R1-10 — Forced-inclusion fee ledger: refund-then-cover path is undefined and breaks the L1-11 conservation identity

**Severity: Medium** — a concrete accounting ambiguity in a rule that pays out user funds; it is either a double-payment surface or an underflow that blocks acceptance (both in the forced-inclusion path, which is the censorship remedy).

**Exact rule.** `L1-11`: `forcedInclusion_after = forcedInclusion_before − sum of feeHeld[r] for r in coveredRequestIds`, with `require(forcedInclusion_after >= 0)` and `FeeAccountingUnderflow()`. `FI-03`(b): after `FORCED_INCLUSION_ESCAPE_THRESHOLD`, *"the requester becomes entitled to a refund of the fee it paid, claimable from the Inbox at any time thereafter, without removing the request or affecting its coverage obligation."*

**Missing rule.** Nothing states what `feeHeld[r]` becomes after a refund, nor how `land` accounts for a request whose fee was already refunded but which is still in the queue and still due. Two implementations are both consistent with the text: (a) the refund zeroes `feeHeld[r]` and the ledger no longer holds the fee → `land` subtracts 0, and the phrase *"// paid to feeRecipient"* is silently false for that request; or (b) the refund pays from the ledger but leaves the obligation → `land` subtracts the original `feeHeld[r]` and `forcedInclusion_after` underflows, reverting every `land` that covers a refunded request — i.e. `land` becomes impossible for exactly the over-due requests that FI-03 keeps queued forever, converting the escape hatch into a settlement halt.

**Concrete trace (b).** (1) Attacker posts one request whose fee is `F`. (2) It ages past `FORCED_INCLUSION_ESCAPE_THRESHOLD`; the attacker claims the refund and receives `F`. (3) The request remains in the queue and is due (FI-03(a)); the batch that lands it must cover it (FI-02 setEquals). (4) `land` runs the L1-11 identity, subtracting `F` that is no longer in the ledger; if the ledger has fewer than `F` ETH (likely, since it only holds unrefunded fees), `FeeAccountingUnderflow()` reverts. (5) Every future `land` covering that request reverts. Because the request is never removed, no batch can ever land: permanent halt. Under interpretation (a) the halt does not occur, but the payment to `feeRecipient` is silently skipped, which is a different (smaller) inconsistency with L1-11's stated identity.

**Inside / outside the claimed fault model.** Inside: single permissionless user, no stake.

**Attacker resources and cost.** One request's fee, fully refunded. Net cost ≈ time-value only.

**Harm.** R6/R10 (the forced-inclusion path can be turned into a settlement halt at zero net cost under one reading), R13 (the ledger rule is under-specified in a load-bearing way), and it interacts with R1-01/R1-06 (all three are about the same queue).

**Required rule.** State that a refund zeroes `feeHeld[r]` and that `land` pays only unrefunded fees, and state explicitly that a refunded-but-uncovered request still carries its coverage obligation with zero payout; or make the refund transfer the fee's claim to the protocol.

---

## R1-11 — Escape hatch availability and the halt state: FI-03's refunds may be unavailable exactly when the chain halts

**Severity: Medium** — the user-protection path is documented as *"claimable at any time thereafter"*, but the ledger it draws on is funded only by outstanding fees and it is drained by every `land` (L1-11), with no rule that a refund cannot fail; and the hatch does not restore inclusion, which the user-facing description (ROLE-04(b)(i)) does not say.

**Exact rule.** `FI-03`(b): refund *"claimable from the Inbox at any time thereafter, without removing the request"*; `ROLE-04`(b)(i) presents the FI-01/FI-02/FI-03 chain as the user's inclusion right; `L1-11`: each covered request's fee is paid out to `feeRecipient` at acceptance.

**Missing rule.** No rule states that the refund cannot fail for lack of balance, that refunds have priority over the `land` payout, or what happens if the ledger is empty at claim time (the L1-11 identity requires `forcedInclusion_after ≥ 0`, which is a *payout* constraint, not a refund-reserve constraint). No rule states the disclosure that a refund terminates the *fee*, not the *duty*: the request remains queued forever (FI-03 a) and, if it exceeds the per-batch cap, is the R1-01 halt state.

**Concrete trace.** (1) Attacker fills the queue (R1-01) and waits for the escape threshold on many requests. (2) Meanwhile other requests are landed, draining the ledger to `feeRecipient`s. (3) The earliest requesters claim refunds; the ledger is insufficient; under the natural implementation the refund reverts or pays less. The specification gives no ordering rule, so each implementation invents one — the exact class R13 forbids. (4) Even if refunds succeed, the requesters' transactions are still never included (FI-03 explicitly refuses an L1 force-exit), so the "escape" restores fees only; ROLE-04's presentation of the hatch as the user's inclusion right is incomplete.

**Inside / outside the claimed fault model.** Inside: permissionless user actions only.

**Attacker resources and cost.** As R1-01.

**Harm.** R10/R6 and the user-facing disclosure obligations (ROLE-04(b)(iii), STATUS-11): a user who relies on the hatch is misled about what it delivers.

**Required rule.** Reserve refund balances (segregate ledger), state refund priority and the behaviour on insufficient balance, and require the disclosure that the hatch refunds fees but neither includes the transaction nor removes the coverage obligation.

---

## Cross-cutting note passed to the consensus reviewer (not counted above)

**The journal does not express a multi-epoch validator-set list.** `PRF-05` requires the guest to check *"each epoch's set commitment"* for *"every epoch boundary inside the batch"*, and `PRF-02`'s journal contains exactly one `epoch`/`validatorSetRoot`/`totalVotingPower`/`quorumThreshold` quadruple; `L1-05` row 9 defines `epoch` as the epoch of the *range ends*. With `EPOCH_LEN_L2 = 300` (PARAM) and batches up to `MAX_BATCH_BLOCKS` blocks, a batch crossing an epoch boundary (or several) has no normative encoding for the per-epoch set roots the guest must check, nor a bound on how many L1 roots the Inbox must read. As written, the guest cannot perform PRF-05(iii) from the journal, and the Inbox cannot know which epochs to expose. This is a consensus/proof-statement defect (I flag it rather than claim it) and it also has a DA-facing consequence: cross-epoch batches are the ones most likely to be the oldest unsettled, i.e. the ones whose retention matters.

---

# Required explicit answers

**Q-A1 — Is the Mode A availability counterexample (a finalized block whose data holders vanish, so no proof can ever be built) reachable INSIDE the stated liveness assumptions, or is it a failure OF those assumptions? Does the Mode A selection survive D2 step 1?**

It is a failure **of** the assumptions, not reachable inside them — with one important refinement. A-CONS-5 states that *correct validators* hold and can serve the data they voted for, for at least the retention window; since quorum is strictly >2/3 and Byzantine stake is <1/3, every quorum contains at least one correct validator, so as long as A-CONS-5 and A-CONS-2 (partial synchrony, post-GST timely delivery) hold, at least one reachable correct holder exists, and the vanishes-holders scenario requires either A-CONS-5 to fail (all holders faulty/offline/past the retention window) or delivery to that holder to fail beyond the synchrony assumption — both outside the stated liveness assumptions, in exactly the sense D2 step 1 anticipates. The refinement that must be stated honestly: A-CONS-5's retention is only *"for at least the retention window"*, so after that window the assumption expires and a permanent halt is **permitted by the assumption set**, not a violation of it; and my R1-03/R1-04 findings show that the retention window is neither observable nor derivable, so "inside" vs "outside" cannot currently be decided by arithmetic — that is a defect in the *bound*, not in the selection. On D2 step 1, the selection survives: the counterexample is a disclosed safe halt (LIM-01), D2 step 1 explicitly says a safe halt outside the stated liveness assumptions is permitted and is not evidence of infeasibility, and the recorded dissent in `DECISIONS.md` D-3 is correctly characterized as a liveness-assumption failure. My Critical/High findings above are not counterexamples to Mode A's *selection* — they are defects in the mechanisms the specification uses to claim that its liveness ends only where it says it ends.

**Q-A2 — Is the "one commit certificate per batch" argument (PRF-08) sound for the whole prefix, including across epoch boundaries?**

Within a single epoch, yes: PRF-08's premises (A-CONS-1, CONS-02 signing uniqueness, CONS-04 lock rule, L1-authenticated set) plus CONS-12's argument yield that finality at the head implies the ancestors, because each correct precommit validates the parent relation (CONS-01 iii) and a conflicting prefix would require ≥1/3 to violate lock/signing, which is slashable; the header-chain check (PRF-04 v) then ties the batch's blocks to the head. Across an epoch boundary it is **not** sound as stated, for two reasons. First, the boundary argument is CONS-09, which the specification itself labels ASSUMED-WITH-ARGUMENT/Open (F1), so the cross-epoch component inherits that status and cannot be quoted as proven. Second, and independently of F1, the *encoding* cannot express the argument: PRF-05 requires the guest to verify each boundary's set commitment, but PRF-02's journal carries a single `epoch`/`validatorSetRoot`/`totalVotingPower`/`quorumThreshold` quadruple (defined for the range ends in L1-05 row 9), so there is no journal slot and no stated count for the per-epoch roots a boundary-crossing batch must check, and no rule telling the Inbox which L1 roots to expose. A prover cannot therefore be forced to prove the boundary transition as specified; an implementation must invent the encoding, and a soundness-relevant difference between the Inbox's and the guest's reading is exactly the failure class PRF-03/PRF-13 exist to prevent. Verdict: sound for a within-epoch batch; unsound-as-specified across boundaries until the journal carries the per-epoch set data and CONS-09's F1 argument is closed.

**Q-A3 — Does the blob binding (DA-03: BLOBHASH equality, on-chain Fiat–Shamir challenge, on-chain KZG opening check, in-guest polynomial evaluation) resist a grinding prover and a malicious caller?**

Mostly yes for the stated threat, with two caveats that belong to the DA/liveness angle rather than to soundness. The binding is well constructed: the challenge `z_i` is derived by the contract from `statementCoreHash` (rows 1–17, i.e. all bound values except the challenges) with the domain tag, chain id and blob index, so the prover cannot choose `z` after fixing its data; the on-chain point-evaluation precompile at `0x0A` binds the *published* blob (via `kzg_to_versioned_hash`) to `(z, y)`, and the guest must show that the polynomial interpolating the elements it actually executed evaluates to the same `y` at the same `z`; `BLOBHASH` is transaction-scoped, so no other transaction's blobs can be substituted, and non-canonical field elements are rejected by the precompile and must be rejected by the guest (PRF-11). A grinding prover succeeds only with probability ≈ deg/|F| per attempt and needs the published KZG commitment to match the executed data, so the argument holds under A-CRYPTO-3 and the random-oracle model, as tagged. The caveats: (i) the Fiat–Shamir domain is `statementCoreHash` over rows 1–17, and the challenge is bound only if every *field* the guest relies on is inside those rows — the forced-inclusion commitment (R1-02) is outside the proof entirely, so the "all other journal fields" phrasing in `PRF-07`(b)(ii) and L1-05 row 18 must be reconciled with the actual 19-field journal, otherwise the two sides derive different `z` and no blob proof will ever verify (a liveness defect, not a soundness one); (ii) a *malicious caller* of `land` can always choose the calldata path instead, which is the specification's stated intent ("the calldata path remains unconditionally available"), so there is no way to force the blob path's probabilistic argument to be exercised; and (iii) the blob path's in-guest cost remains unmeasured (PARAM-02/F2), which is a feasibility gate, not a binding defect.
