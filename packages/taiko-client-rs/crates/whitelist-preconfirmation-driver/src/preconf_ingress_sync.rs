//! Event sync bootstrap helper for whitelist preconfirmation ingestion.

use std::{future::Future, sync::Arc};

use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use driver::{
    DriverConfig,
    sync::{SyncError, event::EventSyncer},
};
use rpc::client::Client;
use tokio::task::JoinHandle;

use crate::{Result, error::WhitelistPreconfirmationDriverError};

/// Runs the event syncer and exposes shared handles used by the whitelist importer.
pub(crate) struct PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// RPC client used by the importer and ingress sync.
    client: Client<P>,
    /// Shared event syncer that exposes ingress readiness and submit hooks.
    event_syncer: Arc<EventSyncer<P>>,
    /// Background task running the event sync loop.
    handle: JoinHandle<std::result::Result<(), SyncError>>,
}

impl PreconfIngressSync<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Start the event syncer and its background task.
    pub(crate) async fn start(config: &DriverConfig) -> Result<Self> {
        let client = Client::new(config.client.clone()).await?;
        let event_syncer = Arc::new(EventSyncer::new(config, client.clone()).await?);
        let event_syncer_task = event_syncer.clone();
        let handle = tokio::spawn(async move { driver::SyncStage::run(&*event_syncer_task).await });

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
    pub(crate) fn handle_mut(&mut self) -> &mut JoinHandle<std::result::Result<(), SyncError>> {
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
    event_syncer_handle: &mut JoinHandle<std::result::Result<(), SyncError>>,
) -> Result<()>
where
    F: Future<Output = Option<()>> + Send,
{
    tokio::select! {
        ready = ready => {
            ready.ok_or(WhitelistPreconfirmationDriverError::PreconfIngressNotEnabled)?;
            Ok(())
        }
        result = event_syncer_handle => {
            match result {
                Ok(Ok(())) => Err(WhitelistPreconfirmationDriverError::EventSyncerExited),
                Ok(Err(err)) => Err(WhitelistPreconfirmationDriverError::Sync(err)),
                Err(err) => Err(WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string())),
            }
        }
    }
}
