//! Sidecar runner wiring the P2P client to the driver preconfirmation path.

use std::{collections::BTreeMap, sync::Arc};

use alloy::providers::Provider;
use anyhow::anyhow;
use p2p::{P2pClient, P2pClientHandle, SdkEvent};
use rpc::engine::PreconfEngine;
use tokio::sync::Mutex;
use tracing::{info, warn};

use crate::{
    error::DriverError,
    p2p_sidecar::{
        config::P2pSidecarConfig,
        engine::SidecarPreconfEngine,
        types::{CanonicalOutcome, ConfirmationDecision, PendingPreconf},
    },
    sync::event::EventSyncer,
};

/// Runtime handle for the in-process P2P sidecar.
pub struct P2pSidecar<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// P2P client handle used for control commands.
    handle: P2pClientHandle,
    /// Shared pending preconfirmation map keyed by block number.
    pending: Arc<Mutex<BTreeMap<u64, PendingPreconf>>>,
    /// Marker for provider type parameter.
    _marker: std::marker::PhantomData<P>,
}

impl<P> P2pSidecar<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Start the sidecar and spawn its background tasks.
    pub async fn start(
        config: P2pSidecarConfig,
        rpc: rpc::client::Client<P>,
        event_syncer: Arc<EventSyncer<P>>,
    ) -> Result<Self, DriverError> {
        // Shared pending preconfirmation map.
        let pending = Arc::new(Mutex::new(BTreeMap::new()));
        // Sidecar preconfirmation engine adapter.
        let sidecar_engine =
            SidecarPreconfEngine::new(rpc.clone(), event_syncer.clone(), pending.clone())
                .await
                .map_err(|err| DriverError::Other(anyhow!(err.to_string())))?;
        // P2P client configuration clone for mutation.
        let mut client_config = config.client.clone();
        // Shared preconfirmation engine adapter.
        let engine = Arc::new(sidecar_engine);
        // Preconfirmation engine injected into the P2P client config.
        client_config.engine = Some(engine.clone());
        // P2P client instance and event receiver.
        let (client, mut events) = P2pClient::new(client_config)
            .map_err(|err| DriverError::Other(anyhow!(err.to_string())))?;
        // P2P client handle for command dispatch.
        let handle = client.handle();
        // Engine head for catch-up start.
        let head = engine
            .engine_head()
            .await
            .map_err(|err| DriverError::Other(anyhow!(err.to_string())))?;
        // Local head block number for catch-up start.
        let local_head = head.block_number;
        if let Err(err) = handle.start_catchup(local_head, 0).await {
            // Catch-up command error.
            warn!(?err, "failed to start p2p catch-up");
        }
        // Spawn the P2P client event loop.
        tokio::spawn(async move {
            if let Err(err) = client.run().await {
                warn!(?err, "p2p sidecar client terminated");
            }
        });

        // Pending map clone for event processing task.
        let pending_for_events = pending.clone();
        // Spawn task to react to SDK events such as reorgs.
        tokio::spawn(async move {
            loop {
                // Next SDK event from the P2P client.
                let event = events.recv().await; // SDK event received from the client.
                let Ok(event) = event else { break };
                if let SdkEvent::Reorg { anchor_block_number, reason } = event {
                    warn!(anchor_block_number, %reason, "p2p sidecar observed reorg");
                    // Pending map guard for clearing entries.
                    let mut pending = pending_for_events.lock().await;
                    // Clear pending preconfirmations on reorg.
                    pending.clear();
                }
            }
        });

        // Canonical outcome receiver from the event syncer.
        let Some(mut canonical_rx) = event_syncer.canonical_outcome_receiver() else {
            return Err(DriverError::Other(anyhow!("missing canonical outcome channel")));
        };
        // Pending map clone for canonical outcome processing.
        let pending_for_canonical = pending.clone();
        // Handle clone for canonical outcome processing.
        let handle_for_canonical = handle.clone();
        // Spawn task to reconcile canonical outcomes with pending preconfirmations.
        tokio::spawn(async move {
            loop {
                // Next canonical outcome from the event syncer.
                let outcome = recv_canonical_outcome(&mut canonical_rx).await;
                let Some(outcome) = outcome else { break };
                // Pending map guard for outcome evaluation.
                let mut pending = pending_for_canonical.lock().await;
                // Decision after evaluating the canonical outcome.
                let decision = evaluate_canonical_outcome(&mut pending, &outcome);
                drop(pending);
                match decision {
                    ConfirmationDecision::Confirmed { block_number, submission_window_end } => {
                        info!(block_number, "preconfirmation confirmed by canonical chain");
                        if let Err(err) = handle_for_canonical
                            .update_head(block_number, submission_window_end)
                            .await
                        {
                            warn!(?err, "failed to update p2p head after confirmation");
                        }
                    }
                    ConfirmationDecision::Reorg { block_number, expected_hash, actual_hash } => {
                        let reason = format!(
                            "canonical hash mismatch at {block_number}: expected {expected_hash:?}, got {actual_hash:?}"
                        );
                        warn!(block_number, "preconfirmation diverged from canonical chain");
                        if let Err(err) =
                            handle_for_canonical.notify_reorg(block_number, reason).await
                        {
                            warn!(?err, "failed to notify p2p reorg");
                        }
                        // Pending map guard for clearing entries.
                        let mut pending = pending_for_canonical.lock().await;
                        // Clear pending preconfirmations after divergence.
                        pending.clear();
                    }
                    ConfirmationDecision::Noop => {}
                }
            }
        });

        Ok(Self { handle, pending, _marker: std::marker::PhantomData })
    }

    /// Access the P2P client handle.
    pub fn handle(&self) -> &P2pClientHandle {
        &self.handle
    }

    /// Access the shared pending preconfirmation map.
    pub fn pending(&self) -> &Arc<Mutex<BTreeMap<u64, PendingPreconf>>> {
        &self.pending
    }
}

/// Receive the next canonical outcome, skipping lagged broadcasts.
async fn recv_canonical_outcome(
    receiver: &mut tokio::sync::broadcast::Receiver<CanonicalOutcome>,
) -> Option<CanonicalOutcome> {
    // Loop until an outcome is received or the channel closes.
    loop {
        match receiver.recv().await {
            Ok(outcome) => return Some(outcome),
            Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
            Err(tokio::sync::broadcast::error::RecvError::Closed) => return None,
        }
    }
}

/// Evaluate a canonical outcome against pending preconfirmations.
fn evaluate_canonical_outcome(
    pending: &mut BTreeMap<u64, PendingPreconf>,
    outcome: &CanonicalOutcome,
) -> ConfirmationDecision {
    // Pending entry removed for the canonical block number.
    let pending_entry = pending.remove(&outcome.block_number);
    let Some(pending_entry) = pending_entry else {
        // Pending entry matched to the outcome.
        return ConfirmationDecision::Noop;
    };
    if pending_entry.block_hash == outcome.block_hash {
        return ConfirmationDecision::Confirmed {
            block_number: outcome.block_number,
            submission_window_end: pending_entry.submission_window_end,
        };
    }
    ConfirmationDecision::Reorg {
        block_number: outcome.block_number,
        expected_hash: pending_entry.block_hash,
        actual_hash: outcome.block_hash,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::B256;
    use tokio::sync::broadcast;

    #[test]
    fn canonical_outcome_confirms_matching_hash() {
        // Pending map seeded with a single entry.
        let mut pending = BTreeMap::new();
        // Pending block hash.
        let pending_hash = B256::from([1u8; 32]);
        // Pending block number.
        let block_number = 10u64;
        // Pending entry inserted for confirmation.
        let pending_entry = PendingPreconf { block_hash: pending_hash, submission_window_end: 99 };
        pending.insert(block_number, pending_entry);
        // Canonical outcome matching the pending hash.
        let outcome = CanonicalOutcome { block_number, block_hash: pending_hash };

        // Decision after evaluating the canonical outcome.
        let decision = evaluate_canonical_outcome(&mut pending, &outcome);

        assert!(matches!(
            decision,
            ConfirmationDecision::Confirmed { block_number: 10, submission_window_end: 99 }
        ));
    }

    #[test]
    fn canonical_outcome_detects_reorg_on_hash_mismatch() {
        // Pending map seeded with a single entry.
        let mut pending = BTreeMap::new();
        // Pending block hash.
        let pending_hash = B256::from([2u8; 32]);
        // Canonical block hash that differs from pending.
        let canonical_hash = B256::from([3u8; 32]);
        // Pending block number.
        let block_number = 11u64;
        // Pending entry inserted for confirmation.
        let pending_entry = PendingPreconf { block_hash: pending_hash, submission_window_end: 77 };
        pending.insert(block_number, pending_entry);
        // Canonical outcome with a different hash.
        let outcome = CanonicalOutcome { block_number, block_hash: canonical_hash };

        // Decision after evaluating the canonical outcome.
        let decision = evaluate_canonical_outcome(&mut pending, &outcome);

        assert!(matches!(
            decision,
            ConfirmationDecision::Reorg { block_number: 11, expected_hash, actual_hash }
                if expected_hash == pending_hash && actual_hash == canonical_hash
        ));
    }

    #[test]
    fn canonical_outcome_ignores_missing_pending() {
        // Pending map with no matching entry.
        let mut pending = BTreeMap::new();
        // Canonical outcome with no pending entry.
        let outcome = CanonicalOutcome { block_number: 12, block_hash: B256::from([4u8; 32]) };

        // Decision after evaluating the canonical outcome.
        let decision = evaluate_canonical_outcome(&mut pending, &outcome);

        assert!(matches!(decision, ConfirmationDecision::Noop));
    }

    #[tokio::test]
    async fn canonical_outcome_receiver_skips_lagged_messages() {
        // Broadcast channel used to simulate lagged canonical outcomes.
        let (tx, mut rx) = broadcast::channel(1);
        // First canonical outcome sent before receiver listens.
        let first = CanonicalOutcome { block_number: 20, block_hash: B256::from([5u8; 32]) };
        // Second canonical outcome expected after lagged message is skipped.
        let second = CanonicalOutcome { block_number: 21, block_hash: B256::from([6u8; 32]) };

        let _ = tx.send(first);
        let _ = tx.send(second);

        // Received canonical outcome after skipping lagged entries.
        let received = recv_canonical_outcome(&mut rx).await.expect("receiver closed");

        assert_eq!(received.block_number, second.block_number);
        assert_eq!(received.block_hash, second.block_hash);
    }
}
