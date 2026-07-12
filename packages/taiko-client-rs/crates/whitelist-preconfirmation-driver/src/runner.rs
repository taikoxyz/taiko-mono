//! Whitelist preconfirmation runner orchestration.

use std::{future::Future, net::SocketAddr, pin::Pin, sync::Arc, time::Duration};

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
            let iteration = async {
                let outcome: Option<Result<()>> = tokio::select! {
                    result = &mut node_handle => {
                        Some(match result {
                            Ok(Ok(())) => Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                                "whitelist preconfirmation network exited unexpectedly".to_string(),
                            )),
                            Ok(Err(err)) => Err(err),
                            Err(err) => Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                                err.to_string(),
                            )),
                        })
                    }
                    result = &mut event_syncer_handle => {
                        Some(map_event_syncer_exit(result).map_err(Into::into))
                    }
                    maybe_event = event_rx.recv() => match maybe_event {
                        Some(event) => {
                            if let Err(err) = importer.handle_event(event).await {
                                warn!(
                                    error = %err,
                                    "failed to handle whitelist preconfirmation network event"
                                );
                            }
                            None
                        }
                        None => {
                            Some(Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                                "whitelist preconfirmation event channel closed".to_string(),
                            )))
                        }
                    },
                    _ = sync_ready_interval.tick() => {
                        if let Err(err) = importer.maybe_import_from_cache().await {
                            warn!(
                                error = %err,
                                "failed to import cached whitelist preconfirmation payloads on sync-ready poll"
                            );
                        }
                        None
                    }
                };
                outcome
            };

            match run_until_shutdown(shutdown.as_mut(), iteration).await {
                Some(Some(result)) => {
                    // Terminal task results must escape the signal-cancellable future before
                    // cleanup starts. Otherwise a signal during REST draining can discard an
                    // already-consumed JoinHandle result and later teardown may re-poll it.
                    let cleanup = async {
                        let _ = command_tx.send(NetworkCommand::Shutdown).await;
                        node_handle.abort();
                        stop_sidecars(event_syncer_handle, &mut rest_ws_server).await;
                    };
                    match complete_cleanup_or_timeout_on_shutdown(
                        shutdown.as_mut(),
                        &mut event_rx,
                        cleanup,
                        SHUTDOWN_DRAIN_TIMEOUT,
                    )
                    .await
                    {
                        ShutdownAwareCleanupOutcome::BeforeSignal => return result,
                        ShutdownAwareCleanupOutcome::AfterSignal => return Ok(()),
                        ShutdownAwareCleanupOutcome::TimedOut => {
                            warn!("whitelist preconfirmation drain timed out; exiting anyway");
                            node_handle.abort();
                            event_syncer_handle.abort();
                            return Ok(());
                        }
                    }
                }
                Some(None) => {}
                None => {
                    info!("shutdown signal received; draining whitelist preconfirmation driver");
                    // Drain the REST server first — with ingress and P2P still available — so
                    // an in-flight build settles end to end (engine insert + gossip publish),
                    // then ask the network to shut down and wait for queued commands to be
                    // consumed. One deadline bounds the whole sequence; abort only as fallback.
                    let teardown = async {
                        if let Some(server) = rest_ws_server.take() {
                            server.stop().await;
                        }
                        request_network_shutdown(&command_tx, &mut node_handle).await;
                    };
                    if tokio::time::timeout(
                        SHUTDOWN_DRAIN_TIMEOUT,
                        complete_while_draining(&mut event_rx, teardown),
                    )
                    .await
                    .is_err()
                    {
                        warn!("whitelist preconfirmation drain timed out; exiting anyway");
                        node_handle.abort();
                    }
                    event_syncer_handle.abort();
                    return Ok(());
                }
            }
        }
    }
}

/// Result of running terminal cleanup while still observing the process shutdown signal.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ShutdownAwareCleanupOutcome {
    /// Cleanup finished normally before a shutdown signal arrived.
    BeforeSignal,
    /// A shutdown signal arrived, and cleanup then finished within the shutdown deadline.
    AfterSignal,
    /// A shutdown signal arrived, but cleanup did not finish within the shutdown deadline.
    TimedOut,
}

/// Run terminal cleanup while watching for shutdown, then bound the same in-progress cleanup
/// future if a signal arrives.
async fn complete_cleanup_or_timeout_on_shutdown<S, T, F>(
    shutdown: Pin<&mut S>,
    event_rx: &mut tokio::sync::mpsc::Receiver<T>,
    cleanup: F,
    shutdown_timeout: Duration,
) -> ShutdownAwareCleanupOutcome
where
    S: Future<Output = ()>,
    F: Future<Output = ()>,
{
    tokio::pin!(cleanup);
    if run_until_shutdown(shutdown, complete_while_draining(event_rx, cleanup.as_mut()))
        .await
        .is_some()
    {
        return ShutdownAwareCleanupOutcome::BeforeSignal;
    }

    if tokio::time::timeout(shutdown_timeout, complete_while_draining(event_rx, cleanup.as_mut()))
        .await
        .is_err()
    {
        ShutdownAwareCleanupOutcome::TimedOut
    } else {
        ShutdownAwareCleanupOutcome::AfterSignal
    }
}

/// Complete a future while discarding inbound events that could otherwise backpressure the
/// network runtime and prevent it from consuming shutdown commands.
async fn complete_while_draining<T, F>(
    event_rx: &mut tokio::sync::mpsc::Receiver<T>,
    future: F,
) -> F::Output
where
    F: Future,
{
    tokio::pin!(future);
    let mut event_rx_open = true;
    loop {
        tokio::select! {
            biased;
            result = &mut future => return result,
            event = event_rx.recv(), if event_rx_open => {
                event_rx_open = event.is_some();
            }
        }
    }
}

/// Resolve with `None` as soon as shutdown wins, including while `work` is already in progress.
async fn run_until_shutdown<S, W, T>(shutdown: Pin<&mut S>, work: W) -> Option<T>
where
    S: Future<Output = ()>,
    W: Future<Output = T>,
{
    tokio::select! {
        _ = shutdown => None,
        result = work => Some(result),
    }
}

/// Enqueue network shutdown and wait until the runtime consumes all preceding commands and exits.
async fn request_network_shutdown(
    command_tx: &tokio::sync::mpsc::Sender<NetworkCommand>,
    node_handle: &mut tokio::task::JoinHandle<Result<()>>,
) {
    // A terminal select branch may already have consumed the task output before a concurrent
    // signal redirects control into teardown. Re-polling that completed handle would panic.
    if node_handle.is_finished() {
        return;
    }
    let _ = command_tx.send(NetworkCommand::Shutdown).await;
    let _ = node_handle.await;
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

#[cfg(test)]
mod tests {
    use std::future::{pending, ready};

    use alloy_primitives::B256;
    use tokio::sync::{mpsc, oneshot};

    use super::*;

    #[tokio::test]
    async fn shutdown_preempts_pending_steady_state_work() {
        let mut shutdown = Box::pin(ready(()));

        let result = run_until_shutdown(shutdown.as_mut(), pending::<()>()).await;

        assert!(result.is_none());
    }

    #[tokio::test]
    async fn network_shutdown_waits_for_queued_commands_to_be_consumed() {
        let (command_tx, mut command_rx) = mpsc::channel(2);
        command_tx
            .send(NetworkCommand::PublishUnsafeRequest { hash: B256::ZERO })
            .await
            .expect("publish command should be queued");

        let (shutdown_received_tx, shutdown_received_rx) = oneshot::channel();
        let (allow_exit_tx, allow_exit_rx) = oneshot::channel();
        let mut node_handle = tokio::spawn(async move {
            assert!(matches!(
                command_rx.recv().await,
                Some(NetworkCommand::PublishUnsafeRequest { hash: B256::ZERO })
            ));
            assert!(matches!(command_rx.recv().await, Some(NetworkCommand::Shutdown)));
            shutdown_received_tx.send(()).expect("receiver should still be waiting");
            allow_exit_rx.await.expect("test should release network task");
            Ok(())
        });

        let shutdown = request_network_shutdown(&command_tx, &mut node_handle);
        tokio::pin!(shutdown);
        tokio::select! {
            () = &mut shutdown => panic!("shutdown returned before the network task exited"),
            result = shutdown_received_rx => result.expect("network task should observe shutdown"),
        }

        allow_exit_tx.send(()).expect("network task should still be waiting");
        shutdown.await;
    }

    #[tokio::test]
    async fn network_shutdown_does_not_repoll_a_consumed_node_handle() {
        let (command_tx, _command_rx) = mpsc::channel(1);
        let mut node_handle = tokio::spawn(async { Ok(()) });
        let result = (&mut node_handle).await;
        assert!(matches!(result, Ok(Ok(()))));

        request_network_shutdown(&command_tx, &mut node_handle).await;
    }

    #[tokio::test]
    async fn network_shutdown_drains_inbound_backpressure_before_exit() {
        let (event_tx, mut event_rx) = mpsc::channel(1);
        event_tx.send(()).await.expect("first inbound event should fill the channel");

        let (command_tx, mut command_rx) = mpsc::channel(2);
        command_tx
            .send(NetworkCommand::PublishUnsafeRequest { hash: B256::ZERO })
            .await
            .expect("publish command should be queued before shutdown");

        let mut node_handle = tokio::spawn(async move {
            event_tx.send(()).await.expect("runner should drain inbound backpressure");
            assert!(matches!(
                command_rx.recv().await,
                Some(NetworkCommand::PublishUnsafeRequest { hash: B256::ZERO })
            ));
            assert!(matches!(command_rx.recv().await, Some(NetworkCommand::Shutdown)));
            Ok(())
        });

        tokio::time::timeout(
            Duration::from_millis(100),
            complete_while_draining(
                &mut event_rx,
                request_network_shutdown(&command_tx, &mut node_handle),
            ),
        )
        .await
        .expect("network shutdown should make progress while inbound forwarding is backpressured");
    }

    #[tokio::test]
    async fn terminal_cleanup_uses_shutdown_deadline_after_signal() {
        let (cleanup_started_tx, cleanup_started_rx) = oneshot::channel();
        let mut shutdown = Box::pin(async {
            cleanup_started_rx.await.expect("cleanup should start before shutdown");
        });
        let (_event_tx, mut event_rx) = mpsc::channel::<()>(1);
        let cleanup = async move {
            cleanup_started_tx.send(()).expect("shutdown should still be waiting");
            pending::<()>().await;
        };

        let outcome = complete_cleanup_or_timeout_on_shutdown(
            shutdown.as_mut(),
            &mut event_rx,
            cleanup,
            Duration::from_millis(10),
        )
        .await;

        assert_eq!(outcome, ShutdownAwareCleanupOutcome::TimedOut);
    }
}
