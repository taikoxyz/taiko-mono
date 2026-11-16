# Etna verification sensitivity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Track steps and actual outcomes.

**Goal:** Repair verified input/oracle/progress blind spots and establish repeatable mutation evidence before one bounded handoff composition.
**Architecture:** One fault runner, focused repairs to existing verification, then a thin wrapper over real model actions. Same formal project, pinned sources and shared cache.
**Tech Stack:** Existing configured Python stdlib, Java17/TLC1.7.4, Forge1.4.2/Solc0.8.30/Osaka.
**Spec:** docs/superpowers/specs/2026-11-16-etna-verification-sensitivity-design.md

## Global Constraints

- Startaed1b861e9dfa9b03f2700837bb8e437be55082c; frozen SPECd18357214fab30ea512ae9858a11699806d72ba1/blob649548c58d6629dd85143b33efd3644a3bb71509; contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c/564-entry manifest.
- Exactly V01–V05; stop on confirmed real protocol/source issue, otherwise stop after five. Verification defects are fixed separately. No sixth task.
- Existing286 configs/19 incomplete archives remain; no production edits, push, merge, publication, deployments, live actions, new SDK/dependencies or Rust targets/caches.
- Existing isolated worktree, configured Python, inspected isolated runner and one shared locked Foundry output/cache. Never mutate original contract snapshots. No Git/home/secrets/network in execution.
- Root owns shared docs/plan/worklist/commits and mutations.json integration; authors own explicit task files. No nested agents. Never revert another author's work.
- Maximum2 coherent fix waves/task, independent raiser rechecks. Independent review/behavior gates before local commit; format JSON before final hashes/tests and verify committed bytes.

## Review Focus

- Tool failure/empty tests/unrelated revert mistaken for killed mutation (V01).
- Invalid input blocked by a different guard, falsely credited coverage (V02).
- Success digest compares state to itself or same-value snapshot hides omitted write (V03).
- Fairness assumes success or disabled action makes progress obligation vacuous (V04).
- Historical validity confused with live knowledge/signing/current proof domain (V05).

### Task 1: V01 fault campaign and explicit inventory

**Files:** Create sensitivity/run.py, sensitivity/mutations.json, sensitivity/tests/test_run.py, sensitivity/README.md under formal/etna.
**Interfaces:** load_manifest/classify_tlc/classify_forge/run_campaign; CLI --manifest/--runtime/--only/--output-dir; evidence schema with KILLED/SURVIVED/INCONCLUSIVE/UNASSESSED and exact input/test identities. Runtime external to Git. Later authors return manifest fragments to root.

- [x] Write failing unit tests for false kills: parser error, wrong invariant/assertion, missing/duplicate targets, unsafe paths, empty Forge selection, drift/timeout and failed restoration.
- [x] Implement isolated temporary exact replacement and baseline/mutated/restored execution with locked Forge cache, clean environment and bounded subprocess cleanup; no shell strings/original writes.
- [x] Add reviewed obligations and actual source mutations for the three known gaps; execute real diagnostic campaign and require reported SURVIVED with non-ready exit, not fabricated success.
- [x] Independently review source/classifier and challenge wrong-failure/empty-test behavior; record limitations, local commit/root worklist update.

### Task 2: V02 discriminatory import inputs

**Files:** Modify EtnaCheckpointImport.tla and CHECKPOINT_IMPORT.md; add configs/import-input-\*.cfg; add sensitivity/input_obligations.json if useful. No old config rewrite.
**Interfaces:** Original raw0..15 preserved, new raw inputs/focused configs; independent ObservedClass unchanged unless separately justified by SPEC; proposed source-fault matrix to root.

- [x] Record original40 EL-guard-survivor and new-input discriminator as regression RED, with exact source delta and intended ClassificationCorrect failure.
- [x] Add wrong EL hash and selected coherent binding bundles; map each selected guard to a valid discriminating input/rejection stage, preserving normal/origin/alternate-priority behavior.
- [x] Execute focused normal/negative cases and guard-removal campaign; mark masking/redundancy/unassessed obligations honestly rather than declaring all guards covered.
- [x] Independently review SPEC classification and matrix; root runs selected independent fault, integrates manifest/records local commit/worklist.

### Task 3: V03 successful publication observers

**Files:** Add conformance/solidity/EtnaReplayTestBase.sol or one equivalent shared assertion library; modify five existing Etna\*Replay.t.sol harnesses; dedicated new public-history test under same directory if needed. Preserve fixture semantics.
**Interfaces:** assert expected SignalService(height,EL,stateRoot) and Inbox active snapshot from original mapped call, explicit invocation after every successful actual land/setup; return source-fault fragments to root.

- [x] Reproduce missing-saveCheckpoint survivor against11 selected replays; add assertions so this exact mutant now fails a declared success observer.
- [x] Share the tuple/snapshot observer, preserve all existing model/abort assertions; add wrong-stateRoot and omitted-snapshot source-fault sensitivity.
- [x] Build source-valid public topUp11/activate21/land22(snapshot21,terminal12) probe with explicit mock/initial-committee premises; require actual changed snapshot and complete tuple.
- [x] Execute original/mutant/restored tests under one physical cache lock, compare original564 entries/final hashes; independently review and root verify/commit/update worklist.

### Task 4: V04 conditional connection progress

**Files:** Modify EtnaCheckpointImport.tla observers and CHECKPOINT_IMPORT.md; add thin EtnaImportProgress.tla fairness companion; create nested sensitivity/configs/import-progress\*.cfg, optional new default reachability config(s). Existing safety specification preserved.
**Interfaces:** ImportProgressSpec, independent connection-enabled/reachability property and named eventual-stable-connection temporal property; campaign fragment uses sole named PROPERTY and meaningful counterexample.

- [x] Preserve disabled-Connect40/40 survivor evidence; write new obligation that fails disabled/no-effect connection, not parser or fairness configuration.
- [x] Define benign environment and weak fairness over internal actions, bounded optional crash/restart; require stable eventual connection without assuming result or resource arrival.
- [x] Run original temporal search and both direct mutations, selected original safety/reachability checks; inspect a counterexample/lasso and exact property identity.
- [x] Independent semantics/fairness review and behavior challenge; root integrates final manifest, local commit/report/worklist.

### Task 5: V05 held-candidate handoff

**Files:** Create EtnaCandidateHandoff.tla, CANDIDATE_HANDOFF.md and configs/handoff-\*.cfg; add only HandoffRecovery raw program/NeedsLanding in EtnaRulesSchedule.tla; refresh conformance/rules_cases.json provenance after unchanged38-call export. Existing engine/raw programs/schema unchanged.
**Interfaces:** EXTENDS real M11 action engine; one held candidate at intermediate Ready point, original metadata and captured anchor; separate derivation, authenticated knowledge/signature exposure and inherited proof-enabledness receipts.

- [ ] Define explicit legal hold-before-call/retry-after-call and support/knowledge-ordering witnesses, using existing Promote and new fixture-only HandoffRecovery(scheduleRules1,time2 at1; recover g0,c12,nonce0,validUntil6,rules2 at3; seededc12).
- [ ] Reuse actual Setup/PrepareCall/Invoke and original history audit; preserve historical timestamps/generation rather than filtering old candidates through current-generation ValidCandidate.
- [ ] Add independent historical identity/derivation, at-exposure knowledge fence and current-generation proof-enabledness invariants; no fake STF or copied consensus engine.
- [ ] Exhaust bounded normals/witnesses and selected wrong-latest/cached-auth/relabelled-generation/proof-generation faults; independently review/verify.
- [ ] Root final stable accumulated TLC/campaign/temporal/Python/real replay evidence, committed-byte readback, whole-batch review and GitHub worklist; stop after five and report remaining gaps.

## Order and source freezes

V01 first establishes report/runtime schema. V02 and V03 can then run in owned
model/code lanes; V04 follows V02 in the same model file. V05 follows those gates.
No source changes while a campaign/checker snapshots that source; author scratch
then freeze. Forge executions use a common physical lock across complete trials.
Root performs one final accumulated regression after all top-level TLA freezes.
