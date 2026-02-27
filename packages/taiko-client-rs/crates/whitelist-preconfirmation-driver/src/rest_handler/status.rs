//! Status and websocket-subscription helpers for the REST handler.

use super::*;

impl<P> WhitelistApiHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<WhitelistStatus> {
        let head_l1_origin = self.rpc.head_l1_origin().await?;
        let highest_unsafe = *self.highest_unsafe_l2_payload_block_id.lock().await;
        let current_epoch = self.beacon_client.current_epoch();
        let end_of_sequencing_block_hash = self
            .cache_state
            .end_of_sequencing_for_epoch(current_epoch)
            .await
            .map(|hash| hash.to_string());
        // sync_ready reflects ingress readiness, which already includes the confirmed-sync
        // and scanner-live checks required by the event syncer.
        let sync_ready = self.event_syncer.is_preconf_ingress_ready();

        Ok(WhitelistStatus {
            head_l1_origin_block_id: head_l1_origin.as_ref().map(|o| o.block_id.to::<u64>()),
            highest_unsafe_block_number: highest_unsafe,
            peer_id: self.local_peer_id.clone(),
            sync_ready,
            highest_unsafe_l2_payload_block_id: highest_unsafe,
            end_of_sequencing_block_hash,
        })
    }

    /// Return a new receiver for end-of-sequencing websocket notifications.
    pub(super) fn subscribe_end_of_sequencing_notifications(
        &self,
    ) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.eos_notification_tx.subscribe()
    }
}
