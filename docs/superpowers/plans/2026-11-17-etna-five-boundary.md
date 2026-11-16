# Etna five-boundary verification implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Execute five coherent increments, review each, then stop for the requested report.

**Goal:** Replace shared positive-premise assumptions with independently checked import chronology, actual receipts/store behavior and nonzero recovery scenarios.

**Architecture:** Extend the existing M10 raw fixtures/audits, export its actual observations, replay selected stock store APIs and add a scripted companion over unchanged M07 actions.

**Tech Stack:** Configured Python stdlib; Java17/TLA+ tools1.7.4(TLC2.19); existing Go SDK/caches; pinned CometBFT0.40.0.

**Spec:** `docs/superpowers/specs/2026-11-17-etna-five-boundary-design.md`.

## Global Constraints

- Base56fc86d482c116df313aabc94ed87c53b537ce08, existing isolated branch/draft PR22387. Exact SPEC/contract/Comet pins in the design remain authoritative.
- User explicitly says continue, five steps, report when done; retain the established delegated implementation/review/test workflow without an additional approval round.
- Preserve350 old configs, old conformance fixtures/pins and incomplete archives. F01/F02 M10 source changes are explicit; other old operational engines remain unchanged.
- Existing tools/caches only, no installations or duplicate build cache; inspect entrypoints, offline read-only execution, disposable outputs, no home/Git/secrets/keys/signing.
- Root owns shared plan/REPORT/ledger/publication; authors own assigned files and preserve others' changes. No nested agents. Independent reviewer/tester inspect the actual request and complete task diff. At most two material fix waves per task.
- Hourly PR checks and confirmed feedback fixes take priority. No production/SPEC/Notion edits, merge/deploy/ready conversion or sixth increment.

## Review Focus

- Constructor and observer agree on time40 although generation genesis is100: F01 independently checks actual successful publication and reachability.
- An authenticated wrong chain/height input is mistaken for a valid positive history or hidden by another binding: F02 singleton fault matrix distinguishes these negative classifier fixtures.
- Empty export or altered landed priorities receives success credit: F03 exact IDs, fresh execution, literal raw/store audit and disabled-publication probe reject it.
- Stock validator lookup silently substitutes priorities/proposer or aliases source through a cache: F04 exact field readback, source fault/restoration and existing layout/lifecycle controls.
- Recovery resurrects resources, old proof authority or an empty origin while a scripted step never runs: F05 raw action enabledness/receipts, live-reference controls and terminal witnesses.

## F01 — positive import chronology and genesis

**Files:** `formal/etna/EtnaCheckpointImport.tla`, new `configs/import-premise-*.cfg`, CHECKPOINT_IMPORT/README and sensitivity inventory/cohorts.
**Interface:** selected non-origin header time102; origin retains old header but installs literal genesis100, first priorities[-2,2]/stored proposer1 and next[1,-1]/proposer2. Independent `PositiveImportPremises` checks actual publication without the shared constructor/helper. The three non-origin current/next pairs must match the selected actual stock two-block prefixes, including coupled power/priority changes; individual priority bounds alone are insufficient.

- [x] Reproduce old non-origin publication40 against genesis100 using an independently appended invariant; record exact source/published trace.
- [x] Repair fixture and literal observer, add origin/non-origin normals and required trust/publication witnesses; preserve350 config bytes.
- [x] Add exact canonical-time and origin-first-proposer source faults to the existing TLC cohort; original/restored pass, each mutant fails PositiveImportPremises. Confirm stock genesis field derivation/readback independently.
- [x] Repair the subsequently confirmed Raw11/20 individual priority-bound premise violations and detect the exact old-tuple source faults; these checks are necessary, and are not evidence of a coherent pair.
- [x] Final fix wave: replace the three positive pairs with actual stock two-block-prefix results, decouple genesis literals, retarget negative fixtures/fault selectors that would become no-ops, and independently detect an individually bounded but incoherent pair. Preserve config bytes and record explicit fixture exceptions.
- [x] Independently review/verify and inspect full diff/hygiene; confirm readiness to commit the reviewed increment including the paired-state supplement (actual publication readback is recorded in the ledger).

## F02 — chain/height input discrimination

**Files:** M10 Raw/domain only, two `configs/import-input-chain-height-*.cfg`, CHECKPOINT_IMPORT and sensitivity inventory/cohorts.
**Interface:** Raw28/29 wrong-chain/wrong-height with only L1 Comet rebinding; raw0 healthy; existing operational/observer definitions unchanged.

- [x] Demonstrate each original guard omission's old-domain survival/masking and justify Reject from SPEC.
- [x] Append two negative fixtures/configs and unique required fault selectors; preserve Raw0..27.
- [x] Run exact normal/mutant/restored trials and independent singleton/cross-input/reachability probes, including authenticated contradiction controls.
- [x] Independently review/verify and confirm commit readiness; do not promote these fixtures to STF validity evidence (actual publication is recorded in the ledger).

## F03 — actual import receipts

**Files:** new `conformance/export_checkpoint_import.py`, `checkpoint_import_cases.json`, `tests/test_checkpoint_import.py`; conformance/model docs.
**Interface:** `etna-checkpoint-import-replay-1`; five exact IDs origin-base/origin-landed-alternate/current-base/current-first-alternate/current-second-alternate, raw source fields plus actual publication stores/durability/trust and pinned provenance.

- [x] Export actual TLC action observations using a temporary wrapper; Python parses values only.
- [x] Freeze exact five receipts and reject omissions/duplicates/alterations/source drift; test fresh --check comparison. Reject duplicate JSON fields at the CLI boundary and verify the temporary executed model/wrapper/config bytes around every run.
- [x] Independently audit every literal field and show disabled publication loses required receipts/witnesses despite green safety.
- [x] Independently review/verify and confirm commit readiness; pass this frozen interface to F04 after publication readback recorded in the ledger.

## F04 — stock bootstrap/store replay

**Files:** separate `conformance/comet_bootstrap/` Go module/tests, focused collector only if needed, tests and COMET docs; reuse existing Comet manifest/pin and supervisor helpers.
**Interface:** exact native subtests consuming all F03 IDs, real Bootstrap/Load/validator/params APIs with raw field observers; original/faulted/actually restored source outcomes and hashes.

- [x] Inspect stock API/serialization/key mappings and define exact selected native IDs; disclose in-memory and symbolic mapping premises before execution.
- [x] Implement the minimum adapter/collector reuse and wrong-field controls without signing; keep old native test discovery/results compatible.
- [x] Execute actual upstream-write fault with exact intended failure diagnostics and real restoration; verify all1659 source entries and consumed receipt/tool hashes.
- [x] Independently review/test failure paths and readback, including rejection of extra failure diagnostics across every mutant output channel. Shared helpers remain unchanged; old-lane reruns were not reopened. Confirm commit readiness; publication is recorded in the ledger.

## F05 — nonzero recovery/proving companion

**Files:** new `EtnaProvingRecovery.tla`, `PROVING_RECOVERY.md`, focused `configs/proving-recovery-*.cfg`, sensitivity inventory/cohorts and README links. Existing M07 source unchanged.
**Interface:** three scripted programs calling actual M07 actions: FreshPresent, FreshAbsent and OldOutstanding. Raw step receipts/expected action results and independent checkpoint/resource/job audits; no duplicate pipeline engine.

- [x] Build explicit settle1/finalize/recover-origin1 sequences; use separate programs to respect two once-used job IDs. Keep old proof reference live to isolate generation binding.
- [x] Add actual completed-script witnesses and absence/late-resource cases; disabled steps or missing terminal receipts must fail gates.
- [x] Add exact wrong-origin, fabricated-resource, generation-binding and disabled-Recover source faults in the existing compatible TLC campaign; normal/restored succeed, exact audit targets fail.
- [x] Independently review/verify and confirm commit readiness, preserving old M07/config bytes and explicit external recovery-macro premises. Implementation publication readback is recorded in the ledger.

## Final five-item gate

- [x] Refresh all PR feedback/head/CI and resolve worthwhile new opinions first.
- [x] Freeze final consumed inputs; run accumulated exact TLC/Python/cohort checks, fresh import/time exports and affected native/store/controller lanes.
- [x] Independently reclassify actual logs/receipts, exact IDs, source/config/tool/mutant hashes and coverage; review complete batch diff and final report.
- [x] Prepare the measured final report and reviewed draft publication. Exact closing commit/push/readback and completion are recorded in the ledger after publication. Stop after these five increments; no sixth is authorized.
