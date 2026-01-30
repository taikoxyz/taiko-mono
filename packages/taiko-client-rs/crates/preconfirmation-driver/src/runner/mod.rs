//! Preconfirmation driver runner orchestration.

mod driver_sync;

use driver::{DriverConfig, sync::SyncError};
use preconfirmation_net::P2pConfig;
use tracing::info;

use crate::{PreconfirmationClientError, PreconfirmationDriverNode, rpc::PreconfRpcServerConfig};

use driver_sync::DriverSync;

/// Errors emitted by the preconfirmation driver runner.
#[derive(Debug, thiserror::Error)]
pub enum RunnerError {
    /// Preconfirmation ingress was not enabled on the driver.
    #[error("preconfirmation ingress not enabled on driver")]
    PreconfIngressNotEnabled,
    /// Event syncer exited before preconfirmation ingress was ready.
    #[error("event syncer exited before preconfirmation ingress was ready")]
    EventSyncerExited,
    /// Event syncer task failed before preconfirmation ingress was ready.
    #[error("event syncer failed before preconfirmation ingress was ready: {0}")]
    EventSyncerFailed(String),
    /// Preconfirmation node task failed.
    #[error("preconfirmation node task failed: {0}")]
    NodeTaskFailed(String),
    /// Failed to resolve the L2 latest head.
    #[error("failed to resolve L2 latest head for preconfirmation tip")]
    MissingL2LatestHead,
    /// Failed to query the L2 latest head.
    #[error("failed to query L2 latest head for preconfirmation tip: {0}")]
    L2LatestHeadQuery(String),
    /// Driver sync error.
    #[error(transparent)]
    Sync(#[from] SyncError),
    /// Driver error.
    #[error(transparent)]
    Driver(#[from] driver::DriverError),
    /// RPC client error.
    #[error(transparent)]
    Rpc(#[from] rpc::RpcClientError),
    /// Preconfirmation client error.
    #[error(transparent)]
    Preconfirmation(#[from] PreconfirmationClientError),
}

/// Configuration for the preconfirmation driver runner.
#[derive(Clone, Debug)]
pub struct RunnerConfig {
    /// Driver configuration (includes RPC client config).
    pub driver_config: DriverConfig,
    /// P2P configuration for the preconfirmation network.
    pub p2p_config: P2pConfig,
    /// Optional RPC server configuration for preconfirmation submissions.
    pub rpc_config: Option<PreconfRpcServerConfig>,
}

impl RunnerConfig {
    /// Build a runner configuration from driver and P2P config.
    pub fn new(driver_config: DriverConfig, p2p_config: P2pConfig) -> Self {
        Self { driver_config, p2p_config, rpc_config: None }
    }

    /// Enable the preconfirmation RPC server.
    pub fn with_rpc(mut self, rpc_config: Option<PreconfRpcServerConfig>) -> Self {
        self.rpc_config = rpc_config;
        self
    }
}

/// Orchestrates the preconfirmation driver with embedded P2P client.
pub struct PreconfirmationDriverRunner {
    config: RunnerConfig,
}

impl PreconfirmationDriverRunner {
    /// Create a new runner.
    pub fn new(config: RunnerConfig) -> Self {
        Self { config }
    }

    /// Run the preconfirmation driver until any component exits.
    pub async fn run(self) -> Result<(), RunnerError> {
        info!("starting preconfirmation driver");

        let mut driver_sync = DriverSync::start(&self.config.driver_config).await?;

        info!("waiting for driver event sync to initialize");
        driver_sync.wait_preconf_ingress_ready().await?;

        info!("driver ready, starting preconfirmation P2P client");

        let _event_syncer = driver_sync.event_syncer().clone();
        let (node, _channels) = PreconfirmationDriverNode::start_with_provider(
            self.config.p2p_config,
            self.config.driver_config.client.inbox_address,
            driver_sync.client().l1_provider.clone(),
            self.config.rpc_config,
        )
        .await?;

        let mut node_handle = tokio::spawn(node.run());
        let event_syncer_handle = driver_sync.handle_mut();

        info!("starting preconfirmation P2P event loop");

        let run_result = tokio::select! {
            result = &mut node_handle => {
                event_syncer_handle.abort();
                match result {
                    Ok(Ok(())) => Ok(()),
                    Ok(Err(err)) => Err(RunnerError::Preconfirmation(err)),
                    Err(err) => Err(RunnerError::NodeTaskFailed(err.to_string())),
                }
            }
            result = &mut *event_syncer_handle => {
                node_handle.abort();
                match result {
                    Ok(Ok(())) => Err(RunnerError::EventSyncerExited),
                    Ok(Err(err)) => Err(RunnerError::Sync(err)),
                    Err(err) => Err(RunnerError::EventSyncerFailed(err.to_string())),
                }
            }
        };

        info!("preconfirmation driver stopped");
        run_result
    }
}

#[cfg(test)]
mod tests {
    use super::driver_sync::DRIVER_SYNC_MODULE_MARKER;

    #[test]
    fn driver_sync_module_exists() {
        let _ = DRIVER_SYNC_MODULE_MARKER;
    }
}
