//! Preconfirmation node combining driver, P2P client, and preconfirmation sidecar JSON-RPC.

use std::sync::Arc;

use alloy_primitives::U256;
use tokio::sync::{mpsc, watch};
use tracing::info;

use crate::{
    EmbeddedDriverClient, PreconfirmationClient, PreconfirmationClientConfig, Result,
    driver_interface::{InboxReader, PreconfirmationInput},
    error::PreconfirmationClientError,
    rpc::{PreconfRpcApi, PreconfRpcServer, PreconfRpcServerConfig},
};

use crate::rpc::node_api::NodeRpcApiImpl;

/// Default channel capacity for preconfirmation inputs to the driver.
const DEFAULT_DRIVER_CHANNEL_CAPACITY: usize = 256;

/// Configuration for the preconfirmation driver node.
#[derive(Debug, Clone)]
pub struct PreconfirmationDriverNodeConfig {
    /// Configuration for the P2P client.
    pub p2p_config: PreconfirmationClientConfig,
    /// Configuration for the preconfirmation sidecar JSON-RPC server (None to disable).
    pub rpc_config: Option<PreconfRpcServerConfig>,
    /// Channel capacity for preconfirmation inputs to the driver.
    pub driver_channel_capacity: usize,
}

impl PreconfirmationDriverNodeConfig {
    /// Create a new configuration with the specified P2P settings.
    pub fn new(p2p_config: PreconfirmationClientConfig) -> Self {
        Self {
            p2p_config,
            rpc_config: None,
            driver_channel_capacity: DEFAULT_DRIVER_CHANNEL_CAPACITY,
        }
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
    /// Input rx for preconfirmation inputs from the node.
    pub input_rx: mpsc::Receiver<PreconfirmationInput>,
    /// Tx for updating the preconfirmation tip.
    pub preconf_tip_tx: watch::Sender<U256>,
}

/// A complete preconfirmation driver node combining P2P client, driver client, and RPC server.
///
/// This struct orchestrates all components of the preconfirmation system:
/// - P2P networking for gossip and peer discovery
/// - Embedded driver client for payload submission
/// - Optional preconfirmation sidecar JSON-RPC server for external clients
///
/// The `I` type parameter represents the inbox reader implementation used by the embedded
/// driver client for L1 sync state verification.
pub struct PreconfirmationDriverNode<I: InboxReader + 'static> {
    /// Embedded driver client for submitting preconfirmation inputs.
    driver_client: EmbeddedDriverClient<I>,
    /// P2P client handling gossip, validation, and tip catch-up.
    p2p_client: PreconfirmationClient<EmbeddedDriverClient<I>>,
    /// Configuration for the optional preconfirmation sidecar JSON-RPC server.
    rpc_config: Option<PreconfRpcServerConfig>,
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
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

        let driver_client =
            EmbeddedDriverClient::new(input_tx, preconf_tip_rx.clone(), inbox_reader);
        let p2p_client = PreconfirmationClient::new(config.p2p_config, driver_client.clone())?;

        Ok((
            Self { driver_client, p2p_client, rpc_config: config.rpc_config, preconf_tip_rx },
            DriverChannels { input_rx, preconf_tip_tx },
        ))
    }

    /// Run the preconfirmation driver node until an error occurs or shutdown.
    pub async fn run(self) -> Result<()> {
        info!("starting preconfirmation node");

        let rpc_server = self.start_rpc_server_if_configured().await?;

        let mut event_loop = self.p2p_client.sync_and_catchup().await?;
        let result = event_loop.run().await;

        if let Some(server) = rpc_server {
            server.stop().await;
        }

        result.map_err(|e| PreconfirmationClientError::Network(e.to_string()))
    }

    /// Start the RPC server if configured.
    async fn start_rpc_server_if_configured(&self) -> Result<Option<PreconfRpcServer>> {
        let Some(rpc_config) = &self.rpc_config else {
            return Ok(None);
        };

        let api: Arc<dyn PreconfRpcApi> = Arc::new(NodeRpcApiImpl {
            command_tx: self.p2p_client.command_tx(),
            preconf_tip_rx: self.preconf_tip_rx.clone(),
            local_peer_id: self.p2p_client.p2p_handle().local_peer_id().to_string(),
            inbox_reader: self.driver_client.inbox_reader().clone(),
            lookahead_resolver: self.p2p_client.lookahead_resolver().clone(),
        });

        let server = PreconfRpcServer::start(rpc_config.clone(), api).await?;
        info!(url = %server.http_url(), "preconfirmation RPC server started");
        Ok(Some(server))
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
