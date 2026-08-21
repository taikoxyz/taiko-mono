# Adversarial Security Review — Permissionless Based Preconfirmation Redesign (PR #22034, v9)

**Reviewer stance:** independent adversary with full freedom of action — auction winner,
successor tenure, Sybil standby, permissionless recoverer, filler, prover cartel, or L1
builder coalition. Goals: (1) pause chain liveness, (2) steal funds, (3) drive the chain into
an invalid/unrecoverable state.

**Target:** `packages/protocol/docs/preconfirmation/redesign-proposal.md` (v9, 2026-08-21,
head `a2c2b7c29`), plus `simulation/model_checker.py` and `simulation/RESULTS.md`.
Documentation-only PR; no contract code changed.

**Method.** Full read of the proposal (1062 lines), the status-quo assessment, the reference
designs, and the 992-line model checker; the checker and its mutation self-test were re-run
and reproduce the claimed results (2,339,418 states at 3×4, 0 violations, 0 halts; all 11
mutants caught). Key claims were cross-checked against the current protocol code
(`Inbox.sol`, `LibForcedInclusion.sol`, `Derivation.md`, `MainnetInbox.sol`) and the
eight prior review rounds on the PR thread.

---

## Verdict

No **confirmed** exploit was found that pauses liveness, steals funds, or corrupts state
_given the design's stated assumptions_. The v1→v9 lineage closed the historical holes
(no-evidence stalls, hidden-tail reorgs, unprovable PUBLISHED poison, poke-dependent
liability, double-κ finality, brake self-triggering), and the state machine holds up under
bounded exhaustive model checking including permanent proving outages.

However, the design's two hardest load-bearing claims rest on mechanisms that are **not
specified at all**, and one theft-deterrence claim is **internally inconsistent**. An
implementer acting on the doc as written can plausibly build a system in which a griefer
slashes every honest seat-holder for pennies, the claimed 'parent final at Γc+κ' boundary
does not exist, or an equivocator nets ≈ (L−1) epochs of MEV against a 1-epoch bond. These
must be pinned as Phase-A blocking items before implementation.

**Severity counts:** 3 High, 5 Medium, 4 Low/notes (list below), plus 7 verification-suite
improvements.

---

## Findings

### A. Liveness (pause the chain)

#### A1 [HIGH] The D+κ 'bytes on L1' decision is the load-bearing rule, but its evaluation mechanism is unspecified

§3.1/§5.2 make the entire v6–v9 structure rest on one sentence: 'the EBC is valid only if
**every referenced byte is on L1 at the single decision D+κ**', and I2/I4 derive the parent's
irreversibility at Γc+κ (7 slots) from it. But **nothing in the doc says how this presence is
evaluated.** L1 contracts cannot read blob data; EIP-4788 exposes beacon block _roots_, while
blob KZG commitments live in the beacon block _body_ (`blob_kzg_commitments`). Checking
'blob commitment C was included in a canonical beacon block by slot D+κ' therefore requires
SSZ generalized-index proofs (through the beacon block into the body's commitment list)
verified either in the EVM (SHA256 precompile, KB-scale proofs, ~225 epoch decisions/day,
base-fee-sensitive gas) or in the seal circuit.

The two obvious implementations have **divergent security consequences**:

- **Decision-time check (design-preserving):** someone must submit the SSZ proofs in a
  permissionless resolution transaction at D+κ (materialize-on-read, I2-consistent). This
  preserves the claimed finality but adds a new consensus-critical, gas-priced machinery
  that the doc never budgets — and the _caller_ who triggers resolution pays for it (an
  unspecified cost attribution: the successor's EBC submission, a withdrawal, or a poke
  could be saddled with the parent's resolution cost).
- **Seal-time check (cheap):** let the seal proof verify blob inclusion in-circuit. Then the
  'decision at D+κ' cannot fire without a proof, an invalid-EBC epoch cannot resolve
  EMPTY-PENDING at D+κ, the successor's 'hard' boundary silently becomes seal time, and the
  double-κ parent-flip hole the design explicitly closed (r4c-2) reopens.

**Suggestions.** (1) Add a new Phase-A blocking spec item: exact blob-inclusion proof format
(EIP-4788 anchor + SSZ proof of `blob_kzg_commitments` membership, κ-grace and
beacon-reorg semantics), who may call resolution, and who pays (suggest: charged to the
epoch's holder tranche if the EBC is invalid, else to the caller). (2) Add the decision
resolution to the §3 timeline and gas/cost budget. (3) State explicitly that the check is
_commitment-inclusion_ (the seal proof then binds bytes to commitments) — the doc's
'every referenced byte is on L1' is not literally evaluable on L1.

#### A2 [HIGH] EBC acceptance predicate unspecified — one-shot can be weaponized to slash honest holders every epoch

§5.1/§3.1: 'one-shot per (tenure, epoch)… the first-landed artifact wins… any second
distinct artifact is invalid.' The doc never states the submission acceptance predicate.
If 'first-landed' consumes the one-shot _before_ signature validation against the tenure's
registered commitment keys (§2), then a griefer submits one well-formed-but-unsigned EBC per
epoch for the holder's tenure → the holder's real EBC is the 'second distinct artifact' →
invalid → EMPTY-PENDING → the holder is **slashed and terminated for a fault it did not
commit**, at a cost to the attacker of one L1 transaction per epoch. This turns the entire
I2 'no fault requires the accused' philosophy into a per-epoch griefer-slashes-everyone loop.

**Suggestions.** State the predicate explicitly as a normative rule: (1) an EBC is accepted
only if it carries a valid signature by the tenure's _registered_ commitment keys for that
epoch; (2) non-conforming submissions are no-ops and **do not consume the one-shot**; (3)
the one-shot is consumed only by the first _valid_ artifact; (4) a second _distinct valid_
EBC is not merely 'invalid' — it is immediate L1 on-chain equivocation evidence (see B1).
Byte-identical re-lands remain no-ops per §3.1.

#### A3 [MEDIUM] K_empty has no on-chain computation path

§5.4 defines K_empty over 'post-derivation output containing no non-system content from an
address outside the tenure's registered key set' and §4 lists 'termination on K_empty'. But
this predicate exists only inside derivation/proofs, and the explicit-empty epoch's seal is
**proof-free** (I7) — so no artifact carries the count to L1, and L1 cannot compute it. As
written, K_empty-termination is not mechanically implementable; an idle holder can simply
avoid content proofs entirely. The doc has honestly demoted K_empty to a 'nuisance bound',
but it still lists termination on it as a mechanism.

**Suggestions.** Either (1) drop K_empty as an on-chain termination trigger and rely on
T_max + the fee clock (both L1-computable) — recommended given the Sybil-resettability; or
(2) if kept, specify its carrier precisely (e.g., only content-seal proofs report the
counter, so it can only ever fire against holders who actually submit content — a
significantly weaker property that should be stated, not implied).

#### A4 [MEDIUM] Worst-case throughput under a permanent outage: 'chain keeps moving' at ≈1 epoch per H_cancel

The outage-robust model pass proves deadlock-freedom, but the real-world exit cadence for a
CONTENT-decided epoch during a proving outage is the H_cancel (10-day) horizon, with the
cascade clearing the tail in one step — so worst-case progress is **one cascade per ~10
days** while forced traffic re-queues in a loop (each re-queued forced-only epoch again
needs a proof-carrying seal and again waits out its own horizon). Forced items eventually
void at blob expiry (~18 days) with refunds, and bridge deposits are recall-only for the
outage duration. G5's 'the chain keeps moving' is technically true but the doc should state
the _rate_, and §9's 'worst-case bridge settlement = H_cancel + one forced-only cadence'
understates the permanent-outage path (≈ blob retention + recall latency, and recall is
user-initiated).

**Suggestions.** State the worst-case throughput explicitly in §10.4/§9; restate the §9
bridge bound for the re-queue-loop path; consider a Phase-B study of whether a cheaper
proof-free 'forced-only digest' (commitment-only processing) could be admitted for forced
items during attested outages.

#### A5 [MEDIUM] The censorship floor is the _last_ slice's Γc+κ window, not '32+κ'

§11.5 prices censorship as 'the 32-slot in-epoch stream plus the Γc+κ post-boundary tail'.
But the last-produced slice only ever has Γc+κ = 7 slots of inclusion budget and few data
holders (the holder plus whatever P2P peers received it in the final seconds). Suppressing
**one blob transaction from one address for 7 consecutive L1 slots** faults an honest
holder. The doc's own §5.2 concedes the 7-slot budget for the last slice; the corridor
quantification (§13-T.6) should price the _minimum_ span per slice (the weakest link), not
the aggregate.

**Suggestions.** Price the corridor at 7 slots for the tail slice; recommend holders end
sequencing with margin (the Γpre lever) or post redundant tail copies early; make this
explicit in §13-T.1/§13-T.6.

#### A6 [LOW] Systemic outage slashes the backlog's holders one by one unless an attestation fires

Seal deadlines toll only for _ancestor_ blockage (I4), not for proving unavailability. Under
an unattested systemic outage, each epoch's holder accrues a missed-seal certificate at its
tolled deadline and is slashed/terminated for an environment failure. The rung-3 freeze
requires a DAO attestation in Phase A and a permissionless predicate that does not exist yet
(§13-S.7); its 'never covers the holder(s) whose epochs drove the stall' is ill-defined
under a systemic outage — nobody 'drove' it.

**Suggestions.** Define outage-aware tolling: while an attested (or, later, permissionlessly
predicated) proving outage is active, seal-deadline maturation pauses for non-causing
epochs. At minimum, Phase A should pre-commit the attestation SLA that covers this case.

---

### B. Fund theft

#### B1 [HIGH] 'One epoch is the exposure' contradicts the design's own adjudication latency

§4/§11.2 size L_safety against **one epoch's MEV** and assert 'one epoch is the exposure',
while §11.2 itself concedes 'if L2 equivocation adjudication is slower than one epoch,
exposure is that latency in epochs'. There is **no accusation-time seat suspension** — the
tenure keeps sequencing until a settled certificate terminates it. The earliest feasible
adjudication (L2 proof of the EBC record against an anchored L1 state root, anchor depth 32
slots) lands ≈ 1.5 epochs after D+κ; if adjudication instead waits for the seal, ≈ 4–5
epochs. An equivocating holder therefore nets ≈ **(L−1) × per-epoch MEV** against a 1× bond,
equivocating in every epoch while the previous certificate settles.

**Suggestions** (do at least two of three): (1) size L_safety ≥ (adjudication-latency
ceiling × per-epoch MEV), with the ceiling pinned as Phase-A-blocking (§13-S.4); (2) make
the **double-EBC case L1-directly slashable**: the second distinct valid EBC is already an
on-chain record — settle its safety certificate at the same D+κ decision with no L2 proof,
closing the latency for that variant; (3) add a bonded-accusation seat suspension for the
preconf-vs-EBC variant (accuser stakes; false accusations forfeit), so the equivocation
stream stops immediately. Also note the erosion direction: L_safety is value-fixed at tenure
start while per-epoch MEV can grow during T_max (weeks) — the T_max re-auction is the
natural re-pricing point and should carry a mandatory top-up to the _current_ safety sizing.

#### B2 [MEDIUM-HIGH] The safety (theft) class has no funded, precommitted-payee enforcement path

Every liveness mechanism is funded: poke bounties, fault-paid recovery, indexed
compensation — all with precommitted payees (I8). But the **equivocation adjudication — the
only fault the ETH safety tranche exists for — has no reward specified anywhere** (§8 says
'adjudication … + distributions' with no definition; the safety slash is burned). Producing
the L2 proof costs real proving work; with no funded incentive, rational actors don't
adjudicate, the safety certificate never settles, and the ETH tranche is a decoration.

**Suggestions.** Specify an accuser reward drawn from L_safety (e.g., burn ≥80%, pay the
accuser the remainder), payee bound as a proof public input (I8-conform), and fund the
adjudication window from the tenure's own tranche on settlement. Fold the reward into the
§13-S.4 adjudication-latency spec.

#### B3 [LOW] Withdrawal gate has no bound on 'in-flight verdicts'

§8.4 blocks withdrawal while 'in-flight verdicts' exist, but nothing bounds a verdict's
resolution time. A griefer with one slow/bogus adjudication can extend an honest ex-holder's
bond lockup indefinitely (the ≥2-week floor is a floor, not a ceiling).

**Suggestions.** Give every adjudication a bounded deadline (timeout → dismissed with the
accuser's stake forfeited if bonded-accusation is adopted, B1), and let the gate treat
time-expired verdicts as resolved.

---

### C. Invalid / unrecoverable state

#### C1 [MEDIUM] Forced-snapshot membership rule and the forced-inclusion delay are consensus-critical and unpinned

Appendix C fixes the snapshot 'before T_N' and the seal proof consumes it, but the
membership predicate is unspecified. It must be exactly 'items **due during [T_N, T_N+E)**'
(which requires forcedInclusionDelay ≥ E), _not_ 'everything queued at T_N' — with today's
576 s = 1.5E delay, an item submitted 0.4 epochs before T_N is not due until epoch N+1; a
'queue-everything' snapshotter includes it in epoch N, where a due-ness-checking seal proof
cannot consume it — the forced-only seal becomes unbuildable and the epoch stalls to
cancellation. Wrong membership rules fork client vs circuit, and §3's parameter table omits
the forced-inclusion delay entirely.

**Suggestions.** Add the parameter to §3; make 'snapshot = items due in [T_N, T_N+E), delay
≥ E + snapshot-fix margin' normative; make the membership rule a seal-proof public input so
client and circuit agree byte-for-byte; audit Hoodi/devnet configs for the delay change.

#### C2 [LOW-MED] Parameter-consistency invariant missing: freshness ceiling vs D_anchor

The anchor must be ≥ D_anchor (32 slots) deep **and** within a governance 'freshness
ceiling' of T_N. If governance ever sets ceiling < D_anchor + Γc + κ + margin, **no valid
EBC can exist**: every epoch resolves EMPTY-PENDING, every holder is slashed for a
governance bug, and the chain degrades to forced-only until the parameter is fixed. This
parameter interdependence should be a checked invariant, not folklore.

**Suggestions.** Enforce `freshness_ceiling ≥ D_anchor + Γc + κ + margin` in the parameter
setter, and add it to the §13-T.3 calibration list.

#### C3 [LOW] Cancellation economics under systemic disaster

§6.7 charges 'the cancellation-causing tenure' for cascades, but a genuine data-loss /
systemic-outage cascade is not tenure-attributable — the openEpoch's holder pays for a
disaster it did not cause, and the gate ('no valid seal _possible_') is only implementable
as 'no valid seal _submitted_ in the horizon', which a hypothetical long-run censoring
coalition can stretch. Mostly a fairness note, but it interacts with A6: disaster + charge +
slash compounds on innocent holders.

**Suggestions.** Distinguish disaster-caused cancellations (charged to a shared pool / no
single-tenure charge) from tenure-attributable stalls; document the residual seal-submission
censorship assumption in §6.7.

---

### D. Verification-suite (model checker) gaps — improvement suggestions

The checker is honest and well-documented, and its results reproduce. The following
extensions would materially raise its evidence value:

1. **Model the D+κ decision itself.** The single-decision rule — the centerpiece of I2/I4 —
   is _not in the model_: decisions are un-deadlined adversary choices and no action
   represents 'parent outcome fixed at D+κ'. The checker currently provides zero evidence
   for the property the whole v6–v9 structure stands on (A1).
2. **Type the seals.** `seal` does not distinguish proof-carrying content seals from
   proof-free empty seals (only the outage branch does). Add `seal_proof` (CONTENT only)
   and `seal_empty` (EMPTY only), so 'empty seal accepted for a CONTENT-decided epoch' —
   an I1 violation — becomes catchable.
3. **Ordered forced queue.** `forced` is a boolean; 're-queued snapshots preserve original
   queue order' (§6.7) is unmodeled. Use ordered lists so ordering bugs across
   cancellation/re-queue are catchable.
4. **EBC one-shot.** Add a per-(tenure, epoch) commit counter so double-EBC acceptance (A2,
   B1's L1-direct slash) can be modeled and mutated against.
5. **Seal-deadline semantics.** The SEAL certificate materializes after one tick as
   openEpoch, vs the design's S=4 tolled epochs. This is over-strict (a documented
   conservative direction is fine), but it means the _actual_ tolling semantics are not the
   thing being verified — state this in RESULTS.md and, ideally, model S tolled ticks.
6. **Throughput, not just deadlock.** Liveness reports existence of a path, never its
   length. Report worst-case advances-per-clock under outage so the '1 epoch per H_cancel'
   consequence (A4) is surfaced by the tool rather than by hand.
7. **Sizing sufficiency.** `RESERVE0 = 2·NEPOCHS+1` makes `inv_bond_nonneg` self-fulfilling
   (admission sizing is _assumed_ perfect — §7.3's solvency invariant is §13-S.9 work).
   Consider deriving the worst-case obligation from the state machine (max certs per owned
   epoch across all interleavings) instead of asserting it.

Also: wire the checker into CI as tracked (§13-T.10).

---

## What the design does well (adversary's honest assessment)

- **I2's computed-liability** discipline (faults are L1 facts, materialize-on-read,
  withdrawal reads the matured set) is the correct anti-poke-censorship fix and is genuinely
  model-checked.
- **Content-addressed origin** (EBC commits its own anchor; no L1-inclusion derivation
  inputs) kills the late-seal/reorg outcome-selection class for good.
- The **degradation ladder** correctly refuses to let one withheld seal become a global
  freeze, and the **cascade bound** (only the ≤ K+S discretionary tail is value-at-risk) is
  a real, checkable bound rather than a hope.
- **I8 precommitted payees** closes the whole mempool-copy reward-theft class.
- **No-oracle ETH safety tranche** is the right denomination split; T_max is the right
  (objective, Sybil-proof) idleness bound even though its calibration is the design's
  biggest accepted economic residual.
- The verification artifact is unusual and good: honest scoping (deadlock-freedom, not
  livelock-freedom), reproducible results, and a mutation self-test with teeth.

## Suggested next steps

1. Promote A1, A2, B1, C1 to **Phase-A-blocking** spec items (new entries under §13-S),
   with the exact predicates/mechanisms stated.
2. Re-size L_safety to the adjudication-latency ceiling and add the accuser-reward path
   (B1/B2) before any bond parameter is fixed.
3. Extend the model checker with D1–D7 (at minimum D1 and D2) and re-run.
4. Recalibrate T_max with the chain-wide discretionary censorship cost (fee-rate × T_max)
   stated explicitly in §4, and consider a time-based (demand-free) fee escalation as the
   Sybil-proof pricing lever.

---

_Independent review, 2026-08-21. Targets: redesign-proposal.md v9 @ a2c2b7c29,
simulation/model_checker.py, simulation/RESULTS.md. No code changes proposed in this review;
all suggestions are design-level._
