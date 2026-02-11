//! Whitelist preconfirmation runner orchestration.

use std::{net::SocketAddr, sync::Arc, time::Instant};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::Address;
use alloy_provider::Provider;
use driver::DriverConfig;
use preconfirmation_net::P2pConfig;
use protocol::signer::FixedKSigner;
use rpc::beacon::BeaconClient;
use tracing::{info, warn};

use crate::{
    Result,
    error::WhitelistPreconfirmationDriverError,
    importer::WhitelistPreconfirmationImporter,
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, WhitelistNetwork},
    preconf_ingress_sync::PreconfIngressSync,
    rpc::{WhitelistRpcServer, WhitelistRpcServerConfig},
    rpc_handler::WhitelistRpcHandler,
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
    /// Optional hex-encoded private key for P2P block signing.
    pub p2p_signer_key: Option<String>,
    /// Optional hex-encoded 32-byte ed25519 private key for persistent libp2p peer identity.
    pub p2p_network_private_key: Option<String>,
}

impl RunnerConfig {
    /// Build runner configuration.
    pub fn new(
        driver_config: DriverConfig,
        p2p_config: P2pConfig,
        whitelist_address: Address,
        rpc_listen_addr: Option<SocketAddr>,
        rpc_jwt_secret: Option<Vec<u8>>,
        p2p_signer_key: Option<String>,
        p2p_network_private_key: Option<String>,
    ) -> Self {
        Self {
            driver_config,
            p2p_config,
            whitelist_address,
            rpc_listen_addr,
            rpc_jwt_secret,
            p2p_signer_key,
            p2p_network_private_key,
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

        let mut preconf_ingress_sync =
            PreconfIngressSync::start(&self.config.driver_config).await?;
        let wait_start = Instant::now();
        preconf_ingress_sync.wait_preconf_ingress_ready().await?;
        metrics::histogram!(
            WhitelistPreconfirmationDriverMetrics::EVENT_SYNC_WAIT_DURATION_SECONDS
        )
        .record(wait_start.elapsed().as_secs_f64());

        let mut beacon_client_init_error = None;
        let beacon_client = match BeaconClient::new(
            self.config.driver_config.l1_beacon_endpoint.clone(),
        )
        .await
        {
            Ok(client) => Some(Arc::new(client)),
            Err(err) => {
                let reason = err.to_string();
                beacon_client_init_error = Some(reason.clone());
                warn!(
                    error = %reason,
                    "failed to initialise beacon metadata client; EOS epoch-indexed cache lookups are disabled"
                );
                None
            }
        };

        let network = if self.config.p2p_network_private_key.is_some() {
            WhitelistNetwork::spawn_with_identity(
                self.config.p2p_config.clone(),
                self.config.p2p_network_private_key.clone(),
            )?
        } else {
            WhitelistNetwork::spawn(self.config.p2p_config.clone())?
        };
        info!(
            peer_id = %network.local_peer_id,
            chain_id = self.config.p2p_config.chain_id,
            "whitelist preconfirmation p2p subscriber started"
        );

        // Optionally start the REST/WS server when both rpc_listen_addr and p2p_signer_key
        // are configured.
        let mut rpc_server = if let (Some(listen_addr), Some(signer_key)) =
            (self.config.rpc_listen_addr, &self.config.p2p_signer_key)
        {
            let beacon_client = beacon_client.clone().ok_or_else(|| {
                WhitelistPreconfirmationDriverError::RpcServerBeaconInit {
                    reason: beacon_client_init_error.clone().unwrap_or_else(|| {
                        "beacon metadata client initialisation failed".to_string()
                    }),
                }
            })?;

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

            let handler = WhitelistRpcHandler::new(
                preconf_ingress_sync.event_syncer(),
                preconf_ingress_sync.client().clone(),
                self.config.p2p_config.chain_id,
                signer,
                beacon_client,
                self.config.whitelist_address,
                initial_highest_unsafe_l2_payload_block_id,
                network.command_tx.clone(),
                network.local_peer_id.to_string(),
            );

            let rpc_config = WhitelistRpcServerConfig {
                listen_addr,
                jwt_secret: self.config.rpc_jwt_secret.clone(),
                ..Default::default()
            };
            let server = WhitelistRpcServer::start(rpc_config, Arc::new(handler)).await?;
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
            beacon_client.clone(),
            network.command_tx.clone(),
        );
        let mut proposal_id_rx = preconf_ingress_sync.event_syncer().subscribe_proposal_id();

        let WhitelistNetwork { mut event_rx, command_tx, handle: mut node_handle, .. } = network;
        let event_syncer_handle = preconf_ingress_sync.handle_mut();

        loop {
            tokio::select! {
                result = &mut node_handle => {
                    event_syncer_handle.abort();
                    if let Some(server) = rpc_server.take() {
                        server.stop().await;
                    }
                    return match result {
                        Ok(Ok(())) => {
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                                "reason" => "node_exit_unexpected",
                            )
                            .increment(1);
                            Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                                "whitelist preconfirmation network exited unexpectedly".to_string(),
                            ))
                        }
                        Ok(Err(err)) => {
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                                "reason" => "node_error",
                            )
                            .increment(1);
                            Err(err)
                        }
                        Err(err) => {
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                                "reason" => "node_join_error",
                            )
                            .increment(1);
                            Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(err.to_string()))
                        }
                    };
                }
                result = &mut *event_syncer_handle => {
                    let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    node_handle.abort();
                    if let Some(server) = rpc_server.take() {
                        server.stop().await;
                    }
                    return match result {
                        Ok(Ok(())) => {
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                                "reason" => "event_syncer_exit",
                            )
                            .increment(1);
                            Err(WhitelistPreconfirmationDriverError::EventSyncerExited)
                        }
                        Ok(Err(err)) => {
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                                "reason" => "event_syncer_error",
                            )
                            .increment(1);
                            Err(WhitelistPreconfirmationDriverError::Sync(err))
                        }
                        Err(err) => {
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                                "reason" => "event_syncer_join_error",
                            )
                            .increment(1);
                            Err(WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string()))
                        }
                    };
                }
                maybe_event = event_rx.recv() => {
                    let Some(event) = maybe_event else {
                        event_syncer_handle.abort();
                        if let Some(server) = rpc_server.take() {
                            server.stop().await;
                        }
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::RUNNER_EXIT_TOTAL,
                            "reason" => "network_event_channel_closed",
                        )
                        .increment(1);
                        return Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            "whitelist preconfirmation event channel closed".to_string(),
                        ));
                    };

                    importer.handle_event(event).await?;
                }
                changed = proposal_id_rx.changed() => {
                    if changed.is_ok()
                        && let Err(err) = importer.on_sync_ready_signal().await {
                            warn!(
                                error = %err,
                                "failed to import cached whitelist preconfirmation payloads on sync-ready signal"
                            );
                        }
                }
            }
        }
    }
}
