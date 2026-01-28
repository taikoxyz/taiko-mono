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
    validate_raw_txlist_gossip,
};
use protocol::{codec::ZlibTxListCodec, preconfirmation::PreconfSignerResolver};
use tokio::sync::{broadcast, mpsc::Sender};
use tracing::{debug, info, warn};

use crate::{
    driver_interface::{DriverClient, PreconfirmationInput},
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    storage::CommitmentStore,
    validation::{is_eop_only, validate_commitment_with_signer, validate_lookahead},
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
    store: Arc<dyn CommitmentStore>,
    /// Codec used to decode compressed txlists.
    codec: Arc<ZlibTxListCodec>,
    /// Driver client used to submit preconfirmation inputs.
    driver: Arc<D>,
    /// Optional expected slasher for commitment validation.
    expected_slasher: Option<Bytes20>,
    /// Broadcast channel for emitting client events.
    event_tx: broadcast::Sender<PreconfirmationEvent>,
    /// Command tx for issuing network requests.
    command_tx: Sender<NetworkCommand>,
    /// Lookahead resolver for signer and window validation.
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
    async fn handle_txlist(&self, txlist: RawTxListGossip) -> Result<()> {
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

    /// Attempt to submit contiguous commitments starting at the provided block.
    async fn try_submit_contiguous_from(&self, start: U256) -> Result<()> {
        info!(start = %start, "attempting contiguous preconfirmation submit");
        let mut next = start;
        let mut submitted_count = 0usize;
        loop {
            let Some(commitment) = self.store.get_commitment(&next) else {
                debug!(
                    next = %next,
                    submitted_count,
                    "missing commitment; stopping contiguous submit"
                );
                break;
            };

            let submitted = self.submit_if_ready(commitment).await?;
            if !submitted {
                debug!(
                    next = %next,
                    submitted_count,
                    "commitment not ready; stopping contiguous submit"
                );
                break;
            }

            submitted_count += 1;
            next += U256::ONE;
        }

        info!(
            start = %start,
            next = %next,
            submitted_count,
            "contiguous submit finished"
        );
        Ok(())
    }

    /// Submit a commitment if its txlist is available and validation passes.
    async fn submit_if_ready(&self, commitment: SignedCommitment) -> Result<bool> {
        let block_number = uint256_to_u256(&commitment.commitment.preconf.block_number);
        let input = if is_eop_only(&commitment) {
            info!(block_number = %block_number, "submitting eop-only commitment");
            PreconfirmationInput::new(commitment, None, None)
        } else {
            let raw_tx_list_hash = commitment.commitment.preconf.raw_tx_list_hash.clone();
            let txlist_hash = B256::from_slice(raw_tx_list_hash.as_ref());
            let Some(txlist) = self.store.get_txlist(&txlist_hash) else {
                debug!(
                    block_number = %block_number,
                    txlist_hash = %txlist_hash,
                    "txlist missing; queuing commitment"
                );
                self.store.add_awaiting_txlist(&raw_tx_list_hash, commitment);
                return Ok(false);
            };

            info!(
                block_number = %block_number,
                txlist_hash = %txlist_hash,
                "txlist available; submitting commitment"
            );
            let transactions = self.codec.decode(txlist.txlist.as_ref()).map_err(|err| {
                warn!(block_number = %block_number, error = %err, "failed to decode txlist");
                PreconfirmationClientError::Codec(err.to_string())
            })?;
            PreconfirmationInput::new(commitment, Some(transactions), Some(txlist.txlist.to_vec()))
        };

        self.driver
            .submit_preconfirmation(input)
            .await
            .inspect(|()| {
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL)
                    .increment(1);
            })
            .inspect_err(|err| {
                warn!(block_number = %block_number, error = %err, "driver submit failed");
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL)
                    .increment(1);
            })?;

        info!(block_number = %block_number, "driver submit succeeded");
        Ok(true)
    }

    /// Update the local head snapshot based on a new commitment.
    async fn update_head(&self, commitment: &SignedCommitment) {
        let head = PreconfHead {
            block_number: commitment.commitment.preconf.block_number.clone(),
            submission_window_end: commitment.commitment.preconf.submission_window_end.clone(),
        };

        let new_block = uint256_to_u256(&head.block_number);
        if self.store.head().is_some_and(|h| new_block <= uint256_to_u256(&h.block_number)) {
            return;
        }

        self.store.set_head(head.clone());

        let block_f64: f64 = new_block.into();
        metrics::gauge!(PreconfirmationClientMetrics::HEAD_BLOCK).set(block_f64);

        if let Err(err) = self.notify_head_update(head).await {
            warn!(error = %err, "failed to notify p2p head update");
        }
    }

    /// Notify the P2P layer about a new head update.
    async fn notify_head_update(&self, head: PreconfHead) -> Result<()> {
        self.command_tx
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
    use protocol::{
        codec::ZlibTxListCodec,
        preconfirmation::{PreconfSignerResolver, PreconfSlotInfo},
    };
    use secp256k1::{PublicKey, Secp256k1, SecretKey};
    use tokio::sync::{broadcast, mpsc};

    use super::EventHandler;
    use crate::{
        driver_interface::{DriverClient, PreconfirmationInput},
        error::{DriverApiError, PreconfirmationClientError, Result},
        storage::{CommitmentStore, InMemoryCommitmentStore},
    };
    use preconfirmation_types::{
        Bytes32, MAX_TXLIST_BYTES, PreconfCommitment, PreconfHead, Preconfirmation,
        RawTxListGossip, SignedCommitment, TxListBytes, Uint256, keccak256_bytes,
        public_key_to_address, sign_commitment, uint256_to_u256,
    };

    struct TestDriver {
        submissions: AtomicUsize,
        preconf_tip: std::sync::RwLock<U256>,
        event_sync_tip: std::sync::RwLock<U256>,
    }

    impl TestDriver {
        fn new() -> Self {
            Self {
                submissions: AtomicUsize::new(0),
                preconf_tip: std::sync::RwLock::new(U256::ZERO),
                event_sync_tip: std::sync::RwLock::new(U256::ZERO),
            }
        }

        fn with_event_sync_tip(event_sync_tip: U256) -> Self {
            Self {
                submissions: AtomicUsize::new(0),
                preconf_tip: std::sync::RwLock::new(U256::ZERO),
                event_sync_tip: std::sync::RwLock::new(event_sync_tip),
            }
        }

        fn submissions(&self) -> usize {
            self.submissions.load(Ordering::SeqCst)
        }
    }

    #[async_trait]
    impl DriverClient for TestDriver {
        async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
            self.submissions.fetch_add(1, Ordering::SeqCst);
            if let Ok(mut guard) = self.preconf_tip.write() {
                *guard = uint256_to_u256(&input.commitment.commitment.preconf.block_number);
            }
            Ok(())
        }

        async fn wait_event_sync(&self) -> Result<()> {
            Ok(())
        }

        async fn event_sync_tip(&self) -> Result<U256> {
            Ok(*self.event_sync_tip.read().expect("event sync tip"))
        }

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
        let (command_tx, _command_rx) = mpsc::channel(8);

        let handler =
            EventHandler::new(store, codec, driver, None, event_tx, command_tx, lookahead_resolver);

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);

        let err = handler.submit_if_ready(commitment).await.expect_err("expected driver error");

        assert!(matches!(
            err,
            PreconfirmationClientError::DriverInterface(DriverApiError::MissingTransactions)
        ));
    }

    fn build_signed_commitment(
        sk: &SecretKey,
        block_number: u64,
        parent_hash: Bytes32,
        timestamp: u64,
        submission_window_end: u64,
    ) -> SignedCommitment {
        let preconf = Preconfirmation {
            eop: true,
            block_number: Uint256::from(block_number),
            timestamp: Uint256::from(timestamp),
            submission_window_end: Uint256::from(submission_window_end),
            parent_preconfirmation_hash: parent_hash,
            ..Default::default()
        };
        let commitment = PreconfCommitment { preconf, ..Default::default() };
        let signature = sign_commitment(&commitment, sk).expect("sign commitment");
        SignedCommitment { commitment, signature }
    }

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

    #[tokio::test]
    async fn genesis_commitment_is_processed() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

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
            command_tx,
            lookahead_resolver,
        );

        let parent_hash = Bytes32::try_from(vec![0u8; 32]).expect("parent hash");
        let commitment = build_signed_commitment(&sk, 1, parent_hash, 100, 200);

        handler.handle_commitment(commitment).await.expect("genesis processed");
        assert!(store.latest_commitment().is_some());
        assert_eq!(driver.submissions(), 1);
    }

    #[tokio::test]
    async fn invalid_lookahead_does_not_abort() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_tx,
            lookahead_resolver,
        );

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);

        assert!(handler.handle_commitment(commitment).await.is_ok());
        assert!(store.latest_commitment().is_none());
    }

    #[tokio::test]
    async fn invalid_commitment_evicts_pending() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_tx,
            lookahead_resolver,
        );

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let commitment = build_signed_commitment(&sk, 2, parent_hash, 100, 200);
        let block = U256::from(2);

        PreconfStorage::insert_commitment(store.as_ref(), block, commitment.clone());
        assert_eq!(store.pending_commitments_len(), 1);

        assert!(handler.handle_commitment(commitment).await.is_ok());
        assert_eq!(store.pending_commitments_len(), 0);
    }

    #[tokio::test]
    async fn invalid_txlist_evicts_pending() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_tx,
            lookahead_resolver,
        );

        let raw_tx_list_hash = Bytes32::try_from(vec![0u8; 32]).expect("txlist hash");
        let txlist = TxListBytes::try_from(vec![0xAB; 3]).expect("txlist bytes");
        let gossip = RawTxListGossip { raw_tx_list_hash, txlist };
        let hash = B256::from_slice(gossip.raw_tx_list_hash.as_ref());

        PreconfStorage::insert_txlist(store.as_ref(), hash, gossip.clone());
        assert_eq!(store.pending_txlists_len(), 1);

        assert!(handler.handle_txlist(gossip).await.is_ok());
        assert_eq!(store.pending_txlists_len(), 0);
    }

    #[tokio::test]
    async fn parentless_commitment_is_processed() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

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
            command_tx,
            lookahead_resolver,
        );

        let parent_hash = Bytes32::try_from(vec![9u8; 32]).expect("parent hash");
        let commitment = build_signed_commitment(&sk, 1, parent_hash, 100, 200);

        handler.handle_commitment(commitment).await.expect("parentless processed");

        assert!(store.latest_commitment().is_some());
        assert_eq!(driver.submissions(), 1);
    }

    #[tokio::test]
    async fn contiguous_commitments_submit_when_gap_filled() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

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
            command_tx,
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

    #[tokio::test]
    async fn stale_commitments_are_dropped() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::with_event_sync_tip(U256::from(5u64)));
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

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
            command_tx,
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

    #[tokio::test]
    async fn txlists_without_commitments_are_retained() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, _command_rx) = mpsc::channel(8);

        let handler = EventHandler::new(
            store.clone(),
            codec,
            driver,
            None,
            event_tx,
            command_tx,
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

    #[tokio::test]
    async fn notify_head_update_reports_send_failure() {
        let store = Arc::new(InMemoryCommitmentStore::new());
        let codec = Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES));
        let driver = Arc::new(TestDriver::new());
        let lookahead_resolver = Arc::new(MockResolver);
        let (event_tx, _event_rx) = broadcast::channel(16);
        let (command_tx, command_rx) = mpsc::channel(1);

        drop(command_rx);

        let handler =
            EventHandler::new(store, codec, driver, None, event_tx, command_tx, lookahead_resolver);

        let head = PreconfHead {
            block_number: Uint256::from(1u64),
            submission_window_end: Uint256::from(2u64),
        };

        assert!(handler.notify_head_update(head).await.is_err());
    }
}
