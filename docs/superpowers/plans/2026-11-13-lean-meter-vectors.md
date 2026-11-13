# Lean Meter Vectors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Generate meter vectors in Lean and check both production client meters against them.

**Architecture:** An audited pure Lean action interpreter computes per-action snapshots. A Lean
exporter emits deterministic JSON. Rust and Go runners parse the same file and call production APIs.

**Tech Stack:** Lean 4.34.1/core JSON; Python standard-library gates; Rust 1.99/serde; Go encoding/json.

**Spec:** `docs/superpowers/specs/2026-11-13-lean-meter-vectors-design.md`

## Global Constraints

- Lean generates inputs and expected results; clients only read and assert.
- Call production meters; duplicate no charge formula in client adapters.
- Preserve the seven existing proof statements and pins.
- Cover all multipliers, six spawn estimates and checked-u64 arithmetic.
- Isolated checkouts preserve the original three repositories.

## Review Focus

- Multiplication overflow rejects even with a u64::MAX budget.
- Addition overflow with existing tx/block usage preserves both totals on rejection.
- Reset restores discarded budget; commit preserves consumed block budget.
- Full-width unknown precompile addresses use the fail-safe without address truncation.
- Missing/empty corpus and malformed action/expected arrays must fail instead of skipping.

### Task 1: Lean model, generator and corpus

**Files:** Add `ZkGasModel/MeterVectors.lean`, `ZkGasTraces/MeterVectors.lean`,
`ZkGasTraces/GenerateMeter.lean` under `formal/zk-gas`; modify library roots, witnesses, lakefile,
source gate/tests and gate.sh; add `testdata/zk_gas_vectors/meter-vectors.json` and schema docs.

**Interfaces:** `MeterVectors.Action`, `State`, `Snapshot`, `applyAction` and `runActions` implement
the design's six actions and checked snapshots. Exporter writes or `--check`s the exact JSON.

- [x] Add literal guards for ADD gas 3 => 57, budget boundaries, overflow, commit/reset; observe RED.
- [x] Implement the pure interpreter and pass the guards.
- [x] Add case enumeration, JSON executable and drift/missing-file checks; generate the corpus.
- [x] Run the full Lean gate and existing Python corpus tests; document regeneration.

### Task 2: alethia-reth runner

**Files:** Add `crates/evm/src/zk_gas/meter_vectors.rs`; modify `zk_gas/mod.rs` and
`.github/workflows/zk-gas-vectors.yml` in the isolated reth checkout.

**Interfaces:** Task 1 JSON via existing corpus env; test name `meter_vectors_match_lean`.

- [x] Test mismatched/missing/empty/malformed corpus before completing the adapter.
- [x] Dispatch six actions to `ZkGasMeter` and check each outcome and both totals.
- [x] Run generated corpus; mutate one expected value, require failure, restore.
- [x] Wire the exact CI test; run the applicable suite, formatting and clippy.

### Task 3: taiko-geth runner

**Files:** Add `core/vm/taiko_zk_gas_meter_vectors_test.go`; modify
`.github/workflows/zk-gas-vectors.yml` in the isolated geth checkout.

**Interfaces:** Same Task 1 JSON; test name `TestZkGasMeterVectors`.

- [x] Test mismatched/missing/empty/malformed corpus before completing the adapter.
- [x] Dispatch six actions to production `ZkGasMeter` and check snapshots.
- [x] Run generated corpus and expected-value mutation; restore after verifying failure.
- [x] Wire exact CI test; run default/tagged zk-gas suites and gofmt.

### Task 4: Integration and review

- [x] Verify deterministic regeneration and both clients using identical corpus bytes.
- [x] Record corpus-pin publication ordering and actual validation evidence.
- [ ] Request independent whole-change review; resolve actionable findings and rerun affected tests.
- [ ] Deliver paths and changes; do not publish or merge.
