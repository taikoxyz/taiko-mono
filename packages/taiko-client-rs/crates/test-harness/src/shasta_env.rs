use std::{
    borrow::Cow,
    env, fmt,
    path::PathBuf,
    str::FromStr,
    sync::{Arc, Mutex},
    time::Duration,
};

use alloy::{
    eips::BlockNumberOrTag, rpc::client::NoParams, sol_types::SolCall,
    transports::http::reqwest::Url as RpcUrl,
};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use anyhow::{Context, Result, anyhow, ensure};
use bindings::taiko_anchor::TaikoAnchor::{anchorCall, updateStateCall};
use event_indexer::indexer::{ProposedEventPayload, ShastaEventIndexer, ShastaEventIndexerConfig};
use once_cell::sync::Lazy;
use proposer::{config::ProposerConfigs, proposer::Proposer};
use rpc::{
    SubscriptionSource,
    client::{Client, ClientConfig},
    error::RpcClientError,
};
use tokio::time::timeout;
use tracing::warn;

type RpcClient = Client<FillProvider<JoinedRecommendedFillers, RootProvider>>;

static SNAPSHOT_ID: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));
const CLEANUP_RPC_TIMEOUT: Duration = Duration::from_secs(5);

struct CleanupInner {
    client: RpcClient,
    snapshot_id: String,
}

impl CleanupInner {
    async fn initialize(client: RpcClient) -> Result<Arc<Self>> {
        if let Some(previous_snapshot) = {
            let mut guard = SNAPSHOT_ID.lock().expect("snapshot mutex poisoned");
            guard.take()
        } && let Err(error) = Self::revert_snapshot(&client, &previous_snapshot).await
        {
            warn!(error = %error, "failed to revert previous L1 snapshot during setup");
        }

        reset_head_l1_origin(&client).await;

        let snapshot_id = Self::create_snapshot(&client, "setup")
            .await
            .context("creating L1 snapshot during setup")?;

        Ok(Arc::new(Self { client, snapshot_id }))
    }

    async fn teardown(client: RpcClient, snapshot_id: String) -> Result<String> {
        Self::revert_snapshot(&client, &snapshot_id).await?;
        reset_head_l1_origin(&client).await;

        let snapshot_id = Self::create_snapshot(&client, "teardown")
            .await
            .context("creating L1 snapshot during teardown")?;

        Ok(snapshot_id)
    }

    async fn revert_snapshot(client: &RpcClient, snapshot_id: &str) -> Result<()> {
        let revert_call =
            client.l1_provider.raw_request(Cow::Borrowed("evm_revert"), (snapshot_id.to_string(),));
        let reverted: bool = match timeout(CLEANUP_RPC_TIMEOUT, revert_call).await {
            Ok(result) => result.context("reverting L1 snapshot")?,
            Err(_) => {
                return Err(anyhow!(
                    "timed out reverting L1 snapshot '{}' after {:?}",
                    snapshot_id,
                    CLEANUP_RPC_TIMEOUT
                ));
            }
        };
        ensure!(reverted, "evm_revert returned false");
        Ok(())
    }

    async fn create_snapshot(client: &RpcClient, phase: &'static str) -> Result<String> {
        let snapshot_call = client
            .l1_provider
            .raw_request::<_, String>(Cow::Borrowed("evm_snapshot"), NoParams::default());
        match timeout(CLEANUP_RPC_TIMEOUT, snapshot_call).await {
            Ok(result) => result.with_context(|| format!("creating L1 snapshot during {phase}")),
            Err(_) => Err(anyhow!(
                "timed out creating L1 snapshot during {phase} after {:?}",
                CLEANUP_RPC_TIMEOUT
            )),
        }
    }
}

impl Drop for CleanupInner {
    /// Revert to a fresh snapshot on drop, preserving the new snapshot ID for the next test.
    fn drop(&mut self) {
        let client = self.client.clone();
        let snapshot_id = self.snapshot_id.clone();
        let join_result = std::thread::spawn(move || {
            tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .map_err(|err| anyhow!(err))
                .and_then(|rt| {
                    rt.block_on(async { CleanupInner::teardown(client, snapshot_id).await })
                })
        })
        .join();

        let result = match join_result {
            Ok(res) => res,
            Err(err) => Err(anyhow!("cleanup task panicked: {err:?}")),
        };

        persist_snapshot_result(result);
    }
}

fn persist_snapshot_result(result: Result<String>) {
    match result {
        Ok(new_snapshot) => {
            let mut guard = SNAPSHOT_ID.lock().expect("snapshot mutex poisoned");
            *guard = Some(new_snapshot);
        }
        Err(error) => {
            warn!(error = %error, "failed to teardown Shasta test environment");
            let mut guard = SNAPSHOT_ID.lock().expect("snapshot mutex poisoned");
            *guard = None;
        }
    }
}

fn is_not_found_error(err: &RpcClientError) -> bool {
    matches!(err, RpcClientError::Rpc(message) if message.contains("not found"))
}

async fn reset_head_l1_origin(client: &RpcClient) {
    let call = client.set_head_l1_origin(U256::from(1u64));
    match timeout(CLEANUP_RPC_TIMEOUT, call).await {
        Ok(result) => {
            if let Err(err) = result &&
                !is_not_found_error(&err)
            {
                warn!(error = %err, "failed to reset head l1 origin");
            }
        }
        Err(_) => {
            warn!(
                timeout = ?CLEANUP_RPC_TIMEOUT,
                "timed out resetting head l1 origin via authenticated RPC"
            );
        }
    };
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
    _cleanup: Arc<CleanupInner>,
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

/// Ensures the latest L2 block contains a TaikoAnchor anchor call.
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

    let selectors = [anchorCall::SELECTOR, updateStateCall::SELECTOR];
    anyhow::ensure!(first_tx.input().len() >= 4, "anchor transaction input too short");
    anyhow::ensure!(
        selectors.iter().any(|sel| &first_tx.input()[..sel.len()] == sel.as_slice()),
        "first transaction is not calling a TaikoAnchor anchor/updateState entrypoint"
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
        let l1_ws = env::var("L1_WS").context("L1_WS env var is required")?;
        let l2_http = env::var("L2_HTTP").context("L2_HTTP env var is required")?;
        let l2_auth = env::var("L2_AUTH").context("L2_AUTH env var is required")?;
        let jwt_secret = env::var("JWT_SECRET").context("JWT_SECRET env var is required")?;
        let inbox = env::var("SHASTA_INBOX").context("SHASTA_INBOX env var is required")?;
        let fee_recipient = env::var("L2_SUGGESTED_FEE_RECIPIENT")
            .context("L2_SUGGESTED_FEE_RECIPIENT env var is required")?;
        let proposer_key = env::var("L1_PROPOSER_PRIVATE_KEY")
            .context("L1_PROPOSER_PRIVATE_KEY env var is required")?;
        let anchor = env::var("TAIKO_ANCHOR").context("TAIKO_ANCHOR env var is required")?;

        let l1_source = SubscriptionSource::Ws(
            RpcUrl::parse(l1_ws.as_str()).context("invalid L1_WS endpoint")?,
        );
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

        let client_config = ClientConfig {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http_url.clone(),
            l2_auth_provider_url: l2_auth_url.clone(),
            jwt_secret: jwt_secret_path.clone(),
            inbox_address,
        };
        let client = Client::new(client_config.clone()).await?;
        let cleanup = CleanupInner::initialize(client.clone()).await?;

        let indexer_config =
            ShastaEventIndexerConfig { l1_subscription_source: l1_source.clone(), inbox_address };
        let event_indexer = ShastaEventIndexer::new(indexer_config).await?;
        event_indexer.clone().spawn(BlockNumberOrTag::Earliest);
        event_indexer.wait_historical_indexing_finished().await;

        let proposer_config = ProposerConfigs {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http_url.clone(),
            l2_auth_provider_url: l2_auth_url.clone(),
            jwt_secret: jwt_secret_path.clone(),
            inbox_address,
            l2_suggested_fee_recipient,
            propose_interval: Duration::from_secs(0),
            l1_proposer_private_key,
            gas_limit: None,
        };
        let proposer =
            Arc::new(Proposer::new_with_indexer(proposer_config, event_indexer.clone()).await?);

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
