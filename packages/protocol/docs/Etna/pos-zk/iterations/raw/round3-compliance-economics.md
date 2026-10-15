# Round 3 — raw adversarial review: compliance with D1–D7 plus economics

**Reviewer angle:** compliance with the fixed decisions D1–D7 plus economics (D5 atomicity incl.
migration and recovery; D3 addresses / slot budget / field split; D7 TAIKO-only staking and the
amended reward design; R1/R2 ordinary-operation privilege; R10 in its D-6 relaxed form; internal
consistency of the economics amendments).

**Snapshot reviewed:** commit `3b0821f2fbbc21427ed2dee2575db4ad32deecc3`. The spec pages under
`spec/` were byte-identical across two independent extractions during this review (MD5 match), so all
rule quotations below are from the frozen content. One drift note: `README.md` has an **uncommitted
working-tree edit made at 17:38 during this review** (it replaces the stale "Open Critical defects"
paragraph with the post-D-6 disposition). Findings that concern README text are stated against the
frozen snapshot and against the working tree where they still hold.

Method: rules judged as written; in-text "(review round N, finding X)" italics treated as claims, not
evidence. Round-2 fixes were re-attacked where a fix was a wording/scoping change rather than a
mechanism; everything I could not re-break is listed in §"Checked and holds" instead of re-listed.

---

## Verdicts on the assigned questions

- **(a) D5.** *Within the Etna path:* no rule lets an accepted batch advance a checkpoint without its
  data and a valid proof in the same transaction. L1-01 (one atomic entry point, no propose-then-prove,
  no overload/fallback/multicall/recovery variant), L1-02 (no pending record of any kind, including
  from an upgrade initialiser), L1-03 (verify before any state write; no partial effect), L1-06
  (monotone succession, no path may write at `lastLandedHeight + 1` differently), DA-01–DA-04 (canonical
  data is the accepting transaction; the commitment is contract-computed or in-guest recompleted),
  REC-01(e), REC-02's D5 obligation and HALT-04 close it. *Outside the Etna path* two carve-outs exist:
  the T3 genesis record (a checkpoint write with no batch and a synthetic `dataCommitment`, which
  MIG-02's genesis section expressly forbids presenting as batch data) and the legacy Shasta wind-down,
  which is a live data-first path during FROZEN and is disclosed as "exactly the data-first flow D5
  forbids for this protocol". **Finding R3-CE-01** (Medium): the wind-down is bounded and disclosed, but
  the specification never says which rule set authenticates an L2→L1 value release in states 0–2, and
  the two candidate readings contradict each other. If the judge refuses the "the wind-down is a
  different protocol" scoping, the D5 text ("no data-first path, in any mode") is breached; I do not
  grade it Critical because the carve-out is bounded, disclosed, and cannot advance any *Etna*
  checkpoint — but the withdrawal question below is independent of that scoping judgment.
- **(b) D3.** Holds. MIG-02's Inbox budget is 10 of the 43 sourced gap slots (258–267), leaving
  268–300; SignalService, Bridge, all three vaults and the Anchor consume **0** new slots; the five
  shared surfaces (and the Inbox/Anchor whose immutables point at them) are upgraded in place by
  MIG-06 with the recorded proxy addresses, and the resolver→immutable change in MIG-04 is code, not
  storage. MSG-01's field split needs no frozen layout change: the preserved SignalService checkpoint
  keeps its three fields `{blockNumber, stateRoot, blockHash}` under the same VERSION key and slot
  derivation, and `epoch`, `setRoot`, `dataCommitment`, `l1BlockNumber` live in the Inbox's own
  L1-07 record keyed by the same L2 block number and written in the same `land` transaction.
- **(c) D7.** Holds. MEM-01/ECON-01(1) accept only the existing TAIKO ERC-20, exclude ETH and every
  wrapped/L2 form, and keep the legacy gwei bond ledger out of consensus; the reporter bounty is TAIKO
  paid from already-debited slashed collateral (ECON-06(1)); validator/prover rewards in ETH are
  conforming because D7 fixes the staking asset. No surviving *silent* appreciation assumption or
  unbounded subsidy was found: ECON-02(2) bans appreciation claims, ECON-10(5) bans hard-coded market
  data, ECON-12 values `R_reserve` at a dated price and makes `ρ_capital` price-dependent, ECON-02(4)
  bounds and expires the subsidy and nets it out as `D_subsidy`, and ECON-02(3) records that TAIKO has
  no mint path. The amended reward **mechanism**, however, is not internally consistent — findings
  R3-CE-02, R3-CE-03, R3-CE-04.
- **(d) R1/R2.** Ordinary operation needs no DAO transaction and no owner/whitelist/pause key
  (SYS-04, MIG-04, GOV-01). Residual privileges are listed honestly: (i) DAO upgrade authority
  (A-GOV-1, not a runtime dependency), and (ii) the L2-side checkpoint writer retained as a reserved
  system sender by SYS-02(g)/MIG-04, which SYS-04(a),(c) and SYS-02(g) state fails the non-operative
  test, so "R1/R2 are not yet satisfied" for that lever. **Finding R3-CE-06** (Medium): 01-system-model
  §3.1 still orders that this writer "must be repointed", while MIG-06 says the repoint is forbidden by
  the same-immutables rule and is not achieved by this migration — two normative-looking instructions
  in opposite directions.
- **(e) R10 relaxed (D-6).** The removal is stated consistently across all eleven spec pages, the
  index, the requirements matrix and the learn course (grep-verified: every surviving mention is the
  tombstone or the LIVE-04 statement; FI-01..FI-05, row 20, the censorship offence, the escrow and the
  domain tag are gone). Nothing claims a per-transaction guarantee, and the withdrawal-censorship
  consequence is disclosed in LIVE-04, FI-REMOVED-01, ROLE-04(b)(i), LIM-01, the 09 glossary, the 06
  walk-through and learn/11. **Finding R3-CE-05** (Medium): the honest statement's premise list is
  wrong — the caveat it names cannot hold under CONS-06(d).
- **(f) Economics amendments.** Minimum stake (ECON-09) is dimensionally closed, price-free and states
  the unfunded regime; the evidence window is anchored to a stored `t_root(e)` (E-R2-07), re-derived
  for the two-epoch lookahead with the `3·E_EPOCH` skew (R2A-01), carries the strict
  `W_EVIDENCE + T_PROCESS + CORR_DELAY + M_ev < D_WITHDRAW` inequality and the HALT-03 coupling clause
  (ECON-07(2),(7)); the churn cap is wired into the rule that owns exit effectiveness (MEM-05(2),
  ECON-03(6)); activation fairness is disclosed and rate-limited (MEM-03(2), ECON-09(5)). The reward
  side does not hold: findings R3-CE-02/03/04, plus the register drift in R3-CE-07/08.

---

## Findings

### R3-CE-01 — Migration states 0–2 do not say which rule authenticates an L2→L1 value release, and the two candidate readings conflict

**Severity: Medium.** One-line rationale: a security-relevant question (which checkpoint may release
bridge value during the migration window) is answered two contradictory ways, and the D5 text is
overridden by a scoping declaration rather than by an authorized exception.

**Exact rule / missing rule (file + rule id).** `spec/08-migration-upgrades.html` MIG-03(1) ("D5's
scope, stated honestly"; clauses (i)–(iv)) and MIG-03(6) ("Withdrawals"), and the T1–T3 transition
table; `spec/04-l1-integration.html` MSG-03, STATUS-06, L1-01; fixed decision D5 and
`01-requirements-and-threat-model.md` §1 ("Explicit non-relaxations (from the user): D5 may not be
relaxed to obtain earlier data publication"). Missing rule: no statement of which rule set is in force
in `SHASTA_ACTIVE`/`FROZEN`/`DRAINED` for checkpoint authentication of bridge releases.

**Assumptions and preconditions.** The migration reaches FROZEN (T1); a legacy `prove()` is submitted
before T2; a user holds a stored signal and a stored checkpoint.

**Concrete attack trace / worked counterexample.**
1. T1 (DAO bundle) installs the migration implementation, calls `freeze()`, and disables `propose()`;
   `prove()` "is unchanged but remains callable" in FROZEN.
2. Any account calls legacy `prove()` for a proposal whose data was published in an **earlier**
   `propose()` transaction. The preserved L1 SignalService checkpoint advances. MIG-03(1) concedes:
   "that is exactly the data-first flow D5 forbids for this protocol".
3. MSG-03 (normative Etna rule) says: "No value may leave the bridge surface on the strength of
   anything weaker than STATUS-06. An L2→L1 withdrawal or message authentication MUST require a
   checkpoint written by a successful `land(data, proof)` ...". STATUS-06 is "The Inbox accepted
   (data, proof) in one transaction and advanced its checkpoint". A legacy checkpoint is **not** that
   object, so on this reading no value may leave during 0–2 and MIG-03(6)'s promise that eligibility
   "remains eligible during and after the migration" is false for the window.
4. On the other reading (legacy rules govern until T3), value does leave against a checkpoint the Etna
   rule set defines as weaker — the exact class D5/DA-01 exists to prevent, on the preserved bridge
   surface (D3).

Nothing in the frozen text chooses between (3) and (4).

**Inside / outside the claimed fault model.** Inside; no adversary, no assumption failure. It is an
unresolved normative choice in ordinary migration operation.

**Attacker resources and cost.** One legacy `prove()` transaction (L1 gas) for step 2; step 4 needs a
user or relayer to submit an existing message proof. No stake, no corruption, no committee.

**Harm and the exact requirement / fixed decision affected.** R9/D5 ("no data-first path, in any
mode"); R3/D3 (the preserved Bridge authenticates against the affected checkpoints); R13 (an
implementer must invent which checkpoint type releases value). Bound acknowledged: `prove()` reverts
`MigrationDrained()` permanently from T2, T2 is permissionless once the drain completes or
`block.number >= frozenAtL1Block + DRAIN_DEADLINE` (21,600 L1 blocks), and T3 requires an
Ethereum-final boundary, so the window is finite and DAO-bounded.

**Evidence.** MIG-03(1) quoted above; MIG-03(1)(iv) ("the honest claim is therefore 'no exception
within the Etna protocol, and the legacy path is disabled at a named transition (T3)'"); MIG-03(6)
("eligibility depends on a stored signal and a stored checkpoint, both preserved unchanged"); MSG-03
and STATUS-06 as quoted; T2 row ("prove() reverts MigrationDrained() permanently"); T1 row ("propose()
reverts MigrationFrozen(); prove() is unchanged"). The T3 genesis record is a second checkpoint write
with no batch (MIG-02 "genesis checkpoint record", which forbids treating its `dataCommitment` as a
batch commitment); I checked it and it does **not** by itself breach D5 because it is the boundary, not
an accepted batch, and INV-02 is scoped to "every batch the Etna protocol accepts" — but it is a second
place where the D5 sentence "no data-first path in any mode" is true only under the spec's scoping.

---

### R3-CE-02 — The validator reward mechanism is stated twice, incompatibly: ROLE-01(d) pays in the acceptance transaction; ECON-02(5) pays by claim after the evidence window

**Severity: High.** One-line rationale: a claimed guarantee (how validators are paid) has two
normative statements that cannot both be implemented; the round-2 fix amended one and left the other.

**Exact rule / missing rule (file + rule id).** `spec/01-system-model.html` ROLE-01(d) versus
`spec/07-economics-slashing.html` ECON-02(5)(a)–(e) and `spec/04-l1-integration.html` L1-11 "Scope";
also L1-03 step (6).

**Assumptions and preconditions.** Any implementation that reads ROLE-01(d) as written; any landed
batch.

**Concrete attack trace / worked counterexample.**
- ROLE-01(d): "Rewards. Paid only from the L1-committed reward pool in the same L1 transaction that
  accepts a batch (L1-11), with the funding identity of ECON-02".
- L1-11 "Scope": "validator rewards are not a term of its conservation identity: validator payouts come
  from the segregated ETH reward pool of the L1 staking contract (ECON-02 clause 5), never from the
  Inbox's ledger"; L1-11's only payout is `rewardPaid = min(REWARD_QUOTE, proverReward_before +
  msg.value)` to `msg.sender`.
- ECON-02(5)(c): "Claims for epoch e open only after evidenceClose(e) (ECON-07), when the epoch's
  allocation is fixed; a claim before then reverts"; (d) pays pro rata over
  `P(e) = { v : participated[e][v] }`, which is not complete until the epoch's last batch is landed;
  (e) states that until the fee-transfer decision exists, `Alloc(e) = 0`, "the pool has no inflow, and
  no validator reward can be paid at all".
- An implementer following ROLE-01(d) must pay validators inside `land(data, proof)` at step (6), i.e.
  before `Alloc(e)` and `P(e)` exist. That either pays a fixed or guessed amount and breaks (d)'s
  "Σ_v payout(v,e) ≤ Alloc(e) ≤ pool_before(e)", or creates exactly the failure L1-11 names as (b): "a
  second payout path out of the reward ledger drains it".

**Inside / outside the claimed fault model.** Inside; no adversary needed.

**Attacker resources and cost.** None. Any prover/lander triggers the landing step; the defect is in
the rule text.

**Harm and the exact requirement / fixed decision affected.** R11 (objective rewards/penalties
accounting), R13 (the payment path is not implementable without choosing one rule), ECON-02's identity,
INV-04 (reward claiming as an ordinary operation). No direct loss of user funds, but the reward pool's
conservation identity is not derivable from the text.

**Evidence.** All quotations above; note that the round-2 finding E-R2-05 quoted ROLE-01(d) as part of
its evidence and the repair touched ECON-02(5)/L1-11 only, so the quoted defect survives in ROLE-01(d)
and its citation "(L1-11)" now points at a rule that excludes validator payouts.

---

### R3-CE-03 — Participation-conditioned rewards: the per-epoch participant set is not frozen when claims open, so the payout identity can be violated

**Severity: High.** One-line rationale: the per-epoch payout identity `Σ payout ≤ Alloc(e)` is not
enforceable as written because `P(e)` grows after claims open; a naive implementation over-pays early
claimants out of the pool, a strict one silently denies a participating validator.

**Exact rule / missing rule (file + rule id).** `spec/07-economics-slashing.html` ECON-02(5)(b),(c),(d);
`spec/04-l1-integration.html` L1-04 and L1-06 (no landing expiry, no depth rejection); missing rule:
the cutoff at which `participated[e][·]` is final for payout purposes.

**Assumptions and preconditions.** `Alloc(e)` is fixed at `evidenceClose(e)`; `land(data, proof)`
writes `participated[e][index] = true` for every set bit of the head-certificate bitmap (ECON-02(5)(b));
a batch of epoch e may land after `evidenceClose(e)` because L1-04 forbids any age/deadline condition
and L1-06 forbids rejecting a batch for being deep. ECON-07(7) itself contemplates settlement lagging
the evidence window (it exists to discuss offences "whose evidence needs the accepting batch's own
data ... wait for that backlog to settle").

**Concrete attack trace / worked counterexample.** Epoch e has validators A (signs only the first 32
blocks of the epoch) and B (signs the rest); both are honest and both hold their data.
1. A's 32-block batch is landed before `evidenceClose(e)`; `participated[e][A] = true`. The epoch's
   allocation is fixed at `evidenceClose(e)`: `Alloc(e) = 100 ETH`.
2. Claims open. `P(e) = {A}`, so A claims
   `floor(100 · stakeA / stakeA) = 100 ETH` — the whole allocation.
3. B's batch of the same epoch lands later (legal: no landing deadline, and a prover may be slow or the
   backlog may be deep). `participated[e][B] = true`.
4. B claims `floor(100 · stakeB / (stakeA + stakeB)) > 0`. Total claimed for epoch e now exceeds
   `Alloc(e) = 100`, violating ECON-02(5)(d)'s "Σ_v payout(v,e) ≤ Alloc(e) ≤ pool_before(e)"; the
   excess is bounded only by the pool balance, i.e. other epochs' allocations.
5. If the implementer instead freezes `P(e)` at `evidenceClose(e)`, B — a validator that signed,
   voted and held data for epoch e — is paid nothing, contradicting (b)'s "land ... MUST write that
   bitmap ... for every epoch the batch's heights cover" and (d)'s definition of `P(e)`.

**Inside / outside the claimed fault model.** Inside; no adversary and no assumption failure. The
"attacker" can be an ordinary prover/lander plus a validator whose batch settles early.

**Attacker resources and cost.** A's cost is being a validator with a small batch landed early; the
gain is up to the whole epoch allocation. The lander needs L1 gas only (and may be A itself, since
L1-04 admits any account).

**Harm and the exact requirement / fixed decision affected.** R11 (reward accounting), ECON-02(5)(d)
identity, ECON-12's budget identity (payouts not bounded by the epoch's allocation), R13 (the cutoff
must be invented). Pool ETH, not user funds, is at risk.

**Evidence.** ECON-02(5)(b) ("After verification, land(data, proof) MUST write that bitmap into the
staking contract's per-epoch participation accumulator — participated[e][index] = true for every set
bit, for every epoch the batch's heights cover — and nothing else may set it"); (c) ("Claims for epoch
e open only after evidenceClose(e) (ECON-07), when the epoch's allocation is fixed; a claim before
then reverts"); (d) (`P(e) = { v : participated[e][v] }` and the payout formula); L1-04 ("no deadline,
timestamp, block-number or age condition that can make a range permanently unacceptable"); L1-06
("land MUST NOT reject an over-depth batch").

---

### R3-CE-04 — ECON-06(5)'s reporter-bounty bound cannot be satisfied by the destination menu it permits

**Severity: Medium.** One-line rationale: the registered bounty bound is false for the permitted fixed
ppm split (the round-2 fix removed only the pure-100% option), so an implementer must invent a dynamic
cap; the self-reporting property itself survives via the weaker second inequality.

**Exact rule / missing rule (file + rule id).** `spec/07-economics-slashing.html` ECON-06(2), (3), (5);
`spec/09-parameters.html` `REPORTER_BOUNTY(id)` row; ECON-05(2) for `P(v,e)`.

**Assumptions and preconditions.** The recorded destination is a fixed split with
`0 < reporterPpm < 1_000_000` (the only remaining bounty form); the offence class has
`IMM_FRAC(c) > 0`; the offender's `SlashBase` is small relative to `TotalVP(e)` (realizable, since
MEM-02 weights are arbitrary base units and `S_min` is unmeasured).

**Concrete attack trace / worked counterexample.** The bounty is a share of every debited amount, so
for one identity the total paid is
`REPORTER_BOUNTY(id) = reporterPpm · charge(id)`, with
`charge = min(P, bonded, remaining)` and `P = min(SlashBase·(IMM_FRAC + c(f)), SlashBase)`
(ECON-05(2),(3)). The bound requires `REPORTER_BOUNTY(id) < c(f)·SlashBase` for "every realised f".
Take `TotalVP = 3,000,000` TAIKO, `SlashBase = 1` TAIKO ⇒ `f = 1/3,000,000`, `F_SAT = 1/3`,
`c(f) = (f/F_SAT)^1 = 10^-6` (CORR_Q = 1), and Ethereum's sourced precedent `IMM_FRAC = 1/32`:
`charge = 0.03125 + 0.000001 = 0.031251` TAIKO. With `reporterPpm = 500,000` (50%, permitted),
`REPORTER_BOUNTY = 0.0156255` TAIKO, which is ≈ 15,600× larger than the bound
`c(f)·SlashBase = 0.000001` TAIKO. Since `c(f) → 0` as the offender's share of `TotalVP` shrinks and
`charge ≥ IMM_FRAC·SlashBase > 0`, **no** constant `reporterPpm` (indeed no fixed amount) satisfies the
bound; only a per-identity cap computed from the final `c(f)·SlashBase` would. The text's own escape
("A fixed bounty amount is permitted only if it satisfies the inequality for the smallest charge the
matrix can produce") tests the wrong quantity — the bound is on `c(f)·SlashBase`, not on
`charge(id)`.

**Inside / outside the claimed fault model.** Inside; no adversary. The beneficiary can be the
offender itself reporting its own offence (the case the bound exists for), but it is not made better
off (see harm).

**Attacker resources and cost.** One evidence transaction; the gain is bounded by the second
inequality, so self-reporting still costs `charge − REPORTER_BOUNTY > 0` plus gas.

**Harm and the exact requirement / fixed decision affected.** R11 and the 09 parameter register: a
registered bound (`REPORTER_BOUNTY(id) < c(f)·SlashBase`) is false as written for the permitted menu;
R13 (the implementer must invent the dynamic cap). Distinct from round-2 E-R2-06 (pure 100% option),
which the revision fixed; the fixed-split case survives it.

**Evidence.** ECON-06(2) ("Exactly one of: TREASURY, BURN, REPORTER_BOUNTY, or a fixed integer split of
the three"; "Selecting it means `reporterPpm < 1_000_000`"); ECON-06(5) quoted bound and its
"smallest charge" sentence; ECON-05(2) formula; 09's `REPORTER_BOUNTY(id)` row registering the same
bound.

---

### R3-CE-05 — R10's honest statement names a premise its own leader-selection rule contradicts, and omits the inclusion-policy premise

**Severity: Medium.** One-line rationale: the D-6 replacement text is the one thing the relaxed R10
requires to be stated honestly, and its premise list is wrong/incomplete — not a censorship overclaim
of the old kind, but a statement whose stated condition cannot hold.

**Exact rule / missing rule (file + rule id).** `spec/04-l1-integration.html` FI-REMOVED-01 ("Three
honest caveats") and `spec/10-assurance.html` LIVE-04, versus `spec/02-consensus.html` CONS-06(b),(d);
`spec/01-system-model.html` ROLE-01(b); `spec/07-economics-slashing.html` ECON-04(5).

**Assumptions and preconditions.** None; textual.

**Concrete attack trace / worked counterexample.** FI-REMOVED-01 states: the resistance "assumes
proposer selection is not predictable enough for the coalition to buy the specific slots in which a
transaction would be included, which is CONS-06(b)'s Assumed fairness claim". But CONS-06(d) says the
proposer is computable by "anyone — a validator, a light client, a full node, an L1 contract, a user —
holding the L1-committed `set_root(epoch_of(H))` and the tuple `(chainId, epoch_of(H), H, R)` ... with
no witness, certificate, proposal, participation proof or cooperation from any validator", and CONS-06
adds "Selection is a public deterministic function, so the next proposer is predictable far in
advance". CONS-06(b)'s Assumed claim is that `pos` is **uniform** (keccak as a random oracle), not that
selection is unpredictable. So the caveat names a premise that cannot hold under the spec's own rules;
the real premise — that buying or coercing a *known* proposer is not cheaper than the delay it buys —
is not in the assumption register (A-CONS-1, A-CONS-2, A-ECO-1). Second gap: "a transaction that
reaches honest validators is included by the first honest proposer with room for it" presumes an
inclusion policy for honest proposers, but ROLE-01(b) says "No inclusion duty attaches to a validator
... omitting a particular transaction is neither a proposal-validity failure nor an offence" and
ECON-04(5) confirms "the catalogue contains no censorship or omission offence". The premise is
therefore unregistered (and R13-relevant).

**Inside / outside the claimed fault model.** Analysis-level; bribery is threat T-6, listed in the
threat model but not carried into LIVE-04's premise list.

**Attacker resources and cost.** A coalition with f < 1/3 needs to pay proposers for selected slots;
no cost is stated because the premise is assumed away.

**Harm and the exact requirement / fixed decision affected.** R10 relaxed form (honesty of the
statement), R13, and the D-6 obligation that the consequence be stated rather than softened. The
withdrawal-censorship consequence itself is disclosed correctly and in all required places.

**Evidence.** The three quotations above; LIVE-04's identical text; LIM-01's censorship row.

---

### R3-CE-06 — Two normative-looking instructions disagree about the L2 SignalService checkpoint writer, and the residual privilege is live in ordinary operation

**Severity: Medium.** One-line rationale: 01-system-model orders a repoint that MIG-06 forbids, so the
migration implementer has no single instruction, and the residual single-writer privilege it leaves is
in ordinary operation (R1/R2 not satisfied for that lever, as the spec itself says elsewhere).

**Exact rule / missing rule (file + rule id).** `spec/01-system-model.html` §3.1 table row
"SignalService single writer" and SYS-02(g)/SYS-04(a),(c), versus `spec/08-migration-upgrades.html`
MIG-06 ("L2 SignalService checkpoint writer, reconciled") and MIG-04's golden-touch row; GOV-01.

**Assumptions and preconditions.** The migration bundle is built from these documents; the golden-touch
address is key-controlled (a precondition the spec records as unverified, P4).

**Concrete attack trace / worked counterexample.**
1. 01 §3.1: "The preserved address (D3) must be repointed by a layout-safe in-place upgrade (MIG-02) to
   a write path that is not a single privileged address. No replacement deployment (MIG-06)."
2. MIG-06: "The aspiration recorded elsewhere in this specification — that the preserved L2 address be
   repointed to a write path that is not a single privileged address — **is not achieved by this
   migration and cannot be achieved by it** without a different `_authorizedSyncer`, which this rule
   forbids."
3. An implementer who follows (1) violates MIG-06 and MIG-06's stated consequence (the immutables
   "are properties of the implementation code ... an implementation upgrade can change them; this rule
   therefore forbids changing them"); an implementer who follows (2) leaves SYS-02(g)'s reserved system
   sender able to publish (or withhold) the L1 fact, which SYS-04(a) calls "a discretion surface in
   ordinary operation" and states means "R1/R2 of the requirements matrix (01 §7) are not yet
   satisfied".
4. SYS-04(a),(c) does list this privilege honestly and MIG-06 carries its removal as Open — the defect
   is that 01 §3.1's instruction was not withdrawn, and the README's R1/R2 checklist rows say only
   "specified" without the residual.

**Inside / outside the claimed fault model.** Inside as a specification defect; the privilege itself is
a trust assumption (A-GOV-1-adjacent) that the spec declines to rely on.

**Attacker resources and cost.** If the reserved sender is a single key (P4 unverified), the holder
needs only to choose or withhold a payload; no stake.

**Harm and the exact requirement / fixed decision affected.** R1 (permissionless roles), R2 (DAO
upgrades only / no privileged party), R3 (the preserved writer link), R12 (no L1 lookahead — the
retained writer is not that, but it is the same privilege family), R13/R14 (two documents, two
instructions).

**Evidence.** The three quotations; 01-system-model's "What this model does NOT claim" is silent on
this residual, while SYS-02(g) states it; MIG-06's "Open" pointer.

---

### R3-CE-07 — Parameter-register drift: `WITHDRAWAL_DELAY` is an unregistered third name used by the normative withdrawal gate

**Severity: Low.** One-line rationale: PARAM-01 requires every protocol parameter to be registered, but
the name MSG-03 uses for the withdrawal delay appears nowhere in 09, so a reader implementing the
withdrawal gate cannot resolve it.

**Exact rule / missing rule (file + rule id).** `spec/04-l1-integration.html` MSG-03 and §8's unmeasured
register; `spec/08-migration-upgrades.html` MIG-02 ("Protocol parameters (... `WITHDRAWAL_DELAY`)");
`spec/09-parameters.html` PARAM-01 and the `D_WITHDRAW` row; `spec/07-economics-slashing.html`
ECON-03(1).

**Assumptions and preconditions.** None; citation-level, but in a rule that gates value leaving the
bridge.

**Concrete attack trace / worked counterexample.** MSG-03: "plus the delay `WITHDRAWAL_DELAY` measured
from that checkpoint's `l1BlockNumber` ... `WITHDRAWAL_DELAY` MUST be derived from the whole settlement
pipeline ... its value is in 09". 09 registers only `D_WITHDRAW` (and ECON-03(1) declares the
deprecated alias `D_withdraw`, with "clients, parameters and migration text MUST use `D_WITHDRAW`").
An implementer searching 09 for `WITHDRAWAL_DELAY` finds no row — the parameter that must gate the
release of bridged value. This is the same class as round-2 E-R2-11(c), whose disposition says the
alias pair was "resolved to one registered name".

**Inside / outside the claimed fault model.** Inside; no adversary.

**Attacker resources and cost.** None.

**Harm and the exact requirement / fixed decision affected.** R13 and PARAM-01 (every parameter
registered with unit/derivation/tag); R3 (withdrawal delays).

**Evidence.** Quotations above; grep of the 09 text shows no `WITHDRAWAL_DELAY` occurrence;
`D_WITHDRAW` is used by MEM-05/ECON-03/09.

---

### R3-CE-08 — The two-epoch amendment is described inconsistently: CONS-13(2) omits the stored anchor field, and the README summary still says one-epoch lookahead

**Severity: Low.** One-line rationale: two surviving descriptions of the epoch→set mapping and the
lookahead contradict the amended rules an implementer must build against.

**Exact rule / missing rule (file + rule id).** `spec/02-consensus.html` CONS-13(2) versus
`spec/03-membership-staking.html` MEM-09(2) and `spec/07-economics-slashing.html` ECON-07(1);
`README.md` summary table row "Membership" versus `spec/02` CONS-13(3) and `spec/09`
`LOOKAHEAD_EPOCHS = 2`.

**Assumptions and preconditions.** None; textual.

**Concrete attack trace / worked counterexample.** CONS-13(2) states the L1 staking contract "stores an
append-only per-epoch mapping `epoch → (setRoot, totalVotingPower)`", while MEM-09(2) and ECON-07(1)
require `epoch → (setRoot, totalVotingPower, rootCommittedAt)` — the third field is the stored
evidence-window anchor `t_root(e)` without which `evidenceClose(e)` cannot be computed. An
implementer who follows CONS-13(2) omits it and ECON-07's window becomes uncomputable (the class
E-R2-07 was closed for). Separately, the README summary says membership uses "epoch-scoped validator-set
roots committed with one-epoch lookahead" while CONS-13(3)/MEM-09(1) and 09 mandate two, and the
README's own revised paragraph (working tree, 17:38) states the two-epoch fix.

**Inside / outside the claimed fault model.** Inside; no adversary.

**Attacker resources and cost.** None.

**Harm and the exact requirement / fixed decision affected.** R13, ECON-07 (window computability),
R14 (README consistent with the specification); the R2A-01 fix is otherwise complete in the normative
pages.

**Evidence.** The three quoted mapping descriptions; README line 48 (frozen snapshot and current
working tree); 09's `LOOKAHEAD_EPOCHS` row ("2 — the set root for epoch e+2 is committed during epoch
e ... normative and not tunable").

---

## Checked and holds (not re-listed as findings)

- **D5, Etna path:** L1-01/L1-02/L1-03 (single atomic `land(data, proof)`; no announce/commit
  function; verify-before-write with typed revert and no partial effect), L1-06 (strict succession; no
  upgrade, recovery or governance call may lower `lastLandedHeight` or backfill), L1-10 (first valid
  submission wins; re-submission allowed), DA-01–DA-04 (data canonical in the accepting transaction;
  calldata commitment computed by the contract; blob path bound by BLOBHASH + on-chain KZG opening +
  in-guest recompletion over the whole blob bytes), REC-01(e), REC-02's "D5 in full" obligation, HALT-04.
  Round-2 R2-LIV-07/08 hold: one cap, one unit, consensus-only, L1-04/L1-06/DA-06/HALT-03 all agree that
  `land` must not reject for depth.
- **D-6 removal:** no FI-01..FI-05 residue anywhere in `spec/` (grep); row 20 vacant and not reused; no
  censorship/omission offence; CONS-01 has no inclusion clause; the tombstone + LIVE-04 + ROLE-04(b)(i)
  + LIM-01 + 09 glossary + learn/11 all carry the same statement and the withdrawal-censorship
  disclosure.
- **D3:** MIG-02 budget (10 of 43 Inbox gap slots 258–267; 268–300 free), zero-slot changes for
  SignalService/Bridge/vaults/Anchor, append-only rule, frozen prefix 0–250, deprecated slots frozen;
  MSG-01's field split needs no frozen-layout change; MIG-06's address table and in-place rule.
- **D7:** MEM-01/ECON-01(1),(2) (existing TAIKO only; no ETH/wrapped/L2 stake; `getVotes` rejected);
  ECON-02(1)–(4) (ETH rewards conforming; no appreciation; no mint; bounded expiring subsidy netted as
  `D_subsidy`); ECON-10(5) (no hard-coded market datum); ECON-12(1),(4) (dated reserve, price
  reflexivity disclosed); reporter bounty paid from already-debited slashed TAIKO.
- **R1/R2 residual, honestly listed:** DAO upgrade authority only (GOV-01, A-GOV-1) plus the SYS-02(g)
  reserved L2 checkpoint writer (SYS-04(a),(c); Open in MIG-04/MIG-06) — the contradiction about the
  latter is R3-CE-06.
- **Economics that hold:** ECON-09 (dimensionally closed, no price term, unfunded regime stated),
  ECON-07(1),(2),(4),(7) (stored anchor, strict inequality, `3·E_EPOCH` re-derivation for two-epoch
  lookahead, HALT-03 coupling and the stated direction in which the cap yields), MEM-05(2)/ECON-03(6)
  (churn wired into exit effectiveness; deferred exits ordered by the objective key), MEM-03(2)
  (activation FIFO, rate limit, fairness disclosure), ECON-05 (saturation at `F_SAT = 1/3`, bounded
  debit, honest-mistake tail), ECON-08 (no bond forfeited on "not proven"; permanent `applied[id]`).
- **Round-2 fixes re-checked as holding:** R2A-01 (CONS-13(3), MEM-09(1), 09 `LOOKAHEAD_EPOCHS`=2,
  ECON-07(4)), E-R2-02 (L1-05 §2.1 reconciliation; row 2 the only L1-local value; row 20 vacant),
  E-R2-03 (slot budget and legal genesis record), E-R2-04 (routes are upgrades only), E-R2-07 (`t_root`
  stored), E-R2-08/R2A-06 (churn), R2A-10 (per-height lock), E-R2-06 (pure-100% option deleted — but
  see R3-CE-04), E-R2-05 (mechanism added — but see R3-CE-02/03). The round-1 blob-binding Critical was
  not re-attacked here (out of this angle); the D5 binding path itself does not depend on the
  fixed-point argument, because the calldata path is contract-computed.

## Counts

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 2 (R3-CE-02, R3-CE-03) |
| Medium | 4 (R3-CE-01, R3-CE-04, R3-CE-05, R3-CE-06) |
| Low | 2 (R3-CE-07, R3-CE-08) |

Every High needs no Byzantine stake, no network adversary and no assumption failure: both are
ordinary-operation defects in the amended reward mechanism, inside the claimed fault model. The
strongest attack is R3-CE-03: the participant set that determines a validator's epoch payout is not
frozen when claims open, so the permissionless landing order lets an early claimant take the epoch's
whole allocation before late participants accrue, and the per-epoch identity `Σ payout ≤ Alloc(e)` in
ECON-02(5)(d) cannot be enforced as written.
