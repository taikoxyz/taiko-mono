//! Status and websocket-subscription helpers for the REST handler.

use super::*;

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<ApiStatus> {
        // Current L2 execution head, best-effort: a failed read yields `None`, which skips
        // the clamp below and leaves the reported value unchanged.
        let l2_head = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .ok()
            .flatten()
            .map(|block| block.header.number);

        // The counter only moves up (on import/build), so after the head moves backward
        // (e.g. an L1 reorg) it can be left above the head. Report it clamped to the head.
        //
        // Report only — do NOT write the clamp back. `l2_head` is read without the lock, so
        // it can already be stale; persisting `min(counter, stale_head)` would pin the
        // stored counter too low until the next import/build. Clamping only the reported
        // value keeps the counter intact, so the next poll recomputes against a fresh head
        // and self-heals.
        let tracked = self.state.highest_unsafe().await;
        let highest_unsafe = reconcile_highest_unsafe(tracked, l2_head);
        if highest_unsafe != tracked {
            warn!(
                tracked,
                head = highest_unsafe,
                "highest_unsafe ahead of head; reporting clamped value"
            );
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
