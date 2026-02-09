//! High level driver orchestration.

use alloy_provider::{RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers};
use tracing::{info, instrument};

use crate::{config::DriverConfig, error::Result, sync::SyncPipeline};
use rpc::client::Client;

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
    #[instrument(skip(self))]
    pub async fn run(&self) -> Result<()> {
        info!(?self.cfg, "starting driver sync pipeline");
        let pipeline = SyncPipeline::new(self.cfg.clone(), self.rpc.clone()).await?;
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
