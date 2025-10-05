//! Synchronization primitives for the driver.

use alloy_provider::Provider;
use async_trait::async_trait;
use rpc::client::Client;

use crate::{
    config::DriverConfig,
    error::DriverError,
    sync::{beacon::BeaconSyncer, event::EventSyncer},
};

pub mod beacon;
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
    P: Provider + Clone,
{
    beacon: BeaconSyncer<P>,
    event: EventSyncer<P>,
}

impl<P> SyncPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new pipeline from the runtime configuration.
    pub fn new(cfg: DriverConfig, rpc: Client<P>) -> Result<Self, DriverError> {
        let beacon = BeaconSyncer::new(&cfg, rpc.clone());
        let event = EventSyncer::new(&cfg, rpc);
        Ok(Self { beacon, event })
    }

    /// Start both syncers in order.
    pub async fn run(self) -> Result<(), DriverError> {
        self.beacon.run().await?;
        self.event.run().await?;
        Ok(())
    }
}
