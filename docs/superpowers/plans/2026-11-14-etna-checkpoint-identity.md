# Etna Checkpoint Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Extend the existing Etna settlement model to check symbolic checkpoint
and proof-cut identity across overlapping landing and ordinary recovery.

**Architecture:** Compose a new top-level TLA+ module with `EtnaSettlement`.
Preserve all first-round model/configuration files. Route new configurations
through the same bounded runner using an optional `MODULE` metadata comment.

**Tech Stack:** TLA+, TLC 1.7.4, Java 17+, Python standard library.

**Spec:** `docs/superpowers/specs/2026-11-14-etna-checkpoint-identity-design.md`

## Global Constraints

- Source remains `d18357214fab30ea512ae9858a11699806d72ba1`.
- One existing `formal/etna/` project/worktree/branch; no replacement of its 12 checks.
- No production edits, compilation, tool installation, publication or deployment.
- Symbolic identities are an explicit abstraction, not cryptographic proofs.
- Recovery origin's retained validator-state hash is not its new genesis state.

## Review Focus

- A wrong-origin proof at p=c must not bypass an interior-only checkpoint check.
- Matching caller leaves must not conceal conflicting execution-authenticated cuts.
- Matching EL hash alone is insufficient when Comet/FI/validator-state fields differ.
- Legitimate recovery-origin reuse must remain possible after generation changes.
- Expanded configurations must run their selected module, never silently run the old model.

### Task 1: Composed model and adversarial configurations

**Files:** new checkpoint identity `.tla` module(s), `formal/etna/configs/identity-*.cfg`.
**Consumes:** base `Init`, `Land`, `Recover`, other actions and constants.
**Produces:** `IdentitySpec`, safety invariants and named reachability witnesses.

- [x] Write expectation/configuration cases before the composed transitions.
- [x] Observe a missing-binding control fail with its intended invariant.
- [x] Implement the normative composed guards and recovery preservation.
- [x] Run normal and adversarial configurations with bounded TLC.
- [x] Independently review source mapping and counterexample plausibility.

### Task 2: Shared runner, documentation and final evidence

**Files:** `formal/etna/check.py`, `tests/test_check.py`, `README.md`, `REPORT.md`.
**Consumes:** cfg comment `\* MODULE: EtnaCheckpointIdentity` or legacy default.
**Produces:** one CLI runs both model scopes; exact result and module metadata.

- [x] Add runner routing tests, observe failures, implement safe module selection.
- [x] Run the complete old/new suite and an independent stronger bound.
- [x] Review all changed files and resolve material findings.
- [x] Document source rules, counterexample paths, results and open boundaries.
- [x] Run formatting/whitespace/path-hygiene checks and preserve a local commit.

Expected: every normal run exhausts its graph; each negative control and witness
returns its exact named invariant, not a parser error, timeout or wrong-module run.
