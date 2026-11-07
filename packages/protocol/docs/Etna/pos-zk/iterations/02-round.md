# Iteration 02 — adversarial review round 2

**Frozen snapshot:** `5e4129913e2540ac42c5c8b5034b64cdc3a5c8f1` (2026-10-05)
**Reviewers:** four fresh independent adversarial reviewers, one per angle, each with the round-1
ledger as history but instructed to judge the rules as written and to treat the in-text
"(review round 1, finding X)" notes as claims rather than evidence.
**Angles:** (A) consensus safety / hidden certificates / reconfiguration; (B) proof soundness and a
dedicated **re-attack of the amended blob binding**; (C) liveness / DA / censorship / recovery /
30-minute pipeline; (D) compliance with D1–D7 plus an economics spot-check (the angle that round 1
did not separately assign).
Raw reports: `raw/round2-consensus-safety-reconfiguration.md`, `raw/round2-proof-blob-binding.md`,
`raw/round2-liveness-da-recovery-pipeline.md`, `raw/round2-compliance-economics.md`.

## Result: NOT CONVERGED

| Angle | Critical | High | Medium | Low |
|-------|----------|------|--------|-----|
| Consensus / reconfiguration | 1 | 6 | 4 | 1 |
| Proof soundness / blob binding | 0 | 5 | 6 | 1 |
| Liveness / DA / recovery | 3 | 7 | 3 | 1 |
| Compliance / economics | 2 | 5 | 3 | 1 |
| **Total** | **6** | **23** | **16** | **4** |

Every Critical and every High is inside the claimed fault model; seven of the ten most severe need no
adversary at all. Under the project's stopping rules this round **does not** count toward the two
consecutive clean full-design rounds, so the specification has **not** reached specification-level
convergence.

## What round 1's fixes actually achieved (verified, not re-listed)

The re-attack angle confirmed the most important outcome: **the round-1 Critical blob-binding attack is
closed.** With `dataCommitment` recomputed over the whole published payload and both it and
`blobHashesHash` entering the per-blob Fiat–Shamir transcript, neither the executed payload nor the
published blob can be adapted after the challenge is fixed; the remaining route requires a KZG-binding
break or a hash fixed point of cost ≈ 2^-243 per fresh candidate. Independently verified closed:
the single quorum predicate, the single validator-set encoding, the `L = 900` epoch length, the
hash-based leader selection (pure, ungrindable, fairness honestly Assumed), the L1-resolved
epoch→root mapping, the narrowed slashability claim, the queue-length denial-of-service fix, escrow
solvency and refund/coverage mutual exclusion, retention presented as an assumption, and the
per-batch liveness wording.

## Round-2 Critical findings

| ID | Finding | Status |
|----|---------|--------|
| R2-LIV-01 | **One permissionless forced-inclusion request whose payload cannot be a valid L2 transaction permanently blocks production and landing.** FI-01 bounds only the payload length; FI-02/CONS-01(v) make the due prefix mandatory "as transactions"; FI-03 forbids voiding the request and refunds the fee while leaving it due forever; HALT-04 forbids a rescue; REC-01/L1-06 forbid rewriting history. Cost: L1 gas. This is a cheaper variant of round-1 C R1-01 that the capped-prefix fix does not cover | **Resolved in revision, not re-reviewed**: requests whose payload fails a normative decodability check must be skippable/voidable at request time, with the fee refunded. Needs a round-3 verification |
| R2-LIV-03 | **The two-sided timestamp bound is an unstated landing deadline.** With `FORCED_INCLUSION_MAX_DRIFT < FORCED_INCLUSION_DELAY_SECONDS` and a normal D6 30-minute proof, a batch's first block is older than the drift bound when it lands, so `land` reverts `BatchTimestampDrift` and the range is permanently unlandable. Breaks D6, L1-04, R9 and Mode A | **Open** |
| R2-LIV-04 | **Consumption scope is not closed.** CONS-01(v) binds every block's due prefix; FI-02(a)/PRF-04(vi) bind only the batch's first block; "consumed" exists only on L1. The per-block reading re-demands an already-executed payload (no valid block can be produced); the batch reading makes the duty unverifiable at proposal time and removes the premise of the anti-cartel argument | **Open** |
| R2A-01 | **The epoch lookahead gate halts production at every boundary.** MEM-09(1)'s gate keys the set-root commit for epoch `e+1` to the Inbox's last accepted height, which under D5 lags production by the whole proving pipeline; with D6's 30-minute envelope equal to one epoch, the gate opens at the boundary and MEM-09(5) forbids producing until the entry is Ethereum-final — a ≥12.8-minute production stop at every epoch boundary, contradicting D1/D6 and CONS-13(3) | **Open** (fix direction: two-epoch lookahead) |
| E-R2-01 | **The migration path defeats D5.** The legacy Shasta entry point remains callable through FROZEN/DRAINED and advances the L1 SignalService checkpoint from a proposal whose data was published in an earlier transaction, and activation adopts that checkpoint as genesis, while L1-01/L1-02/INV-02 claim no exception exists | **Resolved in revision, not re-reviewed**: the legacy path is named as a separate, bounded protocol whose batches can never be Etna batches and whose entry points are disabled at a named transition |
| E-R2-02 | **The public-input vector is defined twice and differently.** L1-05's binding table and PRF-02's "exact" journal disagree by at least eight fields; depending on which is implemented, either no proof can verify or load-bearing values (the forced-inclusion fee recipient, the batch's first-block timestamp) are unbound | **Resolved in revision, not re-reviewed**: one authoritative list with a field-by-field reconciliation |

## Round-2 High findings (23)

Condensed, with disposition:

- **Proof/statement interface**: the executed block bodies are never required to be decoded from the
  committed payload and `transactions_root` is never checked, so a prover can publish arbitrary bytes
  while executing the certified chain from a separate witness element (**Open — must be closed by a
  rule, not a wording change**); PRF-04(vi)'s due-prefix check has no queue or payload list in the
  journal (**Open**); the epoch-opening anchor check is keyed to the wrong block and needs the closing
  epoch's set root that the single-epoch journal cannot carry (**Open**, with R2A-01); the byte-level
  framing of a batch payload is defined nowhere, which also makes "the statement both backends
  implement" ill-posed (**Open**).
- **Caps and windows**: `D_MAX` and `MAX_UNSETTLED_AGE`/RETRIEVABILITY_WINDOW are two caps in two
  units over different objects with no stated relation (**Open**); L1-04/DA-06 forbid the cap as an
  admission condition while L1-06/HALT-03 mandate it (**Resolved in revision: the admission rule is the
  cap's only enforcement point; DA-06's wording was corrected**); LIVE-03(i) admits a parity state in
  which a cap-induced halt never drains (**Open**); ECON-07's evidence window and HALT-03's cap are
  mutually unsatisfiable at the derived values (**Open**).
- **Migration and privilege**: MIG-02's slot budget omits the state required by L1-07, L1-11, FI-01 and
  L1-09 and the genesis checkpoint record is undefined (**Resolved in revision, not re-reviewed**);
  the verifier-route policy's "not rejectable by any account" wording is a bridge-theft hole
  (**Resolved in revision: route changes are upgrades only**).
- **Economics**: validator rewards are promised but no mechanism, per-signer input or claim path exists
  (**Resolved in revision with an Open marker**); the pure reporter-bounty option re-opened
  self-reporting (**Resolved in revision**); the evidence-window anchor is not storable on L1
  (**Resolved in revision**); the churn limit is contradicted by the membership lifecycle
  (**Open**).
- **Textual and traceability**: lock-rule wording can be read as making every lock permanent; the
  binding lists conflict; several parameters named as "fixed in 09" are absent from 09; the learning
  site still teaches the coefficient-form blob interpretation (**partially resolved in revision;
  requires a consistency pass**).

## Round-2 verdict and stopping decision

Round 2 reviewed a frozen, identified snapshot with four fresh reviewers covering all five required
angles, including the compliance angle that round 1 missed. It found **six new Critical and
twenty-three new High** findings, all inside the fault model. Two of the six Criticals were fixed in
revision while the round was closing; the remaining four are open. Because none of those fixes has been
re-reviewed, **no round qualifies as clean**, the consecutive-clean-round count is zero, and the
specification is therefore **not converged**.

Per the project's stopping rules this result is labelled **incomplete**, not converged and not
negative: the architecture-level questions (Mode A feasibility, consensus selection, proof shape,
atomic submission, TAIKO staking, address preservation) are answered with arguments and evidence, but
the specification still contains security-relevant rules that an implementer would have to invent, and
four Critical defects remain open. The work required to reach convergence is: fix R2-LIV-01/03/04 and
R2A-01 together with the statement-interface and cap-unit Highs; unify the two binding lists and the
payload framing; then run at least two consecutive full-design rounds with fresh reviewers on a frozen
snapshot, all five angles, and no new Critical or High findings.
