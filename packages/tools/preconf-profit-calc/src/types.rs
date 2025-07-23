//! Common data types used throughout the application
//! 
//! This module defines the core data structures for events, logs,
//! blocks, and transaction receipts.

use serde::{Deserialize, Serialize};

/// Processed event data with additional context
/// 
/// This is our internal representation of an event after processing
/// raw log data and enriching it with timestamps and readable names.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    /// Human-readable event name (e.g., "BatchProposed")
    pub name: String,
    /// Block number where the event was emitted
    pub block_number: u64,
    /// Transaction hash that emitted this event
    pub transaction_hash: String,
    /// Log index within the transaction
    pub log_index: String,
    /// Event topics (indexed parameters)
    pub topics: Vec<String>,
    /// Non-indexed event data
    pub data: String,
    /// Unix timestamp of the block
    pub timestamp: u64,
}

/// Raw log data from Ethereum RPC
/// 
/// This matches the structure returned by eth_getLogs.
#[derive(Debug, Deserialize)]
pub struct Log {
    /// Contract address that emitted the log
    pub address: String,
    /// Indexed event parameters
    pub topics: Vec<String>,
    /// Non-indexed event data
    pub data: String,
    /// Block number (as hex string)
    #[serde(rename = "blockNumber")]
    pub block_number: Option<String>,
    /// Transaction hash
    #[serde(rename = "transactionHash")]
    pub transaction_hash: Option<String>,
    /// Log index within the block
    #[serde(rename = "logIndex")]
    pub log_index: Option<String>,
}

/// Block information from Ethereum RPC
/// 
/// Minimal block data - we mainly need the timestamp.
#[derive(Debug, Deserialize)]
pub struct Block {
    /// Block number (as hex string)
    pub number: Option<String>,
    /// Block timestamp (as hex string)
    pub timestamp: Option<String>,
}

/// Transaction receipt data
/// 
/// Contains gas usage information needed for cost calculations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionReceipt {
    /// Gas actually used by the transaction (as hex string)
    #[serde(rename = "gasUsed")]
    pub gas_used: Option<String>,
    /// Effective gas price paid (EIP-1559, as hex string)
    #[serde(rename = "effectiveGasPrice")]
    pub effective_gas_price: Option<String>,
    /// Transaction status ("0x1" for success, "0x0" for failure)
    pub status: Option<String>,
}