//! Event handler for P2P network events.
//!
//! This module processes incoming network events, including:
//! - Gossip commitments and txlists
//! - Peer connections/disconnections
//! - Driver submission for validated inputs
//! - Lookahead validation for signer and submission window

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::{NetworkCommand, NetworkEvent};
use preconfirmation_types::{
    Bytes20, PreconfHead, RawTxListGossip, SignedCommitment, uint256_to_u256,
};
use protocol::preconfirmation::PreconfSignerResolver;
use tokio::sync::{broadcast, mpsc::Sender};
use tracing::{debug, warn};

use crate::{
    codec::ZlibTxListCodec,
    driver_interface::{DriverClient, PreconfirmationInput},
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    storage::CommitmentStore,
    validation::rules::{is_eop_only, validate_commitment_with_signer, validate_lookahead},
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
///
/// This component validates incoming gossip messages, stores commitments and txlists,
/// and submits preconfirmation inputs to the driver. It also validates commitments
/// against the lookahead resolver to ensure the correct signer and submission window.
pub struct EventHandler<D>
where
    D: DriverClient,
{
    /// Commitment store for caching commitments and txlists.
    store: Arc<dyn CommitmentStore>,
    /// Txlist codec for decompression.
    codec: Arc<ZlibTxListCodec>,
    /// Driver client for handing off to the driver.
    driver: Arc<D>,
    /// Expected slasher address for validation.
    expected_slasher: Option<Bytes20>,
    /// Broadcast channel for outbound events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
    /// Command sender for updating the P2P head.
    command_sender: Sender<NetworkCommand>,
    /// Lookahead resolver for signer and submission window validation.
    lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
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
        command_sender: Sender<NetworkCommand>,
        lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
    ) -> Self {
        Self {
            store,
            codec,
            driver,
            expected_slasher,
            event_tx,
            command_sender,
            lookahead_resolver,
        }
    }

    /// Update the command sender used to notify the P2P node.
    pub(crate) fn set_command_sender(&mut self, command_sender: Sender<NetworkCommand>) {
        self.command_sender = command_sender;
    }

    /// Handle a network event.
    pub async fn handle_event(&self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::PeerConnected(peer_id) => {
                // Convert the peer id to a string for the event.
                let peer = peer_id.to_string();
                self.handle_peer_connected(peer);
            }
            NetworkEvent::PeerDisconnected(peer_id) => {
                // Convert the peer id to a string for the event.
                let peer = peer_id.to_string();
                self.handle_peer_disconnected(peer);
            }
            NetworkEvent::GossipSignedCommitment { from: _, msg } => {
                // Process the commitment payload.
                self.handle_commitment(*msg).await?;
            }
            NetworkEvent::GossipRawTxList { from: _, msg } => {
                // Process the txlist payload.
                self.handle_txlist(*msg).await?;
            }
            NetworkEvent::InboundCommitmentsRequest { from } => {
                // Commitments are served by the P2P node from the shared store.
                debug!(peer = %from, "received inbound commitments request");
            }
            NetworkEvent::InboundRawTxListRequest { from } => {
                // Raw txlists are served by the P2P node from the shared store.
                debug!(peer = %from, "received inbound raw txlist request");
            }
            NetworkEvent::InboundHeadRequest { from } => {
                // Heads are served by the P2P node using the updated head snapshot.
                debug!(peer = %from, "received inbound head request");
            }
            NetworkEvent::Error(err) => {
                // Emit an error event for observers.
                if let Err(send_err) =
                    self.event_tx.send(PreconfirmationEvent::Error(err.to_string()))
                {
                    warn!(error = %send_err, "failed to emit error event");
                }
            }
            other => {
                // Log unhandled events for observability.
                debug!(event = ?other, "unhandled network event");
            }
        }
        Ok(())
    }

    /// Emit a peer connected event.
    fn handle_peer_connected(&self, peer_id: String) {
        if let Err(err) = self.event_tx.send(PreconfirmationEvent::PeerConnected(peer_id)) {
            warn!(error = %err, "failed to emit peer connected event");
        }
    }

    /// Emit a peer disconnected event.
    fn handle_peer_disconnected(&self, peer_id: String) {
        if let Err(err) = self.event_tx.send(PreconfirmationEvent::PeerDisconnected(peer_id)) {
            warn!(error = %err, "failed to emit peer disconnected event");
        }
    }

    /// Handle an incoming commitment.
    ///
    /// This method validates the commitment through multiple stages:
    /// 1. Basic validation (signature, format, slasher address)
    /// 2. Lookahead validation (signer and submission_window_end)
    pub async fn handle_commitment(&self, commitment: SignedCommitment) -> Result<()> {
        metrics::counter!(PreconfirmationClientMetrics::COMMITMENTS_RECEIVED_TOTAL).increment(1);

        // Extract the current block number for reuse across checks.
        let current_block = uint256_to_u256(&commitment.commitment.preconf.block_number);

        // Drop commitments at or below the driver event sync tip.
        if current_block <= self.driver.event_sync_tip().await? {
            self.store.remove_commitment(&current_block);
            let txlist_hash =
                B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref());
            self.store.remove_txlist(&txlist_hash);
            return Ok(());
        }

        // Validate the commitment with basic rules (signature, format, slasher).
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

        // Get the commitment timestamp for lookahead lookup.
        let timestamp = uint256_to_u256(&commitment.commitment.preconf.timestamp);

        // Query the lookahead resolver for the expected slot info.
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

        // Validate the signer and submission_window_end against lookahead expectations.
        if let Err(err) = validate_lookahead(&commitment, recovered_signer, &expected_slot_info) {
            warn!(error = %err, "dropping commitment with invalid lookahead");
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
            self.store.drop_pending_commitment(&current_block);
            return Ok(());
        }

        // Store the validated commitment.
        self.store.insert_commitment(commitment.clone());
        // Emit the commitment event.
        if let Err(err) =
            self.event_tx.send(PreconfirmationEvent::NewCommitment(Box::new(commitment.clone())))
        {
            warn!(error = %err, "failed to emit new commitment event");
        }

        // Update the head snapshot across store, state, and P2P node.
        self.update_head(&commitment).await;

        // Attempt to submit contiguous commitments only when the incoming block is next.
        let next_block = self.driver.preconf_tip().await? + U256::ONE;
        if current_block == next_block {
            self.try_submit_contiguous_from(next_block).await?;
        }
        Ok(())
    }

    /// Handle a catch-up commitment using the standard validation path.
    pub async fn handle_catchup_commitment(&self, commitment: SignedCommitment) -> Result<()> {
        self.handle_commitment(commitment).await
    }

    /// Handle an incoming txlist.
    async fn handle_txlist(&self, txlist: RawTxListGossip) -> Result<()> {
        metrics::counter!(PreconfirmationClientMetrics::TXLISTS_RECEIVED_TOTAL).increment(1);

        // Extract the txlist hash for indexing.
        let hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());
        // Validate the txlist payload.
        if let Err(err) = preconfirmation_types::validate_raw_txlist_gossip(&txlist)
            .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))
        {
            warn!(error = %err, "dropping invalid txlist gossip");
            metrics::counter!(PreconfirmationClientMetrics::VALIDATION_FAILURES_TOTAL).increment(1);
            self.store.drop_pending_txlist(&hash);
            return Ok(());
        }
        // Store the txlist for later use.
        self.store.insert_txlist(hash, txlist.clone());
        // Emit the txlist event.
        if let Err(err) = self.event_tx.send(PreconfirmationEvent::NewTxList(hash)) {
            warn!(error = %err, "failed to emit new txlist event");
        }

        // Take commitments waiting on this txlist and trigger submission if any exist.
        if !self.store.take_awaiting_txlist(&txlist.raw_tx_list_hash).is_empty() {
            self.try_submit_contiguous_from(self.driver.preconf_tip().await? + U256::ONE).await?;
        }

        Ok(())
    }

    /// Attempt to submit contiguous commitments starting from the driver preconf tip.
    async fn try_submit_contiguous_from(&self, start: U256) -> Result<()> {
        let mut next = start;
        loop {
            let Some(commitment) = self.store.get_commitment(&next) else {
                break;
            };

            let submitted = self.submit_if_ready(commitment).await?;
            if !submitted {
                break;
            }

            next += U256::ONE;
        }

        Ok(())
    }

    /// Submit a commitment to the driver if txlist requirements are satisfied.
    async fn submit_if_ready(&self, commitment: SignedCommitment) -> Result<bool> {
        if is_eop_only(&commitment) {
            // Build an input without transactions.
            let input = PreconfirmationInput::new(commitment, None, None);
            match self.driver.submit_preconfirmation(input).await {
                Ok(()) => {
                    metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL)
                        .increment(1);
                }
                Err(err) => {
                    metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL)
                        .increment(1);
                    return Err(err);
                }
            }
            return Ok(true);
        }

        // Determine the txlist hash for the commitment.
        let txlist_hash = commitment.commitment.preconf.raw_tx_list_hash.clone();
        // Look up the raw txlist payload.
        let txlist = self.store.get_txlist(&B256::from_slice(txlist_hash.as_ref()));
        // Require the txlist to be present before submission.
        let Some(txlist) = txlist else {
            // Buffer the commitment until the txlist arrives.
            self.store.add_awaiting_txlist(&txlist_hash, commitment);
            return Ok(false);
        };

        // Decode the txlist into transaction bytes.
        let transactions = self.codec.decode(txlist.txlist.as_ref())?;
        // Build the input for the driver.
        let input =
            PreconfirmationInput::new(commitment, Some(transactions), Some(txlist.txlist.to_vec()));
        match self.driver.submit_preconfirmation(input).await {
            Ok(()) => {
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL)
                    .increment(1);
            }
            Err(err) => {
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL)
                    .increment(1);
                return Err(err);
            }
        }
        Ok(true)
    }

    /// Update the head snapshot across store and P2P node.
    async fn update_head(&self, commitment: &SignedCommitment) {
        // Build the head snapshot from the commitment.
        let head = PreconfHead {
            block_number: commitment.commitment.preconf.block_number.clone(),
            submission_window_end: commitment.commitment.preconf.submission_window_end.clone(),
        };

        // Only advance the head when this commitment is newer than the stored head.
        let new_block = uint256_to_u256(&head.block_number);
        if self.store.head().is_some_and(|h| new_block <= uint256_to_u256(&h.block_number)) {
            return;
        }

        // Persist the head in the commitment store.
        self.store.set_head(head.clone());

        let block_f64: f64 = new_block.into();
        metrics::gauge!(PreconfirmationClientMetrics::HEAD_BLOCK).set(block_f64);

        // Notify the P2P node so inbound get_head requests respond correctly.
        if let Err(err) = self.notify_head_update(head).await {
            warn!(error = %err, "failed to notify p2p head update");
        }
    }

    /// Notify the P2P node of a head update.
    async fn notify_head_update(&self, head: PreconfHead) -> Result<()> {
        self.command_sender
            .send(NetworkCommand::UpdateHead { head })
            .await
            .map_err(|err| PreconfirmationClientError::Network(err.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use alloy_primitives::{Address, B256, U256};
    use async_trait::async_trait;
    use preconfirmation_net::PreconfStorage;
    use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};
    use secp256k1::{PublicKey, Secp256k1, SecretKey};
    use tokio::sync::{broadcast, mpsc};

    use super::EventHandler;
    use crate::{
        codec::ZlibTxListCodec,
        driver_interface::{DriverClient, PreconfirmationInput},
    error::{DriverApiError, PreconfirmationClientError, Result},
        storage::{CommitmentStore, InMemoryCommitmentStore},
    };
    use preconfirmation_types::{
        Bytes32, MAX_TXLIST_BYTES, PreconfCommitment, PreconfHead, Preconfirmation,
        RawTxListGossip, SignedCommitment, TxListBytes, Uint256, keccak256_bytes,
        public_key_to_address, sign_commitment, uint256_to_u256,
    };

    /// Test driver that records submit calls and maintains a preconf tip.
    struct TestDriver {
        /// Count of submitted preconfirmation inputs.
        submissions: AtomicUsize,
        /// Current preconfirmation tip.
        preconf_tip: std::sync::RwLock<U256>,
        /// Current event sync tip.
        event_sync_tip: std::sync::RwLock<U256>,
    }

    impl TestDriver {
        /// Create a new test driver with zero submissions.
        fn new() -> Self {
            Self {
                submissions: AtomicUsize::new(0),
                preconf_tip: std::sync::RwLock::new(U256::ZERO),
                event_sync_tip: std::sync::RwLock::new(U256::ZERO),
            }
        }

        /// Create a test driver with a specific event sync tip.
        fn with_event_sync_tip(event_sync_tip: U256) -> Self {
            Self {
                submissions: AtomicUsize::new(0),
                preconf_tip: std::sync::RwLock::new(U256::ZERO),
                event_sync_tip: std::sync::RwLock::new(event_sync_tip),
            }
        }

        /// Fetch the current submission count.
        fn submissions(&self) -> usize {
            self.submissions.load(Ordering::SeqCst)
        }
    }

    #[async_trait]
    impl DriverClient for TestDriver {
        /// Record that a preconfirmation input was submitted.
        async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
            self.submissions.fetch_add(1, Ordering::SeqCst);
            if let Ok(mut guard) = self.preconf_tip.write() {
                *guard = uint256_to_u256(&input.commitment.commitment.preconf.block_number);
            }
            Ok(())
        }

        /// Report event sync completion for tests.
        async fn wait_event_sync(&self) -> Result<()> {
            Ok(())
        }

        /// Return the latest event sync tip block number for tests.
        async fn event_sync_tip(&self) -> Result<U256> {
            Ok(*self.event_sync_tip.read().expect("event sync tip"))
        }

        /// Return the latest preconfirmation tip block number for tests.
        async fn preconf_tip(&self) -> Result<U256> {
            Ok(*self.preconf_tip.read().expect("preconf tip"))
        }
    }

    #[tokio::test]
    async fn submit_if_ready_propagates_driver_error() {
        struct ErrorDriver;

        #[async_trait]
        impl DriverClient for ErrorDriver {
            async fn submit_preconfirmation(&self, _input: PreconfirmationInput) -> Result<()> {
                Err(PreconfirmationClientError::DriverInterface(
                    DriverApiError::MissingTransactions,
                ))
            }

            async fn wait_event_sync(&self) -> Result<()> {
                Ok(())
            }

            async fn event_sync_tip(&self) -> Result<U256> {
                Ok(U256::ZERO)
            }

            async fn preconf_tip(&self) -> Result<U256> {
                Ok(U256::ZERO)
            }
        }

        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(ErrorDriver);
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store,
            codec,
            driver,
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);

        let err = handler
            .submit_if_ready(commitment)
            .await
            .expect_err("expected driver error");

        assert!(matches!(
            err,
            PreconfirmationClientError::DriverInterface(DriverApiError::MissingTransactions)
        ));
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

    /// Genesis commitments are processed and update storage.
    #[tokio::test]
    async fn genesis_commitment_is_processed() {
        // Build dependencies for the handler.
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let sk = SecretKey::from_slice(&[3u8; 32]).expect("secret key");
        let signer = public_key_to_address(&PublicKey::from_secret_key(&Secp256k1::new(), &sk));
        let lookahead_resolver =
            Arc::new(MatchingResolver { signer, submission_window_end: U256::from(200u64) });

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver.clone(),
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        // Build a signed commitment with a zero parent hash (genesis).
        let parent_hash = Bytes32::try_from(vec![0u8; 32]).expect("parent hash");
        let commitment = build_signed_commitment(&sk, 1, parent_hash, 100, 200);

        // Process the commitment and expect it to be stored and submitted.
        handler.handle_commitment(commitment).await.expect("genesis processed");
        assert!(store.latest_commitment().is_some());
        assert_eq!(driver.submissions(), 1);
    }

    /// Invalid lookahead data drops the commitment without aborting the handler.
    #[tokio::test]
    async fn invalid_lookahead_does_not_abort() {
        // Build dependencies for the handler.
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        // Build a signed commitment with a non-zero parent hash.
        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);

        // Process the commitment and expect it to be dropped without error.
        assert!(handler.handle_commitment(commitment).await.is_ok());
        assert!(store.latest_commitment().is_none());
    }

    /// Dropped commitments should be evicted from pending storage.
    #[tokio::test]
    async fn invalid_commitment_evicts_pending() {
        // Build dependencies for the handler.
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        // Build a signed commitment with a non-zero parent hash.
        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);
        let block = U256::from(2);

        PreconfStorage::insert_commitment(store.as_ref(), block, commitment.clone());
        assert_eq!(store.pending_commitments_len(), 1);

        // Process the commitment and expect it to be dropped.
        assert!(handler.handle_commitment(commitment).await.is_ok());
        assert_eq!(store.pending_commitments_len(), 0);
    }

    /// Dropped txlists should be evicted from pending storage.
    #[tokio::test]
    async fn invalid_txlist_evicts_pending() {
        // Build dependencies for the handler.
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        // Build a txlist with a mismatched hash to trigger validation failure.
        let raw_tx_list_hash = Bytes32::try_from(vec![0u8; 32]).expect("txlist hash");
        let txlist = TxListBytes::try_from(vec![0xAB; 3]).expect("txlist bytes");
        let gossip = RawTxListGossip { raw_tx_list_hash, txlist };
        let hash = B256::from_slice(gossip.raw_tx_list_hash.as_ref());

        PreconfStorage::insert_txlist(store.as_ref(), hash, gossip.clone());
        assert_eq!(store.pending_txlists_len(), 1);

        // Process the txlist and expect it to be dropped.
        assert!(handler.handle_txlist(gossip).await.is_ok());
        assert_eq!(store.pending_txlists_len(), 0);
    }

    /// Parentless commitments are processed without a parent.
    #[tokio::test]
    async fn parentless_commitment_is_processed() {
        // Build dependencies for the handler.
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let sk = SecretKey::from_slice(&[3u8; 32]).expect("secret key");
        let signer = public_key_to_address(&PublicKey::from_secret_key(&Secp256k1::new(), &sk));
        let lookahead_resolver =
            Arc::new(MatchingResolver { signer, submission_window_end: U256::from(200u64) });

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver.clone(),
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        // Build a signed commitment with a missing parent (parentless).
        let parent_hash = Bytes32::try_from(vec![9u8; 32]).expect("parent hash");
        let commitment = build_signed_commitment(&sk, 1, parent_hash, 100, 200);

        handler.handle_commitment(commitment).await.expect("parentless processed");

        assert!(store.latest_commitment().is_some());
        assert_eq!(driver.submissions(), 1);
    }

    /// Contiguous commitments are submitted once the gap is filled.
    #[tokio::test]
    async fn contiguous_commitments_submit_when_gap_filled() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let sk = SecretKey::from_slice(&[3u8; 32]).expect("secret key");
        let signer = public_key_to_address(&PublicKey::from_secret_key(&Secp256k1::new(), &sk));
        let lookahead_resolver =
            Arc::new(MatchingResolver { signer, submission_window_end: U256::from(200u64) });

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver.clone(),
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        let parent_hash = Bytes32::try_from(vec![9u8; 32]).expect("parent hash");
        let commitment_two = build_signed_commitment(&sk, 2, parent_hash.clone(), 100, 200);
        handler.handle_commitment(commitment_two).await.expect("gap buffered");
        assert_eq!(driver.submissions(), 0);

        let commitment_one = build_signed_commitment(&sk, 1, parent_hash, 100, 200);
        handler.handle_commitment(commitment_one).await.expect("gap filled");
        assert_eq!(driver.submissions(), 2);
    }

    /// Commitments at or below the event sync tip are dropped with their txlists.
    #[tokio::test]
    async fn stale_commitments_are_dropped() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::with_event_sync_tip(U256::from(5u64)));
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let sk = SecretKey::from_slice(&[3u8; 32]).expect("secret key");
        let signer = public_key_to_address(&PublicKey::from_secret_key(&Secp256k1::new(), &sk));
        let lookahead_resolver =
            Arc::new(MatchingResolver { signer, submission_window_end: U256::from(200u64) });

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver.clone(),
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        let txlist_bytes = TxListBytes::try_from(vec![0xAB; 3]).expect("txlist bytes");
        let txlist_hash = keccak256_bytes(txlist_bytes.as_ref());
        let raw_tx_list_hash =
            Bytes32::try_from(txlist_hash.as_slice().to_vec()).expect("txlist hash");
        let gossip =
            RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };
        let hash = B256::from_slice(gossip.raw_tx_list_hash.as_ref());
        CommitmentStore::insert_txlist(store.as_ref(), hash, gossip.clone());

        let preconf = Preconfirmation {
            eop: true,
            block_number: Uint256::from(5u64),
            timestamp: Uint256::from(100u64),
            submission_window_end: Uint256::from(200u64),
            parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).expect("parent"),
            raw_tx_list_hash: raw_tx_list_hash.clone(),
            ..Default::default()
        };
        let commitment = PreconfCommitment { preconf, ..Default::default() };
        let signature = sign_commitment(&commitment, &sk).expect("sign commitment");
        let signed = SignedCommitment { commitment, signature };

        handler.handle_commitment(signed).await.expect("stale dropped");
        assert!(store.get_commitment(&U256::from(5u64)).is_none());
        assert!(CommitmentStore::get_txlist(store.as_ref(), &hash).is_none());
        assert_eq!(driver.submissions(), 0);
    }

    /// Valid txlists without commitments are retained until pruned.
    #[tokio::test]
    async fn txlists_without_commitments_are_retained() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        let txlist_bytes = TxListBytes::try_from(vec![0xAB; 3]).expect("txlist bytes");
        let txlist_hash = keccak256_bytes(txlist_bytes.as_ref());
        let raw_tx_list_hash =
            Bytes32::try_from(txlist_hash.as_slice().to_vec()).expect("txlist hash");
        let gossip =
            RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };
        let hash = B256::from_slice(gossip.raw_tx_list_hash.as_ref());

        assert!(handler.handle_txlist(gossip).await.is_ok());
        assert!(CommitmentStore::get_txlist(store.as_ref(), &hash).is_some());
    }

    /// Head update sends should surface errors when the channel is closed.
    #[tokio::test]
    async fn notify_head_update_reports_send_failure() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_sender, command_rx) = mpsc::channel(1);

        drop(command_rx);

        let handler = EventHandler::new(
            store,
            codec,
            driver,
            None,
            event_tx,
            command_sender,
            lookahead_resolver,
        );

        let head = PreconfHead {
            block_number: Uint256::from(1u64),
            submission_window_end: Uint256::from(2u64),
        };

        assert!(handler.notify_head_update(head).await.is_err());
    }
}
