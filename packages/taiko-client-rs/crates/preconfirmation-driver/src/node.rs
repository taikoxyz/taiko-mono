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
    driver_interface::PreconfirmationInput,
    error::PreconfirmationClientError,
    rpc::{
        LookaheadInfo, NodeStatus, PreconfHead, PreconfRpcApi, PreconfRpcServer,
        PreconfRpcServerConfig, PublishCommitmentRequest, PublishCommitmentResponse,
        PublishTxListRequest, PublishTxListResponse,
    },
};

/// Configuration for the preconfirmation node.
#[derive(Debug, Clone)]
pub struct PreconfirmationNodeConfig {
    /// Configuration for the P2P client.
    pub p2p_config: PreconfirmationClientConfig,
    /// Configuration for the user-facing RPC server (None to disable).
    pub rpc_config: Option<PreconfRpcServerConfig>,
    /// Channel capacity for preconfirmation inputs to the driver.
    pub driver_channel_capacity: usize,
}

impl PreconfirmationNodeConfig {
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

/// A complete preconfirmation node combining P2P client, driver client, and RPC server.
///
/// This struct orchestrates all components of the preconfirmation system:
/// - P2P networking for gossip and peer discovery
/// - Embedded driver client for payload submission
/// - Optional user-facing RPC server for external clients
pub struct PreconfirmationNode {
    /// Embedded driver client for submitting preconfirmation inputs.
    driver_client: EmbeddedDriverClient,
    /// P2P client handling gossip, validation, and tip catch-up.
    p2p_client: PreconfirmationClient<EmbeddedDriverClient>,
    /// Configuration for the optional user-facing RPC server.
    rpc_config: Option<PreconfRpcServerConfig>,
    /// Watch receiver for the canonical proposal ID from the driver.
    canonical_proposal_id_rx: watch::Receiver<u64>,
    /// Watch receiver for the preconfirmation tip from the driver.
    preconf_tip_rx: watch::Receiver<U256>,
}

impl PreconfirmationNode {
    /// Create a new preconfirmation node.
    ///
    /// Returns a tuple of (node, driver_channels) where the channels should be
    /// wired to the driver for communication.
    pub fn new(config: PreconfirmationNodeConfig) -> Result<(Self, DriverChannels)> {
        let (input_tx, input_rx) = mpsc::channel(config.driver_channel_capacity);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

        let driver_client =
            EmbeddedDriverClient::new(input_tx, canonical_id_rx.clone(), preconf_tip_rx.clone());
        let p2p_client = PreconfirmationClient::new(config.p2p_config, driver_client.clone())?;

        let channels = DriverChannels {
            input_receiver: input_rx,
            canonical_proposal_id_sender: canonical_id_tx,
            preconf_tip_sender: preconf_tip_tx,
        };

        let node = Self {
            driver_client,
            p2p_client,
            rpc_config: config.rpc_config,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
        };

        Ok((node, channels))
    }

    /// Run the preconfirmation node until an error occurs or shutdown.
    pub async fn run(self) -> Result<()> {
        info!("starting preconfirmation node");

        let rpc_server = match &self.rpc_config {
            Some(rpc_config) => {
                let api: Arc<dyn PreconfRpcApi> = Arc::new(NodeRpcApiImpl {
                    command_sender: self.p2p_client.command_sender(),
                    canonical_proposal_id_rx: self.canonical_proposal_id_rx.clone(),
                    preconf_tip_rx: self.preconf_tip_rx.clone(),
                    local_peer_id: self.p2p_client.p2p_handle().local_peer_id().to_string(),
                    lookahead_resolver: self.p2p_client.lookahead_resolver().clone(),
                });
                let server = PreconfRpcServer::start(rpc_config.clone(), api).await?;
                info!(url = %server.http_url(), "preconfirmation RPC server started");
                Some(server)
            }
            None => None,
        };

        let mut event_loop = self.p2p_client.sync_and_catchup().await?;
        let result = event_loop.run().await;

        if let Some(server) = rpc_server {
            server.stop().await;
        }

        result.map_err(|e| PreconfirmationClientError::Network(e.to_string()))
    }

    /// Get a reference to the embedded driver client.
    pub fn driver_client(&self) -> &EmbeddedDriverClient {
        &self.driver_client
    }

    /// Subscribe to P2P events.
    pub fn subscribe(
        &self,
    ) -> tokio::sync::broadcast::Receiver<crate::subscription::PreconfirmationEvent> {
        self.p2p_client.subscribe()
    }
}

/// Internal RPC API implementation backed by the preconfirmation node state.
struct NodeRpcApiImpl {
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
}

#[async_trait::async_trait]
impl PreconfRpcApi for NodeRpcApiImpl {
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

        Ok(PublishCommitmentResponse { commitment_hash: B256::from(commitment_hash.0), tx_list_hash })
    }

    /// Publishes a transaction list to the P2P network.
    ///
    /// Compresses the transactions using RLP + zlib, verifies the hash matches,
    /// and broadcasts via the P2P gossip network.
    async fn publish_tx_list(
        &self,
        request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        // Convert transactions to Vec<Vec<u8>>
        let transactions: Vec<Vec<u8>> =
            request.transactions.iter().map(|tx| tx.to_vec()).collect();

        // Compress the transaction list (RLP encode + zlib)
        let compressed =
            crate::codec::ZlibTxListCodec::new(preconfirmation_types::MAX_TXLIST_BYTES)
                .encode(&transactions)?;

        let raw_tx_list = TxListBytes::try_from(compressed)
            .map_err(|_| PreconfirmationClientError::Validation("txlist too large".into()))?;

        // Calculate hash and verify it matches
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

        // Publish via P2P network
        self.command_sender
            .send(NetworkCommand::PublishRawTxList(gossip))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishTxListResponse {
            tx_list_hash: request.tx_list_hash,
            transaction_count: request.transactions.len() as u64,
        })
    }

    /// Returns the current status of the preconfirmation node.
    ///
    /// Queries the P2P layer for peer count and returns sync state information.
    async fn get_status(&self) -> Result<NodeStatus> {
        let canonical_proposal_id = *self.canonical_proposal_id_rx.borrow();

        // Query peer count via command channel
        let (tx, rx) = tokio::sync::oneshot::channel();
        let peer_count = match self
            .command_sender
            .send(NetworkCommand::GetPeerCount { respond_to: tx })
            .await
        {
            Ok(()) => rx.await.unwrap_or(0),
            Err(_) => 0,
        };

        Ok(NodeStatus {
            is_synced: canonical_proposal_id > 0,
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
        let submission_window_end = self
            .get_lookahead()
            .await
            .map(|info| info.submission_window_end)
            .unwrap_or(U256::ZERO);

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

        let api = NodeRpcApiImpl {
            command_sender: command_tx,
            canonical_proposal_id_rx: canonical_id_rx,
            preconf_tip_rx,
            local_peer_id: "12D3KooWTest".to_string(),
            lookahead_resolver: Arc::new(MockResolver),
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
        };

        let lookahead = api.get_lookahead().await.unwrap();
        assert_eq!(lookahead.current_preconfirmer, Address::repeat_byte(0x42));
        assert_eq!(lookahead.submission_window_end, U256::from(12345));
    }
}
