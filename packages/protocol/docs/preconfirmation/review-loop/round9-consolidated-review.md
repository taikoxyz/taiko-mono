# Round 9 — Consolidated Review and v10 Dispositions

**This document merges the two independent round-9 reviews of the based-preconfirmation
redesign (PR #22034) into one report**, deduplicated finding-by-finding, and records how
draft **v10** of [`../redesign-proposal.md`](../redesign-proposal.md) addressed each finding.
The two source reports it replaces:

1. **Adversarial security review** (`PR22034-preconf-redesign-adversarial-review.md`) —
   reviewer stance: independent adversary (auction winner, successor, Sybil standby,
   permissionless recoverer, filler, prover cartel, L1 builder coalition) attempting to
   (1) pause liveness, (2) steal funds, (3) reach an invalid/unrecoverable state. Findings
   labeled **A1–A6** (liveness), **B1–B3** (funds), **C1–C3** (invalid state), **D1–D7**
   (verification-suite gaps).
2. **Comparative implementation-readiness review** (`comparative-analysis-report.html`) —
   an honest comparison of the redesign against the deployed `PreconfWhitelist` across
   security, liveness, decentralization, UX, cost, governance, verification evidence, and
   migration risk. Blocking workstreams labeled **cB1–cB7**, findings **cF1–cF9**, plus a
   claims-narrowing table, checker-confidence assessment, adoption path, and scorecard.

**Targets reviewed:** `redesign-proposal.md` v9 @ `a2c2b7c29`, `simulation/model_checker.py`,
`simulation/RESULTS.md`, `status-quo.md`, the deployed `PreconfWhitelist`/Shasta baseline, and
the eight prior review rounds. Both reviews re-ran the checker and reproduced its claimed
results before attacking it. **Dispositions in this document refer to v10** (same PR lineage;
see the proposal header changelog and Appendix B round-9 table).

---

## 1. Combined verdict

**Security (adversarial pass).** No *confirmed* exploit pauses liveness, steals funds, or
corrupts state *given the design's stated assumptions*. The v1→v9 lineage closed the
historical holes (no-evidence stalls, hidden-tail reorgs, unprovable PUBLISHED poison,
poke-dependent liability, double-κ finality, brake self-triggering), and the state machine
held up under bounded exhaustive model checking including permanent proving outages.
**However**, v9's two hardest load-bearing claims rested on mechanisms that were **not
specified at all**, and one theft-deterrence claim was **internally inconsistent**. An
implementer acting on v9 as written could plausibly have built a system in which a griefer
slashes every honest seat-holder for pennies (A2), the claimed "parent final at `Γc+κ`"
boundary does not exist on-chain (A1), or an equivocator nets ≈ (L−1) epochs of MEV against a
1-epoch bond (B1). **v10 pins all three as normative mechanisms** (see §3 below).

**Readiness (comparative pass).** The redesign is a meaningful protocol-security improvement
over today's whitelist on the axes it targets — objective faults and collateral instead of
reputation-only enforcement, a permissionless recovery path for the oldest gap, structural
forced inclusion, a far more rigorous state machine. It is **not an across-the-board
upgrade**: the whitelist is centralized but small, understandable, inexpensive, and already
integrated with two client stacks, while the redesign buys its properties with a new auction,
multi-tranche dual-asset collateral, per-epoch commitments/proofs/certificates, an append-only
evidence spine, L2→L1 safety adjudication, forced-item lifecycle state, and several
degradation modes — and Phase A pays most of that complexity while still allowlisted.
**Recommendation (unchanged by v10): accept the PR as a strong design and decision record;
do not treat merge as authorization for a full replacement.** Implement incrementally behind
a guarded, bounded Phase-A pilot with a tested whitelist rollback (now normative — §13-S.14),
and hold the production gates of §6 below.

**Implementation-readiness status: NOT READY — by design-record intent.** v10 closes the
round-9 *mechanism* blockers (the design no longer requires an implementer to invent
consensus-critical behavior for the decision path, equivocation economics, cancellation
cutoff, forced membership, or bridge refunds). What remains open is exactly what §13-S has
always tracked: the executable Phase-A implementation specification (interfaces, storage,
events, proof public inputs, wire formats, conformance vectors, migration/rollback
procedures) plus parameter derivations. Closing those is implementation-phase work, gated and
enumerated — not missing mechanism.

---

## 2. Severity roll-up (as found against v9)

| Source | Critical/High | Medium | Low / notes | Verification-suite |
| --- | --- | --- | --- | --- |
| Adversarial pass | 3 (A1, A2, B1) | 5 (A3, A4, A5, B2, C1) | 4 (A6, B3, C2, C3) | 7 (D1–D7) |
| Comparative pass | 7 blockers (cB1–cB7) + 5 high findings (cF1–cF5) | 4 (cF6–cF9) | claims-narrowing table | cB5 |

Overlaps (same defect, two lenses): B1≈cB2, A5≈cB3, F2≈cB4 (cancellation), A6/C3≈cF5
(outage attribution), D1–D7≈cB5 (checker validity), A4≈cF3 (outage liveness), F1≈cF6
(concentration). The unified catalog below merges them.

---

## 3. Unified findings and v10 dispositions

Severities are as assessed against v9. **Status** is the v10 disposition: **Closed** (normative
mechanism/text now in the proposal), **Closed-in-checker** (fixed in the verification
artifact), **Gated** (folded into a normative Phase-A/Phase-B gate — correct closure for an
empirical or implementation-phase item), or **Accepted** (a stated, deliberate property).

### 3.1 Liveness / decision path

**R9-1 [HIGH] — The `D+κ` "bytes on L1" decision had no specified evaluation mechanism**
(A1). L1 contracts cannot read blob data; EIP-4788 exposes beacon-block roots while blob KZG
commitments live in the beacon-block body — so the design's single load-bearing rule ("the
EBC is valid only if every referenced byte is on L1 at `D+κ`") was not evaluable as written,
and the two obvious implementations (decision-time check vs seal-time check) have divergent
security consequences: the seal-time variant silently reopens the double-κ parent-flip hole
that v6–v9 closed.
**Status: Closed.** v10 §5.2 defines the **availability certificate (AC)**: the check is
*commitment inclusion* — permissionless, sender-free SSZ generalized-index proofs (against
EIP-4788 roots) that every referenced blob KZG commitment was in a canonical beacon block at
or before `D+κ`, accepted within a bounded `R`-slot resolution window; **CONTENT materializes
on AC acceptance, EMPTY by `R`-timeout** (absence never needs proving — the same I2
discipline as fault maturity). The seal circuit binds bytes to the certified commitments by
KZG opening, so "bytes on L1" is the conjunction of the two halves. Cost attribution is
stated (EMPTY costs nothing; the AC is paid by its interested submitter and is constructible
by anyone from public beacon data); the decision's information-final (`D+κ`) vs
contract-legible (≤ `+R`) instants are distinguished; §3's timeline and parameter table carry
the `resolve` step and `R`. Exact proof format, reorg semantics, and gas budget are
Phase-A-blocking §13-S.15.

**R9-2 [HIGH] — The EBC one-shot could be weaponized to slash honest holders every epoch**
(A2). v9 said "the first-landed artifact wins… any second distinct artifact is invalid"
without an acceptance predicate: if first-landed consumed the one-shot before signature
validation, a griefer submits one well-formed-but-unsigned EBC per epoch and the holder's
real EBC becomes the invalid "second artifact" — EMPTY-PENDING, slash, termination, for one
L1 transaction per epoch.
**Status: Closed.** v10 §3.1/§5.1: acceptance is a normative predicate — well-formed **and**
validly signed by the tenure's *registered* commitment keys **and** targeting an unconsumed
one-shot. Non-conforming submissions are **inert no-ops that consume nothing**; the one-shot
is consumed only by the first *accepted* artifact; byte-identical re-lands are no-ops; and a
second *distinct accepted* EBC is on-chain equivocation evidence (→ R9-4).

**R9-3 [MEDIUM] — `K_empty` had no on-chain computation path** (A3). v9 defined it over
post-derivation output, but that predicate exists only inside derivation/proofs and the
explicit-empty seal is proof-free — no artifact carries the count to L1; termination on it
was not mechanically implementable.
**Status: Closed.** v10 §5.4 redefines `K_empty` on the **L1-legible** form — consecutive
epochs with **no accepted content-bearing EBC** (absent / explicit-empty / forced-only), a
pure function of the record spine — and states its two honest weaknesses (stuffing-evadable
at blob-fee cost; Sybil-resettable in spirit), which is exactly why it stays a *nuisance
bound* while `T_max` remains the binding bound.

**R9-4 [HIGH] — "One epoch is the exposure" contradicted the design's own adjudication
latency; the safety tranche had no funded enforcement path; verdicts were unbounded**
(B1 + B2 + B3; = cB2). v9 sized `L_safety` against one epoch's MEV while conceding
adjudication might be slower; no accusation-time suspension exists, so an equivocator nets
≈ (latency−1) epochs of MEV against a 1× bond; the safety slash was fully burned with no
accuser reward (rational actors never adjudicate); and one slow/bogus verdict could extend an
honest ex-holder's withdrawal lockup indefinitely.
**Status: Closed** (three normative changes, §4/§8/§11.2): (1) the **double-EBC variant is
L1-directly slashable at the same `D+κ` decision with zero latency** — the second accepted
EBC is already complete on-chain evidence; (2) for the preconf-vs-record variant,
`L_safety ≥ Λ ×` per-epoch MEV where **`Λ` is a normative adjudication-latency ceiling**
(Phase-A-blocking derivation, §13-S.4), with a mandatory top-up to current sizing at every
`T_max` re-auction (erosion direction stated); (3) the safety slash is **≥ 80% burned with
the remainder to the accuser**, payee bound as a proof public input (I8), and **every
in-flight verdict has a bounded deadline** — dismissed with prejudice on timeout, and the
withdrawal gate treats expired verdicts as resolved. A bonded-accusation seat suspension
remains a §13-T.12 option if `Λ ×` sizing proves too capital-heavy.

**R9-5 [MEDIUM] — Outage-progress claims overstated; worst-case rates unstated** (A4 + cF3).
"The chain keeps moving" conflated epoch-counter progress with forced settlement,
discretionary throughput, and bridge completion; the permanent-outage exit cadence (~one
cascade per `H_cancel`) and the re-queue loop's bridge bound were never stated.
**Status: Closed.** v10 §10.4 publishes the **four-guarantee split** (epoch progress —
unconditional; forced settlement — conditional on proving, unconditional only as *refund*;
discretionary throughput — conditional; bridge completion — bounded, user-initiated recall in
the outage path), §6.7 states the one-cascade-per-`H_cancel` cadence, and §9 restates the
permanent-outage bridge bound (≈ blob retention + tolling + recall latency).

**R9-6 [MEDIUM] — Censorship corridor was priced on the aggregate span, not the weakest
link** (A5 + cB3). The last-produced slice has only the ≥7-slot post-boundary tail and few
data holders; the EBC (and now the AC) are single small artifacts with 7-slot/`R`-slot
corridors — suppressing one blob transaction for 7 slots faults an honest holder, and the
old `32+κ` aggregate framing hid that.
**Status: Closed.** v10 §11.5 prices the corridor as
`min(C_slice(span_i), C_EBC(Γc+κ), C_AC(R), C_seal(S·E))`, names the mitigations (EBC/AC are
sender-free, any-party-submittable, fee-bumpable; `Γpre` margin and aggressive tail-slice
gossip), and §13-T.6 requires the measured min-span suppression cost to exceed plausible
seat-capture gain before Phase B.

**R9-7 [LOW→ normative fix] — Systemic outages slashed and charged honest holders one by
one; "drove the stall" was ill-defined** (A6 + C3 + cF5 + half of cB4). Seal deadlines
tolled only for ancestor blockage; an unattested outage matured a missed-seal certificate
against every backlog holder; the cancellation cascade charged the openEpoch's holder for a
disaster it did not cause.
**Status: Closed.** v10 §10.4 rung 3 + §6.7: while an attested outage window is active,
**proof-dependent duties toll** (seal deadlines; `T_exp` up to a hard cap `H_toll_max`) for
every epoch **whose data availability is established** (accepted AC) — the precise,
well-defined replacement for "drove the stall" is "failed a duty that needs no prover" (EBC,
slices, AC never toll). Cascade work whose horizon ran inside attested windows is a
**systemic cost charged to the shared pool/treasury, never the honest holder**; attribution
outside attested windows is unchanged. Phase A pre-commits an **attestation SLA** (maximum
response time from observable onset to DAO attestation), and `H_toll_max` guarantees I3's
proof-free exit is deferred, never removed.

### 3.2 State validity / consensus

**R9-8 [MEDIUM] — Forced-snapshot membership and the forced-inclusion delay were
consensus-critical and unpinned** (C1). "Everything queued at snapshot time" vs "items due
in the epoch" fork client against circuit; with the deployed 576 s delay an item submitted
late in epoch N−1 is due only in N+1, and a queue-everything snapshotter makes the
forced-only seal unbuildable — the epoch stalls to cancellation.
**Status: Closed.** v10 §6.5: membership is normatively **items due in `[T_N, T_N+E)`**
(due = submission + `F_delay`), in queue order; consensus constraints
**`F_delay ≥ E + F_margin`** and **the snapshot's ordered item set is a seal-proof public
input**; `F_delay` added to §3's parameter table; config audit is §13-S.17.

**R9-9 [LOW-MED] — `freshness_ceiling` vs `D_anchor` interdependence unchecked** (C2). A
governance setting of the anchor-freshness ceiling below `D_anchor + Γc + κ (+R) + margin`
makes every EBC invalid — every epoch EMPTY, every holder slashed, by parameter bug.
**Status: Closed.** v10 §6.6: the parameter setter **mechanically enforces**
`freshness_ceiling ≥ D_anchor + Γc + κ + R + margin`; tracked as a checked constraint in
§13-T.3.

**R9-10 [HIGH] — The cancellation predicate was unobservable, and seal-vs-cancel overlap let
L1 ordering pick the outcome** (F2/cB4). "No valid seal is *possible*" is not an L1
predicate; after the horizon both seal and cancel were enabled, so transaction ordering chose
whether content survives — breaking sender/order-independence (I7) at the worst spot.
**Status: Closed.** v10 §6.7: **mechanical, overlap-free cutoff** — per-epoch expiry
`T_exp = decision-final + H_cancel` on the tolled clock; **seals valid strictly before
`T_exp`, cancellation enabled at/after it, no L1 block can accept both**; stated plainly that
unsealed content *expires* even if a valid proof privately existed (expiry is a deadline
outcome, not an impossibility oracle).

**R9-11 [HIGH] — A voided forced bridge message stranded its source-side principal** (cB1).
Refunding the forced-queue fee is not principal safety: the source Bridge principal stays
locked in `NEW`, and `recallMessage` requires proof of a destination-side `FAILED` signal
that a never-executed destination transaction never creates.
**Status: Closed.** v10 §6.4: **bridge terminal-cancellation handshake** (normative,
§13-S.16) — the Bridge accepts a canonical proof of the forced item's terminal
`refunded && !consumed` L1 lifecycle state (the §6.5 nullifier) as a second recall predicate
unlocking the source principal; because the refund transition atomically kills every live
commitment and every seal proof rejects a refunded item, recall and destination execution are
mutually exclusive **by construction**, with the double-spend exclusion an explicit
conformance-test obligation. Named honestly as a required Bridge-contract change.

### 3.3 Claims and framing

**R9-12 [HIGH] — `T_max` was called a censorship bound; it is a renewal bound** (cF1 + cF6).
A well-capitalized incumbent can re-win indefinitely; `T_max` bounds one tenure-id's
un-re-priced occupancy, not actor-level control; permissionless admission and decentralized
sequencing are different properties.
**Status: Closed (wording) + Gated (metrics).** v10 §4/§5.4 rename the claim — `T_max` is
the **tenure-renewal / re-pricing bound**; the *transaction-inclusion* liveness floor is
carried by the forced queue (I6), independent of who holds the seat; durable highest-bidder
control remains a stated, accepted economic property. §13-T.7's graduation criteria now
require **concentration metrics** (seat-share per actor, max consecutive epochs, distinct
qualifying bidders per auction, forced-path usage) so contestability-vs-diversity is decided
on data.

**R9-13 [HIGH] — "Hard" preconfirmation implied more than the bond delivers** (cF4). A
conflicting preconf can create harm beyond local one-epoch MEV (cross-domain arbitrage,
external positions, application credit); the bond is deterrence, not restitution, and an
open auction removes the known-operator social backstop the whitelist implicitly had.
**Status: Closed (definition) + Accepted (residual).** v10 §5.2 defines **hard =
bond-backed, equivocation-slashable, deterrence-only**: user restitution out of scope,
aggregate signed reliance neither metered nor capped, deep-reorg residual stated; sizing
against the equivocator's own extractable gain over `Λ` (R9-4), never against users'
aggregate reliance — applications valuing promises above the deterrence must price the
residual themselves. This is the honest form; a reliance-capped guarantee would be a
different (fair-exchange-class) design, explicitly out of v1 scope (§12).

**R9-14 [MED] — Cost, cheapest-fault re-entry, and Phase-A duration risks** (cF7 + cF8 +
cF9). The normal path is more expensive and operationally selective than the whitelist; the
cheapest repeatable fault's deterrence is TAIKO-denominated and weakest in a drawdown; Phase
A pays nearly all complexity costs before delivering permissionlessness.
**Status: Gated.** §13-T.2 now requires an **empirical lower bound on cheapest-fault
re-entry cost** under stressed price/thin-auction assumptions; §13-S.14 makes Phase A a
**bounded pilot, normatively** — published review/sunset date, explicit rollback conditions,
tested whitelist-rollback path; §10.2 carries the AC gas budget and the benchmark gates of
§6 below remain the go/no-go evidence. These are empirical items; a design-text "closure"
would be theater.

**R9-15 [HIGH, consistency] — The live artifacts disagreed on three rules** (cB6). §3 said
the κ grace covers only re-posts while §5.2 said first inclusions too; §3's table said
`H_cancel` is data-loss-only while §6.7 said data-loss *or* permanent outage; §10.2 said the
residual pool is fee-funded while §7.3 said deposit-funded.
**Status: Closed.** All three fixed in place (§3 text and table, §10.2 — §5.2/§6.7/§7.3 were
normative and won); a **normative-precedence rule** added to the proposal header (the
proposal governs; README/deck/checker are derived artifacts); a cross-artifact consistency
lint is tracked §13-T.13. The learning deck is flagged as derived and pending re-sync to v10.

### 3.4 Verification suite

**R9-16 [checker validity] — Seven model gaps + harness validity** (D1–D7 + cB5). The
centerpiece single-decision rule was not in the model (decisions were un-deadlined adversary
choices); seals were untyped (an I1-violating empty-seal-closes-content bug was uncatchable);
the forced queue was a boolean (re-queue-order bugs uncatchable); no EBC one-shot;
cancellation keyed on global lag, not per-epoch tolled age; the liveness goal ignored
unresolved forced work; the outage mutant was validated at a bound where the baseline
already halts (an invalid negative control); `RESERVE0 = 2·NEPOCHS+1` made the solvency
invariant self-fulfilling; liveness reported path existence, never worst-case length.
**Status: Closed-in-checker.** The v10 checker models the decision deadline (auto-EMPTY +
certificate at window close; late decides are an invariant violation), typed seals
(`seal_content` / `seal_empty` with an I1 edge invariant), the EBC one-shot with an
**L1-direct `equivocate` action** (settles a safety certificate and terminates — the R9-4
mechanism, now mutation-tested), per-epoch tolled `openAge` with the **no-seal-after-expiry
rule** (R9-10, mutation-tested), ordered forced-item identities with an order-preservation
invariant and explicit refund terminals in the liveness goal, a **mutation harness that
first proves the unmutated baseline clean at every mutant's bound** and then requires the
mutant-specific counterexample, an observed-max-debit check against `RESERVE0` (sizing is
now a checked bound, not an assumption), and a worst-case shortest-exit-depth report for
both the standard and outage-robust relations. Full details, real re-run numbers, and the
updated mutant table: [`../simulation/RESULTS.md`](../simulation/RESULTS.md) (v10 revision
note).

**R9-17 [cB7] — The executable Phase-A implementation specification does not exist.**
**Status: Gated (by design).** v10 added §13-S.15–17 so every round-9 mechanism gap has a
numbered blocking item; the fourteen-plus-three §13-S items *are* the enumerated spec
workstream. The comparative review's "definition of done" and evidence gates are preserved
verbatim in §5–§6 below as the acceptance criteria for that work. This is the one finding a
design document cannot close about itself.

---

## 4. What the design does well (adversary's honest assessment, retained)

- **I2's computed-liability discipline** (faults are L1 facts, materialize-on-read,
  withdrawal reads the matured set) is the correct anti-poke-censorship fix and is genuinely
  model-checked — and v10's availability certificate extends the same discipline to the
  decision itself.
- **Content-addressed origin** (the EBC commits its own anchor; no L1-inclusion derivation
  inputs) kills the late-seal/reorg outcome-selection class for good.
- The **degradation ladder** refuses to let one withheld seal become a global freeze, and the
  **cascade bound** (only the ≤ `K+S` discretionary tail is value-at-risk) is a real,
  checkable bound rather than a hope.
- **I8 precommitted payees** closes the whole mempool-copy reward-theft class — and v10 wires
  the safety-adjudication reward into it rather than leaving the theft class unfunded.
- **No-oracle ETH safety tranche** is the right denomination split; `T_max` is the right
  objective renewal bound even though its calibration remains the design's biggest accepted
  economic residual.
- The **verification artifact** is unusual and good: honest scoping, reproducible results, a
  mutation self-test with teeth — and it demonstrably absorbs review pressure (the v10
  upgrades were implementable in days because the model was clean).

## 5. Comparative assessment (retained summary)

The full side-by-side of the comparative report, condensed to what a decision-maker needs;
"current" = the deployed whitelist path.

| Dimension | Advantage | One-line reason |
| --- | --- | --- |
| Who may participate | **redesign (Phase B)** | open auction entry vs DAO-curated roster |
| Misbehavior response | **redesign** | computed faults + collateral vs off-chain ejection |
| Preconfirmation assurance | **redesign, conditionally** | bond-backed after `Γc+κ`; soft window and deep-reorg residual stated (R9-13) |
| Finalization | **redesign, if the proving SLA holds** | one proof-carrying seal by `S=4` vs asynchronous pipeline |
| Forced inclusion | **redesign** | structural minimum outcome; empty invalid when the snapshot is non-empty |
| Fallback/recovery | **redesign structurally** | permissionless lane + ladder vs governance ejection; Phase A stays DAO-recoverable |
| Operator rotation | **current** | epoch-randomized rotation vs standing highest bidder (metrics now gate Phase B — R9-12) |
| Simplicity / auditability | **current, decisively** | one small contract vs many interacting state/economic/proof/bridge components |
| L1 + proving cost | **current** | streamed data, EBC, AC, seal, records, auction accounting vs small whitelist state |
| Capital barrier | **mixed** | security gain vs multi-tranche collateral + proving capacity requirements |
| Governance surface | **current** | roster + ejection vs a dozen live parameters (now partly setter-invariant-checked — R9-9) |
| External dependency | **redesign** | no URC, no validator opt-in, no oracle; depends on proving availability + Phase-A DAO attestation |
| Implementation maturity | **current** | deployed and integrated vs design-only with an enumerated §13-S backlog |

**Bottom line (unchanged):** the whitelist is a centralized operational system; the redesign
is an ambitious cryptoeconomic protocol. The redesign is clearly better if the goal is
objective accountability and eventual open contestability; the whitelist remains better if
the immediate priority is simplicity, rotation among known operators, and low migration
risk. The right decision is staged replacement with evidence gates — not a binary judgment.

### Claims-narrowing table — status after v10

| v9 shorthand | Defensible wording | v10 status |
| --- | --- | --- |
| "`T_max` is the Sybil-proof censorship bound" | "`T_max` forces tenure expiry and recurring market re-pricing; the forced queue provides the inclusion fallback" | **Adopted** (§4, §5.4) |
| "The chain keeps moving under a permanent proving outage" | "The epoch state machine is deadlock-free via proof-free cancellation; content and bridge settlement may remain unavailable" | **Adopted** — four-guarantee split (§10.4) |
| "No harmful monopoly" | "No absolute-censorship monopoly under an affordable, live forced path; ordering/economic concentration are accepted risks" | **Adopted** (§4; metrics §13-T.7) |
| "Hard preconfirmation" | "Bond-backed, equivocation-slashable commitment; no user restitution; residual deep-reorg risk" | **Adopted** (§5.2) |
| "No separate prover market" | "Healthy-path finalization is the holder's duty; fault recovery is a competitive, cost-capped proving job" | already v9 (§11.3); unchanged |
| "Cancellation only when no valid seal is possible" | An exact on-chain deadline/priority rule | **Adopted** — mechanical `T_exp` (§6.7) |

## 6. Adoption path and go/no-go evidence (retained, now partly normative)

Gate 1 — **become implementation-ready**: close every §13-S Phase-A item (now including
S.15 availability certificate, S.16 bridge handshake, S.17 forced membership) with normative
text and executable acceptance tests; no contradictory artifact (§13-T.13 lint).
Gate 2 — **prototype & measure**: non-production vertical slice; publish gas, storage,
proving tail latency (p50/p95/p99 + congestion/reorg retries vs `S=4`), bond sizing, and
client-migration results.
Gate 3 — **shadow Phase A**: run auction + fault accounting without gating the live proposer
path; compare against production; fault-injection drills.
Gate 4 — **guarded activation**: allowlisted Phase A with caps, a tested rollback, the
whitelist retained as emergency fallback — and, per §13-S.14 (now normative), a published
sunset/review date and Phase-B thresholds including the §13-T.7 concentration metrics.

Minimum evidence before replacing the whitelist (unchanged from the comparative report):
proof reliability (two independent prover implementations, tails inside `S=4`), economic
solvency under stress (including the §13-T.2 cheapest-fault re-entry floor), user-facing
guarantee documentation ("soft"/"hard"/forced/anarchy/outage, incl. what is not
compensated), benchmarked L1 cost and record-spine growth with compaction designed,
cross-stack conformance vectors (Solidity/circuit/Go/Rust, incl. reorg, recovery,
cancellation, anarchy, withdrawal, bridge-refund), independent audits + formal properties
for fund conservation, and objective Phase-B graduation data.

---

## 7. Round-9 → v10 traceability

| Report finding | Unified id | v10 disposition anchor |
| --- | --- | --- |
| A1 | R9-1 | §3, §3.1, §5.2, §13-S.15 |
| A2 | R9-2 | §3.1, §5.1 |
| A3 | R9-3 | §3 table, §5.4 |
| A4 | R9-5 | §6.7, §9, §10.4 |
| A5 | R9-6 | §5.2, §11.5, §13-T.6 |
| A6 | R9-7 | §10.4, §6.7 |
| B1 | R9-4 | §4, §8, §11.2, §13-S.4 |
| B2 | R9-4 | §8 |
| B3 | R9-4 | §8 |
| C1 | R9-8 | §3 table, §6.5, §13-S.17 |
| C2 | R9-9 | §6.6, §13-T.3 |
| C3 | R9-7 | §6.7 |
| D1–D7 | R9-16 | `simulation/` (v10 revision) |
| cB1 | R9-11 | §6.4, §9, §13-S.16 |
| cB2 | R9-4 | §8, §11.2 |
| cB3 | R9-6 | §11.5 |
| cB4 | R9-10 (+R9-7) | §6.7 |
| cB5 | R9-16 | `simulation/` (v10 revision) |
| cB6 | R9-15 | header, §3, §10.2, §13-T.13 |
| cB7 | R9-17 | §13-S (open by definition) |
| cF1 | R9-12 | §4, §5.4 |
| cF2 | R9-10 | §6.7 |
| cF3 | R9-5 | §10.4 |
| cF4 | R9-13 | §5.2 |
| cF5 | R9-7 | §6.7, §10.4 |
| cF6 | R9-12 | §13-T.7 |
| cF7 | R9-14 | gates (§6 above) |
| cF8 | R9-14 | §13-T.2 |
| cF9 | R9-14 | §13-S.14 |

---

_Consolidated 2026-08-21 from the two round-9 reviews (originally
`PR22034-preconf-redesign-adversarial-review.md` and `comparative-analysis-report.html`,
both retired by this merge). Dispositions refer to `redesign-proposal.md` v10 and the v10
model checker. Subsequent review-loop iterations live in this folder as
`step-<n>-findings.md`._
