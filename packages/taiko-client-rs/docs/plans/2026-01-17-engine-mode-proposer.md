# Engine Mode Proposer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a new "engine mode" to the proposer that uses Engine API (FCU + get_payload) to build payloads instead of fetching pre-built tx lists.

**Architecture:** The proposer will support two modes controlled by configuration: legacy mode (existing `tx_pool_content_with_min_tip`) and engine mode (FCU with `tx_list: None` + `anchor_transaction`). Engine mode delegates transaction selection to alethia-reth's mempool, then extracts transactions from the built payload for proposing.

**Tech Stack:** Rust, alloy, alethia-reth primitives, Engine API (FCU v2, get_payload v2)

---

## Task 1: Move AnchorTxConstructor to Protocol Crate

**Files:**

- Move: `crates/driver/src/derivation/pipeline/shasta/anchor.rs` → `crates/protocol/src/shasta/anchor.rs`
- Move: `crates/driver/src/signer.rs` → `crates/protocol/src/signer.rs`
- Modify: `crates/protocol/src/shasta/mod.rs`
- Modify: `crates/protocol/src/lib.rs`
- Modify: `crates/driver/src/derivation/pipeline/shasta/mod.rs`
- Modify: `crates/driver/src/lib.rs`

**Step 1: Copy anchor.rs to protocol crate**

Copy `crates/driver/src/derivation/pipeline/shasta/anchor.rs` to `crates/protocol/src/shasta/anchor.rs`.

Update imports in the new file:

```rust
use crate::signer::{FixedKSigner, FixedKSignerError};
```

**Step 2: Copy signer.rs to protocol crate**

Copy `crates/driver/src/signer.rs` to `crates/protocol/src/signer.rs`.

**Step 3: Update protocol/src/shasta/mod.rs**

Add:

```rust
pub mod anchor;
pub use anchor::{AnchorTxConstructor, AnchorTxConstructorError, AnchorV4Input};
```

**Step 4: Update protocol/src/lib.rs**

Add:

```rust
pub mod signer;
pub use signer::{FixedKSigner, FixedKSignerError};
```

**Step 5: Update driver imports**

In `crates/driver/src/derivation/pipeline/shasta/mod.rs`, change:

```rust
// Old
pub mod anchor;
pub use anchor::{AnchorTxConstructor, AnchorV4Input};

// New
pub use protocol::shasta::anchor::{AnchorTxConstructor, AnchorV4Input};
```

In `crates/driver/src/lib.rs` or relevant files, update signer imports:

```rust
// Old
use crate::signer::FixedKSigner;

// New
use protocol::signer::FixedKSigner;
```

**Step 6: Remove old files from driver**

Delete:

- `crates/driver/src/derivation/pipeline/shasta/anchor.rs`
- `crates/driver/src/signer.rs`

**Step 7: Verify build**

Run: `cargo build -p protocol -p driver`
Expected: Build succeeds

**Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(protocol): move AnchorTxConstructor and FixedKSigner from driver to protocol

Move anchor transaction construction and signing utilities to the protocol
crate so they can be shared between driver and proposer.
EOF
)"
```

---

## Task 2: Add Engine Mode Configuration

**Files:**

- Modify: `crates/proposer/src/config.rs`
- Modify: `bin/client/src/flags/proposer.rs`
- Modify: `bin/client/src/commands/proposer.rs`

**Step 1: Add config field**

In `crates/proposer/src/config.rs`, add to `ProposerConfigs`:

```rust
/// Whether to use Engine API mode for payload building.
/// When true, uses FCU + get_payload instead of tx_pool_content_with_min_tip.
pub use_engine_mode: bool,
```

**Step 2: Add CLI flag**

In `bin/client/src/flags/proposer.rs`, add:

```rust
/// Use Engine API mode for payload building (FCU + get_payload).
#[arg(long = "propose.useEngineMode", default_value = "false")]
pub use_engine_mode: bool,
```

**Step 3: Wire up in command**

In `bin/client/src/commands/proposer.rs`, add to config construction:

```rust
use_engine_mode: flags.use_engine_mode,
```

**Step 4: Verify build**

Run: `cargo build -p taiko-client`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(proposer): add use_engine_mode configuration flag

Add --propose.useEngineMode flag to enable Engine API mode for payload
building. Defaults to false for backward compatibility.
EOF
)"
```

---

## Task 3: Add Error Types

**Files:**

- Modify: `crates/proposer/src/error.rs`

**Step 1: Add new error variants**

In `crates/proposer/src/error.rs`, add to `ProposerError`:

```rust
/// Failed to decode extra data from parent block.
#[error("invalid extra data in parent block")]
InvalidExtraData,

/// FCU returned invalid status.
#[error("forkchoice updated failed: {0}")]
FcuFailed(String),

/// FCU did not return a payload ID.
#[error("FCU did not return payload ID (node may be syncing)")]
NoPayloadId,

/// Failed to build anchor transaction.
#[error("anchor transaction construction failed: {0}")]
AnchorConstruction(#[from] protocol::shasta::anchor::AnchorTxConstructorError),
```

**Step 2: Verify build**

Run: `cargo build -p proposer`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(proposer): add error types for engine mode
EOF
)"
```

---

## Task 4: Implement Engine Mode Core Logic

**Files:**

- Modify: `crates/proposer/src/proposer.rs`
- Modify: `crates/proposer/Cargo.toml` (if needed for new dependencies)

**Step 1: Add imports**

In `crates/proposer/src/proposer.rs`, add:

```rust
use alethia_reth_primitives::{
    decode_shasta_proposal_id,
    payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
};
use alloy::rpc::types::engine::{ForkchoiceState, PayloadStatusEnum};
use alloy_rpc_types_engine::EthPayloadAttributes;
use protocol::shasta::{
    anchor::{AnchorTxConstructor, AnchorV4Input},
    payload_helpers::{calculate_shasta_difficulty, encode_extra_data},
};
use alloy_eips::eip2718::Encodable2718;
```

**Step 2: Add anchor_constructor field**

Modify `Proposer` struct:

```rust
pub struct Proposer {
    rpc_provider: ClientWithWallet,
    transaction_builder: ShastaProposalTransactionBuilder,
    anchor_constructor: AnchorTxConstructor<rpc::client::L1WalletProvider>,
    cfg: ProposerConfigs,
}
```

**Step 3: Initialize anchor_constructor in new()**

In `Proposer::new()`, add after rpc_provider initialization:

```rust
let anchor_constructor = AnchorTxConstructor::new(rpc_provider.clone()).await?;
```

And update the return:

```rust
Ok(Self { rpc_provider, cfg, transaction_builder, anchor_constructor })
```

**Step 4: Implement build_forkchoice_state()**

Add method:

```rust
/// Build ForkchoiceState by querying L2 for latest, safe, and finalized blocks.
async fn build_forkchoice_state(&self) -> Result<ForkchoiceState> {
    let latest = self
        .rpc_provider
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await?
        .ok_or(ProposerError::LatestBlockNotFound)?;

    let safe = self
        .rpc_provider
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Safe)
        .await?
        .map(|b| b.header.hash)
        .unwrap_or(latest.header.hash);

    let finalized = self
        .rpc_provider
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Finalized)
        .await?
        .map(|b| b.header.hash)
        .unwrap_or(latest.header.hash);

    Ok(ForkchoiceState {
        head_block_hash: latest.header.hash,
        safe_block_hash: safe,
        finalized_block_hash: finalized,
    })
}
```

**Step 5: Implement build_payload_attributes()**

Add method:

```rust
/// Build TaikoPayloadAttributes for engine mode.
async fn build_payload_attributes(&self) -> Result<(TaikoPayloadAttributes, alloy::primitives::B256)> {
    // Get parent block
    let parent = self
        .rpc_provider
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await?
        .ok_or(ProposerError::LatestBlockNotFound)?;

    let parent_hash = parent.header.hash;

    // Calculate base fee
    let base_fee = self.calculate_next_shasta_block_base_fee().await?;
    let base_fee_u64 = u64::try_from(base_fee).map_err(|_| ProposerError::BaseFeeOverflow)?;

    // Calculate mix_hash (difficulty)
    let mix_hash = calculate_shasta_difficulty(parent.header.mix_hash, parent.header.number + 1);

    // Decode parent proposal_id and increment
    let parent_proposal_id = decode_shasta_proposal_id(parent.header.extra_data.as_ref())
        .ok_or(ProposerError::InvalidExtraData)?;
    let next_proposal_id = parent_proposal_id + 1;

    // Get basefee_sharing_pctg from inbox config
    let config = self.rpc_provider.shasta.inbox.getConfig().call().await?;
    let extra_data = encode_extra_data(config.basefeeSharingPctg, next_proposal_id);

    // Get latest L1 block for anchor
    let l1_block_number = self.rpc_provider.l1_provider.get_block_number().await?;
    let l1_block = self
        .rpc_provider
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Number(l1_block_number))
        .await?
        .ok_or_else(|| ProposerError::ParentBlockNotFound(l1_block_number))?;

    // Build anchor transaction
    let anchor_tx = self
        .anchor_constructor
        .assemble_anchor_v4_tx(
            parent_hash,
            AnchorV4Input {
                anchor_block_number: l1_block_number,
                anchor_block_hash: l1_block.header.hash,
                anchor_state_root: l1_block.header.inner.state_root,
                l2_height: parent.header.number + 1,
                base_fee,
            },
        )
        .await?;

    let anchor_bytes = alloy::primitives::Bytes::from(anchor_tx.encoded_2718());

    // Calculate timestamp (parent + 12s or current time, whichever is greater)
    let timestamp = std::cmp::max(
        parent.header.timestamp + 12,
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs(),
    );

    let attributes = TaikoPayloadAttributes {
        payload_attributes: EthPayloadAttributes {
            timestamp,
            prev_randao: mix_hash,
            suggested_fee_recipient: self.cfg.l2_suggested_fee_recipient,
            withdrawals: Some(vec![]),
            parent_beacon_block_root: None,
        },
        base_fee_per_gas: base_fee,
        block_metadata: TaikoBlockMetadata {
            beneficiary: self.cfg.l2_suggested_fee_recipient,
            gas_limit: parent.header.gas_limit,
            timestamp: alloy::primitives::U256::from(timestamp),
            mix_hash,
            tx_list: None, // Key: None triggers mempool selection
            extra_data,
        },
        l1_origin: RpcL1Origin {
            block_id: alloy::primitives::U256::from(parent.header.number + 1),
            l2_block_hash: alloy::primitives::B256::ZERO, // Will be filled after block is built
            l1_block_height: Some(alloy::primitives::U256::from(l1_block_number)),
            l1_block_hash: Some(l1_block.header.hash),
            build_payload_args_id: [0; 8],
            is_forced_inclusion: false,
            signature: [0; 65],
        },
        anchor_transaction: Some(anchor_bytes),
    };

    Ok((attributes, parent_hash))
}
```

**Step 6: Implement fetch_payload_transactions()**

Add method:

```rust
/// Fetch transactions using Engine API (FCU + get_payload).
async fn fetch_payload_transactions(&self) -> Result<TransactionsLists> {
    // Build forkchoice state
    let forkchoice_state = self.build_forkchoice_state().await?;

    // Build payload attributes
    let (payload_attributes, parent_hash) = self.build_payload_attributes().await?;

    info!(
        parent_hash = %parent_hash,
        timestamp = payload_attributes.payload_attributes.timestamp,
        "triggering payload build via FCU"
    );

    // Call FCU to trigger payload building
    let fcu_response = self
        .rpc_provider
        .engine_forkchoice_updated_v2(forkchoice_state, Some(payload_attributes))
        .await?;

    // Check FCU status
    match fcu_response.payload_status.status {
        PayloadStatusEnum::Valid => {}
        PayloadStatusEnum::Syncing => {
            info!("FCU returned SYNCING, returning empty txlist");
            return Ok(vec![]);
        }
        status => {
            return Err(ProposerError::FcuFailed(format!("{:?}", status)));
        }
    }

    // Get payload ID
    let payload_id = fcu_response.payload_id.ok_or(ProposerError::NoPayloadId)?;

    info!(payload_id = %payload_id, "FCU successful, fetching payload");

    // Get the built payload
    let payload_envelope = self.rpc_provider.engine_get_payload_v2(payload_id).await?;
    let transactions = &payload_envelope.execution_payload.transactions;

    info!(
        tx_count = transactions.len(),
        "fetched payload with transactions"
    );

    // Skip first transaction (anchor) and convert remaining to Transaction type
    let pool_txs: Vec<Transaction> = transactions
        .iter()
        .skip(1) // Skip anchor transaction
        .filter_map(|tx_bytes| {
            from_value::<Transaction>(serde_json::to_value(tx_bytes).ok()?).ok()
        })
        .collect();

    Ok(vec![pool_txs])
}
```

**Step 7: Modify fetch_and_propose() to support both modes**

Update `fetch_and_propose()`:

```rust
pub async fn fetch_and_propose(&self) -> Result<()> {
    // Fetch transactions based on mode
    let pool_content = if self.cfg.use_engine_mode {
        self.fetch_payload_transactions().await?
    } else {
        self.fetch_pool_content().await?
    };

    // Rest of the method remains the same...
    let tx_count: usize = pool_content.iter().map(|list| list.len()).sum();
    gauge!(ProposerMetrics::TX_POOL_SIZE).set(tx_count as f64);
    info!(txs_lists = pool_content.len(), tx_count, "fetched transaction pool content");

    // ... existing code continues
}
```

**Step 8: Verify build**

Run: `cargo build -p proposer`
Expected: Build succeeds

**Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(proposer): implement engine mode for payload building

Add fetch_payload_transactions() method that uses Engine API:
- FCU with tx_list=None and anchor_transaction to trigger mempool selection
- get_payload to retrieve built payload
- Extract transactions (excluding anchor) for proposal

The mode is controlled by use_engine_mode config flag.
EOF
)"
```

---

## Task 5: Integration Test - Engine Mode Propose

**Files:**

- Create: `crates/proposer/tests/engine_mode_propose.rs`

**Step 1: Write the test**

Create `crates/proposer/tests/engine_mode_propose.rs`:

```rust
//! Integration tests for engine mode proposer.

use proposer::{Proposer, ProposerConfigs};
use test_harness::shasta::ShastaEnv;
use std::time::Duration;

#[tokio::test]
async fn test_engine_mode_propose() {
    // Initialize test environment
    let env = ShastaEnv::new().await.expect("failed to create test env");

    // Create proposer with engine mode enabled
    let cfg = ProposerConfigs {
        l1_provider_source: env.l1_provider_source(),
        l2_provider_url: env.l2_provider_url(),
        l2_auth_provider_url: env.l2_auth_provider_url(),
        jwt_secret: env.jwt_secret_path(),
        inbox_address: env.inbox_address(),
        l2_suggested_fee_recipient: env.fee_recipient(),
        propose_interval: Duration::from_secs(12),
        l1_proposer_private_key: env.proposer_private_key(),
        gas_limit: None,
        use_engine_mode: true, // Enable engine mode
    };

    let proposer = Proposer::new(cfg).await.expect("failed to create proposer");

    // Send some test transactions to L2 mempool
    env.send_test_transactions(3).await.expect("failed to send test txs");

    // Fetch and propose
    proposer.fetch_and_propose().await.expect("fetch_and_propose failed");

    // Verify proposal was submitted
    let proposal_count = env.get_proposal_count().await.expect("failed to get proposal count");
    assert!(proposal_count > 0, "expected at least one proposal");
}

#[tokio::test]
async fn test_engine_mode_empty_mempool() {
    let env = ShastaEnv::new().await.expect("failed to create test env");

    let cfg = ProposerConfigs {
        l1_provider_source: env.l1_provider_source(),
        l2_provider_url: env.l2_provider_url(),
        l2_auth_provider_url: env.l2_auth_provider_url(),
        jwt_secret: env.jwt_secret_path(),
        inbox_address: env.inbox_address(),
        l2_suggested_fee_recipient: env.fee_recipient(),
        propose_interval: Duration::from_secs(12),
        l1_proposer_private_key: env.proposer_private_key(),
        gas_limit: None,
        use_engine_mode: true,
    };

    let proposer = Proposer::new(cfg).await.expect("failed to create proposer");

    // Propose with empty mempool - should still succeed
    proposer.fetch_and_propose().await.expect("fetch_and_propose with empty mempool failed");
}
```

**Step 2: Run tests**

Run: `cargo test -p proposer --test engine_mode_propose`
Expected: Tests pass (or adjust implementation if they fail)

**Step 3: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
test(proposer): add integration tests for engine mode

- test_engine_mode_propose: normal flow with transactions
- test_engine_mode_empty_mempool: empty mempool handling
EOF
)"
```

---

## Task 6: Final Verification and Cleanup

**Step 1: Run all tests**

Run: `cargo test --workspace`
Expected: All tests pass

**Step 2: Run clippy**

Run: `cargo clippy --workspace -- -D warnings`
Expected: No warnings

**Step 3: Run fmt**

Run: `cargo fmt --all`
Expected: Code is formatted

**Step 4: Final commit if needed**

```bash
git add -A
git commit -m "chore: fix clippy warnings and formatting"
```

---

## Summary

| Task | Description                          | Files Changed                |
| ---- | ------------------------------------ | ---------------------------- |
| 1    | Move AnchorTxConstructor to protocol | protocol, driver             |
| 2    | Add engine mode configuration        | config, flags, commands      |
| 3    | Add error types                      | error.rs                     |
| 4    | Implement engine mode core logic     | proposer.rs                  |
| 5    | Integration tests                    | tests/engine_mode_propose.rs |
| 6    | Verification and cleanup             | -                            |
