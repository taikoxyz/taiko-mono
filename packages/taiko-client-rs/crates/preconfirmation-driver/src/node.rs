//! Preconfirmation node combining driver, P2P client, and user-facing RPC.

use std::sync::Arc;

use alloy_primitives::{Address, B256, U256};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, TxListBytes};
use protocol::preconfirmation::PreconfSignerResolver;
use ssz_rs::Deserialize;
use tokio::sync::{mpsc, watch};
use tracing::{info, warn};

use crate::{
    EmbeddedDriverClient, PreconfirmationClient, PreconfirmationClientConfig, Result,
    driver_interface::{InboxReader, PreconfirmationInput},
    error::PreconfirmationClientError,
    rpc::{
        LookaheadInfo, NodeStatus, PreconfHead, PreconfRpcApi, PreconfRpcServer,
        PreconfRpcServerConfig, PublishCommitmentRequest, PublishCommitmentResponse,
        PublishTxListRequest, PublishTxListResponse,
    },
};

/// Configuration for the preconfirmation driver node.
#[derive(Debug, Clone)]
pub struct PreconfirmationDriverNodeConfig {
    /// Configuration for the P2P client.
    pub p2p_config: PreconfirmationClientConfig,
    /// Configuration for the user-facing RPC server (None to disable).
    pub rpc_config: Option<PreconfRpcServerConfig>,
    /// Channel capacity for preconfirmation inputs to the driver.
    pub driver_channel_capacity: usize,
}

impl PreconfirmationDriverNodeConfig {
    /// Create a new configuration with the specified P2P settings.
    pub fn new(p2p_config: PreconfirmationClientConfig) -> Self {
        Self { p2p_config, rpc_config: None, driver_channel_capacity: 256 }
    }

    /// Enable the RPC server with the specified configuration.
    pub fn with_rpc(mut self, config: PreconfRpcServerConfig) -> Self {
        self.rpc_config = Some(config);
        self
    }

    /// Set the driver channel capacity.
    pub fn with_driver_channel_capacity(mut self, capacity: usize) -> Self {
        self.driver_channel_capacity = capacity;
        self
    }
}

/// Channels for communicating with an embedded driver.
#[derive(Debug)]
pub struct DriverChannels {
    /// Receiver for preconfirmation inputs from the node.
    pub input_receiver: mpsc::Receiver<PreconfirmationInput>,
    /// Sender for updating the canonical proposal ID.
    pub canonical_proposal_id_sender: watch::Sender<u64>,
    /// Sender for updating the preconfirmation tip.
    pub preconf_tip_sender: watch::Sender<U256>,
}

/// A complete preconfirmation driver node combining P2P client, driver client, and RPC server.
///
/// This struct orchestrates all components of the preconfirmation system:
/// - P2P networking for gossip and peer discovery
/// - Embedded driver client for payload submission
/// - Optional user-facing RPC server for external clients
///
/// The `I` type parameter represents the inbox reader implementation used by the embedded
/// driver client for L1 sync state verification.
pub struct PreconfirmationDriverNode<I: InboxReader + 'static> {
    /// Embedded driver client for submitting preconfirmation inputs.
    driver_client: EmbeddedDriverClient<I>,
    /// P2P client handling gossip, validation, and tip catch-up.
    p2p_client: PreconfirmationClient<EmbeddedDriverClient<I>>,
    /// Configuration for the optional user-facing RPC server.
    rpc_config: Option<PreconfRpcServerConfig>,
    /// Watch receiver for the canonical proposal ID from the driver.
    canonical_proposal_id_rx: watch::Receiver<u64>,
    /// Watch receiver for the preconfirmation tip from the driver.
    preconf_tip_rx: watch::Receiver<U256>,
}

impl<I: InboxReader + 'static> PreconfirmationDriverNode<I> {
    /// Create a new preconfirmation driver node.
    ///
    /// Returns a tuple of (node, driver_channels) where the channels should be
    /// wired to the driver for communication.
    ///
    /// # Arguments
    ///
    /// * `config` - The node configuration including P2P and RPC settings
    /// * `inbox_reader` - The inbox reader implementation for L1 sync state verification
    pub fn new(
        config: PreconfirmationDriverNodeConfig,
        inbox_reader: I,
    ) -> Result<(Self, DriverChannels)> {
        let (input_tx, input_rx) = mpsc::channel(config.driver_channel_capacity);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

        let driver_client = EmbeddedDriverClient::new(
            input_tx,
            canonical_id_rx.clone(),
            preconf_tip_rx.clone(),
            inbox_reader,
        );
        let p2p_client = PreconfirmationClient::new(config.p2p_config, driver_client.clone())?;

        Ok((
            Self {
                driver_client,
                p2p_client,
                rpc_config: config.rpc_config,
                canonical_proposal_id_rx: canonical_id_rx,
                preconf_tip_rx,
            },
            DriverChannels {
                input_receiver: input_rx,
                canonical_proposal_id_sender: canonical_id_tx,
                preconf_tip_sender: preconf_tip_tx,
            },
        ))
    }

    /// Run the preconfirmation driver node until an error occurs or shutdown.
    pub async fn run(self) -> Result<()> {
        info!("starting preconfirmation node");

        let rpc_server = if let Some(rpc_config) = &self.rpc_config {
            let api: Arc<dyn PreconfRpcApi> = Arc::new(NodeRpcApiImpl {
                command_sender: self.p2p_client.command_sender(),
                canonical_proposal_id_rx: self.canonical_proposal_id_rx.clone(),
                preconf_tip_rx: self.preconf_tip_rx.clone(),
                local_peer_id: self.p2p_client.p2p_handle().local_peer_id().to_string(),
                lookahead_resolver: self.p2p_client.lookahead_resolver().clone(),
                inbox_reader: self.driver_client.inbox_reader().clone(),
            });
            let server = PreconfRpcServer::start(rpc_config.clone(), api).await?;
            info!(url = %server.http_url(), "preconfirmation RPC server started");
            Some(server)
        } else {
            None
        };

        let mut event_loop = self.p2p_client.sync_and_catchup().await?;
        let result = event_loop.run().await;

        if let Some(server) = rpc_server {
            server.stop().await;
        }

        result.map_err(|e| PreconfirmationClientError::Network(e.to_string()))
    }

    /// Get a reference to the embedded driver client.
    pub fn driver_client(&self) -> &EmbeddedDriverClient<I> {
        &self.driver_client
    }

    /// Subscribe to P2P events.
    pub fn subscribe(
        &self,
    ) -> tokio::sync::broadcast::Receiver<crate::subscription::PreconfirmationEvent> {
        self.p2p_client.subscribe()
    }
}

/// Internal RPC API implementation backed by the preconfirmation driver node state.
struct NodeRpcApiImpl<I: InboxReader> {
    /// Sender for issuing commands to the P2P network layer.
    command_sender: mpsc::Sender<NetworkCommand>,
    /// Watch receiver for the canonical proposal ID.
    canonical_proposal_id_rx: watch::Receiver<u64>,
    /// Watch receiver for the preconfirmation tip.
    preconf_tip_rx: watch::Receiver<U256>,
    /// Local peer ID string for status responses.
    local_peer_id: String,
    /// Lookahead resolver for slot info queries.
    lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
    /// Inbox reader for checking L1 sync state.
    inbox_reader: I,
}

#[async_trait::async_trait]
impl<I: InboxReader + 'static> PreconfRpcApi for NodeRpcApiImpl<I> {
    /// Publishes a signed commitment to the P2P network.
    ///
    /// Decodes the SSZ-encoded commitment, extracts the tx_list_hash, and broadcasts
    /// via the P2P gossip network.
    async fn publish_commitment(
        &self,
        request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse> {
        // Decode the signed commitment from SSZ bytes
        let commitment_bytes = request.commitment.as_ref();
        let signed_commitment = SignedCommitment::deserialize(commitment_bytes).map_err(|e| {
            PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}"))
        })?;

        // Calculate commitment hash and extract tx_list_hash before publishing
        let commitment_hash = preconfirmation_types::keccak256_bytes(commitment_bytes);
        let tx_list_hash =
            B256::from_slice(signed_commitment.commitment.preconf.raw_tx_list_hash.as_slice());

        // Publish via P2P network
        self.command_sender
            .send(NetworkCommand::PublishCommitment(signed_commitment))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishCommitmentResponse {
            commitment_hash: B256::from(commitment_hash.0),
            tx_list_hash,
        })
    }

    /// Publishes a transaction list to the P2P network.
    ///
    /// Verifies the hash matches the provided encoded tx list and broadcasts via P2P gossip.
    async fn publish_tx_list(
        &self,
        request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        let raw_tx_list = TxListBytes::try_from(request.tx_list.to_vec())
            .map_err(|_| PreconfirmationClientError::Validation("txlist too large".into()))?;

        let calculated_hash = preconfirmation_types::keccak256_bytes(&raw_tx_list);
        if calculated_hash.0 != request.tx_list_hash.0 {
            return Err(PreconfirmationClientError::Validation(format!(
                "tx_list_hash mismatch: expected {}, got {}",
                request.tx_list_hash, calculated_hash
            )));
        }

        let raw_tx_list_hash = Bytes32::try_from(calculated_hash.0.to_vec())
            .expect("keccak256 always produces 32 bytes");
        let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list };

        self.command_sender
            .send(NetworkCommand::PublishRawTxList(gossip))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishTxListResponse { tx_list_hash: request.tx_list_hash })
    }

    /// Returns the current status of the preconfirmation driver node.
    ///
    /// Queries the P2P layer for peer count and returns sync state information.
    async fn get_status(&self) -> Result<NodeStatus> {
        let canonical_proposal_id = *self.canonical_proposal_id_rx.borrow();

        // Query peer count via command channel
        let (tx, rx) = tokio::sync::oneshot::channel();
        let peer_count =
            match self.command_sender.send(NetworkCommand::GetPeerCount { respond_to: tx }).await {
                Ok(()) => rx.await.unwrap_or(0),
                Err(_) => 0,
            };

        // Compute sync status using same logic as wait_event_sync
        let is_synced_with_inbox = self
            .inbox_reader
            .get_next_proposal_id()
            .await
            .map(|next_proposal_id| {
                next_proposal_id == 0 || canonical_proposal_id >= next_proposal_id.saturating_sub(1)
            })
            .unwrap_or(false);

        Ok(NodeStatus {
            is_synced_with_inbox,
            preconf_tip: *self.preconf_tip_rx.borrow(),
            canonical_proposal_id,
            peer_count,
            peer_id: self.local_peer_id.clone(),
        })
    }

    /// Returns the current preconfirmation head information.
    ///
    /// Includes the latest preconfirmed block number and submission window end time.
    async fn get_head(&self) -> Result<PreconfHead> {
        let block_number = *self.preconf_tip_rx.borrow();

        // Try to get submission window from lookahead
        let submission_window_end =
            self.get_lookahead().await.map(|info| info.submission_window_end).unwrap_or(U256::ZERO);

        Ok(PreconfHead { block_number, submission_window_end })
    }

    /// Returns the current lookahead information.
    ///
    /// Resolves the current preconfirmer address and submission window from the
    /// lookahead resolver using the current system time.
    async fn get_lookahead(&self) -> Result<LookaheadInfo> {
        // Use current system time as the timestamp
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| PreconfirmationClientError::Config(format!("system time error: {e}")))?;
        let timestamp = U256::from(now.as_secs());

        match self.lookahead_resolver.slot_info_for_timestamp(timestamp).await {
            Ok(slot_info) => Ok(LookaheadInfo {
                current_preconfirmer: slot_info.signer,
                submission_window_end: slot_info.submission_window_end,
                current_slot: None, // Slot number not available from resolver
            }),
            Err(e) => {
                warn!(error = %e, "failed to resolve lookahead");
                Ok(LookaheadInfo {
                    current_preconfirmer: Address::ZERO,
                    submission_window_end: U256::ZERO,
                    current_slot: None,
                })
            }
        }
    }

    /// Returns the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }

    /// Returns the last canonical proposal ID from L1 events.
    async fn canonical_proposal_id(&self) -> Result<u64> {
        Ok(*self.canonical_proposal_id_rx.borrow())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};

    /// Mock inbox reader for testing.
    #[derive(Clone)]
    struct MockInboxReader {
        next_proposal_id: Arc<AtomicU64>,
    }

    impl MockInboxReader {
        fn new(next_proposal_id: u64) -> Self {
            Self { next_proposal_id: Arc::new(AtomicU64::new(next_proposal_id)) }
        }
    }

    #[async_trait::async_trait]
    impl InboxReader for MockInboxReader {
        async fn get_next_proposal_id(&self) -> Result<u64> {
            Ok(self.next_proposal_id.load(Ordering::SeqCst))
        }
    }

    /// Verify DriverChannels can be created.
    #[test]
    fn test_driver_channels_creation() {
        let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
        let (canonical_id_tx, _canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, _preconf_tip_rx) = watch::channel(U256::ZERO);

        let channels = DriverChannels {
            input_receiver: input_rx,
            canonical_proposal_id_sender: canonical_id_tx,
            preconf_tip_sender: preconf_tip_tx,
        };

        // Verify we can send through the channels.
        drop(input_tx);
        assert!(channels.canonical_proposal_id_sender.send(42).is_ok());
        assert!(channels.preconf_tip_sender.send(U256::from(100)).is_ok());
    }

    /// Test that NodeRpcApiImpl returns correct status with peer_id.
    #[tokio::test]
    async fn test_node_status_includes_peer_id() {
        // Create a mock resolver
        struct MockResolver;

        #[async_trait::async_trait]
        impl PreconfSignerResolver for MockResolver {
            async fn signer_for_timestamp(
                &self,
                _: U256,
            ) -> protocol::preconfirmation::Result<Address> {
                Ok(Address::ZERO)
            }
            async fn slot_info_for_timestamp(
                &self,
                _: U256,
            ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo>
            {
                Ok(protocol::preconfirmation::PreconfSlotInfo {
                    signer: Address::ZERO,
                    submission_window_end: U256::from(1000),
                })
            }
        }

        let (_canonical_id_tx, canonical_id_rx) = watch::channel(42u64);
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::from(100));
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        // MockInboxReader returns 43, so with canonical_id=42, target=42, we should be synced
        let api = NodeRpcApiImpl {
            command_sender: command_tx,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
            local_peer_id: "12D3KooWTest".to_string(),
            lookahead_resolver: Arc::new(MockResolver),
            inbox_reader: MockInboxReader::new(43),
        };

        // Spawn a handler to respond to GetPeerCount command
        tokio::spawn(async move {
            if let Some(NetworkCommand::GetPeerCount { respond_to }) = command_rx.recv().await {
                let _ = respond_to.send(5);
            }
        });

        let status = api.get_status().await.unwrap();
        assert_eq!(status.peer_id, "12D3KooWTest");
        assert_eq!(status.canonical_proposal_id, 42);
        assert_eq!(status.peer_count, 5);
        assert!(status.is_synced_with_inbox); // canonical_id (42) >= target (43-1=42)
    }

    /// Test that get_lookahead returns data from the resolver.
    #[tokio::test]
    async fn test_get_lookahead_uses_resolver() {
        struct MockResolver;

        #[async_trait::async_trait]
        impl PreconfSignerResolver for MockResolver {
            async fn signer_for_timestamp(
                &self,
                _: U256,
            ) -> protocol::preconfirmation::Result<Address> {
                Ok(Address::repeat_byte(0x42))
            }
            async fn slot_info_for_timestamp(
                &self,
                _: U256,
            ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo>
            {
                Ok(protocol::preconfirmation::PreconfSlotInfo {
                    signer: Address::repeat_byte(0x42),
                    submission_window_end: U256::from(12345),
                })
            }
        }

        let (_canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, _command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_sender: command_tx,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            lookahead_resolver: Arc::new(MockResolver),
            inbox_reader: MockInboxReader::new(0),
        };

        let lookahead = api.get_lookahead().await.unwrap();
        assert_eq!(lookahead.current_preconfirmer, Address::repeat_byte(0x42));
        assert_eq!(lookahead.submission_window_end, U256::from(12345));
    }

    /// Test that publish_tx_list accepts pre-encoded tx list bytes.
    #[tokio::test]
    async fn test_publish_tx_list_accepts_encoded_bytes() {
        struct MockResolver;

        #[async_trait::async_trait]
        impl PreconfSignerResolver for MockResolver {
            async fn signer_for_timestamp(
                &self,
                _: U256,
            ) -> protocol::preconfirmation::Result<Address> {
                Ok(Address::ZERO)
            }
            async fn slot_info_for_timestamp(
                &self,
                _: U256,
            ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo>
            {
                Ok(protocol::preconfirmation::PreconfSlotInfo {
                    signer: Address::ZERO,
                    submission_window_end: U256::from(1000),
                })
            }
        }

        let (_canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (_preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let (command_tx, mut command_rx) = mpsc::channel::<NetworkCommand>(16);

        let api = NodeRpcApiImpl {
            command_sender: command_tx,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
            local_peer_id: "test".to_string(),
            lookahead_resolver: Arc::new(MockResolver),
            inbox_reader: MockInboxReader::new(0),
        };

        let tx_list = alloy_primitives::Bytes::from(vec![1u8, 2u8, 3u8, 4u8]);
        let calculated_hash = preconfirmation_types::keccak256_bytes(tx_list.as_ref());
        let tx_list_hash = B256::from(calculated_hash.0);
        let expected_raw_hash =
            Bytes32::try_from(calculated_hash.0.to_vec()).expect("keccak256 always 32 bytes");
        let expected_txlist =
            TxListBytes::try_from(tx_list.to_vec()).expect("tx list within size limit");

        let receiver = tokio::spawn(async move {
            match command_rx.recv().await {
                Some(NetworkCommand::PublishRawTxList(gossip)) => {
                    assert_eq!(gossip.raw_tx_list_hash, expected_raw_hash);
                    assert_eq!(gossip.txlist, expected_txlist);
                }
                other => panic!("unexpected network command: {other:?}"),
            }
        });

        let response =
            api.publish_tx_list(PublishTxListRequest { tx_list_hash, tx_list }).await.unwrap();

        assert_eq!(response.tx_list_hash, tx_list_hash);
        receiver.await.unwrap();
    }
}
