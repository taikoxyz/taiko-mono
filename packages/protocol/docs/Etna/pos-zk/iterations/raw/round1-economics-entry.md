# Round 1 — adversarial review: economics, TAIKO stake concentration, permissionless entry

Reviewer angle: **economics, TAIKO stake concentration, permissionless entry** (adversarial; findings first).
Frozen snapshot: `dfcf067a5b91a1b0bacd4470f5f5054d1f861a24` (verified with `git rev-parse HEAD`, 2026-10-05).
Material read: [README.md](../../README.md) (D1–D7), [01-requirements-and-threat-model.md](../../01-requirements-and-threat-model.md) (§4–§8),
[04-architecture-decision.md](../../04-architecture-decision.md), [DECISIONS.md](../../DECISIONS.md),
[07-economics-slashing.html](../../spec/07-economics-slashing.html) (ECON-01..12),
[03-membership-staking.html](../../spec/03-membership-staking.html) (MEM-01..12),
[01-system-model.html](../../spec/01-system-model.html) (SYS/ROLE), plus 02/04/06/09/10 as needed and
[economics-raw.md](../../research/economics-raw.md).

**Number discipline.** [sourced] = a value/claim taken from this specification or its cited sources;
[derived] = arithmetic on decided or sourced inputs; [unmeasured] = the project states no value.
Where an illustrative magnitude is required it is marked **(illustrative, unmeasured)** and used only
to make arithmetic concrete. No TAIKO price, float, depth, volume or yield is asserted anywhere.

**One-line verdict.** Entry is *formally* open and *economically* unproven; the reward budget has no
inflow denominated in the asset the rewards are said to be paid in; the withdrawal/evidence-window
derivation does not perform the work ECON-07 claims for it; and the anti-concentration argument
contains an internal contradiction and a price-dependent hole.

---

## Findings

### ECO-01 — The reward-funding identity has no inflow in the reward asset, and no L2→L1 revenue path — **Critical**
**Rationale (one line).** ECON-02 fixes rewards as nominal TAIKO but the only funding identity is a sum
of untyped ETH/fee terms with no TAIKO inflow and no mechanism moving L2 fee revenue to the L1 pool, so
ECON-02(3)'s "MUST be fundable from clause 1 alone" cannot be satisfied or even evaluated as written.

**Exact rule / missing rule.** `spec/07-economics-slashing.html` §2 **ECON-02** clauses (1),(2),(3),(5);
`spec/04-l1-integration.html` §4 **L1-11**; missing rule: *a rule naming the reward asset, the TAIKO
inflow (if any), the ETH→TAIKO conversion (if any) and the L2-fee→L1-pool transfer*.
- ECON-02(2): "A reward is a **nominal TAIKO amount** fixed when it is awarded".
- ECON-02(1): `Σ rewards ≤ F_exec_L2 + F_priority_L2 + MEV_captured + S_explicit − C_L1_data − C_L1_verify − C_bridge_ops`.
  Every fee/cost term is ETH-denominated by D7 ("gas stays ETH"); `F_exec_L2`/MEV accrue on L2 in ETH.
- ECON-02(4)(a): `S_explicit` has "a maximum amount **in TAIKO and in ETH**" — i.e. the identity is
  explicitly a sum of two assets with no exchange rate anywhere in the specification.
- ECON-10(5) forbids any price/constant; ECON-02(2) forbids assuming appreciation; no oracle or
  conversion policy is defined.
- L1-11: the reward ledger is `proverReward_after = proverReward_before + msg.value − rewardPaid` —
  an **ETH** balance — "funded by L2 fee revenue (ECON-02) and by any `msg.value`". No rule moves L2
  fee revenue (ETH on L2) into that L1 balance; the baseline's L2 basefee goes to the L1 block coinbase
  (`basefeeSharingPctg = 100`, economics-raw §1.5), not to a protocol pool.
- ECON-02(3) permits new TAIKO only through a DAO token upgrade; none is authorized, and
  `tokenomics_objective_metrics.md:19` ("No Built-In PoS Reward") forbids paying TAIKO to stakers
  unless a new user decision reverses it — none is recorded.

**Assumptions / preconditions.** D7 (TAIKO staking, ETH gas); no mint/burn on L1 TAIKO (verified:
only `_mint` at `TaikoToken.sol:41`, no public mint/burn); ECON-02(3)'s recorded policy stands.

**Attack trace / counterexample (no adversary needed).**
1. Reading A (rewards in TAIKO): clause 1 contains no TAIKO term. Set every fee term to its maximum:
   `Σ rewards_TAIKO ≤ (ETH terms) + S_explicit_TAIKO`. The inequality is dimensionally undefined, and
   the only TAIKO source is the bounded, expiring `S_explicit`, which clause (3) says may not be the
   standing source. Rewards therefore stop the day the subsidy ends — the "fee-only region" of ECON-12
   is unreachable *by construction* because fees never produce TAIKO.
2. Reading B (rewards in ETH): then ECON-02(2) is false, and the entire operator/capital analysis that
   prices a **TAIKO-denominated** position (ρ_capital's "price-risk premium", ECON-12(1); the
   reflexive-loop argument, ECON-12(4); economics-raw §3.4) is mis-specified; additionally the
   `F_exec_L2` term still has no path onto L1.
3. Either reading: a reward schedule cannot be written that satisfies clause (2) and clause (3)
   simultaneously. Example (illustrative, unmeasured): n = 100 validators, S = 100,000 TAIKO,
   required r_req = 5 %/yr in TAIKO ⇒ 500,000 TAIKO/yr owed; suppose fee inflow converts at the
   prevailing price to exactly that; without a conversion rule and with a forbidden price constant,
   no rule can assert the conversion or size it. The number that decides whether the design is funded
   (ECON-12's `NetFeeRevenue ≥ Budget(n)`) is therefore not computable from the specification.

**Inside / outside the claimed fault model.** Not an attack; it is a specification-level defect that
bites in **normal operation, before any adversary acts**. It is *inside* the design's own conformance
claim (GEN-02, R13) and outside every F-class only in the sense that no attacker is required.

**Attacker resources and cost.** None. Consequence is a design gap, not exploit cost.

**Harm and requirement/decision affected.** R1 (permissionless staking cannot have a finite entry floor
when the reward rate is undefined — see ECO-02), R11 (collateral/rewards), R13 (an implementer must
invent the reward asset, the conversion and the pool funding), R14 (learn material repeats the claim),
D7's economic premise, and ECON-02's own MUST. The security budget — the quantity that A-ECO-1 is
supposed to compare against attack profit — is not defined by any rule.

**Evidence.** `spec/07-economics-slashing.html` §2 ECON-02 (raw file lines 88–133); §12 ECON-12
(lines 485–518); `spec/04-l1-integration.html` L1-11 (lines 305–321); `research/economics-raw.md` §1.1,
§1.3, §2.9, §3.4; `packages/protocol/docs/tokenomics_objective_metrics.md:19`;
`packages/protocol/contracts/layer1/mainnet/TaikoToken.sol:41`. README already flags HUM ("reward
funding (ECON-02)") as a human decision — but a *disclosed blocker* is still a defect against R13, and
ECO-01 shows it is not merely a missing number: the identity is untyped.

---

### ECO-02 — `S_min` is an unmeasurable, possibly non-existent predicate; R1 is unsatisfiable as specified — **High**
**Rationale.** The only admission predicate of the validator role is `amount ≥ S_min` (MEM-03(1),
custody `bond`), and ECON-09(1) admits that if `r_gross ≤ ρ_ops` there is **no finite S_min**; no rule
establishes the contrary, and ECO-01 leaves `r_gross` undefined.

**Exact rule / missing rule.** ECON-09 (1),(3),(4); MEM-03(1); custody interface sketch
`bond(uint256 amount, bytes32 ed25519PubKey)` ("requires `amount ≥ S_min`"). Missing: a rule that fixes
`S_min` from measured inputs, or that makes entry possible when the reward rate cannot exceed the
operator margin.

**Assumptions / preconditions.** D7; no mint; ECON-02's schedule; `C_op_annual`, `r_gross`, `ρ_ops`,
`S_affordable` all [unmeasured].

**Attack trace / counterexample.** ECON-09(1): `S_min ≥ C_op_annual/(r_gross − ρ_ops)`. If the numerator
is positive and the denominator ≤ 0, no finite `S_min` satisfies it; ECON-09(1) states this outcome is
"the design is unfunded… not a licence to lower the minimum". ECON-09(3) then requires
`S_min ≤ S_affordable(median intended participant)` or "entry is permissionless only in name (R1)".
Both horns are spec-legal: (a) a finite large `S_min` excludes a median participant (R1 nominal);
(b) no finite `S_min` means `bond()` has no implementable threshold. Either way the *only* gate on the
permissionless role is not fixed by any rule, and ECON-12(2) shows the budget cost of the low-`S_min`
horn grows linearly in `n` while fee revenue does not. There is no demonstrated parameter region
satisfying R1 + R6 + no-mint simultaneously.

**Inside / outside the fault model.** Outside any adversary model; it is a normal-operation conformance
failure (the design's own rules admit a state where no one can enter).

**Attacker resources and cost.** None; consequence is exclusion or non-implementability.

**Harm and requirement affected.** R1 (hard requirement), R13, and — through the free choice of
`S_min` — the concentration outcome the spec claims is *not* promised but is decided here.

**Evidence.** ECON-09 (raw lines 384–411); MEM-03(1),(3) (lines 132–159); ECON-12(2) (lines 495–502);
`research/economics-raw.md` §3.1 ("the reward rate, not the attack-cost argument, is the binding
constraint on the minimum stake").

---

### ECO-03 — ECON-09(1) and ECON-12(1) silently assume a TAIKO price, contradicting ECON-02(2) and ECON-10(5) — **High**
**Rationale.** The break-even and budget formulae combine fiat costs with token quantities without a
price term; the missing term is exactly the quantity the specification forbids assuming, so a price
level is assumed silently by the algebra.

**Exact rule / missing rule.** ECON-09(1): `S_min ≥ C_op_annual/(r_gross − ρ_ops)`, `r_be = C_op_annual/S + ρ_ops`;
ECON-12(1): `Budget(n) = n·(C_op + ρ_capital·S)`; missing: an explicit price conversion
`P(t)` (e.g. `S_min ≥ C_op_annual/((r_gross − ρ_ops)·P(t))`) and the rule that recomputes it.

**Assumptions / preconditions.** `C_op_annual` is hardware/bandwidth/ops/L1 gas — fiat costs
(ROLE-01(c), ECON-09(4)); `S`, `S_min` are TAIKO (MEM-01(1)); `ρ_capital` is a fiat rate
(economics-raw §3.4).

**Attack trace / counterexample (derived).** Units: `C_op_annual/S` is (fiat·yr⁻¹)/(TAIKO) = fiat per
TAIKO per year — not a rate comparable to `ρ_ops` until divided by `P(t)`. With `C_op_annual` =
**X** fiat [unmeasured] and `S` = 100,000 TAIKO [illustrative, unmeasured], the sign and magnitude of
`r_be` depend entirely on the omitted price: at P = 1 unit/TAIKO the implied rate is X/100,000; at
P = 0.1 it is X/10,000 — a **10×** swing that silently changes which side of `ρ_ops` the design is on.
ECON-10(5) forbids a constant price; ECON-02(2) forbids assuming appreciation; the algebra assumes a
fixed level. The "derived price at which the design stops being secure" (07 §volatility) is precisely
the missing term, but no rule inserts it into ECON-09 or ECON-12.

**Inside / outside the fault model.** Not an attack; it is an unsound derivation. Its consequence is
inside the fault model: A-ECO-1 can fail with no rule change (admitted in 07 §volatility), and the
paperwork intended to detect that cannot be computed.

**Attacker resources and cost.** None required; a spot-price move to the price at which the omitted
term flips the sign of the denominator is sufficient to invert the operator-economics conclusion.

**Harm and requirement/decision affected.** R13 (the implementer must invent the price and when to
re-derive it), R6/A-ECO-1 (security claim), R14 (the learn pages repeat "no appreciation assumed"),
D7's "rewards in TAIKO, costs fiat" premise; ECON-12's "fee-only region" test is uncomputable.

**Evidence.** ECON-09(1),(4); ECON-12(1),(4); ECON-10(5); 07 §volatility (raw lines 519–551);
`research/economics-raw.md` §3.1, §3.4, §3.5 (all market data UNVERIFIED, must not be hard-coded).

---

### ECO-04 — The evidence window is anchored to the epoch's set-version L1 block, not to the offence; late-epoch offences get a window shorter than `W_evidence`, and ECON-07(4)'s lower bounds omit the offset — **High**
**Rationale.** ECON-07(1) defines `evidenceClose(e)` from the L1 block that committed the set version of
`e`, while the offence can occur up to ~two epoch-lengths later; the derived inequality and lower
bounds use `W_evidence` as if it ran from the offence, so the exit-race defence is short by exactly
the epoch/lookahead offset and can be empty for late offences.

**Exact rule / missing rule.** ECON-07(1),(2),(4); MEM-09(2)–(5); CONS-13(3). Missing: a rule that
starts the clock at the offence (or that adds `E_epoch` + lookahead + `T_L1_final` to every lower bound).

**Assumptions / preconditions.** CONS-13(3): `set_root(e+1)` is committed **during** epoch `e`, and
final before `e+1` starts; so `N(setVersion(e))` lies **inside epoch `e−1`**. Epoch length
`L = 900` heights × 2 s = **1,800 s** [derived, CONS-13(1)+D1]. Set versions require Ethereum finality
(SYS-02/MEM-09(5)) [value unmeasured].

**Attack trace / counterexample (derived).** Let epoch `e` span `[e0, e0+1800)`. The governing set was
committed during `e−1`, i.e. at `N(k) ∈ [e0−3600, e0−1800]` roughly. An equivocation by validator
`v` at the **last** block of `e` (t ≈ e0+1798 s) is admissible only until
`evidenceClose(e) = N(k) + W_evidence`, so the time actually available to detect and submit is
`W_evidence − [1800, 3600] s − (N(k)→e0 finality gap)`. With `W_evidence` chosen as ECON-07(4)
permits for equivocation — `W_evidence ≥ T_detect + T_evidence_submit` — the available time is
**negative** for any `T_detect + T_evidence_submit < 1800` s. Even with a generous
`W_evidence = 7,200` s [illustrative, unmeasured] a last-block offence has only ≈3,600–5,400 s minus
finality. The offender's rational play is therefore: equivocate at the end of an epoch, let the window
lapse, exit through MEM-05; ECON-08(5)'s "impossible by construction" is achieved by *time-barring*
the evidence, not by guaranteeing it can arrive. This also contradicts ECON-03(2) ("the evidence clock
starts **at the offence** on L2") and economics-raw §2.5 ("the evidence window starts at the offence"),
so the specification and its own research input disagree about the clock's origin.

**Inside / outside the fault model.** Inside: the attacker is a validator with < 1/3 stake (A-CONS-1
holds) and no assumption is violated; the harm is an unpunishable offence, i.e. the R11 collateral
guarantee.

**Attacker resources and cost.** One validator entry at `S_min` plus the offence itself; the marginal
cost of timing the offence late in an epoch is zero.

**Harm and requirement/decision affected.** R11 (objective evidence and collateral), R5's economic
premise, ECON-07/ECON-08's claimed construction, MEM-06(3)'s "three rules hold together" claim (the
third fails).

**Evidence.** ECON-07 (raw lines 311–341); ECON-03(2) (lines 139–143); ECON-08(5) (lines 367–376);
MEM-05(4) (lines 276–278); MEM-09(2) (lines 432–436); CONS-13(3) (02-consensus lines 368–374);
`research/economics-raw.md` lines 340–354.

---

### ECO-05 — The censorship/omission offence has an empty window whenever batch acceptance post-dates `evidenceClose(e)`, and its stated lower bound omits the whole D5 pipeline — **High**
**Rationale.** The only substantive censorship penalty opens its window at L1 acceptance of the batch
(ECON-04) but closes it at the set-version anchor (ECON-07(1)), so the very settlement latency D5
introduces can consume the window entirely; ECON-07(4) nonetheless requires only
`T_detect + T_evidence_submit` for omission offences.

**Exact rule / missing rule.** ECON-04 clause (2) omission row ("the window opens at the L1 acceptance
of the batch carrying B"); ECON-07(1),(4); FI-01..FI-05. Missing: a single window-opening rule and a
lower bound containing `T_proof_bound + T_L1_include(p) + T_L1_final` (and the epoch offset).

**Assumptions / preconditions.** D5 (data **and** proof in one L1 transaction) means B's body is
canonical only once its batch lands; D6 allows up to 1,800 s of proving; `p`-quantile L1 inclusion and
Ethereum finality are additional terms.

**Attack trace / counterexample (derived).** Epoch `e` = `[e0, e0+1800)`; last block `B` at
`e0+1798`. `B`'s batch can be accepted no earlier than `e0+1798 + T_proof_bound` (D6 permits
`T_proof_bound ≤ 1800 s`) plus `T_L1_include(p)` and must be final for evidence purposes. The window
opens at acceptance and closes at `N(k)+W_evidence ≤ e0 + W_evidence` (anchor inside `e−1`). Non-empty
requires `W_evidence ≥ 1800 (epoch) + [1800,3600] (lookahead) + T_proof_bound + T_L1_include + T_L1_final`
≈ **1.5–2 h+** [derived from decided/sourced envelope terms; inclusion/finality values unmeasured].
The rule's own omission bound is `T_detect + T_evidence_submit` — two orders of the pipeline short.
A designer who follows the rule produces an offence that is **never provable**, and a validator set
that omits due forced inclusions cannot be penalised. R10's escape hatch remains, but the *penalty*
that gives FI-02 its teeth is unreachable.

**Inside / outside the fault model.** Inside: censoring proposers are validators below the Byzantine
threshold; no assumption is broken; the design's own timing rules create the blind spot.

**Attacker resources and cost.** A proposer coalition able to build the last block of an epoch
(a sub-threshold share of proposer slots, or a single selected proposer per CONS-06); cost ≈ 0 beyond
the normal proposal.

**Harm and requirement/decision affected.** R10 (forced inclusion), R11 (objective misconduct
evidence), ECON-07's stated purpose, FI-02's deterrence; D5 indirectly (settlement latency is what
breaks the window, and the rule fails to account for it).

**Evidence.** ECON-04 omission row (raw lines 200–210); ECON-07(1),(4); ECON-03(2),(5);
`spec/04-l1-integration.html` FI-01..FI-05; `research/economics-raw.md` §3.3 ("Two distinct classes of
evidence, two distinct windows").

---

### ECO-06 — `REPORTER_BOUNTY` allows the offender (or an affiliate) to collect its own penalty, making slashing net-zero or profitable — **High**
**Rationale.** ECON-06's permitted destination set includes a bounty paid to the submitter, and no rule
requires the submitter to be independent of the offender; because evidence is public and first-come,
the offender can self-report and recover up to 100 % of the debit.

**Exact rule / missing rule.** ECON-06(2) (`REPORTER_BOUNTY`, "fixed integer split"), (3) ("a bounty is
paid once per applied offence identity"); ECON-05. Missing: an independence requirement (submitter
≠ entry owner/beneficiaries, or bounty paid to a sink not controlled by the offender), a cap tying the
bounty below the penalty, or a rule making self-report non-profitable.

**Assumptions / preconditions.** ECON-06 chooses a destination containing `reporterPpm > 0`; evidence
is two public signed messages (CONS-11); the bounty sink is an address chosen by the submitter.

**Attack trace / counterexample (derived, illustrative values [unmeasured]).** n = 100 validators,
each `SlashBase = S = 100,000` TAIKO; `IMM_FRAC = 0.01`; `CORR_Q = 1`; one equivocator.
`f(e,c) = 1/100 = 0.01`; `c = min(3·0.01,1) = 0.03`; `P = min(S·(0.01+0.03), S) = 4,000` TAIKO.
With `reporterPpm = 1,000,000` (pure `REPORTER_BOUNTY`) and the offender's affiliate as first
submitter, the debit is returned to the affiliate: **net penalty 0** minus L1 gas [unmeasured]. The
correlated component is only computed later and is likewise dispatched per ECON-06(3); a second
affiliate collects that too. Even a partial share (e.g. 50 %) halves the effective deterrent, and the
same trick works for the correlated application if any affiliate calls `applyCorrelated` (no
caller restriction is stated). The specification's only guard — "the split MUST NOT be chosen to make
a budget balance" — does not address self-reporting.

**Inside / outside the fault model.** Inside: an economically rational validator with < 1/3 stake
commits a listed offence and neutralises the penalty; A-CONS-1 and A-ECO-1 are the affected
assumptions.

**Attacker resources and cost.** One entry at `S_min`, the offence, L1 gas for the evidence
transaction [unmeasured]; the bounty funds the reporting cost (that is its purpose).

**Harm and requirement/decision affected.** R11 ("penalties"), A-ECO-1's deterrence half, INV-03's "no
consensus without TAIKO at risk" (the stake is at risk in name only), ECON-05's saturation argument
(which assumes the charge is a loss), ECON-06's own requirement that the destination not change the
penalty amount.

**Evidence.** ECON-06(1)–(3) (raw lines 284–309); ECON-05(2),(6) (lines 239–270); ECON-04(4) (lines
186–190); economics-raw §2.2 (Ethereum's bounty is sized at 1/512 of effective balance, i.e. ~0.2 %,
*not* a rebate of the penalty — this design permits 100 %).

---

### ECO-07 — No exit churn limit: the claimed "slow and visible" decline of `S_total` is false, enabling a timed attack on the security cliff — **High**
**Rationale.** MEM-05 makes every pending exit effective at the first set-version snapshot at/after the
request and imposes no per-epoch exit cap, so the whole stake can leave the voting set in one
snapshot; the stated mitigation for a price collapse ("S_total declines only as fast as D_withdraw
allows") is therefore wrong.

**Exact rule / missing rule.** MEM-05(1),(2) (no churn limit); ECON-12(2),(4); 07 §"If the price falls";
missing: an exit-churn limit, a minimum-`S_total`/minimum-online-stake halt rule, or a stated
retention of exiting stake in `TotalVP`.

**Assumptions / preconditions.** Exit becomes effective at a set-version boundary (lifecycle
transition 4); `D_withdraw` gates only the *withdrawal of the balance*, not the loss of voting power;
set versions are committed on a schedule (CONS-13(3)).

**Attack trace / counterexample (derived).** k validators may all call `requestExit()` in one L1 block.
Transition 4 makes `effStake = 0` for each of them at the **same** next set version; `TotalVP` drops by
k·S at one height. `D_withdraw` [unmeasured, ≥ the pipeline sum] then delays only the token payout — it
does not smooth the security loss. A rational attacker observes the public subsidy end date
(ECON-02(4)(b): "a start and an end expressed in unix seconds") or a price threshold, waits for
honest operators to exit first (the spec's own adverse-selection point, economics-raw §4.3), and then
acquires/rents the smaller `S_total`. There is no rule that halts when `S_total` falls below the level
at which `S_total ≥ Λ·(EV+OV)/(b·P(t)·(1+σ(t)))` (ECON-09(2)) holds, and LIVE-01/LIVE-02/HALT-01 do not
list such a condition.

**Inside / outside the fault model.** Inside: no Byzantine assumption is needed; the trigger is a
scheduled subsidy end or a market move, both normal-operation events (F1-adjacent), and the attack
itself is T-5 stake acquisition.

**Attacker resources and cost.** Capital to acquire b·S_total after the collapse, which is *smaller*
precisely because the collapse happened; timing is public. Optionally the attacker can itself be an
exiting validator and be paid its unbonding balance during the attack.

**Harm and requirement/decision affected.** R6 (liveness/security conditionality), A-ECO-1, ECON-12(2),
the "fee-only region" hand-off claim (arXiv:2606.03587 hand-off requires reaching the fee-only region
*before* the reserve depletes — a stampede is the failure mode the paper models).

**Evidence.** MEM-05(1),(2) (raw lines 266–272); lifecycle table row 4 (lines 221–223); ECON-12(2),(4)
(lines 495–510); 07 §"If the price falls" (lines 541–546); economics-raw §4.3 ("The only mitigation
available… strongest argument for choosing D_withdraw generously") — the mitigation does not exist as
stated.

---

### ECO-08 — `WS_max ≤ T_proof_bound + M − M_ws` ≈ the D6 envelope: any halt longer than ~30 minutes makes fresh sync impossible — **High**
**Rationale.** MEM-11(2) derives the maximum bootstrap-checkpoint age by substituting MEM-05(4); the
result is at most the proving envelope plus margins, so a normal-length settlement stall (≤ 30 min,
D6) or any halt puts the chain beyond the freshness window, and MEM-12(3) forbids syncing from
genesis — new participants cannot join precisely when a restart needs them.

**Exact rule / missing rule.** MEM-11(2),(5); MEM-12(3); D6; HALT-01/HALT-02. Missing: a rule that keeps
a fresh checkpoint obtainable across a halt (or that states that permissionless entry ends there, in
which case R1's scope must be narrowed).

**Assumptions / preconditions.** Checkpoints advance only on L1 acceptance of a batch (L1-07, D5);
`T_proof_bound` is the D6 envelope 1,800 s [decided]; `M`, `M_ws` [unmeasured]; halts may last
arbitrarily long (HALT-01, LIVE-01).

**Attack trace / counterexample (derived).** MEM-11(2): `WS_max ≤ D_withdraw − (T_detect +
T_evidence_submit + T_L1_include + T_L1_final + T_process) − M_ws`; substituting MEM-05(4) gives
`WS_max ≤ T_proof_bound + M − M_ws` — the spec states this. With `T_proof_bound = 1800` s and
`M_ws > 0`, `WS_max < 1800 + M` seconds. The D6 envelope itself is 1,800 s, and normal operation is
allowed to use the whole envelope; add `T_L1_include` and Ethereum finality and a *normal* batch can
age past `WS_max` before its successor lands. After any halt longer than that (an F1 event the spec
calls a correct outcome), no Ethereum-final checkpoint younger than `WS_max` exists ⇒ MEM-11(2)
forbids bootstrap, MEM-12(4) requires the node to refuse verification, and MEM-12(3) forbids
genesis-sync. A fresh validator therefore cannot enter during or after the halt, while HALT-02 restart
rules assume participants can resume. (Set `M` [unmeasured] would have to be enormous — e.g.
days — for the window to survive a long halt; no rule bounds it.)

**Inside / outside the fault model.** Inside: the trigger is an F1 liveness failure (prover outage, L1
congestion, data unavailability) that D2 explicitly classifies as permitted, i.e. the entry failure
happens inside the stated fault model.

**Attacker resources and cost.** No attack required; a prover cartel (T-9) or L1 congestion of >30 min
suffices to close the entry door.

**Harm and requirement/decision affected.** R1 (entry), R6 (liveness/restart), A-CONS-6 (weak
subjectivity), HALT-02's restart premise; D6's "30 minutes is normal" is in direct tension with
`WS_max`.

**Evidence.** MEM-11(2) (raw lines 498–503); MEM-12(3),(4) (lines 530–537); MEM-05(4); HALT-01/HALT-02
(06-recovery lines 49–90); D6; 09 PARAM (T_PROOF_ENVELOPE = 1800, decided).

---

### ECO-09 — Activation is formally FIFO but not actually fair or bounded: the anti-front-running claim is false, and `A_max` is an ineffective per-version cap — **High**
**Rationale.** MEM-03(2) promises that "no fee, stake size, key attribute, entity or reputation can
reorder, delay or front-run another entry", but the ordering key is L1 inclusion order, which the L1
fee market and block builders auction; `A_max` is defined **per set version** while set versions are
permissionlessly creatable (MEM-09(1)), so the EIP-7514-style churn bound the rule cites does not
bound the activation rate — and if it did, MEM-03(4) admits an entry can wait forever.

**Exact rule / missing rule.** MEM-03(2),(3),(4); MEM-09(1); missing: a statement that FIFO is only as
fair as L1 inclusion (or a commit-reveal/queue-slot mechanism), a definition of the number of set
versions per epoch, and an upper bound on time-to-activation.

**Assumptions / preconditions.** Entry is an L1 transaction ordered by L1 builders/proposers
(A-L1-1); `commitSet()` "may be called by anyone" and takes no arguments (MEM-09(1)); `A_max`
[unmeasured].

**Attack trace / counterexample (derived, illustrative values [unmeasured]).**
(a) *Front-running / queue capture.* An adversary that wants to delay a target bonds `A_max` entries
with valid keys immediately before the target's bonding transaction, paying L1 priority fees to be
earlier in the block and/or in an earlier block. The target's FIFO key is strictly later; with
`A_max = 8` slots served per version [illustrative, the EIP-7514 precedent is 8/epoch] and 100
entries competing per epoch, the head is served in ≥ 12.5 epochs ≈ **6.25 h** at 30-min epochs, during
which the target's stake is bonded, earns no reward and is not slashable (MEM-03(4)). The adversary's
capital is recoverable via `cancelActivation()` after `D_withdraw`; its only cost is the time value
of `A_max · S_min` plus gas [unmeasured]. The claim in MEM-03(2) is false as written.
(b) *The cap does not cap.* Set versions are append-only and permissionless; each serves `A_max` from
the head. Nothing limits versions per epoch (MEM-09(1) vs CONS-13(4), which limits only the commitment
*for a given epoch*), so any keeper can call `commitSet()` repeatedly and activate the queue at L1 gas
speed — `A_max` bounds nothing; alternatively, if an unstated one-version-per-epoch rule is intended,
the cap must be stated as per-epoch and the EIP-7514 comparison corrected. Either reading leaves
set-growth and time-to-activation undefined. Growth is also unbounded above (MEM-03(1): "no cap on the
number of participants"), and the per-batch guest cost is O(n) Ed25519 verifications (04-architecture
§2) plus O(n) per-epoch L1 stake-ledger writes (ECO-14) — costs not in the reward budget.

**Inside / outside the fault model.** Inside: T-13 griefing on permissionless entry is an enumerated
threat, and the spec claims to defend it ("no third party can cancel, reorder or consume another
entry's position").

**Attacker resources and cost.** `A_max · S_min` TAIKO (recoverable), L1 gas and priority fees
[unmeasured]; if A_max is small this is a cheap, reversible grief.

**Harm and requirement/decision affected.** R1 (permissionless entry: formal, not effective), R13
(undefined rules for `A_max` scope and version rate), D1's cadence claim is unaffected but the
liveness of set growth is.

**Evidence.** MEM-03(2),(3),(4) (raw lines 132–159); lifecycle rows 1–2 (lines 212–216); MEM-09(1)
(lines 427–431); CONS-13(3),(4) (02-consensus lines 368–376); `research/economics-raw.md` §2.5
(EIP-7514 as "activation-churn cap", 8 validators/**epoch**).

---

### ECO-10 — Rewards are unconditional pro-rata to stake; the only claimed downtime consequence cites a penalty ECON-05 does not define — **High**
**Rationale.** ECON-02(5) pays "pro rata to effective stake" per period with no duty predicate, while
ECON-04(5) makes being offline/late explicitly not an offence; the system-model page nonetheless says
"downtime penalties are ECON-05's", and ECON-05 defines no downtime penalty — so either offline
validators are paid, or the eligibility rule is left to the implementer.

**Exact rule / missing rule.** ECON-02(5); ECON-04(1),(5); ECON-05; `spec/01-system-model.html` §9 table
("No reward for missed duties; downtime penalties are ECON-05's"). Missing: the reward-eligibility
predicate (participation threshold, per-epoch attestation, pro-rata among performers) and any negative
incentive for non-participation.

**Assumptions / preconditions.** LIVE-01(L1) requires >2/3 online — an *assumption*, not an incentive;
rewards are funded per period from the pool; `n` is unbounded (ECO-09).

**Attack trace / counterexample.** A validator joins, holds a key, and never runs the node. Per
ECON-04(5) it commits no offence; per ECON-02(5) it is paid pro rata to its effective stake unless a
duty predicate exists (none is normative); per 01 §9 no reward should accrue — a direct contradiction.
Economically the dominant strategy for a rational small operator is to minimise `C_op` (go offline)
and collect stake-proportional rewards, degrading the online fraction that LIVE-01(L1) needs. With
free entry and unbounded `n`, offline weight dilutes quorum: quorum is >2/3 of **TotalVP**
(CONS-03), so offline weight linearly erodes the achievable margin until the chain halts — an outcome
the spec classes as disclosure ("A minority outage halts the chain", LIM-01) but which the reward rule
actively encourages rather than deters. A cartel can force this at the cost of `S_min` per entry with
**no slashing risk** (offline is not slashable), which is strictly cheaper than the equivocation route
that risks 100 % confiscation.

**Inside / outside the fault model.** Inside: rational, non-Byzantine validators; no assumption is
violated. The cartel version is the disclosed "≥1/3 can halt" limitation, but the *free-rider* version
needs no cartel.

**Attacker resources and cost.** `S_min` per offline entry (recoverable via MEM-05) and forgone
rewards only if the eligibility rule exists; otherwise zero.

**Harm and requirement/decision affected.** R6 (conditional liveness), R11 (penalties), D1's 2 s cadence
claim under permissionless global membership (F3) becomes an incentive problem, R14 (learn material).

**Evidence.** ECON-02(5) (raw lines 122–126); ECON-04(1),(5) (lines 164–171, 221–226); ECON-05;
`spec/01-system-model.html` §9 "What happens when a validator fails" (raw line 556); LIM-01
(10-assurance line 149).

---

### ECO-11 — `remaining_exposure(v,e)` is undefined, and the immediate/correlated debit sequencing and residual accounting are unspecified — **Medium**
**Rationale.** The charge formula and the exposure gate use quantities the specification never defines,
so the implementer must invent the per-offence accounting that decides how much is actually collected.

**Exact rule / missing rule.** ECON-05(2) formula line `charge = min(P(v,e), bonded(v), remaining_exposure(v,e))`;
ECON-05(4),(5); MEM-06(2) defines only `max_exposure(v)`. Missing: a definition of `remaining_exposure`,
a rule for reserving the not-yet-computed correlated component against the immediate debit, and the
per-`(v,e)` debit accumulator.

**Assumptions / preconditions.** `IMM_FRAC` is debited at evidence time; `c(f)` is unknown until
`evidenceClose(e)`; the total is capped at `SlashBase`.

**Attack trace / counterexample (derived).** `IMM_FRAC = 0.5`, `SlashBase = S`. Immediate debit 0.5·S
at evidence time. Later `f` is small, `c = 0.1`; the correct residual is 0.1·S, but a naive
implementation that recomputes `P = min(S·0.6,S) = 0.6·S` and debits `P` again over-collects by 0.5·S
(bounded only by the balance); an implementation that treats the immediate debit as consuming the cap
under-collects. Either way the outcome depends on an invented rule. A parallel ambiguity exists across
epochs: `max_exposure` is a **max**, not a sum, so an entry with constant stake S that offends in k
epochs holds S but faces up to k·S of charges; ECON-08(3) resolves this by recording remainders as
unapplied — i.e. the marginal cost of additional offence epochs is zero once the first charge lands.

**Inside / outside the fault model.** Inside (a rational offender exploits the under-collection);
the over-collection branch harms honest key-duplication victims (ECON-05(7)).

**Attacker resources and cost.** An entry at `S`; no additional capital for the 2nd…k-th offence epoch.

**Harm and requirement/decision affected.** R11 (penalty determinism), R13, ECON-05's saturation claim,
A-ECO-1.

**Evidence.** ECON-05(2)-(5) (raw lines 239–264); ECON-08(3) (lines 357–361); MEM-06(1),(2) (lines
315–323); ECON-01(3) INV-C (lines 48–58).

---

### ECO-12 — Anti-concentration argument has an internal contradiction and a price-dependent hole — **Medium**
**Rationale.** (a) The specification claims concentration is constrained by "rewards that are concave in
stake", but its own reward rule pays pro rata (linear); (b) the cap-overhead ratio
`k_op/(C·P(t)·(1+σ(t)))` grows without bound as `P(t)` falls, so "never cancels the dominant term" is
false exactly in the collapse regime the same document treats as decisive.

**Exact rule / missing rule.** ECON-10(1),(4),(5); MEM-10(3),(5); ECON-02(5). Missing: either a concave
reward schedule (and its rule) or deletion of the concavity claim; and a statement of the price regime
in which the cap arithmetic holds.

**Assumptions / preconditions.** `k_op`, `C`, `P(t)`, `σ(t)` [unmeasured]; v1 has **no** cap
(MEM-10(1)), so the argument is about a mechanism the design does not use.

**Attack trace / counterexample (derived).** (a) ECON-10(5)(b) says the constraining factors include
"rewards that are concave in stake, so the marginal token is worth less to a large holder"; ECON-02(5)
says payouts are "pro rata to effective stake" — linearithmic, not concave. The claim is unsupported by
the rule. (b) Cap overhead per unit acquired = `k_op/(C·P·(1+σ))`. ECON-10(3) itself prices the attack
in dollars, and 07 §"If the price falls" states attack cost falls roughly proportionally. Then for any
fixed `k_op, C, σ`, there is a price `P* = k_op/(C(1+σ))` below which the cap overhead **exceeds** the
acquisition cost per token — the cap becomes the binding constraint, contradicting "never cancels the
dominant term". With `k_op` and `C` unmeasured, no one can state where that regime begins, but the
claim is asserted unconditionally and tagged **Proven**.

**Inside / outside the fault model.** The consequence (concentration unbounded) is F2-adjacent
(A-ECO-1), but the defect is a claim-level contradiction.

**Attacker resources and cost.** None; the finding is about the truth of a published guarantee.

**Harm and requirement/decision affected.** R14 (claims must match), R13 (implementer cannot tell
whether to add a concave schedule), INV-03's neighbourhood, ECON-10/MEM-10's "Proven" tags.

**Evidence.** ECON-10(1),(4),(5) (raw lines 413–457); MEM-10(3),(5) (lines 466–483); ECON-02(5);
07 §"If the price falls" (lines 541–546); `research/economics-raw.md` §2.7 points 1–6 (the source
argument is ANALYTICAL and conditions on a cap that v1 does not have).

---

### ECO-13 — `MEV_captured` is budgeted as revenue with no capture mechanism, and ordering/reordering is explicitly not an offence — **Medium**
**Rationale.** The funding identity counts MEV the protocol "actually retains", but no rule creates a
capture mechanism (no PBS, auction, sealed bid or fee rule), while ECON-04(5) says ordering/reordering
of included transactions "is not an offence at all" — so the protocol cannot prevent a proposer from
leaking that value privately.

**Exact rule / missing rule.** ECON-02(1) term `MEV_captured`; ECON-04(5); CONS-06 (deterministic,
publicly predictable proposer). Missing: a rule that routes ordering value to the pool (or an explicit
statement that `MEV_captured` is expected to be 0).

**Assumptions / preconditions.** Order is determined by L2 PoS (D4); the proposer is knowable far in
advance (CONS-06); the proposer builds or relays the block.

**Attack trace / counterexample.** A proposer sells pre-confirmation ordering privately; the protocol
has no offence and no fee to capture. The budget term is then 0 (or negative if the protocol tries to
compete for order flow), while ECON-12's `n_max_fundable` assumes it can be large. An implementer must
invent a mechanism or write the term off — either way a security-relevant budget input is unresolved.

**Inside / outside the fault model.** Inside (T-6 bribery/MEV), but the harm is budget overstatement
rather than a break.

**Attacker resources and cost.** The proposer slot itself (obtainable with stake, CONS-06).

**Harm and requirement/decision affected.** R13, R11's funding, ECON-12's sustainability claim,
A-ECO-1 (denominator of the "profit" side is partly the protocol's own revenue).

**Evidence.** ECON-02(1) (raw line 91–99); ECON-04(5) (lines 221–226); CONS-06 (02-consensus lines
181–210); `research/economics-raw.md` §2.9 (MEV_captured UNMEASURED, "fraction … retained … vs
leaked").

---

### ECO-14 — Per-epoch `SlashBase` retention is an unbounded, unpriced L1 state and gas cost not present in the funding identity — **Medium**
**Rationale.** ECON-01(4) requires the ledger to retain `SlashBase(v,e)` for every epoch an entry
appears in; at one set version per epoch this is Θ(n) new storage slots per epoch, a recurring L1 cost
the budget identity's `C_L1_verify` ("per batch") does not include, and the rule does not say whether
the value is stored or re-proved from the set root.

**Exact rule / missing rule.** ECON-01(4) and the interface row `slashBase[e] mapping(uint64 ⇒ uint256)`;
ECON-02(1) cost terms; MEM-06(1). Missing: the representation (stored vs Merkle-proved against `R_k`),
who pays the gas, and the cost term in the budget.

**Assumptions / preconditions.** Set versions per epoch ≈ 1 (CONS-13(3)); epochs = 30 min ⇒ 48/day,
17,520/yr [derived]; n unbounded (ECO-09).

**Attack trace / counterexample (derived).** One zero→non-zero SSTORE ≈ 20,000 gas plus ~2,100 cold
access (standard EVM constants, not in this project's source register). For n = 1,000 validators:
≈22.1 M gas per epoch; ×48 epochs/day ≈ **1.06 × 10⁹ gas/day** [derived], plus the later clears
(refunds capped at 4,800 gas/slot, EIP-3529). This is a protocol-level cost proportional to n that
appears in no term of ECON-02(1) and grows if `A_max` fails to bound set growth (ECO-09). If instead
`SlashBase` is proved from the published entry list and `R_k`, the rule must say so and the proof's
verification cost must be priced — the implementer currently chooses.

**Inside / outside the fault model.** Not an attack; a costing/feasibility gap.

**Attacker resources and cost.** An adversary can inflate n (entry is cheap and permissionless) to
raise the protocol's per-epoch L1 cost, i.e. a griefing vector against the budget; cost = `S_min` per
entry, recoverable.

**Harm and requirement/decision affected.** R13, ECON-12's budget identity (understated cost),
HALT-03/LIVE-03 throughput assumptions, "Minimal L1 cost" objective (`tokenomics_objective_metrics.md:21`).

**Evidence.** ECON-01(3),(4) and interface table (raw lines 48–86); MEM-06(1) (lines 315–319);
ECON-02(1) (line 98); ECON-12(1) (lines 489–494); CONS-13(1) (02-consensus lines 361–367).

---

### ECO-15 — The validator payout rule is a dangling reference: ECON-02(5) defers "the allocation of inflow … and the exact claim interface" to L1-11, which defines only the prover ledger — **High**
**Rationale.** ECON-02(5) says the allocation across role classes and the claim interface are
"L1-11 and are not restated here", but L1-11 contains no allocation and no validator claim path; ROLE-01(d)
requires validator payment "in the same L1 transaction that accepts a batch", which is an O(n) gas
operation with no mechanism specified.

**Exact rule / missing rule.** ECON-02(5); `spec/04-l1-integration.html` L1-11; ROLE-01(d). Missing: the
split of inflow between validators/provers/reporters and the validator claim/distribution mechanism.

**Assumptions / preconditions.** Every accepted batch pays validators (ROLE-01(d)); n is unbounded
(ECO-09); the reward pool is a single L1 balance (L1-11).

**Attack trace / counterexample (derived).** If every batch's `land` pays all n validators, gas per
batch grows Θ(n); for n = 1,000 and a per-recipient transfer of ≥ 2,300 gas (EVM constant) plus
accounting, that is ≥ 2.3 M gas/batch before any logic — comparable to the proof-verification gas the
same page calls unmeasured, and it scales with the parameter `A_max` fails to bound. A pull-based
claim is the obvious alternative, and the specification neither requires it nor describes its
accounting (per-epoch, per-batch, pro-rata weights) or its interaction with `max_exposure` and the
exposure gate. Also unstated: how the "period" of ECON-02(1)/ECON-12 is defined and when it is closed.

**Inside / outside the fault model.** Not an attack; a missing implementer rule on the payout path.

**Attacker resources and cost.** None; harm is un-implementable/over-costed payouts.

**Harm and requirement/decision affected.** R13 (explicitly), R1 (validators must be able to be paid
to remain), R11, ECON-12's budget.

**Evidence.** ECON-02(5) (raw lines 122–126); L1-11 (04-l1-integration lines 305–321, which mentions only
`proverReward`); ROLE-01(d) (01-system-model lines 362–366).

---

### ECO-16 — No normative rule detects or acts on A-ECO-1 failure; HALT-01's triggers omit security-budget collapse — **Medium**
**Rationale.** A-ECO-1 is a safety-relevant assumption that "can fail with no rule change"; the
specification's stated response is "monitor and halt", but that response exists only as explanatory
prose, and none of HALT-01's enumerated triggers, LIVE-02's backpressure triggers, or any parameter
rule conditions operation on the security budget.

**Exact rule / missing rule.** 07 §"TAIKO price volatility" ("(d) monitor and halt"); A-ECO-1;
HALT-01(a)–(e); LIVE-01/LIVE-02; ECON-09(2) (`Λ` unmeasured, no owner). Missing: a normative
monitor-and-halt rule (what quantity is observed, by whom, at what threshold, with what effect), and a
launch gate that fixes `Λ` and the derived break-even price.

**Assumptions / preconditions.** `P(t)`, `σ(t)`, `EV_extractable`, `OV_option`, `Λ` [unmeasured];
HALT-01 is the only halt authority and is a local validator action.

**Attack trace / counterexample.** TAIKO falls; `S_total` declines (ECO-07 makes the decline abrupt);
the ratio `S_total/(Λ·(EV+OV))` crosses below secure levels. Every rule remains satisfiable, no
validator has a rule-legal reason to halt under HALT-01, and the chain continues. The "monitor and
halt" sentence is not implementable by any participant because no rule names the signal or the actor.
This is exactly the silent-degradation failure the spec says it is avoiding (ECON-12(3), ECON-05(6)).

**Inside / outside the fault model.** The failure is F2 (safety assumption) but the *absence of the
disclosed response* is a specification defect, not an assumption failure.

**Attacker resources and cost.** None; the harm is a security claim that degrades without a rule.

**Harm and requirement/decision affected.** R6, R11/A-ECO-1, GEN-04's evidence discipline (an "Open"
item with no owner), ECON-09(2)'s `Λ`.

**Evidence.** 07 §"TAIKO price volatility" (raw lines 519–551); ECON-05(6) (lines 265–270); ECON-09(2)
(lines 393–397); HALT-01 (06-recovery lines 49–70); LIVE-01/LIVE-02 (10-assurance lines 78–114);
PARAM-03 (09-parameters lines 96–119, which lists market data but not `Λ`).

---

### ECO-17 — The "derived price at which the design stops being secure" is claimed to exist but is nowhere derived — **Low**
**Rationale.** ECON-05(6) states in the present tense that "the specification states the derived price
at which the design stops being secure"; 07 §"TAIKO price volatility" repeats it, but no rule derives,
records or requires such a price.

**Exact rule / missing rule.** ECON-05(6); 07 §volatility; ECON-10(5); PARAM-03. Missing: the derived
price and its recomputation rule.

**Assumptions / preconditions.** All inputs unmeasured; `Λ` has no owner.

**Attack trace / counterexample.** A reader checking the claim finds a formula and an instruction, not a
number or a rule; R14's consistency claim (learning material must state unresolved questions) cannot
be satisfied for this item because the status is not represented as Open in PARAM-01/03.

**Fault model.** Outside (documentation defect).

**Attacker resources and cost.** None.

**Harm and requirement/decision affected.** R14, GEN-04, reviewability (Medium-adjacent).

**Evidence.** ECON-05(6) (raw lines 265–270); 07 §volatility (lines 535–540); PARAM-03.

---

### ECO-18 — Evidence-tag and cross-reference defects in the economic pages — **Low**
**Rationale.** Several claims carry a "Proven" pill while containing unmeasured, untyped or
self-contradictory content, and one cross-reference points at a penalty that does not exist.

**Exact rule / missing rule.** ECON-02 is tagged **Proven** (raw line 134) though clause (1) is
untyped and clause (3) is unsatisfiable as written (ECO-01); ECON-09 is tagged **Proven** for an
inequality whose denominator can be ≤ 0; `spec/01-system-model.html` line 556 says "downtime penalties
are ECON-05's" while ECON-04(5) excludes downtime and ECON-05 defines no such penalty; ECON-04's
omission row and ECON-07(1) give two different window-open rules (ECO-05).

**Assumptions / preconditions.** As stated.

**Attack trace / counterexample.** A reviewer or implementer trusting the tags will treat an
assumption-laden identity as proven and may not re-derive the window anchor or the downtime rule.

**Fault model.** Outside.

**Attacker resources and cost.** None.

**Harm and requirement/decision affected.** R13/R14, GEN-04 (evidence tags).

**Evidence.** As cited inline.

---

### ECO-19 — No top-up path: a slash below `S_min` forcibly ejects an entry and forces a new bond, key and FIFO position — **Low**
**Rationale.** The custody interface admits no way to increase an existing entry's stake; lifecycle
transition 7 removes an entry whose remaining `effStake` falls below `S_min` and re-enters it into the
exit path, so the smallest operators (those nearest the floor) are the most fragile.

**Exact rule / missing rule.** MEM-03 custody sketch (`bond` creates an entry, "appends one FIFO
activation entry"); lifecycle transition 7; MEM-05; MEM-07(6) (one-shot keys). Missing: an explicit
top-up/partial-slash-recovery path or a statement that none exists.

**Assumptions / preconditions.** `IMM_FRAC ≥ 0` (ECON-05(1)); `S_min` unmeasured; re-entry is a new
bond, new key and new FIFO position.

**Attack trace / counterexample (derived).** An entry bonded exactly at `S_min` that receives any
non-zero immediate penalty falls below the floor and is ejected at the next set version; its stake is
locked through `D_withdraw`, it must bind a new Ed25519 key (the old is retired permanently,
MEM-07(6)), and it re-queues behind all pending activations (ECO-09). The same slash on an operator
holding 10× `S_min` is absorbed. This is a structural cost advantage for large operators, in tension
with the permissionless-entry claim.

**Fault model.** Inside (a single small penalty is enough; no Byzantine assumption needed).

**Attacker resources and cost.** None; the harm is disproportionate ejection.

**Harm and requirement/decision affected.** R1, R13, ECON-09's participation goal, ECON-10's
"what actually constrains concentration" (this *increases* it).

**Evidence.** MEM-03 §1.1 table (raw lines 110–112); lifecycle row 7 (lines 228–230); MEM-05;
MEM-07(6) (lines 364–366); ECON-05(1).

---

## Answers

### E1 — Can the protocol fund its own security without minting and without assuming appreciation?
**No, not as specified, and the specification cannot currently demonstrate that it can.** ECON-02(2)
denominates rewards in TAIKO; ECON-02(1)'s only funding identity is a sum of ETH-denominated fee,
MEV and cost terms plus an explicitly dual-currency bounded subsidy, with no TAIKO inflow term and no
ETH→TAIKO conversion rule; L1-11's "reward ledger" receives `msg.value` (ETH) and "L2 fee revenue"
for which no L2→L1 transfer path exists anywhere. ECON-10(5) forbids the price constant that would be
needed to evaluate the mixed identity, and ECON-02(2) forbids the appreciation assumption that would
make a token-denominated reserve sufficient. The condition under which it cannot is therefore twofold
and both hold: **(a) the identity cannot be evaluated or satisfied in the reward asset for any positive
TAIKO reward** (no inflow, no conversion, forbidden price), and **(b) even in the ETH reading, the
"fee-only region" test of ECON-12 — `NetFeeRevenue ≥ Budget(n)` — is uncomputable because
`NetFeeRevenue` is ETH, `Budget(n)` is fiat-over-TAIKO via `ρ_capital·S`, and the only bridge between
them, `P(t)`, is prohibited.** Operationally, the fee-only region is reached only if the
price-converted value of realised fees plus captured MEV covers `n·(C_op + ρ_capital·S)` at the
prevailing price, with the subsidy bounded and expiring — and no rule computes, monitors or acts on
that condition (ECO-16).

### E2 — Is the withdrawal-delay derivation sufficient to make late slashing possible, and where exactly does it break?
**The construction is sound in shape but the derivation is not sufficient, and it breaks at the window
anchor.** The three-part defence (stake-at-offence-time, exposure-gated withdrawal, delay longer than
the evidence pipeline) is the right shape, and the *gate* — MEM-05(3)(b) requiring every epoch's window
to have closed before withdrawal — is what actually closes the exit race, not the length of
`D_withdraw`. It breaks in three concrete places. **(1) Anchor mismatch.** ECON-07(1) computes
`evidenceClose(e)` from the L1 block that committed epoch `e`'s set version, which CONS-13(3)/MEM-09(2)
place inside epoch `e−1`; the offence can occur at the last block of `e`, ≈1,800–3,600 s later
[derived: L = 900 × 2 s]. So the time actually available is `W_evidence − [1800,3600] s − finality`,
while ECON-07(4)'s lower bounds are written as `T_detect + T_evidence_submit` from the offence.
Following the rule as written produces a **negative** window for late-epoch offences, and the spec's own
research input says the clock must start at the offence (economics-raw §2.5) — the rule and its evidence
disagree. **(2) Two open anchors.** The omission/censorship offence opens its window at L1 acceptance of
the batch but closes it at `evidenceClose(e)`; because D5 makes acceptance wait for the proof envelope
(≤1,800 s), plus inclusion and finality, an offence near the end of an epoch needs
`W_evidence ≳ 1.5–2 h` to be provable at all, while ECON-07(4) requires only `T_detect + T_evidence_submit`.
**(3) Per-epoch, not per-offence, collection.** The correlated charge is computed per `(e,c)`, the
charge is capped by `SlashBase`, and ECON-08(3) records the remainder as unapplied, so the aggregate
penalty for a multi-epoch offence history is bounded by the retained balance rather than by the sum of
the epochs' SlashBases. The fix is a single rule: define the window **from the offence** (or, for
settlement-dependent offences, from batch acceptance) and add `E_epoch` + lookahead +
`T_proof_bound` + `T_L1_include(p)` + `T_L1_final` to every lower bound, then re-derive
`D_withdraw` and `WS_max` accordingly.

### E3 — Is permissionless entry genuinely open at the proposed economics, or only formally open?
**Only formally open; economically it is closed at both ends and gated in the middle.** Formally,
MEM-03(1) is exemplary: no allowlist, no approval, no identity requirement, no cap. Economically:
**(i) the gate is not fixed** — the sole predicate `amount ≥ S_min` depends on `S_min`, which ECON-09(1)
says may not exist as a finite number when `r_gross ≤ ρ_ops`, and its derivation silently needs a
TAIKO price the spec forbids assuming (ECO-02, ECO-03); **(ii) the floor excludes the median
participant or the budget excludes the resulting `n`** — ECON-09(3) makes R1 conditional on
`S_min ≤ S_affordable`, and ECON-12(2) shows lowering `S_min` raises the reward bill linearly in `n`
while revenue does not scale with `n`; there is no demonstrated feasible point; **(iii) the queue is
not fair and not bounded** — FIFO is FIFO over L1 inclusion order, which priority fees and builders
control, so the "no fee can front-run" claim is false, and MEM-03(4) admits an entry can remain
unactivated, unrewarded and unslashable indefinitely while its capital is bonded (ECO-09); **(iv) the
real cost stack is unmeasured and non-trivial** — L2 consensus + execution client, a self-operated L1
client for SYS-02 finality evidence, proving-adjacent bandwidth/storage, L1 gas for bond/exit/evidence,
key custody for a one-shot Ed25519 key, and a `D_withdraw` lockup whose length is derived from the
whole pipeline; **(v) penalties fall hardest on the smallest operators** — the correlated honest-mistake
tail, permanent key retirement, no top-up path and forced re-queueing all scale with how close an
operator runs to `S_min` (ECO-10, ECO-19). The design therefore does not *exclude* small participants
by rule; it makes their expected economics dominated by large, professionally operated ones, which is
the same outcome with better paperwork.

---

## Numbers register used above (all arithmetic on decided/sourced inputs unless marked)

| Quantity | Value / relation | Tag |
|---|---|---|
| L2 cadence | 2 s | sourced (D1) |
| Epoch length `L` | 900 heights = 1,800 s | derived (CONS-13(1), D1) |
| D6 proving envelope `T_proof_bound` | ≤ 1,800 s | decided/sourced (D6, PARAM) |
| Set versions at 1/epoch | 48/day, 17,520/yr | derived |
| `WS_max` | ≤ `T_proof_bound + M − M_ws` ≈ < 30 min + M | derived (MEM-11(2) + MEM-05(4)) |
| Late-epoch window loss | `W_evidence − [1800, 3600] s − finality` | derived |
| Omission window lower bound needed | ≳ 1.5–2 h + inclusion/finality | derived (unmeasured inclusion/finality) |
| SlashBase storage cost, n = 1,000 | ≈ 22.1 M gas/epoch ≈ 1.06 × 10⁹ gas/day | derived (EVM SSTORE constants; balances illustrative) |
| Bounty self-report example | f = 0.01, c = 0.03, P = 4,000 TAIKO on S = 100,000, n = 100, IMM = 0.01; net 0 at reporterPpm = 10⁶ | derived on illustrative [unmeasured] inputs |
| Activation wait | 100 entries/epoch at `A_max` = 8 ⇒ ≥ 12.5 epochs ≈ 6.25 h | derived on illustrative [unmeasured] `A_max` |
| TAIKO price, float, depth, σ(t), Λ, C_op, ρ_ops, ρ_capital, S_affordable, EV, OV | no value in the project | unmeasured |
