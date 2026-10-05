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

---

## Round-3 review results (snapshot `3b0821f2f`, four fresh reviewers, all five angles)

| Angle | Critical | High | Medium | Low |
|-------|----------|------|--------|-----|
| Consensus safety / reconfiguration | 0 | 4 | 5 | 2 |
| Proof soundness / binding / custody / accounting | 0 | 3 | 4 | 1 |
| Liveness / DA / censorship / recovery | 0 | 2 | 4 | 3 |
| Compliance with D1–D7 + economics | 0 | 2 | 4 | 2 |
| **Total** | **0** | **11** | **17** | **8** |

**This is a material improvement over round 2 (6 Critical, 23 High) and no reviewer found a
two-conflicting-finalized-histories attack inside the fault model in any round.** It is still **not** a
clean round: eleven new High findings were raised, all inside the claimed fault model, most needing no
adversary at all. The consecutive-clean-round count therefore remains **zero** and the specification
remains **not converged**.

### Verified closed by this round (re-checked, not re-listed)
Forced-inclusion removal is residual-free (no dangling FI dependency, no rule still assuming an inclusion
guarantee); the two-epoch lookahead is coherent across CONS-13/MEM-09/ECON-07/09; the per-height lock of
CONS-04 is unambiguous and matches the published same-height Proof of Safety; the single quorum predicate,
the single set encoding, hash-based leader selection, L1-resolved epoch→root identity and the churn wiring
all hold; the consensus-only cap with one enforcement point bounds finalized depth without stranding a
legitimate extension; the blob fixed-point argument was independently re-derived after the journal change
and holds under its named premises; the payload-decode and `transactions_root` binding holds for the
calldata path; the journal and L1-05 agree field for field; D5 is proven for the Etna path; D3 holds with a
10-of-43 slot budget and no frozen-layout change; D7 holds; ordinary operation needs no privileged party.

### Round-3 High findings and disposition

| ID | Finding | Disposition |
|----|---------|-------------|
| R3A-01 | The L1-side epoch clock was undefined (schedule defined in L2 heights, clock said to be L1 block time), so any cadence faster than nominal or any halt decouples them | **Fixed in revision**: epoch 0 anchored to a named L1 block, L1-side schedule expressed in L1 blocks, and the L2 may not enter an epoch before the L1 has reached its start block |
| R3A-02 | The two-epoch lookahead was a partial fix: one uncontrolled `commitSet()` per call, no obligation, so a single skipped epoch permanently degrades the lead to one epoch | **Fixed in revision**: the append becomes an obligation with a restorable, permissionless call, and the operative steady-state inequality is stated |
| R3A-03 | WH-04 still required carrying the closing epoch's lock forward, contradicting the per-height lock | **Fixed in revision**: WH-04 re-based on parent-validity plus epoch-scoped permanent certificates |
| R3A-04 / R3-PRF-01 | Epoch-boundary evidence has no public inputs, and its trigger is keyed to the batch *head*, so a normal multi-block batch never fires the anchor check; `next_validators_hash` has no L1-pinned input | **Fixed in revision**: trigger re-keyed to the batch's first block, `set_version_commit` added as a journal input, and the L1-pinned anchor value stated |
| R3-PRF-02 | `finalityCommitment` was called proof-bound but no guest clause checked it | **Fixed in revision**: the guest must recompute it from the verified head certificate |
| R3-PRF-03 / R3-CE-03 | The validator payout denominator `P(e)` was never frozen, so the first claimant could take the whole epoch allocation | **Fixed in revision**: `P(e)` is frozen at the evidence-window close, with `Σ payout ≤ Alloc(e)` stated as a checked condition |
| R3-CE-02 | ROLE-01(d) said rewards are paid in the accepting transaction, contradicting the amended pool design | **Fixed in revision** |
| R3-LIV-01 | A halt longer than the evidence window lets committed-but-unproduced epochs' windows close while their immutable set roots still govern, so validators can exit unpunished and INV-03's premise is void | **Fixed in revision**: the window is anchored to the event that makes the offence observable, not to L1 wall-clock alone |
| R3-LIV-02 | No inequality tied the cap to D6's 1800 s envelope, and `T_PROOF_MAX_PERMITTED` was defined oppositely in two places; at plausible values a normal 30-minute proof triggers the cap | **Fixed in revision**: one definition plus a joint inequality that keeps a normal proof from triggering the cap |

### Round-3 Medium and Low findings
Seventeen Mediums and eight Lows were raised. The substantive ones are fixed with the Highs above. Those
recorded as **open** are: the blob-path padding-versus-no-trailing-bytes contradiction and the missing
in-guest padding check (R3-PRF-05, introduced by the round-3 framing fix); the blob-range and hybrid-copy
equality gap (R3-PRF-06 / P-R2-05); the `feeRecipient` and timestamp in-guest binding (R3-PRF-04); the
exposure-cap-versus-withdrawal-gate contradiction (R3-PRF-07 / P-R2-09); the Mode B scoping of L1-04/L1-06
(R3-LIV-05); the redundant ECON-07(7) sentence (R3-LIV-06 / R3A-09); the missing LIM-01 rows; residual
parameter-registration and alias defects; and the index-title mismatches.

### What convergence would still require
Round 4 and round 5 must both be full-design rounds on frozen snapshots with fresh reviewers covering all
five angles, with **no new Critical or High**. Given eleven new Highs at round 3 — several introduced by the
previous round's own fixes, which is itself a finding about the amendment process — two clean rounds are not
yet in hand, and this change cycle has used three of the eight permitted rounds.
