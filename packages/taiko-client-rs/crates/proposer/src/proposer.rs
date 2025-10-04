use alethia_reth::consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy::{
    eips::BlockNumberOrTag, primitives::U256, providers::Provider, rpc::types::Transaction,
};
use alloy_network::TransactionBuilder;
use anyhow::{Result, anyhow};
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig};
use protocol::shasta::constants::{MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES};
use rpc::client::{Client, ClientConfig, ClientWithWallet};
use tokio::time::interval;
use tracing::{error, info};

use crate::{config::ProposerConfigs, transaction_builder::ShastaProposalTransactionBuilder};

// Proposer keep proposing new transactions from L2 execution engine's tx pool at a fixed interval.
pub struct Proposer {
    rpc_provider: ClientWithWallet,
    transaction_builder: ShastaProposalTransactionBuilder,
    cfg: ProposerConfigs,
}

impl Proposer {
    /// Creates a new proposer instance.
    pub async fn new(cfg: ProposerConfigs) -> Result<Self> {
        info!("Initializing proposer with config: {:?}", cfg);

        // Initialize RPC client.
        let rpc_provider = Client::new_with_wallet(
            ClientConfig {
                l1_provider_source: cfg.l1_provider_source.clone(),
                l2_provider_source: cfg.l2_provider_source.clone(),
                l2_auth_provider_url: cfg.l2_auth_provider_url.clone(),
                jwt_secret: cfg.jwt_secret.clone(),
                inbox_address: cfg.inbox_address,
            },
            cfg.l1_proposer_private_key,
        )
        .await?;

        // Initialize event indexer.
        let indexer = ShastaEventIndexer::new(ShastaEventIndexerConfig {
            l1_subscription_source: cfg.l1_provider_source.clone(),
            inbox_address: cfg.inbox_address,
        })
        .await?;
        indexer.clone().spawn();
        indexer.wait_historical_indexing_finished().await;

        let l2_suggested_fee_recipient = cfg.l2_suggested_fee_recipient;

        Ok(Self {
            rpc_provider: rpc_provider.clone(),
            cfg,
            transaction_builder: ShastaProposalTransactionBuilder::new(
                rpc_provider,
                indexer,
                l2_suggested_fee_recipient,
            ),
        })
    }

    /// Start the proposer main loop.
    pub async fn start(&self) -> Result<()> {
        info!("Starting proposer");
        let mut interval = interval(self.cfg.propose_interval);
        let mut epoch = 0;

        loop {
            interval.tick().await;
            info!("Proposer epoch {}", epoch);

            self.fetch_and_propose().await?;

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    async fn fetch_and_propose(&self) -> Result<()> {
        // Fetch mempool content from L2 execution engine.
        let pool_content = self.fetch_pool_content().await?;

        info!("Fetched tx pool content, length: {:#?}", pool_content.len());

        let mut transaction_request = self
            .transaction_builder
            .build(pool_content)
            .await?
            .with_to(self.cfg.inbox_address);

        // Set gas limit if configured, otherwise let the provider estimate it.
        if let Some(gas_limit) = self.cfg.gas_limit {
            transaction_request = transaction_request.with_gas_limit(gas_limit);
        }

        // Send transaction using provider with wallet filler.
        // The wallet filler will automatically fill nonce, gas_limit, fees, and sign the transaction.
        let pending_tx =
            self.rpc_provider.l1_provider.send_transaction(transaction_request).await?;

        info!("Propose transaction sent: {}", pending_tx.tx_hash());
        let receipt = pending_tx.get_receipt().await?;

        if receipt.status() {
            info!("Propose transaction mined: {}", receipt.transaction_hash);
        } else {
            error!("Propose transaction failed: {}", receipt.transaction_hash);
        }

        Ok(())
    }

    /// Fetch transaction pool content from the L2 execution engine.
    async fn fetch_pool_content(&self) -> Result<Vec<Transaction>> {
        let base_fee_u64 = u64::try_from(self.calculate_next_block_base_fee().await?)
            .map_err(|_| anyhow!("base fee exceeds u64"))?;

        let pool_content = self
            .rpc_provider
            .tx_pool_content_with_min_tip(
                self.cfg.l2_suggested_fee_recipient,
                Some(base_fee_u64),
                MIN_BLOCK_GAS_LIMIT,
                PROPOSAL_MAX_BLOB_BYTES as u64,
                vec![],
                1,
                0,
            )
            .await?;

        info!("Fetched {} tx lists from L2 execution engine", pool_content.len());

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
    use std::borrow::Cow;
    use std::{env, path::PathBuf, str::FromStr, sync::OnceLock, time::Duration};

    use super::*;
    use alloy::{
        primitives::{Address, B256, aliases::U48},
        rpc::client::NoParams,
        transports::http::reqwest::Url,
    };
    use rpc::SubscriptionSource;

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
            l1_provider_source: SubscriptionSource::Ws(
                Url::from_str(&env::var("L1_WS").unwrap()).unwrap(),
            ),
            l2_provider_source: SubscriptionSource::Ws(
                Url::from_str(&env::var("L2_WS").unwrap()).unwrap(),
            ),
            l2_auth_provider_url: Url::from_str(&env::var("L2_AUTH").unwrap()).unwrap(),
            jwt_secret: PathBuf::from_str(&env::var("JWT_SECRET").unwrap()).unwrap(),
            inbox_address: Address::from_str(&env::var("SHASTA_INBOX").unwrap()).unwrap(),
            l2_suggested_fee_recipient: Address::from_str(
                &env::var("L2_SUGGESTED_FEE_RECIPIENT").unwrap(),
            )
            .unwrap(),
            propose_interval: Duration::from_secs(0),
            l1_proposer_private_key: env::var("L1_PROPOSER_PRIVATE_KEY").unwrap().parse().unwrap(),
            gas_limit: None,
        };

        let proposer = Proposer::new(cfg.clone()).await.unwrap();
        let provider = proposer.rpc_provider.clone();

        for i in 0..3 {
            assert_eq!(B256::ZERO, get_proposal_hash(provider.clone(), U48::from(i + 1)).await);

            evm_mine(provider.clone()).await;
            proposer.fetch_and_propose().await.unwrap();

            assert_ne!(B256::ZERO, get_proposal_hash(provider.clone(), U48::from(i + 1)).await);
        }
    }

    async fn evm_mine(client: ClientWithWallet) {
        client
            .l1_provider
            .raw_request::<_, String>(Cow::Borrowed("evm_mine"), NoParams::default())
            .await
            .unwrap();
    }

    async fn get_proposal_hash(client: ClientWithWallet, proposal_id: U48) -> B256 {
        client.shasta.inbox.getProposalHash(proposal_id).call().await.unwrap()
    }
}
