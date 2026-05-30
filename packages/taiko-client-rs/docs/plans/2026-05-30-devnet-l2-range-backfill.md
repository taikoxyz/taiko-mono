# Devnet L2 Range Backfill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an explicit checkpoint range backfill mode so a local alethia-reth node can import historical L2 blocks from a remote RPC without relying on devp2p range sync.

**Architecture:** Keep the existing `--l2.checkpoint` behavior unchanged by default. Add a boolean driver flag that, when enabled, makes beacon sync fetch every remote full block from `local_head + 1` through the sampled checkpoint head and submit each block through the existing Engine API payload path.

**Tech Stack:** Rust, clap, alloy providers, Taiko Engine API sidecar, taiko-client-rs driver sync pipeline.

---

### Task 1: Add Backfill Target Selection

**Files:**
- Modify: `crates/driver/src/sync/beacon.rs`

**Steps:**
1. Write unit tests for single-head mode and range-backfill mode target selection.
2. Add a small helper that returns the remote block numbers to submit for a local/checkpoint pair.
3. Run the targeted `driver` beacon tests.

### Task 2: Add Runtime Configuration

**Files:**
- Modify: `crates/driver/src/config.rs`
- Modify: `bin/client/src/flags/driver.rs`
- Modify: `bin/client/src/commands/mod.rs`

**Steps:**
1. Add `l2_checkpoint_backfill: bool` to `DriverConfig`.
2. Add `--l2.checkpointBackfill` / `L2_CHECKPOINT_BACKFILL`, default `false`.
3. Wire the flag into `DriverConfig::new`.

### Task 3: Execute Range Backfill

**Files:**
- Modify: `crates/driver/src/sync/beacon.rs`
- Modify: `crates/driver/src/metrics.rs`

**Steps:**
1. Reuse the existing remote full-block fetch and `submit_remote_block` logic.
2. In backfill mode, submit blocks sequentially from local head plus one to checkpoint head.
3. Accept non-invalid forkchoice status after sequential imports.
4. Set the checkpoint resume head after the sampled range is fully imported.

### Task 4: Verify

**Commands:**
- `cargo test -p driver sync::beacon::tests`
- `cargo test -p client flags::driver`
- `cargo check -p driver`

