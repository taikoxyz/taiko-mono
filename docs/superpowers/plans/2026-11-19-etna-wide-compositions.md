# Etna current-rule and wider-composition implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Root authorizes engines and owns shared publication.

**Goal:** Complete exactly seven broader source/model/public-consumer verification increments against explicit current and historical boundaries.

**Architecture:** Version changed rules explicitly, then combine operational state machines with independent action/receipt observations. Reuse the existing isolated pinned runtime and draft branch; no production implementation changes.

**Tech Stack:** Managed Python, TLA+/TLC1.7.4, cached CometBFT0.40 Go APIs, existing offline isolation.

**Spec:** `docs/superpowers/specs/2026-11-19-etna-wide-compositions-design.md`

## Global Constraints

- Exactly seven W01-W07 plus final gates; never restart completed batches or start an eighth automatically.
- Formal/test tooling and associated reports only; no production/SPEC/Notion/live transactions, merge/ready, signing keys, new signing or dependency installation.
- One implementation writer at a time. Root owns shared REPORT/WORKLIST/README, plan/ledger, monitor and publication. Read-only reconnaissance/review may run independently.
- Preserve historical module/config/fixture/source bytes and retained raw artifacts. Add distinctly named current-rule models; source-version mismatches remain explicit.
- Only managed Python and existing pinned offline Go/Forge/TLC tools/caches. Inspect entrypoints; isolated execution has no Git/secrets/network, RO inputs and disposable RW outputs.
- No native/TLC engine before root approves exact interfaces, observations, source/tool/input hashes, argv and budgets. Smoke precedes full GO; no watched-input edits during guards.
- Independent adversarial source review and independent behavioral verification before publication; at most two material fix rounds per gate and one consolidated final repair wave.
- Every selected claim needs actual reachable positive progress, a precise intended-failure control and same-copy source restoration. Missing input/timeout/panic/skip/setup failures are INCONCLUSIVE, not semantic detections.
- Observe attempted inputs and every relevant state/output field independently; also corrupt expected metadata with actual execution unchanged. Expected values must not choose the execution scheduler.
- Queue zero is required for exhaustive safety PASS; named counterexamples establish reachability only. Resource reductions must disclose the omitted dimension and preserve the selected claim.
- Historical native signatures remain public projections only. Never load mixed/private fixture artifacts, call key loaders, advance cached SignVote to new signing, or invoke upstream test globals.
- Initial per-profile TLC ceiling300s; native Go90s/isolation100s/supervisor110s/outer120s. Any changed budget needs a ledger ruling and a new frozen packet, never an unbounded retry.
- A supported actual protocol/source defect stops for discussion; checker defects are repaired separately without inventing a protocol finding.

## Review Focus

1. New main bytes: unknown revisions reject; historical native/model output cannot silently become new-rule conformance (W01).
2. Presence versus balance: full occupied-zero/pending slots reject atomically; two vacancies select the lowest, preserving lifetime identity (W02/W03).
3. Shared-oracle agreement: app replicas, lookup caches, expected pins or poststate-only observers cannot replace real running-state/wire/pre-action evidence (W04/W05).
4. Old work after recovery: immutable job inputs, delayed replies and full original proof ranges cannot gain fresh authority merely because the frontier moved (W05/W06).
5. Vacuous progress: actual capture/arrival/withdraw/landing/stop/recovery actions must be reachable; omitted actions and wrong-grid inherited assumptions are detected (W02/W03/W06/W07).

---

### Task 1: W01 current source boundaries and merge-result correspondence

**Files:** Preserve legacy `spec_authority.py` and `spec_correspondence.json` behavior/identities; update `SPEC_CORRESPONDENCE.md` with explicit historical boundary. Create `formal/etna/conformance/current_spec.py`, `current_spec_boundaries.json`, `formal/etna/tests/test_current_spec_boundaries.py`; integrate actual `run_comet_signed.py`/`run_registry_cases.py` receipt builders and named dependent hashes only. Root owns shared WORKLIST/REPORT.

**Interfaces:** Keep `verify_workspace_spec(raw, authority, ledger)` unchanged and still rejecting2e6763. New `classify_workspace_documents(raw_by_path: dict[str, bytes], pinned_manifest: dict) -> dict` binds exactly SPEC/ACCEPTANCE/SWITCH from one revision with lengths/Git blobs/SHA256. Separate `select_claim(bundle_id: str, consumer_id: str, claim_id: str) -> dict` uses a closed independent selector inventory to bind actual historical implementation/evidence authority and reviewed current disposition. New runner receipts carry explicit workspace and evidence identities; Registry must choose its own claim rather than inherit the signed-vote result. No native PASS follows from selecting a source row. W02-W07 consume this versioned boundary.

- [x] Read complete exact old/current SPEC/ACCEPTANCE/SWITCH differences and affected consumers; create field/rule/consumer inventory with no blanket equivalence. Include terminal/committee-end-only commit verification, evidence expiry/gossip asymmetry and whole-landing recovery audit changes, not only admission/grid/appHash.
- [x] Add failing tests for unknown/one-byte/partial/mixed three-doc bundles, swapped valid claim rows, changed historical→current status, omitted changed consumers, real runner receipt identities and exact current bundle. Reproduce old effective-merge refusal separately from a protocol defect; do not weaken the legacy guard to fix it.
- [x] Implement separate strict bundle classifier+closed claim selector and actual runner-facing receipt attribution, update only named dependent hashes, preserve old guard/canonical/native pins and archived raw identities. Test branch and effective-merge documents through the actual caller, declining unsupported current consumers explicitly.
- [x] Freeze offline ordinary-check/merge-byte packet; independently review source first, then run focused and356 baseline ordinary checks in inspected isolation. Independently corrupt metadata with genuine input bytes unchanged.
- [x] Obtain independent source and behavioral verdicts, inspect full diff/path hygiene, commit; root records changed acceptance boundaries and publishes reviewed draft increment.

### Task 2: W02 current vacancy lifecycle and successive reuse

**Files:** Create `formal/etna/EtnaRegistryVacancy.tla`, `formal/etna/products/registry-vacancy/*.cfg`, `formal/etna/tests/test_registry_vacancy.py`, `formal/etna/conformance/REGISTRY_VACANCY.md`, a narrowly scoped raw transition observer if needed. No old Registry module/config edits.

**Interfaces:** Operational `Register`, `TopUp`, `Activate`, exit/punishment/confirmation/withdraw/tick actions; separate full PRE/POST transition observations and two-way admission enabledness. Consume W01 source identity; produce opt-in safety/witness results and exact current-rule mapping for W03.

- [ ] Audit actual new rules and freeze two-slot/four-ID/time1..8 funded-call scope, complete state fields and independent literal transition equations.
- [ ] Add failing static/observer tests for occupied-zero mistaken vacancy, two-hole order, full refusal identity/cash mutation and unchanged closed snapshots.
- [ ] Implement free current-rule lifecycle with no expected masks/scripts selecting actions; preserve issued/lifetime/slot identity through two reuse events.
- [ ] After exact static packet/source review, run one smoke then bounded original/source-fault/restored safety/witness profiles; independent tester uses a different actual guard fault and action omission.
- [ ] Verify every selected witness/action frame, queue-zero ordinary profiles and source restoration; independent review, focused ordinary regressions, commit and root publication. Keep native current Registry WAITING.

### Task 3: W03 closed-supply capacity and stalled release

**Files:** Create `formal/etna/EtnaRegistryCapacity.tla`, `formal/etna/products/registry-capacity/*.cfg`, `formal/etna/conformance/registry_capacity.py`, `formal/etna/tests/test_registry_capacity.py`, `formal/etna/conformance/REGISTRY_CAPACITY.md`.

**Interfaces:** `minimum_stake(total_supply: int, slots: int) -> int` enforces strict product inequality with nonnegative exact integers; finite operational circulation ledger consumes W02 vacancy semantics. Expose actual reporter/sink/held/liquid movements and snapshot-confirmation frames.

- [ ] Pin exact4096/10^27 arithmetic and normalized supply7/min4 closed ledger; specify permitted penalty/recycling/landing/withdraw actions and omitted real deployment dependencies.
- [ ] Add RED boundary cases equality/below/above, reporter-only full occupancy, conserved cash, and recovery-without-landing confirmation refusal.
- [ ] Implement independently checked aggregate arithmetic and small free capacity product, never asserting saturation impossible or no-sink-return sufficient.
- [ ] Root reviews packet and smoke; run no-penalty/reporter/sink/stalled+progress profiles, actual inequality/confirmation faults and restored positives. Independent tester changes a different balance/occupancy edge and omits real landing.
- [ ] Review full trace accounting/source restoration, run focused tests, commit and publish selected results; actual token/constructor/gas acceptance remains WAITING.

### Task 4: W04 running validator state, sparse lookup and appHash

**Files:** Extend or add a separately pinned profile under `formal/etna/conformance/comet_handover/`; `run_comet_handover.py`; create `formal/etna/conformance/COMET_APPHASH.md` and `formal/etna/tests/test_comet_apphash.py`. No old public corpus/source manifest rewriting.

**Interfaces:** Existing stock MakeGenesisState/private updateState bridge/Store Save-LoadValidators-Bootstrap. New independently derived valStateHash/appHash encoder consumes observed current/next members and stored proposer indices; returns complete ABI bytes and hashes. Sparse lookup is an observation, never running-state oracle.

- [ ] Inspect named stock source/dependencies and bound pure-integer witness search4096 programs/four public members/16 steps; freeze a genesis/update-reachable late-rescale witness before native execution. If unavailable, keep that claim open and record honest narrower evidence.
- [ ] Add RED encoding and receipt binding controls: signed int64 priorities, exact order/indices, identical Merkle hash with changed priority/proposer, header(s) versus post-s AppHash, pin-only corruption.
- [ ] Implement public-only selected native programs and independent Python integer/ABI oracle; observe actual running and reopened sparse/full store rows plus actual stock header AppHash validation.
- [ ] Obtain root packet/smoke/full GO; run original/exact priority or AppHash-guard fault/restored. Independent tester substitutes a different wrong running-state source while retaining keys/powers, and verifies actual bytes with metadata changed.
- [ ] Verify every native/input/source identity and selected Bootstrap continuation, focused ordinary checks, independent source/behavior gates, commit/publication. Real Etna app/import/EL remains WAITING.

### Task 5: W05 actual cached signer framing and retry

**Files:** Create `formal/etna/conformance/comet_transport/` public-only native harness/go.mod/pins, `run_comet_transport.py`, `formal/etna/tests/test_comet_transport.py`, `formal/etna/conformance/COMET_TRANSPORT.md`; reuse unchanged public projection and disk decode interfaces.

**Interfaces:** Actual RetrySignerClient→SignerClient→ListenerEndpoint→protoio→SignerServer→handler→cached FilePV over net.Pipe/finite listener. Capture actual wire attempts/responses, typed versus transport errors, cancellation and durable state. Never call authenticated TCP dialers/private loaders/fresh signing.

- [ ] Inspect full entrypoints/lifecycle and constrain at most10 episodes/three total SignVote attempts; freeze exact nil-precommit/prevote cached allowlist and safe-prevote-only conflict controls (never non-nil precommit) and owned endpoint/deadline cleanup.
- [ ] Add RED tests for request aliases, wrong response union/assignment, truncated reply, typed refusal extra retries, transport exhaustion and cancellation; expected oracle remains independent of wire execution.
- [ ] Implement actual stock endpoint path with public cached disk state and finite pipes; ordinary collector validates all attempts and complete decoded response/state, including refusal paths.
- [ ] Root packet/source review→cached success smoke→bounded original/refusal-branch fault/restored; independent tester alters a different actual response-consumption edge and checks positive/restored episodes. Distinguish shortened deadlines from5s production settings.
- [ ] Verify unchanged disk/HRS/public signature and no owned goroutine/process leftovers, focused regressions, independent gates, commit/publication; trusted reconnect/supervisor/WAL remains WAITING.

### Task 6: W06 arbitrary-height live proving and recovery

**Files:** Create `formal/etna/EtnaProvingRecoveryProduct.tla`, `formal/etna/products/proving-recovery/*.cfg`, `formal/etna/tests/test_proving_recovery_product.py`, `formal/etna/conformance/PROVING_RECOVERY_PRODUCT.md`, `formal/etna/conformance/current_settlement.py`, `formal/etna/tests/test_current_settlement.py`; reuse unchanged eligible operational M07 actions only after W01 review.

**Interfaces:** Actual Capture/History/Availability/Complete/Publish/Tick/Land/Finalize/Anchor/Produce/Recover actions plus independent full frames and two-way enabledness. Two immutable job slots reserve one for fresh generation; no fixed K/grid precondition. New operational cut/range adapter uses only height/EL/Comet/FI and participates in actual Capture/proof binding/Land, independently encoded and versioned; no validator-state proof commitment. Check ordered interior-only leaves, zero leaves for h=p+1, index c-p-1 and checkpoint-FI/record agreement. Symbolic identities alone receive no ABI/Keccak credit. A fixed-range companion offers one immutable large transaction against repeated exact shortest competitors.

- [ ] Freeze source-mapped small unit-height/two-generation/two-job scope, actual recovery fields/resource retention and fresh origin rules; disclose omitted simultaneous third job and real proving dependencies.
- [ ] Add RED action/observer controls for live recapture, retained old job authority, four-word/zero-interior-cut encoding, full original proof data after frontier advance and missing fresh-generation progress. For fixed resources/reference, every interior frontier is reachable, the unchanged long transaction stays admissible while c<h, and each successful competitor strictly reduces h-c.
- [ ] Implement free bounded scheduler/current4-field cut adapter and literal PRE/POST/eligibility observers without expected masks or scripted capture prelude. Add a separate two-old-job profile (no post-recovery reservation) that really captures long+short, lands short to interior c, refuses suffix-only then lands unchanged long with full original data; no three-job claim.
- [ ] Root reviews static packet and smoke; run original/actual recovery-authority guard fault/restored safety and fresh landing witnesses. Independent tester changes one actual FI/Comet component while holding height/other fields fixed, uses a different resource/origin fault, and omits capture/recovery to verify conditional progress sensitivity. The bad overlap prestate must satisfy all unrelated guards.
- [ ] Verify queue-zero safety, decisive reachability/full frames/restoration, focused regressions and independent gates, commit and root publication; full Q01/P02 implementation stays WAITING.

### Task 7: W07 timestamp-only stop through fresh generation

**Files:** Create `formal/etna/EtnaTimestampSchedule.tla`, `formal/etna/EtnaTimestampRecoveryProduct.tla`, `formal/etna/products/timestamp-recovery/*.cfg`, `formal/etna/tests/test_timestamp_recovery_product.py`, `formal/etna/conformance/TIMESTAMP_RECOVERY_PRODUCT.md`.

**Interfaces:** Separately versioned ScheduleRules/ScheduleStop/Produce/Land/Recover actions for current START10.1 and RECOV8; no stopGrid/K in operational state or admission. Consume W06 reviewed unit-height/proof observations where compatible, without copying old schedule implementation. Use one authoritative generation/c/nonce/authorization/deadline/actual execution R, not two copied states. W06 uses a trusted completed-recovery macro only; W07 must actually check expectedC/generation/nonce/deadline and reset schedule on the transaction state.

- [ ] Map exact current timestamp/anchor lead-time/rules/terminal-parent/settlement/recovery rules and current ACCEPTANCE section6 upgrade vectors; freeze finite free interleavings and full phase/frame observations. Bind every covered block to its own historical anchor schedule, actual R and separate observation time. Do not invent a planned-stop prerequisite for general recover.
- [ ] Add RED controls for first-crossing stop, later production refusal, terminal-height landing regardless old grid, nonzero rules recovery and fresh first-block/landing reachability. Require real terminal landing then matching authorized recovery/reset; include stale expectedC transaction-order refusal and correct distinct fresh EL/BFT clocks.
- [ ] Implement minimal separately named current schedule engine and product, keeping old schedule evidence historical and untouched.
- [ ] Root packet/source review→smoke→original/actual parent-time or recovery-reset fault/restored; independent tester mutates a different schedule/terminal-height guard and omits a required progress action.
- [ ] Verify full traces, queue-zero safety, source restoration, focused ordinary regressions and independent gates, commit/publication. Then root performs accumulated final source/raw review and current-merge/CI/body readbacks.

## Accumulated final gate

- [ ] Fresh most-capable whole-range source reviewer and separate behavioral/raw auditor inspect all seven outputs, all root rulings and complete shared diffs; resolve one consolidated final repair wave if needed.
- [ ] Verify final ordinary suites, relevant bounded actual outputs/restoration, unchanged historical baselines, current SPEC/main/PR head and effective-merge boundary. No generated/pin data stands in for a new engine execution.
- [ ] Root reviews all changes and independent verdicts, normal-pushes existing draft, reads back head/PR/issue bodies and exact CI status, records all seven as selected completion and returns feedback-only. Preserve worktree/raw ledger; no eighth.
