use std::{
    collections::HashMap,
    time::{Duration, SystemTime},
};

use anyhow::{anyhow, Context, Result};
use async_trait::async_trait;
use reqwest::Client;
use serde::de::DeserializeOwned;
use serde::Deserialize;
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

/// JSON-RPC backed implementation of the [`EthereumClient`] trait.
#[derive(Clone, Debug)]
pub struct RpcEthereumClient {
    http: Client,
    rpc_url: String,
}

impl RpcEthereumClient {
    /// Constructs a client that targets the supplied RPC endpoint.
    pub fn new(rpc_url: impl Into<String>) -> Self {
        Self {
            http: Client::new(),
            rpc_url: rpc_url.into(),
        }
    }

    /// Issues a typed JSON-RPC request and deserialises the result.
    async fn rpc_call<T>(&self, method: &str, params: serde_json::Value) -> Result<T>
    where
        T: DeserializeOwned,
    {
        let payload = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params,
        });

        let response = self
            .http
            .post(&self.rpc_url)
            .json(&payload)
            .send()
            .await
            .with_context(|| format!("RPC request to {} failed", self.rpc_url))?;

        let status = response
            .error_for_status()
            .with_context(|| format!("RPC request to {} returned error status", self.rpc_url))?;

        let body: RpcResponse<T> = status
            .json()
            .await
            .with_context(|| "failed to decode RPC response body".to_string())?;

        if let Some(error) = body.error {
            return Err(anyhow!(
                "RPC error {} (method {}): {}",
                error.code,
                method,
                error.message
            ));
        }

        body.result
            .ok_or_else(|| anyhow!("missing result field in RPC response"))
    }
}

#[async_trait]
impl EthereumClient for RpcEthereumClient {
    /// Fetches the latest block metadata using `eth_getBlockByNumber`.
    async fn latest_block(&self) -> Result<BlockSnapshot> {
        let block: RpcBlock = self
            .rpc_call("eth_getBlockByNumber", serde_json::json!(["latest", false]))
            .await?;

        let number_hex = block
            .number
            .ok_or_else(|| anyhow!("block number missing from latest block response"))?;
        let number = hex_to_u64(&number_hex)
            .with_context(|| format!("invalid block number in response: {}", number_hex))?;

        let ts = hex_to_u64(&block.timestamp)
            .with_context(|| format!("invalid block timestamp: {}", block.timestamp))?;
        let timestamp = SystemTime::UNIX_EPOCH + Duration::from_secs(ts);

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

    /// Retrieves pending transactions via `txpool_content`.
    async fn pending_transactions(&self) -> Result<Vec<PendingTransaction>> {
        let content: TxpoolContent = self
            .rpc_call("txpool_content", serde_json::json!([]))
            .await?;

        let mut hashes = Vec::new();

        for entries in content.pending.values() {
            for tx in entries.values() {
                hashes.push(PendingTransaction {
                    hash: tx.hash.clone(),
                });
            }
        }

        debug!(
            target: "overseer::ethereum",
            pending = hashes.len(),
            "queried txpool content"
        );

        Ok(hashes)
    }
}

#[derive(Debug, Deserialize)]
struct RpcResponse<T> {
    result: Option<T>,
    error: Option<RpcError>,
}

#[derive(Debug, Deserialize)]
struct RpcError {
    code: i64,
    message: String,
}

#[derive(Debug, Deserialize)]
struct RpcBlock {
    number: Option<String>,
    timestamp: String,
    #[serde(default)]
    transactions: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct TxpoolContent {
    #[serde(default)]
    pending: HashMap<String, HashMap<String, TxpoolTx>>,
    #[allow(dead_code)]
    #[serde(default, rename = "queued")]
    _queued: HashMap<String, HashMap<String, TxpoolTx>>,
}

#[derive(Debug, Deserialize)]
struct TxpoolTx {
    hash: String,
}

/// Converts a hex-encoded quantity (e.g. `0x1a`) into a `u64`.
fn hex_to_u64(value: &str) -> Result<u64> {
    let digits = value.trim_start_matches("0x");
    if digits.is_empty() {
        return Ok(0);
    }
    u64::from_str_radix(digits, 16)
        .with_context(|| format!("failed to parse hex value '{}'", value))
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
