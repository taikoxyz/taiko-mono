# Etna durability and asynchronous compositions implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add five bounded actual-consumer and free-interleaving verification gates for C01/R01/P01.

**Architecture:** Reuse offline native source/receipt guards and source-fault orchestration; extend current models with additive finite products and independent transition observers. Keep actual source authority and pending implementation boundaries explicit.

**Tech Stack:** Existing managed Python, pinned Go/CometBFT, Forge1.4.2/solc0.8.30, TLA+/TLC; no new dependencies.

**Spec:** ../specs/2026-11-18-etna-durability-compositions-design.md

## Global Constraints

- Exactly five new increments O01–O05; prior N04 repair and N/J/H/G/F batches remain complete. No automatic sixth.
- Formal/test tooling only. No production, normative SPEC, Notion, deployment, live chain, merge or ready conversion.
- No private-key access, key generation or new signing. Only existing allowlisted public vote/registration projections may enter execution; never mount the mixed source artifact.
- Pin canonical SPEC d18357214fab30ea512ae9858a11699806d72ba1/blob649548c58d6629dd85143b33efd3644a3bb71509/SHA2564d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b, Comet0880b4d378f347ab16e54ec677ff50d803f37d62 and contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c.
- Reuse reviewed offline isolation, supervisor, exact source/tool/input guards and existing physical cache locks; writable runtime artifacts are disposable and separately attributed.
- One implementation writer at a time. No native/TLC engine before root approves its exact static interface/oracle/argv/hash packet. Do not edit watched inputs while guards run.
- Independent adversarial source review and independent behavioral verification precede publication. At most two material fix rounds per gate and one consolidated final fix wave.
- Expected values must be source/public-input derived before execution. Bind actual attempted inputs, full selected state, history and events, including refusal paths; terminal counters alone are insufficient.
- Same-copy original/fault/restored is required for each selected source control, with the intended semantic failure and real restored positives. Setup errors, accidental panic, timeout, skips and stale outputs get no detection credit.
- Root owns shared REPORT/WORKLIST/README, plan markers, ledger, publication and monitor state. Preserve completed worktrees, raw evidence, input pins and old executable/config bytes unless a named task explicitly owns a shared change.

## Review Focus

- Missing/stale disk state must not be reconstructed from the public fixture; actual state bytes and both process identities are bound (O01).
- Same-result handler refusals must bind the attempted chain/HRS/bytes and exact response/error; retry cannot mutate durable state (O02).
- Zero principal and unchanged final balance can hide overwritten replacement or missing intermediate checkpoint; compare entire histories and opposite schedule (O03).
- Resource loss, cross-source artifacts and suffix-only publication must not be hidden by expected-mask prefilters; observe actual action enabledness (O04).
- Repeated identical returns can be set no-ops; exact pre-durable byte reuse, live recovery and negative eligibility need action-local audits (O05).

---

### Task 1: O01 public FilePV persistence and cached replay

**Files:** Create `formal/etna/conformance/run_comet_filepv.py`,
`conformance/comet_filepv/{go.mod,go.sum,filepv_test.go,pins.json}`,
`conformance/COMET_FILEPV.md`, and `tests/test_comet_filepv.py` under formal/etna.
Modify `formal/etna/tests/test_registry_cases.py` only for its known import issue.

**Interfaces:** Reuse current Comet module/runtime/isolation helpers and public-votes projection. CLI `run_comet_filepv.py --scenario persistence` uses existing source/Go/cache/lock/output/deadline argument conventions. Default scenario is persistence. Produce strict versioned native receipts and actual writer/reader disk handoff, with input hash records including effective go.mod/go.sum. O02 extends the same runner, pins and native adapter; no handler scenario before O02.

- [x] First reproduce qualified unittest import failure, apply a package-aware sibling import without hiding dependency ImportError, verify package and discovery invocations. Keep this prerequisite out of the five-increment accounting.
- [x] Read source reconnaissance and native entrypoints/hooks. Freeze literal public rows precommit_nil (H1000/R0/step3) and prevote_a_r1 (H1000/R1/step2), exact public signatures/canonical bytes, timestamp1700000000/123, JSON fields/mode0600, full expected named cases. Add RED parser/input-drift/missing-output tests before runner implementation.
- [x] Implement same-directory named-file stock file.go plus same-package test adapter only, no upstream tests. Every staged actual source file must byte-match the current guarded private source in each phase, including mutants; bind executed file hashes independently. Stock saveSigned writes state; a separate process reads actual disk bytes and stock decoder into fresh state with nil private key. Host independently validates exact disk field set/base64 signature/hex signbytes/mode and state-path ownership; receipts bind actual request and resulting bytes. No fixture-only reader reconstruction or accidental panic credit.
- [x] Exercise exact and timestamp-only cached nil replay (123→request124→returned123), genuine prevote same-HRS replay/A-B conflict, wrong chain, H/R/step regressions, explicit incomplete-state errors, and unchanged disk/HRS on every reply. Call CheckHRS directly for the designated missing-signature panic and advancing eligibility; no other SignVote panic earns credit. Approve static interface/argv/hash packet, then one valid replay smoke, root readback, then full original/omit-save/restored with exact persistence diagnostic. Independent tester suppresses timestamp restoration and requires the exact cached-time diagnostic, preserving exact replay control.
- [x] Run focused/full ordinary tests, inspect complete diff/path hygiene and actual source restoration; commit only owned files and report full commands/counts/raw hashes/limits. Independent source and behavior gates precede root completion/publication.

### Task 2: O02 stock signer-handler refusals and cached retry

**Files:** Extend O01 runner/pins/native adapter/docs/tests only.

**Interfaces:** Add `--scenario handler`, consuming actual disk state from its own freshly executed writer and byte-identical stock file.go, signer_requestHandler.go and msgs.go in named-file mode. Existing persistence receipts and outcomes remain exact; root relays accepted O01 helper signatures via task brief.

- [x] Read actual handler and message code; add RED strict response/attempt identity tests. Freeze cases: valid nil cached reply; timestamp-only reply; configured/request chain mismatch; H/R/step and genuine prevote conflict refusals; valid cached retry after refusal. Bind actual request protobuf bytes/chain BEFORE the handler mutates its shared vote pointer, loaded disk identity, returned protobuf union/error/Go error and before/after HRS/disk hash.
- [x] Implement real DefaultValidationRequestHandler calls using the rehydrated FilePV; require exact signer-level response code0/description, value-typed zero Vote on refusal and genuine returned public signature on success. A refusal and retry must execute in the same reader state, not independently reconstructed readers. Wrong chain must refuse before replay: typed code0/description unable to sign vote and the exact separate Go chain-mismatch error. Signer-level refusals use code0/err.Error(); cached success has neither error. Preserve these stock distinctions. No transport, synthetic timeout, trusted-session or WAL claims.
- [x] Approve static packet/single positive smoke, then original/remove-sign-vote-chain-guard/restored on same source copy. Wrong-chain branch must become actual cached success under the fault while valid same-chain remains control; no private signer execution.
- [x] Independent behavior challenge alters actual submitted context between same-outcome leaves and/or removes the successful response's Vote in actual source, requiring precise refusal with restoration. Re-run affected O01 persistence normal results and input guards.
- [x] Focused/full ordinary checks, self-review, scoped commit/report, independent source and behavior gates. Root records selected handler correspondence; C01 remains open.

### Task 3: O03 held-zero displacement and late withdrawal

**Files:** Create `formal/etna/conformance/solidity/EtnaRegistryDisplacementCases.t.sol`; extend `run_registry_cases.py`, `registry_cases/pins.json`, `REGISTRY_CASES.md`, `tests/test_registry_cases.py`. If extracting the public vote decoder, own only that extraction in `EtnaRegistryCasesBase.sol` and the N02 `_vote` wrapper in `EtnaRegistryDoubleSignReplay.t.sol`; preserve semantics and rerun affected native N02. No fixture initialization/config changes.

**Interfaces:** Add `--scenario displacement`, exact two independently named schedule leaves and versioned typed per-action journals. Reuse minimal default Registry fixture/full raw observer and existing public projections. The public decoder has one authoritative implementation if shared extraction is needed.

- [x] Read recon/actual ABI, freeze all primary and opposite-order timeline, roots/packed records/logs/cash invariants before execution. Add RED collector cases for omitted displacement, duplicate/missing action logs, wrong old bond/replacement, same-block checkpoint coalescing, wrong generation/snapshot and same-outcome input aliases.
- [x] Primary: public PoP rows0/2 register A4/B4 at10; A topUp5 at12, readiness14; activation at14 gives9; actual Inbox forceExit15; mock snapshot15 confirmation16 and generation1; public historical gen0 conflict pair at17 pays2/7 and preserves exit15/confirmation16; C row4 register4 at17 displaces held-zero slot0, ID2, active19; public zero-withdraw old A18 must preserve C. Include real earlier readiness/coverage/withdraw refusals and full selected equality. Derive exact call contexts, all native logs, closed checkpoint rows/intermediate same-block root and token ledger independently.
- [x] Opposite order: same preparation/confirmation/slash, old zero withdrawal before C registration. Observe real vacancy clearing, hashed empty used entry, new checkpoint/history/activation and no BondDisplaced on C. Keep expected historical differences rather than forcing equal receipts. Supplement immutable old-ID/key hook refusal only if necessary for the selected boundary, not extra increment.
- [x] Approve static packet and one primary smoke, then same-copy original/omit-displaced-holdsSlot-clear/restored. Primary must fail immediately at actual old holds bit after replacement; opposite order remains accepted. Independent tester removes only withdrawal's holdsSlot guard, detects old withdrawal erasing C, and requires opposite schedule still pass plus exact restoration. If shared base/decoder changes, run affected N02 native and verify N03/N04 positives and actual recorder geometry.
- [x] Focused/full ordinary checks, self-review/commit/report; independent source and behavior gates. No positive-principal full-capacity, authentic recovery or deployment claim.

### Task 4: O04 nondeterministic proving arrival/capacity graph

**Files:** Create `formal/etna/EtnaProvingAsyncProduct.tla`, `PROVING_ASYNC_PRODUCT.md`, `products/proving-async/*.cfg`, `tests/test_proving_async_product.py`. Extend `formal/etna/check.py` and `tests/test_check.py` only for optional config-directory selection with unchanged default and existing outcome/module/input-drift logic. Root owns any shared catalog/index edits.

**Interfaces:** check.py gains `--config-dir DIR`, default script-relative `configs/`; resolve an explicit directory to an absolute caller-relative path before subprocess cwd changes, while local modules still resolve at formal/etna root. Explicit product configs use this same runner; do not add all large graphs to default CI. Exact expectation comments and raw result formats are unchanged.

- [x] Add RED config-directory selection/unknown-case/changed-cfg tests. Freeze current semantic bounds and independent literal two origin captures, property equations and decisive witness prestates from reconnaissance. Read full inherited Init/Setup/actions; add no operational model changes.
- [x] Execute only first four current Setup actions, then allow real History/Availability/Complete (matching and cross-source), Publish(full/suffix), Tick, Land, Finalize, PublishAnchor and Produce in arbitrary enabled order. Bounds head3/produces3/time2/U2/window1/ancestry1, variable resources, capacity1/2; no recovery/rewrite/further captures. Restrict suffix offer only to a valid interval, never by expected acceptance. Add finite action-local observers for exact job/package preservation, actual selected-backend enabledness and full-original-range landing; no ever-growing history.
- [x] Reviewed smoke then exact exhaustive capacity1/2 safety queue0 under root-approved cap≤300seconds. Independent witness configs reach cached proofs surviving outage, actual retry, short settlement, long suffix refusal and cap1 full-range refusal; cap2 additionally full re-publication, overlapping second landing retaining prefix, block-end finality/anchor and actual height3 production. Record any timeout/incomplete attempt with zero PASS credit.
- [x] Same-copy selected Complete-availability guard fault requires exact independent enabledness violation in its focused config and original/restored positives. Independent tester changes Land original-range budget to suffix length and requires cap1 refusal audit at frontier1 with BOTH correct long proofs and FULL original long publication of length2; suffix-only data is not this discriminator because full-data equality independently refuses. Preserve full raw effects/input identities and actual prestate witness. Keep fairness/clock and absent in-flight attempt/cancel semantics explicit.
- [x] Focused/full ordinary checks, exact tool/source/config hashes, self-review/commit/report and independent source/raw behavior gates. Default493 input bytes remain unchanged; no progress/throughput claim.

### Task 5: O05 nondeterministic two-rank signer crash/retry graph

**Files:** Create `formal/etna/EtnaSignerAsyncProduct.tla`, `SIGNER_ASYNC_PRODUCT.md`, `products/signer-async/*.cfg`, `tests/test_signer_async_product.py`. Reuse O04 check.py interface unchanged.

**Interfaces:** Additive wrapper over unchanged EtnaSignerCrash, literal current bounds/initial state and exact named independent audits/witnesses; uses O04 explicit config directory.

- [x] Read current Request/Persist/Expose/Crash/Restart/trust/floor/Deliver actions and archived omitted-dimension report. Freeze independent eligibility comparator and pre-durable exact-byte oracle. Add RED cfg/property/completeness tests before wrapper.
- [x] Free actual graph: domain0 rank1/2 × A/B/Nil × salt0/1, fresh domain1 rank1/A/salt0; optional one real recovery including computed/persisted private work, arbitrary actual crash/restart/delivery and uncertainty. Never filter old-domain requests using expected floor. Observe actual Request/Expose/Deliver arguments, same-rank retry choosing incoming different salt (capture the actual call arguments because inherited actualRequest omits salt), durable original bytes and set-idempotent repeated return events; no scripted histories or unbounded journals.
- [x] Reviewed smoke then selected normal graph queue0 within explicit cap≤300seconds. Witness Nil saved before crash then different-salt exact retry, rank2/value/lower-rank and same-rank conflicting Nil/value refusal; live computed and persisted recovery, fresh trust/connect/return plus delayed old already-queued-but-not-delivered delivery; uncertainty rejects new work. Any reduction must state omitted dimensions and retain failed larger attempt.
- [x] Same-copy actual same-rank reuse fault recomputes incoming-salt bytes and must fail exact pre-durable-reuse audit, then restore. Independent tester selects distinct actual conflict/floor guard fault and requires corresponding exact enabledness/exposure violation with a reachable prestate. Replay full raw traces independently; all normal correctness switches remain true.
- [x] Focused/full ordinary checks, self-review/commit/report, independent source/behavior gates. C01/archived searches remain open/inconclusive outside this selected graph; no FilePV/WAL/supervisor or fairness equivalence claim.

## Root-owned final gate (part of these five)

- [x] Evaluate latest head/all feedback/CI first and before publication; fix confirmed scoped issues without waiting for external confirmation.
- [x] Complete per-task independent source and actual behavioral gates, ordinary checks and selected full product/native controls; preserve pre-batch executable/config snapshot and all failed/raw evidence.
- [x] Most-capable independent accumulated new-batch review and separate raw-artifact/behavior audit; one consolidated final repair wave, same finding authors recheck fixes.
- [x] Synchronize shared report/worklist/readme and exact checkbox evidence, explicitly distinguish default CI from opt-in products, fix known import limitation and retain underlying OPEN/WAITING statuses. Commit/push only reviewed draft changes, read back current head/draft/bodies/CI.
- [x] Record five complete only after actual evidence/publication; report all rulings/costs and realistic progress. Preserve worktree/raw ledger and return feedback-only, no automatic sixth.

Final technical/source/raw gates and code publication complete at `9688066f32f230b8c7684be88a0f56bb9cd273f6`.
The single final repair corrected observed-history binding and inherited relative
output handling, with356 ordinary tests and a new-checker smoke plus five actual
selected replays. Existing PR/issue bodies were read back for all five; final
documentation head/CI readback is recorded separately. Preserve evidence and
return to feedback-only; no sixth increment is authorized.
