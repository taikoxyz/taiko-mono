//! Ethereum RPC client module
//! 
//! This module provides a simple JSON-RPC client for interacting with
//! Ethereum nodes. It uses hyper for HTTP transport and supports HTTPS.

use anyhow::Result;
use hyper::{Body, Client, Request};
use hyper_tls::HttpsConnector;
use serde_json::{json, Value};

use crate::types::{Block, Log, TransactionReceipt};

/// Ethereum JSON-RPC client
/// 
/// Provides methods for making standard Ethereum RPC calls like
/// getting blocks, logs, and transaction receipts.
pub struct RpcClient {
    /// HTTP client with HTTPS support
    client: Client<HttpsConnector<hyper::client::HttpConnector>>,
    /// The RPC endpoint URL
    rpc_url: String,
}

impl RpcClient {
    /// Creates a new RPC client
    /// 
    /// # Arguments
    /// * `rpc_url` - The Ethereum RPC endpoint URL (e.g., Infura, Alchemy)
    /// 
    /// # Returns
    /// * `Result<Self>` - The RPC client instance
    pub fn new(rpc_url: &str) -> Result<Self> {
        let https = HttpsConnector::new();
        let client = Client::builder()
            .build::<_, hyper::Body>(https);
        
        Ok(Self {
            client,
            rpc_url: rpc_url.to_string(),
        })
    }

    /// Makes a generic JSON-RPC call
    /// 
    /// This is the core method used by all other RPC methods.
    /// 
    /// # Arguments
    /// * `method` - The RPC method name (e.g., "eth_blockNumber")
    /// * `params` - The method parameters as a JSON value
    /// 
    /// # Returns
    /// * `Result<Value>` - The RPC result or error
    pub async fn rpc_call(&self, method: &str, params: Value) -> Result<Value> {
        // Build JSON-RPC 2.0 request
        let payload = json!({
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        });

        // Create HTTP request
        let req = Request::builder()
            .method("POST")
            .uri(&self.rpc_url)
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_string(&payload)?))?;

        // Send request and parse response
        let resp = self.client.request(req).await?;
        let body_bytes = hyper::body::to_bytes(resp).await?;
        let result: Value = serde_json::from_slice(&body_bytes)?;
        
        // Check for RPC errors
        if let Some(error) = result.get("error") {
            return Err(anyhow::anyhow!("RPC error: {:?}", error));
        }

        Ok(result["result"].clone())
    }

    /// Gets the client version string
    /// 
    /// # Returns
    /// * `Result<String>` - The client version (e.g., "Geth/v1.10.0")
    pub async fn eth_client_version(&self) -> Result<String> {
        let result = self.rpc_call("web3_clientVersion", json!([])).await?;
        Ok(result.as_str().unwrap_or("unknown").to_string())
    }

    /// Gets the current block number
    /// 
    /// # Returns
    /// * `Result<u64>` - The latest block number
    pub async fn eth_block_number(&self) -> Result<u64> {
        let result = self.rpc_call("eth_blockNumber", json!([])).await?;
        let hex_str = result.as_str().unwrap_or("0x0");
        Ok(u64::from_str_radix(&hex_str[2..], 16)?)
    }

    /// Gets the contract code at a specific block
    /// 
    /// Used to check if a contract exists at a given address and block.
    /// 
    /// # Arguments
    /// * `address` - The contract address
    /// * `block` - The block number
    /// 
    /// # Returns
    /// * `Result<String>` - The contract bytecode (or "0x" if no contract)
    pub async fn eth_get_code(&self, address: &str, block: u64) -> Result<String> {
        let block_hex = format!("0x{:x}", block);
        let result = self.rpc_call("eth_getCode", json!([address, block_hex])).await?;
        Ok(result.as_str().unwrap_or("0x").to_string())
    }

    /// Gets block information by block number
    /// 
    /// # Arguments
    /// * `block` - The block number
    /// 
    /// # Returns
    /// * `Result<Block>` - The block data including timestamp
    pub async fn eth_get_block(&self, block: u64) -> Result<Block> {
        let block_hex = format!("0x{:x}", block);
        // false means we don't need full transaction objects
        let result = self.rpc_call("eth_getBlockByNumber", json!([block_hex, false])).await?;
        Ok(serde_json::from_value(result)?)
    }

    /// Gets logs (events) from a range of blocks
    /// 
    /// # Arguments
    /// * `address` - The contract address to filter logs from
    /// * `from_block` - Starting block (inclusive)
    /// * `to_block` - Ending block (inclusive)
    /// 
    /// # Returns
    /// * `Result<Vec<Log>>` - Vector of matching logs
    pub async fn eth_get_logs(&self, address: &str, from_block: u64, to_block: u64) -> Result<Vec<Log>> {
        let filter = json!({
            "address": address,
            "fromBlock": format!("0x{:x}", from_block),
            "toBlock": format!("0x{:x}", to_block)
        });
        
        let result = self.rpc_call("eth_getLogs", json!([filter])).await?;
        Ok(serde_json::from_value(result)?)
    }
    
    /// Gets a transaction receipt
    /// 
    /// The receipt contains gas usage and other execution details.
    /// 
    /// # Arguments
    /// * `tx_hash` - The transaction hash
    /// 
    /// # Returns
    /// * `Result<TransactionReceipt>` - The transaction receipt
    pub async fn eth_get_transaction_receipt(&self, tx_hash: &str) -> Result<TransactionReceipt> {
        let result = self.rpc_call("eth_getTransactionReceipt", json!([tx_hash])).await?;
        Ok(serde_json::from_value(result)?)
    }
}