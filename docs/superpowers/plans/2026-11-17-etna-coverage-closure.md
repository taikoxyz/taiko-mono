# Etna coverage closure implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Execute five coherent increments, independently review and verify each, then report.

**Goal:** Make remaining verification obligations actionable and test selected real restart/handshake and stop/recovery composition boundaries.

**Architecture:** One current work index, an isolated TLC/Python CI gate, selected stock Go boundary replays and thin compositions over existing model actions.

**Tech Stack:** Configured Python stdlib, Java17+/TLC release1.7.4, pinned Go/CometBFT0.40.0, installed Docker for hosted CI and existing native isolated supervisors/caches.

**Spec:** `docs/superpowers/specs/2026-11-17-etna-coverage-closure-design.md`.

## Global Constraints

- Start at6057aee347f4865830593f1775e99b4f4822f96c on the existing draft branch; previous F01-F05 are complete and must not restart.
- SPEC d18357214fab30ea512ae9858a11699806d72ba1; contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c; stock Comet0880b4d378f347ab16e54ec677ff50d803f37d62; preserve369 old configs and historical experiments.
- TLC jar SHA256936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88. No new SDK/package installations or duplicate physical caches.
- Isolated offline execution of inspected inputs; no host home/Git/secrets/keys/signing/broadcasts. Generated executed copies and modfiles must match expected bytes before and after execution.
- Root owns WORKLIST/README/REPORT, shared inventory/cohorts, issue/PR updates and runtime state; implementers own task-specific files only. No nested agents; one implementation writer at a time.
- Independent spec/quality review and behavior verification per task; intended failures only, exact nonempty identities, actual restoration; two material fix waves maximum and no unresolved material findings presented as passing.
- Existing PR feedback first. No production/SPEC/Notion edits, merge, ready conversion, deployment or sixth increment. User already authorized task-list maintenance and these next five; no redundant approval pause.

## Review Focus

- CI silently omits cases or skips drafts: G01 must show failure for an omitted/changed expected result and run the complete discovered default suite.
- Successful MemDB getters are mislabeled durable: G02 must reopen real disk state from another process after abrupt child termination.
- Empty blockstore bypasses an assumed height check: G03 must observe that actual branch and distinguish its success from complete restart consistency.
- An old proof is never queued or fails only on expiry: G04 requires queue/attempt/terminal witnesses and a live-reference generation fault.
- A copied signer gate or vacuous no-sign path hides stale work: G05 calls actual M03 actions and requires pre-recovery work, post-recovery refusal and fresh-domain exposure witnesses.

### Task 1: G01 — exact-outcome CI

**Files:** create `.github/workflows/protocol--etna-tlc.yml`, `formal/etna/ci.py`, `formal/etna/tests/test_ci.py`; hosted repair adds `formal/etna/ci_container.py` and `formal/etna/tests/test_ci_container.py` for the installed Docker runtime lifecycle, preserving the gate/classifier. Root updates WORKLIST/README.
**Interfaces:** `ci.py --java PATH --tlc-jar PATH --output-dir PATH` calls existing check.py with the whole discovered config set and stdlib test suites. It verifies the pinned jar before execution, records child statuses/logs and returns nonzero on any required failure. Do not reimplement TLC result parsing.

Hosted-repair ruling: actual `uid_map` refusal prevents this runner using the
local namespace launcher. Replace only CI isolation plumbing with the installed
Docker backend described in the design, preserving all checks and signal
semantics. Validate actual full Python/rules, real TLC and same-UID complete
artifact reads, failure/timeout cleanup and unrelated-resource preservation
before new hosted readback. No global kernel/LSM policy changes or hidden
unsandboxed fallback are permitted.

- [x] Write and run red tests for wrong tool hash, failed child, empty/missing default coverage and stale output handling; keep tests behavioral with disposable fake child tools where appropriate.
- [x] Implement the minimal gate; inspect existing runner tests and preserve check.py behavior and all existing source inputs.
- [x] Add draft-enabled PR/main triggers for formal files, workflow and normative docs; read-only permissions, credential-free checkout, pinned existing action commits, bounded job/download/execution, checksum verification and failure artifacts. Separate network tool preparation from offline code execution.
- [x] Execute the actual full default TLC/Python gate locally in the existing namespace and independent negative/omission controls; distinguish actual GitHub CI from local validation until its run is read back.
- [x] Independent source/quality review and behavioral verification; root formats, reviews tested bytes and publishes the reviewed increment before G02. Final hosted44014380640 at9798a68fa passes369 exact outcomes/208 tests, reconciliation, output checking and both artifacts; complete raw/diagnostic archives read back.

### Task 2: G02 — persistent stock Bootstrap restart

**Files:** new `formal/etna/conformance/comet_restart/` module/test inputs, focused `run_comet_restart.py`, `tests/test_comet_restart.py`, `COMET_RESTART.md`; reuse existing supervisors/source manifests, not a second process-control engine.
**Interfaces:** selected native test identities and JSON observations over real GoLevelDB, with completion readiness bound to the child process. Collector accepts only complete expected leaves and exact phase diagnostics; `--scenario persistence` is the initial campaign. Keep a clean extension point for G03 handshake test identities without changing old Bootstrap evidence.

- [x] Inspect actual stock Bootstrap writes and selected disk backend; define the exact observable field/row table and a public-only literal state fixture. Record missing App/EL and power-loss premises.
- [x] Implement red controls for missing durable history/state and no-ready/wrong-child/failed worker outcomes. Use an independent process to Bootstrap, stop/kill only after its explicit completed-write receipt, reopen the same disk directory and compare literal fields/rows.
- [x] Execute isolated stock original/faulted/restored campaigns with one exact upstream write omission; read back all original source entries and actual restored bytes. Never edit the module cache or original source.
- [x] Reject skipped/missing/duplicate identities, wrong reason, added failure diagnostics and generated input drift; verify shared canonical cache/layout and cancellation behavior through existing supervisor contracts.
- [x] Independent source/quality review and actual disk/process behavior verification; format before final tested freeze and publish only reviewed bytes. Independent three-phase campaign and12 actual DB read-only reopen checks pass at the nine frozen file hashes.

### Task 3: G03 — stock handshake height/AppHash boundary

**Files:** extend only new `comet_restart/` test module and `run_comet_restart.py` scenario table, its focused tests and COMET_RESTART docs. Do not modify old run_comet/bootstrap helpers.
**Interfaces:** `--scenario handshake` invokes actual `HandshakeWithContext` through the stock exported API, using explicit observed Info/replay calls. Reuse G02 process/source recording and exact-output handling; G02 identities remain regression cases.

- [x] Build a literal state/blockstore/app-height matrix including empty blockstore equal/mismatched AppHash, nonempty app/state ahead refusals, and a consistent no-replay case. Declare ABCI application responses as a mock boundary, never actual EL durability.
- [x] Assert exact typed/error and call-count behavior. Confirm the empty-blockstore shortcut directly instead of assuming it validates all heights; investigate any actual SPEC requirement mismatch before classifying it.
- [x] Add a single actual upstream AppHash-check fault whose unexpected success is caught by the intended leaf; normal/restored pass. Require complete stable native source/tool/input hashes.
- [x] Independently verify the actual matrix and source mutation/restoration, plus old G02 persistent readback; format and review the complete task diff before publication. Independent current-code handshake and persistence three-phase campaigns,33 fresh-stream negatives and source-drift refusal pass at the eight frozen hashes.

### Task 4: G04 — positive-stop queued proof handoff

**Files:** create `EtnaStopProofHandoff.tla`, `STOP_PROOF_HANDOFF.md`, focused `configs/stop-proof-*.cfg`; preserve existing candidate/schedule/settlement engines. Root owns added inventory/cohort rows.
**Interfaces:** expose `StopProofVars`, `StopProofInit`, `StopProofNext` and actual queue/attempt/terminal receipts to G05. Reuse existing settlement `PrepareProof`/landing and schedule/recovery actions; selected positive due/future/off-grid stop programs now reach a recorded old-proof attempt after actual recovery with its reference still live. Preserve all old program/config meanings.

The inherited proof record has no reference-age field. Availability of its
otherwise-valid proof/reference is an explicit fixed environment premise, not
a measured retention or M07 resource result; do not invent an expiry check and
then claim it exercised the existing action engine.

- [x] Demonstrate the old positive-stop cases never queue/attempt a proof, then add minimal selected programs or action enabling needed for the missing composition.
- [x] Audit immutable queued input and generation/origin/reference/prefix after recovery; require queue, recovery, attempted-refusal and terminal witnesses so green safety cannot omit the path.
- [x] Execute a live-reference missing-generation-binding source fault with the exact independent property failure, original/restored success; disabled queue/attempt must lose its required witness.
- [x] Independently review/verify all affected old/new handoff profiles, actual terminal values and preserved old configs. Update finite assessed scope honestly and publish the reviewed increment. New10/old43, actual shared generation fault, missing-action restoration and six full terminals independently pass; early-support seam fixed and rechecked.

### Task 5: G05 — actual signer action composition

**Files:** new `EtnaHandoffSigner.tla`, `HANDOFF_SIGNER.md`, focused `configs/handoff-signer-*.cfg`; use a namespaced INSTANCE of unchanged EtnaSignerCrash and the reviewed handoff interface. Root owns shared inventory/cohorts.
**Interfaces:** bind signer state variables distinctly from handoff variables, invoking actual Request/Persist/Expose/Crash/Restart/recovery-floor actions. Document exact mapping of authenticated recovery and trust restoration. Never copy an acceptance predicate or treat a stored floor as actual FilePV implementation.

- [x] Define small computed/persisted-before-recovery and restart programs with explicit two-domain/two-slot bounds and actual enabled-action receipts. The handoff's recovery observations drive signer floor adoption; fresh trust remains a stated authenticated-input premise.
- [x] Require old pending work before recovery, refusal of new old-domain exposure afterward, HRS preservation across restart and successful fresh-domain persist/expose under correct trust.
- [x] Use independent raw returned/network/durable observations and meaningful omitted-fence/disabled-action controls; delayed delivery of a signature exposed before recovery is not new post-recovery signing.
- [x] Independently source-review and behaviorally verify actual actions, negative controls, terminal witnesses and all old source/config preservation; publish the reviewed increment.

## Final gate

- [x] Review every remaining-work row and composition against SPEC/ACCEPTANCE and preserved incomplete-search records; synchronize issue22355 without marking whole modules complete.
- [x] Refresh PR feedback/head/CI, freeze final executed inputs, run accumulated exact default TLC/Python/cohort checks and affected actual native/controller lanes.
- [x] Independently review complete batch diff and raw actual results with exact source/tool/mutation hashes, identities and evidence attribution.
- [x] Publish reviewed final report/worklist/PR readback; preserve the active hourly monitor and stop after five for retrospective.

Final evidence: implementation43fe46187fdf0eb5791ac75f840b1a15a49b2e56;
387exact outcomes79normal/308named,68assessed source faults/243raw phase logs,
227ordinary Python+5separate controller tests, both actual native three-phase
scenarios and hosted44030752309 all pass. Independent whole-batch source and raw
artifact reviews pass with no material finding. Closing publication changes
reporting only. Preserve worktree/evidence/hourly feedback monitor; no sixth.
