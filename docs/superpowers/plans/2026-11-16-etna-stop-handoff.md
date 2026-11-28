# Positive-stop handoff implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Track actual outcomes below.

**Goal:** Make positive-stop candidate/recovery composition observable and compare its L1 calls with pinned real Inbox execution.

**Architecture:** Extend existing handoff wrappers, raw M11 fixture programs and rules replay. Preserve one authoritative public action engine and independent observations. This is one coherent repair with model and real-code gates.

**Tech Stack:** Configured Python stdlib, Java17/TLC1.7.4, Forge1.4.2/Solc0.8.30/Osaka.

**Spec:** `docs/superpowers/specs/2026-11-16-etna-stop-handoff-design.md`.

## Global Constraints

- Start at `2fbe8b366`; frozen SPEC `d18357214fab30ea512ae9858a11699806d72ba1` / blob `649548c58d6629dd85143b33efd3644a3bb71509`; contracts `89f419915de4b73bb57c53bf970f6dea9e8e8c8c` with existing 564-entry inventory.
- No production/normative edits, PR/merge/deploy, new dependencies/SDKs, duplicate caches, or reclassification of incomplete experiments. The user's later instruction authorizes committing and pushing the verification branch without a PR.
- Preserve all 314 old configurations and original 38 C05 payloads/schema/mapping; provenance changes are explicit.
- One existing linked worktree and one physically locked Foundry cache. Original source snapshots remain read-only; execute through inspected isolation with no network/secrets.
- Root owns shared plan/ledger, final evidence and integration. Implementer owns the scoped model/exporter/adapter changes. No nested agents. Preserve others' edits.
- Stop on an independently supported actual protocol defect; repair verification/adapter defects separately. Maximum two material review/fix rounds; original raiser rechecks.

## Review Focus

- A scheduled but not-yet-due stop incorrectly rejects every candidate.
- Off-grid parent treated as a stop boundary, or recovery origin substituted for original S.
- Current cleared schedule relabels a historically stopped candidate as valid.
- Stopped candidate signs after software support despite historical invalidity; knowledge checked at the wrong time.
- New exporter or adapter changes original C05 expectations, silently drops a call, or checks actual state against itself.

### Task 1: Close positive-stop composition with actual L1 replay

**Files:**

- Modify `formal/etna/EtnaCandidateHandoff.tla`, `EtnaRulesSchedule.tla` (raw fixture additions only), `CANDIDATE_HANDOFF.md`, `README.md`, `REPORT.md`.
- Add focused `formal/etna/configs/handoff-stop-*.cfg` and sensitivity inventory entries.
- Extend/reuse `formal/etna/conformance/export_rules.py`, its tests, and `solidity/EtnaRulesReplay.t.sol`; add a separate public export config and `stop_handoff_cases.json`.
- Refresh `conformance/rules_cases.json` provenance only, plus relevant conformance documentation.

**Interfaces:**

- Consume existing `Setup`, `PrepareCall`, `Invoke`, `PublicAttempt`, `ExpectedStop`, history audit and existing rules replay observers.
- Add exactly the three programs/candidate metadata in the design, sharing raw fixture construction where appropriate. Original public action bodies remain unchanged.
- Existing exporter default API/CLI/38-case fixture remains compatible. Add an explicit stop-handoff profile with a separate schema/fixture, 3 programs/9 calls, reusing receipt extraction and validation rather than copying acceptance logic.
- Existing handoff programs keep their exact behavior. New profiles may parameterize hold/final-call index and immutable candidate metadata; use independently captured raw inputs in assertions.

- [x] Record RED evidence: existing 19-case handoff suite misses complete stop removal; original M11 workload catches the same mutation. Add meaningful failing checks for the new due/future/off-grid scope before repairing coverage.
- [x] Implement the three bounded normal profiles with independent historical identity/stop and signature observations. Keep generation knowledge asynchronous and original opaque-proof scope separate.
- [x] Add exact negative controls and positive witnesses named for the design's stop/recovery/support/knowledge boundaries. Exhaust normals and inspect counterexamples; no parser, timeout, setup or unrelated assertion counts as success.
- [x] Run source-only faults for stop omission, premature stop, candidate-time substitution, missing grid check, recovery-origin grid rebasing, current cleared stop and signing-gate bypass with normal/mutated/restored phases. Integrate only verified exact failure identities into the existing mutation inventory. These exact source campaigns are the negative controls; duplicate alternate action implementations are unnecessary.
- [x] Export 9 actual new public receipts and add one real replay test reusing existing setup/state/event/abort helpers. Preserve default 38 C05 calls; compare original semantic fields before accepting provenance refresh.
- [x] Add targeted exporter/profile regressions for omitted/duplicate calls and profile/provenance mismatch; run focused Python tests and fresh export comparisons.
- [x] Run selected actual replay and source faults under the common lock. Independently inspect/test code before execution. Retain command/log hashes and verify all 564 original entries before/after.
- [x] Self-review complete diff and path hygiene. Report exact owned files, hashes, commands, results and limits to root; no commit until independent review/behavior gates.
- [x] Root dispatches independent adversarial reviewer and tester, investigates findings, and original raiser rechecks repairs.
- [x] For mixed Forge workloads, document compatible explicit runtime/`--only` cohorts; regression-test their exact disjoint coverage and expected test-set compatibility. Run every assessed required ID across the cohorts, record stable input/source identities and aggregate evidence, and never label subset readiness as full-inventory success.
- [x] Root runs one final stable accumulated TLC/config and Python regression, selected real replay, rule/index checks and full source/provenance readback; confirms readiness for the authorized branch commit/push without a PR.

## Progress and authority

The user explicitly requested formal takeover after the prior five-task stop.
This plan continues that authorized verification work and the existing technical
architecture. The model/replay scope above is the root's bounded implementation
choice, not a new protocol decision. A later queued task is taiko-infra-mono PR51,
to be inspected after this increment completes.

## Verified outcome

339 exact TLC outcomes pass, including 52 queue-empty normal searches; all 41
assessed required faults are killed across compatible TLC36/Identity3/Rules2
cohorts; 13 actual replay test identities, 118 Python tests and 640 rule-reference
checks pass. Both material verification-tool findings are repaired and rechecked
by the original independent reviewer, including all 132 raw fault-phase logs.
Independent behavioral verification also passed. No protocol defect is confirmed.
The root commits and publishes this reviewed result on the existing branch; Git
history and the final handoff identify its published SHA. Actual client/CometBFT/EL
and real proving remain outside the verified scope. No further Etna increment is
started automatically.
