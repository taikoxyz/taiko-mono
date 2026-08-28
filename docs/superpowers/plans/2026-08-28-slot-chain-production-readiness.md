# Slot-Chain Production Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use multi-agent adversarial review between every implementation round. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the slot-chain specification and its executable models into a coherent, implementable protocol specification, or establish with explicit counterexamples that this is impossible under the selected trust model.

**Architecture:** Treat the LaTeX specification as normative and the Python models as executable conformance checks. Consolidate normal and fallback landing into one versioned state machine, make every security/economic bound a hard consensus invariant, close production-blocking lifecycle semantics, and regenerate the PDF after each coherent round.

**Tech Stack:** LaTeX/XeLaTeX, dependency-free Python reference models, Poppler PDF inspection, Git.

---

### Task 1: Establish the production-readiness invariant set

**Files:**
- Modify: `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
- Modify: `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/lookahead-model.py`

- [ ] Record falsifiable invariants for canonical-state transitions, fallback closure, reward conservation, exposure bounds, proof/data availability, lifecycle transitions, and L1 reorg replay.
- [ ] Add adversarial regression tests before changing the corresponding normative rule.
- [ ] Run both models and confirm each new regression fails for the intended reason.

### Task 2: Repair one coherent mechanism round

**Files:**
- Modify: `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
- Modify: `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/lookahead-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/README.md`
- Regenerate: `packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf`

- [ ] Implement the smallest rule set that makes the failing regressions pass.
- [ ] Remove superseded normative rules rather than leaving them beside their replacements.
- [ ] Run both executable models and LaTeX three times.
- [ ] Extract and inspect the generated PDF; verify page count, references, and affected diagrams/tables.
- [ ] Commit exactly one coherent redesign round.

### Task 3: Adversarially challenge the committed round

**Files:**
- Review all files under `packages/protocol/docs/preconfirmation-v2/`.

- [ ] Dispatch independent reviewers for fallback/economics, scheduling/slashing, and implementation/lifecycle semantics.
- [ ] Require explicit attack traces and causal EVM/circuit implementability checks.
- [ ] Reproduce every plausible critical/high finding in a model or a concrete state trace.
- [ ] If a finding survives, return to Task 2 and create one new commit for the next redesign round.

### Task 4: Close the production blockers

**Files:**
- Modify the same normative and model files above.

- [ ] Specify genesis, migration, L1-reorg rollback, proof-system outage behavior, builder admission/exit, and bounded resource limits as executable state transitions.
- [ ] Replace unverifiable economic assumptions with hard bounds or state them as deployment-blocking external requirements with measurable acceptance tests.
- [ ] Remove claims that depend on an unimplemented proof-continuation primitive unless a concrete interface and benchmark gate are specified.

### Task 5: Final acceptance

- [ ] Obtain an adversarial review round with no surviving critical/high findings.
- [ ] Confirm the source, models, README counts, and committed PDF agree.
- [ ] Confirm the working tree contains only intended changes.
- [ ] If any required invariant cannot be achieved under the selected no-DA/no-forced-inclusion architecture, document the impossibility and stop rather than calling the design production-ready.
