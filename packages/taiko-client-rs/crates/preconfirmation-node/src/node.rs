//! Preconfirmation node orchestration.
//!
//! The [`PreconfirmationNode`] combines the embedded driver, preconfirmation
//! client, and user-facing JSON-RPC server into a single process.

use std::{sync::Arc, time::Duration};

use driver::{Driver, DriverConfig};
use tokio::{sync::broadcast, time::interval};
use tracing::{info, warn};

use crate::{
    client::PreconfirmationClient,
    config::PreconfirmationClientConfig,
    driver_interface::{DriverClient, EmbeddedDriverClient},
    error::Result,
    rpc::{PreconfRpcServer, RpcServerConfig},
    subscription::PreconfirmationEvent,
};

/// Poll interval for refreshing RPC status tips.
const STATUS_POLL_INTERVAL: Duration = Duration::from_secs(5);

/// Configuration for the preconfirmation node.
#[derive(Debug, Clone)]
pub struct PreconfirmationNodeConfig {
    /// Driver configuration.
    pub driver: DriverConfig,
    /// Preconfirmation client configuration.
    pub preconf: PreconfirmationClientConfig,
    /// RPC server configuration.
    pub rpc: RpcServerConfig,
}

/// A complete preconfirmation node combining driver, client, and RPC server.
pub struct PreconfirmationNode {
    /// Embedded driver instance.
    driver: Arc<Driver>,
    /// Driver client used by the preconfirmation client.
    driver_client: Arc<EmbeddedDriverClient>,
    /// Preconfirmation client instance.
    preconf_client: PreconfirmationClient<Arc<EmbeddedDriverClient>>,
    /// User-facing RPC server.
    rpc_server: PreconfRpcServer,
    /// Event receiver for client events.
    event_rx: broadcast::Receiver<PreconfirmationEvent>,
}

impl PreconfirmationNode {
    /// Create a new preconfirmation node.
    pub async fn new(config: PreconfirmationNodeConfig) -> Result<Self> {
        let driver = Arc::new(Driver::new(config.driver).await?);
        let event_syncer = driver.event_syncer();
        let rpc_client = driver.rpc_client().clone();
        let driver_client = Arc::new(EmbeddedDriverClient::new(event_syncer, rpc_client));

        let preconf_client = PreconfirmationClient::new(config.preconf, driver_client.clone())?;
        let event_rx = preconf_client.subscribe();

        let rpc_server = PreconfRpcServer::new(
            config.rpc,
            preconf_client.command_sender(),
            preconf_client.store(),
        );

        Ok(Self { driver, driver_client, preconf_client, rpc_server, event_rx })
    }

    /// Run the preconfirmation node until completion or error.
    pub async fn run(self) -> Result<()> {
        info!("starting preconfirmation node");

        let PreconfirmationNode { driver, driver_client, preconf_client, mut rpc_server, event_rx } =
            self;
        rpc_server.start().await?;
        let rpc_api = rpc_server.api();

        let status_handle =
            tokio::spawn(Self::status_updater(driver_client.clone(), Arc::clone(&rpc_api)));
        let event_handle = tokio::spawn(Self::event_handler(event_rx, Arc::clone(&rpc_api)));

        let event_loop = match preconf_client.sync_and_catchup().await {
            Ok(event_loop) => event_loop,
            Err(err) => {
                rpc_server.stop().await;
                return Err(err);
            }
        };
        let event_loop_handle = tokio::spawn(async move { event_loop.run_with_retry().await });

        let driver_handle = tokio::spawn(async move { driver.run().await });

        tokio::select! {
            res = event_loop_handle => {
                warn!("event loop exited: {:?}", res);
            }
            res = driver_handle => {
                warn!("driver exited: {:?}", res);
            }
            res = event_handle => {
                warn!("event handler exited: {:?}", res);
            }
            res = status_handle => {
                warn!("status updater exited: {:?}", res);
            }
        }

        rpc_server.stop().await;
        Ok(())
    }

    /// Background task that updates RPC status fields.
    async fn status_updater(
        driver_client: Arc<EmbeddedDriverClient>,
        rpc_api: Arc<crate::rpc::PreconfRpcApiImpl>,
    ) {
        let mut ticker = interval(STATUS_POLL_INTERVAL);

        loop {
            ticker.tick().await;
            match driver_client.event_sync_tip().await {
                Ok(tip) => rpc_api.set_event_sync_tip(tip).await,
                Err(err) => warn!(error = %err, "failed to refresh event sync tip"),
            }

            match driver_client.preconf_tip().await {
                Ok(tip) => rpc_api.set_preconf_tip(tip).await,
                Err(err) => warn!(error = %err, "failed to refresh preconf tip"),
            }
        }
    }

    /// Background task that updates RPC status based on client events.
    async fn event_handler(
        mut event_rx: broadcast::Receiver<PreconfirmationEvent>,
        rpc_api: Arc<crate::rpc::PreconfRpcApiImpl>,
    ) {
        let mut peer_count: u32 = 0;

        loop {
            match event_rx.recv().await {
                Ok(PreconfirmationEvent::Synced) => {
                    rpc_api.set_synced(true);
                }
                Ok(PreconfirmationEvent::PeerConnected(_)) => {
                    peer_count = peer_count.saturating_add(1);
                    rpc_api.set_peer_count(peer_count);
                }
                Ok(PreconfirmationEvent::PeerDisconnected(_)) => {
                    peer_count = peer_count.saturating_sub(1);
                    rpc_api.set_peer_count(peer_count);
                }
                Ok(_) => {}
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                    continue;
                }
                Err(tokio::sync::broadcast::error::RecvError::Closed) => {
                    break;
                }
            }
        }
    }
}
