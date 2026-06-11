//! Shared preconfirmation ingress sync helper used by preconfirmation drivers.
//!
//! This module hosts the [`PreconfIngressSync`] runner that bootstraps the [`SyncPipeline`],
//! exposes handles to its resources, and waits for preconfirmation ingress readiness. Failures
//! surface as the concrete [`PreconfIngressSyncError`], which consumer crates absorb into their
//! own error types.

use std::{future::Future, result, sync::Arc};

use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use thiserror::Error;

use crate::{
    DriverConfig, DriverError, SyncPipeline,
    sync::{SyncError, event::EventSyncer},
};

/// Result returned by the event sync background task.
pub type EventSyncResult = result::Result<(), DriverError>;
/// Join result returned by the event sync background task handle.
pub type EventSyncJoinResult = result::Result<EventSyncResult, tokio::task::JoinError>;

/// Errors produced while starting the ingress sync pipeline or waiting for readiness.
#[derive(Debug, Error)]
pub enum PreconfIngressSyncError {
    /// Event syncer exited before preconfirmation ingress was ready.
    #[error("event syncer exited before preconfirmation ingress was ready")]
    EventSyncerExited,
    /// Event syncer task failed before preconfirmation ingress was ready.
    #[error("event syncer failed before preconfirmation ingress was ready: {0}")]
    EventSyncerFailed(String),
    /// Driver sync subsystem reported a failure.
    #[error(transparent)]
    Sync(#[from] SyncError),
    /// Driver reported a non-sync failure.
    #[error(transparent)]
    Driver(DriverError),
    /// RPC client construction failed.
    #[error(transparent)]
    Rpc(#[from] rpc::RpcClientError),
}

impl From<DriverError> for PreconfIngressSyncError {
    /// Flatten `DriverError::Sync` into the sync variant so consumers observe sync failures
    /// through their own sync variants, mirroring the driver's error layering.
    fn from(err: DriverError) -> Self {
        match err {
            DriverError::Sync(err) => Self::Sync(err),
            other => Self::Driver(other),
        }
    }
}

/// Runs the preconfirmation ingress event syncer and exposes handles to its resources.
pub struct PreconfIngressSync<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// RPC client shared across ingress sync and driver integrations.
    client: rpc::client::Client<P>,
    /// Event syncer exposing ingress readiness and preconfirmation submit hooks.
    event_syncer: Arc<EventSyncer<P>>,
    /// Join handle for the background sync pipeline task.
    handle: tokio::task::JoinHandle<EventSyncResult>,
}

impl PreconfIngressSync<FillProvider<JoinedRecommendedFillers, RootProvider>> {
    /// Start the preconfirmation ingress sync pipeline and its background task.
    pub async fn start(
        config: &DriverConfig,
    ) -> result::Result<Self, PreconfIngressSyncError> {
        let client = rpc::client::Client::new(config.client.clone()).await?;
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
    pub fn client(&self) -> &rpc::client::Client<P> {
        &self.client
    }

    /// Access the event syncer handle.
    pub fn event_syncer(&self) -> Arc<EventSyncer<P>> {
        self.event_syncer.clone()
    }

    /// Get a mutable handle to the ingress sync pipeline task.
    pub fn handle_mut(&mut self) -> &mut tokio::task::JoinHandle<EventSyncResult> {
        &mut self.handle
    }

    /// Wait for preconfirmation ingress to be ready or the ingress syncer to fail.
    pub async fn wait_preconf_ingress_ready(
        &mut self,
    ) -> result::Result<(), PreconfIngressSyncError> {
        wait_for_preconf_ingress_ready(
            self.event_syncer.wait_preconf_ingress_ready(),
            &mut self.handle,
        )
        .await
    }
}

/// Wait for preconfirmation ingress to be ready or the ingress syncer to exit.
///
/// Resolves to `Ok(())` once `ready` completes successfully. If the event syncer task exits or
/// fails first, the corresponding [`PreconfIngressSyncError`] variant is produced instead.
pub async fn wait_for_preconf_ingress_ready<F>(
    ready: F,
    event_syncer_handle: &mut tokio::task::JoinHandle<EventSyncResult>,
) -> result::Result<(), PreconfIngressSyncError>
where
    F: Future<Output = EventSyncResult> + Send,
{
    tokio::select! {
        ready = ready => ready.map_err(PreconfIngressSyncError::from),
        result = event_syncer_handle => map_event_syncer_exit(result),
    }
}

/// Convert event syncer task termination into readiness errors.
///
/// A clean exit becomes [`PreconfIngressSyncError::EventSyncerExited`], a driver error is
/// flattened through [`PreconfIngressSyncError::from`], and a join failure becomes
/// [`PreconfIngressSyncError::EventSyncerFailed`].
pub fn map_event_syncer_exit(
    result: EventSyncJoinResult,
) -> result::Result<(), PreconfIngressSyncError> {
    match result {
        Ok(Ok(())) => Err(PreconfIngressSyncError::EventSyncerExited),
        Ok(Err(err)) => Err(err.into()),
        Err(err) => Err(PreconfIngressSyncError::EventSyncerFailed(err.to_string())),
    }
}

#[cfg(test)]
mod tests {
    use std::future::pending;

    use super::{EventSyncResult, PreconfIngressSyncError, map_event_syncer_exit};
    use crate::{DriverError, sync::SyncError};

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_preconfirmation_disabled_error() {
        let ready = async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) };
        let mut handle = tokio::spawn(async { Ok::<(), DriverError>(()) });

        let err =
            super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(matches!(
            err,
            PreconfIngressSyncError::Driver(DriverError::PreconfirmationDisabled)
        ));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_sync_driver_error() {
        let ready = pending::<EventSyncResult>();
        let mut handle = tokio::spawn(async {
            Err::<(), DriverError>(DriverError::Sync(SyncError::MissingCheckpointResumeHead))
        });

        let err =
            super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(matches!(
            err,
            PreconfIngressSyncError::Sync(SyncError::MissingCheckpointResumeHead)
        ));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_non_sync_driver_error() {
        let ready = pending::<EventSyncResult>();
        let mut handle =
            tokio::spawn(async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) });

        let err =
            super::wait_for_preconf_ingress_ready(ready, &mut handle).await.unwrap_err();

        assert!(matches!(
            err,
            PreconfIngressSyncError::Driver(DriverError::PreconfirmationDisabled)
        ));
    }

    #[test]
    fn map_event_syncer_exit_maps_clean_exit_to_exited() {
        let err = map_event_syncer_exit(Ok(Ok(()))).unwrap_err();
        assert!(matches!(err, PreconfIngressSyncError::EventSyncerExited));
    }
}
