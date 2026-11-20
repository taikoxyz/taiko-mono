# Etna L1 trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Model the first bounded M02 trust/sign/serve scope and challenge its assertions.

**Architecture:** A finite L1 snapshot trace feeds independent node observations.
A new module uses the existing outcome-checking runner; earlier models are untouched.

**Tech Stack:** TLA+, TLC 1.7.4, Java17, existing Python runner.

**Spec:** `docs/superpowers/specs/2026-11-14-etna-l1-trust-design.md`

## Global Constraints

- Preserve existing models and 31 configurations byte-for-byte.
- No protocol SPEC edits, production compilation, installs, push or PR.
- Use relative portable paths in committed artifacts, temporary run directories.
- Distinguish environment assumptions, model gaps and protocol bugs.
- No claim of code refinement, unconditional liveness or complete module coverage.

## Review Focus

- A lagging canonical view can legitimately differ from global finalized state.
- Own-L1 timeout is distinct from app-trust-confirmation timeout.
- Missing validator material is not a contradictory validator-state value.
- Current-generation start reuses retained metadata with a validator exception.
- Observation changes must not silently lose learned supersession.

## Task 1: Model, configurations and documentation

**Files:** Create `formal/etna/EtnaL1Trust.tla`, `formal/etna/configs/l1-trust-*.cfg`,
`formal/etna/L1_TRUST.md`. Root owns design/plan, README and REPORT integration.

- [x] Write explicit expected PASS, negative-control violations and reachable witnesses first.
- [x] Implement bounded snapshot/provider/authentication/node/sign/serve actions.
- [x] Run normal cases and controls, fix parse/runtime errors, then self-review.
- [x] Independent reviewer inspects source correspondence and all new files.
- [x] Independent tester challenges properties with mutations and stronger bounds.
- [x] Resolve findings, freeze inputs, run full suite and runner tests.
- [x] Root records validation/limits, reviews complete diff, commits locally and updates worklist.
