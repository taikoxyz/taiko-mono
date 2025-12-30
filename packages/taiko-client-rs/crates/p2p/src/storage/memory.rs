//! In-memory implementation of SDK storage with LRU/TTL-based caching.

use std::{
    sync::atomic::{AtomicUsize, Ordering},
    time::{Duration, Instant},
};

use alloy_primitives::{B256, U256};
use crossbeam_skiplist::SkipMap;
use dashmap::DashMap;
use moka::sync::Cache;
use parking_lot::RwLock;
use preconfirmation_types::{RawTxListGossip, SignedCommitment};

use super::{CommitmentDedupeKey, SdkStorage, TxListDedupeKey};

/// Default TTL for dedupe cache entries (5 minutes).
const DEFAULT_DEDUPE_TTL: Duration = Duration::from_secs(300);

/// Default capacity for dedupe caches.
const DEFAULT_DEDUPE_CAPACITY: u64 = 10_000;

/// Default TTL for pending buffer entries (10 minutes).
const DEFAULT_PENDING_TTL: Duration = Duration::from_secs(600);

/// In-memory storage implementation with dedupe caches and pending buffer.
///
/// Uses:
/// - `crossbeam-skiplist` for ordered commitments by block number
/// - `dashmap` for concurrent txlist storage
/// - `moka` for TTL-based dedupe caches
/// - `parking_lot::RwLock` for pending buffer with TTL tracking
pub struct InMemoryStorage {
    /// Commitments keyed by block number, ordered.
    commitments: SkipMap<U256, SignedCommitment>,
    /// Raw txlists keyed by their hash.
    txlists: DashMap<B256, RawTxListGossip>,
    /// Message-ID dedupe cache with TTL.
    message_dedupe: Cache<B256, ()>,
    /// Commitment dedupe cache: (block_number, signer) -> seen.
    commitment_dedupe: Cache<CommitmentDedupeKey, ()>,
    /// TxList dedupe cache: (block_number, tx_hash) -> seen.
    txlist_dedupe: Cache<TxListDedupeKey, ()>,
    /// Pending commitments awaiting parent arrival.
    /// Map from parent_hash -> Vec<(commitment, inserted_at)>.
    pending: RwLock<DashMap<B256, Vec<(SignedCommitment, Instant)>>>,
    /// Pending commitments awaiting txlist data by hash.
    /// Map from txlist_hash -> Vec<(commitment, inserted_at)>.
    pending_txlists: RwLock<DashMap<B256, Vec<(SignedCommitment, Instant)>>>,
    /// TTL for pending buffer entries.
    pending_ttl: Duration,
    /// Atomic counter for pending items (for fast pending_count).
    pending_count: AtomicUsize,
    /// Atomic counter for pending txlist items (for fast pending_txlist_count).
    pending_txlist_count: AtomicUsize,
}

impl Default for InMemoryStorage {
    fn default() -> Self {
        Self::new(DEFAULT_DEDUPE_CAPACITY, DEFAULT_DEDUPE_TTL, DEFAULT_PENDING_TTL)
    }
}

impl InMemoryStorage {
    /// Create a new in-memory storage with custom settings.
    ///
    /// # Arguments
    ///
    /// * `dedupe_capacity` - Maximum number of entries in dedupe caches.
    /// * `dedupe_ttl` - Time-to-live for dedupe cache entries.
    /// * `pending_ttl` - Time-to-live for pending buffer entries.
    pub fn new(dedupe_capacity: u64, dedupe_ttl: Duration, pending_ttl: Duration) -> Self {
        Self {
            commitments: SkipMap::new(),
            txlists: DashMap::new(),
            message_dedupe: Cache::builder()
                .max_capacity(dedupe_capacity)
                .time_to_live(dedupe_ttl)
                .build(),
            commitment_dedupe: Cache::builder()
                .max_capacity(dedupe_capacity)
                .time_to_live(dedupe_ttl)
                .build(),
            txlist_dedupe: Cache::builder()
                .max_capacity(dedupe_capacity)
                .time_to_live(dedupe_ttl)
                .build(),
            pending: RwLock::new(DashMap::new()),
            pending_txlists: RwLock::new(DashMap::new()),
            pending_ttl,
            pending_count: AtomicUsize::new(0),
            pending_txlist_count: AtomicUsize::new(0),
        }
    }

    /// Create storage with custom dedupe settings.
    pub fn with_dedupe_settings(capacity: u64, ttl: Duration) -> Self {
        Self::new(capacity, ttl, DEFAULT_PENDING_TTL)
    }

    /// Insert a commitment keyed by block number.
    pub fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        <Self as SdkStorage>::insert_commitment(self, block, commitment);
    }

    /// Return up to `max` commitments starting from `start` (inclusive).
    pub fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        <Self as SdkStorage>::commitments_from(self, start, max)
    }

    /// Get a commitment by block number, if present.
    pub fn get_commitment(&self, block: U256) -> Option<SignedCommitment> {
        <Self as SdkStorage>::get_commitment(self, block)
    }

    /// Insert a raw txlist keyed by its hash.
    pub fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        <Self as SdkStorage>::insert_txlist(self, hash, tx);
    }

    /// Fetch a raw txlist by hash, if present.
    pub fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        <Self as SdkStorage>::get_txlist(self, hash)
    }

    /// Check if a message ID has been seen recently.
    pub fn is_duplicate_message(&self, message_id: &B256) -> bool {
        <Self as SdkStorage>::is_duplicate_message(self, message_id)
    }

    /// Mark a message ID as seen.
    pub fn mark_message_seen(&self, message_id: B256) {
        <Self as SdkStorage>::mark_message_seen(self, message_id);
    }

    pub(crate) fn is_duplicate_commitment(&self, key: &CommitmentDedupeKey) -> bool {
        <Self as SdkStorage>::is_duplicate_commitment(self, key)
    }

    pub(crate) fn mark_commitment_seen(&self, key: CommitmentDedupeKey) {
        <Self as SdkStorage>::mark_commitment_seen(self, key);
    }

    pub(crate) fn is_duplicate_txlist(&self, key: &TxListDedupeKey) -> bool {
        <Self as SdkStorage>::is_duplicate_txlist(self, key)
    }

    pub(crate) fn mark_txlist_seen(&self, key: TxListDedupeKey) {
        <Self as SdkStorage>::mark_txlist_seen(self, key);
    }

    /// Add a commitment to the pending buffer, awaiting its parent.
    pub fn add_pending(&self, parent_hash: B256, commitment: SignedCommitment) {
        <Self as SdkStorage>::add_pending(self, parent_hash, commitment);
    }

    /// Release all commitments waiting on the given parent hash.
    pub fn release_pending(&self, parent_hash: &B256) -> Vec<SignedCommitment> {
        <Self as SdkStorage>::release_pending(self, parent_hash)
    }

    /// Get the number of pending commitments.
    pub fn pending_count(&self) -> usize {
        <Self as SdkStorage>::pending_count(self)
    }

    /// Clear all pending commitments awaiting parent linkage.
    pub fn clear_pending(&self) -> usize {
        <Self as SdkStorage>::clear_pending(self)
    }

    /// Add a commitment to the pending txlist buffer, awaiting its txlist by hash.
    pub fn add_pending_txlist(&self, txlist_hash: B256, commitment: SignedCommitment) -> bool {
        <Self as SdkStorage>::add_pending_txlist(self, txlist_hash, commitment)
    }

    /// Release all commitments waiting on the given txlist hash.
    pub fn release_pending_txlist(&self, txlist_hash: &B256) -> Vec<SignedCommitment> {
        <Self as SdkStorage>::release_pending_txlist(self, txlist_hash)
    }

    /// Check whether any commitments are pending for the given txlist hash.
    pub fn has_pending_txlist(&self, txlist_hash: &B256) -> bool {
        <Self as SdkStorage>::has_pending_txlist(self, txlist_hash)
    }

    /// Get the number of commitments waiting on txlist data.
    pub fn pending_txlist_count(&self) -> usize {
        <Self as SdkStorage>::pending_txlist_count(self)
    }

    /// Clear all commitments waiting on txlist data.
    pub fn clear_pending_txlists(&self) -> usize {
        <Self as SdkStorage>::clear_pending_txlists(self)
    }

    /// Remove expired entries from caches.
    pub fn cleanup_expired(&self) {
        <Self as SdkStorage>::cleanup_expired(self);
    }
}

impl SdkStorage for InMemoryStorage {
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        self.commitments.insert(block, commitment);
    }

    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        self.commitments.range(start..).take(max).map(|entry| entry.value().clone()).collect()
    }

    fn get_commitment(&self, block: U256) -> Option<SignedCommitment> {
        self.commitments.get(&block).map(|entry| entry.value().clone())
    }

    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        self.txlists.insert(hash, tx);
    }

    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        self.txlists.get(hash).map(|entry| entry.value().clone())
    }

    fn is_duplicate_message(&self, message_id: &B256) -> bool {
        self.message_dedupe.contains_key(message_id)
    }

    fn mark_message_seen(&self, message_id: B256) {
        self.message_dedupe.insert(message_id, ());
    }

    fn is_duplicate_commitment(&self, key: &CommitmentDedupeKey) -> bool {
        self.commitment_dedupe.contains_key(key)
    }

    fn mark_commitment_seen(&self, key: CommitmentDedupeKey) {
        self.commitment_dedupe.insert(key, ());
    }

    fn is_duplicate_txlist(&self, key: &TxListDedupeKey) -> bool {
        self.txlist_dedupe.contains_key(key)
    }

    fn mark_txlist_seen(&self, key: TxListDedupeKey) {
        self.txlist_dedupe.insert(key, ());
    }

    fn add_pending(&self, parent_hash: B256, commitment: SignedCommitment) {
        let pending = self.pending.read();
        pending.entry(parent_hash).or_default().push((commitment, Instant::now()));
        self.pending_count.fetch_add(1, Ordering::SeqCst);
    }

    fn release_pending(&self, parent_hash: &B256) -> Vec<SignedCommitment> {
        let pending = self.pending.read();
        if let Some((_, entries)) = pending.remove(parent_hash) {
            let count = entries.len();
            self.pending_count.fetch_sub(count, Ordering::SeqCst);
            entries.into_iter().map(|(c, _)| c).collect()
        } else {
            Vec::new()
        }
    }

    fn pending_count(&self) -> usize {
        self.pending_count.load(Ordering::SeqCst)
    }

    /// Clear all pending commitments awaiting parent linkage.
    fn clear_pending(&self) -> usize {
        let pending = self.pending.write();
        let count = self.pending_count.swap(0, Ordering::SeqCst);
        pending.clear();
        count
    }

    /// Add a commitment to the pending txlist buffer, returning whether this is a new hash.
    fn add_pending_txlist(&self, txlist_hash: B256, commitment: SignedCommitment) -> bool {
        let pending = self.pending_txlists.read();
        let mut entry = pending.entry(txlist_hash).or_default();
        let is_new = entry.is_empty();
        entry.push((commitment, Instant::now()));
        self.pending_txlist_count.fetch_add(1, Ordering::SeqCst);
        is_new
    }

    /// Release commitments waiting for the given txlist hash.
    fn release_pending_txlist(&self, txlist_hash: &B256) -> Vec<SignedCommitment> {
        let pending = self.pending_txlists.read();
        if let Some((_, entries)) = pending.remove(txlist_hash) {
            let count = entries.len();
            self.pending_txlist_count.fetch_sub(count, Ordering::SeqCst);
            entries.into_iter().map(|(c, _)| c).collect()
        } else {
            Vec::new()
        }
    }

    /// Return whether any commitments are pending for the txlist hash.
    fn has_pending_txlist(&self, txlist_hash: &B256) -> bool {
        let pending = self.pending_txlists.read();
        pending.contains_key(txlist_hash)
    }

    /// Return the count of commitments pending on txlist data.
    fn pending_txlist_count(&self) -> usize {
        self.pending_txlist_count.load(Ordering::SeqCst)
    }

    /// Clear all commitments waiting on txlist data.
    fn clear_pending_txlists(&self) -> usize {
        let pending = self.pending_txlists.write();
        let count = self.pending_txlist_count.swap(0, Ordering::SeqCst);
        pending.clear();
        count
    }

    fn cleanup_expired(&self) {
        let now = Instant::now();
        let pending = self.pending.read();
        let pending_txlists = self.pending_txlists.read();

        // Collect keys with expired entries
        let mut expired_count = 0;
        pending.retain(|_, entries| {
            let before_len = entries.len();
            entries.retain(|(_, inserted_at)| now.duration_since(*inserted_at) < self.pending_ttl);
            expired_count += before_len - entries.len();
            !entries.is_empty()
        });

        let mut txlist_expired_count = 0;
        pending_txlists.retain(|_, entries| {
            let before_len = entries.len();
            entries.retain(|(_, inserted_at)| now.duration_since(*inserted_at) < self.pending_ttl);
            txlist_expired_count += before_len - entries.len();
            !entries.is_empty()
        });

        if expired_count > 0 {
            self.pending_count.fetch_sub(expired_count, Ordering::SeqCst);
        }

        if txlist_expired_count > 0 {
            self.pending_txlist_count.fetch_sub(txlist_expired_count, Ordering::SeqCst);
        }

        // Moka caches auto-expire, but we can force a cleanup
        self.message_dedupe.run_pending_tasks();
        self.commitment_dedupe.run_pending_tasks();
        self.txlist_dedupe.run_pending_tasks();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn storage_default_creates_valid_instance() {
        let storage = InMemoryStorage::default();
        assert_eq!(storage.pending_count(), 0);
    }

    #[test]
    fn storage_with_custom_settings() {
        let storage = InMemoryStorage::new(1000, Duration::from_secs(60), Duration::from_secs(120));
        assert_eq!(storage.pending_count(), 0);
    }
}
