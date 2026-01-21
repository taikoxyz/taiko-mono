# Event-Driven Test Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace polling-based test waits with event-driven mechanisms to reduce E2E test execution time by 15-25%.

**Architecture:** Add `tokio::sync::watch::channel` to `EventSyncer` for proposal ID notifications, and add WebSocket-based `wait_for_block_ws` function using Alloy's `subscribe_blocks()`.

**Tech Stack:** Rust, Tokio (watch channel), Alloy (WebSocket subscription), test-harness

**Test Command:** `PROTOCOL_DIR=/Users/davidcai/Workspace/taiko-mono-shasta/packages/protocol just test`

---

## Task 1: Add `watch::channel` to EventSyncer

### Files:

- Modify: `crates/driver/src/sync/event.rs:61-81` (EventSyncer struct)
- Modify: `crates/driver/src/sync/event.rs:264-292` (EventSyncer::new)
- Modify: `crates/driver/src/sync/event.rs:257` (process_log_batch - store + send)
- Modify: `crates/driver/src/sync/event.rs:294-297` (last_canonical_proposal_id getter)

**Step 1: Add watch channel fields to EventSyncer struct**

In `crates/driver/src/sync/event.rs`, add the watch channel import and fields:

```rust
// Add to imports at line 27 (after existing tokio imports)
use tokio::sync::watch;

// Add to EventSyncer struct after line 76 (after last_canonical_proposal_id field):
    /// Sender for notifying watchers when the canonical proposal ID changes.
    proposal_id_tx: watch::Sender<u64>,
```

**Step 2: Initialize watch channel in EventSyncer::new**

In `EventSyncer::new()`, create the watch channel and store the sender:

```rust
// In EventSyncer::new(), before the Ok(Self { ... }) block (around line 281):
let (proposal_id_tx, _proposal_id_rx) = watch::channel(0u64);

// Add to the Self { ... } block:
proposal_id_tx,
```

**Step 3: Send notification after storing proposal ID**

In `process_log_batch()`, add notification after the atomic store (line 257):

```rust
// After line 257: self.last_canonical_proposal_id.store(proposal_id, Ordering::Relaxed);
// Add:
let _ = self.proposal_id_tx.send(proposal_id);
```

**Step 4: Add subscribe method for tests**

After the `last_canonical_proposal_id()` method (line 297), add:

```rust
/// Subscribe to proposal ID changes.
///
/// Returns a watch::Receiver that receives the latest canonical proposal ID
/// whenever it changes. Useful for event-driven test waits.
pub fn subscribe_proposal_id(&self) -> watch::Receiver<u64> {
    self.proposal_id_tx.subscribe()
}
```

**Step 5: Run tests to verify compilation**

Run: `cargo build -p driver`
Expected: SUCCESS

**Step 6: Run existing tests to ensure no regression**

Run: `cargo test -p driver`
Expected: All tests pass

**Step 7: Commit**

```bash
git add crates/driver/src/sync/event.rs
git commit -m "$(cat <<'EOF'
feat(driver): add watch::channel for proposal ID notifications

Add event-driven notification mechanism to EventSyncer for the canonical
proposal ID. This enables tests to wait for proposal processing without
polling, reducing test latency from ~500ms per wait to near-zero.
EOF
)"
```

---

## Task 2: Add event-driven wait helper in test-harness

### Files:

- Create: `crates/test-harness/src/driver/proposal.rs`
- Modify: `crates/test-harness/src/driver/mod.rs`

**Step 1: Create the proposal wait helper module**

Create `crates/test-harness/src/driver/proposal.rs`:

````rust
//! Event-driven proposal wait helpers.

use std::time::{Duration, Instant};

use anyhow::{Result, anyhow};
use tokio::sync::watch;

/// Waits for a specific proposal ID using event subscription (zero-delay).
///
/// This is more efficient than polling as it receives notifications
/// immediately when the proposal ID changes.
///
/// # Arguments
///
/// * `rx` - A watch receiver from `EventSyncer::subscribe_proposal_id()`.
/// * `expected_proposal_id` - The proposal ID to wait for.
/// * `timeout` - Maximum time to wait.
///
/// # Returns
///
/// Ok(()) when the proposal ID reaches or exceeds the expected value.
///
/// # Example
///
/// ```ignore
/// let mut rx = event_syncer.subscribe_proposal_id();
/// wait_for_proposal_id(&mut rx, 5, Duration::from_secs(30)).await?;
/// ```
pub async fn wait_for_proposal_id(
    rx: &mut watch::Receiver<u64>,
    expected_proposal_id: u64,
    timeout: Duration,
) -> Result<()> {
    let deadline = Instant::now() + timeout;

    loop {
        // Check current value first
        if *rx.borrow() >= expected_proposal_id {
            return Ok(());
        }

        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!(
                "timed out waiting for proposal {expected_proposal_id}, current: {}",
                *rx.borrow()
            ));
        }

        // Wait for change notification
        match tokio::time::timeout(remaining, rx.changed()).await {
            Ok(Ok(())) => {
                if *rx.borrow() >= expected_proposal_id {
                    return Ok(());
                }
            }
            Ok(Err(_)) => return Err(anyhow!("proposal ID channel closed")),
            Err(_) => {
                return Err(anyhow!(
                    "timed out waiting for proposal {expected_proposal_id}, current: {}",
                    *rx.borrow()
                ))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::watch;

    #[tokio::test]
    async fn wait_returns_immediately_when_already_reached() {
        let (tx, mut rx) = watch::channel(10u64);
        drop(tx); // Close sender to ensure we don't wait

        let result = wait_for_proposal_id(&mut rx, 5, Duration::from_millis(100)).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn wait_succeeds_when_value_changes() {
        let (tx, mut rx) = watch::channel(0u64);

        tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(10)).await;
            tx.send(5).unwrap();
        });

        let result = wait_for_proposal_id(&mut rx, 5, Duration::from_secs(1)).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn wait_times_out_when_value_not_reached() {
        let (_tx, mut rx) = watch::channel(0u64);

        let result = wait_for_proposal_id(&mut rx, 10, Duration::from_millis(50)).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("timed out"));
    }
}
````

**Step 2: Export the module from driver/mod.rs**

Check if `crates/test-harness/src/driver/mod.rs` exists. If not, create it:

```rust
//! Driver test utilities.

mod proposal;

pub use proposal::wait_for_proposal_id;
```

**Step 3: Export from test-harness lib.rs**

Add to `crates/test-harness/src/lib.rs` if not already present:

```rust
pub mod driver;
pub use driver::wait_for_proposal_id;
```

**Step 4: Run tests**

Run: `cargo test -p test-harness`
Expected: All tests pass including new unit tests

**Step 5: Commit**

```bash
git add crates/test-harness/src/driver/
git commit -m "$(cat <<'EOF'
feat(test-harness): add event-driven wait_for_proposal_id helper

Add helper function that uses watch::channel subscription to wait for
proposal ID changes without polling. Includes unit tests.
EOF
)"
```

---

## Task 3: Update proposer_driver_e2e tests to use event-driven waits

### Files:

- Modify: `crates/driver/tests/proposer_driver_e2e.rs:69-101` (wait_for_proposal_processed)

**Step 1: Update wait_for_proposal_processed to use watch channel**

Replace the polling-based `wait_for_proposal_processed` function:

```rust
/// Waits for the event syncer to process a specific proposal using event subscription.
async fn wait_for_proposal_processed<P>(
    event_syncer: &EventSyncer<P>,
    driver_client: &Client<P>,
    expected_proposal_id: u64,
    l2_head_before: u64,
    timeout: Duration,
) -> Result<u64>
where
    P: Provider + Clone + 'static,
{
    let mut rx = event_syncer.subscribe_proposal_id();
    let deadline = tokio::time::Instant::now() + timeout;

    loop {
        // Check current value first
        let current_proposal_id = *rx.borrow();
        if current_proposal_id >= expected_proposal_id {
            let l2_head = driver_client.l2_provider.get_block_number().await?;
            if l2_head < l2_head_before {
                warn!(
                    l2_head_before,
                    l2_head, "L2 head moved backward while waiting for proposal processing"
                );
            }
            return Ok(l2_head);
        }

        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!("timed out waiting for proposal {expected_proposal_id}"));
        }

        // Wait for change notification instead of polling
        match tokio::time::timeout(remaining, rx.changed()).await {
            Ok(Ok(())) => continue, // Loop back to check new value
            Ok(Err(_)) => return Err(anyhow!("proposal ID channel closed")),
            Err(_) => return Err(anyhow!("timed out waiting for proposal {expected_proposal_id}")),
        }
    }
}
```

**Step 2: Run the E2E tests**

Run: `PROTOCOL_DIR=/Users/davidcai/Workspace/taiko-mono-shasta/packages/protocol cargo test -p driver --test proposer_driver_e2e -- --nocapture`
Expected: All tests pass, should be noticeably faster

**Step 3: Commit**

```bash
git add crates/driver/tests/proposer_driver_e2e.rs
git commit -m "$(cat <<'EOF'
perf(driver): use event-driven waits in proposer_driver_e2e tests

Replace polling-based wait_for_proposal_processed with event subscription
using watch::channel. This eliminates 500ms polling delays.
EOF
)"
```

---

## Task 4: Add WebSocket-based wait_for_block_ws function

### Files:

- Modify: `crates/test-harness/src/blocks/mod.rs`

**Step 1: Add the WebSocket-based wait function**

Add to `crates/test-harness/src/blocks/mod.rs` after the existing `wait_for_block` function:

````rust
use alloy_provider::ProviderBuilder;
use alloy_pubsub::PubSubFrontend;
use futures_util::StreamExt;

/// Waits for a block using WebSocket subscription (event-driven, zero-delay).
///
/// This is more efficient than polling as it receives block notifications
/// immediately when they are produced.
///
/// # Arguments
///
/// * `ws_url` - WebSocket URL of the L2 node (e.g., "ws://localhost:8546").
/// * `block_number` - The block number to wait for.
/// * `timeout` - Maximum time to wait.
///
/// # Returns
///
/// The block with full transaction details once it appears.
///
/// # Example
///
/// ```ignore
/// let block = wait_for_block_ws("ws://localhost:8546", 100, Duration::from_secs(30)).await?;
/// ```
pub async fn wait_for_block_ws(
    ws_url: &str,
    block_number: u64,
    timeout: Duration,
) -> Result<RpcBlock<TxEnvelope>> {
    use alloy::transports::http::reqwest::Url;

    let ws_url = Url::parse(ws_url).map_err(|e| anyhow!("invalid WebSocket URL: {e}"))?;
    let provider = ProviderBuilder::new()
        .on_ws(alloy_provider::WsConnect::new(ws_url))
        .await
        .map_err(|e| anyhow!("failed to connect WebSocket: {e}"))?;

    // First check if block already exists
    if let Ok(Some(block)) = provider
        .get_block_by_number(BlockNumberOrTag::Number(block_number))
        .full()
        .await
    {
        return Ok(block.map_transactions(TxEnvelope::from));
    }

    // Subscribe to new blocks
    let subscription = provider
        .subscribe_blocks()
        .await
        .map_err(|e| anyhow!("failed to subscribe to blocks: {e}"))?;
    let mut stream = subscription.into_stream();

    let deadline = Instant::now() + timeout;

    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!("timed out waiting for block {block_number}"));
        }

        match tokio::time::timeout(remaining, stream.next()).await {
            Ok(Some(header)) => {
                if header.number >= block_number {
                    // Fetch full block with transactions
                    return provider
                        .get_block_by_number(BlockNumberOrTag::Number(block_number))
                        .full()
                        .await?
                        .map(|b| b.map_transactions(TxEnvelope::from))
                        .ok_or_else(|| anyhow!("block {block_number} not found after notification"));
                }
            }
            Ok(None) => return Err(anyhow!("block subscription stream ended")),
            Err(_) => return Err(anyhow!("timed out waiting for block {block_number}")),
        }
    }
}
````

**Step 2: Add required dependencies to test-harness Cargo.toml**

Check if `alloy-pubsub` and `futures-util` are in dependencies. If not, add:

```toml
alloy-pubsub = { workspace = true }
futures-util = { workspace = true }
```

**Step 3: Run compilation**

Run: `cargo build -p test-harness`
Expected: SUCCESS

**Step 4: Commit**

```bash
git add crates/test-harness/src/blocks/mod.rs crates/test-harness/Cargo.toml
git commit -m "$(cat <<'EOF'
feat(test-harness): add WebSocket-based wait_for_block_ws function

Add event-driven block wait function using Alloy's subscribe_blocks().
This eliminates 200ms polling delays when waiting for blocks.
EOF
)"
```

---

## Task 5: Update out_of_order_arrival tests to use WebSocket waits

### Files:

- Modify: `crates/preconfirmation-driver/tests/out_of_order_arrival.rs`

**Step 1: Read the current test file**

First, read the file to understand current usage patterns.

**Step 2: Update imports and wait calls**

Replace `wait_for_block` calls with `wait_for_block_ws` where appropriate, using `env.l2_ws_0.as_str()` as the WebSocket URL.

**Step 3: Run tests**

Run: `PROTOCOL_DIR=/Users/davidcai/Workspace/taiko-mono-shasta/packages/protocol cargo test -p preconfirmation-driver --test out_of_order_arrival -- --nocapture`
Expected: All tests pass

**Step 4: Commit**

```bash
git add crates/preconfirmation-driver/tests/out_of_order_arrival.rs
git commit -m "$(cat <<'EOF'
perf(preconfirmation-driver): use WebSocket waits in out_of_order tests

Replace polling-based wait_for_block with wait_for_block_ws for faster
event-driven block detection in E2E tests.
EOF
)"
```

---

## Task 6: Run full test suite and verify improvements

### Files:

- None (verification only)

**Step 1: Run full test suite with timing**

Run: `PROTOCOL_DIR=/Users/davidcai/Workspace/taiko-mono-shasta/packages/protocol time just test 2>&1 | tee test-output.log`

**Step 2: Compare timing with baseline**

Check the test output for the previously slow tests:

- `proposer_driver_e2e::known_canonical_fast_path` (was 12.7s)
- `proposer_driver_e2e::multiple_proposals_event_sync` (was 13.0s)
- `out_of_order_arrival::out_of_order_blocks_buffered...` (was 12.6s)

Expected: Each test should be 2-4 seconds faster.

**Step 3: Document results**

Update the design document with actual measured improvements.

---

## Summary

| Task | Description                       | Key Changes                                         |
| ---- | --------------------------------- | --------------------------------------------------- |
| 1    | Add watch::channel to EventSyncer | `event.rs`: add channel, send on proposal ID update |
| 2    | Add wait helper in test-harness   | New `driver/proposal.rs` module                     |
| 3    | Update proposer_driver_e2e tests  | Replace polling with subscription                   |
| 4    | Add wait_for_block_ws function    | New WebSocket-based wait in `blocks/mod.rs`         |
| 5    | Update out_of_order tests         | Use WebSocket waits                                 |
| 6    | Verify improvements               | Run full test suite                                 |

**Expected Total Improvement:** 15-25% reduction in E2E test time (~105s -> ~80-90s)
