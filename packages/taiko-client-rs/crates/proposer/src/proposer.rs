use alethia_reth::consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy::{
    eips::BlockNumberOrTag, primitives::U256, providers::Provider, rpc::types::Transaction,
    signers::local::PrivateKeySigner,
};
use alloy_network::{Ethereum, EthereumWallet, NetworkWallet, TransactionBuilder};
use anyhow::{Result, anyhow};
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig};
use protocol::shasta::constants::{MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES};
use rpc::client::Client;
use tokio::time::interval;
use tracing::info;

use crate::{config::ProposerConfigs, transaction_builder::ShastaProposalTransactionBuilder};

// Proposer keep proposing new transactions from L2 execution engine's tx pool at a fixed interval.
pub struct Proposer {
    rpc_provider: Client,
    transaction_builder: ShastaProposalTransactionBuilder,
    wallet: EthereumWallet,
    cfg: ProposerConfigs,
}

impl Proposer {
    /// Creates a new proposer instance.
    pub async fn new(cfg: ProposerConfigs) -> Result<Self> {
        info!("Initializing proposer with config: {:?}", cfg);
        // Initialize RPC client.
        let rpc_provider = Client::new(rpc::client::ClientConfig {
            l1_provider: cfg.l1_provider.clone(),
            l2_provider: cfg.l2_provider.clone(),
            l2_auth_provider: cfg.l2_auth_provider.clone(),
            jwt_secret: cfg.jwt_secret.clone(),
            inbox_address: cfg.inbox_address,
        })
        .await?;

        // Initialize event indexer.
        let indexer = ShastaEventIndexer::new(ShastaEventIndexerConfig {
            l1_subscription_source: cfg.l1_provider.clone(),
            inbox_address: cfg.inbox_address,
        })
        .await?;
        // indexer.wait_historical_indexing_finished().await;

        let l2_suggested_fee_recipient = cfg.l2_suggested_fee_recipient;
        let signer = PrivateKeySigner::from_bytes(&cfg.l1_proposer_private_key)?;
        let wallet = EthereumWallet::new(signer);

        Ok(Self {
            rpc_provider: rpc_provider.clone(),
            cfg,
            wallet,
            transaction_builder: ShastaProposalTransactionBuilder::new(
                rpc_provider,
                indexer,
                l2_suggested_fee_recipient,
            ),
        })
    }

    /// Start the proposer main loop.
    pub async fn start(&self) -> Result<()> {
        tracing::info!("Starting proposer");
        let mut interval = interval(self.cfg.propose_interval);
        let mut epoch = 0;

        loop {
            interval.tick().await;
            tracing::info!("Proposer epoch {}", epoch);

            self.fetch_and_propose().await?;

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    async fn fetch_and_propose(&self) -> Result<()> {
        // Fetch mempool content from L2 execution engine.
        let pool_content = self.fetch_pool_content().await?;

        tracing::info!("Fetched tx pool content, length: {:#?}", pool_content.len());

        // If there are no transaction to propose, skip this epoch.
        if pool_content.is_empty() {
            tracing::info!("No transaction to propose");
            return Err(anyhow!("No transaction to propose"));
        }

        let transaction_request =
            self.transaction_builder.build(pool_content).await?.with_to(self.cfg.inbox_address);

        let pending_tx = self
            .rpc_provider
            .l1_provider
            .send_transaction(
                NetworkWallet::<Ethereum>::sign_request(&self.wallet, transaction_request)
                    .await?
                    .into(),
            )
            .await?;

        let receipt = pending_tx.get_receipt().await?;

        if receipt.status() {
            tracing::info!("Propose transaction mined: {}", receipt.transaction_hash);
        } else {
            tracing::warn!("Propose transaction not mined yet: {}", receipt.transaction_hash);
        }

        Ok(())
    }

    /// Fetch transaction pool content from the L2 execution engine.
    async fn fetch_pool_content(&self) -> Result<Vec<Transaction>> {
        let pool_content = self
            .rpc_provider
            .tx_pool_content_with_min_tip(
                self.cfg.l2_suggested_fee_recipient,
                Some(self.calculate_next_block_base_fee().await?),
                MIN_BLOCK_GAS_LIMIT,
                PROPOSAL_MAX_BLOB_BYTES as u64,
                vec![],
                1,
                0,
            )
            .await?;

        let transactions = pool_content
            .into_iter()
            .flat_map(|tx_list| tx_list.tx_list.into_iter())
            .map(|tx| serde_json::from_value::<Transaction>(tx).map_err(anyhow::Error::from))
            .collect::<Result<Vec<_>>>()?;

        Ok(transactions)
    }

    /// Calculate the base fee for the next L2 block using EIP-4396 rules.
    async fn calculate_next_block_base_fee(&self) -> Result<U256> {
        let parent = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(anyhow!("latest block not found"))?;

        if parent.number() <= 2 {
            return Ok(U256::from(SHASTA_INITIAL_BASE_FEE));
        }

        let parent_block_time = parent.header.timestamp
            - self
                .rpc_provider
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(parent.number() - 1))
                .await?
                .ok_or_else(|| anyhow!("parent block {} not found", parent.number() - 1))?
                .header
                .timestamp;

        Ok(U256::from(calculate_next_block_eip4396_base_fee(
            &parent.header.inner,
            parent_block_time,
        )))
    }
}

#[cfg(test)]
mod tests {
    use std::{env, path::PathBuf, str::FromStr, sync::OnceLock, time::Duration};

    use alloy::{primitives::Address, transports::http::reqwest::Url};
    use rpc::SubscriptionSource;
    use tracing::info;

    use super::*;

    fn init_tracing() {
        static INIT: OnceLock<()> = OnceLock::new();

        INIT.get_or_init(|| {
            let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("debug"));
            let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
        });
    }

    #[tokio::test]
    async fn propose_shasta_batches() {
        init_tracing();

        let cfg = ProposerConfigs {
            l1_provider: SubscriptionSource::Ws(
                Url::from_str(&env::var("L1_WS").unwrap()).unwrap(),
            ),
            l2_provider: SubscriptionSource::Ws(
                Url::from_str(&env::var("L2_WS").unwrap()).unwrap(),
            ),
            l2_auth_provider: Url::from_str(&env::var("L2_AUTH").unwrap()).unwrap(),
            jwt_secret: PathBuf::from_str(&env::var("JWT_SECRET").unwrap()).unwrap(),
            inbox_address: Address::from_str(&env::var("SHASTA_INBOX").unwrap()).unwrap(),
            l2_suggested_fee_recipient: Address::from_str(
                &env::var("L2_SUGGESTED_FEE_RECIPIENT").unwrap(),
            )
            .unwrap(),
            propose_interval: Duration::from_secs(0),
            l1_proposer_private_key: env::var("L1_PROPOSER_PRIVATE_KEY").unwrap().parse().unwrap(),
        };

        let proposer = Proposer::new(cfg).await.unwrap();
        proposer.fetch_and_propose().await.unwrap();
    }
}
