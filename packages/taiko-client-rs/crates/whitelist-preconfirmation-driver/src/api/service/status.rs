//! Status and websocket-subscription helpers for the REST handler.

use super::*;

impl WhitelistApiService {
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<ApiStatus> {
        // Current L2 execution head, best-effort: a failed read yields `None` and the most
        // recently observed head is reported instead.
        let l2_head = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .ok()
            .flatten()
            .map(|block| block.header.number);

        let highest_unsafe = self.state.reconcile_reported_head(l2_head);
        if l2_head.is_none() {
            warn!(reported = highest_unsafe, "L2 head unreadable; reporting last observed head");
        }

        let current_epoch = self.beacon_client.current_epoch();
        let end_of_sequencing_block_hash = self
            .state
            .end_of_sequencing_for_epoch(current_epoch)
            .await
            .unwrap_or(B256::ZERO)
            .to_string();
        let can_shutdown = self.compute_can_shutdown().await;

        Ok(ApiStatus {
            highest_unsafe_l2_payload_block_id: highest_unsafe,
            end_of_sequencing_block_hash,
            can_shutdown,
        })
    }

    /// Return a new receiver for end-of-sequencing websocket notifications.
    pub(super) fn subscribe_end_of_sequencing_notifications(
        &self,
    ) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.eos_notification_tx.subscribe()
    }
}
