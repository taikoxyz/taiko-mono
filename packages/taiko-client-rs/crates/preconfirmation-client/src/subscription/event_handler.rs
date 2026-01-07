//! Event handler for P2P network events.
//!
//! This module processes incoming network events, including:
//! - Gossip commitments and txlists
//! - Peer connections/disconnections
//! - Driver submission for validated inputs

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkEvent;
use preconfirmation_types::{
    RawTxListGossip, SignedCommitment, b256_to_bytes32, bytes32_to_b256, uint256_to_u256,
};
use tokio::sync::{RwLock, broadcast};
use tracing::debug;

use crate::{
    codec::TxListCodec,
    driver_interface::{DriverSubmitter, PreconfirmationInput},
    error::{PreconfirmationClientError, Result},
    state::PreconfirmationState,
    storage::{CommitmentStore, PendingCommitmentBuffer, PendingTxListBuffer},
    validation::rules::{self, validate_commitment_basic, validate_parent_linkage, validate_txlist_gossip},
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

/// Dependencies required to construct an event handler.
pub struct EventHandlerDeps<D>
where
    D: DriverSubmitter,
{
    /// Client state for tracking sync status and peers.
    pub state: Arc<RwLock<PreconfirmationState>>,
    /// Commitment store for caching commitments and txlists.
    pub store: Arc<dyn CommitmentStore>,
    /// Pending buffer for out-of-order commitments.
    pub pending_parents: Arc<PendingCommitmentBuffer>,
    /// Pending buffer for commitments waiting on txlists.
    pub pending_txlists: Arc<PendingTxListBuffer>,
    /// Txlist codec for decompression.
    pub codec: Arc<dyn TxListCodec>,
    /// Driver submitter for handing off to the driver.
    pub driver: Arc<D>,
    /// Expected slasher address for validation.
    pub expected_slasher: Option<preconfirmation_types::Bytes20>,
    /// Broadcast channel for outbound events.
    pub event_tx: broadcast::Sender<PreconfirmationEvent>,
}

/// Handler for processing P2P network events.
///
/// This component validates incoming gossip messages, stores commitments and txlists,
/// and submits preconfirmation inputs to the driver.
pub struct EventHandler<D>
where
    D: DriverSubmitter,
{
    /// Client state for tracking sync status and peers.
    state: Arc<RwLock<PreconfirmationState>>,
    /// Commitment store for caching commitments and txlists.
    store: Arc<dyn CommitmentStore>,
    /// Pending buffer for out-of-order commitments.
    pending_parents: Arc<PendingCommitmentBuffer>,
    /// Pending buffer for commitments waiting on txlists.
    pending_txlists: Arc<PendingTxListBuffer>,
    /// Txlist codec for decompression.
    codec: Arc<dyn TxListCodec>,
    /// Driver submitter for handing off to the driver.
    driver: Arc<D>,
    /// Expected slasher address for validation.
    expected_slasher: Option<preconfirmation_types::Bytes20>,
    /// Broadcast channel for outbound events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
}

impl<D> EventHandler<D>
where
    D: DriverSubmitter,
{
    /// Create a new event handler.
    pub fn new(deps: EventHandlerDeps<D>) -> Self {
        Self {
            state: deps.state,
            store: deps.store,
            pending_parents: deps.pending_parents,
            pending_txlists: deps.pending_txlists,
            codec: deps.codec,
            driver: deps.driver,
            expected_slasher: deps.expected_slasher,
            event_tx: deps.event_tx,
        }
    }

    /// Handle a network event.
    pub async fn handle_event(&self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::PeerConnected(peer_id) => {
                // Convert the peer id to a string for the event.
                let peer = peer_id.to_string();
                self.handle_peer_connected(peer).await;
            }
            NetworkEvent::PeerDisconnected(peer_id) => {
                // Convert the peer id to a string for the event.
                let peer = peer_id.to_string();
                self.handle_peer_disconnected(peer).await;
            }
            NetworkEvent::GossipSignedCommitment { from: _, msg } => {
                // Process the commitment payload.
                self.handle_commitment(*msg).await?;
            }
            NetworkEvent::GossipRawTxList { from: _, msg } => {
                // Process the txlist payload.
                self.handle_txlist(*msg).await?;
            }
            NetworkEvent::Error(err) => {
                // Emit an error event for observers.
                let _ = self.event_tx.send(PreconfirmationEvent::Error(err.to_string()));
            }
            other => {
                // Log unhandled events for observability.
                debug!(event = ?other, "unhandled network event");
            }
        }
        Ok(())
    }

    /// Update state and emit a peer connected event.
    async fn handle_peer_connected(&self, peer_id: String) {
        // Acquire a mutable state guard.
        let mut guard = self.state.write().await;
        guard.increment_peers();
        // Emit the peer connected event.
        let _ = self.event_tx.send(PreconfirmationEvent::PeerConnected(peer_id));
    }

    /// Update state and emit a peer disconnected event.
    async fn handle_peer_disconnected(&self, peer_id: String) {
        // Acquire a mutable state guard.
        let mut guard = self.state.write().await;
        guard.decrement_peers();
        // Emit the peer disconnected event.
        let _ = self.event_tx.send(PreconfirmationEvent::PeerDisconnected(peer_id));
    }

    /// Handle an incoming commitment.
    pub async fn handle_commitment(&self, commitment: SignedCommitment) -> Result<()> {
        // Initialize a queue for commitment processing.
        let mut queue = vec![commitment];

        while let Some(commitment) = queue.pop() {
            // Extract the parent hash for linkage checks.
            let parent_hash =
                bytes32_to_b256(&commitment.commitment.preconf.parent_preconfirmation_hash);
            // Ignore genesis commitments.
            if parent_hash == B256::ZERO {
                debug!("ignoring genesis commitment");
                continue;
            }

            // Validate the commitment with basic rules.
            validate_commitment_basic(&commitment, self.expected_slasher.as_ref())?;

            // Extract the current block number for sequencing.
            let current_block = uint256_to_u256(&commitment.commitment.preconf.block_number);
            // Derive the expected parent block number.
            let expected_parent = current_block.saturating_sub(U256::ONE);
            // Fetch the parent commitment if available.
            let parent = self.store.get_commitment(&expected_parent);
            // Proceed when the parent commitment is present.
            if let Some(parent) = parent {
                // Validate parent linkage using the parent preconfirmation.
                validate_parent_linkage(&commitment, &parent.commitment.preconf)?;
                // Extract the parent block number for sequential checks.
                let parent_block = uint256_to_u256(&parent.commitment.preconf.block_number);
                if current_block != parent_block + U256::ONE {
                    return Err(PreconfirmationClientError::Validation(
                        "block number not sequential".to_string(),
                    ));
                }
            } else {
                // Clone the parent hash before moving the commitment.
                let parent_hash = commitment.commitment.preconf.parent_preconfirmation_hash.clone();
                // Buffer this commitment until the parent arrives.
                self.pending_parents.add(&parent_hash, commitment);
                continue;
            }

            // Store the validated commitment.
            self.store.insert_commitment(commitment.clone());
            // Emit the commitment event.
            let _ = self
                .event_tx
                .send(PreconfirmationEvent::NewCommitment(Box::new(commitment.clone())));

            // Update the head snapshot.
            // Acquire a mutable state guard.
            let mut guard = self.state.write().await;
            // Build the head snapshot for the state.
            let head = preconfirmation_types::PreconfHead {
                block_number: commitment.commitment.preconf.block_number.clone(),
                submission_window_end: commitment.commitment.preconf.submission_window_end.clone(),
            };
            guard.set_head(head);

            // Collect buffered children waiting on this commitment.
            let children = self.collect_pending_children(&commitment)?;
            // Submit to the driver when txlist requirements are satisfied.
            self.submit_if_ready(commitment).await?;
            // Queue any children for processing.
            queue.extend(children);
        }

        Ok(())
    }

    /// Handle an incoming txlist.
    async fn handle_txlist(&self, txlist: RawTxListGossip) -> Result<()> {
        // Validate the txlist payload.
        validate_txlist_gossip(&txlist)?;
        // Extract the txlist hash for indexing.
        let hash = bytes32_to_b256(&txlist.raw_tx_list_hash);
        // Store the txlist for later use.
        self.store.insert_txlist(hash, txlist.clone());
        // Emit the txlist event.
        let _ = self.event_tx.send(PreconfirmationEvent::NewTxList(hash));

        // Drain commitments waiting on this txlist.
        let waiting = self.pending_txlists.take_waiting(&txlist.raw_tx_list_hash);
        for commitment in waiting {
            // Submit if now ready.
            self.submit_if_ready(commitment).await?;
        }

        Ok(())
    }

    /// Collect children buffered on the current commitment hash.
    fn collect_pending_children(
        &self,
        commitment: &SignedCommitment,
    ) -> Result<Vec<SignedCommitment>> {
        // Compute the preconfirmation hash for the commitment.
        let hash = preconfirmation_types::preconfirmation_hash(&commitment.commitment.preconf)
            .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))?;
        // Convert to Bytes32 for the buffer lookup.
        let hash_bytes = b256_to_bytes32(hash);
        // Drain buffered children for this parent.
        let children = self.pending_parents.take_children(&hash_bytes);
        Ok(children)
    }

    /// Submit a commitment to the driver if txlist requirements are satisfied.
    async fn submit_if_ready(&self, commitment: SignedCommitment) -> Result<()> {
        if rules::is_eop_only(&commitment) {
            // Build an input without transactions.
            let input = PreconfirmationInput::new(commitment, None, None);
            self.driver
                .submit_preconfirmation(input)
                .await
                .map_err(|err| PreconfirmationClientError::DriverSubmit(err.to_string()))?;
            return Ok(());
        }

        // Determine the txlist hash for the commitment.
        let txlist_hash = commitment.commitment.preconf.raw_tx_list_hash.clone();
        // Look up the raw txlist payload.
        let txlist = self.store.get_txlist(&bytes32_to_b256(&txlist_hash));
        // Require the txlist to be present before submission.
        let Some(txlist) = txlist else {
            // Buffer the commitment until the txlist arrives.
            self.pending_txlists.add(&txlist_hash, commitment);
            return Ok(());
        };

        // Decode the txlist into transaction bytes.
        let transactions = self.codec.decode(txlist.txlist.as_ref())?;
        // Build the input for the driver.
        let input =
            PreconfirmationInput::new(commitment, Some(transactions), Some(txlist.txlist.to_vec()));
        self.driver
            .submit_preconfirmation(input)
            .await
            .map_err(|err| PreconfirmationClientError::DriverSubmit(err.to_string()))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, atomic::{AtomicUsize, Ordering}};

    use async_trait::async_trait;
    use tokio::sync::{RwLock, broadcast};

    use super::{EventHandler, EventHandlerDeps};
    use crate::{
        codec::ZlibTxListCodec,
        driver_interface::{DriverSubmitter, PreconfirmationInput},
        error::Result,
        state::PreconfirmationState,
        storage::{CommitmentStore, InMemoryCommitmentStore, PendingCommitmentBuffer, PendingTxListBuffer},
    };
    use preconfirmation_types::{PreconfCommitment, Preconfirmation, SignedCommitment, MAX_TXLIST_BYTES};

    /// Test driver that records submit calls.
    struct TestDriver {
        /// Count of submitted preconfirmation inputs.
        submissions: AtomicUsize,
    }

    impl TestDriver {
        /// Create a new test driver with zero submissions.
        fn new() -> Self {
            Self { submissions: AtomicUsize::new(0) }
        }

        /// Fetch the current submission count.
        fn submissions(&self) -> usize {
            self.submissions.load(Ordering::SeqCst)
        }
    }

    #[async_trait]
    impl DriverSubmitter for TestDriver {
        /// Record that a preconfirmation input was submitted.
        async fn submit_preconfirmation(&self, _input: PreconfirmationInput) -> Result<()> {
            self.submissions.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }
    }

    /// Genesis commitments are ignored and do not update state or storage.
    #[tokio::test]
    async fn genesis_commitment_is_ignored() {
        // Build shared state and dependencies for the handler.
        let state = Arc::new(RwLock::new(PreconfirmationState::default()));
        let store = Arc::new(InMemoryCommitmentStore::new());
        let pending_parents = Arc::new(PendingCommitmentBuffer::new());
        let pending_txlists = Arc::new(PendingTxListBuffer::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);

        let handler = EventHandler::new(EventHandlerDeps {
            state,
            store: store.clone(),
            pending_parents,
            pending_txlists,
            codec,
            driver: driver.clone(),
            expected_slasher: None,
            event_tx,
        });

        // Build a commitment with a zero parent hash (genesis).
        let preconf = Preconfirmation::default();
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };

        // Process the commitment and expect it to be ignored.
        handler.handle_commitment(commitment).await.expect("genesis ignored");
        assert!(store.latest_commitment().is_none());
        assert_eq!(driver.submissions(), 0);
    }
}
