use std::{
    borrow::Cow,
    env, fmt,
    path::PathBuf,
    str::FromStr,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy::{
    eips::BlockNumberOrTag, rpc::client::NoParams, sol_types::SolCall,
    transports::http::reqwest::Url as RpcUrl,
};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::{
    Provider, ProviderBuilder, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use anyhow::{Context, Result};
use bindings::anchor::Anchor::anchorV4Call;
use event_indexer::indexer::{ProposedEventPayload, ShastaEventIndexer, ShastaEventIndexerConfig};
use proposer::{config::ProposerConfigs, proposer::Proposer};
use rpc::{
    SubscriptionSource,
    client::{Client, ClientConfig},
    error::RpcClientError,
};
use tokio::{runtime::Builder, time::timeout};
use tracing::warn;

type RpcClient = Client<FillProvider<JoinedRecommendedFillers, RootProvider>>;

const PRECONF_OPERATOR_ACTIVATION_BLOCKS: usize = 64;
const L1_BLOCK_TIME_SECONDS: u64 = 12;

/// Owns a per-test L1 snapshot and reverts it on drop.
#[derive(Clone)]
struct SnapshotGuard {
    cleanup_provider: RootProvider,
    snapshot_id: String,
}

impl SnapshotGuard {
    /// Take a fresh L1 snapshot after resetting the head so each test starts clean.
    async fn new(client: RpcClient, cleanup_provider: RootProvider) -> Result<Self> {
        reset_head_l1_origin(&client).await?;
        let snapshot_id = create_snapshot("setup", &cleanup_provider).await?;
        Ok(Self { cleanup_provider, snapshot_id })
    }
}

impl Drop for SnapshotGuard {
    /// Revert the L1 snapshot on drop.
    fn drop(&mut self) {
        let cleanup_provider = self.cleanup_provider.clone();
        let snapshot_id = self.snapshot_id.clone();

        // Use a dedicated runtime to avoid issues with dropping inside async contexts.
        match Builder::new_current_thread().enable_all().build() {
            Ok(runtime) => runtime.block_on(revert_snapshot(&cleanup_provider, &snapshot_id)).unwrap(),
            Err(err) => warn!(error = %err, "failed to build runtime for snapshot revert"),
        };
    }
}

/// Advances L1 time and mines blocks to ensure the preconfigured operator whitelist is active.
async fn ensure_preconf_whitelist_active(client: &RpcClient) -> Result<()> {
    for _ in 0..PRECONF_OPERATOR_ACTIVATION_BLOCKS {
        increase_l1_time(client, L1_BLOCK_TIME_SECONDS).await?;
        mine_l1_block(client).await?;
    }
    Ok(())
}

/// Checks if the RPC error indicates a "not found" condition.
fn is_not_found_error(err: &RpcClientError) -> bool {
    matches!(err, RpcClientError::Rpc(message) if message.contains("not found"))
}

/// Reset the authenticated L1 RPC head.
async fn reset_head_l1_origin(client: &RpcClient) -> Result<()> {
    match client.set_head_l1_origin(U256::from(1u64)).await {
        Ok(_) => Ok(()),
        Err(err) if is_not_found_error(&err) => Ok(()),
        Err(err) => Err(err.into()),
    }
}

/// Revert the L1 snapshot with retries.
async fn revert_snapshot(provider: &RootProvider, snapshot_id: &str) -> Result<()> {
    provider
        .raw_request::<_, bool>(Cow::Borrowed("evm_revert"), (&snapshot_id,))
        .await
        .context("reverting L1 snapshot")?;
    Ok(())
}

/// Create a new L1 snapshot to reuse across a single test run.
async fn create_snapshot(phase: &'static str, provider: &RootProvider) -> Result<String> {
    provider
        .raw_request::<_, String>(Cow::Borrowed("evm_snapshot"), NoParams::default())
        .await
        .with_context(|| format!("creating L1 snapshot during {phase}"))
}

/// Environment configuration required to exercise Shasta fork integration tests against
/// the Docker harness started by `tests/entrypoint.sh`.
/// Holds resolved endpoints, credentials, and clients needed to drive Shasta integration flows.
#[derive(Clone)]
pub struct ShastaEnv {
    pub l1_source: SubscriptionSource,
    pub l2_http: RpcUrl,
    pub l2_auth: RpcUrl,
    pub jwt_secret: PathBuf,
    pub inbox_address: Address,
    pub l2_suggested_fee_recipient: Address,
    pub l1_proposer_private_key: B256,
    pub taiko_anchor_address: Address,
    pub client_config: ClientConfig,
    pub client: Client<FillProvider<JoinedRecommendedFillers, RootProvider>>,
    pub event_indexer: Arc<ShastaEventIndexer>,
    pub proposer: Arc<Proposer>,
    _cleanup: SnapshotGuard,
}

impl fmt::Debug for ShastaEnv {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ShastaEnv")
            .field("l1_source", &self.l1_source)
            .field("l2_http", &self.l2_http)
            .field("l2_auth", &self.l2_auth)
            .field("jwt_secret", &self.jwt_secret)
            .field("inbox_address", &self.inbox_address)
            .field("l2_suggested_fee_recipient", &self.l2_suggested_fee_recipient)
            .field("l1_proposer_private_key", &self.l1_proposer_private_key)
            .field("taiko_anchor_address", &self.taiko_anchor_address)
            .field("client_config", &self.client_config)
            .field("client", &self.client)
            .field("event_indexer", &"ShastaEventIndexer")
            .field("proposer", &"Proposer")
            .finish()
    }
}

/// Ensures the latest L2 block contains an Anchor `anchorV4` call.
pub async fn verify_anchor_block<P>(client: &Client<P>, anchor_address: Address) -> Result<()>
where
    P: alloy_provider::Provider + Clone + Send + Sync + 'static,
{
    let latest_block: RpcBlock<TxEnvelope> = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .full()
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest block missing"))?
        .map_transactions(|tx: RpcTransaction| tx.into());

    let first_tx = latest_block
        .transactions
        .as_transactions()
        .and_then(|txs| txs.first())
        .ok_or_else(|| anyhow::anyhow!("block missing anchor transaction"))?;

    let selectors = [anchorV4Call::SELECTOR];
    anyhow::ensure!(first_tx.input().len() >= 4, "anchor transaction input too short");
    anyhow::ensure!(
        selectors.iter().any(|sel| &first_tx.input()[..sel.len()] == sel.as_slice()),
        "first transaction is not calling an Anchor anchorV4 entrypoint"
    );
    anyhow::ensure!(
        first_tx.to() == Some(anchor_address),
        "anchor transaction target mismatch: expected {}, got {:?}",
        anchor_address,
        first_tx.to()
    );

    Ok(())
}

/// Waits until the indexer observes a proposal with an ID greater than `previous_id`.
pub async fn wait_for_new_proposal(
    indexer: Arc<ShastaEventIndexer>,
    previous_id: u64,
) -> Result<ProposedEventPayload> {
    let wait = async {
        loop {
            if let Some(payload) = indexer.get_last_proposal() {
                let proposal_id = payload.proposal.id.to::<u64>();
                if proposal_id > previous_id {
                    return payload;
                }
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    };

    timeout(Duration::from_secs(15), wait)
        .await
        .map_err(|_| anyhow::anyhow!("timed out waiting for proposal to be indexed"))
}

impl ShastaEnv {
    /// Resolves required environment variables and builds a default RPC client bundle.
    pub async fn load_from_env() -> Result<Self> {
        let started = Instant::now();
        // Read all required endpoints, secrets, and addresses from the harness environment.
        let l1_ws = env::var("L1_WS").context("L1_WS env var is required")?;
        let l1_http =
            env::var("L1_HTTP").context("L1_HTTP env var is required for cleanup snapshots")?;
        let l2_http = env::var("L2_HTTP").context("L2_HTTP env var is required")?;
        let l2_auth = env::var("L2_AUTH").context("L2_AUTH env var is required")?;
        let jwt_secret = env::var("JWT_SECRET").context("JWT_SECRET env var is required")?;
        let inbox = env::var("SHASTA_INBOX").context("SHASTA_INBOX env var is required")?;
        let fee_recipient = env::var("L2_SUGGESTED_FEE_RECIPIENT")
            .context("L2_SUGGESTED_FEE_RECIPIENT env var is required")?;
        let proposer_key = env::var("L1_PROPOSER_PRIVATE_KEY")
            .context("L1_PROPOSER_PRIVATE_KEY env var is required")?;
        let anchor = env::var("TAIKO_ANCHOR").context("TAIKO_ANCHOR env var is required")?;

        // Parse raw strings into URLs, paths, and addresses.
        let l1_source = SubscriptionSource::Ws(
            RpcUrl::parse(l1_ws.as_str()).context("invalid L1_WS endpoint")?,
        );
        let l1_http_url = RpcUrl::parse(l1_http.as_str()).context("invalid L1_HTTP endpoint")?;
        let l2_http_url = RpcUrl::parse(l2_http.as_str()).context("invalid L2_HTTP endpoint")?;
        let l2_auth_url = RpcUrl::parse(l2_auth.as_str()).context("invalid L2_AUTH endpoint")?;
        let jwt_secret_path = PathBuf::from(jwt_secret);
        let inbox_address = Address::from_str(inbox.as_str()).context("invalid SHASTA_INBOX")?;
        let l2_suggested_fee_recipient = Address::from_str(fee_recipient.as_str())
            .context("invalid L2_SUGGESTED_FEE_RECIPIENT")?;
        let l1_proposer_private_key =
            proposer_key.parse().context("invalid L1_PROPOSER_PRIVATE_KEY hex value")?;
        let taiko_anchor_address =
            Address::from_str(anchor.as_str()).context("invalid TAIKO_ANCHOR address")?;

        // Build shared RPC client bundle and a dedicated HTTP provider for snapshots.
        let client_config = ClientConfig {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http_url.clone(),
            l2_auth_provider_url: l2_auth_url.clone(),
            jwt_secret: jwt_secret_path.clone(),
            inbox_address,
        };
        let client = Client::new(client_config.clone()).await?;

        // Take a fresh snapshot and activate preconf whitelist before tests run.
        let cleanup = SnapshotGuard::new(
            client.clone(),
            ProviderBuilder::default().connect_http(l1_http_url.clone()),
        )
        .await?;
        ensure_preconf_whitelist_active(&client).await?;

        // Start the inbox event indexer and wait for historical sync.
        let indexer_config = ShastaEventIndexerConfig {
            l1_subscription_source: l1_source.clone(),
            inbox_address,
            use_local_codec_decoder: true,
        };
        let event_indexer = ShastaEventIndexer::new(indexer_config).await?;
        event_indexer.clone().spawn();
        event_indexer.wait_historical_indexing_finished().await;

        // Build the proposer wired to the shared indexer and local codec.
        let proposer_config = ProposerConfigs {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http_url.clone(),
            l2_auth_provider_url: l2_auth_url.clone(),
            jwt_secret: jwt_secret_path.clone(),
            inbox_address,
            use_local_shasta_codec: true,
            l2_suggested_fee_recipient,
            propose_interval: Duration::from_secs(0),
            l1_proposer_private_key,
            gas_limit: None,
        };
        let proposer =
            Arc::new(Proposer::new_with_indexer(proposer_config, event_indexer.clone()).await?);

        tracing::info!(elapsed_ms = started.elapsed().as_millis(), "loaded ShastaEnv");
        Ok(Self {
            l1_source,
            l2_http: l2_http_url,
            l2_auth: l2_auth_url,
            jwt_secret: jwt_secret_path,
            inbox_address,
            l2_suggested_fee_recipient,
            l1_proposer_private_key,
            taiko_anchor_address,
            client_config,
            client,
            event_indexer,
            proposer,
            _cleanup: cleanup,
        })
    }
}

/// Mines a single empty L1 block via the connected execution engine.
pub async fn mine_l1_block<P>(client: &Client<P>) -> Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    client
        .l1_provider
        .raw_request::<_, String>(Cow::Borrowed("evm_mine"), NoParams::default())
        .await
        .context("mining L1 block")?;
    Ok(())
}

/// Increases L1 time by the specified number of seconds.
async fn increase_l1_time(client: &RpcClient, seconds: u64) -> Result<()> {
    client
        .l1_provider
        .raw_request::<_, i64>(Cow::Borrowed("evm_increaseTime"), (seconds,))
        .await
        .context("increasing L1 time via evm_increaseTime")?;
    Ok(())
}
