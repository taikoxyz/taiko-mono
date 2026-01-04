//! Synchronization primitives for the driver.

use std::sync::Arc;

use alloy_provider::Provider;
use anyhow::anyhow;
use async_trait::async_trait;
use rpc::client::Client;
use tracing::{info, instrument};

use crate::{
    config::DriverConfig,
    error::DriverError,
    p2p_sidecar::{P2pSidecar, config::P2pSidecarConfig},
    sync::{beacon::BeaconSyncer, event::EventSyncer},
};

pub mod beacon;
pub mod engine;
pub mod error;
pub mod event;

pub use error::SyncError;

/// High level trait to represent a driver sync stage.
#[async_trait]
pub trait SyncStage {
    /// Run the stage until completion or failure.
    async fn run(&self) -> Result<(), SyncError>;
}

/// Factory helper assembling both sync stages.
pub struct SyncPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Beacon syncer stage.
    beacon: BeaconSyncer<P>,
    /// Event syncer stage wrapped for sharing with the sidecar.
    event: Arc<EventSyncer<P>>,
    /// Optional P2P sidecar config for deferred startup.
    sidecar_config: Option<P2pSidecarConfig>,
    /// RPC client retained for deferred sidecar startup.
    rpc: Client<P>,
}

impl<P> SyncPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new pipeline from the runtime configuration.
    #[instrument(skip(cfg, rpc), name = "sync_pipeline_new")]
    pub async fn new(cfg: DriverConfig, rpc: Client<P>) -> Result<Self, DriverError> {
        // Beacon syncer constructed from config and RPC client.
        let beacon = BeaconSyncer::new(&cfg, rpc.clone());
        // Event syncer wrapped in Arc for sharing with the sidecar.
        let event = Arc::new(EventSyncer::new(&cfg, rpc.clone()).await?);
        // Optional sidecar config enabled flag.
        let sidecar_enabled = cfg.p2p_sidecar.as_ref().map(|cfg| cfg.enabled).unwrap_or(false);
        if sidecar_enabled && !cfg.preconfirmation_enabled {
            return Err(DriverError::Other(anyhow!(
                "preconfirmation must be enabled when the p2p sidecar is active"
            )));
        }
        // Optional sidecar config for deferred startup.
        let sidecar_config = if sidecar_enabled {
            Some(cfg.p2p_sidecar.clone().expect("sidecar config must be present when enabled"))
        } else {
            None
        };
        Ok(Self { beacon, event, sidecar_config, rpc })
    }

    /// Start both syncers in order.
    #[instrument(skip(self), name = "sync_pipeline_run")]
    pub async fn run(self) -> Result<(), DriverError> {
        info!("beginning sync pipeline run");
        // Beacon syncer stage extracted for ordered startup.
        let beacon = self.beacon;
        // Event syncer stage extracted for ordered startup.
        let event = self.event;
        // Optional sidecar config extracted for deferred startup.
        let sidecar_config = self.sidecar_config;
        // RPC client extracted for deferred sidecar startup.
        let rpc = self.rpc;
        beacon.run().await?;
        info!("beacon syncer completed");
        // Sidecar handle retained to keep the runtime alive during event sync.
        let _sidecar = if let Some(sidecar_config) = sidecar_config {
            Some(P2pSidecar::start(sidecar_config, rpc, event.clone()).await?)
        } else {
            None
        };
        event.run().await?;
        Ok(())
    }
}
