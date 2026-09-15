# Slot Chain review repairs implementation plan

**Goal:** Resolve the four findings in the independent Astra review of PR #22064 and publish a tested design-only PR stacked on that exact design branch.

**Architecture:** Preserve permissionless canonical progress and the existing custody boundaries. Make forced-transaction validity total, enforce the current L1 transaction resource limits, publish one complete migration journal, and replace an unsupported seat-collusion claim with explicit, bounded economic exposure. The Solidity reference implementation remains a separate PR.

**Tech stack:** Normative LaTeX/PDF, standalone Python models and regression tests, GitHub CLI.

## Decisions

- Reject static transaction invalidity at ingress; consume execution-state/fork-dependent invalidity under an explicit deterministic no-transaction disposition. Every supported input has one classification; EVM execution reverts remain ordinary included transactions.
- Retain the existing canonical profile layout where possible. Enforce the profile revision's fixed Ethereum transaction cap in addition to its configured block limit, and account for the calldata floor and full call envelopes. Synthetic fixtures must obey the same resource bounds.
- Make the detailed migration journal and normative appendix agree, including ingress activation, VMC1 and its final static lease post-read. Add rollback/ordering evidence against the composed model.
- Preserve the deliberate late-cure/no-slash policy. Remove the assertion that a refundable SLA bond deters every higher-ask promotion, quantify the funded premium exposure, and require economic acceptance of non-breaching promotion before production. Do not introduce an unreviewed penalty into canonical proof acceptance.
- Preserve the distinction between revocable preconfirmations, canonical state and L1 finality; require implementation artifacts to pin an exact normative commit rather than only a v2.27 label.

## Work items

- [x] Add forced-admission/classification regressions, then implement the exhaustive classification model and update its normative wire rules.
- [x] Add the accepted-17-million-gas regression and fork-aware resource-bound tests; repair profile validation and all affected fixtures/commitments.
- [x] Add a composed late-cure/premium/bond-credit regression, correct economic relation descriptions and document the accepted exposure instead of claiming slashing that does not occur.
- [x] Reconcile the full migration ordering and verify its trace and rollback behavior.
- [x] Synchronize README, specification status, implementation guidance, model counts and revised PDF.
- [x] Run focused regressions followed by all existing model suites; independently review the final spec/model diff.
- [x] Rebuild the PDF and inspect changed pages, including tables and the transition appendix.
Publication target: commit and push `codex/slot-chain-spec-astra-fixes`, then open the design-only PR with base `claude/chain-liveness-builder-roles-cda13y`. Report the verified results and remaining production gates.

## File ownership during implementation

The forced-transaction worker owns `settlement-window-model.py` and a new focused forced-transaction regression file. The gas worker owns `commitment-model.py` and a new resource-bound regression file. The economics worker owns `economic-profile-model.py`, its existing test file and a new composed economics regression file. The coordinator owns `tex/main.tex`, README, this plan, migration integration follow-ups and the PDF. Workers report proposed normative text rather than editing the shared LaTeX file concurrently.

## Verification

Focused tests must demonstrate the previously accepted invalid cases reject or receive the specified discard outcome. Full verification runs the settlement, lookahead, commitment, seat-market and economic-profile models and all adversarial suites. Real EVM/circuit conformance, compiled gas certificates and external audits remain production gates; Python predicates are not represented as cryptographic or EVM execution evidence.

## Completed verification

- Settlement and lookahead models: 186 and 38 properties pass.
- Regression suites: settlement 302, seat market 114, economic profile 41, forced validity 17, L1 resources 20, route preparation 8, migration journal 2, composed seat promotion 7; all pass.
- Commitment model: 876 golden vectors and 1,693 assertion sites pass, including the final normative publication table.
- Full activation succeeds while both source factory deployment methods are forbidden. Seven final lease-read fault cases restore the complete projected state and permit the same proof to be retried.
- Independent review found and verified corrections for cross-model resource validation, the final raw lease read, kind-0 handle rollback and deployment calls in the actual activation path.
- Tectonic 0.17.0 rebuilt the 253-page PDF. The revised forced rules, resource formulas, economics, migration journal, model summary, diagrams and parameter tables were visually inspected; the committed PDF matches the final build byte for byte.
- `git diff --check` passes. No Solidity runtime changes are included.
