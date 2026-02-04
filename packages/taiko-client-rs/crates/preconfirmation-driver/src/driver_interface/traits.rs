//! Driver interface trait definitions.

use alloy_primitives::U256;
use alloy_rpc_types::Header as RpcHeader;
use async_trait::async_trait;

use crate::error::Result;

use super::PreconfirmationInput;

/// Trait for reading L1 Inbox contract state.
///
/// This abstraction allows the embedded driver client to check L1 sync status
/// without requiring a concrete provider type, enabling easier testing.
#[async_trait]
pub trait InboxReader: Clone + Send + Sync {
    /// Returns the next proposal ID from the L1 Inbox contract.
    async fn get_next_proposal_id(&self) -> Result<u64>;
}

/// Resolve a block header for a block number.
#[async_trait]
pub trait BlockHeaderProvider: Send + Sync {
    /// Fetch the block header for the specified block number.
    async fn header_by_number(&self, block_number: u64) -> Result<RpcHeader>;
}

/// Trait for driving preconfirmation submissions and sync state.
#[async_trait]
pub trait DriverClient: Send + Sync {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()>;
    /// Await the driver event sync completion signal.
    async fn wait_event_sync(&self) -> Result<()>;
    /// Return the latest event sync tip block number.
    async fn event_sync_tip(&self) -> Result<U256>;
    /// Return the latest preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256>;
}
