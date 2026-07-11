//! Whitelist preconfirmation runner orchestration.

use std::{net::SocketAddr, sync::Arc, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::Address;
use alloy_provider::Provider;
use driver::{
    DriverConfig,
    preconf_ingress_sync::{PreconfIngressSync, map_event_syncer_exit},
    shutdown::shutdown_signal,
};
use protocol::signer::FixedKSigner;
use rpc::beacon::BeaconClient;
use tracing::{info, warn};

use crate::{
    Result,
    api::{
        WhitelistApiServer, WhitelistApiServerConfig, WhitelistApiService,
        WhitelistApiServiceParams,
    },
    cache::{L1_EPOCH_DURATION_SECS, SharedPreconfState},
    error::WhitelistPreconfirmationDriverError,
    importer::{WhitelistPreconfirmationImporter, WhitelistPreconfirmationImporterParams},
    network::{NetworkCommand, NetworkConfig, WhitelistNetwork},
    operator_set::OperatorSetPoller,
};

/// Bound on the whole signal-teardown sequence (REST/WS drain plus the network shutdown
/// command), mirroring the Go driver's bounded preconfirmation-server shutdown window.
const SHUTDOWN_DRAIN_TIMEOUT: Duration = Duration::from_secs(5);

/// Configuration for the whitelist preconfirmation runner.
#[derive(Clone, Debug)]
pub struct RunnerConfig {
    /// Driver configuration (includes RPC client configuration).
    pub driver_config: DriverConfig,
    /// P2P configuration for whitelist preconfirmation topics.
    pub p2p_config: NetworkConfig,
    /// Whitelist contract address used for signer validation.
    pub whitelist_address: Address,
    /// Optional listen address for the whitelist preconfirmation REST/WS server.
    pub rpc_listen_addr: Option<SocketAddr>,
    /// Optional shared secret used for Bearer JWT authentication on REST/WS routes.
    pub rpc_jwt_secret: Option<Vec<u8>>,
    /// Optional list of allowed CORS origins for REST/WS routes.
    pub rpc_cors_origins: Vec<String>,
    /// Optional hex-encoded private key for P2P block signing.
    pub p2p_signer_key: Option<String>,
}

/// Runs event sync plus whitelist preconfirmation message ingestion.
pub struct WhitelistPreconfirmationDriverRunner {
    /// Static runtime configuration for the network and importer.
    config: RunnerConfig,
}

impl WhitelistPreconfirmationDriverRunner {
    /// Create a new runner.
    pub fn new(config: RunnerConfig) -> Self {
        Self { config }
    }

    /// Run until either event syncer or whitelist network exits.
    pub async fn run(self) -> Result<()> {
        let mut preconf_ingress_sync =
            PreconfIngressSync::start(&self.config.driver_config).await?;
        let chain_id = preconf_ingress_sync.client().chain_id;

        info!(
            chain_id,
            whitelist_address = %self.config.whitelist_address,
            "starting whitelist preconfirmation driver"
        );

        preconf_ingress_sync.wait_preconf_ingress_ready().await?;

        let operator_poller = OperatorSetPoller::new(
            self.config.whitelist_address,
            preconf_ingress_sync.client().l1_provider.clone(),
        )
        .await?;
        let operator_set = operator_poller.shared_set();
        tokio::spawn(operator_poller.run_refresh_loop());

        let network = WhitelistNetwork::spawn(
            chain_id,
            self.config.p2p_config.clone(),
            operator_set.clone(),
        )?;
        let beacon_client = Arc::new(
            BeaconClient::new(self.config.driver_config.l1_beacon_endpoint.clone()).await.map_err(
                |err| {
                    WhitelistPreconfirmationDriverError::RestWsServerStartup(format!(
                        "failed to initialize beacon client: {err}"
                    ))
                },
            )?,
        );
        info!(
            peer_id = %network.peer_id,
            chain_id,
            "whitelist preconfirmation p2p subscriber started"
        );

        // Seed the shared status-reporting fallback with the current L2 head.
        let initial_l2_head = preconf_ingress_sync
            .client()
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?
            .ok_or_else(|| {
                WhitelistPreconfirmationDriverError::provider(
                    "latest L2 block unavailable during whitelist driver startup",
                )
            })?
            .header
            .number;
        let state = SharedPreconfState::new(initial_l2_head);

        // Optionally start the REST/WS server when both rpc_listen_addr and p2p_signer_key
        // are configured.
        let mut rest_ws_server = if let (Some(listen_addr), Some(signer_key)) =
            (self.config.rpc_listen_addr, &self.config.p2p_signer_key)
        {
            let signer = FixedKSigner::new(signer_key).map_err(|e| {
                WhitelistPreconfirmationDriverError::Signing(format!(
                    "failed to create P2P signer: {e}"
                ))
            })?;
            let handler = Arc::new(WhitelistApiService::new(WhitelistApiServiceParams {
                event_syncer: preconf_ingress_sync.event_syncer(),
                rpc: preconf_ingress_sync.client().clone(),
                chain_id,
                signer,
                beacon_client: Arc::clone(&beacon_client),
                operator_set: operator_set.clone(),
                state: state.clone(),
                network_command_tx: network.command_tx.clone(),
            }));
            let server_config = WhitelistApiServerConfig {
                listen_addr,
                jwt_secret: self.config.rpc_jwt_secret.clone(),
                cors_origins: self.config.rpc_cors_origins.clone(),
            };
            let server = WhitelistApiServer::start(server_config, handler.clone()).await?;
            info!(
                addr = %server.local_addr(),
                http_url = %server.http_url(),
                ws_url = %server.ws_url(),
                "whitelist preconfirmation REST server started"
            );
            Some(server)
        } else {
            None
        };

        let mut importer =
            WhitelistPreconfirmationImporter::new(WhitelistPreconfirmationImporterParams {
                event_syncer: preconf_ingress_sync.event_syncer(),
                rpc: preconf_ingress_sync.client().clone(),
                chain_id,
                network_command_tx: network.command_tx.clone(),
                state,
                beacon_client,
            });
        let mut sync_ready_interval =
            tokio::time::interval(tokio::time::Duration::from_secs(L1_EPOCH_DURATION_SECS));
        // Consume the immediate first tick so the periodic cache poll starts one
        // full epoch later; event-driven imports still call maybe_import_from_cache
        // on every inbound network event.
        sync_ready_interval.tick().await;

        let WhitelistNetwork { mut event_rx, command_tx, handle: mut node_handle, .. } = network;
        let mut event_syncer_handle = preconf_ingress_sync.handle_mut();

        // Cooperative shutdown for the steady-state loop; pinned once so a signal arriving
        // between loop iterations is not lost. Signals arriving before the first poll keep
        // their default disposition (immediate exit), acceptable while nothing is in flight.
        let shutdown = shutdown_signal();
        tokio::pin!(shutdown);

        loop {
            tokio::select! {
                _ = &mut shutdown => {
                    info!("shutdown signal received; draining whitelist preconfirmation driver");
                    // Drain the REST server first — with ingress and P2P still available — so
                    // an in-flight build settles end to end (engine insert + gossip publish),
                    // then ask the network to shut down. One deadline bounds the whole
                    // teardown; the aborts below are synchronous and cannot block.
                    let teardown = async {
                        if let Some(server) = rest_ws_server.take() {
                            server.stop().await;
                        }
                        let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    };
                    if tokio::time::timeout(SHUTDOWN_DRAIN_TIMEOUT, teardown).await.is_err() {
                        warn!("whitelist preconfirmation drain timed out; exiting anyway");
                    }
                    node_handle.abort();
                    event_syncer_handle.abort();
                    return Ok(());
                }
                result = &mut node_handle => {
                    stop_sidecars(event_syncer_handle, &mut rest_ws_server).await;
                    return match result {
                        Ok(Ok(())) => Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            "whitelist preconfirmation network exited unexpectedly".to_string(),
                        )),
                        Ok(Err(err)) => Err(err),
                        Err(err) => Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            err.to_string(),
                        )),
                    };
                }
                result = &mut event_syncer_handle => {
                    let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    node_handle.abort();
                    stop_sidecars(event_syncer_handle, &mut rest_ws_server).await;
                    return map_event_syncer_exit(result).map_err(Into::into);
                }
                maybe_event = event_rx.recv() => {
                    let Some(event) = maybe_event else {
                        stop_sidecars(event_syncer_handle, &mut rest_ws_server).await;
                        return Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            "whitelist preconfirmation event channel closed".to_string(),
                        ));
                    };

                    if let Err(err) = importer.handle_event(event).await {
                        warn!(
                            error = %err,
                            "failed to handle whitelist preconfirmation network event"
                        );
                    }
                }
                _ = sync_ready_interval.tick() => {
                    if let Err(err) = importer.maybe_import_from_cache().await {
                        warn!(
                            error = %err,
                            "failed to import cached whitelist preconfirmation payloads on sync-ready poll"
                        );
                    }
                }
            }
        }
    }
}

/// Abort sidecar tasks and stop the REST server during shutdown.
async fn stop_sidecars<T>(
    event_syncer_handle: &mut tokio::task::JoinHandle<T>,
    rest_ws_server: &mut Option<WhitelistApiServer>,
) {
    event_syncer_handle.abort();
    if let Some(server) = rest_ws_server.take() {
        server.stop().await;
    }
}
