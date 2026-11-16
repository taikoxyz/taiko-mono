# Etna three-increment implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Review each coherent task before proceeding; stop after exactly three new increments.

**Goal:** Check first-block fixture premises, compare the actual stock Comet boundary, and close selected import-authentication sensitivity gaps.

**Architecture:** One existing formal project, a distinct-clock companion with actual TLC receipts, an isolated pinned Go replay, and raw-input-only M10 extensions. Shared fault inventory/cohorts remain authoritative.

**Tech Stack:** Existing Python stdlib, Java17, TLA+ tools1.7.4 (TLC2.19), Go1.27.4 and shared Go caches; pinned CometBFT0.40.0.

**Spec:** `docs/superpowers/specs/2026-11-16-etna-three-increment-design.md`.

## Global Constraints

- Start at reviewed/published d1206bb07. SPEC d18357214fab30ea512ae9858a11699806d72ba1 and contract89f419915de4b73bb57c53bf970f6dea9e8e8c8c pins remain. Preserve existing339 configs and old conformance payload/pin bytes.
- Existing draft PR22387/branch, hourly review checks and old feedback priority. Exactly3 increments, then retrospective; no fourth from a timer tick.
- Separate public dependency preparation from offline execution. Configured Python environment and existing Go/Java/Forge tools/caches; no toolchain install or duplicate cache. Inspect entrypoints; no secrets/Git/live endpoints in execution namespace.
- Root owns plan/ledger/REPORT/publication; each author owns its assigned task. Authors are not alone and must preserve others' changes. No nested agents. Independent reviewer/tester inspect actual source and behavior.
- No production/normative/Notion changes, merge/deploy/ready conversion. Stop on confirmed protocol defects; repair model/tool/adapter defects separately. Maximum2 material fix waves.

## Review Focus

- EL4/BFT3 is wrongly rejected by a universal first-time equality assertion.
- A positive fixture violates its retained-parent or anchor premise, or an observer calls the constructor it checks.
- Removing a required action makes every safety assertion vacuously green.
- Go tests call a local timestamp surrogate, skip discovery, or fail at an unrelated setup/header field.
- Authentication guard masking or incompatible runtime selection makes a campaign appear complete.

## T01 — first-block time model and receipts

**Files:** add `formal/etna/EtnaRecoveryTime.tla`, `RECOVERY_TIME.md`, focused `configs/recovery-time-*.cfg`, `conformance/export_recovery_time.py`, `conformance/recovery_time_cases.json`, `conformance/tests/test_recovery_time.py`; update relevant README and sensitivity inventory/cohorts.

**Interface:** actual TLC observations for exactly the three spec-table cases; schema `etna-recovery-time-replay-1`, separately named BFT/EL fields and raw origin/parent/anchor/generation metadata. T02 consumes this fixture; old exporters/defaults stay unchanged.

- [x] Record RED for collapsed EL/BFT identity on both valid EL4 cases.
- [x] Implement the bounded construction, independent literal audit, exact reachable witnesses and source-fault controls; preserve old models/configs.
- [x] Export actual receipts; reject omitted/duplicate/altered/provenance-mismatched fixtures and compare fresh output.
- [x] Run focused checks, independent review/behavior verification and source/hash readback; confirm readiness to publish the reviewed task result (actual commit/push readback is recorded in Git history and the ledger).

## T02 — actual CometBFT first-block replay

**Files:** add `formal/etna/conformance/comet/` Go module/tests, `comet-pins.json`, `manifests/comet.json`, a focused `run_comet.py`/tests if needed, and reproduction documentation. Do not alter existing global pins.

**Interface:** consume T01 exact receipts; call pinned upstream exported BlockExecutor.ValidateBlock with disclosed evidence-free/seeded-state premises; emit nonempty exact test identities/outcomes and execution logs with source/tool hashes.

- [x] Inspect upstream boundary, source/license/tool requirements; fetch only missing public dependencies with bounded commands, then use offline execution.
- [x] Add meaningful actual-code RED/controls for wrong first BFT time/height/LastBlockID/LastCommit, including valid EL4/BFT3 cases.
- [x] Implement minimal fixture adapter and exact outcome recorder, preserving one authoritative upstream validation path.
- [x] Run original/upstream-time-check-mutant/restored trials, independently review/test and verify original source/caches; confirm readiness to publish the reviewed task result (actual commit/push readback is recorded in Git history and the ledger).

## T03 — import contradiction prerequisite sensitivity

**Files:** extend only Raw fixture constructor in `formal/etna/EtnaCheckpointImport.tla`; add focused `configs/import-*.cfg`; update CHECKPOINT_IMPORT/sensitivity docs, `mutations.json` and `cohorts.json`.

**Interface:** existing Raw, ProvenContradiction/Decision and ObservedClass, exact ClassificationCorrect target, compatible TLC cohort. Original raw0..24 and operational/observer definitions remain unchanged.

- [x] Demonstrate which five branch-specific guard removals survive old inputs or lack inventory coverage; inspect SPEC classifications before defining fixtures.
- [x] Add discriminatory negative raw inputs and positive healthy controls; do not use a contradictory input as normal-progress evidence.
- [x] Execute each guard fault with exact semantic normal/mutated/restored results and update compatible inventory coverage.
- [x] Complete independent source review and behavior challenges; confirm readiness to publish the reviewed task result (actual commit/push readback is recorded in Git history and the ledger).

## Final three-item gate

- [x] Check current PR feedback before final publication; handle confirmed issues first.
- [x] Root verifies one final stable accumulated TLC/Python/fault-cohort result and selected Comet replay/export, input hashes, complete diff and hygiene.
- [x] Complete whole-batch independent review and final report, confirm publication readiness, then push/read back the exact draft head and stop for the three-item retrospective (actual publication is recorded in Git history and the ledger).
