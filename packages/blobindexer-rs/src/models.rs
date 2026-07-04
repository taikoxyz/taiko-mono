use alloy_primitives::{Address, B256, FixedBytes};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlockRecord {
    pub slot: i64,
    pub block_root: B256,
    pub parent_root: B256,
    pub timestamp: Option<DateTime<Utc>>,
    pub canonical: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeaconBlockSummary {
    pub slot: u64,
    pub block_root: B256,
    pub parent_root: B256,
    pub timestamp: Option<DateTime<Utc>>,
    pub blob_commitments: Vec<FixedBytes<48>>,
    pub blob_targets: Vec<Option<Address>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlobRecord {
    pub slot: i64,
    pub block_root: B256,
    pub index: i32,
    pub versioned_hash: B256,
    pub commitment: FixedBytes<48>,
    pub proof: FixedBytes<48>,
    pub blob: Vec<u8>,
    pub canonical: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlobSidecar {
    pub slot: u64,
    pub block_root: B256,
    pub index: u64,
    pub commitment: FixedBytes<48>,
    pub proof: FixedBytes<48>,
    pub blob: Vec<u8>,
}
