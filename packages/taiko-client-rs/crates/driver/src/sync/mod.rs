//! Synchronization primitives for the driver.

use async_trait::async_trait;
use thiserror::Error;

use crate::{config::DriverConfig, error::DriverError};

pub mod beacon;
pub mod event;

/// Errors emitted by sync components.
#[derive(Debug, Error)]
pub enum SyncError {
    /// Beacon sync failure.
    #[error("beacon sync failed: {0}")]
    Beacon(String),
    /// Event sync failure.
    #[error("event sync failed: {0}")]
    Event(String),
}

/// High level trait to represent a driver sync stage.
#[async_trait]
pub trait SyncStage {
    /// Run the stage until completion or failure.
    async fn run(&self) -> std::result::Result<(), SyncError>;
}

/// Factory helper assembling both sync stages.
pub struct SyncPipeline<P>
where
    P: alloy_provider::Provider + Clone,
{
    beacon: beacon::BeaconSyncer<P>,
    event: event::EventSyncer<P>,
}

impl<P> SyncPipeline<P>
where
    P: alloy_provider::Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new pipeline from the runtime configuration.
    pub fn new(
        cfg: DriverConfig,
        rpc: rpc::client::Client<P>,
    ) -> std::result::Result<Self, DriverError> {
        let beacon = beacon::BeaconSyncer::new(&cfg, rpc.clone());
        let event = event::EventSyncer::new(rpc, cfg);
        Ok(Self { beacon, event })
    }

    /// Start both syncers sequentially.
    pub async fn run(self) -> std::result::Result<(), DriverError> {
        let beacon = self.beacon;
        let event = self.event;

        tokio::try_join!(async { beacon.run().await }, async { event.run().await })
            .map(|_| ())
            .map_err(DriverError::from)
    }
}
