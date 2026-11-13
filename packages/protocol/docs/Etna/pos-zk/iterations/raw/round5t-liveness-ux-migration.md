# Round 5 — liveness, user exposure, censorship, migration and cumulative consistency

**Snapshot:** `7759eb269` (branch `etna-pos-zk`, PR #22262) · **Angle:** liveness / user exposure /
censorship / migration / cumulative consistency · **Reviewer:** r5-liveness-ux-migration
**Targets:** `spec/10-assurance.html`, `spec/01-system-model.html`, `spec/08-migration-upgrades.html`,
`spec/index.html`, `spec/04-l1-integration.html` (FI-*, DA-*, L1-13, MSG-03), `spec/03` (MEM-15),
`spec/02` (CONS-01(v)), `learn/**`.
**Verdict:** 6 High, 4 Medium, 1 Low, **0 Critical**. Every High is reachable **inside** the claimed
fault model (no assumption failure and no cryptographic break is required). The single most serious
result is a cross-page contradiction about the *same* user-visible fact — whether value at or below the
last L1-accepted checkpoint can actually leave while the chain is halted — which four rounds of
amendments have left standing in three pages at once (F1/F2). The narrow forced-inclusion rule is
bounded in *work* but its *clock* is not bounded in L1 time (F3), and its *void* predicate is
controllable by the party it is meant to judge (F4). Migration is sound for the new state (publication
register, heartbeat, recovery) except for the settlement record that no slot owns (F8) and the
pre-migration withdrawal promise (F7). The learning course teaches the superseded withdrawal path with
zero mentions of the withdrawal root or the veto (F6).

---

## F1 — The exit guarantee is stated twice with opposite meanings: MEM-15/LIVE-01/LIVE-05 promise an
L1-only exit, while ROLE-04(f), MSG-03 and L1-13 say a release needs an epoch-boundary withdrawal root
and a halt delays exits indefinitely

**Severity:** High. One-line: two normative texts describe the same user outcome — a withdrawal while
L2 is halted — as "no L2 liveness, no new L2 block" and as "delayed, indefinitely", so at least one
normative rule is false and the load-bearing mitigation for the D-7 selection is misstated.

**Exact rules.**
- `spec/03-membership-staking.html:349` **MEM-15(1)–(3)**: the L1 authentication path "MUST remain
  executable on L1 with (i) no new L2 blocks, (ii) no L2 consensus participation, quorum or validator
  set, (iii) no cooperation from any validator, proposer, prover, relayer or operator"; "subject
  **only** to WITHDRAWAL_DELAY, measured from the checkpoint's `l1BlockNumber`"; "(3) The exit set keeps
  growing while production is halted … `land` is permissionless and **unconditional** … and requires
  **only** `firstBlockHeight == max(lastLandedHeight + 1, resumeHeight)`".
- `spec/10-assurance.html:121` **LIVE-01**: "Independent of every clause above … every L2→L1 message
  included at or below the latest L1-accepted checkpoint stays withdrawable on L1 with no new L2 block,
  no consensus participation, no quorum and no validator cooperation (MEM-15)"; `spec/10:259`
  **LIVE-05** repeats it in the halt table ("Yes: value at or below the last accepted checkpoint exits
  on L1 with no L2 block, no quorum and no validator").
- `spec/01-system-model.html:536` (line 580) **ROLE-04(f)**: "If the L2 halts, funds at or below the
  last accepted checkpoint are not lost **but exit is delayed while the chain is stopped**".
- `spec/04-l1-integration.html:809` **MSG-03**: "An L2→L1 withdrawal … MUST require a **withdrawal
  root** (L1-13) whose stateRoot covers the signal … plus the delay WITHDRAWAL_DELAY **measured from
  that root's `l1BlockNumber`** … an ordinary checkpoint that is not a withdrawal root MUST NOT anchor
  any value release"; and, as a MUST-disclose item, "a settlement halt delays withdrawals —
  **indefinitely** if no trigger fires and no recovery completes".
- `spec/04-l1-integration.html:438` **L1-13(1)–(2)**: "A withdrawal root is an **epoch-boundary
  checkpoint**"; "A checkpoint that is not a withdrawal root MUST NOT anchor any value release";
  `L1-13(5)`: "a signal above the last root waits for a later epoch boundary whose root is formed by k
  available families: at least one further epoch plus its proofs"; `spec/index.html:266`
  **STATUS-08** repeats "an epoch-boundary checkpoint carrying an aggregation proof that attests at
  least K_PROOF_BACKENDS distinct registered backend families".
- MEM-15's own evidence tag concedes the debt: "The reconciliation of MSG-03's 'a settlement halt
  delays withdrawals — indefinitely' sentence with this rule is owed by page 04." It is still owed.

**Assumptions.** Only A-L1-1 and the existing liveness assumptions. No cryptographic premise, no
Byzantine behaviour.

**Concrete attack trace (no adversary at all).**
1. Let `B` be the last epoch boundary at or below the latest L1-accepted checkpoint `C`, and let a user
   start a withdrawal whose signal lands at height `h` with `B < h ≤ C` (anywhere inside an epoch,
   i.e. up to `E_EPOCH = 1,800 s` of blocks).
2. L2 production halts (ordinary outage; also the case the D-7 selection exists for). `C` stops
   advancing; no new epoch boundary can be certified without new L2 blocks.
3. L1-13(1)/(2)/(5) and STATUS-08 admit no release: the only roots are epoch boundaries, the last root
   is `B < h`, and an ordinary checkpoint never anchors a value release — however many ordinary proofs
   it carries. MEM-15(1)(ii)-(iii) and LIVE-01's "no cooperation from any prover" are false for this
   message: the exit needs a *later epoch boundary* (new L2 blocks) plus a k-family aggregation proof.
4. If production never resumes, the wait is unbounded; if it resumes, the wait is ≥ one epoch plus the
   slowest of k inner proofs — exactly MSG-03's "indefinitely" and ROLE-04(f)'s "delayed", and exactly
   not MEM-15's "no new L2 block, no quorum and no validator".
5. An interface built to MEM-15/LIVE-01 tells the user the exit is available on the L1 clock alone. The
   user cannot act on it, and no rule compensates (ECON-11).

**Inside / outside the claimed fault model.** Inside. Step 2 is a stated liveness assumption failing
(A-CONS-5/A-DA-2), which the spec explicitly treats as a permitted safe halt and which is the exact
case MEM-15/LIVE-05 claim to cover with an unconditional L1 exit.

**Attacker resources and cost.** None. This is not an attack; it is the specification contradicting
itself and the disclosed bound being false in the users' disfavour.

**Requirement / fixed decision affected.** R5/R6 (the selected mode's confirmation and liveness
guarantee, "with exact end conditions"); R14 (learning site/specification consistency); LIM-01's claim
that the checkpoint-anchored exit is "the load-bearing mitigation for both residuals" of the F6 closure;
MSG-03(5)'s disclosure obligation.

**Evidence.** MEM-15 (spec/03:349 and its tag), LIVE-01 (spec/10:121), LIVE-05 row 1 (spec/10:259),
ROLE-04(f) (spec/01:536, line 580), MSG-03 (spec/04:809), L1-13(1)(2)(5) (spec/04:438), STATUS-08
(spec/index.html:266). Course agrees with the opposite side: `learn/08-when-things-go-wrong.html:321-322`
"Below the accepted checkpoint, funds are not lost; exit is delayed. A withdrawal needs the settlement
pipeline to resume."

---

## F2 — `attestWithdrawalRoot` has no stated epoch-boundary precondition: either L1-13(1)/STATUS-08 are
wrong, or the attach path cannot rescue a mid-epoch signal during a halt

**Severity:** High. One-line: L1-13(3)'s "Otherwise any account MAY call `attestWithdrawalRoot(height, …)`"
drops the epoch-boundary conjunct that L1-13(1) and STATUS-08 make definitional, so the one mechanism
that could make F1 harmless is left for an implementer to invent.

**Exact rules / missing rule.** `spec/04-l1-integration.html:438` **L1-13(3)**: "If that accepting proof
attests at least k distinct live families **and the height is an epoch boundary**, the checkpoint MUST be
marked a withdrawal root in the same transaction … **Otherwise** any account MAY call
`attestWithdrawalRoot(height, aggregationImageId, aggregationInput, proof)` … When the count holds, the
height MUST be marked a withdrawal root". The "otherwise" branch restates the count condition and never
restates the boundary condition. The missing rule is the boundary precondition on the attach path (or
its explicit absence, with L1-13(1) and STATUS-08 amended).

**Assumptions.** None beyond the stated set.

**Concrete attack trace / consequence.** Two readings, both defects:
(a) *Boundary-only (the L1-13(1)/STATUS-08 reading).* A mid-epoch signal above the last boundary is
unreleasable while production is halted, because no accept-height can be attested — this is F1's attack
trace, and it is not repairable by the user or by any prover.
(b) *Any-height (the literal L1-13(3) reading).* Then L1-13(1) ("A withdrawal root **is** an
epoch-boundary checkpoint"), STATUS-08 ("an epoch-boundary checkpoint carrying an aggregation proof")
and L1-13(5) ("a signal above the last root waits for a **later epoch boundary**") are all false, and
the exit-path liveness statement is wrong in the other direction, including its "unbounded if fewer
than k families operate" disclosure.
An implementer must choose; whichever choice it makes, one normative rule is violated, and the choice
decides whether a halted chain's settled value is escapable (R6, D-7's rationale).

**Inside / outside fault model.** Inside (specification defect; no adversary).

**Attacker resources and cost.** None. If reading (a) is correct, a censoring coalition pays nothing to
hold value by simply not producing the next epoch boundary.

**Affected.** R6; L1-13's own "exit-path liveness is weaker than settlement liveness, and is stated";
LIVE-01's unconditional clause; STATUS-08's definition.

**Evidence.** L1-13(1),(3),(5) (spec/04:438), STATUS-08 (spec/index.html:266), MEM-15(1) (spec/03:349),
MSG-03 (spec/04:809).

---

## F3 — The forced-inclusion clock is judged at the batch's anchored view `A`, and no rule requires
`A` to advance; the continuity rule spec/01 delegates to 04/05 does not exist

**Severity:** High. One-line: the due point of every published record is a function of a view `A` that
the protocol only requires to be Ethereum-final and monotone, never fresh, so a legally stale `A`
postpones the exclusion deadline indefinitely and the whole narrow rule never fires while the chain
settles normally.

**Exact rules / missing rule.**
- `spec/04-l1-integration.html:715` **FI-10**: "A record is *due* at L1 view `A` iff
  `record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A` … so the due set is a function of Ethereum-final L1
  state alone."
- `spec/04-l1-integration.html:717` **FI-11**: "recover the batch's anchored L1 view `A` from the
  anchor step it re-executes under SYS-02 … MUST reject a view that is not Ethereum-final at landing
  (`A ≤ block.number − L1_FINALITY_DEPTH`) or that is **older than the predecessor's recorded
  `anchoredL1Block`** (no stale-view escape)". This forbids `A` going *backwards*; it does not forbid
  `A` standing still, and it sets no upper bound on staleness.
- `spec/01-system-model.html:248` (SYS-02 §3.1 table): the baseline Anchor "validates a rolling
  255-block ancestor commitment and refuses arbitrary jumps" — and "**The replacement continuity rule
  for L2-side L1 observation belongs to 04/05; the anchor's rule is not inherited implicitly.**" Pages
  04 and 05 contain no such rule (grep: no "continuity", "freshness", "newest/latest Ethereum-final"
  obligation in either page).
- The only age-related rule, `L1_FACT_MAX_AGE` (`spec/01:176`, registered `spec/09-parameters.html:113`),
  is a parameter row with an explicit escape: a batch whose coordinates aged past the EVM's 256-block
  window "must either be **re-bound through an already-committed L1 hash chain** (L1-05, PRF-02) or
  rejected with an explicit error". Neither FI-10/FI-11 nor L1-05/PRF-02 state how that re-binding
  works, and the re-binding branch removes the only implicit freshness bound. The offence row
  `spec/07-economics-slashing.html` ECON-04(6) judges the breach at "the block's own anchored view A",
  so the same stale `A` also removes the *offence*.
- The missing rule: (i) which view is "the batch's `A`" when the batch's blocks carry different anchors;
  (ii) how stale `A` may be; (iii) the L2-side L1-observation continuity rule spec/01 says 04/05 own.

**Assumptions.** The adversary may choose a legal (monotone, Ethereum-final) anchor payload; a prover
chooses the batch range. If the batch's `A` is the head block's own per-block committed field
(PRF-04(vi) speaks of "the batch's anchored L1 view" in the singular, so this is a live reading), one
censor-controlled block per batch suffices. If `A` is monotone L2 state, the same failure appears
whenever the last published anchor is old and nothing requires the next proposer to refresh it — the
protocol has no such duty today.

**Concrete attack trace.**
1. At L1 block `T0` the L2 anchor state / head commit fixes `A = T0`.
2. At `T1 = T0 + FI_INCLUSION_DELAY + 1` a user publishes the data of a censored transaction (DA-07);
   the record's due point is `T1 + FI_INCLUSION_DELAY`.
3. A coalition that can place one block carrying the old anchor payload at the head of each batch (or
   that inherits a stale monotone anchor) lands batches whose `A` stays `T0` — legal under FI-11, since
   `A` is Ethereum-final and `A ≥` the predecessor's `A`.
4. `d(A) = 0` at every anchored view: the required prefix `[c, min(d(A), c + cap))` is empty, the guest
   check of PRF-04(vi) passes, the checkpoint advances, and CONS-01(v) never makes an omitting block
   invalid. The chain "otherwise runs" exactly as D-12's own claim requires it not to.
5. At `record.l1BlockNumber + T_PROVE_DEADLINE` the record is DISCARDED (DA-09(1)) and the user must
   re-publish into the same frozen view. The user's L1 cost is unbounded; the coalition's cost is
   ordinary block production.

**Inside / outside fault model.** Inside: no assumption fails (`A` is final and monotone) and no
cryptography breaks; the attack uses only behaviour the rules permit. The only out is a rule the
specification does not contain.

**Attacker resources and cost.** Far below one third of the stake for the head-field reading: a
cooperating prover plus periodic censor-produced blocks (proposer selection gives a <1/3 coalition
fewer than one third of slots in expectation — enough to place the blocks it needs, and it chooses the
batch end). For the monotone-state reading, the cost is the cost of not being the honest proposer who
refreshes the anchor, which is zero.

**Affected.** Fixed decision **D-12** ("the rule fixes a deadline by which forced data must be proven",
"a backlog drains … instead of halting the chain"); LIVE-04 ("from the record's due point a batch must
resolve it"); FI-10/FI-11/PRF-04(vi)/CONS-01(v)/ECON-04(6); R10 in its narrowed form.

**Evidence.** FI-10, FI-11, CONS-01(v) (spec/02:64-77), ECON-04(6) (spec/07), SYS-02 §3.1 row
(spec/01:248), L1_FACT_MAX_AGE (spec/01:176; spec/09:113), PRF-04(vi) (spec/05:327-341).

---

## F4 — FI-13's void predicate is steerable by the block producer, and its "member of the block's body"
wording is undefined about block space

**Severity:** High. One-line: a record is discharged as void when the guest finds its transaction "not
includable in any block of the batch", but includability is defined over pre-state conditions and a
per-block gas/base-fee environment that the proposer controls, so the party the rule is meant to judge
can make the published transaction un-includable — or the rule is undefined for a full block.

**Exact rule.** `spec/04-l1-integration.html:721` **FI-13**: "A record's transaction is *includable* in a
block `h` iff the L2 execution rules the guest already applies **admit it as a member of `h`'s body at
`h`'s pre-state**: the chain id matches, the sender's nonce at that pre-state equals the transaction's
nonce, **the sender's balance covers the maximum charge the transaction can impose at that block's base
fee**, and its gas limit fits the block's gas limit and does not exceed FI_RECORD_GAS_MAX, and the
record's published byte string does not exceed FI_ITEM_MAX_BYTES". "it is void *only* if the guest
determines from the batch's own execution that its transaction was not includable in any block of the
batch. No other ground discharges a record, at any layer". The rule's own failure mode: "a discharge
rule with any subjective or unbounded ground becomes a censorship instrument (a proposer voids what it
dislikes)". CONS-01(v) imports the same predicate as an excusal: "a record is not required if … it is
not includable in the block under FI-13's predicate".

**Assumptions.** The proposer builds the block; the guest only re-executes. No Byzantine majority is
needed — one proposer per block, and the *void* is decided over the whole batch, which the prover
chooses.

**Concrete attack trace (two readings, both bad).**
- *Fullness counts as "not admissible as a member of the body" (the natural reading of the preamble —
  a block's body is valid only if its gas usage ≤ its gas limit).* A censoring proposer fills every
  block of the batch to the gas limit with its own paying transactions. The published transaction is
  then not a member of any block's body ⇒ void ⇒ FI-13 "A voided record is settled: the frontier
  advances past it". The user's only stated remedy is re-publication (DA-09(2)), which the same censor
  voids again. Exclusion is unbounded, the chain keeps running and settling, and D-12's "upper bound on
  exclusion" is not delivered.
- *Fullness is excluded by the enumerated list (the list is exhaustive).* Then FI-13 does not say what
  happens to a required record that is includable but for which no block has room, and CONS-01(v)
  simultaneously excuses a block that omits it ("not includable in the block") and requires it ("MUST
  contain … the FIFO prefix"). The implementer invents the rule; FI-11's own test applies ("the two
  checks must agree, and a disagreement is a protocol defect").
- Independent of fullness, the predicate depends on the block's **base fee** and **gas limit**, both
  producer-influenced; a published transaction with an ordinary `maxFeePerGas` can be made objectively
  un-includable for a whole batch by fee/gas-limit movement, and F-FI-3 only discloses that "a record
  voided because it was not includable in this batch may become includable later" — it does not say the
  producer may lawfully cause the non-includability, and no rule obliges a proposer to leave room or
  bounds the environment it may set.

**Inside / outside fault model.** Inside. The proposer is acting inside its ordinary role; the only
"cost" is L2 gas it pays to itself through the fee-vault rule (and under CONS-01(viii) it cannot divert
those fees).

**Attacker resources and cost.** A censoring proposer (or a prover that selects the batch range) plus
enough L2 gas to fill blocks; no L1 capital, no stake majority, no cryptographic work. The user pays an
L1 blob publication per cycle.

**Affected.** D-12 ("upper bound on exclusion"); LIVE-04(1); FI-12's no-halt argument (a void that is
not objective is the poison-halt escape hatch); R10 narrowed form.

**Evidence.** FI-13 (spec/04:721), CONS-01(v) (spec/02:64-77), FI-11 last sentence (spec/04:717),
F-FI-3 in FI-13's tag, ECON-04(6) (spec/07).

---

## F5 — CONS-01(v) imposes the forced-data prefix **per block** at cap FI_MAX_PER_BATCH, while FI-12's
capacity relation and non-halt argument are **per batch**

**Severity:** High. One-line: the consensus-side rule and the proof-side rule disagree on the unit of
the obligation, and the registered relation permits a configuration in which a block is required to
carry more forced gas than a block can hold — the round-1 permanent-halt class in a new place.

**Exact rules.**
- `spec/02-consensus.html:64-77` **CONS-01(v)**: "Let P be the records of R(A) that are due at A and not
  yet settled … **The block MUST contain, among its executed transactions, the FIFO prefix of P up to
  FI_MAX_PER_BATCH records**, each at most once and in register order, except that a record is not
  required if its transaction already appears at a height above the last L1-accepted checkpoint in the
  block's ancestry, or if it is not includable in the block under FI-13's predicate. The block MUST NOT
  be required to include more than FI_MAX_PER_BATCH records."
- `spec/04-l1-integration.html:719` **FI-12**: `cap(batch) = min(FI_MAX_PER_BATCH, floor(batchGasCapacity /
  FI_RECORD_GAS_MAX))`, where `batchGasCapacity` is "the sum of the gas limits of the batch's own
  headers"; the registered relation is `FI_MAX_PER_BATCH × FI_RECORD_GAS_MAX ≤ MAX_BATCH_BLOCKS ×
  L2_BLOCK_GAS_LIMIT` (batch-level), and the non-halt argument concludes "the required records fit in its
  **blocks**".
- `spec/04-l1-integration.html:717` **FI-11**: "The same predicate is the per-block clause CONS-01(v) …
  the two checks must agree, and a disagreement is a protocol defect."

**Assumptions.** The relation is registered as stated and the gas-limit schedule produces
MAX_BATCH_BLOCKS blocks each with L2_BLOCK_GAS_LIMIT gas (FI-12's Open premise F-FI-1 holds). No
adversary.

**Concrete attack trace (configuration, no adversary).**
1. Choose FI_MAX_PER_BATCH = 10, FI_RECORD_GAS_MAX = 30M, MAX_BATCH_BLOCKS = 10, L2_BLOCK_GAS_LIMIT =
   30M. The registered relation holds with equality: 10 × 30M ≤ 10 × 30M.
2. A publication becomes due. The next batch's first block must contain the first min(d(A), 10) records
   (CONS-01(v)) — none of them is in its ancestry — i.e. up to 300M gas in a block whose limit is 30M.
3. No valid proposal exists; correct validators must vote NIL (CONS-01); no batch can be certified or
   landed; the guest check would also fail for any batch that omits them. Settlement halts permanently
   until the records expire (DA-09), which is the exact failure D-12 says must not return ("the failure
   mode that produced review round 1's critical finding … must not return"), now reproduced per block.
4. The alternative reading — "up to FI_MAX_PER_BATCH" as an upper bound rather than a requirement —
   makes CONS-01(v) vacuous and leaves the consensus-side check disagreeing with the guest check, which
   FI-11 declares a protocol defect.

**Inside / outside fault model.** Inside: a legal parameter registration plus a legal publication, no
adversary and no assumption failure.

**Attacker resources and cost.** None needed; a griefer needs one L1 publication if it can pick the
registration, and the halt occurs with honest participants.

**Affected.** Fixed decision **D-12** ("a backlog drains over successive batches instead of halting the
chain"); R6; FI-11's agreement requirement; FI-12's "cannot halt" claim; HALT-01/03.

**Evidence.** CONS-01(v) (spec/02:64-77), FI-12 (spec/04:719), FI-11 (spec/04:717), the FI capacity
relation row (spec/09).

---

## F6 — The learning course teaches the superseded withdrawal path and omits every disclosure MSG-03(5)
and MSG-04(5) make mandatory

**Severity:** High. One-line: `learn/**` describes a withdrawal as "checkpoint + message path + delay",
with zero mentions of the withdrawal root, the epoch-boundary requirement, the k-family dependency or
the veto, so a user sizing an exit on the course is told a path that cannot release their funds.

**Exact rules.** `spec/04-l1-integration.html:809` **MSG-03(5)**: "The design MUST disclose, wherever
withdrawal timing is described and without burying it, the two user-visible costs of the soundness fix:
(i) an exit is proven only against an epoch-boundary withdrawal root, which adds up to E_EPOCH plus the
slowest of k proofs while at least k backend families operate, and is **unbounded if they do not**
(L1-13(5)); and (ii) an unexpired veto (MSG-04) can add up to T_VETO". `MSG-04(5)`: "Every artifact
that describes withdrawal timing MUST state plainly that a verified proof contradiction can add up to
T_VETO to any pending withdrawal". `spec/index.html:146` **GEN-07**: status labels "are fixed by
STATUS-01–STATUS-11 … A document may not introduce a synonym for a status label or redefine a glossary
term locally." R14 requires the learning site to be consistent with the specification.

**Evidence (course side, all checked by grep over `learn/**`).**
- `learn/09-censorship-and-the-bridge.html:97`: "A withdrawal then needs WITHDRAWAL_DELAY measured from
  that **checkpoint's** l1BlockNumber, plus Ethereum finality …" — the spec measures it from the
  **root's** l1BlockNumber and requires the root (MSG-03).
- `learn/09:218`: "Check that WITHDRAWAL_DELAY has elapsed since the **checkpoint's** …".
- `learn/09:240`: "From there the value can leave once WITHDRAWAL_DELAY has …" — no root, no k families,
  no veto.
- `learn/07-timing.html:213`: the row for the normative label **STATUS-08** is "Checkpoint plus message
  path plus the delay" — a local redefinition of a status label, forbidden by GEN-07, and it drops the
  root and the "absence of an unexpired withdrawal veto".
- Counts over the whole course: `withdrawal root` 0, `veto` 0, `T_VETO` 0, `K_PROOF_BACKENDS` 0,
  `aggregation` 0, `families` 0, `contradiction` 0, `circuit` 0.

**Assumptions.** None. No adversary is required; the defect is a false user-facing statement.

**Concrete attack trace (user exposure).** A user holds value and plans an exit during a period when
fewer than k backend families operate (or a post-upgrade window in which an aggregation image is not
live — L1-09's Open inventory row). The course tells them the exit is available after
WITHDRAWAL_DELAY from their checkpoint; the specification's MSG-03/L1-13(5) says no root can form and
the wait is unbounded. Their funds are not lost but their exit plan is void, and the course never told
them the condition. The same user is not told that a verified proof contradiction can add T_VETO to a
proven withdrawal.

**Inside / outside fault model.** Inside (deliverable defect; user exposure).
**Attacker resources and cost.** None.
**Affected.** R14; MSG-03(5), MSG-04(5), STATUS-11, GEN-07.
**Evidence.** As listed above, plus `spec/04:809` (MSG-03(5)), MSG-04(5) (spec/04:817), L1-13(5)
(spec/04:438), STATUS-08 (spec/index.html:266).

---

## F7 — MIG-03(6) promises pre-migration withdrawal eligibility with "no delay extended", but the only
post-T3 release path is an *Etna* epoch-boundary withdrawal root

**Severity:** Medium. One-line: eligibility of a stored signal is preserved, but release is not: the
preserved legacy checkpoints and the T3 genesis checkpoint are ordinary checkpoints, and MSG-03/L1-13(2)
forbid an ordinary checkpoint from anchoring a value release, so a pre-migration eligible withdrawal
waits for the first Etna epoch boundary (or longer).

**Exact rules.** `spec/08-migration-upgrades.html:446` **MIG-03(6)**: "A withdrawal that was
withdrawal-eligible at the freeze remains eligible during and after the migration: eligibility depends
on a stored signal and a stored checkpoint, both preserved unchanged, and **no delay is extended,
restarted or re-based by any transition**"; the disposition table repeats "Withdrawal eligibility …
unchanged; nothing already eligible is delayed or restarted". Against that: MSG-03 (spec/04:809) and
L1-13(2) (spec/04:438) require a **withdrawal root at a height not below the signal's height**, and
L1-13(1) defines a root as an **epoch-boundary checkpoint** carrying a k-family aggregation proof.
`spec/08:370-396` writes the T3 genesis checkpoint but marks no height as a withdrawal root, and no
rule attests a legacy checkpoint as one.

**Assumptions.** Existing pending withdrawals at B* exist (the D3 surfaces are preserved with live
message state; MIG-03(5)-(6) exist precisely because they do).

**Concrete attack trace (no adversary).**
1. At the freeze, user U's withdrawal is eligible against checkpoint `B*` (signal at height ≤ B*).
2. T3 activates Etna with genesis checkpoint `(B*, H*, S*)`; it is not a withdrawal root, and the
   legacy checkpoints are not roots either.
3. Under MSG-03/L1-13(2), no value may leave until an Etna epoch-boundary root at height ≥ U's signal
   height exists — i.e. until the Etna chain produces to the end of epoch 0 and settles it, plus one
   k-family aggregation proof.
4. That is a delay introduced by the transition, contradicting MIG-03(6) and the disposition row; if
   fewer than k families operate, L1-13(5) makes it unbounded.

**Inside / outside fault model.** Inside (plain migration state, no adversary).
**Attacker resources and cost.** None.
**Affected.** R3 (migration), MIG-01/MIG-03(6), R6, STATUS-08.
**Evidence.** MIG-03(6) and disposition table (spec/08:446, lines 509-527), genesis record (spec/08:370-
396), MSG-03 (spec/04:809), L1-13(1)-(2) (spec/04:438), STATUS-08 (spec/index.html:266).

---

## F8 — FI-10's per-height settlement record is state no slot owns and MIG-02's "complete change list"
does not contain

**Severity:** Medium. One-line: `(settledCount, anchoredL1Block)` is required per accepted height by
FI-10, is absent from L1-07's frozen eight-field record and from MIG-02's enumeration, so the migration
budget's completeness claim and its 20-of-43 arithmetic are false for a rule the implementer must obey.

**Exact rules.** `spec/04-l1-integration.html:715` **FI-10**: "The Inbox MUST keep, **per accepted
height**, a settlement record `(settledCount, anchoredL1Block)` written atomically by that height's
accepting `land(data, proof)`"; L1-05 row 36 reads `settledFrontier` "from the predecessor
checkpoint's **own settlement record**". `spec/04-l1-integration.html:233` **L1-07** fixes the record's
fields as exactly eight (`height, blockHash, stateRoot, epoch, setRoot, dataCommitment, l1BlockNumber,
lastAcceptedBatchTime`) — no settlement record. `spec/08-migration-upgrades.html:223` **MIG-02**
enumerates the Inbox's 20 declaration slots (258-277) and claims on line 236: "**The complete change list
is the table below; any change not in it requires a new decision recorded in the decision log**", with
slot 264 described as "the eight L1-07 fields". No row holds a per-height settlement record, and L1-13(3)'s
per-height side mapping fields (`daMode`, `dataBindingSource`, `publicationId`, `familyCount`) are also
not in slot 265's description beyond `routeVersion`.

**Assumptions.** MIG-02's completeness claim is normative (it is stated as a MUST-shaped constraint on
implementers and reviewers).

**Concrete attack trace.** An implementer follows FI-10 and adds a new per-height map; it has violated
MIG-02's "any change not in it requires a new decision" and the layout-diff obligation it imposes,
while the reviewer who trusts the budget finds a required object unbudgeted. The converse (packing the
settlement record into the frozen L1-07 record under a new field) is forbidden by L1-07's exact field
list and MSG-01's frozen three-field SignalService reconciliation. Twenty-three gap slots remain, so
this is a specification/accounting defect, not an immediate collision.

**Inside / outside fault model.** Inside (specification defect).
**Attacker resources and cost.** None.
**Affected.** MIG-02's completeness claim; R3; FI-10/FI-11 (settled frontier); PARAM/reviewer trust in
the slot budget.
**Evidence.** FI-10, L1-05 row 36, L1-07 (spec/04:715, 233), MIG-02 (spec/08:223, line 236), L1-13(3)
(spec/04:438).

---

## F9 — STATUS-11 cannot tell a user what happened to a published forced record: include and void are
indistinguishable on L1, and DA-09's status model can label a resolved record DISCARDED

**Severity:** Medium. One-line: the disclosure rule that is supposed to make provisional/pending
state observable exposes only a frontier count, so no interface can tell a user "your published
transaction was discharged as void — re-publish", and a record whose transaction *was* executed by
another batch never becomes PROVEN and will be marked DISCARDED.

**Exact rules.** `spec/index.html:299` **STATUS-11** requires public facts (i)-(v): checkpoint,
`resumeHeight`, pending recovery, backpressure halt, withdrawal root and veto. It requires no fact
about a publication record's resolution. `spec/04-l1-integration.html:695` **DA-09(1)**: a record is
"PUBLISHED when written, **PROVEN when a batch referencing it is accepted**, and DISCARDED at
`deadlineBlock` if it is still PUBLISHED". FI-11(5)/FI-10 record only `settledCount` — a count, not a
per-record include/void flag — and FI-13 states "A voided record is settled: the frontier advances past
it … the remedy is re-publication" without requiring any observable mark.

**Assumptions.** Users interact through an interface (ROLE-04(iii) and STATUS-11 exist for exactly
this).

**Concrete attack trace / failure.** A user publishes their transaction's data (the v1 censorship
remedy). A batch includes the transaction's bytes *as part of a different batch's payload* without
referencing that record, or discharges it as void. In both cases the frontier passes the record, no
per-record fact changes, the record is never PROVEN, and at its deadline it shows DISCARDED — the same
status a never-touched record shows. The interface cannot distinguish "your transaction is on L2" from
"your record was voided, re-publish", which is precisely the decision FI-13 hands to the user
("the user's own re-publication, permissionlessly, is the exit"). This is also the only remaining answer
if F4's void steering is exercised.

**Inside / outside fault model.** Inside (disclosure sufficiency; no adversary needed).
**Attacker resources and cost.** None.
**Affected.** STATUS-11 (its stated purpose: "so that … the replacement disclosure this rule requires
can be made truthfully"); R14; FI-13's remedy; ROLE-04(iii).
**Evidence.** STATUS-11 (spec/index.html:299), DA-09(1) (spec/04:695), FI-10/FI-11/FI-13 (spec/04:715-723).

---

## F10 — Stale old-model text survives in spec/03: MEM-05(5) still argues from the un-relaxed D5, and
the page still says no rule can invalidate a PoS-finalized block "in Mode A"

**Severity:** Medium. One-line: two normative-looking clauses on the membership page assume the
pre-D-11 single-transaction model and the pre-D-7 mode, and both are contradicted by the pages that own
those decisions.

**Exact rules.** `spec/03-membership-staking.html:290` **MEM-05(5)** ("Why not nominal proving
latency"): "**D5 lands a batch's data and its proof in one L1 transaction, so there is no data-first
window** in which a third party could inspect a published batch and object before settlement. Detection
therefore cannot rely on 'the data sat on L1 for N hours before the proof arrived' …". This is false
under **D-11** (GEN-02, spec/index.html:66 names D-11 as the recorded relaxation): data may be published
and recorded up to `T_PROVE_DEADLINE` before the proof, and D-11's whole stated purpose is to collapse
the withholding window by putting data on L1 first — i.e. there *is* a data-first window, bounded by
DA-09. The clause is the rationale for `D_WITHDRAW`'s formula, so a normative-looking derivation now
rests on a false premise about the protocol. `spec/03:30-33`: "**No rule on this page can invalidate a
PoS-finalized block in Mode A** (D2, REC-01) …". After D-7 the mode is Mode B and REC-02 does discard
PoS-finalized blocks above the last accepted checkpoint; the qualifier "on this page" is doing all the
work, and the phrase as written states a Mode A guarantee in a Mode B protocol, inviting the reader to
extend it.

**Assumptions.** None.
**Concrete attack trace / consequence.** A reader (or an implementer deriving the withdrawal delay)
takes "no data-first window" as a protocol property, concludes that evidence can never be inspected
before settlement, and does not account for the published-but-unproven interval that D-11 creates —
the interval in which MEM-15/LIVE-04's forced-inclusion anchor lives. Conservative for D_WITHDRAW's
length, wrong for everything built on the claim. The Mode A sentence is the same class of stale text
round 4 flagged; it was not swept.

**Inside / outside fault model.** Inside (documentation defect with a security-relevant premise).
**Attacker resources and cost.** None.
**Affected.** GEN-02/D-11/D-5; MEM-05's delay derivation; R14/R4 vocabulary; D-7 (Mode B).
**Evidence.** MEM-05(5) (spec/03:290), MEM-05(4) (spec/03:290), spec/03 lines 30-33 (spec/03:29-36),
D-11 (DECISIONS.md), spec/index.html:66 (D5 as relaxed).

---

## F11 — MEM-15 measures WITHDRAWAL_DELAY from the checkpoint, MSG-03/STATUS-08 from the root

**Severity:** Low. One-line: the same delay is anchored to two different L1 blocks, so any interface or
analysis that computes the exit time from MEM-15 is wrong by up to one epoch plus the proving pipeline
whenever the root is later than the signal's checkpoint.

**Exact rules.** MEM-15(1) (spec/03:349): "It is subject only to WITHDRAWAL_DELAY, **measured from the
checkpoint's `l1BlockNumber`** on the L1 clock (MSG-03)". MSG-03 (spec/04:809) and STATUS-08
(spec/index.html:266): the delay is "measured from **the root's** `l1BlockNumber`". L1-13(2) makes the
root height ≥ the signal height and often much later than the checkpoint that first covers the signal.
**Assumptions.** None. **Attack trace.** A withdrawal whose signal is admitted at checkpoint `h` but
first covered by a withdrawal root at height `h' > h`; the interface displays an unlock time based on
`h`, and the value does not move until `h' + WITHDRAWAL_DELAY`. No funds are lost; the disclosure is
late. **Inside/outside.** Inside. **Resources/cost.** None. **Affected.** STATUS-08/MSG-03, R14.
**Evidence.** MEM-15(1), MSG-03, STATUS-08.

---

## Checked and holds (not re-listed)

- **Forced data across a recovery.** FI-14(1)-(4) survives re-attack: the register is L1 state; REC-02
  restores the checkpoint and, with it, the frontier of the restored height; a record included only in a
  discarded batch is not settled and is required again; no recovery invocation, completion, cooldown or
  bond may create, discard, re-order or re-clock a record; retirement cannot be used to escape a pending
  forced inclusion. The only ways I could break it are F3 (never due) and F4 (void), which are upstream
  of the recovery interaction, not in it.
- **Publication register, heartbeat and recovery state in migration.** MIG-02 slots 275-277 hold the
  publication identity map, the order map and the packed clock; the register is initialised empty at T3
  so no publication can be retroactively in breach; the heartbeat key and `lastHeartbeatAt` live in the
  new staking contract, which MIG-02 explicitly places outside the preserved prefixes, so D-14 creates
  no migration gap; GOV-03(e) carries a pending recovery across an upgrade. I re-broke none of these.
- **D-14 / no-rule-removes-weight.** MEM-02(1)-(2), MEM-13(4)-(5), MEM-13(7)-F8 and LIM-01 agree that
  no rule scales, discounts or zeroes weight; `T_INACTIVE`, `D_LAPSE_MAX` and `lastObserved(v)` are
  tombstoned in spec/03 and spec/09 and size nothing. Consistent from the page to the register.
- **FI-12's drain argument for a backlog above the cap** (min(pending, cap), frontier advances by ≥1)
  holds in the per-batch unit; the round-1 "required set equals the whole due set" defect is not
  repeated. F5 is the per-block-unit residue, not a re-run of round 1's exact defect.
- **Rule bookkeeping.** 160 `div.rule` ids across `spec/*.html`, no duplicate id, and 160 index rows —
  the README/05-freeze count claim holds on this snapshot.

---

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 6 | F1 (exit contradiction), F2 (attach-path boundary), F3 (frozen anchored view), F4 (void steering), F5 (per-block vs per-batch cap), F6 (course omits root/veto) |
| Medium | 4 | F7 (MIG-03(6) withdrawal promise), F8 (unbudgeted settlement record), F9 (STATUS-11 can't show include/void), F10 (stale D5/Mode A text in spec/03) |
| Low | 1 | F11 (delay anchored to two blocks) |

Strongest attack: **F3** — keep the batch's anchored view `A` frozen (legal: Ethereum-final and
monotone is all FI-11 requires), and every published record's due point is postponed forever while the
chain settles normally; the exclusion the narrow rule claims to bound never begins, and the user pays
an L1 re-publication per `T_PROVE_DEADLINE`. It is inside the fault model and it breaks fixed decision
D-12's stated constraint.

All six Highs are inside the claimed fault model; no finding requires a failed cryptographic
assumption, a >1/3 Byzantine coalition, or an L1-censoring adversary.
