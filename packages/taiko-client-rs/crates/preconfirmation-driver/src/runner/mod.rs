//! Preconfirmation driver runner orchestration.

mod preconf_ingress_sync;

use std::sync::Arc;

use alloy_provider::Provider;
use driver::{
    DriverConfig, map_driver_error,
    sync::{SyncError, event::EventSyncer},
};
use preconfirmation_net::P2pConfig;
use tracing::info;

use crate::{
    ContractInboxReader, EventSyncerDriverClient, PreconfirmationClient,
    PreconfirmationClientConfig, PreconfirmationClientError,
    rpc::{
        PreconfRpcApi, PreconfRpcServer, PreconfRpcServerConfig,
        runner_api::{CanonicalProposalIdProvider, RunnerRpcApiImpl},
    },
};
use protocol::preconfirmation::LookaheadResolver;

use preconf_ingress_sync::PreconfIngressSync;

/// Canonical id provider that delegates to the event syncer.
struct EventSyncerCanonicalIdProvider<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer used to read the latest canonical proposal id.
    event_syncer: Arc<EventSyncer<P>>,
}

impl<P> CanonicalProposalIdProvider for EventSyncerCanonicalIdProvider<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Return the last canonical proposal id observed by the syncer.
    fn canonical_proposal_id(&self) -> u64 {
        self.event_syncer.last_canonical_proposal_id()
    }
}

/// Errors emitted by the preconfirmation driver runner.
#[derive(Debug, thiserror::Error)]
pub enum RunnerError {
    /// Preconfirmation ingress was not enabled on the driver.
    #[error("preconfirmation ingress not enabled on driver")]
    PreconfIngressNotEnabled,
    /// Event syncer exited before preconfirmation ingress was ready.
    #[error("event syncer exited before preconfirmation ingress was ready")]
    EventSyncerExited,
    /// Event syncer task failed before preconfirmation ingress was ready.
    #[error("event syncer failed before preconfirmation ingress was ready: {0}")]
    EventSyncerFailed(String),
    /// Preconfirmation node task failed.
    #[error("preconfirmation node task failed: {0}")]
    NodeTaskFailed(String),
    /// Failed to resolve the L2 latest head.
    #[error("failed to resolve L2 latest head for preconfirmation tip")]
    MissingL2LatestHead,
    /// Failed to query the L2 latest head.
    #[error("failed to query L2 latest head for preconfirmation tip: {0}")]
    L2LatestHeadQuery(String),
    /// Driver sync error.
    #[error(transparent)]
    Sync(#[from] SyncError),
    /// Driver error.
    #[error(transparent)]
    Driver(#[from] driver::DriverError),
    /// RPC client error.
    #[error(transparent)]
    Rpc(#[from] rpc::RpcClientError),
    /// Preconfirmation client error.
    #[error(transparent)]
    Preconfirmation(#[from] PreconfirmationClientError),
}

/// Configuration for the preconfirmation driver runner.
#[derive(Clone, Debug)]
pub struct RunnerConfig {
    /// Driver configuration (includes RPC client config).
    pub driver_config: DriverConfig,
    /// P2P configuration for the preconfirmation network.
    pub p2p_config: P2pConfig,
    /// Optional RPC server configuration for preconfirmation submissions.
    pub rpc_config: Option<PreconfRpcServerConfig>,
}

impl RunnerConfig {
    /// Build a runner configuration from driver and P2P config.
    pub fn new(driver_config: DriverConfig, p2p_config: P2pConfig) -> Self {
        Self { driver_config, p2p_config, rpc_config: None }
    }

    /// Enable the preconfirmation RPC server.
    pub fn with_rpc(mut self, rpc_config: Option<PreconfRpcServerConfig>) -> Self {
        self.rpc_config = rpc_config;
        self
    }
}

/// Orchestrates the preconfirmation driver with embedded P2P client.
pub struct PreconfirmationDriverRunner {
    /// Runner configuration for driver, P2P, and optional RPC server.
    config: RunnerConfig,
}

impl PreconfirmationDriverRunner {
    /// Create a new runner.
    pub fn new(config: RunnerConfig) -> Self {
        Self { config }
    }

    /// Run the preconfirmation driver until any component exits.
    ///
    /// This starts the driver event syncer, wires the P2P client, optionally
    /// starts the RPC server, then blocks until either the P2P loop or the
    /// event syncer finishes (returning an error on early exit).
    pub async fn run(self) -> Result<(), RunnerError> {
        info!("starting preconfirmation driver");

        // Start the driver ingress + event syncer background tasks.
        let mut preconf_ingress_sync =
            PreconfIngressSync::start(&self.config.driver_config).await?;

        info!("waiting for preconfirmation ingress sync to initialize");
        // Wait for the driver to signal readiness before wiring P2P.
        preconf_ingress_sync.wait_preconf_ingress_ready().await?;

        info!("driver ready, starting preconfirmation P2P client");

        // Extract shared driver components needed for the P2P client.
        let event_syncer = preconf_ingress_sync.event_syncer();
        let rpc_client = preconf_ingress_sync.client().clone();
        let inbox_address = self.config.driver_config.client.inbox_address;

        // Build the lookahead resolver and start its background event scanner
        let l1_source = self.config.driver_config.client.l1_provider_source.clone();
        let (lookahead_resolver, _scanner_handle) =
            LookaheadResolver::new(inbox_address, l1_source)
                .await
                .map_err(PreconfirmationClientError::from)?;

        // Build the preconfirmation P2P client configuration.
        let client_config = PreconfirmationClientConfig::new_with_resolver(
            self.config.p2p_config,
            Arc::new(lookahead_resolver),
        );

        // Wrap the driver so P2P submissions go through the event syncer.
        let driver_client =
            EventSyncerDriverClient::from_client(event_syncer.clone(), rpc_client.clone());

        // Start the preconfirmation P2P client.
        let preconf_client = PreconfirmationClient::new(client_config, driver_client)?;
        let command_tx = preconf_client.command_tx();
        let local_peer_id = preconf_client.p2p_handle().local_peer_id().to_string();
        let lookahead_resolver = preconf_client.lookahead_resolver().clone();

        let mut rpc_server = None;
        if let Some(rpc_config) = &self.config.rpc_config {
            // Build and launch the RPC server using runner-backed APIs.
            let canonical_provider =
                Arc::new(EventSyncerCanonicalIdProvider { event_syncer: event_syncer.clone() });
            let inbox_reader = ContractInboxReader::new(rpc_client.shasta.inbox.clone());
            let rpc_driver =
                Arc::new(EventSyncerDriverClient::from_client(event_syncer.clone(), rpc_client));
            let api: Arc<dyn PreconfRpcApi> = Arc::new(RunnerRpcApiImpl::new(
                command_tx.clone(),
                canonical_provider,
                rpc_driver,
                local_peer_id,
                inbox_reader,
                lookahead_resolver,
            ));
            let server = PreconfRpcServer::start(rpc_config.clone(), api).await?;
            info!(url = %server.http_url(), "preconfirmation RPC server started");
            rpc_server = Some(server);
        }

        // Start the P2P sync/catchup event loop.
        let mut event_loop = preconf_client.sync_and_catchup().await?;

        let mut node_handle = tokio::spawn(async move { event_loop.run().await });
        let event_syncer_handle = preconf_ingress_sync.handle_mut();

        info!("starting preconfirmation P2P event loop");

        // Stop when either the P2P node or the event syncer exits.
        let run_result = tokio::select! {
            result = &mut node_handle => {
                event_syncer_handle.abort();
                match result {
                    Ok(Ok(())) => Ok(()),
                    Ok(Err(err)) => Err(RunnerError::Preconfirmation(err)),
                    Err(err) => Err(RunnerError::NodeTaskFailed(err.to_string())),
                }
            }
            result = &mut *event_syncer_handle => {
                node_handle.abort();
                match result {
                    Ok(Ok(())) => Err(RunnerError::EventSyncerExited),
                    Ok(Err(err)) => Err(map_driver_error(err)),
                    Err(err) => Err(RunnerError::EventSyncerFailed(err.to_string())),
                }
            }
        };

        // Ensure the RPC server is stopped before returning.
        if let Some(server) = rpc_server {
            server.stop().await;
        }

        info!("preconfirmation driver stopped");
        run_result
    }
}
