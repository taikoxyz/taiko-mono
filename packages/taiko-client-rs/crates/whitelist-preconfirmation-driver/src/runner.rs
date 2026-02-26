//! Whitelist preconfirmation runner orchestration.

use std::{net::SocketAddr, sync::Arc, time::Instant};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::Address;
use alloy_provider::Provider;
use driver::{DriverConfig, map_driver_error};
use preconfirmation_net::P2pConfig;
use protocol::signer::FixedKSigner;
use rpc::beacon::BeaconClient;
use tokio::sync::Mutex;
use tracing::{info, warn};

use crate::{
    Result,
    cache::{L1_EPOCH_DURATION_SECS, SharedPreconfCacheState},
    error::WhitelistPreconfirmationDriverError,
    importer::{WhitelistPreconfirmationImporter, WhitelistPreconfirmationImporterParams},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, WhitelistNetwork},
    preconf_ingress_sync::{EventSyncJoinResult, PreconfIngressSync},
    rest::{WhitelistRestWsServer, WhitelistRestWsServerConfig},
    rest_handler::{WhitelistRestHandler, WhitelistRestHandlerParams},
    whitelist_fetcher::WhitelistSequencerFetcher,
};

/// Configuration for the whitelist preconfirmation runner.
#[derive(Clone, Debug)]
pub struct RunnerConfig {
    /// Driver configuration (includes RPC client configuration).
    pub driver_config: DriverConfig,
    /// P2P configuration for whitelist preconfirmation topics.
    pub p2p_config: P2pConfig,
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

impl RunnerConfig {
    /// Build runner configuration.
    pub fn new(
        driver_config: DriverConfig,
        p2p_config: P2pConfig,
        whitelist_address: Address,
        rpc_listen_addr: Option<SocketAddr>,
        rpc_jwt_secret: Option<Vec<u8>>,
        rpc_cors_origins: Vec<String>,
        p2p_signer_key: Option<String>,
    ) -> Self {
        Self {
            driver_config,
            p2p_config,
            whitelist_address,
            rpc_listen_addr,
            rpc_jwt_secret,
            rpc_cors_origins,
            p2p_signer_key,
        }
    }
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
        metrics::counter!(WhitelistPreconfirmationDriverMetrics::RUNNER_START_TOTAL).increment(1);

        // Fail fast on deterministic misconfiguration before blocking on sync bootstrap.
        if !self.config.p2p_config.allow_all_sequencers &&
            self.config.p2p_config.sequencer_addresses.is_empty()
        {
            return Err(WhitelistPreconfirmationDriverError::MissingSequencerAddressList);
        }

        info!(
            chain_id = self.config.p2p_config.chain_id,
            whitelist_address = %self.config.whitelist_address,
            "starting whitelist preconfirmation driver"
        );

        let mut preconf_ingress_sync =
            PreconfIngressSync::start(&self.config.driver_config).await?;
        let wait_start = Instant::now();
        preconf_ingress_sync.wait_preconf_ingress_ready().await?;
        metrics::histogram!(
            WhitelistPreconfirmationDriverMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS
        )
        .record(wait_start.elapsed().as_secs_f64());

        let network =
            WhitelistNetwork::spawn_with_whitelist_filter(self.config.p2p_config.clone())?;
        let cache_state = SharedPreconfCacheState::new();
        let beacon_client = Arc::new(
            BeaconClient::new(self.config.driver_config.l1_beacon_endpoint.clone()).await.map_err(
                |err| WhitelistPreconfirmationDriverError::RestWsServerBeaconInit {
                    reason: err.to_string(),
                },
            )?,
        );
        info!(
            peer_id = %network.local_peer_id,
            chain_id = self.config.p2p_config.chain_id,
            "whitelist preconfirmation p2p subscriber started"
        );

        // Optionally start the REST/WS server when both rpc_listen_addr and p2p_signer_key
        // are configured. When enabled, create shared state for highestUnsafeL2PayloadBlockID
        // so the importer can update it on P2P imports.
        let (mut rest_ws_server, shared_highest_unsafe) = if let (
            Some(listen_addr),
            Some(signer_key),
        ) =
            (self.config.rpc_listen_addr, &self.config.p2p_signer_key)
        {
            let signer = FixedKSigner::new(signer_key).map_err(|e| {
                WhitelistPreconfirmationDriverError::Signing(format!(
                    "failed to create P2P signer: {e}"
                ))
            })?;
            let initial_highest_unsafe_l2_payload_block_id = match preconf_ingress_sync
                .client()
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Latest)
                .await
            {
                Ok(Some(block)) => block.header.number,
                Ok(None) => 0,
                Err(err) => {
                    warn!(
                        error = %err,
                        "failed to fetch initial latest L2 block; defaulting highest unsafe block id to zero"
                    );
                    0
                }
            };
            let shared_highest = Arc::new(Mutex::new(initial_highest_unsafe_l2_payload_block_id));

            let rest_sequencer_fetcher = WhitelistSequencerFetcher::new(
                self.config.whitelist_address,
                preconf_ingress_sync.client().l1_provider.clone(),
            );
            let handler = Arc::new(WhitelistRestHandler::new(WhitelistRestHandlerParams {
                event_syncer: preconf_ingress_sync.event_syncer(),
                rpc: preconf_ingress_sync.client().clone(),
                chain_id: self.config.p2p_config.chain_id,
                signer,
                beacon_client: Arc::clone(&beacon_client),
                sequencer_fetcher: rest_sequencer_fetcher,
                highest_unsafe_l2_payload_block_id: shared_highest.clone(),
                network_command_tx: network.command_tx.clone(),
                cache_state: cache_state.clone(),
                local_peer_id: network.local_peer_id.to_string(),
            }));
            let server_config = WhitelistRestWsServerConfig {
                listen_addr,
                jwt_secret: self.config.rpc_jwt_secret.clone(),
                cors_origins: self.config.rpc_cors_origins.clone(),
                ..Default::default()
            };
            let server = WhitelistRestWsServer::start(server_config, handler.clone()).await?;
            info!(
                addr = %server.local_addr(),
                http_url = %server.http_url(),
                ws_url = %server.ws_url(),
                "whitelist preconfirmation REST server started"
            );
            (Some(server), Some(shared_highest))
        } else {
            (None, None)
        };

        let mut importer =
            WhitelistPreconfirmationImporter::new(WhitelistPreconfirmationImporterParams {
                event_syncer: preconf_ingress_sync.event_syncer(),
                rpc: preconf_ingress_sync.client().clone(),
                whitelist_address: self.config.whitelist_address,
                chain_id: self.config.p2p_config.chain_id,
                network_command_tx: network.command_tx.clone(),
                cache_state,
                beacon_client,
                highest_unsafe_l2_payload_block_id: shared_highest_unsafe,
            });
        let mut sync_ready_interval =
            tokio::time::interval(tokio::time::Duration::from_secs(L1_EPOCH_DURATION_SECS));
        sync_ready_interval.tick().await;

        let WhitelistNetwork { mut event_rx, command_tx, handle: mut node_handle, .. } = network;
        let mut event_syncer_handle = preconf_ingress_sync.handle_mut();

        loop {
            tokio::select! {
                result = &mut node_handle => {
                    return finish_runner(
                        event_syncer_handle,
                        &mut rest_ws_server,
                        map_node_exit_for_runner(result),
                    )
                    .await;
                }
                result = &mut event_syncer_handle => {
                    let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    node_handle.abort();
                    return finish_runner(
                        event_syncer_handle,
                        &mut rest_ws_server,
                        map_event_syncer_exit_for_runner(result),
                    )
                    .await;
                }
                maybe_event = event_rx.recv() => {
                    let Some(event) = maybe_event else {
                        return finish_runner(
                            event_syncer_handle,
                            &mut rest_ws_server,
                            (
                                "network_event_channel_closed",
                                Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                                "whitelist preconfirmation event channel closed".to_string(),
                            )),
                            ),
                        )
                        .await;
                    };

                    importer.handle_event(event).await?;
                }
                _ = sync_ready_interval.tick() => {
                    importer.maybe_invalidate_sequencer_cache_for_epoch().await;
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
    rest_ws_server: &mut Option<WhitelistRestWsServer>,
) {
    event_syncer_handle.abort();
    if let Some(server) = rest_ws_server.take() {
        server.stop().await;
    }
}

/// Tuple describing the runner exit reason and result.
type RunnerExit = (&'static str, Result<()>);

/// Stop sidecars and return the unified runner exit result.
async fn finish_runner<T>(
    event_syncer_handle: &mut tokio::task::JoinHandle<T>,
    rest_ws_server: &mut Option<WhitelistRestWsServer>,
    (reason, result): RunnerExit,
) -> Result<()> {
    stop_sidecars(event_syncer_handle, rest_ws_server).await;
    record_runner_exit(reason, result)
}

/// Convert a node task result into a standardized runner exit reason.
fn map_node_exit_for_runner(
    result: std::result::Result<
        std::result::Result<(), WhitelistPreconfirmationDriverError>,
        tokio::task::JoinError,
    >,
) -> (&'static str, Result<()>) {
    match result {
        Ok(Ok(())) => (
            "node_exit_unexpected",
            Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                "whitelist preconfirmation network exited unexpectedly".to_string(),
            )),
        ),
        Ok(Err(err)) => ("node_error", Err(err)),
        Err(err) => (
            "node_join_error",
            Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(err.to_string())),
        ),
    }
}

/// Convert an event-syncer result into a standardized runner exit reason.
fn map_event_syncer_exit_for_runner(result: EventSyncJoinResult) -> (&'static str, Result<()>) {
    match result {
        Ok(Ok(())) => {
            ("event_syncer_exit", Err(WhitelistPreconfirmationDriverError::EventSyncerExited))
        }
        Ok(Err(err)) => (
            "event_syncer_error",
            Err(map_driver_error::<WhitelistPreconfirmationDriverError>(err)),
        ),
        Err(err) => (
            "event_syncer_join_error",
            Err(WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string())),
        ),
    }
}

/// Record exit reason and return the final result.
fn record_runner_exit(reason: &'static str, result: Result<()>) -> Result<()> {
    metrics::counter!(WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL, "reason" => reason)
        .increment(1);
    result
}
