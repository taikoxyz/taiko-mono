# Proposer Retry Migration To `base-tx-manager` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace proposer-local L1 proposal retry logic with upstream `base-tx-manager`, while also landing the non-engine manifest gas-limit fix from `proposer-rs-retry`.

**Architecture:** Keep Shasta proposal construction in proposer-owned code, but move nonce management, resubmission, fee bumping, and receipt polling behind a small proposer adapter backed by `base-tx-manager`. Treat upstream blob/EIP-4844 support as a hard prerequisite: if the selected upstream revision cannot send blob transactions, stop and surface the blocker instead of retaining local retry logic.

**Tech Stack:** Rust, Tokio, Alloy, `base-tx-manager`, Clap, workspace integration tests via `just test`

---

## File Structure

### Files to Modify

- `Cargo.toml`
  Add any missing workspace-level dependencies needed by `base-tx-manager` and pin the upstream crate revision.
- `crates/proposer/Cargo.toml`
  Add the proposer crate dependency on `base-tx-manager`.
- `crates/proposer/src/lib.rs`
  Export the new adapter module.
- `crates/proposer/src/config.rs`
  Add the small proposer-facing tx-manager config surface and any translation helpers.
- `crates/proposer/src/error.rs`
  Add error mapping for tx-manager failures if needed.
- `crates/proposer/src/proposer.rs`
  Remove proposer-local retry ownership, integrate the adapter, and keep the outer proposer loop behavior.
- `crates/proposer/src/transaction_builder.rs`
  Land the manifest gas-limit fix and, if needed, return a proposer-owned built-transaction type instead of only a raw `TransactionRequest`.
- `bin/client/src/flags/proposer.rs`
  Add or reshape proposer CLI flags so they map to a small tx-manager-backed config surface.
- `bin/client/src/commands/proposer.rs`
  Wire CLI flags into `ProposerConfigs`.
- `crates/proposer/tests/shasta_propose.rs`
  Update integration expectations for the tx-manager-backed send path.

### Files to Create

- `crates/proposer/src/tx_manager_adapter.rs`
  Hold the proposer-owned boundary to `base-tx-manager`, including config translation and send-result mapping.

### Tests To Add Or Expand

- Unit tests in `crates/proposer/src/transaction_builder.rs`
  Cover the non-engine manifest gas-limit derivation.
- Unit tests in `crates/proposer/src/tx_manager_adapter.rs`
  Cover config translation and proposal-to-tx-manager candidate translation.
- Integration tests in `crates/proposer/tests/shasta_propose.rs`
  Keep successful proposal coverage through the new path.

## Task 1: Verify Upstream Blob Support And Pin The Dependency

**Files:**

- Modify: `Cargo.toml`
- Modify: `crates/proposer/Cargo.toml`
- Reference: `docs/superpowers/specs/2026-03-28-proposer-rs-retry-base-tx-manager-design.md`

- [ ] **Step 1: Inspect the target upstream revision for blob support**

Check the selected `base-tx-manager` revision for a send path that accepts blob-capable transaction candidates instead of rejecting them.

Look for evidence similar to:

```rust
match candidate.blobs.is_empty() {
    true => { /* type-2 path */ }
    false => { /* type-3/blob path */ }
}
```

- [ ] **Step 2: Stop immediately if blob support is absent**

Do not write local proposer retry code as a fallback.

Run: record the blocker in the work log / thread summary
Expected: a clear stop condition such as `Blocked: selected base-tx-manager revision rejects blob transactions`

- [ ] **Step 3: Add the pinned upstream dependency only after blob support is confirmed**

Add the upstream dependency in the workspace and proposer crate.

Example shape:

```toml
# Cargo.toml
[workspace.dependencies]
base-tx-manager = { git = "https://github.com/base/base", rev = "<PINNED_REV>" }
```

```toml
# crates/proposer/Cargo.toml
[dependencies]
base-tx-manager = { workspace = true }
```

- [ ] **Step 4: Run dependency-level verification**

Run: `cargo check -p proposer`
Expected: dependency resolution succeeds and the proposer crate still compiles before local migration work starts

- [ ] **Step 5: Commit**

Run:

```bash
git add Cargo.toml crates/proposer/Cargo.toml
git commit -m "chore(proposer): add base tx-manager dependency"
```

Expected: one commit containing only dependency/bootstrap work

## Task 2: Land The Manifest Gas-Limit Fix First

**Files:**

- Modify: `crates/proposer/src/transaction_builder.rs`

- [ ] **Step 1: Write the failing unit tests for manifest gas-limit derivation**

Add tests for:

```rust
#[test]
fn manifest_gas_limit_uses_effective_parent_limit_in_non_engine_mode() {
    assert_eq!(manifest_gas_limit(None, 42, 45_000_000), 44_000_000);
}

#[test]
fn manifest_gas_limit_keeps_genesis_parent_limit_in_non_engine_mode() {
    assert_eq!(manifest_gas_limit(None, 0, 45_000_000), 45_000_000);
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cargo test -p proposer manifest_gas_limit -- --nocapture`
Expected: FAIL because the helper does not exist yet or the old non-engine path still uses `MAX_BLOCK_GAS_LIMIT`

- [ ] **Step 3: Implement the minimal gas-limit helper and switch non-engine mode to use parent block data**

Add a focused helper instead of embedding the logic inline.

Example shape:

```rust
fn manifest_gas_limit(
    engine_params: Option<EngineBuildContext>,
    parent_block_number: u64,
    parent_gas_limit: u64,
) -> u64
```

For non-engine mode:

- fetch `BlockNumberOrTag::Latest`
- use the latest canonical parent gas limit
- keep the genesis-parent exception
- keep the anchor-gas discount for non-genesis parents

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cargo test -p proposer manifest_gas_limit -- --nocapture`
Expected: PASS

- [ ] **Step 5: Commit**

Run:

```bash
git add crates/proposer/src/transaction_builder.rs
git commit -m "fix(proposer): derive manifest gas limit from parent block"
```

Expected: one commit containing only the manifest fix

## Task 3: Introduce A Proposer-Owned Built Transaction Boundary

**Files:**

- Modify: `crates/proposer/src/transaction_builder.rs`
- Modify: `crates/proposer/src/lib.rs`
- Create: `crates/proposer/src/tx_manager_adapter.rs`

- [ ] **Step 1: Write the failing translation tests first**

In the new adapter module, add unit tests that describe the boundary the adapter expects.

Example test cases:

```rust
#[test]
fn proposal_candidate_carries_call_data_to_inbox_destination() { /* ... */ }

#[test]
fn proposal_candidate_preserves_blob_payload() { /* ... */ }
```

- [ ] **Step 2: Run the adapter unit tests and confirm they fail**

Run: `cargo test -p proposer tx_manager_adapter -- --nocapture`
Expected: FAIL because the module and translation types do not exist yet

- [ ] **Step 3: Add a proposer-owned built transaction type**

Do not keep `TransactionRequest` as the only boundary if that forces tx-manager-specific knowledge back into `proposer.rs`.

Example shape:

```rust
pub struct BuiltProposalTx {
    pub to: Address,
    pub call_data: Bytes,
    pub gas_limit: Option<u64>,
    pub blob_payload: ProposalBlobPayload,
}
```

The exact blob payload type can follow what `base-tx-manager` expects, but it should stay proposer-owned until the adapter converts it.

- [ ] **Step 4: Update the transaction builder to return the built proposal shape**

Keep Shasta-specific assembly here:

- construct `inbox.propose(...)` calldata
- build blob sidecar/blob payload
- capture the destination address
- preserve optional gas limit override hooks

- [ ] **Step 5: Export the new adapter module**

Add to `crates/proposer/src/lib.rs`:

```rust
pub mod tx_manager_adapter;
```

- [ ] **Step 6: Run focused compilation/tests**

Run: `cargo test -p proposer tx_manager_adapter -- --nocapture`
Expected: PASS for translation-focused unit tests

- [ ] **Step 7: Commit**

Run:

```bash
git add crates/proposer/src/lib.rs crates/proposer/src/transaction_builder.rs crates/proposer/src/tx_manager_adapter.rs
git commit -m "refactor(proposer): add tx-manager proposal boundary"
```

Expected: one commit introducing the boundary without cutting over the send path yet

## Task 4: Add Proposer Config Translation To `TxManagerConfig`

**Files:**

- Modify: `crates/proposer/src/config.rs`
- Modify: `bin/client/src/flags/proposer.rs`
- Modify: `bin/client/src/commands/proposer.rs`
- Test: `crates/proposer/src/tx_manager_adapter.rs`

- [ ] **Step 1: Write failing config-mapping tests**

Add tests that verify only the approved small proposer-facing surface is exposed.

Example cases:

```rust
#[test]
fn proposer_config_maps_fee_floors_into_tx_manager_config() { /* ... */ }

#[test]
fn proposer_config_maps_retry_controls_into_resubmission_and_confirmation_timeouts() { /* ... */ }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cargo test -p proposer proposer_config_maps -- --nocapture`
Expected: FAIL because translation helpers and fields do not exist yet

- [ ] **Step 3: Add only the small proposer-facing config surface**

Keep proposer-level knobs limited to the approved behavior surface. A reasonable minimum is:

- resend/retry timing
- bounded confirmation/retry window
- minimum fee floors for low-activity chains

Avoid flattening all tx-manager knobs into proposer CLI.

- [ ] **Step 4: Implement deterministic translation into `TxManagerConfig`**

Put the mapping in one place, preferably in the adapter or a dedicated config helper.

Example shape:

```rust
impl ProposerConfigs {
    pub fn to_tx_manager_config(&self) -> TxManagerConfig { /* ... */ }
}
```

Document all internal defaults in doc comments.

- [ ] **Step 5: Wire the CLI flags into `ProposerConfigs`**

Update:

- `bin/client/src/flags/proposer.rs`
- `bin/client/src/commands/proposer.rs`

Keep names consistent with existing proposer CLI conventions instead of exposing `BASE_TX_MANAGER_*` directly.

- [ ] **Step 6: Re-run the focused tests**

Run: `cargo test -p proposer proposer_config_maps -- --nocapture`
Expected: PASS

- [ ] **Step 7: Commit**

Run:

```bash
git add crates/proposer/src/config.rs bin/client/src/flags/proposer.rs bin/client/src/commands/proposer.rs crates/proposer/src/tx_manager_adapter.rs
git commit -m "feat(proposer): map proposer retry config to tx-manager"
```

Expected: one commit containing only config surface and translation work

## Task 5: Implement The `base-tx-manager` Adapter

**Files:**

- Create: `crates/proposer/src/tx_manager_adapter.rs`
- Modify: `crates/proposer/src/error.rs`

- [ ] **Step 1: Write failing adapter tests for result mapping**

Cover:

- successful mined send -> proposer success outcome
- bounded retry exhaustion / confirmation timeout -> `ProposalOutcome::RetryExhausted`
- non-retryable tx-manager failures -> `ProposerError`

Example shape:

```rust
#[test]
fn tx_manager_timeout_maps_to_retry_exhausted() { /* ... */ }

#[test]
fn tx_manager_non_retryable_error_maps_to_proposer_error() { /* ... */ }
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cargo test -p proposer tx_manager_timeout_maps -- --nocapture`
Expected: FAIL because adapter mapping does not exist yet

- [ ] **Step 3: Implement the adapter with a narrow public API**

Preferred shape:

```rust
pub struct ProposalTxManager { /* tx-manager + config + metrics deps */ }

impl ProposalTxManager {
    pub async fn send_proposal(&self, proposal: BuiltProposalTx) -> Result<ProposalOutcome> {
        /* translate -> send -> map result */
    }
}
```

The adapter should own:

- `TxCandidate` construction
- tx-manager initialization
- tx-manager result classification

The adapter should not own:

- manifest generation
- txpool fetches
- outer proposer loop timing

- [ ] **Step 4: Add any required error conversions**

Extend `crates/proposer/src/error.rs` only as needed so tx-manager failures map cleanly into proposer errors without losing operator context.

- [ ] **Step 5: Run focused adapter tests**

Run: `cargo test -p proposer tx_manager_adapter -- --nocapture`
Expected: PASS

- [ ] **Step 6: Commit**

Run:

```bash
git add crates/proposer/src/tx_manager_adapter.rs crates/proposer/src/error.rs
git commit -m "feat(proposer): add base tx-manager adapter"
```

Expected: one commit containing only adapter behavior

## Task 6: Cut Over `Proposer` To The Adapter And Delete Local Retry Logic

**Files:**

- Modify: `crates/proposer/src/proposer.rs`
- Modify: `crates/proposer/src/config.rs`
- Modify: `crates/proposer/src/error.rs`
- Modify: `crates/proposer/tests/shasta_propose.rs`

- [ ] **Step 1: Write or update failing proposer-level tests first**

Update proposer tests to assert mined outcomes through the new send path.

Example expectation:

```rust
assert_eq!(proposer.fetch_and_propose().await?, ProposalOutcome::Mined);
```

- [ ] **Step 2: Run the proposer tests and verify they fail against the pre-cutover code**

Run: `cargo test -p proposer shasta_propose -- --nocapture`
Expected: FAIL if the new outcome contract or adapter path is not wired yet

- [ ] **Step 3: Remove proposer-local retry ownership**

Delete local fee state, replacement bump helpers, and receipt-timeout resend loops from `crates/proposer/src/proposer.rs`.

Specifically, do not keep local equivalents of:

- fee bump arithmetic
- retry budget accounting
- receipt timeout resend loops
- replacement error string matching

- [ ] **Step 4: Initialize and call the adapter from `Proposer`**

`Proposer` should:

- fetch txpool/engine data
- build `BuiltProposalTx`
- call the adapter
- map the result into metrics/logging
- continue the outer proposer loop on `RetryExhausted`

- [ ] **Step 5: Re-run proposer tests**

Run: `cargo test -p proposer shasta_propose -- --nocapture`
Expected: PASS

- [ ] **Step 6: Commit**

Run:

```bash
git add crates/proposer/src/proposer.rs crates/proposer/src/config.rs crates/proposer/src/error.rs crates/proposer/tests/shasta_propose.rs
git commit -m "refactor(proposer): send proposals through base tx-manager"
```

Expected: one commit that removes local retry logic and completes the send-path cutover

## Task 7: Run Workspace Verification And Clean Up Docs

**Files:**

- Modify: any production file touched above if clippy/doc issues appear

- [ ] **Step 1: Run formatter**

Run: `just fmt`
Expected: formatting passes and any generated sort updates are applied

- [ ] **Step 2: Run clippy as the doc/comment gate**

Run: `just clippy`
Expected: PASS with no missing docs and no new warnings

- [ ] **Step 3: Run proposer-focused tests first**

Run: `cargo test -p proposer -- --nocapture`
Expected: PASS

- [ ] **Step 4: Run full repo verification required by this package**

Run: `just test`
Expected: PASS, or a clearly documented blocker if the environment cannot run the Docker-backed stack

- [ ] **Step 5: Commit any final verification-driven fixes**

Run:

```bash
git add <verification-fix-files>
git commit -m "chore(proposer): address verification fixes"
```

Expected: either no-op if unnecessary or one final cleanup commit

## Final Handoff Checklist

- [ ] `base-tx-manager` revision is pinned and confirmed to support blob transactions
- [ ] non-engine manifest gas-limit fix is landed
- [ ] proposer config exposes only the approved small surface
- [ ] proposer-local retry state machine is deleted, not layered under tx-manager
- [ ] proposer integration tests pass through the tx-manager-backed path
- [ ] `just fmt`
- [ ] `just clippy`
- [ ] `just test`
