//! Preconfirmation driver subcommand.

use std::{future::Future, sync::Arc};

use alloy::{
    eips::BlockNumberOrTag, providers::Provider, transports::http::reqwest::Url as RpcUrl,
};
use alloy_primitives::U256;
use async_trait::async_trait;
use clap::Parser;
use driver::{
    DriverConfig, PreconfPayload, SyncStage,
    metrics::DriverMetrics,
    sync::{SyncError, event::EventSyncer},
};
use preconfirmation_driver::{
    ContractInboxReader, DriverChannels, PreconfirmationClientConfig, PreconfirmationClientMetrics,
    PreconfirmationDriverNode, PreconfirmationDriverNodeConfig,
    driver_interface::payload::build_taiko_payload_attributes, rpc::PreconfRpcServerConfig,
};
use preconfirmation_net::P2pConfig;
use rpc::{
    SubscriptionSource,
    client::{Client, ClientConfig},
};
use tokio::sync::watch;
use tracing::{error, info, warn};

use crate::{
    commands::Subcommand,
    error::{CliError, Result},
    flags::{common::CommonArgs, driver::DriverArgs, preconfirmation::PreconfirmationArgs},
};

/// Command-line interface for running the preconfirmation driver.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the preconfirmation driver with embedded P2P client")]
pub struct PreconfirmationDriverSubCommand {
    /// Common CLI arguments shared across all subcommands.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// Driver-specific CLI arguments.
    #[command(flatten)]
    pub driver_flags: DriverArgs,
    /// Preconfirmation-specific CLI arguments.
    #[command(flatten)]
    pub preconf_flags: PreconfirmationArgs,
}

impl PreconfirmationDriverSubCommand {
    /// Build driver configuration from command-line arguments.
    fn build_driver_config(&self) -> Result<DriverConfig> {
        let l1_source =
            SubscriptionSource::Ws(RpcUrl::parse(self.common_flags.l1_ws_endpoint.as_str())?);
        let l2_http = RpcUrl::parse(self.common_flags.l2_http_endpoint.as_str())?;
        let l2_auth = RpcUrl::parse(self.common_flags.l2_auth_endpoint.as_str())?;
        let l1_beacon = RpcUrl::parse(self.driver_flags.l1_beacon_endpoint.as_str())?;

        let l2_checkpoint = self
            .driver_flags
            .l2_checkpoint_endpoint
            .as_ref()
            .map(|url| RpcUrl::parse(url.as_str()))
            .transpose()?;

        let blob_server = self
            .driver_flags
            .blob_server_endpoint
            .as_ref()
            .map(|url| RpcUrl::parse(url.as_str()))
            .transpose()?;

        let client_cfg = ClientConfig {
            l1_provider_source: l1_source,
            l2_provider_url: l2_http,
            l2_auth_provider_url: l2_auth,
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
        };

        let mut cfg = DriverConfig::new(
            client_cfg,
            self.driver_flags.retry_interval(),
            l1_beacon,
            l2_checkpoint,
            blob_server,
        );

        // Enable preconfirmation since we're running P2P client.
        cfg.preconfirmation_enabled = true;

        Ok(cfg)
    }

    /// Build P2P configuration from command-line arguments.
    fn build_p2p_config(&self) -> P2pConfig {
        let pre_dial_peers = self
            .preconf_flags
            .p2p_static_peers
            .iter()
            .filter_map(|peer| {
                peer.parse().map_err(|_| warn!(peer, "failed to parse static peer address")).ok()
            })
            .collect();

        P2pConfig {
            listen_addr: self.preconf_flags.p2p_listen,
            discovery_listen: self.preconf_flags.p2p_discovery_addr,
            enable_discovery: !self.preconf_flags.p2p_disable_discovery,
            bootnodes: self.preconf_flags.p2p_bootnodes.clone(),
            pre_dial_peers,
            ..Default::default()
        }
    }

    /// Resolve the preconfirmation tip from the L2 latest head.
    async fn resolve_preconf_tip_from_l2<P>(_proposal_id: u64, l2_provider: &P) -> Option<U256>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
        match l2_provider.get_block_by_number(BlockNumberOrTag::Latest).await {
            Ok(Some(block)) => Some(U256::from(block.number())),
            Ok(None) => {
                warn!("failed to resolve L2 latest head for preconfirmation tip");
                None
            }
            Err(err) => {
                warn!(?err, "failed to query L2 latest head for preconfirmation tip");
                None
            }
        }
    }

    /// Wait for the preconfirmation ingress loop to be ready or fail if the event syncer exits.
    async fn wait_for_preconf_ingress_ready<F>(
        ready: F,
        event_syncer_handle: &mut tokio::task::JoinHandle<std::result::Result<(), SyncError>>,
    ) -> Result<()>
    where
        F: Future<Output = Option<()>> + Send,
    {
        tokio::select! {
            ready = ready => ready.ok_or(CliError::PreconfIngressNotEnabled),
            result = event_syncer_handle => {
                match result {
                    Ok(Ok(())) => Err(CliError::EventSyncerExited),
                    Ok(Err(err)) => Err(CliError::Sync(err)),
                    Err(err) => Err(CliError::EventSyncerFailed(err.to_string())),
                }
            }
        }
    }

    /// Seed the proposal state to the event syncer.
    async fn seed_proposal_state<P>(
        proposal_id_rx: &mut watch::Receiver<u64>,
        canonical_sender: &watch::Sender<u64>,
        preconf_tip_sender: &watch::Sender<U256>,
        l2_provider: &P,
    ) where
        P: Provider + Clone + Send + Sync + 'static,
    {
        let proposal_id = *proposal_id_rx.borrow_and_update();
        Self::publish_proposal_state(
            proposal_id,
            canonical_sender,
            preconf_tip_sender,
            l2_provider,
        )
        .await;
    }

    /// Wait for the preconfirmation driver or event syncer to exit.
    async fn wait_for_driver_exit<N>(
        node_run: N,
        event_syncer_handle: &mut tokio::task::JoinHandle<std::result::Result<(), SyncError>>,
    ) -> Result<()>
    where
        N: Future<
                Output = std::result::Result<
                    (),
                    preconfirmation_driver::PreconfirmationClientError,
                >,
            > + Send,
    {
        tokio::select! {
            result = node_run => {
                match result {
                    Ok(()) => Ok(()),
                    Err(err) => {
                        error!(?err, "preconfirmation node exited with error");
                        Err(CliError::from(err))
                    }
                }
            }
            result = event_syncer_handle => {
                match result {
                    Ok(Ok(())) => {
                        error!("event syncer task exited unexpectedly");
                        Err(CliError::EventSyncerExited)
                    }
                    Ok(Err(err)) => {
                        error!(?err, "event syncer exited with error");
                        Err(CliError::Sync(err))
                    }
                    Err(err) => {
                        error!(?err, "event syncer task failed");
                        Err(CliError::EventSyncerFailed(err.to_string()))
                    }
                }
            }
        }
    }

    /// Publish the current proposal state to the event syncer.
    async fn publish_proposal_state<P>(
        proposal_id: u64,
        canonical_sender: &watch::Sender<u64>,
        preconf_tip_sender: &watch::Sender<U256>,
        l2_provider: &P,
    ) where
        P: Provider + Clone + Send + Sync + 'static,
    {
        if canonical_sender.send(proposal_id).is_err() {
            error!(proposal_id, "failed to publish canonical proposal id");
        }
        if let Some(tip) = Self::resolve_preconf_tip_from_l2(proposal_id, l2_provider).await {
            if preconf_tip_sender.send(tip).is_err() {
                error!(
                    proposal_id,
                    preconf_tip = %tip,
                    "failed to publish preconfirmation tip"
                );
            }
        } else {
            error!(proposal_id, "failed to resolve preconfirmation tip from L2 latest head");
        }
    }

    /// Spawn task to forward proposal state updates to EventSyncer.
    async fn forward_state_updates<P>(
        mut proposal_id_rx: watch::Receiver<u64>,
        canonical_sender: watch::Sender<u64>,
        preconf_tip_sender: watch::Sender<U256>,
        l2_provider: P,
    ) where
        P: Provider + Clone + Send + Sync + 'static,
    {
        Self::seed_proposal_state(
            &mut proposal_id_rx,
            &canonical_sender,
            &preconf_tip_sender,
            &l2_provider,
        )
        .await;

        loop {
            if proposal_id_rx.changed().await.is_err() {
                break;
            }
            let id = *proposal_id_rx.borrow();
            Self::publish_proposal_state(id, &canonical_sender, &preconf_tip_sender, &l2_provider)
                .await;
        }
    }

    /// Spawn task to forward preconfirmation inputs from node channels to EventSyncer.
    fn spawn_input_forwarder<P>(
        event_syncer: Arc<EventSyncer<P>>,
        mut channels: DriverChannels,
        driver_client: Client<P>,
    ) -> tokio::task::JoinHandle<()>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
        tokio::spawn(async move {
            // Subscribe to proposal ID changes (event-driven, not polling)
            let proposal_id_rx = event_syncer.subscribe_proposal_id();
            let canonical_sender = channels.canonical_proposal_id_sender.clone();
            let preconf_tip_sender = channels.preconf_tip_sender.clone();
            let l2_provider = driver_client.l2_provider.clone();

            // Spawn event-driven state update task
            let state_update_handle = tokio::spawn(Self::forward_state_updates(
                proposal_id_rx,
                canonical_sender,
                preconf_tip_sender,
                l2_provider,
            ));

            while let Some(input) = channels.input_receiver.recv().await {
                if input.should_skip_driver_submission() {
                    continue;
                }
                let config = match driver_client.shasta.inbox.getConfig().call().await {
                    Ok(config) => config,
                    Err(err) => {
                        error!(?err, "failed to fetch inbox config for payload build");
                        continue;
                    }
                };
                let payload = match build_taiko_payload_attributes(
                    &input,
                    config.basefeeSharingPctg,
                    &driver_client.l2_provider,
                )
                .await
                {
                    Ok(payload) => payload,
                    Err(err) => {
                        error!(
                            ?err,
                            block_number = ?input.commitment.commitment.preconf.block_number,
                            "failed to build preconfirmation payload"
                        );
                        continue;
                    }
                };

                if let Err(err) =
                    event_syncer.submit_preconfirmation_payload(PreconfPayload::new(payload)).await
                {
                    error!(
                        ?err,
                        block_number = ?input.commitment.commitment.preconf.block_number,
                        "failed to submit preconfirmation payload"
                    );
                }
            }

            state_update_handle.abort();
        })
    }

    /// Run the preconfirmation driver.
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

#[cfg(test)]
mod tests {
    use super::PreconfirmationDriverSubCommand;
    use crate::error::CliError;
    use alloy::{providers::ProviderBuilder, transports::mock::Asserter};
    use alloy_consensus::Header as ConsensusHeader;
    use alloy_primitives::U256;
    use alloy_rpc_types_eth::{Block, Header as RpcHeader};
    use driver::sync::SyncError;
    use preconfirmation_driver::PreconfirmationClientError;
    use std::time::Duration;
    use tokio::sync::watch;

    #[tokio::test]
    async fn preconf_tip_from_l2_uses_latest_head() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        let mut header = ConsensusHeader::default();
        header.number = 42;
        let block: Block = Block::empty(RpcHeader::new(header));
        asserter.push_success(&Some(block));

        let tip =
            PreconfirmationDriverSubCommand::resolve_preconf_tip_from_l2(100, &provider).await;
        assert_eq!(tip, Some(U256::from(42u64)));
        assert!(
            asserter.read_q().is_empty(),
            "expected unsafe head query to consume mock response"
        );
    }

    #[tokio::test]
    async fn preconf_tip_from_l2_handles_rpc_error() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        asserter.push_failure_msg("boom");

        let tip =
            PreconfirmationDriverSubCommand::resolve_preconf_tip_from_l2(100, &provider).await;
        assert_eq!(tip, None);
    }

    #[tokio::test]
    async fn preconf_tip_from_l2_handles_missing_latest_block() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        let block: Option<Block> = None;
        asserter.push_success(&block);

        let tip =
            PreconfirmationDriverSubCommand::resolve_preconf_tip_from_l2(100, &provider).await;
        assert_eq!(tip, None);
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_returns_error_on_syncer_exit() {
        let ready = std::future::pending::<Option<()>>();
        let mut handle = tokio::spawn(async { Ok(()) });

        let result = tokio::time::timeout(
            Duration::from_millis(50),
            PreconfirmationDriverSubCommand::wait_for_preconf_ingress_ready(ready, &mut handle),
        )
        .await;

        assert!(matches!(result, Ok(Err(CliError::EventSyncerExited))));
    }

    #[tokio::test]
    async fn wait_for_preconf_ingress_ready_returns_ok_when_ready() {
        let ready = async { Some(()) };
        let mut handle = tokio::spawn(async {
            std::future::pending::<std::result::Result<(), SyncError>>().await
        });

        let result = tokio::time::timeout(
            Duration::from_millis(50),
            PreconfirmationDriverSubCommand::wait_for_preconf_ingress_ready(ready, &mut handle),
        )
        .await;

        assert!(matches!(result, Ok(Ok(()))));
        handle.abort();
    }

    #[tokio::test]
    async fn seed_proposal_state_publishes_current_values() {
        let (proposal_tx, mut proposal_rx) = watch::channel(0u64);
        let (canonical_tx, canonical_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

        proposal_tx.send(7).expect("proposal id update should succeed");

        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        let mut header = ConsensusHeader::default();
        header.number = 42;
        let block: Block = Block::empty(RpcHeader::new(header));
        asserter.push_success(&Some(block));

        PreconfirmationDriverSubCommand::seed_proposal_state(
            &mut proposal_rx,
            &canonical_tx,
            &preconf_tip_tx,
            &provider,
        )
        .await;

        assert_eq!(*canonical_rx.borrow(), 7);
        assert_eq!(*preconf_tip_rx.borrow(), U256::from(42u64));
    }

    #[tokio::test]
    async fn wait_for_driver_exit_propagates_node_error() {
        let mut event_syncer_handle = tokio::spawn(async {
            std::future::pending::<std::result::Result<(), SyncError>>().await
        });

        let result = PreconfirmationDriverSubCommand::wait_for_driver_exit(
            async { Err(PreconfirmationClientError::Network("boom".into())) },
            &mut event_syncer_handle,
        )
        .await;

        assert!(matches!(result, Err(CliError::Preconfirmation(_))));
        event_syncer_handle.abort();
    }

    #[tokio::test]
    async fn wait_for_driver_exit_propagates_syncer_error() {
        let mut event_syncer_handle =
            tokio::spawn(async { Err(SyncError::MissingLatestExecutionBlock) });

        let result = PreconfirmationDriverSubCommand::wait_for_driver_exit(
            std::future::pending::<Result<(), PreconfirmationClientError>>(),
            &mut event_syncer_handle,
        )
        .await;

        assert!(matches!(result, Err(CliError::Sync(SyncError::MissingLatestExecutionBlock))));
    }
}

#[async_trait]
impl Subcommand for PreconfirmationDriverSubCommand {
    /// Returns a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Registers driver and preconfirmation metrics with the global registry.
    fn register_metrics(&self) -> Result<()> {
        DriverMetrics::init();
        PreconfirmationClientMetrics::init();
        Ok(())
    }

    /// Runs the preconfirmation driver with embedded P2P client.
    ///
    /// This method initializes the driver event syncer, waits for it to be ready,
    /// then starts the preconfirmation P2P node and forwards inputs to the driver.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        info!("starting preconfirmation driver");

        let driver_config = self.build_driver_config()?;
        let p2p_config = self.build_p2p_config();

        let driver_client = Client::new(driver_config.client.clone()).await?;
        let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);

        info!("waiting for driver event sync to initialize");
        let event_syncer_run = event_syncer.clone();
        let event_syncer_handle = tokio::spawn(async move { event_syncer_run.run().await });

        let mut event_syncer_handle = event_syncer_handle;
        // Wait for the ingress loop or fail fast if the syncer exits before readiness.
        Self::wait_for_preconf_ingress_ready(
            event_syncer.wait_preconf_ingress_ready(),
            &mut event_syncer_handle,
        )
        .await?;

        info!("driver ready, starting preconfirmation P2P client");

        let mut node_config = PreconfirmationDriverNodeConfig::new(
            PreconfirmationClientConfig::new(
                p2p_config,
                self.common_flags.shasta_inbox_address,
                driver_client.l1_provider.clone(),
            )
            .await?,
        );
        if let Some(rpc_addr) = self.preconf_flags.preconf_rpc_addr {
            node_config = node_config.with_rpc(PreconfRpcServerConfig { listen_addr: rpc_addr });
        }

        let inbox_reader = ContractInboxReader::new(driver_client.shasta.inbox.clone());

        let (node, channels) = PreconfirmationDriverNode::new(node_config, inbox_reader)?;
        let forward_handle =
            Self::spawn_input_forwarder(event_syncer.clone(), channels, driver_client.clone());

        info!("starting preconfirmation P2P event loop");

        let run_result = Self::wait_for_driver_exit(node.run(), &mut event_syncer_handle).await;

        forward_handle.abort();
        event_syncer_handle.abort();
        info!("preconfirmation driver stopped");
        run_result
    }
}
