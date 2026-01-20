//! High level driver orchestration.

use std::sync::Arc;

use alloy_provider::{RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers};
use tokio::sync::Mutex;
#[cfg(feature = "standalone-rpc")]
use tracing::error;
use tracing::{info, instrument, warn};

#[cfg(feature = "standalone-rpc")]
use crate::jsonrpc::{DriverIpcServer, DriverRpcApi, DriverRpcServer};
use crate::{
    config::DriverConfig,
    error::{DriverError, Result},
    sync::{EventSyncer, SyncPipeline},
};
use rpc::client::Client;
#[cfg(feature = "standalone-rpc")]
use rpc::client::read_jwt_secret;

/// Provider type used by the driver RPC client.
pub type DriverProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;

/// Type alias for the default RPC client used by the driver.
pub type DriverRpcClient = Client<DriverProvider>;

/// Shasta driver responsible for keeping an execution engine in sync with protocol state.
pub struct Driver {
    /// Static configuration loaded at startup.
    cfg: DriverConfig,
    /// RPC client wrapper shared with derivation and sync subsystems.
    rpc: DriverRpcClient,
    /// Event syncer instance shared with embedded preconfirmation clients.
    event_syncer: Arc<EventSyncer<DriverProvider>>,
    /// Sync pipeline instance consumed when the driver starts.
    pipeline: Mutex<Option<SyncPipeline<DriverProvider>>>,
}

impl Driver {
    /// Construct a driver instance from the provided configuration.
    #[instrument(skip(cfg))]
    pub async fn new(cfg: DriverConfig) -> Result<Self> {
        let rpc = Client::new(cfg.client.clone()).await?;
        let pipeline = SyncPipeline::new(cfg.clone(), rpc.clone()).await?;
        let event_syncer = pipeline.event_syncer();

        Ok(Self { cfg, rpc, event_syncer, pipeline: Mutex::new(Some(pipeline)) })
    }

    /// Start the driver until completion.
    ///
    /// When the standalone RPC server feature is enabled and the HTTP RPC server
    /// is configured, it requires a dedicated JWT secret configured via
    /// `rpc_jwt_secret`. The IPC server does not require JWT authentication (uses
    /// filesystem permissions instead).
    #[instrument(skip(self))]
    pub async fn run(&self) -> Result<()> {
        info!(?self.cfg, "starting driver sync pipeline");

        let pipeline = {
            let mut guard = self.pipeline.lock().await;
            guard.take().ok_or_else(|| {
                DriverError::Other(anyhow::anyhow!("driver pipeline already running"))
            })?
        };
        let event_syncer = Arc::clone(&self.event_syncer);
        let mut pipeline_future = Box::pin(pipeline.run());

        #[cfg(feature = "standalone-rpc")]
        {
            if self.cfg.preconfirmation_enabled && self.cfg.rpc_listen_addr.is_some() {
                info!(
                    "waiting for preconfirmation ingress to become ready before starting RPC server"
                );
                tokio::select! {
                    ready = event_syncer.wait_preconf_ingress_ready() => {
                        if ready.is_none() {
                            warn!("preconfirmation ingress readiness wait skipped (disabled)");
                        }
                    }
                    result = &mut pipeline_future => {
                        result?;
                        return Ok(());
                    }
                }
                info!("preconfirmation ingress is ready; starting RPC server");
            }

            let api: Arc<dyn DriverRpcApi> = event_syncer.clone();

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
                match DriverIpcServer::start(ipc_path.clone(), Arc::clone(&api)).await {
                    Ok(server) => Some(server),
                    Err(err) => {
                        // If IPC server fails to start, stop HTTP server if it was started.
                        if let Some(http) = http_server {
                            error!(error = %err, "IPC server failed to start, stopping HTTP server");
                            http.stop().await;
                        }
                        return Err(err);
                    }
                }
            } else {
                None
            };

            // Log warning if no RPC servers are configured.
            if http_server.is_none() && ipc_server.is_none() {
                info!("driver RPC server disabled (no HTTP or IPC endpoint configured)");
            }

            let result = pipeline_future.await;

            if let Some(ipc) = ipc_server {
                info!("stopping driver IPC RPC server");
                ipc.stop().await;
            }
            if let Some(http) = http_server {
                info!("stopping driver HTTP RPC server");
                http.stop().await;
            }

            result?;
            return Ok(());
        }

        #[cfg(not(feature = "standalone-rpc"))]
        {
            info!("standalone RPC feature disabled; running without JSON-RPC servers");
            let _ = event_syncer;
            pipeline_future.await?;
            Ok(())
        }
    }

    /// Access the underlying RPC client (primarily for tests).
    pub fn rpc_client(&self) -> &DriverRpcClient {
        &self.rpc
    }

    /// Access the event syncer instance.
    pub fn event_syncer(&self) -> Arc<EventSyncer<DriverProvider>> {
        Arc::clone(&self.event_syncer)
    }

    /// Return the last canonical proposal id processed by the driver.
    pub fn last_canonical_proposal_id(&self) -> u64 {
        self.event_syncer.last_canonical_proposal_id()
    }

    /// Access configuration.
    pub fn config(&self) -> &DriverConfig {
        &self.cfg
    }
}
