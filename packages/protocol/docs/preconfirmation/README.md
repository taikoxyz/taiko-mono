# Taiko Based Preconfirmation — Design Documentation

This directory holds the design documentation for Taiko's based preconfirmation protocol,
including the historical/reference design documents and the ongoing redesign work.

## Contents

| Document | Description |
| --- | --- |
| [`reference/post-whitelist-design.md`](reference/post-whitelist-design.md) | Markdown conversion of the "[Ext] Taiko Preconf Post-Whitelist Design Doc" (Notion). Describes the URC-based "Phase 2" design: L1 validators opt in via the Universal Registry Contract, lookahead handling, equivocation slashing, and the fair exchange problem. |
| [`reference/post-shasta-preconf-slashing.md`](reference/post-shasta-preconf-slashing.md) | Markdown conversion of the "Taiko Post-Shasta Preconfirmation Slashing" doc (Notion). Describes the two-contract PreconfSlasherL2/PreconfSlasherL1 slashing system built around the URC and the native bridge. |
| [`status-quo.md`](status-quo.md) | (Deliverable 1) Assessment of the current preconfirmation design and its implementation status in this repository, validation of the redesign premises, and open questions. |
| [`redesign-proposal.md`](redesign-proposal.md) | (Deliverable 2) Draft design proposal: perpetual auction with commit→publish→seal epochs — nine normative invariants, single-decision epoch state machine, L2-evidence slashing, split ETH/TAIKO bond, degradation ladder, Total Anarchy fallback, and game-theory analysis with an attack catalog. Converged across four adversarial review rounds (eight passes). |
| [`simulation/`](simulation/) | (Deliverable 3) Exhaustive state-machine model checker of the v6 design + [results](simulation/RESULTS.md): all safety invariants hold and no permanent halt exists across millions of reachable states, with a mutation self-test proving the invariants have teeth. |

Figure images extracted from the original PDFs live in [`reference/images/`](reference/images/).
