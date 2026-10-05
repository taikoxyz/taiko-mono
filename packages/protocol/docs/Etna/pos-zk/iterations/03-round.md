# Iteration 03 — change order 03 (forced inclusion removed; round-2 Criticals closed)

**Base snapshot:** `f67458b45` · **Decision:** D-6 (user-authorized removal of forced inclusion) ·
**Change order:** `03-change-order.md` · **Status:** changes applied, awaiting review round 3.

## Why this round exists

Round 2 (six Critical, twenty-three High) left four Criticals open. The user authorized removing forced
inclusion from the specification entirely, which **closes three of them by deletion** and simplifies the
public-input vector, the reward accounting and the migration path. The fourth, R2A-01, is fixed by
changing the validator-set lookahead from one epoch to two.

## What was completed

| Item | Finding(s) closed | Where |
|------|-------------------|-------|
| Forced inclusion removed in full: FI-01…FI-05, the L1 queue, fee, escrow, events, errors, interface functions, the `forcedInclusionCommitment` public input and its guest check, the inclusion duty in proposal validity, the censorship offence, the escape hatch, and every cross-reference | R2-LIV-01, R2-LIV-03, R2-LIV-04 and the forced-inclusion Highs | spec/01, 02, 04, 05, 06, 07, 08, 09, 10, index |
| Tombstone rule `FI-REMOVED-01` and honest statement rule `LIVE-04` added; R10 restated in the requirements matrix and README | D-6 | spec/04, spec/10, 01-requirements, README |
| Two-epoch lookahead: the staking contract commits the set root for epoch `e+2` during epoch `e`, with the normative inequality `2·E_EPOCH ≥ T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + margin`; a missing *future* entry is not a halt condition | R2A-01, R2A-02 | spec/02 CONS-13, spec/03 MEM-03/09, spec/09 |
| Unsettled-depth cap made **consensus-only** with a single enforcement point; the L1 rejection deleted because it could strand a legitimate extension; the honest cost stated (a violating quorum is not objectively punishable) | R2-LIV-07, R2-LIV-08 (partly) | spec/04, spec/06 HALT-03 |
| One cap in one unit: `D_MAX` in L2 blocks from `RETENTION_WINDOW`; `MAX_UNSETTLED_AGE` deleted as redundant; `RETRIEVABILITY_WINDOW` stated as a different object (post-acceptance archive duty, L1 blocks) | R2-LIV-08 | spec/04 DA-05/DA-06, spec/09 |
| Executed bodies must be decoded **from the committed payload** with `transactions_root` checked; no second witness copy of the payload | P-R2-01 | spec/05 PRF-06/PRF-03 |
| Canonical byte-level payload framing (ordered frames, `be32` length prefix, RLP body, exact frame count, no trailing bytes, injective) so both backends implement one statement | P-R2-04 | spec/05 PRF-07(0) |
| Journal and L1-05 reconciled to one authoritative public-input vector; row 20 vacated; `feeRecipient` kept with an independent justification | E-R2-02 | spec/04 §2.1, spec/05 PRF-02 |
| Reward mechanism made implementable: segregated ETH pool, per-signer participation input, permissionless claim, per-epoch payout identity | E-R2-05 | spec/07 ECON-02 |
| Reporter bounty strictly below the penalty; evidence window anchored to the offence epoch and to a stored `rootCommittedAt`; churn limit reconciled with the exit lifecycle | E-R2-06, E-R2-07, R2A-06 | spec/03, spec/07 |
| Migration: D5 boundary stated (the Shasta wind-down is a different protocol; legacy entry points disabled at a named transition); slot budget enumerated; legal genesis checkpoint record | E-R2-01, E-R2-03 | spec/08 |
| Verifier-route policy closed: routes are upgrades only; the "not rejectable by any account" wording deleted | E-R2-04 | spec/04 L1-09, spec/05 PRF-09 |
| Lock rule rewritten per height so it cannot be read as permanent | R2A-10 | spec/02 CONS-04 |
| Learning course re-based on the removal: lesson 11 rewritten in place, the course map, six further lessons and the limitations page updated; all 1,054 links resolve | R14 consistency | learn/* |

## What remains open entering round 3

- **F1** — the epoch-handoff lock carry-over argument is still argued, not machine-checked.
- The full round-2 Medium/Low set that was dispositioned by text rather than by mechanism
  (per-epoch state-retention cost, activation queue timing, alias resolution, evidence-identity
  encoding).
- The measurement gates F2–F4 (in-guest blob evaluation, 2 s cadence, prover fleet sizing).
- Two normative questions still parked as Open with stated consequences: the L2-fee-to-L1-pool
  transfer, and the audited verifier-route inventory.

**No convergence is claimed.** Round 3 must re-review a frozen snapshot with fresh reviewers covering all
five angles; only two consecutive clean full-design rounds would satisfy the project's stopping rule.
