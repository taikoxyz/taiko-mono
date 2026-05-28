//! Whitelist preconfirmation runner orchestration.

use std::{net::SocketAddr, result, sync::Arc, time::Instant};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::Address;
use alloy_provider::Provider;
use driver::{DriverConfig, SyncPipeline, map_driver_error};
use protocol::signer::FixedKSigner;
use rpc::{beacon::BeaconClient, client::Client};
use tokio::{sync::Mutex, task::JoinHandle};
use tracing::{info, warn};

use crate::{
    Result,
    api::{
        WhitelistApiServer, WhitelistApiServerConfig, WhitelistApiService,
        WhitelistApiServiceParams,
    },
    cache::{L1_EPOCH_DURATION_SECS, SharedPreconfCacheState},
    error::WhitelistPreconfirmationDriverError,
    importer::{WhitelistPreconfirmationImporter, WhitelistPreconfirmationImporterParams},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, NetworkConfig, WhitelistNetwork},
    operator_set::OperatorSetPoller,
};

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

impl RunnerConfig {
    /// Build runner configuration.
    pub fn new(
        driver_config: DriverConfig,
        p2p_config: NetworkConfig,
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

        let client = Client::new(self.config.driver_config.client.clone()).await?;
        let pipeline =
            SyncPipeline::new(self.config.driver_config.clone(), client.clone()).await?;
        let event_syncer = pipeline.event_syncer();
        let mut event_syncer_handle: JoinHandle<EventSyncResult> =
            tokio::spawn(async move { pipeline.run().await });
        let chain_id = client.chain_id;

        info!(
            chain_id,
            whitelist_address = %self.config.whitelist_address,
            "starting whitelist preconfirmation driver"
        );

        let wait_start = Instant::now();
        tokio::select! {
            ready = event_syncer.wait_preconf_ingress_ready() => {
                ready.map_err(map_driver_error::<WhitelistPreconfirmationDriverError>)?;
            }
            result = &mut event_syncer_handle => {
                return Err(event_syncer_exit_error(result));
            }
        }
        metrics::histogram!(
            WhitelistPreconfirmationDriverMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS
        )
        .record(wait_start.elapsed().as_secs_f64());

        let operator_poller = OperatorSetPoller::new(
            self.config.whitelist_address,
            client.l1_provider.clone(),
        )
        .await?;
        let operator_set = operator_poller.shared_set();
        tokio::spawn(operator_poller.run_refresh_loop());

        let network =
            WhitelistNetwork::spawn(chain_id, self.config.p2p_config.clone(), operator_set.clone())
                .await?;
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
            chain_id,
            "whitelist preconfirmation p2p subscriber started"
        );

        // Optionally start the REST/WS server when both rpc_listen_addr and p2p_signer_key
        // are configured. When enabled, create shared state for highestUnsafeL2PayloadBlockID
        // so the importer can update it on P2P imports.
        let (mut rest_ws_server, shared_highest_unsafe) =
            if let (Some(listen_addr), Some(signer_key)) =
                (self.config.rpc_listen_addr, &self.config.p2p_signer_key)
            {
                let signer = FixedKSigner::new(signer_key).map_err(|e| {
                    WhitelistPreconfirmationDriverError::Signing(format!(
                        "failed to create P2P signer: {e}"
                    ))
                })?;
                let initial_highest_unsafe_l2_payload_block_id = client
                    .l2_provider
                    .get_block_by_number(BlockNumberOrTag::Latest)
                    .await
                    .map_err(WhitelistPreconfirmationDriverError::provider)?
                    .ok_or_else(|| {
                        WhitelistPreconfirmationDriverError::provider(
                            "latest L2 block unavailable during whitelist REST/WS startup",
                        )
                    })?
                    .header
                    .number;
                let shared_highest =
                    Arc::new(Mutex::new(initial_highest_unsafe_l2_payload_block_id));

                let handler = Arc::new(WhitelistApiService::new(WhitelistApiServiceParams {
                    event_syncer: event_syncer.clone(),
                    rpc: client.clone(),
                    chain_id,
                    signer,
                    beacon_client: Arc::clone(&beacon_client),
                    operator_set: operator_set.clone(),
                    highest_unsafe_l2_payload_block_id: shared_highest.clone(),
                    network_command_tx: network.command_tx.clone(),
                    cache_state: cache_state.clone(),
                    local_peer_id: network.local_peer_id.to_string(),
                }));
                let server_config = WhitelistApiServerConfig {
                    listen_addr,
                    jwt_secret: self.config.rpc_jwt_secret.clone(),
                    cors_origins: self.config.rpc_cors_origins.clone(),
                    ..Default::default()
                };
                let server = WhitelistApiServer::start(server_config, handler.clone()).await?;
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
                event_syncer: event_syncer.clone(),
                rpc: client.clone(),
                operator_set: operator_set.clone(),
                chain_id,
                network_command_tx: network.command_tx.clone(),
                cache_state,
                beacon_client,
                highest_unsafe_l2_payload_block_id: shared_highest_unsafe,
            });
        let mut sync_ready_interval =
            tokio::time::interval(tokio::time::Duration::from_secs(L1_EPOCH_DURATION_SECS));
        // Consume the immediate first tick so the periodic cache poll starts one
        // full epoch later; event-driven imports still call maybe_import_from_cache
        // on every inbound network event.
        sync_ready_interval.tick().await;

        let WhitelistNetwork { mut event_rx, command_tx, handle: mut node_handle, .. } = network;

        loop {
            tokio::select! {
                result = &mut node_handle => {
                    let (reason, mapped) = match result {
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
                    };
                    return finish(&mut event_syncer_handle, &mut rest_ws_server, reason, mapped).await;
                }
                result = &mut event_syncer_handle => {
                    let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    node_handle.abort();
                    let reason = match &result {
                        Ok(Ok(())) => "event_syncer_exit",
                        Ok(Err(_)) => "event_syncer_error",
                        Err(_) => "event_syncer_join_error",
                    };
                    let err = event_syncer_exit_error(result);
                    return finish(&mut event_syncer_handle, &mut rest_ws_server, reason, Err(err)).await;
                }
                maybe_event = event_rx.recv() => {
                    let Some(event) = maybe_event else {
                        return finish(
                            &mut event_syncer_handle,
                            &mut rest_ws_server,
                            "network_event_channel_closed",
                            Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                                "whitelist preconfirmation event channel closed".to_string(),
                            )),
                        )
                        .await;
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

/// Result returned by the event sync background task.
type EventSyncResult = result::Result<(), driver::DriverError>;
/// Join result returned by the event sync background task handle.
type EventSyncJoinResult = result::Result<EventSyncResult, tokio::task::JoinError>;

/// Convert event syncer task termination into a whitelist driver error.
///
/// Returned by both the ingress-readiness wait (Task 3) and the main
/// `select!` arm that observes the event syncer exiting mid-run (Task 4).
fn event_syncer_exit_error(result: EventSyncJoinResult) -> WhitelistPreconfirmationDriverError {
    match result {
        Ok(Ok(())) => WhitelistPreconfirmationDriverError::EventSyncerExited,
        Ok(Err(err)) => map_driver_error(err),
        Err(err) => WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string()),
    }
}

/// Abort sidecar tasks, stop the REST server, record the exit metric,
/// and return the final runner result. Called from each `select!` arm in
/// `WhitelistPreconfirmationDriverRunner::run`.
async fn finish(
    event_syncer_handle: &mut JoinHandle<EventSyncResult>,
    rest_ws_server: &mut Option<WhitelistApiServer>,
    reason: &'static str,
    result: Result<()>,
) -> Result<()> {
    event_syncer_handle.abort();
    if let Some(server) = rest_ws_server.take() {
        server.stop().await;
    }
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
        "reason" => reason,
    )
    .increment(1);
    result
}

#[cfg(test)]
mod tests {
    use driver::{DriverError, sync::SyncError};
    use tokio::task::JoinError;

    use super::{EventSyncJoinResult, WhitelistPreconfirmationDriverError, event_syncer_exit_error};

    fn ok_join(value: Result<(), DriverError>) -> EventSyncJoinResult {
        Ok(value)
    }

    #[tokio::test]
    async fn event_syncer_exit_error_maps_preconfirmation_disabled() {
        let mapped = event_syncer_exit_error(ok_join(Err(DriverError::PreconfirmationDisabled)));
        assert!(matches!(
            mapped,
            WhitelistPreconfirmationDriverError::Driver(DriverError::PreconfirmationDisabled)
        ));
    }

    #[tokio::test]
    async fn event_syncer_exit_error_maps_sync_driver_error() {
        let mapped = event_syncer_exit_error(ok_join(Err(DriverError::Sync(
            SyncError::MissingCheckpointResumeHead,
        ))));
        assert!(matches!(
            mapped,
            WhitelistPreconfirmationDriverError::Sync(SyncError::MissingCheckpointResumeHead)
        ));
    }

    #[tokio::test]
    async fn event_syncer_exit_error_maps_clean_exit() {
        let mapped = event_syncer_exit_error(ok_join(Ok(())));
        assert!(matches!(mapped, WhitelistPreconfirmationDriverError::EventSyncerExited));
    }

    #[tokio::test]
    async fn event_syncer_exit_error_maps_join_failure() {
        let handle = tokio::spawn(async { std::future::pending::<EventSyncJoinResult>().await });
        handle.abort();
        let join_err: JoinError = handle.await.expect_err("aborted task should join with error");
        let mapped = event_syncer_exit_error(Err(join_err));
        assert!(matches!(mapped, WhitelistPreconfirmationDriverError::EventSyncerFailed(_)));
    }
}
