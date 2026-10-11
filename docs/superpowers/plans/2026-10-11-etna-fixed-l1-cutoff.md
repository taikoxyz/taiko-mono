# Fixed L1 Cutoff Committee Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Update PR #22280 and #22286 to derive committees from fixed authenticated L1 cutoffs and activate them without per-epoch set/land publication.

**Architecture:** The approved design is `docs/superpowers/specs/2026-10-11-etna-fixed-l1-cutoff-design.md`. Protocol V4 binds an authenticated committee config; ABCI derives the target set at the H+2 switch using a fixed cutoff; the lander independently authenticates all sets from L1 registry witnesses. Keep settlement back-pressure and generation behavior.

**Tech Stack:** Rust 1.95, stock CometBFT 0.40, Alloy, Solidity 0.8.30, Foundry, pnpm, Docker.

## Global Constraints

- Client baseline `50dd8723622daac0930ac7a03688102a933f20d1`; approved spec commit `2752272fa700b8afab6d1af1c3152b455ab4a1d9`.
- Protocol baseline `639bae72ba2e69fc44387306d56f9fef7cb6703d`.
- Client worktree `/Users/davidcai/.codex/worktrees/pr22280-review-oct11/taiko-mono`.
- Protocol worktree `/Users/davidcai/.codex/worktrees/etna-fixed-cutoff-protocol/taiko-mono`.
- Do not change back-pressure `height - checkpoint <= d_max - margin_v`, schedule bound `epochLenL2 >= unsettledCap + 3`, generation domains or supersession behavior.
- Preserve unrelated edits and generated bindings. Never reset other worktrees. Generated Solidity fixtures are regenerated, not manually edited.
- Envelope version 2; landing domain `TAIKO_ETNA_LAND_V4`; statement preimage is fifteen static ABI words.
- Config hash encoding is the exact eleven-word `ETNA_FIXED_CUTOFF_V1` encoding in the spec; lookahead 2 and record version 1.
- Inbox slots: status 258; generation 268; committee config hash 269; checkpoint 270-271; genesis 272-274; genesis committee hash 278; genesis cutoff 279.
- No new set transaction, per-epoch L1 committee output/mapping, real guest, snapshot feature, nonce cancellation/replacement, or implicit empty-set fallback.
- Every production Rust symbol requires documentation; public Solidity interface functions use full NatSpec and implementations use inheritdoc.
- Commit only owned paths. No worker may push. Root pushes only after final verification/review.
- Tests use only existing ephemeral devnet keys; never read Secret values.
- Root regenerates client ABI/fixtures after Task 1 is reviewed and before Task 3 starts; Task 4 verifies reproducibility and final provenance.

### Task 1: Protocol V4 and authenticated genesis config

**Ownership:** `packages/protocol/contracts/layer1/etna`, corresponding `test/layer1/etna`, deployment script, layout/gas output for Etna only. Act as the required solidity-tester when writing/running tests. Root owns cross-package docs and Rust fixture generation.

**Consumes:** Approved spec and existing GenesisParams/init/land public interface.

**Produces:** `GenesisParams` retains existing fields and appends `bytes32 committeeConfigHash`; `LandInput` has exactly `lastHeight`, `lastBlockHash`, `lastStateRoot`, `l1ReferenceBlockNumber`; getters `committeeConfigHash()` and `genesisCommitteeRecordHash()`; V4 `hashLandStatement` without a caller-supplied starting committee.

The new hash helper signature is:

```solidity
function hashLandStatement(
    uint64 _generation,
    uint64 _parentHeight,
    bytes32 _parentHash,
    LandInput calldata _input,
    bytes32 _l1ReferenceBlockHash,
    bytes32[] calldata _blobHashes
) external view returns (bytes32 statementHash_);
```

- [ ] Write a regression using a batch crossing epoch boundaries with no records: `_land(_batch(11, new CommitteeRecord[](0)))` must advance the checkpoint; the baseline must fail on missing committee records. Add config-zero initialization rejection, stored config binding, caller independence, proxy/registry changes and V3 rejection tests.
- [ ] Run targeted RED with `FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/EtnaInbox*.t.sol'`; save expected failures to `/private/tmp/etna-fixed-cutoff-protocol-red.log`.
- [ ] Store the nonzero genesis config at slot 269 and genesis committee hash at 278; remove future mapping/event/record writes. Keep SignalService, reference and blob checks. Build V4 from contract identities, its own config and checkpoint, exactly as the spec lists.
- [ ] Rewrite test helpers/vectors around the four-field ABI; independently compute and pin the fifteen-word V4 hash, and mutate every field. Verify verifier failure rolls everything back.
- [ ] Update Etna deployment inputs and NatSpec. Document fixture input use, keeping the dummy verifier explicit.
- [ ] Run `pnpm fmt:sol`, `pnpm test`, `pnpm layout:l1`, `pnpm snapshot:l1`; preserve non-Etna tracked outputs if regeneration makes irrelevant changes. Attempt required coverage and report any tooling limitation honestly. Write exact commands/counts to the report.
- [ ] Self-review and commit owned changes on a new `codex/etna-fixed-cutoff-protocol` local branch; return exact HEAD and ABI/hash encoding. Do not push.

### Task 2: ABCI fixed-cutoff derivation, switch witness and replay

**Ownership:** `packages/taiko-client-rs/crates/abci`, `crates/test-harness`, `bin/client/src/commands/abci_genesis.rs`, `bin/client/src/commands/abci_committee_record.rs`. Other CLI, lander, artifacts and top-level docs belong to later tasks/root.

**Consumes:** Task 1 slot/getter/config encoding; existing committee snapshot verifier and epoch schedule.

**Produces:** These public pure interfaces for the lander:

```rust
pub fn fixed_cutoff(
    schedule: &Schedule,
    params: &ChainParams,
    target_epoch: u64,
) -> Result<u64, CommitteeError>;

pub fn committee_config_hash(params: &ChainParams) -> B256;
```

Keep `verify_committee_witness(parent_anchor, schedule, params, witness, target_epoch)` but make it use `fixed_cutoff`; explicitly reject a cutoff after the proving anchor. Keep the explicit-cutoff verifier for genesis and authenticated host jobs. Update the existing committee-witness discovery APIs to compute fixed cutoffs from target epoch rather than parent anchor.

Core arithmetic:

```rust
if target_epoch == 0 { return Ok(schedule.genesis_cutoff); }
let base = schedule.checked_l1_first(target_epoch.saturating_sub(2))
    .ok_or(CommitteeError::EpochOutOfRange(target_epoch))?;
let lagged = base.saturating_sub(params.cutoff_lag);
Ok((lagged / params.cutoff_grid * params.cutoff_grid).max(schedule.genesis_cutoff))
```

Check zero grid before division and retain existing membership/heartbeat rules.

- [ ] Add RED regressions for parent-anchor independence, exact launch/lag/grid/overflow results, config mismatch and switch-only witness presence. Example: parent anchors 1058 and 1099 with unchanged proven snapshot must yield the same cutoff/record for the same target epoch.
- [ ] Run focused RED with `cargo nextest run -p abci --lib`; retain relevant failures in `/private/tmp/etna-fixed-cutoff-abci-red.log`.
- [ ] Implement fixed cutoff/config hash, slot decoding and genesis verification. Persist config hash in GenesisRecord; reject loading state with a different local config opening.
- [ ] Remove InboxFacts.committee and optional epoch from anchor slot/proof APIs. Genesis reads plain slot 278 and config slot 269. Anchors use four fixed slots and are forced only on moves or H0.
- [ ] Require/derive committee `t` only at switch `H(t)-2`; FinalizeBlock inserts it before generating H+2 updates. Remove landed-record predicates/errors. Keep old/new local state consistency and all back-pressure/generation checks.
- [ ] Move wire version to 2; reject version 1. Keep the same registry/entry/record structure to avoid unrelated representation redesign.
- [ ] Update fake devnet initialization/config hashes; the fake lander advances checkpoints only. Replace missing-record stall test with a switch test with no L1 committee publication. Keep settlement-pause/back-pressure and generation tests.
- [ ] Verify targeted unit and ABCI Docker scenarios including switch, restart and lost-state replay. Workspace verification follows Task 3 integration; report any expected lander compile break explicitly instead of asserting full workspace success.
- [ ] Run formatting and targeted clippy/documentation checks; self-review and commit only owned files, on the existing client local branch. Do not push.

### Task 3: Lander V4 and independent committee authentication

**Ownership:** `packages/taiko-client-rs/crates/lander`, its tests, `bin/client/src/commands/lander.rs`, `bin/client/src/flags/lander.rs`, `bin/client/tests/lander_cli.rs`, `bin/client/tests/support/lander.rs`. Root coordinates generated artifact provenance and cross-package docs.

**Consumes:** Task 1 V4 interface/config slots and Task 2 pure functions/new GenesisRecord.

**Produces:** Authenticated per-epoch witness contexts in PreparedBatch; no on-chain per-epoch mapping or untrusted Comet committee hint as an authority; fifteen-word V4 statement and four-field LandInput.

- [ ] Add RED tests for a batch beginning after a switch, crossing a switch and spanning multiple epochs with no future committee records. Mutate registry/root/config and reject them; keep certificate and next-validator hash boundaries.
- [ ] Run focused RED for lander unit tests and retain expected failures in `/private/tmp/etna-fixed-cutoff-lander-red.log`.
- [ ] Read config slot 269, authenticate it against local opening, and read genesis bootstrap hash at plain 278. Replace `LandingSnapshot.start_committee_record_hash` with committee config binding.
- [ ] Derive required signing and pending committees from fixed-cutoff registry witnesses under authenticated L1 roots covering the cutoff. At a batch checkpoint, the parent's authenticated anchor can prove starting/current/pending snapshots; later switch witnesses are carried by blocks. Include extra proving headers in the verified reference ancestry when another header is used.
- [ ] Preserve certificate, part-set, body, previous-commit and next-validator-hash checks. Deduplicate committee contexts by epoch but retain their witness provenance for the proof request.
- [ ] Remove records hashing/output publication. Keep batch waiting/minimum block thresholds, limits, back-pressure flushes, reference retention and outstanding nonce/journal rules. Reject old incompatible pending journals without deleting or replacing their signed transaction.
- [ ] Use the generated V4 interface and fixtures from Task 1. Match the independent Solidity/ethers V4 vector and mutate all fifteen words/blob ordering.
- [ ] Run client `just fmt`, both `just clippy` passes, `just unit` and all Docker scenarios once integration is complete; record exact results/log paths. Self-review and commit owned changes; do not push.

### Task 4: Fixture provenance, docs, final review and push

**Ownership:** Root integrates scripts, top-level README/CHANGELOG/AGENTS, CI/test entrypoint references, design/plan progress and PR descriptions. A dedicated solidity-tester handles protocol verification and generated layouts/gas reports. Fresh reviewers own read-only review only.

**Consumes:** Verified protocol commit and all implementation reports/diffs.

- [ ] Verify the Task 1 integration pin in `script/gen_lander_artifacts.sh`, `PROTOCOL_REVISION` and provenance checks; repeat `PNPM_OFFLINE=1 script/gen_lander_artifacts.sh <protocol-worktree>` and verify every generated manifest hash/source.
- [ ] Update both READMEs/CLI docs/CHANGELOG around final behavior, fixed cutoff formula, V4 binding, snapshot-history boundaries, unchanged back-pressure/generation and dummy proof limitations.
- [ ] Run fresh client `just fmt && just clippy && just unit && just test`; run protocol formatting/full tests/layout/gas verification. Test new-version restart, lost-state replay, no-landed-committee switches and unchanged settlement outage stall/resume.
- [ ] Generate immutable review packages covering protocol baseline to HEAD and client baseline to HEAD. Obtain per-task spec/quality verdicts and a final cross-repo review; fix all actionable Critical/Important issues and rerun covering checks.
- [ ] Confirm no unrelated files or private data are staged. Confirm current remote heads before pushing; if advanced, reconcile the changes without force pushing.
- [ ] Push protocol HEAD to `codex/protocol-etna-contracts`, then client HEAD to `feat/taiko-client-rs-abci`, after all required checks pass. Verify remote commit SHAs and update existing PR bodies with exact validation and compatibility notes.
