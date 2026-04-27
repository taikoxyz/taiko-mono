//! Pending commitment buffer implementation.

use std::sync::atomic::{AtomicUsize, Ordering};

use dashmap::DashMap;

use alloy_primitives::{B256, U256};
use preconfirmation_types::{Bytes32, SignedCommitment, uint256_to_u256};

use crate::config::DEFAULT_RETENTION_LIMIT;

/// Buffer for commitments awaiting their txlist payload.
pub(crate) struct CommitmentsAwaitingTxList {
    /// Pending commitments grouped by their txlist hash.
    by_txlist_hash: DashMap<B256, Vec<SignedCommitment>>,
    /// Total number of pending commitments.
    count: AtomicUsize,
    /// Maximum number of pending commitments to retain.
    retention_limit: usize,
}

impl CommitmentsAwaitingTxList {
    /// Create a buffer with the default retention limit.
    pub fn new() -> Self {
        Self::with_retention_limit(DEFAULT_RETENTION_LIMIT)
    }

    /// Create a buffer with a custom retention limit.
    pub fn with_retention_limit(retention_limit: usize) -> Self {
        Self { by_txlist_hash: DashMap::new(), count: AtomicUsize::new(0), retention_limit }
    }

    /// Return the number of buffered commitments.
    pub fn len(&self) -> usize {
        self.count.load(Ordering::SeqCst)
    }

    /// Add a commitment keyed by its txlist hash.
    pub fn add(&self, txlist_hash: &Bytes32, commitment: SignedCommitment) {
        self.evict_if_needed();
        let key = B256::from_slice(txlist_hash.as_ref());
        self.by_txlist_hash.entry(key).or_default().push(commitment);
        self.count.fetch_add(1, Ordering::SeqCst);
    }

    /// Take and remove all commitments waiting for the given txlist hash.
    pub fn take_waiting(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment> {
        let key = B256::from_slice(txlist_hash.as_ref());
        if let Some((_, value)) = self.by_txlist_hash.remove(&key) {
            self.count.fetch_sub(value.len(), Ordering::SeqCst);
            return value;
        }
        Vec::new()
    }

    /// Evict the oldest commitment when the retention limit is exceeded.
    fn evict_if_needed(&self) {
        let count = self.count.load(Ordering::SeqCst);
        if count < self.retention_limit {
            return;
        }

        let mut min_block: Option<U256> = None;
        let mut min_key: Option<B256> = None;
        let mut min_idx: Option<usize> = None;

        for entry in self.by_txlist_hash.iter() {
            for (idx, commitment) in entry.value().iter().enumerate() {
                let block = uint256_to_u256(&commitment.commitment.preconf.block_number);
                if min_block.is_none_or(|min| block < min) {
                    min_block = Some(block);
                    min_key = Some(*entry.key());
                    min_idx = Some(idx);
                }
            }
        }

        if let (Some(key), Some(idx)) = (min_key, min_idx) &&
            let Some(mut entry) = self.by_txlist_hash.get_mut(&key) &&
            idx < entry.len()
        {
            entry.remove(idx);
            self.count.fetch_sub(1, Ordering::SeqCst);
            if entry.is_empty() {
                drop(entry);
                self.by_txlist_hash.remove(&key);
            }
        }
    }
}

impl Default for CommitmentsAwaitingTxList {
    /// Build a buffer with the default retention limit.
    fn default() -> Self {
        Self::new()
    }
}
