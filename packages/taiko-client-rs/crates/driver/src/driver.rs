//! High level driver orchestration.

use alloy_provider::{RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers};
use std::sync::Arc;
use tracing::{error, info, instrument};

use crate::{
    config::DriverConfig,
    error::{DriverError, Result},
    jsonrpc::{DriverIpcServer, DriverRpcApi, DriverRpcServer},
    sync::SyncPipeline,
};
use rpc::client::{Client, read_jwt_secret};

/// Type alias for the default RPC client used by the driver.
pub type DriverRpcClient = Client<FillProvider<JoinedRecommendedFillers, RootProvider>>;

/// Shasta driver responsible for keeping an execution engine in sync with protocol state.
pub struct Driver {
    /// Static configuration loaded at startup.
    cfg: DriverConfig,
    /// RPC client wrapper shared with derivation and sync subsystems.
    rpc: DriverRpcClient,
}

impl Driver {
    /// Construct a driver instance from the provided configuration.
    #[instrument(skip(cfg))]
    pub async fn new(cfg: DriverConfig) -> Result<Self> {
        let rpc = Client::new(cfg.client.clone()).await?;

        Ok(Self { cfg, rpc })
    }

    /// Start the driver until completion.
    ///
    /// When the HTTP RPC server is enabled, it requires a dedicated JWT secret
    /// configured via `rpc_jwt_secret`. The IPC server does not require JWT
    /// authentication (uses filesystem permissions instead).
    #[instrument(skip(self))]
    pub async fn run(&self) -> Result<()> {
        info!(?self.cfg, "starting driver sync pipeline");
        let pipeline = SyncPipeline::new(self.cfg.clone(), self.rpc.clone()).await?;

        let api: Arc<dyn DriverRpcApi> = pipeline.event_syncer();

        // Start HTTP RPC server (JWT-protected) if configured.
        let http_server = if let Some(listen_addr) = self.cfg.rpc_listen_addr {
            info!(addr = %listen_addr, "driver HTTP RPC server enabled");

            let jwt_secret_path = match &self.cfg.rpc_jwt_secret {
                Some(path) => path.clone(),
                None => {
                    error!("driver HTTP RPC server enabled but jwt secret path not configured");
                    return Err(DriverError::DriverRpcJwtSecretMissing);
                }
            };

            let jwt_secret = match read_jwt_secret(jwt_secret_path.clone()) {
                Some(secret) => {
                    info!(path = ?jwt_secret_path, "loaded driver RPC JWT secret");
                    secret
                }
                None => {
                    error!(path = ?jwt_secret_path, "failed to read driver RPC JWT secret");
                    return Err(DriverError::DriverRpcJwtSecretReadFailed);
                }
            };
            Some(DriverRpcServer::start(listen_addr, jwt_secret, Arc::clone(&api)).await?)
        } else {
            None
        };

        // Start IPC RPC server (no JWT, uses filesystem permissions) if configured.
        let ipc_server = if let Some(ipc_path) = &self.cfg.rpc_ipc_path {
            info!(path = ?ipc_path, "driver IPC RPC server enabled");
            Some(DriverIpcServer::start(ipc_path.clone(), Arc::clone(&api)).await?)
        } else {
            None
        };

        // Log warning if no RPC servers are configured.
        if http_server.is_none() && ipc_server.is_none() {
            info!("driver RPC server disabled (no HTTP or IPC endpoint configured)");
        }

        pipeline.run().await?;
        Ok(())
    }

    /// Access the underlying RPC client (primarily for tests).
    pub fn rpc_client(&self) -> &DriverRpcClient {
        &self.rpc
    }

    /// Access configuration.
    pub fn config(&self) -> &DriverConfig {
        &self.cfg
    }
}
