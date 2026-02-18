//! Whitelist preconfirmation runner orchestration.

use std::{
    net::SocketAddr,
    result,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::Address;
use alloy_provider::Provider;
use driver::{DriverConfig, map_driver_error};
use preconfirmation_net::P2pConfig;
use protocol::signer::FixedKSigner;
use rpc::beacon::BeaconClient;
use tokio::time;
use tracing::{info, warn};

use crate::{
    Result,
    cache::L1_EPOCH_DURATION_SECS,
    error::WhitelistPreconfirmationDriverError,
    importer::WhitelistPreconfirmationImporter,
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, WhitelistNetwork},
    preconf_ingress_sync::{self, PreconfIngressSync},
    rest::{WhitelistRestWsServer, WhitelistRestWsServerConfig},
    rest_handler::{WhitelistRestHandler, WhitelistRestHandlerParams},
};

/// Join outcome emitted by the whitelist P2P node task.
type NodeLoopResult = result::Result<Result<()>, tokio::task::JoinError>;

/// Classified terminal outcome from the whitelist node task.
enum NodeExit {
    /// Node task returned `Ok(())`, which is unexpected in runner mode.
    Exited,
    /// Node task returned a driver-level error.
    Error(WhitelistPreconfirmationDriverError),
    /// Node task failed to join.
    Join(tokio::task::JoinError),
}

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

/// Increment runner exit metrics with a normalized reason label.
fn record_runner_exit(reason: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
        "reason" => reason,
    )
    .increment(1);
}

/// Classify raw node task join output into semantic exit states.
fn classify_node_exit(result: NodeLoopResult) -> NodeExit {
    match result {
        Ok(Ok(())) => NodeExit::Exited,
        Ok(Err(err)) => NodeExit::Error(err),
        Err(err) => NodeExit::Join(err),
    }
}

/// Convert whitelist node task completion into runner termination errors and metrics.
fn map_node_exit_for_runner(result: NodeLoopResult) -> WhitelistPreconfirmationDriverError {
    match classify_node_exit(result) {
        NodeExit::Exited => {
            record_runner_exit("node_exit_unexpected");
            WhitelistPreconfirmationDriverError::NodeTaskFailed(
                "whitelist preconfirmation network exited unexpectedly".to_string(),
            )
        }
        NodeExit::Error(err) => {
            record_runner_exit("node_error");
            err
        }
        NodeExit::Join(err) => {
            record_runner_exit("node_join_error");
            WhitelistPreconfirmationDriverError::NodeTaskFailed(err.to_string())
        }
    }
}

/// Convert event-sync task completion into runner termination errors and metrics.
fn map_event_syncer_exit_for_runner(
    result: preconf_ingress_sync::EventSyncJoinResult,
) -> WhitelistPreconfirmationDriverError {
    match preconf_ingress_sync::classify_event_syncer_exit(result) {
        preconf_ingress_sync::EventSyncerExit::Exited => {
            record_runner_exit("event_syncer_exit");
            WhitelistPreconfirmationDriverError::EventSyncerExited
        }
        preconf_ingress_sync::EventSyncerExit::Driver(err) => {
            record_runner_exit("event_syncer_error");
            map_driver_error(err)
        }
        preconf_ingress_sync::EventSyncerExit::Join(err) => {
            record_runner_exit("event_syncer_join_error");
            WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string())
        }
    }
}

/// Stop the optional REST/WS server when it is running.
async fn stop_rest_ws_server(rest_ws_server: &mut Option<WhitelistRestWsServer>) {
    if let Some(server) = rest_ws_server.take() {
        server.stop().await;
    }
}

/// Resolve the initial latest unsafe L2 block id used to seed REST handler state.
async fn initial_highest_unsafe_l2_payload_block_id<P>(
    preconf_ingress_sync: &PreconfIngressSync<P>,
) -> u64
where
    P: Provider + Clone + Send + Sync + 'static,
{
    match preconf_ingress_sync
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
        info!(
            chain_id = self.config.p2p_config.chain_id,
            whitelist_address = %self.config.whitelist_address,
            "starting whitelist preconfirmation driver"
        );
        if self.config.p2p_config.allow_all_sequencers {
            warn!(
                allow_all_sequencers = true,
                "p2p sequencer allow-all mode is enabled; accepting all sequencer messages"
            );
            if !self.config.p2p_config.sequencer_addresses.is_empty() {
                warn!(
                    provided_sequencer_count = self.config.p2p_config.sequencer_addresses.len(),
                    "p2p.sequencer-addresses will be ignored while allow-all mode is enabled"
                );
            }
        } else if self.config.p2p_config.sequencer_addresses.is_empty() {
            return Err(WhitelistPreconfirmationDriverError::MissingSequencerAddressList);
        }

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
        info!(
            peer_id = %network.local_peer_id,
            chain_id = self.config.p2p_config.chain_id,
            "whitelist preconfirmation p2p subscriber started"
        );

        // Optionally start the REST/WS server when both rpc_listen_addr and p2p_signer_key
        // are configured.
        let mut rest_ws_server = if let (Some(listen_addr), Some(signer_key)) =
            (self.config.rpc_listen_addr, &self.config.p2p_signer_key)
        {
            let beacon_client = Arc::new(
                BeaconClient::new(self.config.driver_config.l1_beacon_endpoint.clone())
                    .await
                    .map_err(|err| WhitelistPreconfirmationDriverError::RestWsServerBeaconInit {
                        reason: err.to_string(),
                    })?,
            );

            let signer = FixedKSigner::new(signer_key).map_err(|e| {
                WhitelistPreconfirmationDriverError::Signing(format!(
                    "failed to create P2P signer: {e}"
                ))
            })?;
            let initial_highest_unsafe_l2_payload_block_id =
                initial_highest_unsafe_l2_payload_block_id(&preconf_ingress_sync).await;

            let handler = WhitelistRestHandler::new(WhitelistRestHandlerParams {
                event_syncer: preconf_ingress_sync.event_syncer(),
                rpc: preconf_ingress_sync.client().clone(),
                chain_id: self.config.p2p_config.chain_id,
                signer,
                beacon_client,
                whitelist_address: self.config.whitelist_address,
                initial_highest_unsafe_l2_payload_block_id,
                network_command_tx: network.command_tx.clone(),
                local_peer_id: network.local_peer_id.to_string(),
            });

            let server_config = WhitelistRestWsServerConfig {
                listen_addr,
                jwt_secret: self.config.rpc_jwt_secret.clone(),
                cors_origins: self.config.rpc_cors_origins.clone(),
                ..Default::default()
            };
            let server = WhitelistRestWsServer::start(server_config, Arc::new(handler)).await?;
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

        let mut importer = WhitelistPreconfirmationImporter::new(
            preconf_ingress_sync.event_syncer(),
            preconf_ingress_sync.client().clone(),
            self.config.whitelist_address,
            self.config.p2p_config.chain_id,
            network.command_tx.clone(),
        );
        let mut epoch_tick = time::interval(Duration::from_secs(L1_EPOCH_DURATION_SECS));

        let WhitelistNetwork { mut event_rx, command_tx, handle: mut node_handle, .. } = network;
        let event_syncer_handle = preconf_ingress_sync.handle_mut();

        loop {
            tokio::select! {
                result = &mut node_handle => {
                    event_syncer_handle.abort();
                    stop_rest_ws_server(&mut rest_ws_server).await;
                    return Err(map_node_exit_for_runner(result));
                }
                result = &mut *event_syncer_handle => {
                    let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    node_handle.abort();
                    stop_rest_ws_server(&mut rest_ws_server).await;
                    return Err(map_event_syncer_exit_for_runner(result));
                }
                maybe_event = event_rx.recv() => {
                    let Some(event) = maybe_event else {
                        event_syncer_handle.abort();
                        stop_rest_ws_server(&mut rest_ws_server).await;
                        record_runner_exit("network_event_channel_closed");
                        return Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            "whitelist preconfirmation event channel closed".to_string(),
                        ));
                    };

                    importer.handle_event(event).await?;
                }
                _ = epoch_tick.tick() => {
                    if let Err(err) = importer.on_sync_ready_signal().await {
                        warn!(
                            error = %err,
                            "failed to import cached whitelist preconfirmation payloads on periodic epoch tick"
                        );
                    }
                }
            }
        }
    }
}
