//! Event handler for P2P network events.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::{NetworkCommand, NetworkEvent};
use preconfirmation_types::{
    Bytes20, RawTxListGossip, SignedCommitment, uint256_to_u256, validate_raw_txlist_gossip,
};
use protocol::{codec::ZlibTxListCodec, preconfirmation::PreconfSignerResolver};
use tokio::sync::{broadcast, mpsc::Sender};
use tracing::{debug, warn};

use crate::{
    driver_interface::DriverClient,
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    storage::CommitmentStore,
    validation::{validate_commitment_with_signer, validate_lookahead},
};

/// Events emitted by the preconfirmation client.
#[derive(Clone, Debug)]
pub enum PreconfirmationEvent {
    /// A new validated commitment was received.
    NewCommitment(Box<SignedCommitment>),
    /// A new validated txlist was received.
    NewTxList(B256),
    /// Catch-up completed and live gossip is active.
    Synced,
    /// A peer connected to the network.
    PeerConnected(String),
    /// A peer disconnected from the network.
    PeerDisconnected(String),
    /// A network or processing error occurred.
    Error(String),
}

/// Handler for processing P2P network events.
pub struct EventHandler<D>
where
    D: DriverClient,
{
    /// Commitment store used for persistence and pending buffers.
    pub(super) store: Arc<dyn CommitmentStore>,
    /// Codec used to decode compressed txlists.
    pub(super) codec: Arc<ZlibTxListCodec>,
    /// Driver client used to submit preconfirmation inputs.
    pub(super) driver: Arc<D>,
    /// Optional expected slasher for commitment validation.
    pub(super) expected_slasher: Option<Bytes20>,
    /// Broadcast channel for emitting client events.
    pub(super) event_tx: broadcast::Sender<PreconfirmationEvent>,
    /// Command tx for issuing network requests.
    pub(super) command_tx: Sender<NetworkCommand>,
    /// Lookahead resolver for signer and window validation.
    pub(super) lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
}

impl<D> EventHandler<D>
where
    D: DriverClient,
{
    /// Create a new event handler with the required dependencies.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        store: Arc<dyn CommitmentStore>,
        codec: Arc<ZlibTxListCodec>,
        driver: Arc<D>,
        expected_slasher: Option<Bytes20>,
        event_tx: broadcast::Sender<PreconfirmationEvent>,
        command_tx: Sender<NetworkCommand>,
        lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
    ) -> Self {
        Self { store, codec, driver, expected_slasher, event_tx, command_tx, lookahead_resolver }
    }

    /// Update the command tx used to notify the P2P node.
    pub(crate) fn set_command_tx(&mut self, command_tx: Sender<NetworkCommand>) {
        self.command_tx = command_tx;
    }

    /// Handle a network event.
    pub async fn handle_event(&self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::PeerConnected(peer_id) => {
                self.handle_peer_connected(peer_id.to_string());
            }
            NetworkEvent::PeerDisconnected(peer_id) => {
                self.handle_peer_disconnected(peer_id.to_string());
            }
            NetworkEvent::GossipSignedCommitment { from: _, msg } => {
                self.handle_commitment(*msg).await?;
            }
            NetworkEvent::GossipRawTxList { from: _, msg } => {
                self.handle_txlist(*msg).await?;
            }
            NetworkEvent::InboundCommitmentsRequest { from } => {
                debug!(peer = %from, "received inbound commitments request");
            }
            NetworkEvent::InboundRawTxListRequest { from } => {
                debug!(peer = %from, "received inbound raw txlist request");
            }
            NetworkEvent::InboundHeadRequest { from } => {
                debug!(peer = %from, "received inbound head request");
            }
            NetworkEvent::Error(err) => {
                if let Err(send_err) =
                    self.event_tx.send(PreconfirmationEvent::Error(err.to_string()))
                {
                    warn!(error = %send_err, "failed to emit error event");
                }
            }
            other => {
                debug!(event = ?other, "unhandled network event");
            }
        }
        Ok(())
    }

    /// Emit a peer-connected event to subscribers.
    fn handle_peer_connected(&self, peer_id: String) {
        if let Err(err) = self.event_tx.send(PreconfirmationEvent::PeerConnected(peer_id)) {
            warn!(error = %err, "failed to emit peer connected event");
        }
    }

    /// Emit a peer-disconnected event to subscribers.
    fn handle_peer_disconnected(&self, peer_id: String) {
        if let Err(err) = self.event_tx.send(PreconfirmationEvent::PeerDisconnected(peer_id)) {
            warn!(error = %err, "failed to emit peer disconnected event");
        }
    }

    /// Handle an incoming commitment.
    pub async fn handle_commitment(&self, commitment: SignedCommitment) -> Result<()> {
        metrics::counter!(PreconfirmationClientMetrics::COMMITMENTS_RECEIVED_TOTAL).increment(1);

        let current_block = uint256_to_u256(&commitment.commitment.preconf.block_number);

        // If we're behind the event sync tip, drop the commitment.
        if current_block <= self.driver.event_sync_tip().await? {
            self.store.remove_commitment(&current_block);
            let txlist_hash =
                B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref());
            self.store.remove_txlist(&txlist_hash);
            return Ok(());
        }

        // Validate the commitment signer.
        let recovered_signer =
            match validate_commitment_with_signer(&commitment, self.expected_slasher.as_ref()) {
                Ok(signer) => signer,
                Err(err) => {
                    warn!(error = %err, "dropping invalid commitment");
                    metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL)
                        .increment(1);
                    self.store.drop_pending_commitment(&current_block);
                    return Ok(());
                }
            };

        let timestamp = uint256_to_u256(&commitment.commitment.preconf.timestamp);

        let expected_slot_info =
            match self.lookahead_resolver.slot_info_for_timestamp(timestamp).await {
                Ok(info) => info,
                Err(err) => {
                    warn!(timestamp = %timestamp, error = %err, "lookahead resolver failed");
                    metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL)
                        .increment(1);
                    self.store.drop_pending_commitment(&current_block);
                    return Ok(());
                }
            };

        // Validate the lookahead (signer and submission window).
        if let Err(err) = validate_lookahead(&commitment, recovered_signer, &expected_slot_info) {
            warn!(error = %err, "dropping commitment with invalid lookahead");
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
            self.store.drop_pending_commitment(&current_block);
            return Ok(());
        }

        self.store.insert_commitment(commitment.clone());
        if let Err(err) =
            self.event_tx.send(PreconfirmationEvent::NewCommitment(Box::new(commitment.clone())))
        {
            warn!(error = %err, "failed to emit new commitment event");
        }

        self.update_head(&commitment).await;

        // If the txlist is available, try to submit contiguous commitments.
        let next_block = self.driver.preconf_tip().await? + U256::ONE;
        if current_block == next_block {
            self.try_submit_contiguous_from(next_block).await?;
        }
        Ok(())
    }

    /// Handle an inbound txlist gossip payload.
    pub async fn handle_txlist(&self, txlist: RawTxListGossip) -> Result<()> {
        metrics::counter!(PreconfirmationClientMetrics::TXLISTS_RECEIVED_TOTAL).increment(1);

        let hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());
        if let Err(err) = validate_raw_txlist_gossip(&txlist)
            .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))
        {
            warn!(error = %err, "dropping invalid txlist gossip");
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
            self.store.drop_pending_txlist(&hash);
            return Ok(());
        }
        self.store.insert_txlist(hash, txlist.clone());
        if let Err(err) = self.event_tx.send(PreconfirmationEvent::NewTxList(hash)) {
            warn!(error = %err, "failed to emit new txlist event");
        }

        if !self.store.take_awaiting_txlist(&txlist.raw_tx_list_hash).is_empty() {
            self.try_submit_contiguous_from(self.driver.preconf_tip().await? + U256::ONE).await?;
        }

        Ok(())
    }
}

#[cfg(test)]
pub(crate) const EVENT_HANDLER_MODULE_MARKER: () = ();
