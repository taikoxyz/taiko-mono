//! Event handler for P2P network events.
//!
//! This module processes incoming network events, including:
//! - Gossip commitments and txlists
//! - Peer connections/disconnections
//! - Driver submission for validated inputs
//! - Lookahead validation for signer and submission window

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkEvent;
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, uint256_to_u256};
use protocol::preconfirmation::PreconfSignerResolver;
use tokio::sync::{RwLock, broadcast};
use tracing::{debug, warn};

use crate::{
    codec::TxListCodec,
    driver_interface::{DriverClient, PreconfirmationInput},
    error::{PreconfirmationClientError, Result},
    state::PreconfirmationState,
    storage::{CommitmentStore, PendingCommitmentBuffer, PendingTxListBuffer},
    validation::rules::{
        is_eop_only, validate_commitment_basic_with_signer, validate_lookahead,
        validate_parent_linkage, validate_txlist_gossip,
    },
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
    D: DriverClient,
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
    /// Driver client for handing off to the driver.
    pub driver: Arc<D>,
    /// Expected slasher address for validation.
    pub expected_slasher: Option<preconfirmation_types::Bytes20>,
    /// Broadcast channel for outbound events.
    pub event_tx: broadcast::Sender<PreconfirmationEvent>,
    /// Lookahead resolver for signer and submission window validation.
    pub lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
}

/// Handler for processing P2P network events.
///
/// This component validates incoming gossip messages, stores commitments and txlists,
/// and submits preconfirmation inputs to the driver. It also validates commitments
/// against the lookahead resolver to ensure the correct signer and submission window.
pub struct EventHandler<D>
where
    D: DriverClient,
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
    /// Driver client for handing off to the driver.
    driver: Arc<D>,
    /// Expected slasher address for validation.
    expected_slasher: Option<preconfirmation_types::Bytes20>,
    /// Broadcast channel for outbound events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
    /// Lookahead resolver for signer and submission window validation.
    lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
}

impl<D> EventHandler<D>
where
    D: DriverClient,
{
    /// Create a new event handler with the required dependencies.
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
            lookahead_resolver: deps.lookahead_resolver,
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
    ///
    /// This method validates the commitment through multiple stages:
    /// 1. Basic validation (signature, format, slasher address)
    /// 2. Lookahead validation (signer and submission_window_end)
    /// 3. Parent linkage validation
    /// 4. Block number sequencing validation
    pub async fn handle_commitment(&self, commitment: SignedCommitment) -> Result<()> {
        self.handle_commitment_internal(commitment, false).await
    }

    /// Handle a catch-up commitment, allowing a parentless commitment if configured.
    pub async fn handle_catchup_commitment(
        &self,
        commitment: SignedCommitment,
        allow_parentless: bool,
    ) -> Result<()> {
        self.handle_commitment_internal(commitment, allow_parentless).await
    }

    /// Handle a commitment with optional parentless allowance.
    async fn handle_commitment_internal(
        &self,
        commitment: SignedCommitment,
        allow_parentless: bool,
    ) -> Result<()> {
        // Initialize a queue for commitment processing.
        let mut queue = vec![commitment];

        while let Some(commitment) = queue.pop() {
            // Extract the parent hash for linkage checks.
            let parent_hash = B256::from_slice(
                commitment.commitment.preconf.parent_preconfirmation_hash.as_ref(),
            );
            // Ignore genesis commitments.
            if parent_hash == B256::ZERO {
                debug!("ignoring genesis commitment");
                continue;
            }

            // Validate the commitment with basic rules (signature, format, slasher).
            let recovered_signer = match validate_commitment_basic_with_signer(
                &commitment,
                self.expected_slasher.as_ref(),
            ) {
                Ok(signer) => signer,
                Err(err) => {
                    warn!(error = %err, "dropping invalid commitment");
                    continue;
                }
            };

            // Get the commitment timestamp for lookahead lookup.
            let timestamp = uint256_to_u256(&commitment.commitment.preconf.timestamp);

            // Query the lookahead resolver for the expected slot info.
            let expected_slot_info =
                match self.lookahead_resolver.slot_info_for_timestamp(timestamp).await {
                    Ok(info) => info,
                    Err(err) => {
                        warn!(timestamp = %timestamp, error = %err, "lookahead resolver failed");
                        continue;
                    }
                };

            // Validate the signer and submission_window_end against lookahead expectations.
            if let Err(err) = validate_lookahead(&commitment, recovered_signer, &expected_slot_info)
            {
                warn!(error = %err, "dropping commitment with invalid lookahead");
                continue;
            }

            // Extract the current block number for sequencing.
            let current_block = uint256_to_u256(&commitment.commitment.preconf.block_number);
            // Derive the expected parent block number.
            let expected_parent = current_block.saturating_sub(U256::ONE);
            // Fetch the parent commitment if available.
            let parent = self.store.get_commitment(&expected_parent);
            // Proceed when the parent commitment is present.
            if let Some(parent) = parent {
                // Validate parent linkage using the parent preconfirmation.
                if let Err(err) = validate_parent_linkage(&commitment, &parent.commitment.preconf) {
                    warn!(error = %err, "dropping commitment with invalid parent linkage");
                    continue;
                }
                // Extract the parent block number for sequential checks.
                let parent_block = uint256_to_u256(&parent.commitment.preconf.block_number);
                let expected_block = parent_block + U256::ONE;
                if current_block != expected_block {
                    warn!(
                        current = %current_block,
                        expected = %expected_block,
                        "dropping commitment with non-sequential block number"
                    );
                    continue;
                }
            } else if allow_parentless {
                warn!(
                    block = %current_block,
                    "accepting catch-up commitment without parent"
                );
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
        if let Err(err) = validate_txlist_gossip(&txlist) {
            warn!(error = %err, "dropping invalid txlist gossip");
            return Ok(());
        }
        // Extract the txlist hash for indexing.
        let hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());
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
        let hash_bytes = Bytes32::try_from(hash.as_slice().to_vec()).expect("hash length 32");
        // Drain buffered children for this parent.
        let children = self.pending_parents.take_children(&hash_bytes);
        Ok(children)
    }

    /// Submit a commitment to the driver if txlist requirements are satisfied.
    async fn submit_if_ready(&self, commitment: SignedCommitment) -> Result<()> {
        if is_eop_only(&commitment) {
            // Build an input without transactions.
            let input = PreconfirmationInput::new(commitment, None, None);
            self.driver
                .submit_preconfirmation(input)
                .await
                .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?;
            return Ok(());
        }

        // Determine the txlist hash for the commitment.
        let txlist_hash = commitment.commitment.preconf.raw_tx_list_hash.clone();
        // Look up the raw txlist payload.
        let txlist = self.store.get_txlist(&B256::from_slice(txlist_hash.as_ref()));
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
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use alloy_primitives::{Address, U256};
    use async_trait::async_trait;
    use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};
    use secp256k1::{PublicKey, Secp256k1, SecretKey};
    use tokio::sync::{RwLock, broadcast};

    use super::{EventHandler, EventHandlerDeps};
    use crate::{
        codec::ZlibTxListCodec,
    driver_interface::{DriverClient, PreconfirmationInput},
        error::Result,
        state::PreconfirmationState,
        storage::{
            CommitmentStore, InMemoryCommitmentStore, PendingCommitmentBuffer, PendingTxListBuffer,
        },
    };
    use preconfirmation_types::{
        Bytes32, MAX_TXLIST_BYTES, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
        public_key_to_address, sign_commitment,
    };

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
    impl DriverClient for TestDriver {
        /// Record that a preconfirmation input was submitted.
        async fn submit_preconfirmation(&self, _input: PreconfirmationInput) -> Result<()> {
            self.submissions.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        /// Report event sync completion for tests.
        async fn wait_event_sync(&self) -> Result<()> {
            Ok(())
        }

        /// Return the latest event sync tip block number for tests.
        async fn event_sync_tip(&self) -> Result<U256> {
            Ok(U256::ZERO)
        }
    }

    /// Build a signed commitment for tests.
    fn build_signed_commitment(
        sk: &SecretKey,
        block_number: u64,
        parent_hash: Bytes32,
        timestamp: u64,
        submission_window_end: u64,
    ) -> SignedCommitment {
        // Build a minimal preconfirmation payload.
        let preconf = Preconfirmation {
            eop: true,
            block_number: Uint256::from(block_number),
            timestamp: Uint256::from(timestamp),
            submission_window_end: Uint256::from(submission_window_end),
            parent_preconfirmation_hash: parent_hash,
            ..Default::default()
        };
        // Build the commitment and sign it.
        let commitment = PreconfCommitment { preconf, ..Default::default() };
        let signature = sign_commitment(&commitment, sk).expect("sign commitment");
        SignedCommitment { commitment, signature }
    }

    /// Mock lookahead resolver for testing.
    struct MockResolver;

    #[async_trait]
    impl PreconfSignerResolver for MockResolver {
        async fn signer_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<Address> {
            Ok(Address::ZERO)
        }

        async fn slot_info_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo { signer: Address::ZERO, submission_window_end: U256::ZERO })
        }
    }

    /// Resolver that intentionally mismatches lookahead expectations.
    struct MismatchResolver;

    #[async_trait]
    impl PreconfSignerResolver for MismatchResolver {
        async fn signer_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<Address> {
            Ok(Address::ZERO)
        }

        async fn slot_info_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo { signer: Address::ZERO, submission_window_end: U256::ZERO })
        }
    }

    /// Resolver that matches a specific signer for catch-up tests.
    struct MatchingResolver {
        signer: Address,
        submission_window_end: U256,
    }

    #[async_trait]
    impl PreconfSignerResolver for MatchingResolver {
        async fn signer_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<Address> {
            Ok(self.signer)
        }

        async fn slot_info_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo {
                signer: self.signer,
                submission_window_end: self.submission_window_end,
            })
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
        let lookahead_resolver = Arc::new(MockResolver);
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
            lookahead_resolver,
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

    /// Invalid lookahead data drops the commitment without aborting the handler.
    #[tokio::test]
    async fn invalid_lookahead_does_not_abort() {
        // Build shared state and dependencies for the handler.
        let state = Arc::new(RwLock::new(PreconfirmationState::default()));
        let store = Arc::new(InMemoryCommitmentStore::new());
        let pending_parents = Arc::new(PendingCommitmentBuffer::new());
        let pending_txlists = Arc::new(PendingTxListBuffer::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MismatchResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);

        let handler = EventHandler::new(EventHandlerDeps {
            state,
            store: store.clone(),
            pending_parents,
            pending_txlists,
            codec,
            driver,
            expected_slasher: None,
            event_tx,
            lookahead_resolver,
        });

        // Build a signed commitment with a non-zero parent hash.
        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);

        // Process the commitment and expect it to be dropped without error.
        assert!(handler.handle_commitment(commitment).await.is_ok());
        assert!(store.latest_commitment().is_none());
    }

    /// Catch-up parentless commitments are processed without a parent.
    #[tokio::test]
    async fn catchup_parentless_is_processed() {
        // Build shared state and dependencies for the handler.
        let state = Arc::new(RwLock::new(PreconfirmationState::default()));
        let store = Arc::new(InMemoryCommitmentStore::new());
        let pending_parents = Arc::new(PendingCommitmentBuffer::new());
        let pending_txlists = Arc::new(PendingTxListBuffer::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);

        let sk = SecretKey::from_slice(&[3u8; 32]).expect("secret key");
        let signer = public_key_to_address(&PublicKey::from_secret_key(&Secp256k1::new(), &sk));
        let lookahead_resolver =
            Arc::new(MatchingResolver { signer, submission_window_end: U256::from(200u64) });

        let handler = EventHandler::new(EventHandlerDeps {
            state,
            store: store.clone(),
            pending_parents,
            pending_txlists,
            codec,
            driver: driver.clone(),
            expected_slasher: None,
            event_tx,
            lookahead_resolver,
        });

        // Build a signed commitment with a missing parent (parentless).
        let parent_hash = Bytes32::try_from(vec![9u8; 32]).expect("parent hash");
        let commitment = build_signed_commitment(&sk, 1, parent_hash, 100, 200);

        handler.handle_catchup_commitment(commitment, true).await.expect("parentless processed");

        assert!(store.latest_commitment().is_some());
        assert_eq!(driver.submissions(), 1);
    }
}
