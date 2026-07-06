//! Status and websocket-subscription helpers for the REST handler.

use super::*;

impl WhitelistApiService {
    /// Build the current status snapshot served by the REST `/status` route.
    pub(super) async fn get_status_snapshot(&self) -> Result<ApiStatus> {
        // Current L2 execution head, best-effort: a failed read yields `None`, which skips
        // the reconciliation below and reports the tracked counter unchanged.
        let l2_head = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .ok()
            .flatten()
            .map(|block| block.header.number);

        // The counter only moves on imports/builds, so it can drift from the head in both
        // directions: an L1 reorg rewinds the head below it, and canonical L1 derivation
        // with no gossip traffic advances the head past it. Report the head in both cases —
        // canonical blocks were inserted by this driver too, and the Catalyst sync gate
        // only opens when the reported value equals the execution head exactly.
        //
        // Report only — do NOT write the reconciled value back. `l2_head` is read without
        // the lock, so it can already be stale; persisting it could pin the stored counter
        // wrong until the next import/build. Reconciling only the reported value keeps the
        // counter intact, so the next poll recomputes against a fresh head and self-heals.
        let tracked = self.state.highest_unsafe().await;
        let highest_unsafe = reconcile_highest_unsafe(tracked, l2_head);
        if highest_unsafe < tracked {
            warn!(
                tracked,
                head = highest_unsafe,
                "highest_unsafe ahead of head; reporting clamped value"
            );
        } else if highest_unsafe > tracked {
            debug!(tracked, head = highest_unsafe, "highest_unsafe behind head; reporting head");
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
