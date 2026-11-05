# Etna Checkpoint Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement authenticated bounded-window app checkpoint import in #22280 and repair other confirmed client discrepancies in the agreed scope.

**Architecture:** Rust authenticates finalized-L1 boundaries, original window data and reconstructed application metadata. A helper linked to unmodified CometBFT writes its stock stores, and an isolated pinned-EL helper verifies local state and installs canonical header indexes. Offline installation coordinates these stores before normal untrusted startup and stock P2P continuation.

**Tech Stack:** Rust 1.95, existing Alloy/tendermint versions, Go 1.27.2, stock CometBFT v0.40.0, pinned alethia-reth database libraries.

**Spec:** `docs/superpowers/specs/2026-11-06-etna-checkpoint-import-design.md` (approved).

## Global Constraints

- Baseline #22280: `91bb1b8d89fa79968ed7306d9bc55124e432fe8f`; normative Etna docs: `589b542de790861efd8b4d9bb0a4b1d066c2685f`.
- Exclude Unzen switching and public EL snapshot tooling; support S=0 and governance recovery.
- Do not fork CometBFT; no implicit app/journal migration, HRS reset or imported signer material.
- No pre-window consensus reads, pre-s EL execution/FI trial or fabricated ancestor hashes.
- Reject bad candidates; missing dependencies remain incomplete; authenticated contradictions safety-halt.
- Original chain_id/InitialHeight; fixed APP_VERSION=1; landed s+1/s+2 priorities and stored proposers.
- Evidence expires only after both 100,000 blocks and 48 h, using stock post-s state when checking s+1.
- Retain dummy-proof development restriction. No merge or deployment. Update existing PR after final verification.

## Review Focus

- Terminal bytes which authenticate but disagree across landing fields must safety-halt (Tasks 1/2).
- Window evidence referring below w must not force a forbidden history read (Tasks 1/2).
- A pruned source must not silently export an incomplete usable package (Tasks 1/4).
- A crash between stores must not admit a mixed installation or signer session (Task 4).
- A checkpoint q more than 255 blocks behind s must resolve through the EL after restart (Tasks 3/5).

---

### Task 1: Stock Comet window verification, export and offline stores

**Files:** Create `packages/taiko-client-rs/tools/etna-signer/internal/checkpoint/` and `cmd/etna-comet-import/`; modify only helper build/packaging scripts as needed.

**Interfaces:** A version-1 JSON stock package contains `schema`, original `genesis` JSON, `blocks`, and `validator_state`. Each block contains `block` (0x-prefixed original protobuf), `commit` (same encoding), and `validators` entries with `key` (0x compressed SEC1) and integer `power`. Validator-state is the strict appendix-A preimage as 0x bytes. CLI `verify`/`install` take this file and separate `--trusted-comet-hash`, `--trusted-el-hash`, `--trusted-val-state-hash`; install takes fresh `--home`. `export` reads an offline stock home, supplied terminal preimage and explicit window bounds. Output is strict JSON with schema, range, full terminal BlockID, terminal time, original identity, resulting set hashes and package hash. Trusted CLI arguments must come from the Rust L1 verifier, never package fields.

- [ ] Write failing tests for native secp256k1eth commits, wrong terminal trusted hash, stored proposer at a switch and preserving original InitialHeight.
- [ ] Run `go test -mod=readonly ./internal/checkpoint ./cmd/etna-comet-import` and record expected missing-feature failures.
- [ ] Implement canonical decode/hash/part-set/commit validation with stock APIs; exact validator-state decoding/hash and stock set construction; fixed consensus params/results.
- [ ] Write window block/validator/param stores and committed-evidence markers, then bootstrap post-s state and verify by reopening stock stores. Never historical `ValidateBlock`/evidence validation for window bytes.
- [ ] Add evidence tests for below-window references, committed duplicates, exact age boundaries and validator lookup at periodic/checkpoint changes; export round-trip and malformed/oversized/trailing input tests.
- [ ] Run all pinned Go tests with race detector. Self-review; return exact files, commands and limitations. Controller integrates commits after review.

### Task 2: Rust authentication, window bounds and app reconstruction

**Files:** Create focused checkpoint-import modules under `packages/taiko-client-rs/crates/abci/src/` (and shared native verification if needed); extend public bootstrap/witness access narrowly. Additional integration in `crates/lander` is allowed where native Comet decoding currently lives. Do not duplicate full validation logic.

**Interfaces:** Expose strict serializable `ImportPackage`, `VerifiedImport`, and typed `ImportError` with candidate/unavailable/safety classes. `authenticate_import(package, params, own_l1)` returns a verified app state, the stock helper package from Task 1 and authenticated EL header/context requirements. Publish actual signatures to the controller before CLI integration. No serialized trusted-state token can bypass verification.

- [ ] Write failing tests from DATA-5.4 vectors: nonlanded/other-generation s, mismatching preimage as candidate, hash-matching contradictory preimage/envelope as safety error.
- [ ] Authenticate own-finalized L1, generation origin and retained checkpoint under existing witness verifiers; recover original genesis/identity; route s=o to the fixed-genesis path.
- [ ] Derive evidence/switch/anchor window bounds and authenticate native Comet/EL chains, each block's own commit and per-height validator hash, without pre-window history or pre-s execution.
- [ ] Reconstruct s+1/s+2 committees and compare landed sets, pending H+2, inherited anchor/rules, FI cursor and post-s app state. Retain terminal Comet/val-state sidecars and needed origin data.
- [ ] Test ordinary/S(t)/S(t)+1/H(t)/recovery boundaries, both evidence limits and rules boundaries, forbidden-read instrumentation, and no need for successor blocks.
- [ ] Run targeted Rust tests and strict library documentation lint. Self-review and report public interfaces and required runtime initialization guards.

### Task 3: Pinned local EL state verifier and header installer

**Files:** Create isolated `packages/taiko-client-rs/tools/etna-el-import/` with its own pinned manifest/lockfile, tests and build script. Avoid adding database dependencies to consensus crates.

**Interfaces:** Source-available local helper `verify`/`install` consumes a complete offline local EL dataset and Rust-authenticated terminal header plus linked header range. It reports schema, pinned build identity, terminal hash/stateRoot, installed canonical-range hashes and durable dataset identity. It must verify complete accounts/storage/code, not trust supplied metadata or an existing trie root. Install operates only on owned staging directories. No downloader, public exporter or snapshot-hosting service.

- [ ] Write failing tests for tampered account/storage/code and absent/corrupt code, incorrect terminal stateRoot and missing ancestor indexes.
- [ ] Use exactly alethia-reth `6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4` and its reth dependency revision for database types. Recompute or cryptographically verify the entire local state and rebuild/check derived indexes.
- [ ] Install real authenticated canonical number/hash and header-by-hash indexes for max(o,s-U+1)..s and 5.3 context. Do not generate dummy genesis-to-s history.
- [ ] Test pinned real provider lookups/restart and first forkchoice finalized q with s-q>255; retain snapshot state for post-s execution/FI.
- [ ] Run helper tests and compile the pinned runtime. Record any unavoidable EL contract limitation with exact source evidence; resolve it before claiming app import complete.

### Task 4: Offline import CLI, durable installation and guarded startup

**Files:** Create `packages/taiko-client-rs/bin/client/src/import/`, `commands/abci_import.rs`; update CLI dispatch/error/flags, app startup guards, helper build/runtime packaging and operator docs.

**Interfaces:** `taiko-client abci-import export|prepare|install|status` orchestrates Tasks 1-3. Store original package plus a typed versioned plan/manifest binding finalized L1 observation, generation/s, immutable inputs, helpers and canonical component paths. Status always has `live_trust=false`. Existing runtime only starts a completed coherent import.

- [ ] Write failing CLI/process tests for unknown schema, interrupted prepare/install and mismatched component identities; HRS and WAL remain byte-identical.
- [ ] Export authenticated app-import packages using stock archive sources; preserve package/preimage availability beyond runtime sidecar pruning.
- [ ] Acquire existing component leases, refuse aliases/live owners/non-fresh destinations, verify local inputs, stage/fsync all stores and publish one completion boundary.
- [ ] On retry, reverify immutable inputs/helpers and current generation; resume only owned staging. On startup reject mixed/incomplete stores before any signer connection.
- [ ] Integrate app post-import state/sidecars without InitChain reset; latest-target trust and existing signer authority/HRS rules still apply. Safety errors durably latch and exit 2.
- [ ] Test crashes across writes and completion, obsolete generation, bad publisher versus safety latch, preserved HRS, older/latest target and stock blocksync continuation.
- [ ] Run native CLI/process, signer and supervisor tests; document exact import/retry/status commands.

### Task 5: End-to-end conformance, bounded resources and PR update

**Files:** Extend `packages/taiko-client-rs/crates/test-harness/`, relevant Docker scenarios, test entrypoint/CI, README/CHANGELOG/operator guide and an inspectable applicable-rule conformance record.

**Interfaces:** Use the preceding public CLI/helpers and stock pinned runtime; all acceptance assertions compare independent full replay with import and subsequent normal consensus.

- [ ] Add Docker differential tests across switch/H+2 and recovery boundaries; import latest and older checkpoints, continue stock P2P/consensus, perform FI skip/restart and a subsequent landing.
- [ ] Demonstrate real evidence behavior, stored proposer selection in later rounds, all required EL indexes and checkpoint q>255 ancestry after restart, and unchanged signer HRS.
- [ ] Record applicable client rule code/tests, independently audit other current in-scope behavior and repair confirmed defects with failing regressions.
- [ ] Measure increasing prefix lengths with fixed necessary window; record real bytes/times/memory/disk and prove no pre-window consensus reads or pre-s execution. Preserve full archive replay and export after sidecar pruning.
- [ ] Run `just fmt && just clippy-fix`, then final `just verify` once on the completed batch; do not suppress failures or substitute smoke tests.
- [ ] Obtain independent task/whole-branch review and fix actionable findings; confirm latest remote head, commit verified changes, push a normal follow-up to #22280 and update its description with exact results/exclusions. Do not merge or deploy.
