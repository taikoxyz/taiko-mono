//! Status and websocket-subscription helpers for the REST handler.

use super::*;
use crate::metrics::WhitelistPreconfirmationDriverMetrics;

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<WhitelistStatus> {
        let head_l1_origin = self.rpc.head_l1_origin().await?;

        // reth's canonical head — the same value the Catalyst compares against as
        // "Taiko Geth Height". Best-effort: a failed read yields `None`, leaving the
        // tracked counter unchanged so `/status` is no more fragile than before.
        let reth_head = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .ok()
            .flatten()
            .map(|block| block.header.number);

        // The counter only ratchets upward on import/build, so after reth's head moves
        // backward (e.g. an L1 reorg) it can be left stuck above the head, permanently
        // failing the sequencer's `highest_unsafe == geth_height` gate. Report it clamped
        // down to reth's head.
        //
        // We deliberately do NOT write the clamp back to the shared counter. `reth_head` is
        // read lock-free above, so it can lag a concurrent import/build that advanced both
        // reth and the counter between that read and here; persisting `min(counter, stale
        // head)` would pin the counter below reth's real head (the helper never raises it)
        // until the next import/build — long enough to stall the Catalyst equality gate.
        // Clamping only the reported value keeps the stored counter intact, so the next
        // poll recomputes against a fresh head and self-heals.
        let highest_unsafe = {
            let guard = self.highest_unsafe_l2_payload_block_id.lock().await;
            let reconciled = reconcile_highest_unsafe(*guard, reth_head);
            if reconciled != *guard {
                warn!(
                    tracked = *guard,
                    reth_head = reconciled,
                    "highest_unsafe ahead of reth head; reporting clamped value (L1 reorg / rewind)"
                );
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::HIGHEST_UNSAFE_RECONCILED_TOTAL
                )
                .increment(1);
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
