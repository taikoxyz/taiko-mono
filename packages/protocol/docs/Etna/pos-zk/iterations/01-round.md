# Iteration 01 — adversarial review round 1

**Frozen snapshot:** `dfcf067a5b91a1b0bacd4470f5f5054d1f861a24` (2026-10-05)
**Reviewers:** four independent adversarial reviewers, one per angle, each writing a raw report under
`iterations/raw/`, followed by lead adjudication (deduplication and severity).
**Angles covered:** (A) consensus safety, hidden certificates, reconfiguration; (B) proof soundness,
bridge funds, stake custody, accounting; (C) liveness, data availability, censorship, recovery, the
30-minute pipeline; (D) economics, TAIKO concentration, permissionless entry.
**Coverage limitation:** the fifth required angle (compliance with atomic submission and preservation
of shared addresses) was **not** assigned to a dedicated reviewer in round 1; it is covered in round 2.
**Model note:** the harness exposes one model for delegated work in this session, so reviewer
diversity is procedural (fresh context, independent verdicts, no mitigation narrative) rather than by
model. Recorded as a limitation, not a substitute for a safety argument.

Raw reports: `raw/round1-liveness-da-recovery-30min.md` (C, 11 findings),
`raw/round1-proof-bridge-custody.md` (B, 17 findings),
`raw/round1-economics-entry.md` (D, 19 findings). Angle A's report had not landed when this ledger was
written; its findings are appended in iteration 01b and must be resolved before round 2 closes.

---

## Round-1 counts (lead-adjudicated, duplicates merged)

| Severity | Count | Inside the fault model |
|----------|-------|------------------------|
| Critical | 3 | 3 (plus 1 conditional) |
| High | 22 | 18 |
| Medium | 14 | 9 |
| Low | 5 | 0 |

The three Critical findings that survive adjudication:

1. **Round-1 B R1-01 — blob data binding is defeated if the challenge can be fixed before the payload is
   fixed** (2° report, Critical). Adjudication: **Accepted as High-Critical ambiguity, fixed by
   construction.** The attack requires `z` to be independent of the executed payload. The revised
   rule makes `dataCommitment` cover the *whole* published blob byte string, folds it into the
   Fiat–Shamir challenge, and binds the executed payload to the certified header chain, so the attack
   becomes a fixed-point search over `p_D(z(D)) = p_B(z(D))` rather than a linear solve. Additionally
   the EIP-4844 polynomial convention (evaluation form, bit-reversed setup) is now normative, and the
   calldata path remains the unconditionally sound alternative. Residual: the tightened construction
   is a new argument and must be re-attacked in round 2 (Q-A3).
2. **Round-1 C R1-01 — forced-inclusion due set versus the per-batch cap permits a permissionless
   permanent halt** (Critical, inside the fault model). Adjudication: **Accepted. Fixed** — the duty is
   now the *capped FIFO prefix* of the due list, defined once in FI-02 and consumed by CONS-01(v); an
   arbitrarily long queue can slow coverage but can never invalidate every proposal.
3. **Round-1 D ECO-01 — the reward budget has no inflow in the reward asset** (Critical). Adjudication:
   **Accepted. Fixed by correcting the design, not the wording**: TAIKO is the staking and collateral
   asset (D7), while validator rewards are denominated and paid in **ETH**, collected on L1, so the
   budget identity is single-currency and evaluable. The remaining question — how L2 fee revenue
   reaches the L1 reward pool — is recorded as an **Open** rule with the honest consequence that an
   unfunded pool pays nothing and the security budget collapses.

---

## Disposition of accepted High findings

| ID (source) | Finding | Disposition |
|-------------|---------|-------------|
| B R1-02 | Blob polynomial convention was ambiguous (evaluation vs coefficient form) | **Fixed**: EIP-4844 evaluation-form convention and the bit-reversal order are normative; honest proofs now pass |
| B R1-03 | Nothing binds the claimed epoch to the batch heights or to a set version | **Fixed**: epoch is a pure function of height under the L1-committed schedule; the L1 staking contract stores set roots per epoch, so L1 resolves epoch → root without trusting the proof |
| B R1-04 | A batch may cross epochs but the journal carries one set root | **Fixed**: a batch may not span an epoch boundary (PRF-05) |
| B R1-05 | Two contradictory validator-set commitments (MEM-08 Merkle vs CONS-10 flat hash) | **Fixed**: one canonical encoding; CONS-10's header fields commit to the MEM-08 root |
| B R1-06 | Pure-blob `dataCommitment` undefined; PRF-07 contradicts DA-02 | **Fixed**: one definition — the commitment covers the same bytes that are executed and published |
| B R1-07 | Forced-inclusion refund plus coverage payout double-pays, making batches unlandable | **Fixed**: escrow solvency invariant and a single accounting path; refund and coverage are mutually exclusive per request |
| B R1-08 / C R1-06, R1-07 | Dueness defined twice with different clocks; drift bound one-sided | **Fixed**: one definition (FI-02, L1-visible state), applied identically on L2 and L1, with a two-sided timestamp bound |
| B R1-09 | L1→L2 checkpoint writer remains the privileged golden-touch/Anchor path | **Accepted, reconciled**: SYS-02 governs which L1 facts may be consumed; the remaining writer privilege is recorded as an Open migration item with its consequence, not asserted away |
| C R1-02 | The L1 backstop does not verify forced-inclusion payloads | **Fixed**: `forcedInclusionCommitment` is in the journal and PRF-04(vi) checks the covered set equals the capped due prefix |
| C R1-03, R1-05 | The unsettled-depth cap was unobservable and unexpressible | **Fixed**: `land` rejects depth > D_MAX using its own storage; validators use a mandatory finality margin; D_MAX now contains a proof-latency term |
| C R1-04 | Retention is unenforceable | **Accepted as a disclosed limitation**: retention is a liveness assumption, not a duty; the claim that it is enforced was removed |
| C R1-08 | Mode B `T_STALL` satisfiable by ordinary degradation | **Accepted**: folded into REC-03, whose blocker status is unchanged |
| C R1-09 | Liveness claim stated as a mean rate | **Fixed**: per-batch wording in LIVE-01(L4) |
| C R1-10, R1-11 | Forced-inclusion refund ledger and hatch availability | **Fixed**: escrow solvency and refund-without-removal semantics; hatch described as a fee remedy, not an inclusion right |
| D ECO-02, ECO-03 | Minimum-stake predicate undefined; price silently assumed | **Fixed**: rewards in ETH remove the mixed-currency sum; S_min is stated only in ETH-revenue terms with UNMEASURED inputs; price appears only in the deterrence discussion |
| D ECO-04, ECO-05 | Evidence windows anchored at the wrong event and possibly empty | **Fixed**: windows anchor to the offence's epoch and cover the whole D5 pipeline |
| D ECO-06 | Offender can self-report and recover its own penalty | **Fixed**: reporter bounty is strictly less than the correlated penalty, so self-reporting is never profitable |
| D ECO-07 | No exit churn limit; predictable security cliff | **Fixed**: per-epoch churn limit added |
| D ECO-08 | Weak-subjectivity window ≈ the proof envelope, so a stall blocks fresh entry | **Fixed**: the L1 checkpoint is the weak-subjectivity source regardless of stall duration; the freshness window is derived from the withdrawal delay, and the consequence of exceeding it is stated |
| D ECO-09, ECO-10, ECO-15 | Activation fairness, offline free-riding, payout interface | **Fixed**: activation rate-limited and described honestly (ordering is not proof-of-fairness under adversarial L1 ordering); rewards conditioned on attested participation |
| D ECO-13 | MEV counted as revenue with no capture mechanism | **Fixed**: removed from the funding identity until a capture mechanism exists |

## Medium and Low findings

Twelve Mediums are fixed by the same edits (accounting identities, parameter registrations, route
wording, naming, PRF-04 signature fields, MSG-01 versus frozen storage, per-epoch state retention
cost). The remainder are explicitly **accepted with rationale**: the unmeasured economic inputs; the
absence of an objective on-chain signal for a price-driven security collapse (so it cannot be a halt
condition, only a disclosure plus a governance parameter change); and the EPOCH-len arithmetic.

## Round-1 verdict

**Not converged.** Six Critical and twenty-eight High findings were inside or adjacent to the claimed
fault model (see iteration 01b below for the consensus-angle findings and the revised counts). Fixes were applied to the specification; round 2 must re-attack the fixed rules with fresh
reviewers, including the fifth compliance angle and a dedicated re-attack of the tightened blob binding.


---

## Iteration 01b — consensus-safety angle (landed after the main ledger)

**Report:** `raw/round1-consensus-safety-reconfiguration.md` — 3 Critical, 6 High, 1 Medium, 1 Low,
all inside the fault model.

Revised round-1 totals after adjudication: **Critical 6, High 28, Medium 15, Low 6.**

| ID | Finding | Disposition |
|----|---------|-------------|
| CS-01 | The epoch → set-version mapping was a function of the *node-local* L1 view, so the proposer effectively chose the validator set; it also contradicted MEM-09(3), CONS-13(5) and the glossary, and no L1 object mapped epoch to root | **Accepted, Critical. Fixed**: `epoch_of(h)` is a pure function of height under the L1-committed schedule; the L1 staking contract stores an append-only `epoch → (setRoot, totalVotingPower)` mapping that is immutable once the epoch starts; L1 resolves epoch to root without trusting the proof (fixer applied to CONS-13 / MEM-09 / L1-05) |
| CS-02 | Leader selection was a linear residue rotation in *weight units*, so with realistic totals the first-sorted validator was proposer for effectively every height; one minimum-bond key could halt the chain or capture ordering | **Accepted, Critical. Fixed**: selection becomes `pos = keccak256(domain, l2ChainId, epoch, height, round) mod W`, with the proposer the owner of the cumulative-weight interval containing `pos` — uniform-in-weight, deterministic and verifiable, with negligible modulo bias because `W ≪ 2^256` |
| CS-03 | The Fiat–Shamir point was derived over a field list that did not contain the blob versioned hashes, so under the contract-side reading the challenge was independent of the blob and the adaptive-payload attack succeeded with probability 1 | **Accepted, Critical. Fixed**: the challenge derivation now includes `blobHashesHash` and `dataCommitment` per blob index, and the commitment covers the entire published byte string — the same fix as the proof-angle finding B R1-01, reached independently by two reviewers |
| CS-04 | Two incompatible set-root encodings (CONS-10 flat hash vs MEM-08 Merkle) | **Fixed**: MEM-08 owns the single encoding; CONS-10's header fields commit to that root |
| CS-05 | PRF-05(iii) required per-epoch set commitments with no public input to carry them | **Fixed**: a batch may not span an epoch boundary, so one root suffices |
| CS-06 | Epoch length had two normative values (CONS-13 `L = 900` vs PARAM-02 `EPOCH_LEN_L2 = 300`) | **Fixed**: one value, owned by CONS-13, registered in PARAM-01 |
| CS-07 | The "≥ 1/3 is objectively slashable" claim was unproven for cross-round conflicts, because CONS-11 admits only same-(height, round) pairs and the quoted lemma assumes compilable JSets that a withholding adversary prevents | **Accepted**: the claim is narrowed to what is provable; cross-round lock violations under withholding are recorded as **Assumed/Open**, not as an established penalty |
| CS-08 | Transition fields (`epoch_anchor`, `(setVersion, N(k))`) had no header encoding | **Fixed**: fields and canonical encodings specified under GEN-05's convention |
| CS-09 | Quorum off by one: CONS-03 accepted `3s > 2W` (67 at W=100) while the L1 threshold was `floor(2W/3)+1 = 67` and PRF-04 required strictly more (68), so a minimally finalized certificate would be unprovable | **Fixed**: a single predicate `3·s > 2·W` is normative in the client, the guest and the L1 contract; the `threshold + 1` formulation is deleted |
| CS-10, CS-11 | Parameter-register gaps; evidence did not include an epoch-agreement check | **Fixed**: parameters registered; CONS-11 evidence includes the epoch-agreement check |

**Reviewer agreement worth recording:** the consensus reviewer independently reached the same
conclusion as the proof reviewer on the blob binding (CS-03 ≡ B R1-01) from a different starting
point (the contract-side challenge field list rather than the polynomial form). Two independent
reviewers converging on the same Critical finding is the strongest evidence in this round that the
original text was defective; the fix therefore had to satisfy both attacks, not one.

**Q-A1 answer (all three reviewers that answered it agree):** the availability counterexample is a
failure *of* the stated liveness assumptions, not reachable inside them, so the Mode A selection
survives D2 step 1. All three added the same caveat: the bound that keeps it outside — the unsettled
depth cap — was unobservable and unexpressible, which is a defect in the bound, not in the selection,
and is fixed by HALT-03 / L1-06.

