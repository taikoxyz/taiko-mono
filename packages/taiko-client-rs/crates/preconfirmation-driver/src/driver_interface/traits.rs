//! Driver interface trait definitions.

use std::{future::Future, result::Result, time::Duration};

use alloy_primitives::U256;
use alloy_rpc_types::Header as RpcHeader;
use async_trait::async_trait;
use driver::sync::ConfirmedSyncSnapshot;
use tokio::time::sleep;

use crate::error::Result as ClientResult;

use super::PreconfirmationInput;

/// Default poll interval for `wait_event_sync` checks in production paths.
pub(crate) const DEFAULT_WAIT_EVENT_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Trait for reading L1 Inbox contract state.
///
/// This abstraction allows the embedded driver client to check L1 sync status
/// without requiring a concrete provider type, enabling easier testing.
#[async_trait]
pub trait InboxReader: Clone + Send + Sync {
    /// Returns the next proposal ID from the L1 Inbox contract.
    async fn get_next_proposal_id(&self) -> ClientResult<u64>;
    /// Returns the last L2 block mapped to the given proposal/batch ID.
    async fn get_last_block_id_by_batch_id(&self, proposal_id: u64) -> ClientResult<Option<u64>>;
    /// Returns the current confirmed event-sync tip from `head_l1_origin`.
    async fn get_head_l1_origin_block_id(&self) -> ClientResult<Option<u64>>;

    /// Returns a strict confirmed-sync snapshot derived from core state + custom tables.
    async fn confirmed_sync_snapshot(&self) -> ClientResult<ConfirmedSyncSnapshot> {
        let target_proposal_id = self.get_next_proposal_id().await?.saturating_sub(1);
        if target_proposal_id == 0 {
            return Ok(ConfirmedSyncSnapshot::new(
                target_proposal_id,
                None,
                self.get_head_l1_origin_block_id().await?,
            ));
        }

        Ok(ConfirmedSyncSnapshot::new(
            target_proposal_id,
            self.get_last_block_id_by_batch_id(target_proposal_id).await?,
            self.get_head_l1_origin_block_id().await?,
        ))
    }
}

/// Resolve a block header for a block number.
#[async_trait]
pub trait BlockHeaderProvider: Send + Sync {
    /// Fetch the block header for the specified block number.
    async fn header_by_number(&self, block_number: u64) -> ClientResult<RpcHeader>;
}

/// Trait for driving preconfirmation submissions and sync state.
#[async_trait]
pub trait DriverClient: Send + Sync {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> ClientResult<()>;
    /// Await the driver event sync completion signal.
    async fn wait_event_sync(&self) -> ClientResult<()>;
    /// Return the latest confirmed event-sync L2 block number.
    async fn event_sync_tip(&self) -> ClientResult<U256>;
    /// Return the latest preconfirmation tip block number.
    async fn preconf_tip(&self) -> ClientResult<U256>;
}

/// Wait for strict confirmed-sync readiness by polling a caller-provided snapshot source.
pub(crate) async fn wait_for_confirmed_sync<F, Fut, E>(
    mut snapshot: F,
    poll_interval: Duration,
) -> Result<(), E>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<ConfirmedSyncSnapshot, E>>,
{
    loop {
        if snapshot().await?.is_ready() {
            return Ok(());
        }
        sleep(poll_interval).await;
    }
}
