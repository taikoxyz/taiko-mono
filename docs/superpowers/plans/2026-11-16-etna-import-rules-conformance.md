# Etna import, rules and conformance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Track actual outcomes per task.

**Goal:** Complete five meaningful verification increments, stop on confirmed real issues or after five for retrospective.

**Architecture:** Thin import/schedule models plus actual frozen-model-to-contract replay. Two owned lanes in the existing formal project/worktree; root coordinates freeze, independent review and reporting.

**Tech Stack:** Existing TLC1.7.4/Java17, configured Python standard library, Foundry1.4.2/Solc0.8.30/Osaka, one shared output/cache; no Rust builds.

**Spec:** `docs/superpowers/specs/2026-11-16-etna-import-rules-conformance-design.md`

## Global Constraints

- Preserve baseline7f1f6f52e, all212 old default cases/model/checker semantics and19 incomplete configurations.
- SPEC d18357214fab30ea512ae9858a11699806d72ba1/blob649548c58d6629dd85143b33efd3644a3bb71509; contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c. Source changes require correspondence review, never implicit repinning.
- No production edits, global installs, new Rust target, push/merge/deploy or live changes. GitHub22355 worklist updates/local commits allowed.
- Reuse isolated worktree and single existing Foundry out/cache; isolated execution requires inspected source, read-only inputs, no original Git/home/secrets, clean environment, network disabled and explicit temp writes.
- Python uses configured user environment; no package installation. Portable artifacts use relative/configured paths and neutral names.
- Root owns sharedREADME/REPORT/plan/worklist; workers own only explicit new files. No nested agents. Parallel model/code lanes are user-authorized and must not revert each other's changes.
- Confirmed actual source issue stops both lanes for user confirmation; model/oracle/adapter defects are repaired separately. Max2coherent review/fix waves per task, independent raiser rechecks fixes. No sixth task.

## Review Focus

- Authenticated contradiction versus corrupt/missing candidate; reject/wait/halt must follow raw authenticated inputs.
- Partial durable imports, wrong store identities and HRS/priority/preimage writes; compare actual state, not readiness flags.
- C04 integer rounding and actual public prehistory: use exact50%/MIN units, affine S=6 grid mapping and literal confirmation95.
- Historical L1 schedule versus L2 time; strict M=1152 equality must survive adapter normalization, zero/max sentinels distinct.
- C06 candidate-valid proof mock versus original-statement mock; a later verifier error cannot certify a Solidity frontier check.

### Task 1: M10-A checkpoint import admission

**Files:** Create `formal/etna/EtnaCheckpointImport.tla`, `configs/import-*.cfg`, `CHECKPOINT_IMPORT.md`; nested historical experiment files only when actually incomplete.

**Interfaces:** Independent raw candidate/L1/store/publication/session inputs and observer receipts; three profiles latest s4/t4, older s4/t6, origin s=o2. Document M02/M03 interfaces without modifying fixed old domains.

- [x] Define raw component domains and expected rejection/wait/halt/publication observations; write exact config expectations before completing behavior.
- [x] Implement bounded candidate authentication, separate durable staging, atomic publication, crash/restart, latest-target admission and immutable signer HRS.
- [x] Include fixed required ancestor/evidence sets, priorities/proposers and EL(s) AppHash; explicitly defer actual importer/full window arithmetic.
- [x] Run exhaustive normals, exact named controls/witnesses; independent pure-store-write/auth-boundary mutation challenges; retain incomplete candidates.
- [x] Independent full-source review/behavior verification, local commit/shared report/worklist update or stop on real issue.

### Task 2: C04 literal displaced and withdrawn recovery

**Files:** Create `conformance/export_recovery_lifecycle.py`, `recovery_lifecycle_cases.json`, `solidity/EtnaRecoveryLifecycleReplay.t.sol`, `tests/test_recovery_lifecycle.py`.

**Interfaces:** Consume frozen M08 PublicAttempt;8 cases from two profiles×two kinds×two failure classes; real public switching chronology and mappings exactly as design. No callback class claim.

- [x] Generate actual M08 receipts with copied-source/jar/config provenance, source drift and full8case validation; add meaningful exporter negative regressions first.
- [x] Materialize exact public history87/92/93/95/97/98/99, oldeff3/pending1/5000bps, fillers5/replacement5 and real confirmation/withdrawal. No planted registry state.
- [x] Compare full mapped before/after public projection, raw filler/replacement/custody and actual withdrawal identity effects; inject only explicitly labeled second dependency failure.
- [x] Execute actual selected methods with same build/cache and at least one independently selected failure/observer mutation; review schema/hash/case completeness.
- [x] Independent source/replay review and focused fixes, local commit/report/worklist or stop on real issue.

### Task 3: M11-A schedule/history model

**Files:** Create `formal/etna/EtnaRulesSchedule.tla`, `configs/rules-*.cfg`, `RULES_SCHEDULE.md`.

**Interfaces:** PublicAttempt schema1 with original operation/arguments/context, actual accepted/reverted result, complete raw before/after schedule and packed event/counter projection for C05. Export L1 projection independently of L2-only candidate observations.

- [x] Pin actual scheduleRules/scheduleStop/recover guards and raw state effects; write exact normal/control/witness expectations.
- [x] Implement sparse-time L1 schedule transitions and atomic failed attempts plus bounded historical anchors/L2 rule and planned-stop selection with separate clocks.
- [x] Check strict equality/cancellation/nonzero S/parent boundary, historical anchor use, unknown rules retry, recovery zero/nonzero schedule effects and packed sentinel boundaries.
- [x] Exhaust bounded normal products; named controls and positive witnesses; independent actual raw-write/old-anchor/mixed-clock mutations.
- [x] Freeze schema/source/config, independent review/test gate, local commit/report/worklist; concrete importer/K-upgrade remains outside scope.

### Task 4: C05 real L1 scheduling replay

**Files:** Create `conformance/export_rules.py`, `rules_cases.json`, `solidity/EtnaRulesReplay.t.sol`, `tests/test_rules.py`.

**Interfaces:** Consume frozen M11 PublicAttempt actual execution. Clock scale1152 with explicit base and zero/MAX48 mapping; L2 heights separately normalized. L2 ruleset support is model-only.

- [ ] Export bounded valid/invalid reschedule, earliest/equality lock, cancellation, stop grid, failed promotion and recover0/next+1 attempts without Python guard copies.
- [ ] Validate complete cases/provenance/fresh outputs and negative regressions; materialize only real public schedule/recovery setup.
- [ ] Compare success/revert, entire schedule, selected packed event, counters/origin and failed state equality; add concrete48-bit/ABI boundary cases explicitly labeled.
- [ ] Run actual methods with shared compiler/cache; independent model time-equality and event/write mutation checks; preserve exact source/hash identity.
- [ ] Independent review/fix gate, local commit/report/worklist or stop on real issue.

### Task 5: C06 landing identity responsibility replay

**Files:** Create `conformance/export_identity.py`, `identity_cases.json`, `solidity/EtnaIdentityReplay.t.sol`, `tests/test_identity.py`.

**Interfaces:** Consume actual unchanged EtnaCheckpointIdentity outcomes and observations. Candidate-statement-accepting mock for contract-frontier tests; immutable-original-statement mock only for labeled binding tests.

- [ ] Export finite overlap/divergent-suffix/frontier-component/origin scenarios with actual action enabledness and records; validate no skipped/mutated cases.
- [ ] Map symbolic cut identities to concrete encoded cuts/real keccak statements, preserving old public originVal versus fresh genesis execution state.
- [ ] Replay real Inbox calls; precise guard rejection and actual proof-binding errors must be distinguished; compare bounded retained records and abort equality.
- [ ] Run selected actual methods and independent guard/mock-masking sensitivity mutant; investigate any mismatch before classifying source versus model premise.
- [ ] Independent review/verification and local commit/report; final stable accumulated TLC/adapter/rule checks and stop after five.

## Execution order and ownership

M10-A and C04 may start together. Model lane then M11-A; code lane may do independent C06 while waiting for frozen M11, then C05. No two authors own the same artifact. Root authorizes only actual API-backed scope; all modeling/data mappings are subject to independent review. Setup/docs alone do not count. Root runs final regressions after top-level modules freeze.
