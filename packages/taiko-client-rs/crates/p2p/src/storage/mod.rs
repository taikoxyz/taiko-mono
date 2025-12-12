//! Storage abstractions for the P2P SDK.
//!
//! The SDK persists validated gossip so the sidecar can serve req/resp queries,
//! deduplicate inbound data, and answer head requests. A simple in-memory
//! backend is provided for now.

use std::{
    collections::{HashMap, VecDeque},
    num::NonZeroUsize,
    time::{Duration, Instant},
};

use alloy_primitives::{B256, U256};
use lru::LruCache;
use parking_lot::RwLock;
use preconfirmation_service::PreconfStorage;
use preconfirmation_types::{Bytes32, PreconfHead, RawTxListGossip, SignedCommitment};

use crate::{error::Result, metrics::record_cache, types::MessageId};

/// Abstraction over commitment and raw-txlist storage used by the SDK.
/// Storage abstraction for commitments and raw tx lists.
pub trait SdkStorage: Send + Sync {
    /// Persist a commitment keyed by its SSZ hash.
    fn store_commitment(&self, hash: Bytes32, commitment: SignedCommitment) -> Result<()>;
    /// Retrieve a commitment by hash if present.
    fn get_commitment(&self, hash: &Bytes32) -> Option<SignedCommitment>;
    /// Persist a raw txlist blob keyed by its content hash.
    fn store_raw_txlist(&self, hash: Bytes32, tx: RawTxListGossip) -> Result<()>;
    /// Retrieve a raw txlist by hash if present.
    fn get_raw_txlist(&self, hash: &Bytes32) -> Option<RawTxListGossip>;
    /// Update the locally served head for answering inbound `get_head`.
    fn set_head(&self, head: PreconfHead) -> Result<()>;
    /// Return the last stored head, if any.
    fn head(&self) -> Option<PreconfHead>;
    /// Record a message id and return true if it was not seen recently.
    fn record_message_id(&self, id: MessageId, now: Instant, ttl: Duration) -> bool;
    /// Downcast hook enabling tests to access concrete implementations.
    fn as_any(&self) -> &dyn std::any::Any;
}

/// Convert an SSZ `Bytes32` value into a fixed-size key suitable for `HashMap`.
fn to_key(hash: &Bytes32) -> [u8; 32] {
    let mut out = [0u8; 32];
    out.copy_from_slice(hash.as_ref());
    out
}

/// Simple in-memory storage suitable for development, tests, and defaults.
pub struct InMemoryStorage {
    /// Stored commitments keyed by their hash.
    commitments: RwLock<LruCache<[u8; 32], SignedCommitment>>,
    /// Stored raw txlists keyed by their hash.
    txlists: RwLock<HashMap<[u8; 32], RawTxListGossip>>,
    /// Insertion order of txlists for FIFO eviction.
    txlist_order: RwLock<VecDeque<[u8; 32]>>,
    /// Approximate bytes currently held in txlist cache.
    txlist_bytes: RwLock<usize>,
    /// Byte cap for raw txlist cache.
    txlist_byte_cap: usize,
    /// Optional served head value.
    head: RwLock<Option<PreconfHead>>,
    /// Recently seen message ids for deduplication.
    message_ids: RwLock<LruCache<MessageId, Instant>>,
    /// Time-to-live for message id entries.
    message_ttl: Duration,
}

impl InMemoryStorage {
    /// Construct a new empty in-memory storage instance.
    pub fn new() -> Self {
        Self::with_caps_and_ids(1024, 16 * 1024 * 1024, 2048, Duration::from_secs(120))
    }

    /// Construct with explicit cache caps for commitments (count) and raw txlists (bytes).
    pub fn with_caps(commitment_cap: usize, txlist_byte_cap: usize) -> Self {
        Self::with_caps_and_ids(commitment_cap, txlist_byte_cap, 2048, Duration::from_secs(120))
    }

    /// Construct with explicit cache caps and message-id settings.
    pub fn with_caps_and_ids(
        commitment_cap: usize,
        txlist_byte_cap: usize,
        message_id_cap: usize,
        message_ttl: Duration,
    ) -> Self {
        Self {
            commitments: RwLock::new(LruCache::new(
                NonZeroUsize::new(commitment_cap.max(1)).unwrap(),
            )),
            txlists: RwLock::new(HashMap::new()),
            txlist_order: RwLock::new(VecDeque::new()),
            txlist_bytes: RwLock::new(0),
            txlist_byte_cap: txlist_byte_cap.max(1),
            head: RwLock::new(None),
            message_ids: RwLock::new(LruCache::new(
                NonZeroUsize::new(message_id_cap.max(1)).unwrap(),
            )),
            message_ttl: message_ttl.max(Duration::from_secs(1)),
        }
    }
}

impl Default for InMemoryStorage {
    /// Build an empty storage using default cache caps.
    fn default() -> Self {
        Self::new()
    }
}

impl SdkStorage for InMemoryStorage {
    /// Persist a commitment keyed by its SSZ hash.
    fn store_commitment(&self, hash: Bytes32, commitment: SignedCommitment) -> Result<()> {
        self.commitments.write().put(to_key(&hash), commitment);
        Ok(())
    }

    /// Retrieve a commitment if present in the cache.
    fn get_commitment(&self, hash: &Bytes32) -> Option<SignedCommitment> {
        let hit = self.commitments.read().peek(&to_key(hash)).cloned();
        record_cache("commitment", hit.is_some());
        hit
    }

    /// Persist a raw txlist keyed by its hash, evicting FIFO when over byte cap.
    fn store_raw_txlist(&self, hash: Bytes32, tx: RawTxListGossip) -> Result<()> {
        let key = to_key(&hash);
        let bytes = tx.txlist.len();

        let mut map = self.txlists.write();
        let mut order = self.txlist_order.write();
        let mut size = self.txlist_bytes.write();

        if let Some(old) = map.get(&key) {
            *size = size.saturating_sub(old.txlist.len());
        }

        map.insert(key, tx);
        order.push_back(key);
        *size += bytes;

        while *size > self.txlist_byte_cap {
            if let Some(evict) = order.pop_front() {
                if let Some(old) = map.remove(&evict) {
                    *size = size.saturating_sub(old.txlist.len());
                }
            } else {
                break;
            }
        }
        Ok(())
    }

    /// Retrieve a raw txlist by hash if present.
    fn get_raw_txlist(&self, hash: &Bytes32) -> Option<RawTxListGossip> {
        let hit = self.txlists.read().get(&to_key(hash)).cloned();
        record_cache("raw_txlist", hit.is_some());
        hit
    }

    /// Update the stored head served to inbound `get_head` requests.
    fn set_head(&self, head: PreconfHead) -> Result<()> {
        *self.head.write() = Some(head);
        Ok(())
    }

    /// Return the last stored head if available.
    fn head(&self) -> Option<PreconfHead> {
        self.head.read().clone()
    }

    /// Record a message id and return true if it was not seen recently.
    fn record_message_id(&self, id: MessageId, now: Instant, ttl: Duration) -> bool {
        let ttl = if ttl.is_zero() { self.message_ttl } else { ttl };
        let mut cache = self.message_ids.write();

        // prune expired entries
        let expired: Vec<MessageId> = cache
            .iter()
            .filter_map(|(k, t)| if now.duration_since(*t) > ttl { Some(*k) } else { None })
            .collect();
        for key in expired {
            cache.pop(&key);
        }

        if cache.contains(&id) {
            record_cache("message_id", true);
            false
        } else {
            record_cache("message_id", false);
            cache.put(id, now);
            true
        }
    }

    /// Downcast hook for tests to reach concrete storage internals.
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

impl PreconfStorage for InMemoryStorage {
    /// Insert a commitment keyed by block number for req/resp serving.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        let key = to_block_key(&block);
        self.commitments.write().put(key, commitment);
    }

    /// Insert a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        let mut key = [0u8; 32];
        key.copy_from_slice(hash.as_slice());
        self.txlists.write().insert(key, tx);
    }

    /// Return commitments from the requested start block up to `max` entries.
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        let start_key = to_block_key(&start);
        let mut values: Vec<(UintKey, SignedCommitment)> = self
            .commitments
            .read()
            .iter()
            .filter_map(|(_, commit)| {
                let height = to_block_key_from_commit(commit);
                if height >= start_key { Some((height, commit.clone())) } else { None }
            })
            .collect();
        values.sort_by(|a, b| a.0.cmp(&b.0));
        values.into_iter().take(max).map(|(_, c)| c).collect()
    }

    /// Fetch a raw txlist by its hash if present.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        let mut key = [0u8; 32];
        key.copy_from_slice(hash.as_slice());
        self.txlists.read().get(&key).cloned()
    }
}

/// Local key type used to order commitments by block number in memory.
type UintKey = [u8; 32];

/// Convert a U256 height into a sortable 32-byte little-endian key.
fn to_block_key(block: &U256) -> UintKey {
    let mut out = [0u8; 32];
    out.copy_from_slice(&block.to_le_bytes::<32>());
    out
}

/// Extract the block-number key from a signed commitment for ordering.
fn to_block_key_from_commit(commit: &SignedCommitment) -> UintKey {
    let bytes = commit.commitment.preconf.block_number.to_bytes_le();
    let mut out = [0u8; 32];
    out[..bytes.len().min(32)].copy_from_slice(&bytes[..bytes.len().min(32)]);
    out
}

pub mod memory;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{MessageId, Uint256};
    use preconfirmation_types::RawTxListGossip;
    use std::thread;

    #[test]
    /// Verify commitments and raw txlists round-trip through storage.
    fn stores_and_loads_commitment_and_txlist() {
        let store = InMemoryStorage::new();
        let hash = Bytes32::default();
        let commitment = SignedCommitment::default();
        let tx = RawTxListGossip::default();

        store.store_commitment(hash.clone(), commitment.clone()).unwrap();
        store.store_raw_txlist(hash.clone(), tx.clone()).unwrap();

        assert_eq!(store.get_commitment(&hash).unwrap(), commitment);
        assert_eq!(store.get_raw_txlist(&hash).unwrap(), tx);
    }

    #[test]
    /// Ensure ordered commitments are returned starting at a given block.
    fn preconf_storage_commitments_from_is_ordered() {
        let store = InMemoryStorage::new();
        // Insert three commitments with increasing blocks.
        for block in [1u64, 3, 2] {
            let mut c = SignedCommitment::default();
            c.commitment.preconf.block_number = Uint256::from(block);
            store.insert_commitment(U256::from(block), c);
        }

        let commits = store.commitments_from(U256::from(2u64), 10);
        let blocks: Vec<u64> =
            commits.iter().map(|c| u256_to_u64_local(&c.commitment.preconf.block_number)).collect();
        assert_eq!(blocks, vec![2, 3]);
    }

    #[test]
    /// Commitments cache should evict oldest entries when capacity is exceeded.
    fn commitments_cache_eviction_respects_cap() {
        let store = InMemoryStorage::with_caps_and_ids(2, 1024, 8, Duration::from_secs(10));
        for block in 0u64..3 {
            let mut c = SignedCommitment::default();
            c.commitment.preconf.block_number = Uint256::from(block);
            let hash = Bytes32::try_from(vec![block as u8; 32]).unwrap();
            store.store_commitment(hash, c).unwrap();
        }

        assert_eq!(store.commitments.read().len(), 2);
    }

    #[test]
    /// Raw txlist cache should evict FIFO to respect byte cap.
    fn raw_txlist_cache_eviction_by_bytes() {
        let store = InMemoryStorage::with_caps_and_ids(16, 10, 8, Duration::from_secs(10)); // tiny cap

        for i in 0u8..3 {
            let mut txlist = preconfirmation_types::TxListBytes::default();
            let _ = txlist.push(1);
            let hash = Bytes32::try_from(vec![i; 32]).unwrap();
            store
                .store_raw_txlist(
                    hash,
                    RawTxListGossip {
                        raw_tx_list_hash: Bytes32::try_from(vec![i; 32]).unwrap(),
                        txlist,
                    },
                )
                .unwrap();
        }

        assert!(*store.txlist_bytes.read() <= 10);
    }

    /// Convert Uint256 to u64 for test assertions, saturating on overflow.
    fn u256_to_u64_local(value: &Uint256) -> u64 {
        let bytes = value.to_bytes_le();
        let mut buf = [0u8; 8];
        let len = bytes.len().min(8);
        buf[..len].copy_from_slice(&bytes[..len]);
        if bytes.iter().skip(8).any(|&b| b != 0) { u64::MAX } else { u64::from_le_bytes(buf) }
    }

    #[test]
    /// Verify head value persists and can be read back.
    fn stores_and_reads_head() {
        let store = InMemoryStorage::new();
        let head = PreconfHead {
            block_number: Uint256::from(10u64),
            submission_window_end: Uint256::from(0u64),
        };
        store.set_head(head.clone()).unwrap();
        assert_eq!(store.head().unwrap(), head);
    }

    #[test]
    /// Message id cache records first-seen ids and rejects duplicates.
    fn message_id_dedupe() {
        let store = InMemoryStorage::with_caps_and_ids(16, 1024, 2, Duration::from_secs(30));
        let now = Instant::now();
        let id = MessageId::commitment([1u8; 32]);

        assert!(store.record_message_id(id, now, Duration::from_secs(30)));
        assert!(!store.record_message_id(
            id,
            now + Duration::from_secs(1),
            Duration::from_secs(30)
        ));
    }

    #[test]
    /// Expired message ids should be pruned allowing re-insertion.
    fn message_id_expires_after_ttl() {
        let store = InMemoryStorage::with_caps_and_ids(16, 1024, 2, Duration::from_millis(50));
        let start = Instant::now();
        let id = MessageId::raw_txlist([2u8; 32]);
        assert!(store.record_message_id(id, start, Duration::from_millis(50)));
        thread::sleep(Duration::from_millis(60));
        assert!(store.record_message_id(id, Instant::now(), Duration::from_millis(50)));
    }
}
