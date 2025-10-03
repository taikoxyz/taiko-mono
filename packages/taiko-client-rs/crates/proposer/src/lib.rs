use alethia_reth::consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy::{
    eips::BlockNumberOrTag, primitives::U256, providers::Provider, rpc::types::Transaction,
};
use anyhow::{Result, anyhow};
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig};
use rpc::{
    client::Client,
    constants::{MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES},
};
use tokio::time::interval;

use crate::config::ProposerConfigs;

pub mod config;

// Proposer keep proposing new transactions from L2 execution engine's tx pool at a fixed interval.
pub struct Proposer {
    rpc_provider: Client,
    event_indexer: ShastaEventIndexer,
    cfg: ProposerConfigs,
}

impl Proposer {
    /// Creates a new proposer instance.
    pub async fn new(cfg: ProposerConfigs) -> Result<Self> {
        // Initialize RPC client.
        let rpc_provider = Client::new(rpc::client::ClientConfig {
            l1_provider: cfg.l1_provider.clone(),
            l2_provider: cfg.l2_provider.clone(),
            inbox_address: cfg.inbox_address,
        })
        .await?;

        // Initialize event indexer.
        let indexer = ShastaEventIndexer::new(ShastaEventIndexerConfig {
            l1_subscription_source: cfg.l1_provider.clone(),
            inbox_address: cfg.inbox_address,
        })
        .await?;
        indexer.wait_historical_indexing_finished().await;

        Ok(Self { event_indexer: indexer, rpc_provider, cfg })
    }

    pub async fn start(&self) -> Result<()> {
        tracing::info!("Starting proposer");
        let mut interval = interval(self.cfg.propose_interval);
        let mut epoch = 0;

        loop {
            tracing::info!("Proposer epoch {}", epoch);
            interval.tick().await;

            // Fetch mempool content from L2 execution engine.
            let pool_content = self.fetch_pool_content().await?;

            tracing::info!("Fetched tx pool content, length: {:#?}", pool_content.len());

            // If there are no transaction to propose, skip this epoch.
            if pool_content.is_empty() {
                tracing::info!("No transaction to propose");
                continue;
            }

            epoch += 1;
        }
    }

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
