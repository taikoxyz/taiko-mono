//! Commitment storage and pending buffer implementation.
//!
//! This module provides:
//! - `CommitmentStore` trait for accessing stored commitments and txlists.
//! - `InMemoryCommitmentStore` for caching commitments in memory.
//! - `CommitmentsAwaitingTxList` for buffering commitments awaiting txlists.

use std::{
    collections::BTreeMap,
    sync::{
        RwLock,
        atomic::{AtomicUsize, Ordering},
    },
};

use alloy_primitives::{B256, U256};
use dashmap::DashMap;
use preconfirmation_net::PreconfStorage;
use preconfirmation_types::{
    Bytes32, PreconfHead, RawTxListGossip, SignedCommitment, uint256_to_u256,
};

use crate::config::DEFAULT_RETENTION_LIMIT;

/// Trait for accessing stored commitments and txlists.
pub trait CommitmentStore: Send + Sync {
    /// Store a commitment keyed by its block number.
    fn insert_commitment(&self, commitment: SignedCommitment);
    /// Fetch a commitment by block number.
    fn get_commitment(&self, block_number: &U256) -> Option<SignedCommitment>;
    /// Store a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, txlist: RawTxListGossip);
    /// Fetch a raw txlist by hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip>;
    /// Drop a pending commitment that failed validation.
    fn drop_pending_commitment(&self, block_number: &U256);
    /// Drop a pending txlist that failed validation.
    fn drop_pending_txlist(&self, hash: &B256);
    /// Buffer a commitment awaiting its txlist payload.
    fn add_awaiting_txlist(&self, txlist_hash: &Bytes32, commitment: SignedCommitment);
    /// Drain commitments waiting on the provided txlist hash.
    fn take_awaiting_txlist(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment>;
    /// Update the stored head snapshot.
    fn set_head(&self, head: PreconfHead);
    /// Fetch the stored head snapshot.
    fn head(&self) -> Option<PreconfHead>;
}

/// In-memory commitment store.
///
/// This store keeps commitments indexed by block number and raw txlists
/// indexed by their hash. It is shared with the P2P layer, but only validated
/// entries are exposed via the P2P storage interface.
pub struct InMemoryCommitmentStore {
    /// Commitments indexed by block number.
    commitments: RwLock<BTreeMap<U256, SignedCommitment>>,
    /// Raw txlists indexed by hash.
    txlists: DashMap<B256, RawTxListGossip>,
    /// Pending commitments inserted by the P2P layer before client validation.
    pending_commitments: DashMap<U256, SignedCommitment>,
    /// Pending txlists inserted by the P2P layer before client validation.
    pending_txlists: DashMap<B256, RawTxListGossip>,
    /// Commitments awaiting their txlist payload.
    awaiting_txlist: CommitmentsAwaitingTxList,
    /// Current head snapshot.
    head: RwLock<Option<PreconfHead>>,
    /// Maximum number of commitments/txlists to retain.
    retention_limit: usize,
}

impl InMemoryCommitmentStore {
    /// Create a new empty in-memory commitment store.
    pub fn new() -> Self {
        Self::with_retention_limit(DEFAULT_RETENTION_LIMIT)
    }

    /// Create a new in-memory store with a custom retention limit.
    pub fn with_retention_limit(retention_limit: usize) -> Self {
        Self {
            commitments: RwLock::new(BTreeMap::new()),
            txlists: DashMap::new(),
            pending_commitments: DashMap::new(),
            pending_txlists: DashMap::new(),
            awaiting_txlist: CommitmentsAwaitingTxList::with_retention_limit(retention_limit),
            head: RwLock::new(None),
            retention_limit,
        }
    }

    /// Extract the block number from a commitment.
    fn block_number(commitment: &SignedCommitment) -> U256 {
        // Convert the SSZ uint256 block number into an alloy U256.
        uint256_to_u256(&commitment.commitment.preconf.block_number)
    }

    /// Fetch a range of commitments starting at the provided block number.
    pub(crate) fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        // Prepare the output vector.
        let mut commitments = Vec::new();
        // Read the map for ordered iteration.
        let guard = match self.commitments.read() {
            Ok(guard) => guard,
            Err(_) => return commitments,
        };
        // Iterate over the requested range.
        for (_, commitment) in guard.range(start..) {
            // Stop when we reach the requested max.
            if commitments.len() >= max {
                break;
            }
            // Push a clone of the commitment.
            commitments.push(commitment.clone());
        }
        commitments
    }

    /// Prune the oldest commitments if the retention limit is exceeded.
    fn prune_commitments(&self, guard: &mut BTreeMap<U256, SignedCommitment>) {
        let excess = guard.len().saturating_sub(self.retention_limit);
        if excess == 0 {
            return;
        }

        let keys: Vec<U256> = guard.keys().take(excess).cloned().collect();
        for key in keys {
            if let Some(commitment) = guard.remove(&key) {
                let hash =
                    B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref());
                self.txlists.remove(&hash);
                self.pending_txlists.remove(&hash);
            }
            self.pending_commitments.remove(&key);
        }
    }

    /// Prune pending commitments to the retention limit.
    fn prune_pending_commitments(&self) {
        let excess = self.pending_commitments.len().saturating_sub(self.retention_limit);
        if excess == 0 {
            return;
        }

        let mut keys: Vec<U256> =
            self.pending_commitments.iter().map(|entry| *entry.key()).collect();
        keys.sort();
        for key in keys.into_iter().take(excess) {
            if let Some((_, commitment)) = self.pending_commitments.remove(&key) {
                let hash =
                    B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref());
                self.pending_txlists.remove(&hash);
            }
        }
    }

    /// Prune pending txlists to the retention limit.
    fn prune_pending_txlists(&self) {
        let excess = self.pending_txlists.len().saturating_sub(self.retention_limit);
        if excess == 0 {
            return;
        }

        let keys: Vec<B256> =
            self.pending_txlists.iter().take(excess).map(|entry| *entry.key()).collect();
        for key in keys {
            self.pending_txlists.remove(&key);
        }
    }

    /// Prune stored txlists to the retention limit, preferring to keep referenced hashes.
    fn prune_txlists(&self) {
        let excess = self.txlists.len().saturating_sub(self.retention_limit);
        if excess == 0 {
            return;
        }

        let referenced: std::collections::HashSet<B256> = match self.commitments.read() {
            Ok(guard) => guard
                .values()
                .map(|commitment| {
                    B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref())
                })
                .collect(),
            Err(_) => return,
        };

        let mut candidates = Vec::new();
        for entry in self.txlists.iter() {
            if !referenced.contains(entry.key()) {
                candidates.push(*entry.key());
            }
        }

        for key in candidates.into_iter().take(excess) {
            self.txlists.remove(&key);
        }
    }
}

impl Default for InMemoryCommitmentStore {
    /// Build a default in-memory store using the standard constructor.
    fn default() -> Self {
        Self::new()
    }
}

impl CommitmentStore for InMemoryCommitmentStore {
    /// Insert a commitment into the in-memory store.
    fn insert_commitment(&self, commitment: SignedCommitment) {
        // Extract the block number for indexing.
        let block_number = Self::block_number(&commitment);
        // Insert into the ordered map.
        if let Ok(mut guard) = self.commitments.write() {
            guard.insert(block_number, commitment.clone());
            self.prune_commitments(&mut guard);
        }
        // Drop any pending entry for this block now that it is accepted.
        self.pending_commitments.remove(&block_number);
        // Prune unreferenced txlists if needed.
        self.prune_txlists();
    }

    /// Fetch a commitment by block number from the in-memory store.
    fn get_commitment(&self, block_number: &U256) -> Option<SignedCommitment> {
        // Read the map for the requested block number.
        let guard = self.commitments.read().ok()?;
        guard.get(block_number).cloned()
    }

    /// Insert a raw txlist payload keyed by its hash.
    fn insert_txlist(&self, hash: B256, txlist: RawTxListGossip) {
        // Insert into the concurrent map.
        self.txlists.insert(hash, txlist);
        // Drop any pending entry for this hash now that it is accepted.
        self.pending_txlists.remove(&hash);
        // Prune unreferenced txlists if needed.
        self.prune_txlists();
    }

    /// Fetch a raw txlist payload by hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        // Fetch and clone the stored txlist.
        self.txlists.get(hash).map(|entry| entry.value().clone())
    }

    /// Drop a pending commitment for the provided block.
    fn drop_pending_commitment(&self, block_number: &U256) {
        self.pending_commitments.remove(block_number);
    }

    /// Drop a pending txlist for the provided hash.
    fn drop_pending_txlist(&self, hash: &B256) {
        self.pending_txlists.remove(hash);
    }

    /// Buffer a commitment awaiting its txlist payload.
    fn add_awaiting_txlist(&self, txlist_hash: &Bytes32, commitment: SignedCommitment) {
        self.awaiting_txlist.add(txlist_hash, commitment);
    }

    /// Drain commitments waiting on the provided txlist hash.
    fn take_awaiting_txlist(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment> {
        self.awaiting_txlist.take_waiting(txlist_hash)
    }

    /// Update the cached head snapshot.
    fn set_head(&self, head: PreconfHead) {
        // Write the new head snapshot.
        if let Ok(mut guard) = self.head.write() {
            *guard = Some(head);
        }
    }

    /// Fetch the cached head snapshot, if set.
    fn head(&self) -> Option<PreconfHead> {
        // Read and clone the head snapshot.
        let guard = self.head.read().ok()?;
        guard.clone()
    }
}

impl PreconfStorage for InMemoryCommitmentStore {
    /// Insert a commitment into the pending buffer.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        if let Ok(guard) = self.commitments.read() &&
            guard.contains_key(&block)
        {
            return;
        }
        self.pending_commitments.insert(block, commitment);
        self.prune_pending_commitments();
    }

    /// Insert a raw txlist into the pending buffer.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        if self.txlists.contains_key(&hash) {
            return;
        }
        self.pending_txlists.insert(hash, tx);
        self.prune_pending_txlists();
    }

    /// Fetch commitments starting from a block number.
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        InMemoryCommitmentStore::commitments_from(self, start, max)
    }

    /// Fetch a raw txlist by its hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        CommitmentStore::get_txlist(self, hash)
    }
}

/// Buffer for commitments awaiting their txlist payload.
///
/// When a commitment arrives but its txlist hasn't arrived yet, the commitment
/// is buffered here keyed by the txlist hash. Once the txlist arrives, the
/// commitments can be retrieved and processed.
pub(crate) struct CommitmentsAwaitingTxList {
    /// Map from txlist hash to commitments waiting for that txlist.
    by_txlist_hash: DashMap<B256, Vec<SignedCommitment>>,
    /// Count of commitments across all txlist hashes.
    count: AtomicUsize,
    /// Maximum number of commitments to retain.
    retention_limit: usize,
}

impl CommitmentsAwaitingTxList {
    /// Create a new empty buffer.
    pub fn new() -> Self {
        Self::with_retention_limit(DEFAULT_RETENTION_LIMIT)
    }

    /// Create a new buffer with a custom retention limit.
    pub fn with_retention_limit(retention_limit: usize) -> Self {
        Self { by_txlist_hash: DashMap::new(), count: AtomicUsize::new(0), retention_limit }
    }

    /// Add a commitment awaiting its txlist.
    ///
    /// If the buffer is at capacity, the commitment with the smallest block number
    /// is evicted to make room for the new one.
    pub fn add(&self, txlist_hash: &Bytes32, commitment: SignedCommitment) {
        // Evict oldest if at capacity.
        self.evict_if_needed();
        // Normalize the hash to B256.
        let key = B256::from_slice(txlist_hash.as_ref());
        // Push the commitment into the list.
        self.by_txlist_hash.entry(key).or_default().push(commitment);
        self.count.fetch_add(1, Ordering::SeqCst);
    }

    /// Remove and return all commitments waiting for the given txlist hash.
    pub fn take_waiting(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment> {
        // Normalize the hash to B256.
        let key = B256::from_slice(txlist_hash.as_ref());
        if let Some((_, value)) = self.by_txlist_hash.remove(&key) {
            self.count.fetch_sub(value.len(), Ordering::SeqCst);
            return value;
        }
        Vec::new()
    }

    /// Evict the commitment with the smallest block number if at capacity.
    fn evict_if_needed(&self) {
        let count = self.count.load(Ordering::SeqCst);
        if count < self.retention_limit {
            return;
        }

        // Find the commitment with the smallest block number.
        let mut min_block: Option<U256> = None;
        let mut min_key: Option<B256> = None;
        let mut min_idx: Option<usize> = None;

        for entry in self.by_txlist_hash.iter() {
            for (idx, commitment) in entry.value().iter().enumerate() {
                let block = uint256_to_u256(&commitment.commitment.preconf.block_number);
                if min_block.is_none() || block < min_block.unwrap() {
                    min_block = Some(block);
                    min_key = Some(*entry.key());
                    min_idx = Some(idx);
                }
            }
        }

        // Remove the oldest commitment.
        if let (Some(key), Some(idx)) = (min_key, min_idx) &&
            let Some(mut entry) = self.by_txlist_hash.get_mut(&key) &&
            idx < entry.len()
        {
            entry.remove(idx);
            self.count.fetch_sub(1, Ordering::SeqCst);
            // Remove the key if the vector is now empty.
            if entry.is_empty() {
                drop(entry);
                self.by_txlist_hash.remove(&key);
            }
        }
    }
}

impl Default for CommitmentsAwaitingTxList {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::InMemoryCommitmentStore;
    use crate::storage::commitment_store::CommitmentStore;
    use alloy_primitives::{B256, U256};
    use preconfirmation_net::PreconfStorage;
    use preconfirmation_types::{
        Bytes32, RawTxListGossip, SignedCommitment, TxListBytes, u256_to_uint256,
    };

    impl InMemoryCommitmentStore {
        /// Fetch the highest stored commitment, if any.
        pub(crate) fn latest_commitment(&self) -> Option<SignedCommitment> {
            let guard = self.commitments.read().ok()?;
            guard.iter().next_back().map(|(_, value)| value.clone())
        }

        /// Get the number of pending commitments.
        pub(crate) fn pending_commitments_len(&self) -> usize {
            self.pending_commitments.len()
        }

        /// Get the number of pending txlists.
        pub(crate) fn pending_txlists_len(&self) -> usize {
            self.pending_txlists.len()
        }
    }

    fn commitment_with_block(block: U256) -> SignedCommitment {
        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.block_number = u256_to_uint256(block);
        commitment
    }

    fn txlist_with_byte(byte: u8) -> RawTxListGossip {
        let raw_tx_list_hash = Bytes32::try_from(vec![byte; 32]).expect("32-byte hash");
        let txlist = TxListBytes::try_from(vec![byte; 3]).expect("txlist bytes");
        RawTxListGossip { raw_tx_list_hash, txlist }
    }

    fn commitment_with_block_and_hash(block: U256, hash: Bytes32) -> SignedCommitment {
        let mut commitment = SignedCommitment::default();
        commitment.commitment.preconf.block_number = u256_to_uint256(block);
        commitment.commitment.preconf.raw_tx_list_hash = hash;
        commitment
    }

    fn txlist_with_hash(hash: Bytes32) -> RawTxListGossip {
        let txlist = TxListBytes::try_from(vec![0xAB; 3]).expect("txlist bytes");
        RawTxListGossip { raw_tx_list_hash: hash, txlist }
    }

    #[test]
    fn commitments_awaiting_txlist_evicts_oldest() {
        let store = InMemoryCommitmentStore::with_retention_limit(3);

        // Add commitments with different block numbers.
        let txlist_hash = Bytes32::try_from(vec![1u8; 32]).expect("txlist hash");
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(10u64)));
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(5u64)));
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(15u64)));

        // Adding a 4th should evict the one with block 5 (smallest).
        store.add_awaiting_txlist(&txlist_hash, commitment_with_block(U256::from(20u64)));

        let waiting = store.take_awaiting_txlist(&txlist_hash);
        assert_eq!(waiting.len(), 3);

        // Verify block 5 was evicted (smallest block number).
        let blocks: Vec<u64> = waiting
            .iter()
            .map(|c| {
                let block =
                    preconfirmation_types::uint256_to_u256(&c.commitment.preconf.block_number);
                block.try_into().unwrap()
            })
            .collect();
        assert!(!blocks.contains(&5u64));
        assert!(blocks.contains(&10u64));
        assert!(blocks.contains(&15u64));
        assert!(blocks.contains(&20u64));
    }

    /// Ensure a new store has no latest commitment.
    #[test]
    fn store_roundtrip_commitment() {
        // Initialize a fresh store for assertions.
        let store = InMemoryCommitmentStore::new();
        assert!(store.latest_commitment().is_none());
    }

    #[test]
    fn pending_commitment_hidden_until_accepted() {
        let store = InMemoryCommitmentStore::new();
        let block = U256::from(7);
        let commitment = commitment_with_block(block);

        PreconfStorage::insert_commitment(&store, block, commitment.clone());

        assert!(store.latest_commitment().is_none());
        assert!(PreconfStorage::commitments_from(&store, block, 1).is_empty());

        CommitmentStore::insert_commitment(&store, commitment.clone());

        let commitments = PreconfStorage::commitments_from(&store, block, 1);
        assert_eq!(commitments, vec![commitment]);
    }

    #[test]
    fn pending_txlist_hidden_until_accepted() {
        let store = InMemoryCommitmentStore::new();
        let txlist = txlist_with_byte(0xAB);
        let hash = B256::from_slice(txlist.raw_tx_list_hash.as_ref());

        PreconfStorage::insert_txlist(&store, hash, txlist.clone());

        assert!(PreconfStorage::get_txlist(&store, &hash).is_none());

        CommitmentStore::insert_txlist(&store, hash, txlist.clone());

        assert_eq!(PreconfStorage::get_txlist(&store, &hash), Some(txlist));
    }

    #[test]
    fn retention_prunes_oldest_commitment_and_txlist() {
        let store = InMemoryCommitmentStore::with_retention_limit(2);
        let first_block = U256::from(1u64);
        let second_block = U256::from(2u64);
        let third_block = U256::from(3u64);

        let first_hash = Bytes32::try_from(vec![0x11; 32]).expect("hash");
        let second_hash = Bytes32::try_from(vec![0x22; 32]).expect("hash");
        let third_hash = Bytes32::try_from(vec![0x33; 32]).expect("hash");

        CommitmentStore::insert_commitment(
            &store,
            commitment_with_block_and_hash(first_block, first_hash.clone()),
        );
        CommitmentStore::insert_commitment(
            &store,
            commitment_with_block_and_hash(second_block, second_hash.clone()),
        );
        CommitmentStore::insert_commitment(
            &store,
            commitment_with_block_and_hash(third_block, third_hash.clone()),
        );

        CommitmentStore::insert_txlist(
            &store,
            B256::from_slice(first_hash.as_ref()),
            txlist_with_hash(first_hash.clone()),
        );
        CommitmentStore::insert_txlist(
            &store,
            B256::from_slice(second_hash.as_ref()),
            txlist_with_hash(second_hash.clone()),
        );
        CommitmentStore::insert_txlist(
            &store,
            B256::from_slice(third_hash.as_ref()),
            txlist_with_hash(third_hash.clone()),
        );

        assert!(CommitmentStore::get_commitment(&store, &first_block).is_none());
        assert!(
            CommitmentStore::get_txlist(&store, &B256::from_slice(first_hash.as_ref())).is_none()
        );
        assert!(CommitmentStore::get_commitment(&store, &second_block).is_some());
        assert!(CommitmentStore::get_commitment(&store, &third_block).is_some());
        assert!(
            CommitmentStore::get_txlist(&store, &B256::from_slice(second_hash.as_ref())).is_some()
        );
        assert!(
            CommitmentStore::get_txlist(&store, &B256::from_slice(third_hash.as_ref())).is_some()
        );
    }

    #[test]
    fn retention_prunes_pending_buffers() {
        let store = InMemoryCommitmentStore::with_retention_limit(1);
        let first_block = U256::from(10u64);
        let second_block = U256::from(11u64);
        let first_hash = Bytes32::try_from(vec![0x44; 32]).expect("hash");
        let second_hash = Bytes32::try_from(vec![0x55; 32]).expect("hash");

        PreconfStorage::insert_commitment(
            &store,
            first_block,
            commitment_with_block_and_hash(first_block, first_hash.clone()),
        );
        PreconfStorage::insert_commitment(
            &store,
            second_block,
            commitment_with_block_and_hash(second_block, second_hash.clone()),
        );

        PreconfStorage::insert_txlist(
            &store,
            B256::from_slice(first_hash.as_ref()),
            txlist_with_hash(first_hash.clone()),
        );
        PreconfStorage::insert_txlist(
            &store,
            B256::from_slice(second_hash.as_ref()),
            txlist_with_hash(second_hash.clone()),
        );

        assert!(store.pending_commitments_len() <= 1);
        assert!(store.pending_txlists_len() <= 1);
    }
}
