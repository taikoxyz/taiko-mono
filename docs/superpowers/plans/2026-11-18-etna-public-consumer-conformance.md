# Etna Public-Consumer Conformance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add four real-consumer assurance gates and complete the19-profile archived-disposition acceptance audit.

**Architecture:** Reuse pinned source, public published inputs and the existing isolated supervisors. Keep native Go, Solidity and historical-model evidence independent; share only typed public fixtures and narrow execution infrastructure.

**Tech Stack:** Existing managed Python, Go/stock CometBFT v0.40.0, Forge1.4.2/solc0.8.30, existing offline dependency caches.

**Spec:** `docs/superpowers/specs/2026-11-18-etna-public-consumer-conformance-design.md`

## Global Constraints

- Exactly five increments N01–N05; preserve completed J/H/G/F. No automatic sixth.
- No production, normative SPEC, Notion, deployment, live chain, real signing, key generation, installation, new dependency or network fallback.
- No security-specific skills/tools. Ordinary source, failure-safety and trust-boundary review remains required.
- All local Git reads use `GIT_NO_LAZY_FETCH=1`; GitHub uses bounded authenticated gh with explicit repository.
- Public-only typed projections; never extract/print/use private fields or mount the mixed published artifact in execution.
- Preserve baseline executable/model/config bytes and prior raw/ignored artifacts. No writing while source/hash guards run.
- Reuse authoritative isolation, supervisor cleanup and physical cache locks; environment-specific paths belong only in runtime configuration/evidence.
- Independent source review and independent behavioral verification; at most two material fix rounds per gate, one final fix wave.
- Keep canonical/scoped SPEC pins and actual contracts/Comet pins from the design. Changed interfaces need root disposition before execution.
- Source faults require exact intended failure plus original/restored positives on the same private source copy; never count setup failure/timeout/skip.
- Root owns shared REPORT/WORKLIST/catalog/publication/ledger. Authors own only their named task files; one implementation writer at a time, no nested agents, no pushes.

## Review Focus

- Negative seconds, uint64 maxima, malformed BlockIDs: freeze each consumer's representability and refusal layer (N01/N02).
- Duplicate identities, wrong power/index or nil signatures: exact native arithmetic and no inflated success count (N01).
- Wrong immutable domain, historical/future generation and same-block new timestamp: real L1 predicate and full cash/state effects (N02).
- Reused slot with different bond ID and mature pending stake at exit: literal roots and correct cleanup/payout (N03).
- Late token failure after writes, stale output or omitted archived row: atomic exact-call retry and closed-schema completeness (N04/N05).

---

### Task 1: N01 actual stock signed admission, quorum and POL

**Files:** Create `formal/etna/conformance/run_comet_signed.py`,
`formal/etna/conformance/comet_signed/{go.mod,go.sum,signed_test.go,public-votes.json,pins.json}`,
`formal/etna/conformance/COMET_SIGNED.md`, and
`formal/etna/tests/test_comet_signed.py`.

**Interfaces:** Consumes existing Comet manifests, isolation/layout helpers and sensitivity supervisor. Produces a versioned strict public JSON projection at `comet_signed/public-votes.json`, independent consumer expectation table in pins/docs, and CLI `run_comet_signed.py --help` describing offline paths/output/deadline. Follow existing native runner argument conventions; later gates consume the JSON bytes, not Python internals or Go verdicts.

- [x] Read the design and the controller-provided public-consumer reconnaissance report; inspect all imported entrypoints/hooks and the public allowlist. Add focused RED tests for strict JSON/schema, duplicate/missing/wrong output outcomes, intended mutant diagnostic and input-drift refusal. Freeze public fields/counts/provenance/hash and role-specific case table before engine execution. Source blob is available locally by ID; never output the mixed artifact or any private field.
- [x] Implement strict projection and native test using actual secp256k1eth, VoteSignBytes, ValidateBasic, Verify, VoteSet, HeightVoteSet and full VerifyCommit. Freeze literal expected bytes from the published rows before execution; distinguish malformed encoding, validation and signature admission. Structural nil uses empty Go BlockID. All23 published rows must compare equal and Verify successfully without signature normalization; ValidateBasic21 accepts and exactly partial_block_id/hash_only_block_id refuse. No published-row exclusion. Signed -1 maps to uint64 18446744073709551615; max_values fits the native bounds. Only separately named supplemental out-of-range probes may be classified unrepresentable. Encode maxima without constructing huge rounds/part arrays or calling SetRound on maxRound. Map each absent partial hash individually to empty bytes.
- [x] Run one valid genuine `precommit_a` smoke under reviewed isolation before other native products. Then exact2/3 rejection,3/4 acceptance,below-threshold controls (heavy signer native sorted index0) and a separate below-threshold nonzero-index profile; independently Verify both signatures in same-block later-time control because native VoteSet rejects that conflict before verification; valid nil zero nonnil-commit power; duplicate/no power-add; A/B,A/nil and same-block later-time conflicts; chain/address/index/H/R/type changes; genuine round1/2 POL. No consensus.State lifecycle, proposals, locks or finalization claim.
- [x] Implement unique actual strict-quorum source fault in a private guarded copy. Run normal/mutant/restored with precise threshold diagnostic and full raw case identities. Add public receipt observations for genuine bytes, key/address, powers, vote counts and POL, not only PASS frames. Keep old executable code unchanged and reuse lower-level isolation helpers without inventing another supervisor.
- [x] Run focused Python tests and native three-phase receipt. Self-review full diff, source/projection hashes, cleanup and path hygiene. Write report with commands, raw paths/hashes, RED/GREEN, exact leaf counts, incomplete cases and limitations. Commit only owned files; independent reviewer/tester follow before task completion. Independent behavior challenge chooses a different actual domain/nil fault and verifies intended failure/restoration.

### Task 2: N02 canonical Solidity bytes and actual double-sign effects

**Files:** Create `formal/etna/conformance/run_registry_cases.py`,
`formal/etna/conformance/solidity/EtnaRegistryCasesBase.sol`,
`formal/etna/conformance/solidity/EtnaRegistryDoubleSignReplay.t.sol`,
`formal/etna/conformance/registry_cases/pins.json`,
`formal/etna/conformance/REGISTRY_CASES.md`,
`formal/etna/tests/test_registry_cases.py`.

**Interfaces:** Consumes N01 public-votes JSON and existing registration.json/manifests. Produces shared minimal abstract Solidity fixture with internal public-PoP registration, actual Registry/proxy, configurable Inbox generation/snapshot, independent raw-state/cash/history observers and exact refusal helper. Reuse existing PublicReplayToken by selective import, never inherit old private/signing test bases. CLI `run_registry_cases.py --scenario double-sign` (later `lifecycle`/`atomicity`) selects exact test contract/leaf identities; shared runner owns offline isolated Forge and source-fault phases. Do not extend historical shared80 mutation accounting.

- [x] Read design, recon and real LibCometVote/Registry/interface/keys source; check all14 pair expectations against SPEC. Freeze exact pair, bytes and per-role counts. Add RED parser/output regressions for wrong/repeated/missing identities, mismatched revert origin, unrelated mutant failure, bad input hash and truncated results.
- [x] Create minimal actual proxy/init fixture with L1=1,L2=167001, literal Inbox0x1111... and Registry0x2222...; deploy Inbox code first. Seed only proxy implementation pointer. Validate immutable getters and published registration digest. Reuse H01 public token contract, preserve H01 files. Define fixture interfaces in docs for N03/N04; do not add unused general token/runtime machinery.
- [x] Compare actual chainDomain/chainId/signBytes against frozen public literals for all Solidity rows; compare common Go-representable rows additionally. Exercise14 pairs fresh, literal six success/six NotDoubleSign/one FutureGeneration/one InvalidSignature as design. Use effective4+pending4,bounty2500bps,reporter2,sink6. Assert lifetime identity/metadata, exact raw roots/principal/cash/events/refusal equality and no repeat principal. Mock generation stays explicit premise.
- [x] Add one guarded actual-source fault (sameBlock refusal or equivalent independently justified discriminating branch), exact diagnostic plus successful original/restored. Execute reviewed offline Forge, public projection only; record raw JSON, exact leaf frames and behavioral receipts. No recording a setup failure as detection.
- [x] Run focused Python and actual three-phase gate, self-review, commit owned files, write full report. Independent source and behavioral gates include a distinct domain/payout challenge and source restoration. Future lifecycle/atomicity scenario slots stay rejected until their tasks add exact cases.

### Task 3: N03 actual ordinary exit, two withdrawals and slot reuse

**Files:** Create `formal/etna/conformance/solidity/EtnaRegistryLifecycleCases.t.sol`; modify `run_registry_cases.py`, `registry_cases/pins.json`, `REGISTRY_CASES.md`, `tests/test_registry_cases.py`; minimally extend `EtnaRegistryCasesBase.sol` only for this gate's required observers.

**Interfaces:** Consumes N02 fixture/helper API documented in REGISTRY_CASES.md and exact immutable domain; produces `--scenario lifecycle` with exact identities/receipts. Root relays final helper names rather than duplicating fixture setup.

- [x] Add RED tests for omitted lifecycle receipt and wrong intended mutation diagnostic. Independently freeze literal h10/12/13/14/15/16/17/18/20/23/25/26/28 timeline, roots/checkpoint words, token ledger and expected events from design/source before runtime.
- [x] Implement actual two-key registration, mature pending4, exit15 and activation refusal14; owner/repeated-exit and snapshot14/exact15 controls; early withdraw17 refusal then positive8 payout18. Preserve lifetime key; alternate-owner valid old-key PoP refuses. Reuse slot0 with bond2 at20, leaving bond1 slot1 and entryCount2. Preserve empty checkpoint at prior block: slot0 is its canonical hashed zero-field entry alongside live slot1 at count2, never a padding leaf, zero root or empty Registry.
- [x] Exit bond2 at23, confirm26(snapshot25), withdraw28 payout4. Compare independent Merkle/checkpoint roots and all selected raw identity, owner, key, pending, slot, index and cash/event values. Final deposits16,payout12,vault4. No helper assumption bondId==slotId or fabricated full-capacity evidence.
- [x] Add distinct actual exit/reuse guard fault with intended failure and restoration; run exact full scenario three phases under unchanged runtime controls. Independent tester exercises actual wrong-bond-ID cleanup fault using second withdrawal as discriminator.
- [x] Run focused regressions and previous N02 affected gate as required, self-review/commit/report. Independent review/behavior required. R01 full4096 capacity, real token/deployment and other lifecycle products remain open.

### Task 4: N04 late transfer failure atomicity and identical-call retry

**Files:** Create `formal/etna/conformance/solidity/EtnaRegistryAtomicityCases.t.sol`; modify `run_registry_cases.py`, `registry_cases/pins.json`, `REGISTRY_CASES.md`, `tests/test_registry_cases.py`; extend shared base only for necessary complete raw observer.

**Interfaces:** Consumes N02/N03 fixture and strict runner; produces exact `--scenario atomicity` identities and pre/post/retry receipts. The fixture token's real allowance/balance conditions, not a fault switch, cause the normal refusals.

- [x] Add RED parser/receipt regressions for wrong nested token refusal, missing post-state and nonidentical retry. Freeze full selected observer layout including all8192 index cells. Calibrate vm.recordLogs with a minimal emit-then-revert observer control. Actual register \_save/\_commit emits CheckpointWritten before transfer; topUp/token emit after the selected failure. Retained reverted trace entries are allowed and labeled; no claim of committed receipt-log observation and no requirement that failed register trace be empty. Capture exact nested token target/transferFrom calldata and low-level Error bytes with ordered AccountAccess or equivalent actual-call trace; bracket tracing around the call, outside raw observer loops. Require exact successful retry event order CheckpointWritten/Transfer/Registered.
- [x] At fixed block, register with valid public PoP and insufficient allowance; exact refusal, complete selected raw/cash/allowance/transfer equality plus exact calibrated trace observations (which can contain reverted checkpoint events). Approve externally and retry identical bytes; require contiguous ID and one genuine transfer. Verify no checkpoint/identity/index residue from failure.
- [x] Top-up with enough allowance and too little balance; token allowance is decremented before genuine balance failure. Require allowance and full Registry rollback; fund externally, retry same calldata, assert pending/admission increase with unchanged effective stake/history until actual activation. Include neighboring successful bond as untouched control.
- [x] Add guarded actual transfer/liability source fault, intended semantic diagnostic and normal/restored positives. Independent tester challenges a distinct rollback/slot-index observation through actual source. No token callback/withdraw custody/gas claim.
- [x] Run focused Python and actual phases plus affected earlier Registry cases, full self-review/commit/report, independent source and behavior gate. Keep both failed raw runs and restoration evidence.

### Task 5: N05 exact19 archived-disposition acceptance audit

**Files:** Create `formal/etna/ARCHIVED_DISPOSITION.md`, `formal/etna/archived_disposition.json`, `formal/etna/check_archived_disposition.py`, `formal/etna/tests/test_archived_disposition.py`.

**Interfaces:** Consumes tracked archived config inventory and current WORKLIST obligations/evidence; produces closed-schema19-row disposition artifact and read-only checker. Root alone updates X01 status and shared catalog/report after independent semantic review. No archived cfg/model bytes change.

- [ ] Read the controller-provided archived-search reconnaissance report and inspect each19 exact cfg/source association. Add focused RED completeness/duplicate/hash/source-version regression before checker. No superficial assertion of a table copied into code; derive authoritative inventory using existing archived markers/catalog rules and bind independently audited hashes. Include transitive archived model imports: all9 FI rows bind fi-base/EtnaSettlement.tla, rollback binds its own archived EtnaSettlement.tla. Distinguish attested signer predecessor SHA from directly verified historical bytes; never label current source as an unavailable historical source.
- [ ] For signer2/Registry4/FI9/proving3/rollback1, bind path/config hash, historical source identity/version hazard, omitted dimension/property, current actual selected evidence and named C01/R01/F01/P01/Q02 remaining acceptance. Review reductions semantically: no old EXPECT PASS header or unchanged cfg proves graph exhaustion.
- [ ] Implement strict read-only inventory/hash/link check and meaningful missing/extra/duplicate/stale-source negatives. Keep all19 status INCONCLUSIVE. This closes X01 disposition review only, not underlying obligations. Write semantic audit prose sufficient for another reviewer to reproduce the classifications.
- [ ] Run focused Python/checker. Independent reviewer reads the19 configurations and source/evidence associations, independent tester removes/adds/duplicates/stales rows to establish fail-closed tooling. Document that this fifth gate is substantive disposition acceptance, not routine index work, and costs no new state-space exhaustion.
- [ ] Self-review/commit/report owned files. Root then updates shared worklist/catalog/report, leaving outstanding modules OPEN/WAITING as justified; no automatic sixth task.

## Root-owned final gate (part of these five)

- [ ] Recheck feedback/head/base/CI first; fix confirmed in-scope feedback before advancing.
- [ ] Review complete base-to-head diff, preserve baseline executable hashes; fresh affected Python/native/Forge gates and ordinary exact493 TLC/default regressions where justified by shared documentation/catalog integration. Do not silently claim historical80 mutation results as fresh.
- [ ] Independent most-capable whole-diff source review and independent behavioral/raw-artifact audit; one final fix wave, retained failures/restoration. Verify source manifests, public projection mounts, all exact identities and current plan/checklist state.
- [ ] Synchronize REPORT/WORKLIST/README/catalog as actually required; verify formatting, links and completed checkbox evidence. Commit/push normally to existing draft branch only, read back exact head/draft/CI and authorized issue/PR bodies. No merge/ready.
- [ ] Mark all five complete only after evidence/review/publication; retain this plan's ignored ledger/raws. Return hourly monitoring to feedback-only and report progress estimate with scope/limits and all root rulings/costs.
