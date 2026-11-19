# Etna boundary compositions implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task. Root owns shared publication and engine authorization.

**Goal:** Deliver exactly seven new protocol-boundary/model/public-consumer increments after completed W01–W07.

**Architecture:** Reuse the exact source classifier and stable byte adapters; add a reviewed same-domain projection, new versioned compositions and separately scoped native consumers. Current protocol and historical implementation evidence remain distinct.

**Tech Stack:** Managed Python, pinned TLA+/TLC1.7.4, cached Go/CometBFT0.40 and Forge, existing offline isolation.

**Spec:** `docs/superpowers/specs/2026-11-19-etna-boundary-compositions-design.md`

## Global constraints

- Exactly Y01–Y07 plus final gates; old batches stay complete and no eighth starts automatically.
- Base `9abe2590805787569c0aaf6fb528db367482fffb`; current reviewed bundle `2e6763e21bc236cfcda6011d164b32040f9e0c8d`, current main `479bc3db6b5341b72b6e7b9233be5b53d64a574a` at preflight. Re-fetch before publication.
- Formal/test/report changes only; no production/SPEC/Notion/live/deploy/merge/ready, private/mixed fixtures, new signing or dependency installation.
- One implementation writer and one native/cache owner. Root alone owns REPORT/WORKLIST/README, plans/ledger, monitor and publication.
- Preserve old model/config/fixture/native bytes and all raw artifacts. A corrected/new model has its own version and source identity.
- Managed Python and existing pinned offline tools; inspect entrypoints/hooks, RO inputs, disposable RW output, no Git/secrets/network in executions.
- Root reviews exact source/tool/input hashes, modes, argv and bounds before GO. Smoke then bounded full. Java at most1GiB/profile300s; Go/Forge90/isolation100/supervisor110. No automatic retry or budget expansion.
- Independent source and behavioral gates; up to two material fix rounds per gate and one consolidated final review wave.
- Actual valid progress and discriminating same-copy source fault/restoration, plus a different independent fault or dispatch omission. Timeout/setup error/unexpected panic/skip/missing target is INCONCLUSIVE. Y06 may locally capture only its exact source-pinned expected constructor panic at the named API; all other panic remains INCONCLUSIVE.
- Native0+Finished+queue0 means only the exact finite graph exhausted; named12 is existence. No ordinary completeness claim follows from a witness or smaller replacement.
- A supported natural protocol/source defect stops for concrete discussion; verification defects are repaired within scope. Keep R01/P01 and runtime/deployment requirements OPEN/WAITING where unsupported.

## Review focus

1. Preserve exactly offered attempts and primed receipts under projection; a bad self-edge must not disappear with observational history.
2. Old external authorization, generation origin, closed R snapshot and terminal-active selection cannot be silently replaced by current mutable PRE values.
3. Full ordered rule histories and each proof family are checked separately; identical endpoints or capability unions cannot hide an interior omission.
4. Occupied cardinality, authenticated width, empty entry hash and padding are distinct; withdrawn bond identity cannot be reassigned through slot reuse.
5. Constructor acceptance, cache hits and peer suppression are not authentication or cold verification; exact native calls and stateful reads/writes must be observed.

---

### Task 1: Y01 timestamp safety projection and source scopes

**Files:** Create `formal/etna/EtnaTimestampSafety.tla`, `formal/etna/products/timestamp-safety/*.cfg`, `formal/etna/conformance/timestamp_projection.py`, `formal/etna/conformance/boundary_scope.py`, `formal/etna/tests/test_timestamp_projection.py`, `formal/etna/conformance/TIMESTAMP_SAFETY_PROJECTION.md`. Modify only the claim inventory/pin and relevant boundary tests in `current_spec_boundaries.json`, `current_spec.py`, `test_current_spec_boundaries.py`.

**Interfaces:** `reviewed_boundary(workspace_root: Path, fixed_claim_id: str) -> dict` delegates exact three-document classification and fixed `boundary-products` claim selection. Seven IDs are fixed by the design; the shared selector legitimately accepts each. A producer's `projection_receipt(..., expected_claim=None)` binds its fixed claim `timestamp-projection`, actual config/source/raw and rejects a swapped expectation. `audit_projection_source(product_bytes: bytes, wrapper_bytes: bytes) -> dict` binds reviewed source/read dependencies and projection contract. Raw replay uses the unchanged timestamp oracle.

- [x] Freeze original constants, guards, Next/Offers, invariants, source hashes and proof of edge lifting to/from `(s,bad)`; distinguish ordinary safety from witness `seen` predicates.
- [x] RED: projection omitting bad, an old-metadata guard dependency, lost primed receipt/event, swapped known claim at the actual producer and altered old claim rows must refuse. Historical/mixed/unknown workspace still refuses current-only scopes; do not reject a valid different claim at the generic selector.
- [x] Add separate wrapper/config and source-bound attribution. Preserve every old bundle/claim value and the legacy guard; test exact old/new inventories and both effective-workspace variants.
- [x] Root packet/smoke/full GO; compare original/projected small profiles and same-bounds projected StructuralSafety. Actual refused-event/frame source controls must remain visible and restore.
- [x] Independent source proof and different fault/omission audit, focused ordinary checks, commit/publication. If the quotient still times out, keep its safety acceptance OPEN rather than claim original full-state exhaustion.

### Task 2: Y02 repeated recovery at a fixed nonzero c

**Files:** Create `formal/etna/EtnaRepeatedRecovery.tla`, `formal/etna/products/repeated-recovery/*.cfg`, `formal/etna/conformance/repeated_recovery.py`, `formal/etna/tests/test_repeated_recovery.py`, `formal/etna/conformance/REPEATED_RECOVERY.md`.

**Interfaces:** consume `boundary_scope.reviewed_boundary(..., "repeated-recovery")`, unchanged four-word cuts/statement adapter, and existing pure schedule operations where compatible. `audit(text: str, case: str) -> list[dict]` validates complete typed Init/adjacent frames, external authorization and named endpoint; no current-state rewriting of caller inputs.

- [x] Source-map RECOV8.3/8.4 and ACCEPTANCE2; freeze g0..2, previously settled c=6>S, head at most8, at most3 Produce calls and6 L1 advances. Use R1 number32/time101 and R2 number35/time104, immutable origins and explicit finalized-R observation. Use actual initial pending Rules1, first recover rules0, second recover rules2; authorized values must satisfy current nextRules+1. Empty lists and EL-validity are premises; do not claim the Unzen first-landing case.
- [x] RED: stale same-generation nonce after Invalidate, old-generation authorization, R1-only readiness for g2, overwritten g1 origin, incorrect rules0/nonzero reset and changed settled/FI record.
- [x] Implement free bounded actual calls and independent literal observer. Retain g1 suffix/job only as external archived evidence; reset g2 canonical/head to c. G2 first block uses genesis BFT104, empty LastBlockID/LastCommit, carried finalized anchor>=R2 and a distinct generation domain. Keep c/FI/slot284 and every earlier origin unchanged until actual Land.
- [x] Root reviewed smoke/full positive path through g2 Land/finality/next own anchor; primary origin-overwrite fault/restored, independent second-bootstrap/observe dispatch omission.
- [x] Reconsume complete raw trajectories with source scope, exact failures/restoration, independent gates and commit/publication. No end-to-end Q01 closure.

### Task 3: Y03 ordinary multi-rule batch and lossless pause

**Files:** Create `formal/etna/EtnaRuleRange.tla`, `formal/etna/products/rule-range/*.cfg`, `formal/etna/conformance/rule_range.py`, `formal/etna/tests/test_rule_range.py`, `formal/etna/conformance/RULE_RANGE.md`.

**Interfaces:** source claim `mixed-rule-landing`; `resolve_blocks(blocks, authenticated_views) -> tuple[int,...]` derives each block's rule from its own anchor. `audit(text, case)` validates actual schedule/produce/pause/capture/backend/publication/landing frames and ordered range statements.

- [ ] Freeze M=1296/U=4, writes2304→3600 and3888→5184, a valid prior parent3598, four EL times3599/3600/3601/5184 and anchors3456/3456/3600/5184. Attempt the first rule1 block3600 with software0: actual unsupported refusal preserves all live fields. Resume with finalized/retained anchor3456 after software upgrade; the following BFT3600/anchor3600 make literal parent+1=3601. Record witness carry/inherit flags, monotone finalized anchors, full-range reference>=all anchors and landing block>reference. Do not scale away the +1/activation−1 edge. Per-family adjacent-image aggregation/whole-range proving is an explicit premise, not a flat capability union or three-fork ELF requirement.
- [ ] RED: latest-slot historical reinterpretation, endpoint-only backend check, capability-union substitution, lossy pause and illegal anchor/reference/time choices.
- [ ] Implement separately versioned current-rule product and per-backend complete ordered range validation. Guest implementation/proof generation remain outside it.
- [ ] Root packet/smoke/full: actual two activations, unsupported-rule pause/resume, full original range and successful Land; actual one-backend interior-rule fault/restored and different independent latest-anchor/dispatch control.
- [ ] Independent trace/ABI observations and focused regressions, commit/publication; actual client/EL/guest/FI/Unzen deployment vectors remain WAITING.

### Task 4: Y04 real funded pending forfeiture component

**Files:** Create `formal/etna/conformance/solidity/EtnaRegistryFundingReplay.t.sol`, `formal/etna/conformance/registry_funding/pins.json`, `formal/etna/conformance/run_registry_funding.py`, `formal/etna/tests/test_registry_funding.py`, `formal/etna/conformance/REGISTRY_FUNDING.md`. Reuse unchanged public Registry base/token and existing offline Forge helpers; do not change old replay cases/pins.

**Interfaces:** fixed source claim `funded-forfeiture` records actual old implementation identity separately. `audit_journal(receipt: bytes) -> dict` checks every offered actor/call, full selected state, transfer/event order and closed account allocations. Native fixture uses only reviewed public registration PoPs.

- [ ] Inspect complete native setup/call lifecycle and public file allowlist. Allocate exactly15 across A9/B4/public2; inspect all mint sites (token lacks totalSupply), transfers and complete participating accounts/storage. Freeze exact forfeit calldata/executor before topUp. Distinguish timestamp deadline from block-number activation/confirmation/withdrawal clocks.
- [ ] RED: penalty not debiting pending, authorization-time rather than execution-time balance, public withdrawal with pending principal, strict-deadline error, actor/generation metadata aliases and money from an unmodeled account.
- [ ] Implement actual registration/top-up/forfeit/confirm/delay/withdraw journal. Coverage comes from explicit mock setSnapshot, not Land; mock setGeneration is not a nonce/recover call. Use intact-prefix deadline+1 and funded public topUp1 owner-refusal branches (all other guards valid), then A topUp5. After sink5/Registry8, confirm and wait full delay; public pending withdrawal refuses, A gets4. Reuse exactly A's payout4 with a fresh A-owned public PoP/approval, never \_fund/mint again. Preserve lifetime flags.
- [ ] Root source/packet/smoke/full GO; actual penalty-source original/fault/restored. Independent ownership or deadline source control and unchanged-native metadata corruption.
- [ ] Verify balances15 and sink5/owner4, full raw journals, same-source restoration and independent gates; commit/publication. No current Registry or production token/governance funding claim.

### Task 5: Y05 positional snapshots and recovery committee selection

**Files:** Create `formal/etna/EtnaRegistryRecoverySnapshot.tla`, `formal/etna/products/registry-recovery-snapshot/*.cfg`, `formal/etna/conformance/registry_snapshot.py`, `formal/etna/tests/test_registry_snapshot.py`, `formal/etna/conformance/REGISTRY_SNAPSHOT.md`. Root may clarify old symbolic-count evidence without rewriting old model/config/raw bytes.

**Interfaces:** `encode_checkpoint(l1_block:int, width:int, entries:tuple) -> bytes`, `entries_root(entries:tuple, width:int) -> bytes`, `select_committee(entries, snapshot, s_min, vp_unit, n_max, chain_id) -> tuple` enforce exact positional/packed inputs and canonical key order. `audit(text, case)` binds actual lifecycle/close-R/exclusion/Land observations to those byte functions and fixed claim `registry-origin-selection`.

- [ ] Source-map ENC/STOR/STAKE/COMM/RECOV clauses. Use2 slots,3 issued lifetimes plus an unissued test id, L1 blocks1..8 and unit delays. A/B register1, A exit2 effective3, mocked proved terminal snapshot3 lands no earlier than4, confirm4, withdrawal/reuse5, C active/topUp6 and mature7. Close R7 and R+1=8 explicitly, even at the horizon. s_min4/vp_unit2/n_max1 are model execution/selection parameters, not valid governance dispersion or a full authorized RECOV8.1 witness. Concrete byte vectors use Q=10^23 and legal minStake/vp units. Width is authenticated input: operational width2 internal hole plus separate static width3→4 true-zero-padding vector. Leave trailing-empty trimming unspecified.
- [ ] RED: occupied-count prefix, compacted positions, bond-id leaf index, raw-zero internal leaf versus hashed padding, threshold below max(s_min,vp_unit), wrong set-key tie order, ceil instead of floor, withdrawn/unissued conflation and recover-call-time snapshot. Give eligibility (eff3 versus4), tie (distinct keys at eff4) and floor (eff5/unit2 gives2) separately distinguishable vectors.
- [ ] Implement current small lifecycle/exclusion/Close(R)/selection product with exact issuer/slot maps and full atomic list failure. Mature activation before/after recover within R agrees; R+1 cannot alter R. Land uses actual terminal-active snapshot.
- [ ] Root packet/smoke/full actual histories and wrong-occupant/live-snapshot controls/restoration. Independent byte/root encoder plus different selection/exclusion fault or omitted block-close action.
- [ ] Independent source/raw/byte gates and commit/publication. Old native roots may be a labeled unchanged-encoding component; no native current Registry or K01 authentication closure.

### Task 6: Y06 real terminal seen-commit reconstruction

**Files:** Under `formal/etna/conformance/`, create `comet_boundary/public_input.go.txt`, `comet_boundary/terminal_test.go`, `comet_boundary/go.mod`, `comet_boundary/go.sum`, `comet_boundary/pins.json`, `comet_boundary_common.py` and `run_comet_terminal.py`; also create `formal/etna/tests/test_comet_terminal.py`, `formal/etna/conformance/COMET_TERMINAL.md`.

**Interfaces:** frozen `BoundaryProfile` names its files/pins/tests/expected public digest. `run_profile(profile:BoundaryProfile, args) -> dict` reuses existing source/tool/cache/isolation helpers with fixed argv and source/input/output journals. Shared public Go reader hashes the actual buffer before decode. `audit_terminal(receipt:bytes) -> dict` independently validates signed context, exact state/commit/majority/reopened rows and successor outcome. Claim is `terminal-seen-commit`.

- [ ] Inspect constructor, Store/BlockStore, normal ValidateBlock and fixture allowlist. No signer/service startup, private loader, upstream test global or fresh signing.
- [ ] RED: wrong same-height opaque BlockID, wrong domain/index/weight, missing seen AND fallback block commits, constructor-only authentication and metadata aliases with unchanged native bytes. Pin exact expected constructor panic type/reason per subcase; capture only at that API and classify all unexpected panic as INCONCLUSIVE.
- [ ] Native positive: actual public A commit VerifyCommit, Bootstrap/SaveSeenCommit/reopen, consensus.NewState/GetRoundState and normal synthetic successor ValidateBlock. Use independently reopened blockstores and fresh BlockExecutor/uncached successor per A/B branch. Both headers bind parentA; derive each LastCommit from the actually reconstructed A/B votes and record exact child hash/time. Genuine B mismatch records constructor acceptance separately from explicit verifier/successor refusal at the intended guard, with unrelated header/time predicates satisfied.
- [ ] Root reviewed source/packet/smoke/full; exact verification/binding source control and same-copy restoration. Independent different wrong-domain/weight control and full raw/crypto/input readback.
- [ ] Focused checks and independent gates, commit/publication. Opaque parent IDs/synthetic successor are not a complete authenticated import or signed multi-height chain.

### Task 7: Y07 native evidence lifecycle and import markers

**Files:** Under `formal/etna/conformance/`, create `comet_evidence/evidence_test.go`, `comet_evidence/go.mod`, `comet_evidence/go.sum`, `comet_evidence/pins.json` and `run_comet_evidence.py`; also create `formal/etna/tests/test_comet_evidence.py`, `formal/etna/conformance/COMET_EVIDENCE.md`. Consume unchanged Y06 common driver/public Go reader through an explicit staged allowlist; do not alter Y06 pinned inputs casually.

**Interfaces:** claim `evidence-lifecycle`; native receipts record actual pool calls, exact evidence/signatures/hash, historical lookups, persistence, peer height/Send and refusal reason. `audit_evidence(receipt:bytes) -> dict` derives dual-age/gossip/committed/pending results independently.

- [ ] Freeze h1000 A/B evidence, historical header-time and exact transitions: +900/+901 block gossip and duration3599/3600/3601 seconds, cached/cold/startup-pruned cases. Use disposable cold pools. Persist latest state before reopen; continuing-holder versus NewPool-startup pruning need two separately built identical-prefix databases or a durable clone, never the same mutable DB. Assert continuing pending remains before its own pruning Update.
- [ ] RED: conflated gossip/validity ages, vote-time substitution, cold-check state contamination, missed startup prune/committed marker and missing below-window lookup suppression.
- [ ] Implement real Pool/Reactor APIs and controlled peer Send with branch synchronization, not timeout-as-absence. Install/reopen stock committed markers with w>1000. Marked h1000 must perform zero header/validator lookups at h<=w; the unmarked pair must attempt and fail its real missing-h1000 lookup. Record exact pending deletion in both independent pruning branches.
- [ ] Root source/packet/smoke/full GO, actual age or marker original/fault/restored; independent different source edge/control and unchanged-output metadata negatives. All goroutines/processes terminate inside bounds.
- [ ] Verify complete raw outcomes/restoration/input attribution and independent gates, commit/publication. Real P2P trust, authenticated window/chain and atomic multi-store import remain WAITING.

## Accumulated final gate

- [ ] Fresh most-capable whole-range source review and separate raw/behavior audit cover all seven, shared files and coordinator rulings. Repair one consolidated final wave if needed.
- [ ] Relevant ordinary suites and actual current-main merge pass with exact counts/inputs; original historical sources/configs/pins and native restoration are checked. Re-fetch current PR feedback first.
- [ ] Root prepares normal publication; no force push, merge or mark-ready. Record exact pushed head/full PR+issue body readbacks and CI outcome externally after actual execution. Then return to feedback-only; no eighth automatically.

### Y02 source preflight correction

Keep O0 at L1 number25, but use genesisCutoff24 for the initial committee
snapshot and last landed record. Preserve R1(32,101), R2(35,104), c6 and all
existing finite offers. Use maxAnchorAge1296, a historical schedule write at
time98, stop1394 and activation1397; the first recovery clears stop while
preserving still-pending Rules1, and the second recovery installs Rules2.
Allow valid ordinary g0 successors and check their truncation at R1. Apply
first-generation-block requirements only at ownOrigin.height+1. The isolated
old-generation witness uses matching nonce1, alongside the composed trace's
joint old-generation/old-nonce retry.

The confirmed native-argv attribution repair has one shared implementation in
boundary_scope.py, consumed by timestamp_projection.py and repeated_recovery.py.
Companion Y01 path-substitution tests and authentic archived execution readback
are within Y02 repair scope. Preserve old model/config and native raw bytes,
current-only source selection and the trusted execution-collector premise.
