//! Shared preconfirmation ingress sync helper used by preconfirmation drivers.
//!
//! This module hosts the generic [`PreconfIngressSync`] runner that bootstraps the
//! [`SyncPipeline`], exposes handles to its resources, and waits for preconfirmation ingress
//! readiness. It is generic over the consumer's error type via [`PreconfIngressError`] so each
//! driver crate can reuse a single implementation while producing its own error variants.

use std::{future::Future, result, sync::Arc};

use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};

use crate::{
    DriverConfig, DriverError, SyncPipeline, map_driver_error,
    sync::{SyncError, event::EventSyncer},
};

/// Result returned by the event sync background task.
pub type EventSyncResult = result::Result<(), DriverError>;
/// Join result returned by the event sync background task handle.
pub type EventSyncJoinResult = result::Result<EventSyncResult, tokio::task::JoinError>;

/// Error abstraction required by the shared preconfirmation ingress sync helper.
///
/// Implementors are the crate-local error types of the preconfirmation drivers. The
/// [`From<SyncError>`] and [`From<DriverError>`] bounds let the helper reuse
/// [`map_driver_error`] so `DriverError::Sync` is preserved as the consumer's sync variant, while
/// the [`From<rpc::RpcClientError>`] bound supports RPC client construction during
/// [`PreconfIngressSync::start`]. The constructors below build the readiness-specific variants on
/// event syncer termination.
pub trait PreconfIngressError:
    From<SyncError> + From<DriverError> + From<rpc::RpcClientError>
{
    /// Build the error returned when the event syncer exits before ingress is ready.
    fn event_syncer_exited() -> Self;

    /// Build the error returned when the event syncer task fails before ingress is ready.
    ///
    /// `message` carries the underlying join/task failure description.
    fn event_syncer_failed(message: String) -> Self;
}

/// Runs the preconfirmation ingress event syncer and exposes handles to its resources.
pub struct PreconfIngressSync<P, E>
where
    P: Provider + Clone + Send + Sync + 'static,
    E: PreconfIngressError,
{
    /// RPC client shared across ingress sync and driver integrations.
    client: rpc::client::Client<P>,
    /// Event syncer exposing ingress readiness and preconfirmation submit hooks.
    event_syncer: Arc<EventSyncer<P>>,
    /// Join handle for the background sync pipeline task.
    handle: tokio::task::JoinHandle<EventSyncResult>,
    /// Marker binding the consumer error type used for readiness mapping.
    _error: std::marker::PhantomData<E>,
}

impl<E> PreconfIngressSync<FillProvider<JoinedRecommendedFillers, RootProvider>, E>
where
    E: PreconfIngressError,
{
    /// Start the preconfirmation ingress sync pipeline and its background task.
    pub async fn start(config: &DriverConfig) -> result::Result<Self, E> {
        let client = rpc::client::Client::new(config.client.clone()).await?;
        let pipeline = SyncPipeline::new(config.clone(), client.clone()).await?;
        let event_syncer = pipeline.event_syncer();
        let handle = tokio::spawn(async move { pipeline.run().await });

        Ok(Self { client, event_syncer, handle, _error: std::marker::PhantomData })
    }
}

impl<P, E> PreconfIngressSync<P, E>
where
    P: Provider + Clone + Send + Sync + 'static,
    E: PreconfIngressError,
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
    pub async fn wait_preconf_ingress_ready(&mut self) -> result::Result<(), E> {
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
/// fails first, the corresponding [`PreconfIngressError`] variant is produced instead.
pub async fn wait_for_preconf_ingress_ready<F, E>(
    ready: F,
    event_syncer_handle: &mut tokio::task::JoinHandle<EventSyncResult>,
) -> result::Result<(), E>
where
    F: Future<Output = EventSyncResult> + Send,
    E: PreconfIngressError,
{
    tokio::select! {
        ready = ready => ready.map_err(map_driver_error),
        result = event_syncer_handle => map_event_syncer_exit(result),
    }
}

/// Convert event syncer task termination into readiness errors.
///
/// A clean exit becomes [`PreconfIngressError::event_syncer_exited`], a driver error is mapped
/// through [`map_driver_error`], and a join failure becomes
/// [`PreconfIngressError::event_syncer_failed`].
pub fn map_event_syncer_exit<E>(result: EventSyncJoinResult) -> result::Result<(), E>
where
    E: PreconfIngressError,
{
    match result {
        Ok(Ok(())) => Err(E::event_syncer_exited()),
        Ok(Err(err)) => Err(map_driver_error(err)),
        Err(err) => Err(E::event_syncer_failed(err.to_string())),
    }
}

#[cfg(test)]
mod tests {
    use std::future::pending;

    use thiserror::Error;

    use super::{EventSyncResult, PreconfIngressError, map_event_syncer_exit};
    use crate::{DriverError, sync::SyncError};

    /// In-crate test error implementing [`PreconfIngressError`] to exercise the helper.
    #[derive(Debug, Error)]
    enum TestError {
        /// Event syncer exited before ingress was ready.
        #[error("event syncer exited")]
        EventSyncerExited,
        /// Event syncer task failed before ingress was ready.
        #[error("event syncer failed: {0}")]
        EventSyncerFailed(String),
        /// Driver sync error.
        #[error(transparent)]
        Sync(#[from] SyncError),
        /// Driver error.
        #[error(transparent)]
        Driver(#[from] DriverError),
        /// RPC client error.
        #[error(transparent)]
        Rpc(#[from] rpc::RpcClientError),
    }

    impl PreconfIngressError for TestError {
        fn event_syncer_exited() -> Self {
            Self::EventSyncerExited
        }

        fn event_syncer_failed(message: String) -> Self {
            Self::EventSyncerFailed(message)
        }
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_preconfirmation_disabled_error() {
        let ready = async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) };
        let mut handle = tokio::spawn(async { Ok::<(), DriverError>(()) });

        let err = super::wait_for_preconf_ingress_ready::<_, TestError>(ready, &mut handle)
            .await
            .unwrap_err();

        assert!(matches!(err, TestError::Driver(DriverError::PreconfirmationDisabled)));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_sync_driver_error() {
        let ready = pending::<EventSyncResult>();
        let mut handle = tokio::spawn(async {
            Err::<(), DriverError>(DriverError::Sync(SyncError::MissingCheckpointResumeHead))
        });

        let err = super::wait_for_preconf_ingress_ready::<_, TestError>(ready, &mut handle)
            .await
            .unwrap_err();

        assert!(matches!(err, TestError::Sync(SyncError::MissingCheckpointResumeHead)));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_maps_non_sync_driver_error() {
        let ready = pending::<EventSyncResult>();
        let mut handle =
            tokio::spawn(async { Err::<(), DriverError>(DriverError::PreconfirmationDisabled) });

        let err = super::wait_for_preconf_ingress_ready::<_, TestError>(ready, &mut handle)
            .await
            .unwrap_err();

        assert!(matches!(err, TestError::Driver(DriverError::PreconfirmationDisabled)));
    }

    #[test]
    fn map_event_syncer_exit_maps_clean_exit_to_exited() {
        let err = map_event_syncer_exit::<TestError>(Ok(Ok(()))).unwrap_err();
        assert!(matches!(err, TestError::EventSyncerExited));
    }
}
