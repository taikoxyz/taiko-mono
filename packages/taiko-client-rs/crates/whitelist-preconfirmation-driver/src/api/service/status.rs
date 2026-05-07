//! Status and websocket-subscription helpers for the REST handler.

use super::*;

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<WhitelistStatus> {
        let head_l1_origin = self.rpc.head_l1_origin().await?;
        let highest_unsafe = *self.highest_unsafe_l2_payload_block_id.lock().await;
        let current_slot = self.beacon_client.current_slot();
        let slots_per_epoch = self.beacon_client.slots_per_epoch();
        let current_epoch = current_slot / slots_per_epoch;
        let slot_in_epoch = current_slot % slots_per_epoch;
        let can_shutdown =
            self.can_shutdown_for_status(current_epoch, current_slot, slot_in_epoch).await;
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
            can_shutdown,
        })
    }

    /// Return whether the local signer is outside its current shutdown-sensitive windows.
    async fn can_shutdown_for_status(
        &self,
        current_epoch: u64,
        current_slot: u64,
        slot_in_epoch: u64,
    ) -> bool {
        let (can_shutdown, is_initialized, needs_refresh) = {
            let sequencing_window = self.sequencing_window.lock().await;
            (
                sequencing_window.can_shutdown(current_slot),
                sequencing_window.is_initialized(),
                sequencing_window.should_refresh(current_epoch, slot_in_epoch),
            )
        };

        if !needs_refresh {
            return can_shutdown;
        }

        match self.fetch_current_next_operators().await {
            Ok((current_operator, next_operator)) => {
                let mut sequencing_window = self.sequencing_window.lock().await;
                sequencing_window.refresh(
                    current_epoch,
                    current_operator,
                    next_operator,
                    self.signer.address(),
                );
                if is_initialized {
                    return sequencing_window.can_shutdown(current_slot);
                }
            }
            Err(err) => {
                warn!(%err, current_epoch, "failed to refresh sequencing window for status");
            }
        }

        true
    }

    /// Fetch the current and next whitelist operators from L1.
    async fn fetch_current_next_operators(&self) -> Result<(Address, Address)> {
        let current_operator =
            self.whitelist.getOperatorForCurrentEpoch().call().await.map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to fetch current epoch operator: {err}"
                ))
            })?;
        let next_operator =
            self.whitelist.getOperatorForNextEpoch().call().await.map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to fetch next epoch operator: {err}"
                ))
            })?;

        Ok((current_operator, next_operator))
    }

    /// Return a new receiver for end-of-sequencing websocket notifications.
    pub(super) fn subscribe_end_of_sequencing_notifications(
        &self,
    ) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.eos_notification_tx.subscribe()
    }
}
