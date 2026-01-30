//! Preconfirmation ingress sync helper for the runner.

use std::{future::Future, sync::Arc};

use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use driver::{
    DriverConfig, SyncStage,
    sync::{SyncError, event::EventSyncer},
};
use rpc::client::Client;
use tokio::task::JoinHandle;

use super::RunnerError;

/// Runs the preconfirmation ingress event syncer and exposes handles to its resources.
pub(crate) struct PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    client: Client<P>,
    event_syncer: Arc<EventSyncer<P>>,
    handle: JoinHandle<std::result::Result<(), SyncError>>,
}

impl PreconfIngressSync<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Start the preconfirmation ingress syncer and its background task.
    pub(crate) async fn start(config: &DriverConfig) -> Result<Self, RunnerError> {
        let client = Client::new(config.client.clone()).await?;
        let event_syncer = Arc::new(EventSyncer::new(config, client.clone()).await?);
        let event_syncer_run = event_syncer.clone();
        let handle = tokio::spawn(async move { event_syncer_run.run().await });

        Ok(Self { client, event_syncer, handle })
    }
}

impl<P> PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Access the preconfirmation ingress RPC client.
    pub(crate) fn client(&self) -> &Client<P> {
        &self.client
    }

    /// Access the event syncer.
    pub(crate) fn event_syncer(&self) -> &Arc<EventSyncer<P>> {
        &self.event_syncer
    }

    /// Get a mutable handle to the ingress syncer task.
    pub(crate) fn handle_mut(&mut self) -> &mut JoinHandle<std::result::Result<(), SyncError>> {
        &mut self.handle
    }

    /// Wait for preconfirmation ingress to be ready or the ingress syncer to fail.
    pub(crate) async fn wait_preconf_ingress_ready(&mut self) -> Result<(), RunnerError> {
        wait_for_preconf_ingress_ready(
            self.event_syncer.wait_preconf_ingress_ready(),
            &mut self.handle,
        )
        .await
    }
}

/// Wait for preconfirmation ingress to be ready or the ingress syncer to exit.
pub(crate) async fn wait_for_preconf_ingress_ready<F>(
    ready: F,
    event_syncer_handle: &mut JoinHandle<std::result::Result<(), SyncError>>,
) -> Result<(), RunnerError>
where
    F: Future<Output = Option<()>> + Send,
{
    tokio::select! {
        ready = ready => ready.ok_or(RunnerError::PreconfIngressNotEnabled),
        result = event_syncer_handle => {
            match result {
                Ok(Ok(())) => Err(RunnerError::EventSyncerExited),
                Ok(Err(err)) => Err(RunnerError::Sync(err)),
                Err(err) => Err(RunnerError::EventSyncerFailed(err.to_string())),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_errors_when_ready_none() {
        use driver::sync::SyncError;

        let ready = async { None };
        let mut handle = tokio::spawn(async { Ok::<(), SyncError>(()) });

        let err = super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(err.to_string().contains("preconfirmation ingress"));
    }
}
