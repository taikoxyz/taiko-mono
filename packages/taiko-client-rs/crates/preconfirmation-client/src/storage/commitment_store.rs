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
use preconfirmation_types::{
    Bytes32, PreconfHead, RawTxListGossip, SignedCommitment, bytes32_to_b256, uint256_to_u256,
};

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
    /// Update the stored head snapshot.
    fn set_head(&self, head: PreconfHead);
    /// Fetch the stored head snapshot.
    fn head(&self) -> Option<PreconfHead>;
}

/// In-memory commitment store.
///
/// This store keeps commitments indexed by block number and raw txlists
/// indexed by their hash. It is separate from the P2P layer's internal storage.
pub struct InMemoryCommitmentStore {
    /// Commitments indexed by block number.
    commitments: RwLock<BTreeMap<U256, SignedCommitment>>,
    /// Raw txlists indexed by hash.
    txlists: DashMap<B256, RawTxListGossip>,
    /// Current head snapshot.
    head: RwLock<Option<PreconfHead>>,
}

impl InMemoryCommitmentStore {
    /// Create a new empty in-memory commitment store.
    pub fn new() -> Self {
        Self {
            commitments: RwLock::new(BTreeMap::new()),
            txlists: DashMap::new(),
            head: RwLock::new(None),
        }
    }

    /// Extract the block number from a commitment.
    fn block_number(commitment: &SignedCommitment) -> U256 {
        // Convert the SSZ uint256 block number into an alloy U256.
        uint256_to_u256(&commitment.commitment.preconf.block_number)
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
        }
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
    }

    /// Fetch a raw txlist payload by hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        // Fetch and clone the stored txlist.
        self.txlists.get(hash).map(|entry| entry.value().clone())
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
        let key = bytes32_to_b256(parent_hash);
        // Push the commitment into the pending list.
        self.pending_by_parent.entry(key).or_default().push(commitment);
    }

    /// Remove and return all commitments waiting for the given parent hash.
    pub fn take_children(&self, parent_hash: &Bytes32) -> Vec<SignedCommitment> {
        // Normalize the parent hash to B256.
        let key = bytes32_to_b256(parent_hash);
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
        let key = bytes32_to_b256(txlist_hash);
        // Push the commitment into the pending list.
        self.pending_by_txhash.entry(key).or_default().push(commitment);
    }

    /// Remove and return all commitments waiting for a txlist hash.
    pub fn take_waiting(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment> {
        // Normalize the hash to B256.
        let key = bytes32_to_b256(txlist_hash);
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

    /// Ensure a new store has no latest commitment.
    #[test]
    fn store_roundtrip_commitment() {
        // Initialize a fresh store for assertions.
        let store = InMemoryCommitmentStore::new();
        assert!(store.latest_commitment().is_none());
    }
}
