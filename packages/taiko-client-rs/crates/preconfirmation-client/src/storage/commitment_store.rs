//! Commitment storage and pending buffer implementation.
//!
//! This module provides:
//! - `CommitmentStore` trait for accessing stored commitments and txlists.
//! - `InMemoryCommitmentStore` for caching commitments in memory.
//! - `PendingCommitmentBuffer` for buffering out-of-order commitments.
//! - `PendingTxListBuffer` for buffering commitments awaiting txlists.

use std::{collections::BTreeMap, sync::RwLock};

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
    /// Fetch the latest stored commitment.
    fn latest_commitment(&self) -> Option<SignedCommitment>;
    /// Fetch the latest stored block number.
    fn latest_block_number(&self) -> Option<U256>;
    /// Return up to `max` commitments starting from `start` (inclusive).
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment>;
    /// Store a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, txlist: RawTxListGossip);
    /// Fetch a raw txlist by hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip>;
    /// Drop a pending commitment that failed validation.
    fn drop_pending_commitment(&self, block_number: &U256);
    /// Drop a pending txlist that failed validation.
    fn drop_pending_txlist(&self, hash: &B256);
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
            head: RwLock::new(None),
            retention_limit,
        }
    }

    /// Extract the block number from a commitment.
    fn block_number(commitment: &SignedCommitment) -> U256 {
        // Convert the SSZ uint256 block number into an alloy U256.
        uint256_to_u256(&commitment.commitment.preconf.block_number)
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
        // Update the head snapshot when this is the new tip.
        if let Ok(mut head_guard) = self.head.write() {
            // Compute the current head block number.
            let current_head = head_guard.as_ref().map(|head| uint256_to_u256(&head.block_number));
            // Update head if missing or smaller.
            if current_head.map(|current| block_number > current).unwrap_or(true) {
                // Build a new head snapshot from the commitment.
                let head = PreconfHead {
                    block_number: commitment.commitment.preconf.block_number.clone(),
                    submission_window_end: commitment
                        .commitment
                        .preconf
                        .submission_window_end
                        .clone(),
                };
                *head_guard = Some(head);
            }
        }
    }

    /// Fetch a commitment by block number from the in-memory store.
    fn get_commitment(&self, block_number: &U256) -> Option<SignedCommitment> {
        // Read the map for the requested block number.
        let guard = self.commitments.read().ok()?;
        guard.get(block_number).cloned()
    }

    /// Fetch the highest stored commitment, if any.
    fn latest_commitment(&self) -> Option<SignedCommitment> {
        // Read the map to access the highest block.
        let guard = self.commitments.read().ok()?;
        guard.iter().next_back().map(|(_, value)| value.clone())
    }

    /// Fetch the highest stored block number, if any.
    fn latest_block_number(&self) -> Option<U256> {
        // Read the map to access the highest block.
        let guard = self.commitments.read().ok()?;
        guard.keys().next_back().cloned()
    }

    /// Fetch a range of commitments starting at the provided block number.
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
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
        CommitmentStore::commitments_from(self, start, max)
    }

    /// Fetch a raw txlist by its hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        CommitmentStore::get_txlist(self, hash)
    }
}

/// Buffer for pending commitments that arrived out of order.
///
/// When a commitment arrives whose parent is not yet known, it is buffered here
/// keyed by its parent hash. Once the parent arrives, children can be retrieved
/// and processed.
pub struct PendingCommitmentBuffer {
    /// Map from parent preconfirmation hash to children waiting for that parent.
    pending_by_parent: DashMap<B256, Vec<SignedCommitment>>,
}

impl PendingCommitmentBuffer {
    /// Create a new empty pending buffer.
    pub fn new() -> Self {
        Self { pending_by_parent: DashMap::new() }
    }

    /// Add a commitment to the pending buffer keyed by its parent hash.
    pub fn add(&self, parent_hash: &Bytes32, commitment: SignedCommitment) {
        // Normalize the parent hash to B256.
        let key = B256::from_slice(parent_hash.as_ref());
        // Push the commitment into the pending list.
        self.pending_by_parent.entry(key).or_default().push(commitment);
    }

    /// Remove and return all commitments waiting for the given parent hash.
    pub fn take_children(&self, parent_hash: &Bytes32) -> Vec<SignedCommitment> {
        // Normalize the parent hash to B256.
        let key = B256::from_slice(parent_hash.as_ref());
        self.pending_by_parent.remove(&key).map(|(_, value)| value).unwrap_or_default()
    }
}

impl Default for PendingCommitmentBuffer {
    /// Build a default pending commitment buffer using the standard constructor.
    fn default() -> Self {
        Self::new()
    }
}

/// Buffer for pending commitments that are waiting on txlists.
pub struct PendingTxListBuffer {
    /// Map from txlist hash to commitments waiting for the payload.
    pending_by_txhash: DashMap<B256, Vec<SignedCommitment>>,
}

impl PendingTxListBuffer {
    /// Create a new empty pending txlist buffer.
    pub fn new() -> Self {
        Self { pending_by_txhash: DashMap::new() }
    }

    /// Add a commitment to the pending txlist buffer.
    pub fn add(&self, txlist_hash: &Bytes32, commitment: SignedCommitment) {
        // Normalize the hash to B256.
        let key = B256::from_slice(txlist_hash.as_ref());
        // Push the commitment into the pending list.
        self.pending_by_txhash.entry(key).or_default().push(commitment);
    }

    /// Remove and return all commitments waiting for a txlist hash.
    pub fn take_waiting(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment> {
        // Normalize the hash to B256.
        let key = B256::from_slice(txlist_hash.as_ref());
        self.pending_by_txhash.remove(&key).map(|(_, value)| value).unwrap_or_default()
    }
}

impl Default for PendingTxListBuffer {
    /// Build a default pending txlist buffer using the standard constructor.
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

        assert!(CommitmentStore::latest_commitment(&store).is_none());
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
