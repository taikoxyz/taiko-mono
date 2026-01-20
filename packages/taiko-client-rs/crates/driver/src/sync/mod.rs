//! Synchronization primitives for the driver.

use std::sync::Arc;

use alloy_provider::Provider;
use async_trait::async_trait;
use rpc::client::Client;
use tracing::{info, instrument};

use crate::{config::DriverConfig, error::DriverError, sync::beacon::BeaconSyncer};

pub mod beacon;
pub mod engine;
pub mod error;
pub mod event;

pub use error::SyncError;
/// Re-export the event syncer for embedded driver usage.
pub use event::EventSyncer;

/// High level trait to represent a driver sync stage.
#[async_trait]
pub trait SyncStage {
    /// Run the stage until completion or failure.
    async fn run(&self) -> Result<(), SyncError>;
}

/// Factory helper assembling both sync stages.
///
/// Runs the beacon syncer first to catch up via checkpoint sync,
/// then hands off to the event syncer for real-time L1 event processing.
pub struct SyncPipeline<P>
where
    P: Provider + Clone,
{
    /// Beacon syncer for checkpoint-based catch-up.
    beacon: BeaconSyncer<P>,
    /// Event syncer for following L1 inbox proposals in real time.
    event: Arc<EventSyncer<P>>,
}

impl<P> SyncPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new pipeline from the runtime configuration.
    #[instrument(skip(cfg, rpc), name = "sync_pipeline_new")]
    pub async fn new(cfg: DriverConfig, rpc: Client<P>) -> Result<Self, DriverError> {
        let beacon = BeaconSyncer::new(&cfg, rpc.clone());
        let event = Arc::new(EventSyncer::new(&cfg, rpc).await?);
        Ok(Self { beacon, event })
    }

    /// Access the event syncer instance.
    pub fn event_syncer(&self) -> Arc<EventSyncer<P>> {
        self.event.clone()
    }

    /// Start both syncers in order.
    #[instrument(skip(self), name = "sync_pipeline_run")]
    pub async fn run(self) -> Result<(), DriverError> {
        info!("beginning sync pipeline run");
        self.beacon.run().await?;
        info!("beacon syncer completed");
        self.event.run().await?;
        Ok(())
    }
}
