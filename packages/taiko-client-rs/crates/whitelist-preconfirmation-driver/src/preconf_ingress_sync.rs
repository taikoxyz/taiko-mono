//! Event sync bootstrap helper for whitelist preconfirmation ingestion.

use std::{future::Future, sync::Arc};

use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use driver::{DriverConfig, SyncPipeline, sync::event::EventSyncer};
use rpc::client::Client;
use tokio::task::JoinHandle;

use crate::{
    Result,
    error::{WhitelistPreconfirmationDriverError, map_driver_error},
};

/// Runs the event syncer and exposes shared handles used by the whitelist importer.
pub(crate) struct PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// RPC client used by the importer and ingress sync.
    client: Client<P>,
    /// Shared event syncer that exposes ingress readiness and submit hooks.
    event_syncer: Arc<EventSyncer<P>>,
    /// Background task running the sync pipeline loop.
    handle: JoinHandle<std::result::Result<(), driver::DriverError>>,
}

impl PreconfIngressSync<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Start the sync pipeline and expose its event syncer and background task.
    pub(crate) async fn start(config: &DriverConfig) -> Result<Self> {
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
    /// Access the RPC client shared by the event syncer.
    pub(crate) fn client(&self) -> &Client<P> {
        &self.client
    }

    /// Access the running event syncer.
    pub(crate) fn event_syncer(&self) -> Arc<EventSyncer<P>> {
        self.event_syncer.clone()
    }

    /// Access the background event syncer task handle.
    pub(crate) fn handle_mut(
        &mut self,
    ) -> &mut JoinHandle<std::result::Result<(), driver::DriverError>> {
        &mut self.handle
    }

    /// Wait until preconfirmation ingress is available on the event syncer.
    pub(crate) async fn wait_preconf_ingress_ready(&mut self) -> Result<()> {
        wait_for_preconf_ingress_ready(
            self.event_syncer.wait_preconf_ingress_ready(),
            &mut self.handle,
        )
        .await
    }
}

/// Wait for ingress readiness, or return if the event syncer exits first.
pub(crate) async fn wait_for_preconf_ingress_ready<F>(
    ready: F,
    event_syncer_handle: &mut JoinHandle<std::result::Result<(), driver::DriverError>>,
) -> Result<()>
where
    F: Future<Output = std::result::Result<(), driver::DriverError>> + Send,
{
    tokio::select! {
        ready = ready => {
            ready.map_err(map_driver_error)?;
            Ok(())
        }
        result = event_syncer_handle => {
            match result {
                Ok(Ok(())) => Err(WhitelistPreconfirmationDriverError::EventSyncerExited),
                Ok(Err(err)) => Err(map_driver_error(err)),
                Err(err) => Err(WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string())),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use driver::{DriverError, sync::SyncError};

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_preconfirmation_disabled_error() {
        let ready = async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) };
        let mut handle = tokio::spawn(async { Ok::<(), DriverError>(()) });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();
        assert!(matches!(
            err,
            super::WhitelistPreconfirmationDriverError::Driver(
                DriverError::PreconfirmationDisabled
            )
        ));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_sync_driver_error() {
        let ready = std::future::pending::<std::result::Result<(), DriverError>>();
        let mut handle = tokio::spawn(async {
            Err::<(), DriverError>(DriverError::Sync(SyncError::MissingCheckpointResumeHead))
        });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();
        assert!(matches!(
            err,
            super::WhitelistPreconfirmationDriverError::Sync(
                SyncError::MissingCheckpointResumeHead
            )
        ));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_non_sync_driver_error() {
        let ready = std::future::pending::<std::result::Result<(), DriverError>>();
        let mut handle =
            tokio::spawn(async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();
        assert!(matches!(
            err,
            super::WhitelistPreconfirmationDriverError::Driver(
                DriverError::PreconfirmationDisabled
            )
        ));
    }
}
