# Etna model/code five-increment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete five more meaningful verification increments, stop on an independently supported real issue, otherwise return for retrospective.

**Architecture:** Two isolated, owned lanes in the same formal project: M08/M09 TLA state exploration and Lean/TLA-to-real-contract correspondence. Reuse exact sources, a single SDK and one Foundry cache.

**Tech Stack:** Existing TLC1.7.4/Java17/Python standard library; temporary official Lean4.35.0; existing Foundry1.4.2/cached Solc0.8.30; exact pinned dependencies.

**Spec:** `docs/superpowers/specs/2026-11-15-etna-model-code-design.md`

## Global Constraints

- Preserve175 existing TLA configs/models/runner and incomplete experiments.
- Freeze SPEC d183, Lean cdbc346 and contracts89f419; current main SPEC blob matches.
- No production changes, global installs, Rust builds, duplicate target trees, live actions, push or merge.
- Use portable artifacts under `formal/etna/`, caller-configured staging/output paths and exact-source manifests.
- Execute inspected repository code with network disabled, clean environment, isolated source/output and no original Git metadata/secrets.
- Model/oracle/adapter errors are repaired separately; independently confirmed real source/implementation bugs stop both lanes for user confirmation.
- Independent source review and behavioral verification at each gate; at most two coherent fix waves.

## Review Focus

- Wildcard proof mocks must not create old-generation proof acceptance; C02 binds original statement and tests mismatch rejection.
- Normalize K6 grid points consistently and keep empty FI in C02; do not rescale per-block FI claims.
- Lean metadata/CLI changes and missing SDK are not code bugs; C01 validates exact metadata exception and real execution separately.
- Invalid late list items/registry failures must not leak canonical state; M08-A/C03 compare raw full pre/post projections.
- Rollback preserves current generation and advances current nonce; invalid cached-signal AND retry authorization, confirmation snapshot and fee-paid markers require independent M09-A checks.

## Task1 C01: Lean and real Registry8 baseline

**Files:** `formal/etna/conformance/pins.json`, `conformance/README.md`, `conformance/run_baseline.py`, `conformance/tests/test_baseline.py`, `conformance/REPORT.md`.

**Interfaces:** Caller supplies pinned Lean/contract source roots, SDK/compiler paths and output root. Runner emits exact source/tool digests, generated/current vector comparison, actual command outcomes and explicit unavailable/failed states.

- [x] Stage and inspect exact sources/dependencies; size-check verified official SDK before extraction; preserve a build/disk reserve.
- [x] Add tests rejecting wrong source/vector hashes, any non-authority JSON difference, missing cases and false PASS from skipped/failed commands.
- [x] Build current Lean targets locally once; regenerate vectors through actual current CLI and compare both raw/semantic digests.
- [x] Replay real pinned Registry8 fixture; keep authority metadata bridge explicit and all expected behavior unchanged.
- [x] Independent review/verification, evidence/local commit/worklist update; setup-only or CI-only is not completion.

## Task2 M08-A: recovery list validation and atomicity

**Files:** `formal/etna/EtnaRecoveryTransaction.tla`, `configs/recovery-tx-*.cfg`, `RECOVERY_TRANSACTION.md`; export interface documented for C03.

**Interfaces:** Reuse actual `EtnaSettlement` actions through wrappers; actual canonical pre/post receipt plus immutable original request. Complete public-attempt projection includes lists, id/key identity, queue state, outcome and canonical fields.

- [x] Pin exact recovery rules and finite sequence domains; write expected controls/witnesses first.
- [x] Implement private tentative workspace, validation/external failure and atomic commit/abort; no bypassed base actions.
- [x] Check sorted/unique ids/indices, issued-unheld id, matching keys, execution-time range, unchanged fees/metadata/confirmations and complete failed-call state equality independently.
- [x] Measure bounded full-action profiles; retain incomplete products with exact inputs; independently challenge oracles and positive mixed-list paths.
- [x] Review/test/fix gate, freeze export interface, local commit/worklist update; stop on real issue.

## Task3 C02: real settlement and authorization replay

**Files:** `conformance/EtnaSettlementReplay.tla`, `conformance/export_settlement.py`, `conformance/settlement_cases.json`, `conformance/solidity/EtnaSettlementReplay.t.sol`, focused exporter/adapter tests.

**Interfaces:** Actual TLC base actions determine each outcome; versioned JSON records inputs and scalar/retained-record expected observations per step. Contract adapter maps grid q to6q and binds strict prepared statement hashes.

- [x] Inspect actual Inbox/test helper APIs and document mapped observables/mocked exclusions.
- [x] Export real model-executed overlap, stale checkpoint/nonce, inclusive deadline and old-domain proof scenarios; do not copy guards into Python expectations.
- [x] Validate schema/provenance and deterministic generation; mutation tests reject altered expectations, source pins and skipped steps.
- [x] Replay every public step on actual pinned contracts using one shared compiler output; compare getters/records/revert flags and required effects.
- [x] Independent review plus actual behavioral mutation check; freeze results/commit/worklist or stop on real source issue.

## Task4 M09-A: rollback authority and nonce

**Files:** `formal/etna/EtnaVerifierRollback.tla`, `configs/rollback-*.cfg`, `VERIFIER_ROLLBACK.md`.

**Interfaces:** Explicit unsound-verifier/upgrade boundary distinct from ordinary recovery; retained record/cursor/snapshot, current nonce/generation, confirmations, derived-authority and irreversible payment projections.

- [x] Prepare trusted1/bad2 history and same-block confirmations with opposing restored-snapshot outcomes; define explicit known limitations.
- [x] Implement restore/void/revalidate/revoke/reproof/fee-preservation and stranded-origin fence with actual independent observers.
- [x] Exercise historical-nonce resurrection, one-path-only revocation, confirmation filtering, namespace deletion, forgotten fee-paid and improper landing controls.
- [x] Independently verify normal/positive traces and oracles; explicitly record no concrete corrective-upgrade API as GAP when applicable.
- [x] Review/test/fix gate, local commit/worklist update; no production fix without confirmation.

## Task5 C03: real recovery list and failure replay

**Files:** `conformance/export_recovery.py`, `conformance/recovery_cases.json`, `conformance/solidity/EtnaRecoveryReplay.t.sol`, focused exporter tests and report sections.

**Interfaces:** Consume frozen M08 canonical attempt projection; internal tentative actions map to one real atomic Recover call. Use real Inbox/registry/FI with exact original calldata/auth and distinguish any injected dependency.

- [ ] Export valid mixed lists and invalid late id/key/index/order/failure cases from actual model execution.
- [ ] Materialize valid issued/unheld fixture through real public APIs; compare mapped identities and full unchanged out-of-scope/canonical observations.
- [ ] Run real calls and check before/after/revert/events and origin/cursor/fee/registry effects, with strict boundary labels for fault injection.
- [ ] Independent source review and actual mutation sensitivity; investigate any source discrepancy before classifying it.
- [ ] Run final accumulated TLC/adapter regression and reused relevant Lean/contract suites; record exact limits, commit/update worklist and stop after five.
