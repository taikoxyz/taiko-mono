//! Shared preconfirmation ingress sync helper used by runner integrations.

use std::{future::Future, result, sync::Arc};

use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use driver::{DriverConfig, SyncPipeline};
use rpc::client::Client;
use tokio::task::JoinHandle;

/// Result returned by the event sync background task.
pub type EventSyncResult = result::Result<(), driver::DriverError>;
/// Join result returned by the event sync background task handle.
pub type EventSyncJoinResult = result::Result<EventSyncResult, tokio::task::JoinError>;

/// Classified terminal outcome from the event sync background task.
#[derive(Debug)]
pub enum EventSyncerExit {
    /// The task exited cleanly (`Ok(())`) before ingress could proceed.
    Exited,
    /// The task returned an underlying driver error.
    Driver(driver::DriverError),
    /// The task failed to join.
    Join(tokio::task::JoinError),
}

/// Runs the preconfirmation ingress event syncer and exposes handles to its resources.
pub struct PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// RPC client shared across ingress sync and runner integrations.
    client: Client<P>,
    /// Event syncer exposing ingress readiness and preconfirmation submit hooks.
    event_syncer: Arc<driver::sync::event::EventSyncer<P>>,
    /// Join handle for the background sync pipeline task.
    handle: JoinHandle<EventSyncResult>,
}

impl PreconfIngressSync<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Start the preconfirmation ingress sync pipeline and its background task.
    pub async fn start(config: &DriverConfig) -> std::result::Result<Self, driver::DriverError> {
        let client = Client::new(config.client.clone()).await?;
        let pipeline = SyncPipeline::new(config.clone(), client.clone()).await?;
        let event_syncer = pipeline.event_syncer();
        let handle = tokio::spawn(async move { pipeline.run().await });

        Ok(Self { client, event_syncer, handle })
    }
}

impl<P> PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Access the preconfirmation ingress RPC client.
    pub fn client(&self) -> &Client<P> {
        &self.client
    }

    /// Access the event syncer handle.
    pub fn event_syncer(&self) -> Arc<driver::sync::event::EventSyncer<P>> {
        self.event_syncer.clone()
    }

    /// Get a mutable handle to the ingress sync pipeline task.
    pub fn handle_mut(&mut self) -> &mut JoinHandle<EventSyncResult> {
        &mut self.handle
    }

    /// Wait for preconfirmation ingress to be ready or report the event syncer exit.
    pub async fn wait_preconf_ingress_ready(&mut self) -> result::Result<(), EventSyncerExit> {
        wait_for_preconf_ingress_ready(
            self.event_syncer.wait_preconf_ingress_ready(),
            &mut self.handle,
        )
        .await
    }
}

/// Wait for preconfirmation ingress to be ready or for the event syncer to exit.
pub async fn wait_for_preconf_ingress_ready<F>(
    ready: F,
    event_syncer_handle: &mut JoinHandle<EventSyncResult>,
) -> result::Result<(), EventSyncerExit>
where
    F: Future<Output = EventSyncResult> + Send,
{
    tokio::select! {
        ready = ready => ready.map_err(EventSyncerExit::Driver),
        result = event_syncer_handle => Err(classify_event_syncer_exit(result)),
    }
}

/// Convert raw join output from the event syncer task into a semantic exit state.
pub fn classify_event_syncer_exit(result: EventSyncJoinResult) -> EventSyncerExit {
    match result {
        Ok(Ok(())) => EventSyncerExit::Exited,
        Ok(Err(err)) => EventSyncerExit::Driver(err),
        Err(err) => EventSyncerExit::Join(err),
    }
}

#[cfg(test)]
mod tests {
    use std::future::pending;

    use driver::{DriverError, sync::SyncError};

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_preconfirmation_disabled_error() {
        let ready = async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) };
        let mut handle = tokio::spawn(async { Ok::<(), DriverError>(()) });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(matches!(
            err,
            super::EventSyncerExit::Driver(DriverError::PreconfirmationDisabled)
        ));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_sync_driver_error() {
        let ready = pending::<super::EventSyncResult>();
        let mut handle = tokio::spawn(async {
            Err::<(), DriverError>(DriverError::Sync(SyncError::MissingCheckpointResumeHead))
        });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(matches!(
            err,
            super::EventSyncerExit::Driver(DriverError::Sync(
                SyncError::MissingCheckpointResumeHead
            ))
        ));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_non_sync_driver_error() {
        let ready = pending::<super::EventSyncResult>();
        let mut handle =
            tokio::spawn(async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(matches!(
            err,
            super::EventSyncerExit::Driver(DriverError::PreconfirmationDisabled)
        ));
    }
}
