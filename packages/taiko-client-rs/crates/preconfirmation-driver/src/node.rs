//! Preconfirmation node combining driver, P2P client, and user-facing RPC.

use std::sync::Arc;

use alloy_primitives::{Address, U256};
use preconfirmation_net::NetworkCommand;
use tokio::sync::{mpsc, watch};
use tracing::info;

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
pub struct PreconfirmationNode {
    driver_client: EmbeddedDriverClient,
    p2p_client: PreconfirmationClient<EmbeddedDriverClient>,
    rpc_config: Option<PreconfRpcServerConfig>,
    canonical_proposal_id_rx: watch::Receiver<u64>,
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

struct NodeRpcApiImpl {
    #[allow(dead_code)]
    command_sender: mpsc::Sender<NetworkCommand>,
    canonical_proposal_id_rx: watch::Receiver<u64>,
    preconf_tip_rx: watch::Receiver<U256>,
}

#[async_trait::async_trait]
impl PreconfRpcApi for NodeRpcApiImpl {
    async fn publish_commitment(
        &self,
        _request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse> {
        // TODO: Implement commitment publishing via P2P network
        Err(PreconfirmationClientError::Config("publish_commitment not yet implemented".into()))
    }

    async fn publish_tx_list(
        &self,
        _request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        // TODO: Implement txlist publishing via P2P network
        Err(PreconfirmationClientError::Config("publish_tx_list not yet implemented".into()))
    }

    async fn get_status(&self) -> Result<NodeStatus> {
        let canonical_proposal_id = *self.canonical_proposal_id_rx.borrow();
        Ok(NodeStatus {
            is_synced: canonical_proposal_id > 0,
            preconf_tip: *self.preconf_tip_rx.borrow(),
            canonical_proposal_id,
            peer_count: 0,                  // TODO: Get from P2P handle
            peer_id: "unknown".to_string(), // TODO: Get from P2P handle
        })
    }

    async fn get_head(&self) -> Result<PreconfHead> {
        Ok(PreconfHead {
            block_number: *self.preconf_tip_rx.borrow(),
            submission_window_end: U256::ZERO, // TODO: Get from lookahead
        })
    }

    async fn get_lookahead(&self) -> Result<LookaheadInfo> {
        // TODO: Implement lookahead resolution
        Ok(LookaheadInfo {
            current_preconfirmer: Address::ZERO,
            submission_window_end: U256::ZERO,
            current_slot: None,
        })
    }

    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }

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
}
