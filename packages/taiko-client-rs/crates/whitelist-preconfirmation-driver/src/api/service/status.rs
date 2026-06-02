//! Status and websocket-subscription helpers for the REST handler.

use super::*;

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<WhitelistStatus> {
        let head_l1_origin = self.rpc.head_l1_origin().await?;

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
        let highest_unsafe = {
            let guard = self.highest_unsafe_l2_payload_block_id.lock().await;
            let reconciled = reconcile_highest_unsafe(*guard, l2_head);
            if reconciled != *guard {
                warn!(
                    tracked = *guard,
                    head = reconciled,
                    "highest_unsafe ahead of head; reporting clamped value"
                );
            }
            reconciled
        };

        let current_epoch = self.beacon_client.current_epoch();
        let end_of_sequencing_block_hash = self
            .cache_state
            .end_of_sequencing_for_epoch(current_epoch)
            .await
            .map(|hash| hash.to_string());
        // sync_ready reflects ingress readiness, which already includes the confirmed-sync
        // and scanner-live checks required by the event syncer.
        let sync_ready = self.event_syncer.is_preconf_ingress_ready();
        let can_shutdown = self.compute_can_shutdown().await;

        Ok(WhitelistStatus {
            head_l1_origin_block_id: head_l1_origin.as_ref().map(|o| o.block_id.to::<u64>()),
            highest_unsafe_block_number: highest_unsafe,
            peer_id: self.peer_id.clone(),
            sync_ready,
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
