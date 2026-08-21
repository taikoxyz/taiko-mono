# Taiko Based Preconfirmation — Design Documentation

This directory holds the design documentation for Taiko's based preconfirmation protocol,
including the historical/reference design documents and the ongoing redesign work.

## Contents

| Document | Description |
| --- | --- |
| [`reference/post-whitelist-design.md`](reference/post-whitelist-design.md) | Markdown conversion of the "[Ext] Taiko Preconf Post-Whitelist Design Doc" (Notion). Describes the URC-based "Phase 2" design: L1 validators opt in via the Universal Registry Contract, lookahead handling, equivocation slashing, and the fair exchange problem. |
| [`reference/post-shasta-preconf-slashing.md`](reference/post-shasta-preconf-slashing.md) | Markdown conversion of the "Taiko Post-Shasta Preconfirmation Slashing" doc (Notion). Describes the two-contract PreconfSlasherL2/PreconfSlasherL1 slashing system built around the URC and the native bridge. |
| [`status-quo.md`](status-quo.md) | (Deliverable 1) Assessment of the current preconfirmation design and its implementation status in this repository, validation of the redesign premises, and open questions. |
| [`redesign-proposal.md`](redesign-proposal.md) | (Deliverable 2) Draft design proposal, now **v11**: perpetual auction (with a `T_max` tenure-expiry re-auction — the objective tenure-renewal/re-pricing bound) with commit→publish→seal epochs — nine normative invariants, single-decision epoch state machine with an L1-evaluable availability certificate and a default derivation rule for holderless epochs, deadline-only proof-carrying seals, L1-direct + L2-evidence slashing with a funded accuser reward, split ETH/TAIKO bond in one seniority-waterfall account, mechanical expiry cancellation, attested-outage tolling, degradation ladder, Total Anarchy fallback, and game-theory analysis with an attack catalog. Converged across ten adversarial review rounds, an owner-approved self-review simplification round (v7), and a post-simplification regression audit (v8) (proposal header, Appendix A #24–35, Appendix B). |
| [`review-loop/`](review-loop/) | The review-loop record: [`round9-consolidated-review.md`](review-loop/round9-consolidated-review.md) merges the two independent round-9 reviews (adversarial security pass + comparative implementation-readiness pass) into one report with the v10 dispositions for every finding, and `step-<n>-findings.md` files record each subsequent challenge-then-respond review iteration until no critical/important findings remain. |
| [`simulation/`](simulation/) | (Deliverable 3) State-machine model checker of the v10 design + [results](simulation/RESULTS.md): exhaustive bounded exploration from a curated set of initial configurations — all safety invariants hold at every reachable state and transition, and no permanent halt exists **even under an adversarial proving outage that never lifts**, with a mutation self-test (validity-checked baselines + mutant-specific counterexamples) proving the checks have teeth. |
| [`slides/`](slides/) | Learning deck: a 22-slide PDF walking through the design (motivation → mechanisms → economics → degradation → verification), for onboarding without reading the full proposal. HTML source + rendered PDF. Derived artifact — currently reflects v9; the proposal governs on any divergence (see the proposal's normative-precedence note); re-sync tracked in §13-T.13. |

Figure images extracted from the original PDFs live in [`reference/images/`](reference/images/).
