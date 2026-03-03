//! Driver interface trait definitions.

use std::{result::Result, time::Duration};

use alloy_primitives::U256;
use alloy_rpc_types::Header as RpcHeader;
use async_trait::async_trait;
use driver::sync::{ConfirmedSyncSnapshot, build_confirmed_sync_snapshot};
use tokio::time::sleep;
use tracing::info;

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
        build_confirmed_sync_snapshot(
            target_proposal_id,
            |target| self.get_last_block_id_by_batch_id(target),
            || self.get_head_l1_origin_block_id(),
        )
        .await
    }
}

/// Resolve a block header for a block number.
#[async_trait]
pub trait BlockHeaderProvider: Send + Sync {
    /// Fetch the block header for the specified block number.
    async fn header_by_number(&self, block_number: u64) -> ClientResult<RpcHeader>;
    /// Return the connected L2 chain ID.
    async fn chain_id(&self) -> ClientResult<u64>;
}

/// Trait for driving preconfirmation submissions and sync state.
#[async_trait]
pub trait DriverClient: Send + Sync {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> ClientResult<()>;
    /// Await the driver event sync completion signal.
    async fn wait_event_sync(&self) -> ClientResult<()>;
    /// Return the latest confirmed event-sync L2 block number.
    /// On fresh genesis with no confirmed `head_l1_origin` yet, this resolves to `0`.
    async fn event_sync_tip(&self) -> ClientResult<U256>;
    /// Return the latest preconfirmation tip block number.
    async fn preconf_tip(&self) -> ClientResult<U256>;
}

/// Resolve the event-sync tip from a [`ConfirmedSyncSnapshot`].
///
/// On a fresh genesis chain (`target_proposal_id == 0`) where no confirmed tip exists
/// (`head_l1_origin == None`), this returns `0`, which is the genesis confirmed boundary.
/// When `target_proposal_id > 0` but `head_l1_origin` is still unknown (i.e. confirmed
/// sync has not completed), this returns [`DriverApiError::EventSyncTipUnknown`] to
/// preserve fail-closed behavior during the startup catch-up window.
///
/// This is the single source of truth for the fallback logic so that all
/// [`DriverClient`] implementations stay consistent.
pub async fn resolve_event_sync_tip(snapshot: &ConfirmedSyncSnapshot) -> ClientResult<U256> {
    match snapshot.event_sync_tip() {
        Some(tip) => Ok(U256::from(tip)),
        // Fresh genesis chain — no proposals confirmed on L1 yet, confirmed boundary is 0.
        None if snapshot.target_proposal_id == 0 => Ok(U256::ZERO),
        // Confirmed sync still catching up — reject to stay fail-closed.
        None => Err(crate::error::DriverApiError::EventSyncTipUnknown.into()),
    }
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
        let sync_snapshot = snapshot().await?;

        if sync_snapshot.is_ready() {
            info!(
                target_proposal_id = sync_snapshot.target_proposal_id,
                target_block = ?sync_snapshot.target_block,
                head_l1_origin_block_id = ?sync_snapshot.head_l1_origin_block_id,
                "confirmed sync is ready"
            );
            return Ok(());
        }

        info!(
            target_proposal_id = sync_snapshot.target_proposal_id,
            target_block = ?sync_snapshot.target_block,
            head_l1_origin_block_id = ?sync_snapshot.head_l1_origin_block_id,
            "waiting for confirmed sync"
        );

        sleep(poll_interval).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::PreconfirmationClientError;

    #[tokio::test]
    async fn resolve_returns_snapshot_tip_when_present() {
        let snapshot = ConfirmedSyncSnapshot::new(1, Some(10), Some(42));
        let tip = resolve_event_sync_tip(&snapshot).await.unwrap();
        assert_eq!(tip, U256::from(42));
    }

    #[tokio::test]
    async fn resolve_returns_zero_when_tip_missing_on_genesis_snapshot() {
        let snapshot = ConfirmedSyncSnapshot::new(0, None, None);
        let tip = resolve_event_sync_tip(&snapshot).await.unwrap();
        assert_eq!(tip, U256::ZERO);
    }

    #[tokio::test]
    async fn resolve_rejects_when_confirmed_sync_not_ready() {
        // target_proposal_id > 0 but head_l1_origin is None → startup catch-up window.
        let snapshot = ConfirmedSyncSnapshot::new(5, Some(10), None);
        let err = resolve_event_sync_tip(&snapshot).await.unwrap_err();
        assert!(
            matches!(
                err,
                PreconfirmationClientError::DriverInterface(
                    crate::error::DriverApiError::EventSyncTipUnknown
                )
            ),
            "expected EventSyncTipUnknown, got: {err:?}"
        );
    }
}
