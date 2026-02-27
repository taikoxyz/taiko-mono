//! Commitment storage and pending buffer implementation.

use std::{collections::BTreeMap, sync::RwLock};

use tracing::warn;

use alloy_primitives::{B256, U256};
use dashmap::DashMap;
use preconfirmation_net::PreconfStorage;
use preconfirmation_types::{
    Bytes32, PreconfHead, RawTxListGossip, SignedCommitment, uint256_to_u256,
};

use crate::{config::DEFAULT_RETENTION_LIMIT, metrics::PreconfirmationClientMetrics};

use super::awaiting::CommitmentsAwaitingTxList;

/// Trait for accessing stored commitments and txlists.
pub trait CommitmentStore: Send + Sync {
    /// Store a commitment keyed by its block number.
    fn insert_commitment(&self, commitment: SignedCommitment);
    /// Fetch a commitment by block number.
    fn get_commitment(&self, block_number: &U256) -> Option<SignedCommitment>;
    /// Remove a commitment by block number.
    fn remove_commitment(&self, block_number: &U256);
    /// Store a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, txlist: RawTxListGossip);
    /// Fetch a raw txlist by hash.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip>;
    /// Remove a raw txlist by hash.
    fn remove_txlist(&self, hash: &B256);
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
        uint256_to_u256(&commitment.commitment.preconf.block_number)
    }

    /// Fetch a range of commitments starting at the provided block number.
    pub(crate) fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        let mut commitments = Vec::new();
        let guard = match self.commitments.read() {
            Ok(guard) => guard,
            Err(err) => {
                warn!(error = %err, start = %start, max, "commitments lock poisoned, returning empty");
                return commitments;
            }
        };
        for (_, commitment) in guard.range(start..) {
            if commitments.len() >= max {
                break;
            }
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
            Err(err) => {
                warn!(error = %err, "commitments lock poisoned during txlist pruning, skipping prune");
                return;
            }
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
    /// Build an in-memory store with the default retention limit.
    fn default() -> Self {
        Self::new()
    }
}

impl CommitmentStore for InMemoryCommitmentStore {
    /// See [`CommitmentStore::insert_commitment`].
    fn insert_commitment(&self, commitment: SignedCommitment) {
        let block_number = Self::block_number(&commitment);
        if let Ok(mut guard) = self.commitments.write() {
            guard.insert(block_number, commitment.clone());
            self.prune_commitments(&mut guard);
            metrics::gauge!(PreconfirmationClientMetrics::STORE_COMMITMENTS_COUNT)
                .set(guard.len() as f64);
        }
        self.pending_commitments.remove(&block_number);
        metrics::gauge!(PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT)
            .set(self.pending_commitments.len() as f64);
        self.prune_txlists();
    }

    /// See [`CommitmentStore::get_commitment`].
    fn get_commitment(&self, block_number: &U256) -> Option<SignedCommitment> {
        let guard = self.commitments.read().ok()?;
        guard.get(block_number).cloned()
    }

    /// See [`CommitmentStore::remove_commitment`].
    fn remove_commitment(&self, block_number: &U256) {
        if let Ok(mut guard) = self.commitments.write() {
            guard.remove(block_number);
            metrics::gauge!(PreconfirmationClientMetrics::STORE_COMMITMENTS_COUNT)
                .set(guard.len() as f64);
        }
        self.pending_commitments.remove(block_number);
        metrics::gauge!(PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT)
            .set(self.pending_commitments.len() as f64);
    }

    /// See [`CommitmentStore::insert_txlist`].
    fn insert_txlist(&self, hash: B256, txlist: RawTxListGossip) {
        self.txlists.insert(hash, txlist);
        self.pending_txlists.remove(&hash);
        self.prune_txlists();
        metrics::gauge!(PreconfirmationClientMetrics::STORE_TXLISTS_COUNT)
            .set(self.txlists.len() as f64);
    }

    /// See [`CommitmentStore::get_txlist`].
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        self.txlists.get(hash).map(|entry| entry.value().clone())
    }

    /// See [`CommitmentStore::remove_txlist`].
    fn remove_txlist(&self, hash: &B256) {
        self.txlists.remove(hash);
        metrics::gauge!(PreconfirmationClientMetrics::STORE_TXLISTS_COUNT)
            .set(self.txlists.len() as f64);
        self.pending_txlists.remove(hash);
    }

    /// See [`CommitmentStore::drop_pending_commitment`].
    fn drop_pending_commitment(&self, block_number: &U256) {
        self.pending_commitments.remove(block_number);
        metrics::gauge!(PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT)
            .set(self.pending_commitments.len() as f64);
    }

    /// See [`CommitmentStore::drop_pending_txlist`].
    fn drop_pending_txlist(&self, hash: &B256) {
        self.pending_txlists.remove(hash);
    }

    /// See [`CommitmentStore::add_awaiting_txlist`].
    fn add_awaiting_txlist(&self, txlist_hash: &Bytes32, commitment: SignedCommitment) {
        self.awaiting_txlist.add(txlist_hash, commitment);
        metrics::gauge!(PreconfirmationClientMetrics::AWAITING_TXLIST_DEPTH)
            .set(self.awaiting_txlist.len() as f64);
    }

    /// See [`CommitmentStore::take_awaiting_txlist`].
    fn take_awaiting_txlist(&self, txlist_hash: &Bytes32) -> Vec<SignedCommitment> {
        let result = self.awaiting_txlist.take_waiting(txlist_hash);
        metrics::gauge!(PreconfirmationClientMetrics::AWAITING_TXLIST_DEPTH)
            .set(self.awaiting_txlist.len() as f64);
        result
    }

    /// See [`CommitmentStore::set_head`].
    fn set_head(&self, head: PreconfHead) {
        if let Ok(mut guard) = self.head.write() {
            *guard = Some(head);
        }
    }

    /// See [`CommitmentStore::head`].
    fn head(&self) -> Option<PreconfHead> {
        let guard = self.head.read().ok()?;
        guard.clone()
    }
}

#[cfg(test)]
impl InMemoryCommitmentStore {
    pub(crate) fn latest_commitment(&self) -> Option<SignedCommitment> {
        let guard = self.commitments.read().ok()?;
        guard.iter().next_back().map(|(_, value)| value.clone())
    }

    pub(crate) fn pending_commitments_len(&self) -> usize {
        self.pending_commitments.len()
    }

    pub(crate) fn pending_txlists_len(&self) -> usize {
        self.pending_txlists.len()
    }
}
impl PreconfStorage for InMemoryCommitmentStore {
    /// Store a commitment in the pending buffer for later validation.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        match self.commitments.read() {
            Ok(guard) if guard.contains_key(&block) => return,
            Ok(_) => {}
            Err(err) => {
                warn!(error = %err, block = %block, "commitments lock poisoned, inserting to pending anyway");
            }
        }
        self.pending_commitments.insert(block, commitment);
        self.prune_pending_commitments();
        metrics::gauge!(PreconfirmationClientMetrics::STORE_PENDING_COMMITMENTS_COUNT)
            .set(self.pending_commitments.len() as f64);
    }

    /// Store a txlist in the pending buffer for later validation.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        if self.txlists.contains_key(&hash) {
            return;
        }
        self.pending_txlists.insert(hash, tx);
        self.prune_pending_txlists();
    }

    /// Fetch a batch of commitments starting from the given block number.
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        InMemoryCommitmentStore::commitments_from(self, start, max)
    }

    /// Fetch a txlist by hash if it has been validated.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        CommitmentStore::get_txlist(self, hash)
    }
}
