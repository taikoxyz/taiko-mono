# Round 2 — adversarial review: liveness, data availability, censorship, recovery, the 30-minute pipeline

**Reviewer.** Fresh independent adversarial reviewer, round 2, assigned angle: *liveness / DA /
censorship / recovery / 30-minute pipeline*.
**Snapshot.** Working tree at commit `5e4129913e2540ac42c5c8b5034b64cdc3a5c8f1`; material
`packages/protocol/docs/Etna/pos-zk/`.
**Method.** Read `README.md`, `01-requirements-and-threat-model.md`,
`04-architecture-decision.md`, `DECISIONS.md`, and the specification pages
`index.html` and `01`–`10`. Re-derived the amended forced-inclusion and backpressure rules
from their own text. Every italic *"(review round 1, finding X)"* was treated as a claim to be
falsified, not as evidence: for each I asked what new rule now exists and whether the original
attack (or a cheaper variant) still succeeds. Where a round-1 fix is not closed I give the new
trace, not the old one.

**Verdict in one line.** The amended rules close the round-1 queue-length denial of service and
the fee-ledger double-payment, and they present retention honestly as an assumption; but the
forced-inclusion duty is still not closed (unincludable and cancelled payloads, missing
discharge accounting, an implicit landing deadline), the amended unsettled-depth cap contradicts
the rule it was bolted onto, and the settlement pipeline is not shown to be able to keep up with
production. Several of these need no adversary at all.

---

## 0. Verification of the five amended forced-inclusion rules (brief, §"verify")

| # | Requested check | Verdict |
|---|-----------------|---------|
| 1 | Single dueness definition | **Not closed.** One predicate exists, but its *scope* is not single: FI-02(a) binds the batch's first block, CONS-01(v) binds every block at every height. Under the per-block scope the duty is unsatisfiable; under the batch scope it cannot be checked at proposal time (the partition is chosen later by the lander). See **R2-LIV-04**. |
| 2 | Capped FIFO prefix `DueCap(T)` | **Closed for queue length only.** An arbitrarily long queue can no longer invalidate every proposal and the scan is bounded (round-1 C R1-01's fix is real). It does **not** close one unincludable payload (**R2-LIV-01**) or the omission of `cancelled` from the predicate (**R2-LIV-02**). |
| 3 | Containment direction `DueCap_L1(T) ⊆ DueCap_L2(T)` | **Inverted.** The direction written as a "MUST" is the one that holds automatically (monotonicity of `consumed`/`cancelled`); the "converse holds automatically" claim is false — it is exactly the direction in which the layers can differ. Evidence in **R2-LIV-04**. |
| 4 | Two-sided timestamp bound | **Not closed.** The upper arm is an unstated *settlement deadline* of `FORCED_INCLUSION_MAX_DRIFT` after each block's production. It contradicts the D6 envelope and the stated derivation of `FORCED_INCLUSION_DELAY_SECONDS`; a normally-proven batch can become permanently unlandable. See **R2-LIV-03**. |
| 5 | Escrow solvency | **Closed.** `escrow ≥ Σ feeHeld[r]` is inductive: coverage and refund each debit exactly `feeHeld[r]` and zero it (refund) or mark it consumed (coverage); a refunded request can never be paid twice because coverage pays 0 and still consumes; a refund cannot fail for lack of balance. Residue, not a solvency defect: the retained `CANCELLATION_COST` stays in the escrow with no disposition rule (surplus only). |

**Retention as an assumption (brief, §"check whether retention is honestly presented as an
assumption rather than a duty").** Yes, it is now presented as an assumption in every place that
matters: `10:138 LIM-01` (*"Retention is a liveness assumption (A-CONS-5, A-DA-2), not an
enforceable protocol duty"*), `01:477 ROLE-03(b)`, `01:131 SYS-01(b)` and `09:109`
(`RETENTION_WINDOW` … *"a disclosed liveness assumption, not an enforced duty"*). The round-1
C R1-04 presentation defect is closed. `DA-06`'s first sentence still says *"the retention
duty MUST satisfy …"*, but the normative content is an inequality on parameters, so I do not
count it as a finding. **However**, making retention an assumption does not make the *derivation*
of `D_MAX` from it sound — see **R2-LIV-08**.

---

## 1. Findings

### R2-LIV-01 — A single unincludable forced-inclusion payload permanently stops production and settlement, at L1-gas cost
**Severity: Critical** — a permissionless actor with no stake, inside every stated assumption,
can put the chain into a permanent state in which no batch can ever be landed, and the amended
rules forbid every exit.

**Exact rule / missing rule.** `04:512 FI-01` (request format) admits arbitrary `_txData`
bounded only by `MAX_FORCED_INCLUSION_BYTES`; `04:533 FI-02(a)/(b)` makes the batch's first
block contain "as transactions" exactly `DueCap(T)`; `04:556 FI-03` forbids voiding a
request, and the escape hatch refunds the fee while leaving the request due forever;
`06:120 HALT-04` forbids a DAO rescue. **Missing rule:** `requestForcedInclusion` MUST
reject a payload that cannot be included in an L2 block (not decodable as a transaction, invalid
signature/nonce, gas limit above the L2 block gas limit, or a set of payloads whose combined
execution exceeds the first block's gas limit), or the duty MUST be satisfiable without executing
the literal payload. Neither exists.

**Assumptions / preconditions.** A-L1-1 (L1 inclusion liveness), ordinary operation, one
permissionless account with ETH for gas. No Byzantine stake, no consensus fault, nothing outside
the fault model.

**Attack trace.**
1. Attacker calls `requestForcedInclusion(_txData)` with `_txData` = a byte string that is not
   a valid RLP-encoded signed transaction (a single `0x00` byte is enough), or a well-formed
   transaction whose `gasLimit` exceeds the L2 block gas limit. Fee `F` is escrowed.
2. After `FORCED_INCLUSION_DELAY_SECONDS` the request is eligible. `Due(T) = {r : eligibleAt ≤ T
   && !consumed[r]}` contains it; it is at (or reaches) the head of the FIFO prefix
   `DueCap(T)` because preceding requests drain as they are covered.
3. From the first height `H` with timestamp `T_H ≥ eligibleAt`, CONS-01(v) makes every block at
   `H` (and, if the payload were merely already-included, every later block, see R2-LIV-04)
   invalid unless it contains the payload; the payload cannot be contained by any valid block.
   So production stops, and `land(data, proof)` fails `ForcedInclusionNotCovered`, so
   settlement stops at `lastLandedHeight`.
4. After `FORCED_INCLUSION_ESCAPE_THRESHOLD` the attacker claims the FI-03(b) refund; the
   request stays in the queue and stays due ("coverable by any future batch, forever"). Net cost:
   L1 gas and time.
5. The state is permanent: L1-04 forbids an admission rule that makes a range permanently
   unacceptable but the FI duty *is* such a rule here; REC-01/D2 forbid discarding the finalized
   history; L1-06 forbids rewriting the checkpoint; FI-03 forbids removing the request; HALT-04
   forbids a DAO rescue; DA-06/L1-04 forbid using any recovery path. The only exit is a rule
   change, which FI-03 itself forbids ("There MUST NOT exist an owner, DAO, operator, or recovery
   function that removes a request from the queue").

**Inside / outside the claimed fault model.** **Inside.** A single permissionless user, all
assumptions intact. This is a strictly cheaper variant of round-1 C R1-01: that finding needed
`MAX_FORCED_INCLUSIONS_PER_BATCH + 1` requests because the whole due set had to be covered; the
capped-prefix fix removed that, but one payload that cannot be a transaction is enough.

**Attacker resources and cost.** One L1 transaction, a refundable fee, plus gas for the refund.
No stake, no validator participation, no TAIKO.

**Harm and requirement.** R6 (liveness ends at a condition not in LIVE-01's list), R10 (forced
inclusion becomes the censorship instrument rather than the remedy), R13; D2/Mode A (the chain is
permanently unable to settle a legitimately finalized prefix, which is the one outcome Mode A
exists to prevent). `REC-03`'s Mode B blocker analysis must also treat this as a cheap stall
primitive, because Mode B's only trigger is a settlement stall.

**Evidence.** `04:512`–`04:592` (FI-01/02/03/05), `02:72` CONS-01(v), `06:120` HALT-04,
`09:124` PARAM-03 (no parameter bounds a payload's decodability or gas). The baseline
`LibForcedInclusion.sol:42-72` validates only the blob reference and the fee, not the payload —
so there is no inherited rule to fall back on either.

---

### R2-LIV-02 — The "single predicate" omits `cancelled`, so a cancelled request stays due
**Severity: High** — the exact predicate that the round-1 fix made normative is inconsistent
with the cancellation rule the same fix introduced; two conforming implementations compute
different due sets, and the cheap variant of R2-LIV-01 is a cancellation.

**Exact rule / missing rule.** `04:537`: `Due(T) = FIFO queue in request order: { r :
r.eligibleAtL1Timestamp <= T && !consumed[r] }`. `04:586 FI-05(a)`: a request may be cancelled
before eligibility, "marks the request cancelled". `04:549 FI-02(c)`: "a request consumed or
cancelled in that view is consumed or cancelled in L1's" — i.e. cancellation is meant to remove a
request from the due set. **Missing rule:** `!cancelled[r]` in the predicate (and in the
guest's recomputation), plus a statement of whether a cancelled payload's bytes remain stored and
whether its inclusion duty survives.

**Assumptions / preconditions.** Ordinary operation; one permissionless account; cancellation is
cheap by construction (`CANCELLATION_COST`).

**Attack trace / counterexample.** Implementer A reads `Due(T)` literally: cancelled requests
are still due once `eligibleAt` passes. Implementer B reads FI-02(c)/FI-05(a): cancellation
removes them. For the same signed block and the same L1 state, A rejects (payload omitted) and B
accepts; `land` (which uses the contract's own scan, i.e. one of the two) then either rejects a
legitimately finalized range or requires a payload the L2 rule did not require. The predicate is
supposed to be identical in the client, the guest and the contract (CONS-01(v), PRF-04(vi)) — so
the disagreement is not a local bug, it is a settlement split. If the literal reading is used and
the cancelled payload is unincludable, the attacker pays only `CANCELLATION_COST` + gas for the
permanent halt of R2-LIV-01, having *withdrawn* the request in the only way FI-05 allows.

**Inside / outside the claimed fault model.** Inside: a rule ambiguity exercised by honest
implementers, plus a permissionless user.

**Attacker resources and cost.** One request + cancellation (fee minus `CANCELLATION_COST`, if
the cancel path is used) or the full fee with a post-threshold refund.

**Harm and requirement.** R10, R13 (a load-bearing predicate left to the implementer), R6.

**Evidence.** `04:537` (predicate), `04:549` (containment sentence), `04:586` (cancellation),
`05:142 PRF-04(vi)` (guest recomputes the same predicate).

---

### R2-LIV-03 — The two-sided timestamp bound is an unstated landing deadline; a normal D6 proof can make a finalized range permanently unlandable
**Severity: Critical** — it breaks D6 ("30 minutes is normal"), L1-04 (no age condition may make
a range permanently unacceptable), R9 and Mode A, with no adversary and no assumption failure.

**Exact rule.** `04:533 FI-02(c)`: "T is sandwiched by L1's own clock (`T ≤ block.timestamp ≤
T + FORCED_INCLUSION_MAX_DRIFT`)"; the L1 backstop reverts `BatchTimestampDrift`
(`04:196 L1-08`). `FORCED_INCLUSION_MAX_DRIFT MUST be strictly smaller than
FORCED_INCLUSION_DELAY_SECONDS`, whose stated lower bound is `L1_FINALITY_DEPTH + MAX_BATCH_BLOCKS
× L2_BLOCK_INTERVAL + clock-skew/observation margin`. `T` is the proof-bound header timestamp of
the batch's first block (`04:118 L1-05` row 8), and `firstBlockHeight = lastLandedHeight + 1`
(`04:155 L1-06`), so `T` is fixed once the block exists.

**Assumptions / preconditions.** A-L1-1 and ordinary operation. The batch is proven inside the D6
envelope (up to 1,800 s) — explicitly *normal*, and `06:92 HALT-03` says such a proof "is not
misconduct and not grounds for any recovery action". Implementation of row 8 as written (T
proof-bound); if row 8 is *not* implemented, the same page's binding list is false (see
R2-LIV-05).

**Worked counterexample (spec's own parameters).** `09:96` proposes `BATCH_BLOCKS = 32` (64 s
= `MAX_BATCH_BLOCKS × L2_BLOCK_INTERVAL`); `09` gives `L1_FINALITY_DEPTH ≈ 2 epochs` (≈ 768 s).
So FI-02(c)'s lower bound on `FORCED_INCLUSION_DELAY_SECONDS` is ≈ 830 s + margin, and
`FORCED_INCLUSION_MAX_DRIFT` must be strictly smaller than that. But at `land` time the batch's
first block is at least the proving latency old (09 defines proving latency from the moment the
batch's blocks are final), i.e. up to 1,800 s per D6, plus witness generation, queueing and L1
inclusion. With `MAX_DRIFT < ~830 s`, step (6) of `land` sees `block.timestamp > T +
MAX_DRIFT` and reverts. `T` cannot change, the range cannot start later
(`firstBlockHeight = lastLandedHeight + 1`), and no function may move the checkpoint backwards
(L1-06). The range is permanently unacceptable — exactly the outcome `L1-04` forbids and the
outcome Mode A cannot repair. The spec never states the required inequality `MAX_DRIFT ≥
T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + queueing`, and `MAX_DRIFT` is not registered in
`09` at all (R2-LIV-13).

**Second horn.** If an implementer instead sets `MAX_DRIFT` large enough for a normal proof, then
`FORCED_INCLUSION_DELAY_SECONDS > MAX_DRIFT >` 30 min, and the "omission window" that the same
rule advertises as "a fraction of the eligibility delay" is most of the delay. The rule cannot
satisfy both its stated purpose and the D6 envelope.

**Deeper inconsistency.** The upper arm is a settlement deadline `MAX_DRIFT` after each block's
production. `HALT-03`/`DA-06` derive the *opposite* regime: the oldest unsettled block may be
`RETENTION_WINDOW − T_PROOF_MAX_PERMITTED − T_SETTLE_PIPELINE` old (days, if retention is
expressed as the blob window). The two amended rules bound the same quantity by orders of
magnitude apart and neither cites the other.

**Inside / outside the fault model.** Inside: a normally-proven batch, honest validators, an
adversary is not required.

**Attacker resources and cost.** None. Any user who submits a transaction on L2 at the wrong
moment (or simply a congested proving queue) can produce the state.

**Harm and requirement.** D6, R6/R9, D2/Mode A, L1-04; also R8 (the data was published — the
batch simply cannot be accepted).

**Evidence.** `04:533` (FI-02(a)/(c)), `04:155` L1-06, `04:118` L1-05 rows 7–8,
`04:99` L1-04, `06:92` HALT-03, `09:96` (K = 32), `09:130` (T_PROOF_ENVELOPE = 1,800 s).

---

### R2-LIV-04 — Forced-inclusion consumption is not closed: the duty is unsatisfiable per block and unenforceable per batch
**Severity: Critical** — no attacker and no assumption failure; either reading of the amended rule
breaks production or settlement.

**Exact rules.** `02:72 CONS-01(v)`: "A proposal at height H and round R … (v) The forced
inclusions required at this height are included … Let `DueCap(H)` be the first
`min(|Due(H)|, MAX_FORCED_INCLUSIONS_PER_BATCH)` entries … The block MUST contain every element
of `DueCap(H)` exactly once". `04:533 FI-02(a)`: "A proposal is invalid unless **its first
block** includes … exactly the capped FIFO prefix `DueCap(T)`, where `T` is **the batch's**
first-block timestamp". `05:142 PRF-04(vi)`: the guest checks that **the batch's first block**
contains exactly those requests. Consumption exists only in L1: `04:321 L1-11` marks consumed
exactly the covered ids of a landed batch; `04:537` defines `consumed` as an L1 fact.

**Trace A — per-block scope (CONS-01(v) read literally).**
1. Request `r` becomes eligible at `τ`. Let `H0` be the first height with `T_H0 ≥ τ`;
   CONS-01(v) requires block `H0` to contain `r`'s payload. It does.
2. `consumed[r]` is still false (no land has covered `r`; lands lag production by the proof
   pipeline). At `H0+1`, `r ∈ DueCap(H0+1)`, so the block must contain the same payload
   **again**. A transaction whose nonce is already used is invalid; a block containing it is
   invalid. There is no valid block at `H0+1`, so no valid chain, so nothing to prove or land.
3. The only consistent discharge rule is "a request is discharged once its payload appears at or
   below the parent" — a *second* consumption rule, which FI-02(c) explicitly forbids ("one
   predicate, one clock … no proof-supplied dueness flag") and which the guest cannot implement
   from the journal, because the journal binds only the covered id list (see R2-LIV-06).

**Trace B — batch scope (FI-02(a) read literally).** Then the duty is checked only when a batch
is landed, and the batch partition is chosen *after* the blocks are finalized: the next batch's
first block is `lastLandedHeight+1`, but whether a later block is a "first block" depends on the
`lastBlockHeight` the submitter picks at land time (`04:196 L1-08` `LandInput.lastBlockHeight`
is claimed). A validator at height `H` therefore cannot know whether `H` is a batch's first
block, so the §"Why a sub-threshold cartel cannot starve inclusion" argument in
`04:594-604` — "an honest proposer MUST include the due set or its proposal is invalid, and
honest validators precommit only valid proposals" — has no checkable premise. The cartel can omit
requests freely; coverage then depends entirely on the L1 backstop, which is the "proposer
discretion" failure mode FI-02 exists to remove.

**Containment direction (brief item 3).** FI-02(c) states `DueCap_L1(T) ⊆ DueCap_L2(T)` as a
"MUST" and says "the converse holds automatically because the L2 view is a historical prefix of
L1 state (a request consumed or cancelled in that view is consumed or cancelled in L1's)". That
parenthetical proves the *first* direction, not the converse: `consumed`/`cancelled` are
monotone, so a request consumed in the older (L2) view is consumed in the newer (L1) view, giving
`Due_L1 ⊆ Due_L2` automatically; the converse fails exactly when a request was consumed in L1
after the L2 view was taken — the normal case, because lands lag production. So "the two sets
MUST in fact coincide" is not established, and `setEquals` is precisely what the two layers
cannot guarantee without the missing discharge rule.

**Inside / outside the fault model.** Inside. Trace A needs two consecutive blocks and a request
that becomes eligible between their timestamps (the normal case, since proofs lag by many block
intervals); trace B needs only the text.

**Attacker resources and cost.** Trace A: none. Trace B: a sub-threshold cartel may omit, but it
does not even have to — the rule has no enforcement point at proposal time.

**Harm and requirement.** R6, R10, R13; D1 (a 2 s cadence that the validity rule itself stops),
D5/D2.

**Evidence.** `02:72`, `04:533`–`04:551`, `05:142 PRF-04(vi)`, `04:321 L1-11`,
`04:196` (L1-08 `lastBlockHeight` claimed), `04:594`–`604`.

---

### R2-LIV-05 — The two binding lists disagree; one reading binds the predecessor's L1 block number and destroys all proof pipelining
**Severity: High** (Critical under the L1-05 reading) — both lists are normative and claim
exhaustiveness; the pair is unsatisfiable as written, and the two possible realisations give
opposite pipeline properties.

**Exact rules.** `04:118 L1-05`: "The statement the proof is checked against MUST bind **every
value in the table below**" — row 2 is `previousCheckpointHash = keccak256(keccak over the
stored record at lastLandedHeight (L1-07))`, and `04:173 L1-07`'s record hash includes
`l1BlockNumber` ("L1 block that accepted it"). `05:52 PRF-02`: "The guest commits to **exactly
the following journal**" — it contains `prevHeight`, `prevBlockHash`, `prevStateRoot` but **no**
`previousCheckpointHash`, and it also omits L1-05 rows 8 (first/last block timestamp), 15
(`finalityCommitment`), 17 (`daMode`) and 21 (`feeRecipient`), while containing
`configHash`, which L1-05 does not list. The L1-05 list governs what the contract hashes into
`statementHash`; the journal governs what the guest commits to; `05:304 PRF-09` requires both
backends to implement "the same statement".

**Consequence (i) — if L1-05 row 2 governs.** A proof for batch `k+1` binds the predecessor
checkpoint record, which includes the L1 block number in which batch `k`'s `land` transaction
was included. That number cannot be known before batch `k` lands; a prover that guesses it
produces a proof against the wrong `statementHash`. Therefore no proof for batch `k+1` can be
computed until batch `k` is accepted: proof concurrency is 1, not `L/Δ`. With K = 32 blocks
(64 s) and a normal proof latency of up to 1,800 s, settlement advances 32 blocks per proof
latency while production advances 32 blocks per 64 s — roughly 28× slower. The backlog grows
monotonically to `D_MAX` and, per R2-LIV-09, never drains. `10:119 LIVE-03(ii)`
("the number of proofs in flight is at least `L / Δ`") and `09:89` ("Proofs in flight at the
envelope limit … ≈ 28.1") are unachievable. The maximum possible batch span is an epoch
(`05:189 PRF-05`: no batch may span an epoch boundary; `09:120 EPOCH_LEN_L2 = 900`), giving at
most 32×28 = 900 blocks per 1,800 s = exactly production with zero slack for L1 inclusion — so no
parameter choice satisfies the inequality either. Under this reading the finding is Critical: R6
and D6 cannot hold for any parameterisation.

**Consequence (ii) — if PRF-02 governs.** L1-05 row 2 (and with it the amended round-1 claim that
the precedent is L1-derived and bound) is not implemented; `previousCheckpointHash` is computed
and then unused by the verifier; and the timestamps, `daMode` and `finalityCommitment` that
L1-05 says are bound are not. Also, `T` in FI-02(c) is then a claimed, unbound value while
CONS-01(v) uses the header timestamp, so the "one predicate, one clock" claim is false in a second
way (see R2-LIV-03 and R2-LIV-02).

**Inside / outside the fault model.** Inside: it is an internal contradiction, exercised by two
honest implementers (the two backends, or the contract team and the guest team).

**Attacker resources and cost.** None for the contradiction. Under consequence (i) no attacker is
needed for the throughput failure; a prover cartel can also exploit the serialization by holding
one proof, which the specification explicitly permits ("a normal proof taking up to 30 minutes is
not misconduct").

**Harm and requirement.** R13, R7 (both backends realise the same statement), R6, D6; and, under
(i), R9/D2 because settlement can never catch up.

**Evidence.** `04:118` L1-05 (rows 2, 8, 15, 17, 21 and the sentence "MUST bind every value in
the table below"), `04:173` L1-07 (record hash with `l1BlockNumber`), `05:52` PRF-02,
`05:304` PRF-09, `09:89` (in-flight formula and 28.1), `05:189` PRF-05, `09:120`.

---

### R2-LIV-06 — The amended L1 backstop still cannot check the payloads it requires (round-1 C R1-02 is not closed)
**Severity: High** — the single mechanism FI-02 claims against a colluding quorum does not reach
the proof; the round-1 fix bound the ids and left the payloads out.

**Exact rules.** `04:118 L1-05` row 20: `forcedInclusionCommitment =
keccak256(abi.encode("TAIKO_ETNA_FI", chainId, requestIds[]))` — **ids only**.
`05:52 PRF-02`'s journal carries the same single field. `05:142 PRF-04(vi)` requires the guest
to recompute `DueCap(T)` "from the L1-stored queue (the queue head, the eligibility timestamps
and the consumed set are L1 state …)" and to require "that the batch's first block contains
exactly those requests". To check "contains request r" the guest needs `r`'s payload (or its
hash); the journal contains neither, and the guest cannot read L1 storage.

**Attack trace / counterexample.** A prover supplies the payload bytes out-of-band. If they are a
private witness, the guest cannot constrain them against L1 (it has no L1 view) — the check is
vacuous, and a colluding quorum can omit the real payloads, cover the ids, collect the fees, and
still produce a verifying proof. If they are public inputs supplied by the contract, they are not
in `statementHash` (L1-05 row 20 hashes ids only), so they are a submitter-supplied value
outside the statement — precisely the failure mode L1-05's own "Failure mode" paragraph forbids.
Round-1 C R1-02's required fix was "ordered ids **and the payload hashes**"
(`iterations/raw/round1-liveness-da-recovery-30min.md:74`); the amendment added only the ids.

**Inside / outside the fault model.** The attack needs a quorum that violates CONS-01(v), i.e.
outside A-CONS-1 — and is therefore not itself inside the fault model. The *finding* is inside:
the specification claims FI-02's L1 backstop as the enforcement, and that claim is false as
written (R13).

**Attacker resources and cost.** ≥2/3 of an epoch's voting power (outside A-CONS-1), or a prover
that fabricates the unbound payload inputs if the contract/guest split is read charitably.

**Harm and requirement.** R10 (the anti-censorship backstop), R8/R7 (the proof must bind what L1
claims it binds), R13.

**Evidence.** `04:118` row 20, `05:52` PRF-02, `05:142` PRF-04(vi),
`iterations/raw/round1-liveness-da-recovery-30min.md:74`.

---

### R2-LIV-07 — The amended cap contradicts the rule it was added to: L1-04/DA-06 forbid exactly the L1-06/HALT-03 check, and the "objectively detectable" claim still fails
**Severity: High** — two pairs of normative rules are mutually exclusive; an implementer must
break one, and the round-1 C R1-03/R1-05 closure depends on the pair that L1-04 forbids.

**Exact rules.** `04:99 L1-04`: "no deadline, timestamp, block-number or age condition that can
make a range permanently unacceptable" and "Backpressure on production — the consensus-enforced
unsettled-depth cap of HALT-03 and DA-06 — **MUST NOT be implemented as an admission condition
on `land(data, proof)`**". `04:497 DA-06`: "The cap is a rule on production; it MUST NOT be
applied to `land(data, proof)` (L1-04), because refusing an available, valid proof would strand
finalized history." `04:155 L1-06`: "`land(data, proof)` MUST also reject any batch whose
unsettled depth `lastBlockHeight − lastLandedHeight` exceeds `D_MAX`
(`UnsettledDepthExceeded()`)"; `06:92 HALT-03`: "`land` itself MUST reject any batch whose
depth … exceeds `D_MAX`". Both L1-04 and DA-06 carry no round-1 amendment; L1-06's check was
added by the round-1 fix. `04-architecture-decision.md:177-183` lists both
`L1-ADMIT-NO-EXPIRY` and `DA-BACKLOG-CAP` as Mode A's binding obligations.

**Second defect.** Even taking L1-06 as intended, it cannot deliver HALT-03's claim that "a
violation is objectively detectable from the accepted batch itself". The L1 check is on a
*submitted batch*, and any range can be split into sub-batches of depth ≤ `D_MAX`. A validator
(or a quorum with a lagging L1 view, see R2-LIV-10) that produces blocks past
`D_MAX − MARGIN_V` never has to submit an over-deep batch; the over-deep blocks are landed in
pieces. No L1 object — not the checkpoint record (`04:173`), not `BatchLanded` — records the
depth at which the blocks were finalized, and CONS-01's objective-offence list does not include
cap exceedance. The round-1 claim "the cap becomes objectively detectable from L1 state alone" is
therefore not established by the amendment.

**Inside / outside the fault model.** Inside for the contradiction (it is text). The detection
part is inside for the stale-view/client-bug case (a quorum whose L1 view lags by more than
`MARGIN_V`).

**Attacker resources and cost.** None; the contradiction is a specification defect. A stale L1
view requires no stake.

**Harm and requirement.** R13, R9 (refusing a valid proof for a finalized range is the stranding
L1-04 exists to prevent), R6.

**Evidence.** `04:99` L1-04, `04:155` L1-06, `04:497` DA-06, `06:92` HALT-03,
`04-architecture-decision.md:177-183`, `04:196` L1-08 (split batches are individually
acceptable).

---

### R2-LIV-08 — `D_MAX` and `MAX_UNSETTLED_AGE` are two caps, in two units, over two different windows, and one of the windows measures the wrong object
**Severity: High** — the amended `D_MAX` (the round-1 C R1-03/R1-05 fix) is derived from a
quantity that, under D5, does not bound the availability of unsettled data at all.

**Exact rules.** `06:92 HALT-03`: `D_MAX = floor((RETENTION_WINDOW − T_PROOF_MAX_PERMITTED −
T_SETTLE_PIPELINE) / L2_BLOCK_INTERVAL)` — `D_MAX` in **L2 blocks**, from `RETENTION_WINDOW` in
**seconds** (`09:109`). `04:497 DA-06` instead defines `unsettledAge` as the **L1-block**
distance and caps production at `MAX_UNSETTLED_AGE`, with `RETRIEVABILITY_WINDOW ≥
MAX_UNSETTLED_AGE + SETTLEMENT_PIPELINE + EVIDENCE_WINDOW` — a window in L1 blocks compared to
pipeline terms in seconds. `04:481 DA-05(a)` defines `RETRIEVABILITY_WINDOW` "in L1 block
numbers, not shorter than the blob-retention window" and (b) an archive duty over "the full
**accepting-transaction** calldata and full blob sidecars". No rule states the relation between
`D_MAX` and `MAX_UNSETTLED_AGE`, or between `RETENTION_WINDOW` and `RETRIEVABILITY_WINDOW`.

**Why the derivation does not bound what it claims.** Under D5 the data of an unsettled batch is
**not on L1 at all** — it is published only in the transaction that already carries the proof.
DA-05's window and archive requirement therefore govern *post-acceptance* artifacts (L1 blob
sidecars, EIP-4444 bodies, EIP-4844's 4096-epoch sidecar retention), which is not the object whose
loss would make an unsettled batch unprovable. The object that matters is the L2 data held by
validators/nodes (A-CONS-5, ROLE-03(b)), and its duration is an unmeasured assumption
(`09:124-137` "Retrievability duration of L2 data held by validators and nodes"). So `D_MAX` is
computed from a window whose stated justification is attached to a different object, and
`DA-06`'s claim that the cap keeps "the oldest unsettled batch" inside the retrievability window
is not supported by DA-05's definition. The amendment's phrase "a bounded, recoverable halt" is
therefore unproven: the bound is on an assumption with no measured value and no link to the L1
artifacts it cites.

**Inside / outside the fault model.** Inside: ordinary operation; no adversary.

**Attacker resources and cost.** None.

**Harm and requirement.** R8 (data availability), R9, R6, R13 (the contract's `D_MAX` is a
governance-set number that the specification does not derive), D5.

**Evidence.** `06:92`–`115` HALT-03, `04:481`–`508` DA-05/DA-06, `09:97`, `09:109`,
`09:111`, `09:124`–`137`, `10:119` LIVE-03(iii).

---

### R2-LIV-09 — LIVE-01's premises are satisfiable while the halt is permanent: no rule requires a drain margin
**Severity: High** — the liveness statement has no clause that fails in the state it describes as
recoverable.

**Exact rules.** `10:78 LIVE-01`: "(L4) for every committed batch, at least one
adequately-resourced prover completes its proof inside the envelope … then L2 produces a block
every 2 seconds, blocks reach STATUS-04 …, and committed batches reach STATUS-06 within the
proof-queue envelope." `10:119 LIVE-03`: "(i) rate: the fleet's sustained proven execution rate
is **at least** the L2's sustained execution rate; (ii) concurrency: the number of proofs in
flight is at least `L / Δ`". `06:92 HALT-03`: at the cap "production stops and the chain is in
the safe-halt state until provers catch up". `04:497 DA-06`: "The cap converts an unbounded,
unrecoverable failure into a bounded, recoverable halt."

**Worked counterexample.** Take the permitted parity state: proven rate = production rate, every
batch proven within the envelope (L4 holds per batch), and the cap binds for any transient reason.
From the `D_MAX` derivation, the oldest unsettled block has exactly `T_PROOF_MAX_PERMITTED +
T_SETTLE_PIPELINE` of retention left. Because lands are strictly sequential
(`firstBlockHeight = lastLandedHeight + 1`), the backlog can only be drained one batch at a time;
at parity a batch's proof consumes exactly the L2 time the batch covers, so the backlog never
shrinks — the "catch up" HALT-03 assumes never happens. If concurrency is 1 (R2-LIV-05), the
drain is ~28× slower than that and the failure happens immediately. The margin is zero throughout:
any proof slower than `T_PROOF_MAX_PERMITTED`, any queueing or L1-inclusion delay, consumes
retention that the derivation never reserved. L4 never fails — each batch is individually
provable — yet liveness is permanently lost. LIVE-01's own end-condition list ("(L4) fails →
settlement halts after the unsettled-depth cap binds") does not cover this: the cap bound, L4 did
not fail.

**Inside / outside the fault model.** Inside: honest provers, honest validators, no adversary.
Round-1 C R1-09 asked for per-batch wording; the amendment supplied it, but the converse gap — a
per-batch guarantee does not give a drain guarantee — was not addressed.

**Attacker resources and cost.** None.

**Harm and requirement.** R6 (its exact end conditions are wrong), R9, D6 (a design that cannot
absorb the normal envelope).

**Evidence.** `10:78` LIVE-01, `10:105` LIVE-02, `10:119` LIVE-03, `06:92` HALT-03,
`04:497` DA-06, `09:89` (in-flight 28.1), `04:155` L1-06 (sequential landing).

---

### R2-LIV-10 — HALT-03's mandatory finality margin is derived in the wrong direction
**Severity: Medium** — the amended rule states a rationale its own construction contradicts;
reviewers cannot check the parameter, though the parameter is conservative in the normal case.

**Exact rule.** `06:92 HALT-03`: "MARGIN_V is mandatory and is at least the number of L2 blocks
produced during one Ethereum finality depth, because a validator's view of the L1 checkpoint is
itself only usable at that depth (SYS-02); without the margin a validator can systematically
under-estimate depth and overshoot the cap."

**Why it is wrong.** SYS-02 (`01:177`) restricts a validator to Ethereum-final L1 facts, so the
checkpoint it uses is at most as new as the true one: `C_obs ≤ C_true`, hence estimated depth
`H − C_obs ≥ H − C_true`. A stale view therefore **over**-estimates depth and stops *earlier* —
it is conservative, and the margin makes it more so. Systematic *under*-estimation requires the
validator to consume a land that is not Ethereum-final (or that is later reorganised out), which
SYS-02/HALT-01(c) forbid and which no margin repairs (a reorg can remove arbitrarily many lands).
The quantity that bounds the error is not "L2 blocks produced during one finality depth" but the
checkpoint advance contained in the unobserved window — up to `MAX_BATCH_BLOCKS` per land, with
several lands possible in one finality window. The margin is therefore both mis-derived and, in
the compliant case, unnecessary; it cannot support the claim in R2-LIV-07 that production-side
violations are detectable.

**Inside / outside the fault model.** Inside (specification reasoning), with an
observed-stale-view implementation.

**Attacker resources and cost.** None.

**Harm and requirement.** R13 (parameter derivation must be checkable), R6 (the halt threshold is
unreviewable).

**Evidence.** `06:92`–`101`, `01:177` SYS-02, `04:155` L1-06, `09:110` MARGIN_V.

---

### R2-LIV-11 — HALT-02's restart rule is incoherent for the finalized-but-unavailable case
**Severity: Medium** — the rule is load-bearing for Mode A and reads as an authorisation to
resume below the finalized tip, which REC-01 forbids.

**Exact rule.** `06:72 HALT-02`: "After a halt, a correct participant resumes only from the
highest finalized block whose data and certificate it can independently reconstruct. It must
never adopt an alternative history at a height it has already finalized…" `06:28 REC-01` makes
any change at or below a STATUS-04 height the violation of Mode A's entire content; the scenario
table at `06:288` says unavailable data for a finalized block is "Safe halt, possibly permanent
unless a holder returns".

**Defect.** The two sentences are only consistent if "resumes from" means "re-syncs its view and
remains unable to advance". Nothing says that. Read as a resume rule it instructs a participant
whose highest reconstructable block is *below* its finalized tip to continue producing from
there — i.e. to re-finalize an alternative history at heights that already reached STATUS-04
(peers may hold the certificate and the quorum may still be online). The rule needs to state
explicitly that a participant whose reconstructable prefix ends below its finalized tip MUST NOT
propose, vote or sign at any height above it, MUST NOT build an alternative at any finalized
height, and that the only recovery is obtaining the missing data.

**Inside / outside the fault model.** Inside: an implementation reading, exercised by any data
outage.

**Attacker resources and cost.** None.

**Harm and requirement.** R5, Mode A/D2, R13.

**Evidence.** `06:72` HALT-02, `06:28` REC-01, `06:288` scenario table, `10:78` LIVE-01 L3.

---

### R2-LIV-12 — Mode B cannot be implemented against the unconditional rules it does not name
**Severity: Medium** — Mode B is not selected, so this is not live; but the stated purpose "Mode A
is not designed in a way that makes the fallback unimplementable" fails.

**Exact rules.** `06:230 REC-02`: "Recovery may only replace history strictly above the last
Ethereum-finalized L1 checkpoint… The new checkpoint after recovery is exactly that L1
checkpoint." `04:155 L1-06`: "No function **in any mode** — including an upgrade initialiser, a
**recovery path**, or a governance call — may decrease `lastLandedHeight`, replace or delete a
checkpoint record at a height ≤ the current one". `06:28 REC-01` forbids any function that
changes the canonical history at or below a STATUS-04 height. `REC-02` does not name either as
overridden, while claiming the fallback is "fully specified rather than sketched"; its own
"Obligations it must still satisfy" lists only D5.

**Counterexample.** A recovery that restores a checkpoint `c' < c` necessarily calls a function
whose effect is to decrease `lastLandedHeight` and to delete checkpoint records above `c'`.
L1-06 says such a function must not exist; REC-01 says no function may change history at or below
a STATUS-04 height, and Mode B's rollback boundary is far below the PoS-finalized tip. Therefore
selecting Mode B requires amending REC-01/L1-06 — a rule change that REC-02 does not disclose and
that D2's evidence procedure does not obviously authorise (D2 distinguishes selecting Mode B from
changing Mode A's rules). Additionally, REC-03's blocker analysis must include the FI-queue stall
primitive of R2-LIV-01/R2-LIV-04: "engineering a stall" is not merely an outage-amplification
question when the protocol itself gives a permissionless, zero-cost stall.

**Inside / outside the fault model.** Not applicable to live operation (Mode B unselected); the
defect is in the specification of the fallback.

**Attacker resources and cost.** n/a; if Mode B were selected on this text, the trigger is cheap
by construction.

**Harm and requirement.** R13, D2 (the authorised fallback is not actually specified), REC-03.

**Evidence.** `06:230`–`267` REC-02, `04:155` L1-06, `06:28` REC-01, `06:254` REC-03.

---

### R2-LIV-13 — The parameters the amended rules depend on are not registered, and one is named twice
**Severity: High** — four normative rules say their parameter is "fixed in 09"; 09 contains none
of them, so the containment argument, the drift bound and the queue cap are sized by the
implementer (PARAM-01 violation, R13).

**Exact rules.** `04:512 FI-01`: "`FORCED_INCLUSION_DELAY_SECONDS` … its value is fixed in
09". `04:533 FI-02(c)`: "`FORCED_INCLUSION_MAX_DRIFT` … is a liveness parameter fixed in 09".
`04:579 FI-05`: "`BASE_FEE`, `FEE_DOUBLE_THRESHOLD` and `MAX_FEE` are set in 09".
`04:497 DA-06`: "(`RETRIEVABILITY_WINDOW`, `MAX_UNSETTLED_AGE` and the pipeline terms are
unmeasured parameters; all four are fixed in 09)". `04:685` repeats the list.
`09:15 PARAM-01`: "Every protocol parameter appears in the table below". `05:189 PRF-05`
bans batches spanning an epoch boundary; `09:120 EPOCH_LEN_L2 = 900`; `04:118 L1-05` row 7 and
`04:99 L1-04` use `MAX_BATCH_BLOCKS`, while `09:96` registers `BATCH_BLOCKS (K) = 32` and
nothing else.

**Counterexample.** A grep of `09-parameters.html` for `FORCED_INCLUSION_DELAY_SECONDS`,
`FORCED_INCLUSION_MAX_DRIFT`, `FORCED_INCLUSION_ESCAPE_THRESHOLD`, `MAX_FORCED_INCLUSION_BYTES`,
`MAX_FORCED_INCLUSIONS_PER_BATCH`, `CANCELLATION_COST`, `MAX_BATCH_BLOCKS`,
`MAX_UNSETTLED_AGE`, `RETRIEVABILITY_WINDOW` and `ARCHIVE_REQUIREMENT` returns zero matches.
The same identifiers appear only in `04` (and `MAX_FORCED_INCLUSIONS_PER_BATCH` once in
`02:72`). An implementer cannot evaluate FI-02(c)'s containment inequality, cannot size the
drift window (R2-LIV-03), and cannot set the contract's `D_MAX` threshold without inventing
values — the exact failure mode PARAM-01 exists to prevent. `MAX_BATCH_BLOCKS` (L1-04/L1-05/
FI-02) and `BATCH_BLOCKS (K)` (09) are either the same parameter under two names or two
parameters with no stated relation.

**Inside / outside the fault model.** Inside: a specification defect with a direct
security-relevant consequence.

**Attacker resources and cost.** None; the harm is that the parameters that decide whether the
chain can land anything are unset and unpublished.

**Harm and requirement.** R13, PARAM-01; R6/R10 through R2-LIV-03 and R2-LIV-04.

**Evidence.** `09:15` PARAM-01, `09:49`–`123` (parameter table contains none of the
identifiers), `04:512`, `04:533`, `04:579`, `04:497`, `04:685`, `09:96`.

---

### R2-LIV-14 — The assurance page's own ledger understates round 1
**Severity: Low** — a citation/consistency defect in the document that certifies the review
process.

**Exact rule.** `10:194 LIM-03`'s table records round 1 as "3 Critical, 22 High, 14 Medium, 5
Low (duplicates merged)" at snapshot `dfcf067…`, while `iterations/01-round.md:103` records the
adjudicated totals as "Critical 6, High 28, Medium 15, Low 6" after iteration 01b. `LIM-03`'s
own next row says round 2 must re-attack "the fixed rules"; a reader of the assurance page cannot
see the size of round 1.

**Inside / outside the fault model.** n/a.

**Attacker resources and cost.** n/a.

**Harm and requirement.** R13/reviewability; the round-2 row of LIM-03 is the record of this
review and should carry the corrected round-1 counts.

**Evidence.** `10:194`–`239` LIM-03, `iterations/01-round.md:98`–`128`.

---

## 2. Checked and closed (stated so the record is honest)

- **Round-1 C R1-01 (queue stuffing).** Closed for queue length: the capped FIFO prefix makes
  `DueCap` satisfiable with bounded cost and the `land` scan bounded by the cap. Not closed for
  a single bad payload (R2-LIV-01) or for cancellation (R2-LIV-02).
- **Round-1 B R1-07 / C R1-10 / C R1-11 (fee ledger).** Closed: the L1-11 escrow invariant is
  inductive, coverage and refund are mutually exclusive per request, coverage of a refunded
  request pays 0 and still consumes, and no refund path can fail for lack of balance. Residue:
  `CANCELLATION_COST` remains in the escrow with no disposition rule (surplus only).
- **Round-1 C R1-04 (retention presentation).** Closed: LIM-01, ROLE-03(b), SYS-01(b) and 09 all
  state retention is an assumption, not an enforceable duty.
- **Round-1 C R1-09 (mean-rate liveness).** Partially closed: L4 is now per-batch. The converse
  gap (a per-batch guarantee does not give a drain guarantee) is R2-LIV-09.
- **Round-1 C R1-02 (payload binding).** Not closed: R2-LIV-06.
- **Round-1 C R1-03/R1-05 (cap observability).** Partially closed and self-contradictory:
  R2-LIV-07, R2-LIV-10.
- **Round-1 C R1-08 (Mode B trigger).** Still an open blocker; the specification's own FI queue
  supplies a cheaper stall primitive than the throughput-degradation scenario the blocker
  discusses (R2-LIV-01, R2-LIV-12).
- **Whitelist/privilege claims.** INV-04 is marked *Open* and SYS-02(g)'s reserved L2 checkpoint
  writer is disclosed (`01:210`–`229`). R1 is therefore not satisfied in ordinary operation
  while that writer remains; because the specification says so itself, I do not count it as a new
  finding, but the README verdict line ("satisfies the hard requirements under the stated
  assumptions") overstates it relative to the Open/MIG items.

## 3. Counts

| Severity | Count | IDs |
|----------|-------|-----|
| Critical | 3 | R2-LIV-01, R2-LIV-03, R2-LIV-04 |
| High | 7 | R2-LIV-02, R2-LIV-05, R2-LIV-06, R2-LIV-07, R2-LIV-08, R2-LIV-09, R2-LIV-13 |
| Medium | 3 | R2-LIV-10, R2-LIV-11, R2-LIV-12 |
| Low | 1 | R2-LIV-14 |

**Inside the claimed fault model.** All three Criticals and all seven Highs are inside the stated
fault model (A-CONS-1/A-CONS-2/A-CONS-5/A-DA-2/A-L1-1/A-GOV-1 hold; no Byzantine stake and, for
R2-LIV-01/03/04/05/08/09/13, no adversary at all). The only finding whose *attack* requires
≥1/3 Byzantine stake is R2-LIV-06 (a quorum that violates CONS-01(v)); the finding itself — the
claim that FI-02's backstop is proof-enforced — is a specification defect regardless.

**Single strongest attack.** R2-LIV-01: one L1 transaction carrying a payload that cannot be a
transaction, refundable after the escape threshold, leaves the request due forever; the amended
rules (FI-03 no-void, HALT-04 no rescue, REC-01/L1-06 no rewrite, L1-04's failure to bar a range
made permanently unacceptable by the FI duty) leave no rule-legal exit. It needs no fault-model
violation, no stake and no coordination — and it shows that the round-1 "Fixed" disposition for
the forced-inclusion Critical is not closed.
