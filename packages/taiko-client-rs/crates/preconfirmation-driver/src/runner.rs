//! Preconfirmation driver runner orchestration.

use std::{future::Future, sync::Arc};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use driver::{
    DriverConfig, PreconfPayload, SyncStage,
    sync::{SyncError, event::EventSyncer},
};
use preconfirmation_net::P2pConfig;
use rpc::client::Client;
use tokio::sync::watch;
use tracing::{error, info};

use crate::{
    ContractInboxReader, DriverChannels, PreconfirmationClientConfig, PreconfirmationClientError,
    PreconfirmationDriverNode, PreconfirmationDriverNodeConfig,
    driver_interface::payload::build_taiko_payload_attributes, rpc::PreconfRpcServerConfig,
};

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
    /// Input forwarder task failed.
    #[error("input forwarder task failed: {0}")]
    InputForwarderFailed(String),
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
#[derive(Clone, Debug)]
pub struct PreconfirmationDriverRunner {
    config: RunnerConfig,
}

impl PreconfirmationDriverRunner {
    /// Create a new runner.
    pub fn new(config: RunnerConfig) -> Self {
        Self { config }
    }

    /// Run the preconfirmation driver until any component exits.
    pub async fn run(self) -> Result<(), RunnerError> {
        info!("starting preconfirmation driver");

        let driver_client = Client::new(self.config.driver_config.client.clone()).await?;
        let event_syncer =
            Arc::new(EventSyncer::new(&self.config.driver_config, driver_client.clone()).await?);

        info!("waiting for driver event sync to initialize");
        let event_syncer_run = event_syncer.clone();
        let mut event_syncer_handle = tokio::spawn(async move { event_syncer_run.run().await });

        wait_for_preconf_ingress_ready(
            event_syncer.wait_preconf_ingress_ready(),
            &mut event_syncer_handle,
        )
        .await?;

        info!("driver ready, starting preconfirmation P2P client");

        let mut node_config = PreconfirmationDriverNodeConfig::new(
            PreconfirmationClientConfig::new(
                self.config.p2p_config,
                self.config.driver_config.client.inbox_address,
                driver_client.l1_provider.clone(),
            )
            .await?,
        );
        if let Some(rpc_config) = self.config.rpc_config {
            node_config = node_config.with_rpc(rpc_config);
        }

        let inbox_reader = ContractInboxReader::new(driver_client.shasta.inbox.clone());
        let (node, channels) = PreconfirmationDriverNode::new(node_config, inbox_reader)?;

        let mut node_handle = tokio::spawn(node.run());
        let mut forward_handle = tokio::spawn(run_input_forwarder(
            event_syncer.clone(),
            channels,
            driver_client.clone(),
        ));

        info!("starting preconfirmation P2P event loop");

        let run_result = tokio::select! {
            result = &mut node_handle => {
                forward_handle.abort();
                event_syncer_handle.abort();
                match result {
                    Ok(Ok(())) => Ok(()),
                    Ok(Err(err)) => Err(RunnerError::Preconfirmation(err)),
                    Err(err) => Err(RunnerError::NodeTaskFailed(err.to_string())),
                }
            }
            result = &mut forward_handle => {
                node_handle.abort();
                event_syncer_handle.abort();
                match result {
                    Ok(Ok(())) => Ok(()),
                    Ok(Err(err)) => Err(err),
                    Err(err) => Err(RunnerError::InputForwarderFailed(err.to_string())),
                }
            }
            result = &mut event_syncer_handle => {
                node_handle.abort();
                forward_handle.abort();
                match result {
                    Ok(Ok(())) => Err(RunnerError::EventSyncerExited),
                    Ok(Err(err)) => Err(RunnerError::Sync(err)),
                    Err(err) => Err(RunnerError::EventSyncerFailed(err.to_string())),
                }
            }
        };

        info!("preconfirmation driver stopped");
        run_result
    }
}

/// Resolve the preconfirmation tip from the L2 latest head.
async fn resolve_preconf_tip_from_l2<P>(l2_provider: &P) -> Result<U256, RunnerError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    match l2_provider.get_block_by_number(BlockNumberOrTag::Latest).await {
        Ok(Some(block)) => Ok(U256::from(block.number())),
        Ok(None) => Err(RunnerError::MissingL2LatestHead),
        Err(err) => Err(RunnerError::L2LatestHeadQuery(err.to_string())),
    }
}

/// Publish the proposal state to the event syncer.
async fn publish_proposal_state<P>(
    proposal_id: u64,
    canonical_tx: &watch::Sender<u64>,
    preconf_tip_tx: &watch::Sender<U256>,
    l2_provider: &P,
) -> Result<(), RunnerError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    if canonical_tx.send(proposal_id).is_err() {
        error!(proposal_id, "failed to publish canonical proposal id");
    }

    let tip = resolve_preconf_tip_from_l2(l2_provider).await?;
    if preconf_tip_tx.send(tip).is_err() {
        error!(proposal_id, preconf_tip = %tip, "failed to publish preconfirmation tip");
    }

    Ok(())
}

/// Seed the initial proposal state to the event syncer.
async fn seed_proposal_state<P>(
    proposal_id_rx: &mut watch::Receiver<u64>,
    canonical_tx: &watch::Sender<u64>,
    preconf_tip_tx: &watch::Sender<U256>,
    l2_provider: &P,
) -> Result<(), RunnerError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let proposal_id = *proposal_id_rx.borrow_and_update();
    publish_proposal_state(proposal_id, canonical_tx, preconf_tip_tx, l2_provider).await
}

/// Forward preconfirmation inputs from the driver to the event syncer.
async fn run_input_forwarder<P>(
    event_syncer: Arc<EventSyncer<P>>,
    mut channels: DriverChannels,
    driver_client: Client<P>,
) -> Result<(), RunnerError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let mut proposal_id_rx = event_syncer.subscribe_proposal_id();
    let canonical_tx = channels.canonical_proposal_id_tx.clone();
    let preconf_tip_tx = channels.preconf_tip_tx.clone();
    let l2_provider = driver_client.l2_provider.clone();

    seed_proposal_state(&mut proposal_id_rx, &canonical_tx, &preconf_tip_tx, &l2_provider).await?;

    loop {
        tokio::select! {
            changed = proposal_id_rx.changed() => {
                if changed.is_err() {
                    break;
                }
                let id = *proposal_id_rx.borrow();
                publish_proposal_state(id, &canonical_tx, &preconf_tip_tx, &l2_provider).await?;
            }
            input = channels.input_rx.recv() => {
                let Some(input) = input else { break; };
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
        }
    }

    Ok(())
}

/// Wait for preconfirmation ingress to be ready or the event syncer to exit.
async fn wait_for_preconf_ingress_ready<F>(
    ready: F,
    event_syncer_handle: &mut tokio::task::JoinHandle<std::result::Result<(), SyncError>>,
) -> Result<(), RunnerError>
where
    F: Future<Output = Option<()>> + Send,
{
    tokio::select! {
        ready = ready => ready.ok_or(RunnerError::PreconfIngressNotEnabled),
        result = event_syncer_handle => {
            match result {
                Ok(Ok(())) => Err(RunnerError::EventSyncerExited),
                Ok(Err(err)) => Err(RunnerError::Sync(err)),
                Err(err) => Err(RunnerError::EventSyncerFailed(err.to_string())),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::resolve_preconf_tip_from_l2;
    use alloy_consensus::Header as ConsensusHeader;
    use alloy_primitives::U256;
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types_eth::{Block, Header as RpcHeader};
    use alloy_transport::mock::Asserter;

    #[tokio::test]
    async fn preconf_tip_from_l2_uses_latest_head() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        let mut header = ConsensusHeader::default();
        header.number = 42;
        let block: Block = Block::empty(RpcHeader::new(header));
        asserter.push_success(&Some(block));

        let tip = resolve_preconf_tip_from_l2(&provider).await.unwrap();
        assert_eq!(tip, U256::from(42u64));
        assert!(asserter.read_q().is_empty());
    }

    #[tokio::test]
    async fn preconf_tip_from_l2_errors_on_rpc_failure() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        asserter.push_failure_msg("boom");

        let err = resolve_preconf_tip_from_l2(&provider).await.unwrap_err();
        assert!(err.to_string().contains("L2 latest head"));
    }

    #[tokio::test]
    async fn preconf_tip_from_l2_errors_on_missing_latest_block() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter.clone());
        let block: Option<Block> = None;
        asserter.push_success(&block);

        let err = resolve_preconf_tip_from_l2(&provider).await.unwrap_err();
        assert!(err.to_string().contains("L2 latest head"));
    }
}
