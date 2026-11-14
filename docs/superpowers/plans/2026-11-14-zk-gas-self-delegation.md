# EIP-7702 Self-Delegation Fix Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Correct CALL-family self-delegation modeling, add boundary regressions, and enumerate remaining implementation-proof obligations.

**Architecture:** Preserve initial warmth facts and add optional `delegate_is_target` (false when absent). Exporters emit the alias fact only when true; the model accounts for target loading before delegate loading. Existing trace bytes remain valid.

**Tech Stack:** Lean 4.34.1, Python standard library, Rust/revm 43, Go.

**Spec:** User request following PR 22351 review; existing formal and trace-schema READMEs.

## Global Constraints

- Preserve the seven headline theorem statements and standard-axiom trust basis.
- Generate golden values and traces through alethia-reth, never by hand.
- Keep ordinary delegation and failed cold target loading unchanged.
- Use the three attached worktrees; do not push or merge.

## Review Focus

- Target warming happens only after the target load succeeds.
- Exact delegate-read budget spawns; one short spends all gas.
- CALL/CALLCODE value cost precedes target/delegate loading.
- Non-aliasing cold delegates still pay the cold surcharge.
- Legacy trace parsing stays valid and malformed alias facts are rejected.

### Task 1: Lean model and parser

**Files:** `packages/formal/zk-gas/ZkGasModel/{Pre,Step/Call}.lean`, `ZkGasTraces/Json.lean`, `ZkGasWitnesses/Tests.lean`.

**Interface:** Optional JSON `delegate_is_target`; `Facts.delegateIsTarget : Bool := false`.

- [x] Write parsed-alias regressions for all CALL-family exact/short budgets, forwarding, warm and non-alias controls; observe RED.
- [x] Implement alias parsing/effective warmth; build existing proofs and observe GREEN.

### Task 2: Exporters and shared vectors

**Files:** reth `crates/evm/src/zk_gas/trace.rs`; geth `core/vm/taiko_zk_gas_trace{,_test}.go`; shared corpus `cases/`, `traces/`, `coverage.json`.

- [x] Add failing exporter/parser regressions and implement alias emission/parsing.
- [x] Generate boundary vector expectations/traces from reth; verify Lean and geth against them.

### Task 3: Documentation and verification

**Files:** Existing formal/corpus READMEs and this plan.

- [x] Remove the self-delegation exclusion; document the alias fact.
- [x] List outstanding universal refinement, state, precompile and integration obligations.
- [x] Run full Lean/Python gates and affected client suites; request independent final review.

## Validation record

- RED: parsed alias guards fail before the parser extension; cold exact/value/forwarding guards still fail after parser support but before the warmth correction.
- RED: reth emits no alias fact; geth rejects the new fact. GREEN: both exporter/parser regressions pass.
- Lean full gate: seven unchanged headline statements, standard axioms, leanchecker replay; 458 vectors / 39,738 steps / 158 of 158 branches; 1,940 generated meter cases.
- Corpus checker and 35 Python tests pass. Rust EVM suite: 86 passed; payload vector suite: 16 passed. Geth VM suites pass with and without tracing, as does its traced block-vector suite.
- Repository `just clippy` passes. Independent whole-change review: no P1/P2 findings; clarified the harness-only documentation rationale.
- Client source commits are recorded in `reference.json`; source tables are regenerated with their pinned provenance. All commits are local.
