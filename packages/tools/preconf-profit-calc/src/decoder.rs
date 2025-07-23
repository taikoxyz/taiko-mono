//! Event decoding module for Taiko L1 events
//! 
//! This module provides structures and functions to decode the raw event data
//! from Taiko's smart contracts into strongly-typed Rust structures.

use anyhow::Result;
use ethereum_types::{H256, U256, Address};
use hex;
use serde::{Deserialize, Serialize};

/// Information about a proposed batch
/// 
/// This struct represents the core batch data including transaction hashes,
/// coinbase information, and anchor block references.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchInfo {
    /// Hash of all transactions in the batch
    pub txs_hash: H256,
    /// Coinbase address for the batch
    pub coinbase: Address,
    /// L1 block number where batch was proposed
    pub proposed_in: u64,
    /// Gas limit for the batch
    pub gas_limit: u32,
    /// ID of the last L2 block in the previous batch
    pub last_block_id: u64,
    /// Timestamp of the last L2 block
    pub last_block_timestamp: u64,
    /// L1 block ID used as anchor
    pub anchor_block_id: u64,
    /// L1 block hash used as anchor
    pub anchor_block_hash: H256,
    /// Number of blocks in this batch
    pub num_blocks: u64,
}

/// Metadata about a proposed batch
/// 
/// Additional information including the batch ID and timing data.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchMetadata {
    /// Hash of the batch info struct
    pub info_hash: H256,
    /// Address of the proposer
    pub proposer: Address,
    /// Unique identifier for this batch
    pub batch_id: u64,
    /// Timestamp when the batch was proposed
    pub proposed_at: u64,
}

/// Decoded data from a BatchProposed event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecodedBatchProposed {
    /// Core batch information
    pub info: BatchInfo,
    /// Batch metadata
    pub meta: BatchMetadata,
}

/// Decoded data from a BatchesProved event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecodedBatchesProved {
    /// Address of the verifier contract that accepted the proof
    pub verifier: Address,
    /// List of batch IDs that were proved
    pub batch_ids: Vec<u64>,
}

/// Decoded data from a BatchesVerified event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecodedBatchesVerified {
    /// ID of the verified batch
    pub batch_id: u64,
    /// Hash of the verified block
    pub block_hash: H256,
}

/// Decoded data from a StatsUpdated event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecodedStatsUpdated {
    /// Total number of batches
    pub num_batches: u64,
    /// ID of the last verified batch
    pub last_verified_batch_id: u64,
    /// Whether the protocol is paused
    pub paused: bool,
    /// Block number of last proposal
    pub last_proposed_in: u64,
    /// Timestamp when last unpaused
    pub last_unpaused_at: u64,
}

/// Decodes an Ethereum address from hex data at the specified offset
/// 
/// Addresses are 20 bytes but stored as 32-byte words in event data,
/// so we skip the first 12 bytes (24 hex chars) of padding.
/// 
/// # Arguments
/// * `data` - Hex string (with or without 0x prefix)
/// * `offset` - Byte offset in the data (as hex char offset)
/// 
/// # Returns
/// * `Result<Address>` - The decoded address or error
pub fn decode_address(data: &str, offset: usize) -> Result<Address> {
    let clean_data = data.trim_start_matches("0x");
    if clean_data.len() < offset + 40 {
        return Err(anyhow::anyhow!("Insufficient data for address"));
    }
    
    // Skip 24 chars (12 bytes) of padding, then take 40 chars (20 bytes) for address
    let address_hex = &clean_data[offset + 24..offset + 64];
    let address_bytes = hex::decode(address_hex)?;
    Ok(Address::from_slice(&address_bytes))
}

/// Decodes a U256 value from hex data at the specified offset
/// 
/// # Arguments
/// * `data` - Hex string (with or without 0x prefix)
/// * `offset` - Byte offset in the data (as hex char offset)
/// 
/// # Returns
/// * `Result<U256>` - The decoded 256-bit unsigned integer
pub fn decode_u256(data: &str, offset: usize) -> Result<U256> {
    let clean_data = data.trim_start_matches("0x");
    if clean_data.len() < offset + 64 {
        return Err(anyhow::anyhow!("Insufficient data for U256"));
    }
    
    let value_hex = &clean_data[offset..offset + 64];
    Ok(U256::from_str_radix(value_hex, 16)?)
}

/// Decodes a u64 value from hex data at the specified offset
/// 
/// Safely converts from U256 to u64, returning 0 on overflow.
/// 
/// # Arguments
/// * `data` - Hex string (with or without 0x prefix)
/// * `offset` - Byte offset in the data (as hex char offset)
/// 
/// # Returns
/// * `Result<u64>` - The decoded 64-bit unsigned integer
pub fn decode_u64(data: &str, offset: usize) -> Result<u64> {
    let value = decode_u256(data, offset)?;
    // Safely convert U256 to u64, return 0 if overflow
    if value > U256::from(u64::MAX) {
        Ok(0)
    } else {
        Ok(value.low_u64())
    }
}

/// Decodes a u32 value from hex data at the specified offset
/// 
/// Safely converts from U256 to u32, returning 0 on overflow.
/// 
/// # Arguments
/// * `data` - Hex string (with or without 0x prefix)
/// * `offset` - Byte offset in the data (as hex char offset)
/// 
/// # Returns
/// * `Result<u32>` - The decoded 32-bit unsigned integer
pub fn decode_u32(data: &str, offset: usize) -> Result<u32> {
    let value = decode_u256(data, offset)?;
    // Safely convert U256 to u32, return 0 if overflow
    if value > U256::from(u32::MAX) {
        Ok(0)
    } else {
        Ok(value.low_u32())
    }
}

/// Decodes a 256-bit hash from hex data at the specified offset
/// 
/// # Arguments
/// * `data` - Hex string (with or without 0x prefix)
/// * `offset` - Byte offset in the data (as hex char offset)
/// 
/// # Returns
/// * `Result<H256>` - The decoded hash
pub fn decode_h256(data: &str, offset: usize) -> Result<H256> {
    let clean_data = data.trim_start_matches("0x");
    if clean_data.len() < offset + 64 {
        return Err(anyhow::anyhow!("Insufficient data for H256"));
    }
    
    let hash_hex = &clean_data[offset..offset + 64];
    let hash_bytes = hex::decode(hash_hex)?;
    Ok(H256::from_slice(&hash_bytes))
}

/// Decodes a boolean value from hex data at the specified offset
/// 
/// In Solidity, booleans are stored as U256 where 0 = false, non-zero = true.
/// 
/// # Arguments
/// * `data` - Hex string (with or without 0x prefix)
/// * `offset` - Byte offset in the data (as hex char offset)
/// 
/// # Returns
/// * `Result<bool>` - The decoded boolean value
pub fn decode_bool(data: &str, offset: usize) -> Result<bool> {
    let value = decode_u256(data, offset)?;
    Ok(!value.is_zero())
}

/// Decodes a BatchProposed event
/// 
/// Note: This is a simplified decoder that extracts basic information.
/// Full ABI decoding would be needed to extract all nested struct fields.
/// 
/// # Arguments
/// * `data` - The event's data field
/// * `topics` - The event's indexed topics
/// * `timestamp` - The block timestamp when the event was emitted
/// 
/// # Returns
/// * `Result<DecodedBatchProposed>` - Decoded event data
pub fn decode_batch_proposed(data: &str, topics: &[String], timestamp: u64) -> Result<DecodedBatchProposed> {
    // The deployed contract seems to emit a simplified BatchProposed event
    // Topic[0]: Event signature
    // Topic[1]: Indexed proposer address
    // Data: Single value (possibly basefee adjustment or batch-related value)
    
    // Clean the data by removing 0x prefix if present
    let clean_data = data.trim_start_matches("0x");
    
    println!("DEBUG: BatchProposed event");
    println!("  Topics count: {}", topics.len());
    println!("  Data length: {} chars ({} bytes)", clean_data.len(), clean_data.len() / 2);
    
    // Extract proposer from topic[1] (indexed parameter)
    let proposer = if topics.len() > 1 {
        decode_address(&topics[1], 0)?
    } else {
        Address::zero()
    };
    
    // For now, we'll need to get batch information from other sources
    // The single data field might be related to basefee adjustment
    let data_value = if clean_data.len() >= 64 {
        decode_u256(clean_data, 0)?
    } else {
        U256::zero()
    };
    
    println!("DEBUG: Decoded values:");
    println!("  Proposer: {:?}", proposer);
    println!("  Data value: {:?}", data_value);
    
    // Since we can't extract batch_id and block info from this event alone,
    // we'll need to correlate with other events or use default values
    return Ok(DecodedBatchProposed {
        info: BatchInfo {
            txs_hash: H256::zero(),
            coinbase: Address::zero(),
            proposed_in: 0,
            gas_limit: 0,
            last_block_id: 0,
            last_block_timestamp: 0,
            anchor_block_id: 0,
            anchor_block_hash: H256::zero(),
            num_blocks: 0,
        },
        meta: BatchMetadata {
            info_hash: H256::zero(),
            proposer,
            batch_id: 0, // Would need to extract from other events
            proposed_at: timestamp,
        },
    })
}

/// Decodes a BatchesProved event
/// 
/// # Arguments
/// * `data` - The event's data field
/// * `topics` - The event's indexed topics
/// 
/// # Returns
/// * `Result<DecodedBatchesProved>` - Decoded event data
pub fn decode_batches_proved(data: &str, _topics: &[String]) -> Result<DecodedBatchesProved> {
    // BatchesProved has no indexed parameters - all data is in the data field
    // The data contains: verifier address, batch IDs array, and transitions array
    
    // Decode verifier address from data (offset 192 = 0xC0)
    let verifier = if data.len() > 448 { // Need at least 224 bytes
        decode_address(data, 384)? // 192 * 2 = 384 hex chars
    } else {
        Address::zero()
    };
    
    // Extract batch ID from data
    // The batch ID appears at offset 416 (0x1A0)
    let mut batch_ids = Vec::new();
    if data.len() > 864 { // Need at least 432 bytes
        if let Ok(batch_id) = decode_u64(data, 832) { // 416 * 2 = 832 hex chars
            if batch_id > 0 && batch_id < 10000000 { // Sanity check
                batch_ids.push(batch_id);
            }
        }
    }
    
    Ok(DecodedBatchesProved {
        verifier,
        batch_ids,
    })
}

/// Decodes a BatchesVerified event
/// 
/// This event has data in the data field, not indexed topics.
/// 
/// # Arguments
/// * `data` - The event's data field
/// * `topics` - The event's indexed topics
/// 
/// # Returns
/// * `Result<DecodedBatchesVerified>` - Decoded event data
pub fn decode_batches_verified(data: &str, _topics: &[String]) -> Result<DecodedBatchesVerified> {
    // BatchesVerified data contains:
    // - lastVerifiedBatchId at offset 0
    // - newLastVerifiedBatchId at offset 32
    // - blockHash is not included in this version
    
    // Get the new last verified batch ID (second field)
    let batch_id = if data.len() > 128 {
        decode_u64(data, 64)? // offset 32 * 2 = 64 hex chars
    } else {
        0
    };
    
    // For now, we don't have the block hash in this event structure
    let block_hash = H256::zero();
    
    Ok(DecodedBatchesVerified {
        batch_id,
        block_hash,
    })
}

/// Decodes a StatsUpdated event
/// 
/// This decodes the Stats2Updated variant which contains protocol statistics.
/// 
/// # Arguments
/// * `data` - The event's data field
/// * `_topics` - The event's indexed topics (unused)
/// 
/// # Returns
/// * `Result<DecodedStatsUpdated>` - Decoded event data
pub fn decode_stats_updated(data: &str, _topics: &[String]) -> Result<DecodedStatsUpdated> {
    // Stats2Updated event structure
    // Each field is a 32-byte word in the data
    let num_batches = decode_u64(data, 0)?;
    let last_verified_batch_id = decode_u64(data, 64)?;
    let paused = decode_bool(data, 128)?;
    let last_proposed_in = decode_u64(data, 192)?;
    let last_unpaused_at = decode_u64(data, 256)?;
    
    Ok(DecodedStatsUpdated {
        num_batches,
        last_verified_batch_id,
        paused,
        last_proposed_in,
        last_unpaused_at,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_address() {
        let data = "0x000000000000000000000000742d35cc6634c0532925a3b844bc9e7595ed1234";
        let addr = decode_address(data, 0).unwrap();
        assert_eq!(format!("{:?}", addr), "0x742d35cc6634c0532925a3b844bc9e7595ed1234");
    }

    #[test]
    fn test_decode_u64() {
        let data = "0x000000000000000000000000000000000000000000000000000000000000002a";
        let value = decode_u64(data, 0).unwrap();
        assert_eq!(value, 42);
    }
}