# Etna current-rule interleavings implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task by task. Preserve this plan's ledger and all prior evidence.

**Goal:** Check seven newly specified recovery/switch interactions at exact f556 without transferring historical evidence or inventing implementation correspondence.

**Architecture:** Add small immutable Python transition models and a bounded complete explorer. Each independently reviewable task supplies literal source-based witnesses and guard-removal controls; a separate final source/behavior gate covers all seven.

**Tech Stack:** Managed Python, standard library, existing unchanged pure encoding helpers where explicitly needed.

**Spec:** `docs/superpowers/specs/2026-11-20-etna-current-rule-interleavings-design.md`; normative `packages/protocol/docs/etna/{SPEC,ACCEPTANCE,SWITCH}.md` at `f556fa94186b0ab604573e8d3a4c4d4fa835dc84`.

## Global Constraints

- Existing source-only ledger/claim inventories/old models/configs/pins and historical evidence stay unchanged.
- Models are finite selected rule checks; runtime, cryptography, EVM atomicity, economic deployment and actual finality are explicit premises or WAITING.
- One implementation writer at a time; independent source review and behavioral verification before publication.
- No network/keys/signing/dependencies/production/SPEC/Notion/live/merge/ready or automatic eighth.
- Declare complete finite action banks, retain actual accepted/refused edges and shortest witnesses; a cap, missing witness or unrelated failure cannot pass.
- Source receipts compare exact three raw document streams; metadata selection never asserts execution.
- Keep all artifacts portable; use configured inputs and temporary paths rather than personal directories.
- Each test establishes its repository-relative import root and passes standalone unittest discovery from `formal/etna` under isolated `-I -S -B`; no wrapper or prior-test path leak is assumed.

## Review Focus

- A generation-matching schedule after rollback is legal if other guards hold; no schedule nonce exists. Z01 tests this separately from stale-generation refusal.
- A permanently issued withdrawn bond is distinct from the replacement in its old slot. Z02/Z03 observe both full records and lifetime flags.
- A commitment can authenticate a noncanonical trailing-empty list. Z04 changes both root and count/list and still requires refusal.
- Successful recovery can finish R with no eligible committee. Z05 must exhibit the safe non-signing outcome, without inventing a recovery veto.
- Latch/guest/node checks and temporary/permanent split configurations differ. Z06/Z07 must retain those legal states and the exact source/operation/deadline guards.

### Task 1: Z01 generation-bound schedules

**Files:** Create `formal/etna/current_rules/__init__.py`, `explorer.py`, `source.py`, `governance.py`; test `formal/etna/tests/test_current_governance.py`.

**Interfaces:** `Refused(ValueError)` denotes a modeled atomic refusal. `explore(initial, actions, step, check, *, max_states)` returns immutable visited states, accepted edges, refused edge observations and shortest paths; raises on a cap or failed check. Model modules expose immutable `State`, `initial()`, `actions(state)`, `step(state, action)`, `check(pre, action, post)` and named witness predicates. `source_identity(raw_by_path)` delegates exact classification and requires f556, returning SOURCE_REVIEWED / runtime NOT_EVALUATED. Later models consume only explorer and Refused; they do not import each other's transition logic.

- [x] RED tests use an explicit missing-module assertion, then literal expected schedule tuples; no import-error credit.
- [x] Implement START-10.1-5a/b/c, RECOV-8-31/32/47a and 8.3 guards for schedules, recovery and rollback. Bound g=0..2, c=0..2, nonce=0..3, rules=0..3; use maxAnchorAge=1296 and offer timestamps0,1,2,1296,1297,2592,2593 plus uint48 edge tests. The action generator omits valid transitions leaving these exploration bounds, tagged as model bounds rather than protocol refusals. Protocol uint48 arithmetic is checked separately. Use a finite named input bank rather than an uncontrolled Cartesian bank; retain distinct refused edges without copying whole paths.
- [x] Observe complete schedule/g/c/nonce and emitted update values: stale updates/cancellations do nothing; carry and next+1 structural recovery; exact minimum lead and strict cancellation equality; same-generation post-rollback schedule remains possible. Origins and landed-prefix details are out of this projection.
- [x] Exhaust the declared graph with all witnesses; remove expectedGeneration guard in a disposable model copy, detect a stale write, restore and recheck. Independently inspect rule correspondence and behavior before marking complete.

### Task 2: Z02 permanent bond forfeiture

**Files:** Create `formal/etna/current_rules/forfeiture.py`; test `formal/etna/tests/test_current_forfeiture.py`.

**Interfaces:** Same pure model protocol as Z01; additional public `penalty(balance,bps)` and `bounty(balance,bps)` use exact integer arithmetic, uint256 bounds and inclusive validUntil. Principal/key/slot/forfeiture identities are separate fields.

- [x] RED literal scenarios for two issued IDs sharing a slot over time, third unissued ID, pending stake, nonintegral rounding and failed transfers.
- [x] Model STAKE-4.1-13a/27/28/34 and FORF-4.4-1..20 with closed initial principal14 across one bond and an external owner reserve: seeds (eff9,pending4,reserve1), (eff4,pending9,reserve1) and (eff4,pending0,reserve10), forfeit3333bps and bounty1000bps. The third permits topUp9 after authorization; the second actually debits pending. Separate 9500bps/one-unit arithmetic cases cover self-report-cheaper and rounding boundaries. Independent transactions include top-up/activation, forfeit, slash/self-report, confirmation/withdraw/reuse, nonce invalidation/recovery; preauthorized forfeit survives the latter two. Signature validity, caller authority and EVM atomicity are explicit inputs/premises.
- [x] Check full per-ID/slot state, pending-ready/exit/confirmation/flag, sink/reporter/owner balances and conservation on all selected interleavings. Failure/reuse cannot retarget old ID or clear its flag. Refusal preserves events/state; self-report ordering uses real ceil/floor and includes pending funds.
- [x] Exhaust a declared finite bank with positive live/withdrawn/reused/deadline witnesses, omit lifetime-ID binding or effective-first deduction in a disposable copy, detect intended differences and restore. Independent source/behavior gate.

### Task 3: Z03 exclusions and recovery replay

**Files:** Create `formal/etna/current_rules/recovery.py`; test `formal/etna/tests/test_current_recovery.py`.

**Interfaces:** Independent immutable registry/exclusion/FI projection, shared explorer only. `recover` inputs include caller, expected generation/c/nonce, deadline, ordered bond/FI lists and structural rules.

- [ ] RED on withdrawn-issued acceptance, unissued-tail refusal, unsorted/duplicate bond and FI lists, stale generation/c/nonce, deadline equality and nonce overflow.
- [ ] Model RECOV-8-38..50, 8.3-1..19 and 8.4-3..5. Bound three permanent issued IDs/two slots plus an unissued ID, two FI entries, two generations and nonce0..3 as an exploration limit, not a uint256 refusal guard. Separate literal tests exercise uint256 maximum and no wrap. FI head/tail, original timestamps/enqueue block/fees and fixed prior origins are explicit. No signature/whole-landing-audit implementation is invented.
- [ ] Complete-call validation precedes effects: an invalid later FI/id leaves every field/event unchanged, an already-withdrawn exclusion preserves earlier exit and replacement, FI blank keeps metadata/fees/head, only recovery increments generation and writes own immutable origin. A separate successful forfeit remains when a later independent recovery fails; no cross-transaction rollback.
- [ ] Explore and retain shortest positive/reject histories, omit issued-id or nonce guard in a disposable copy, detect and restore. Independent source/behavior gate. Atomicity remains a modeled transaction premise.

### Task 4: Z04 minimal positional snapshots

**Files:** Create `formal/etna/current_rules/snapshot.py`; test `formal/etna/tests/test_current_snapshot.py`.

**Interfaces:** `canonical_entries(slots)` returns the shortest positional tuple through the highest occupied slot. `validate_snapshot(entries,count,root)` validates canonical shape then unchanged Registry encoding. `select(entries,snapshot,config,expected_config_hash)` authenticates the complete configuration before reading its one immutable minStake value. Standalone arithmetic may remain parameterized, but the selected admission path must reject a one-word minStake disagreement that changes eligibility. Reuse only unchanged `registry_snapshot.entries_root`/pure keccak helpers; preserve their sources.

- [ ] RED vectors: no slots→count0/root0; three slots with hole; occupied zero-stake last entry; highest withdrawal→shrinking count; slot reuse; count>4096; exact threshold and floor power.
- [ ] Apply STAKE-4.1-36, COMM-4.3-2..5, START-10-12/14 and ENC-A-36..38. Preserve indexed hashed interior vacancies and raw-zero tree padding. Reject trailing/all-empty positive counts even when their matching root is supplied. Bind minStake to fifth config ABI word; minStake≥vp_unit, no independent s_min override.
- [ ] Enumerate all occupancy patterns for three slots plus independently encoded literal public-key/Q=10^23/minStake=4Q vectors; historical snapshots immutable. Real deployment/economic constraints remain separate.
- [ ] Remove trailing-occupied guard in a disposable copy, prove that matching-root malformed witness passes the mutant and fails baseline, restore. Independently derive roots/config bytes and gate source/behavior.

### Task 5: Z05 final-R selection

**Files:** Create `formal/etna/current_rules/final_snapshot.py`; test `formal/etna/tests/test_current_final_snapshot.py`.

**Interfaces:** Independent symbolic finite state model; Z04 actual byte admission is separate. Explicit tx-local registry state, block-close snapshot, fixed R, authenticated finalized view, derived committee and last-landed snapshot. No hash/signature claims from symbolic keys.

- [ ] RED with recovery and matured top-up/independent standby forfeiture/withdrawal-reuse ordered within the same R, as permitted by the guards. Excluded bond cannot activate top-up. Selection before block close refuses.
- [ ] Implement STAKE-4.1-36, COMM-4.3-2..8, RECOV-8-17..19/49/51..55 and 8.4-9. Bound three IDs/two slots and R=7/R+1=8; threshold4, unit2, topup1 are arithmetic model units, not deployed economic parameters. Track complete block-final snapshots and immutable older snapshots.
- [ ] Demonstrate different tx-local prefixes with the same final R entries select identically; R+1 mutation cannot change R; recover leaves slot284 unchanged until a modeled valid landing; accepted recovery with nonzero count but empty eligible set remains non-signing. Valid proof/signature/finality are premises.
- [ ] Explore all finite orders; private fault substitutes recover-time snapshot or permits selection before close, require discrimination/restoration. Independent source/behavior gate.

### Task 6: Z06 permissionless proven-origin latch

**Files:** Create `formal/etna/current_rules/origin.py`; test `formal/etna/tests/test_current_origin.py`.

**Interfaces:** Independent branch-local immutable model of Unzen core, forwarded checkpoints, one-time start, FI readiness and finalized trust. Latch, node and guest predicates remain separate public methods.

- [ ] RED: public callers, uninitialized/open-cutoff/not-all-proven/missing/wrong checkpoints, duplicate latch, before/after proof same block, forwarding before and after start, reorg then canonical latch.
- [ ] Model START-10-5/5a..5d/6, LAND-6.1-8a, PROOF-6.2-46a, SYNC-9-5a and RECOV-8-27/28. Bound S=1/2, one pending/finalized proposal and two canonical branch candidates; fork100/cutoff88 and times87/88/99/100. Caller supplies only S; use nonzero symbolic hashes/roots as authenticated premises.
- [ ] Start writes all coupled fields/FI0 once, preserves Unzen checkpoint; forwarder closes for every height once latched. Reorg discards whole orphan branch; signer requires own finalized start and local fork compatibility. A legal latch can fail node/guest checks; local override mismatch alone is not a guest rejection. First-landing rollback preserves original start and Unzen checkpoint.
- [ ] Exhaust declared branches; omit all-proposals-finalized or finalized-start trust guard in private copy, detect/restoration. Independent source/behavior gate.

### Task 7: Z07 replacement deadlines and acknowledgment

**Files:** Create `formal/etna/current_rules/replacement.py`; test `formal/etna/tests/test_current_replacement.py`; add batch README and selected evidence summary after gates.

**Interfaces:** Independent bounded two-chain/bridge model with explicit phaseA sent-message identity, L2 implementation, acknowledgment, L1 installed schedule, canonical finalized proof and signing readiness.

- [ ] RED: exact operation/schedules/chain IDs/source/target ack; NEW/RETRIABLE; wrong predecessor; old matching observation before deadline; multiple sent deadlines; unsent phase A still authorized.
- [ ] Model SWITCH section7 Moving the fork time and START-10-5d. Use A=10,E=20,B=30,C=40 and second E=25; require A<E<B≤C, strict A/E/B execution bounds, timestamps immediately before/at each boundary. Fixed old/new fork100/200, FI margin60, proposal margin12, modeled old-schedule release budget70 (so B=min(40,100−70)=30), and new lead80>60; authentication/available proof and rollout estimates remain premises, not measured facts.
- [ ] Preserve reachable temporary L2-new/L1-old split; phaseB accepts only exact finalized acknowledgment before B plus new lead/unwritten start/old config. Missed B remains split with signing closed. Old-date release requires same proven old-implementation/old-getter block covering every sent E and every unsent phase A cancelled/expired. Multiple old messages cannot overwrite newer implementation through predecessor bypass. Successful upgrades serialize through phaseB; multi-sent deadline cases belong to abandoned/unexecuted branches, not concurrent successful upgrades.
- [ ] Exhaust finite NEW/retry/deadline/abandon permutations; remove exact-op or all-deadlines guard privately, detect/restoration. Independent source/behavior gate and complete current-rule README with precise limits.

## Accumulated final gate

- [ ] Fresh whole-range adversarial review by an independent reviewer plus independent behavior/source-identity/guard-control audit; investigate all material findings and recheck fixes.
- [ ] Run focused and ordinary suites in a reviewed disposable offline snapshot; record actual counts, no fabricated native/TLC/production claims. Re-fetch current main and compare effective merge when source bytes move; older source obligations never silently gain credit.
- [ ] Update only verification WORKLIST/REPORT/README and existing PR/issue body scoped prefix after code gates. Review full diff/path hygiene, normal commit/push on existing draft, read back exact head and complete changed bodies/CI. Return to feedback-only at seven; no eighth.
