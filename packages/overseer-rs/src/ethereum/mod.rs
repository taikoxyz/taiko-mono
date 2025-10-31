use std::time::{Duration, SystemTime};

use alloy::network::{Ethereum, TransactionResponse};
use alloy::providers::ext::TxPoolApi;
use alloy::providers::{DynProvider, Provider, ProviderBuilder};
use alloy::rpc::types::BlockNumberOrTag;
use anyhow::{anyhow, Context, Result};
use async_trait::async_trait;
use reqwest::Url;
use tracing::debug;

use crate::types::{Observation, PendingTransaction};

/// Minimal snapshot of a block required for blacklist evaluations.
#[derive(Clone, Debug)]
pub struct BlockSnapshot {
    pub number: u64,
    pub timestamp: SystemTime,
    pub transaction_count: u64,
}

/// Client abstraction for querying Ethereum execution data.
#[async_trait]
pub trait EthereumClient: Send + Sync {
    /// Returns the most recent block snapshot from the execution layer.
    async fn latest_block(&self) -> Result<BlockSnapshot>;

    /// Returns the set of pending transactions currently in the mempool.
    async fn pending_transactions(&self) -> Result<Vec<PendingTransaction>>;
}

/// Alloy-backed implementation of the [`EthereumClient`] trait.
#[derive(Clone, Debug)]
pub struct RpcEthereumClient {
    provider: DynProvider<Ethereum>,
}

impl RpcEthereumClient {
    /// Constructs a client that targets the supplied RPC endpoint using an Alloy provider stack.
    pub fn new(rpc_url: &str) -> Result<Self> {
        let url =
            Url::parse(rpc_url).with_context(|| format!("invalid execution rpc url: {rpc_url}"))?;

        let provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_http(url)
            .erased();

        Ok(Self { provider })
    }
}

#[async_trait]
impl EthereumClient for RpcEthereumClient {
    /// Fetches the latest block metadata via `eth_getBlockByNumber`.
    async fn latest_block(&self) -> Result<BlockSnapshot> {
        let block = self
            .provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| anyhow!("latest block not available"))?;

        let number = block.header.inner.number;
        let timestamp = SystemTime::UNIX_EPOCH + Duration::from_secs(block.header.inner.timestamp);
        let transaction_count = block.transactions.len() as u64;

        debug!(
            target: "overseer::ethereum",
            block_number = number,
            transaction_count,
            "fetched latest block"
        );

        Ok(BlockSnapshot {
            number,
            timestamp,
            transaction_count,
        })
    }

    /// Retrieves pending transactions via the `txpool_content` namespace.
    async fn pending_transactions(&self) -> Result<Vec<PendingTransaction>> {
        let content = self.provider.txpool_content().await?;

        let hashes: Vec<PendingTransaction> = content
            .pending
            .values()
            .flat_map(|entries| entries.values())
            .map(|tx| PendingTransaction {
                hash: format!("{:#x}", tx.tx_hash()),
            })
            .collect();

        debug!(
            target: "overseer::ethereum",
            pending = hashes.len(),
            "queried txpool content"
        );

        Ok(hashes)
    }
}

/// Collects the chain data required by the monitor in a single RPC round trip.
pub async fn collect_observation(client: &dyn EthereumClient) -> Result<Observation> {
    let latest_block = client.latest_block().await?;
    let pending_transactions = client.pending_transactions().await?;
    let pending_transaction_count = pending_transactions.len() as u64;

    Ok(Observation {
        latest_block,
        pending_transaction_count,
        pending_transactions,
    })
}
