//! Whitelist preconfirmation runner orchestration.

use std::time::Duration;

use alloy_primitives::Address;
use driver::DriverConfig;
use preconfirmation_net::P2pConfig;
use tracing::info;

use crate::{
    Result,
    error::WhitelistPreconfirmationDriverError,
    importer::WhitelistPreconfirmationImporter,
    network::{NetworkCommand, WhitelistNetwork},
    preconf_ingress_sync::PreconfIngressSync,
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
}

impl RunnerConfig {
    /// Build runner configuration.
    pub fn new(
        driver_config: DriverConfig,
        p2p_config: P2pConfig,
        whitelist_address: Address,
    ) -> Self {
        Self { driver_config, p2p_config, whitelist_address }
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
        info!("starting whitelist preconfirmation driver");

        let mut preconf_ingress_sync =
            PreconfIngressSync::start(&self.config.driver_config).await?;
        preconf_ingress_sync.wait_preconf_ingress_ready().await?;

        let network = WhitelistNetwork::spawn(self.config.p2p_config.clone())?;
        info!(peer_id = %network.local_peer_id, "whitelist preconfirmation p2p subscriber started");

        let mut importer = WhitelistPreconfirmationImporter::new(
            preconf_ingress_sync.event_syncer(),
            preconf_ingress_sync.client().clone(),
            self.config.whitelist_address,
            self.config.p2p_config.chain_id,
            network.command_tx.clone(),
        );

        let WhitelistNetwork { mut event_rx, command_tx, handle: mut node_handle, .. } = network;
        let mut heartbeat = tokio::time::interval(Duration::from_secs(1));
        let event_syncer_handle = preconf_ingress_sync.handle_mut();

        loop {
            tokio::select! {
                result = &mut node_handle => {
                    event_syncer_handle.abort();
                    return match result {
                        Ok(Ok(())) => Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            "whitelist preconfirmation network exited unexpectedly".to_string(),
                        )),
                        Ok(Err(err)) => Err(err),
                        Err(err) => Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(err.to_string())),
                    };
                }
                result = &mut *event_syncer_handle => {
                    let _ = command_tx.send(NetworkCommand::Shutdown).await;
                    node_handle.abort();
                    return match result {
                        Ok(Ok(())) => Err(WhitelistPreconfirmationDriverError::EventSyncerExited),
                        Ok(Err(err)) => Err(WhitelistPreconfirmationDriverError::Sync(err)),
                        Err(err) => Err(WhitelistPreconfirmationDriverError::EventSyncerFailed(err.to_string())),
                    };
                }
                maybe_event = event_rx.recv() => {
                    let Some(event) = maybe_event else {
                        event_syncer_handle.abort();
                        return Err(WhitelistPreconfirmationDriverError::NodeTaskFailed(
                            "whitelist preconfirmation event channel closed".to_string(),
                        ));
                    };

                    importer.handle_event(event).await?;
                }
                _ = heartbeat.tick() => {
                    importer.on_tick().await?;
                }
            }
        }
    }
}
