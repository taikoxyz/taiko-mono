# Taiko Based Preconfirmation — Design Documentation

This directory holds the design documentation for Taiko's based preconfirmation protocol,
including the historical/reference design documents and the ongoing redesign work.

## Contents

| Document | Description |
| --- | --- |
| [`reference/post-whitelist-design.md`](reference/post-whitelist-design.md) | Markdown conversion of the "[Ext] Taiko Preconf Post-Whitelist Design Doc" (Notion). Describes the URC-based "Phase 2" design: L1 validators opt in via the Universal Registry Contract, lookahead handling, equivocation slashing, and the fair exchange problem. |
| [`reference/post-shasta-preconf-slashing.md`](reference/post-shasta-preconf-slashing.md) | Markdown conversion of the "Taiko Post-Shasta Preconfirmation Slashing" doc (Notion). Describes the two-contract PreconfSlasherL2/PreconfSlasherL1 slashing system built around the URC and the native bridge. |
| [`status-quo.md`](status-quo.md) | (Deliverable 1) Assessment of the current preconfirmation design and its implementation status in this repository, validation of the redesign premises, and open questions. |
| [`redesign-proposal.md`](redesign-proposal.md) | (Deliverable 2) Draft design proposal, now **v8**: perpetual auction with commit→publish→seal epochs — nine normative invariants, single-decision epoch state machine, deadline-only proof-carrying seals, L2-evidence slashing, split ETH/TAIKO bond in one seniority-waterfall account, degradation ladder, Total Anarchy fallback, and game-theory analysis with an attack catalog. Converged across six adversarial review rounds (ten reviewer passes), an owner-approved self-review simplification round (v7), and a post-simplification regression audit (v8) that re-checked every prior finding and reverted the one simplification that regressed (see the proposal header and Appendix A #24–28). |
| [`simulation/`](simulation/) | (Deliverable 3) State-machine model checker of the v8 design + [results](simulation/RESULTS.md): exhaustive bounded exploration from a curated set of initial configurations — all safety invariants hold at every reachable state and transition and no permanent halt exists across millions of states, with a mutation self-test proving the invariants have teeth. |
| [`slides/`](slides/) | Learning deck: a 22-slide PDF walking through the v6 design (motivation → mechanisms → economics → degradation → verification), for onboarding without reading the full proposal. HTML source + rendered PDF. |

Figure images extracted from the original PDFs live in [`reference/images/`](reference/images/).
