//! In-memory caches and shared runtime state for whitelist preconfirmation envelopes.

use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use hashlink::LinkedHashMap;
use tokio::sync::Mutex;

use crate::{
    codec::WhitelistExecutionPayloadEnvelope, metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Maximum number of recently validated envelopes retained for serving responses.
const RECENT_ENVELOPE_CAPACITY: usize = 1024;
/// Maximum number of pending envelopes retained while waiting for parents.
pub(crate) const PENDING_ENVELOPE_CAPACITY: usize = 768;
/// Maximum number of EOS cache entries retained.
const EOS_CACHE_CAPACITY: usize = PENDING_ENVELOPE_CAPACITY;
/// Default cooldown, in seconds, between duplicate parent-hash requests.
const DEFAULT_REQUEST_COOLDOWN_SECS: u64 = 10;
/// One L1 epoch (32 slots x 12 seconds).
pub(crate) const L1_EPOCH_DURATION_SECS: u64 = 12 * 32;

/// Shared mutable state for the whitelist preconfirmation driver.
///
/// Holds everything both the importer (P2P ingestion) and the API service
/// (REST build/status) need to observe: end-of-sequencing markers, the
/// recently validated envelopes served to request topics, and the highest
/// unsafe L2 payload block id.
#[derive(Debug, Clone)]
pub(crate) struct SharedPreconfState {
    /// End-of-sequencing markers tracked per epoch.
    end_of_sequencing_by_epoch: Arc<Mutex<LinkedHashMap<u64, B256>>>,
    /// Recently validated envelopes retained for serving request-topic responses.
    recent_envelopes: Arc<Mutex<EnvelopeCache>>,
    /// Highest unsafe L2 payload block id observed via P2P import or local build.
    highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
}

impl SharedPreconfState {
    /// Create shared state seeded with the current L2 head block number.
    pub(crate) fn new(initial_highest_unsafe_l2_payload_block_id: u64) -> Self {
        Self {
            end_of_sequencing_by_epoch: Arc::new(Mutex::new(LinkedHashMap::new())),
            recent_envelopes: Arc::new(Mutex::new(EnvelopeCache::with_capacity(
                RECENT_ENVELOPE_CAPACITY,
            ))),
            highest_unsafe_l2_payload_block_id: Arc::new(Mutex::new(
                initial_highest_unsafe_l2_payload_block_id,
            )),
        }
    }

    /// Record an EOS hash for the given epoch with bounded cache size.
    pub(crate) async fn record_end_of_sequencing(&self, epoch: u64, block_hash: B256) {
        let mut entries = self.end_of_sequencing_by_epoch.lock().await;
        entries.insert(epoch, block_hash);

        if entries.len() > EOS_CACHE_CAPACITY {
            let _ = entries.pop_front();
        }
    }

    /// Fetch EOS hash for an epoch, if known.
    pub(crate) async fn end_of_sequencing_for_epoch(&self, epoch: u64) -> Option<B256> {
        self.end_of_sequencing_by_epoch.lock().await.get(&epoch).copied()
    }

    /// Insert a validated envelope into the recent cache and refresh its gauge.
    pub(crate) async fn insert_recent(&self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        let mut recent = self.recent_envelopes.lock().await;
        recent.insert(envelope);
        WhitelistPreconfirmationDriverMetrics::set_cache_recent_count(recent.len());
    }

    /// Get a recently validated envelope by block hash.
    pub(crate) async fn get_recent(
        &self,
        hash: &B256,
    ) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.recent_envelopes.lock().await.get(hash).cloned()
    }

    /// Raise the highest unsafe block id to `block_number` when it is higher.
    pub(crate) async fn raise_highest_unsafe(&self, block_number: u64) {
        let mut guard = self.highest_unsafe_l2_payload_block_id.lock().await;
        *guard = block_number.max(*guard);
    }

    /// Set the highest unsafe block id unconditionally (local builds may
    /// legitimately lower it after an L1 reorg).
    pub(crate) async fn set_highest_unsafe(&self, block_number: u64) {
        *self.highest_unsafe_l2_payload_block_id.lock().await = block_number;
    }

    /// Read the highest unsafe block id.
    pub(crate) async fn highest_unsafe(&self) -> u64 {
        *self.highest_unsafe_l2_payload_block_id.lock().await
    }
}

/// Bounded in-memory envelope cache keyed by block hash with LRU-style eviction.
#[derive(Debug)]
pub(crate) struct EnvelopeCache {
    /// Fast lookup table keyed by payload block hash.
    entries: LinkedHashMap<B256, Arc<WhitelistExecutionPayloadEnvelope>>,
    /// Maximum number of envelopes to retain.
    capacity: usize,
}

impl EnvelopeCache {
    /// Construct an envelope cache with a fixed capacity.
    pub fn with_capacity(capacity: usize) -> Self {
        let capacity = capacity.max(1);
        Self { entries: LinkedHashMap::with_capacity(capacity), capacity }
    }

    /// Insert or replace a cached envelope, refreshing its recency.
    pub fn insert(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        let hash = envelope.execution_payload.block_hash;
        self.entries.remove(&hash);
        self.entries.insert(hash, envelope);
        self.evict_oldest();
    }

    /// Evict oldest entries until capacity is satisfied.
    fn evict_oldest(&mut self) {
        while self.entries.len() > self.capacity {
            let _ = self.entries.pop_front();
        }
    }

    /// Remove a cached envelope by block hash.
    pub fn remove(&mut self, hash: &B256) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.entries.remove(hash)
    }

    /// Returns all cached envelope hashes sorted by block number and hash.
    pub fn sorted_hashes_by_block_number(&self) -> Vec<B256> {
        let mut hashes = self
            .entries
            .iter()
            .map(|(hash, envelope)| (*hash, envelope.execution_payload.block_number))
            .collect::<Vec<_>>();
        hashes.sort_unstable_by(|a, b| a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0)));
        hashes.into_iter().map(|(hash, _)| hash).collect()
    }

    /// Get a cached envelope by block hash.
    pub fn get(&self, hash: &B256) -> Option<&Arc<WhitelistExecutionPayloadEnvelope>> {
        self.entries.get(hash)
    }

    /// Returns true when the cache is empty.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Returns current number of cached envelopes.
    pub fn len(&self) -> usize {
        self.entries.len()
    }
}

/// Per-hash request throttle used to avoid repeatedly requesting the same missing parent.
#[derive(Debug)]
pub(crate) struct RequestThrottle {
    /// Minimum elapsed time required before re-requesting the same hash.
    cooldown: Duration,
    /// Last request time per hash.
    requested_at: HashMap<B256, Instant>,
}

impl Default for RequestThrottle {
    /// Build a throttle with the default per-hash cooldown window.
    fn default() -> Self {
        Self::new(Duration::from_secs(DEFAULT_REQUEST_COOLDOWN_SECS))
    }
}

impl RequestThrottle {
    /// Create a request throttle with a custom cooldown.
    pub fn new(cooldown: Duration) -> Self {
        Self { cooldown, requested_at: HashMap::new() }
    }

    /// Remove hashes whose cooldown window has elapsed.
    fn prune_expired(&mut self, now: Instant) {
        let cooldown = self.cooldown;
        self.requested_at
            .retain(|_, last_request| now.saturating_duration_since(*last_request) < cooldown);
    }

    /// Return `true` if the hash should be requested at `now`, then records the request.
    pub fn should_request(&mut self, hash: B256, now: Instant) -> bool {
        self.prune_expired(now);

        match self.requested_at.get(&hash) {
            Some(last) if now.saturating_duration_since(*last) < self.cooldown => false,
            _ => {
                self.requested_at.insert(hash, now);
                true
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use alloy_primitives::Bytes;

    use super::*;
    use crate::test_support::sample_envelope_with_transactions;

    /// Cache tests key envelopes by `(block_hash, block_number)`; wrap the shared
    /// builder and override just those two fields.
    fn sample_envelope(hash: B256, block_number: u64) -> WhitelistExecutionPayloadEnvelope {
        let mut envelope = sample_envelope_with_transactions(vec![Bytes::from(vec![0x99u8; 4])]);
        envelope.execution_payload.block_hash = hash;
        envelope.execution_payload.block_number = block_number;
        envelope
    }

    #[test]
    fn envelope_cache_eviction_is_bounded() {
        let mut cache = EnvelopeCache::with_capacity(2);
        let h1 = B256::from([0x10u8; 32]);
        let h2 = B256::from([0x20u8; 32]);
        let h3 = B256::from([0x30u8; 32]);

        cache.insert(Arc::new(sample_envelope(h1, 1)));
        cache.insert(Arc::new(sample_envelope(h2, 2)));
        cache.insert(Arc::new(sample_envelope(h3, 3)));

        let hashes = cache.sorted_hashes_by_block_number();
        assert_eq!(hashes, vec![h2, h3]);
        assert_eq!(cache.len(), 2);
        assert!(cache.get(&h1).is_none());
    }

    #[test]
    fn envelope_cache_remove_keeps_insertion_order_consistent() {
        let mut cache = EnvelopeCache::with_capacity(3);
        let h1 = B256::from([0x40u8; 32]);
        let h2 = B256::from([0x50u8; 32]);
        let h3 = B256::from([0x60u8; 32]);

        cache.insert(Arc::new(sample_envelope(h1, 1)));
        cache.insert(Arc::new(sample_envelope(h2, 2)));
        cache.insert(Arc::new(sample_envelope(h3, 3)));
        let removed = cache.remove(&h2);
        assert!(removed.is_some());

        cache.insert(Arc::new(sample_envelope(B256::from([0x70u8; 32]), 4)));
        let hashes = cache.sorted_hashes_by_block_number();
        assert_eq!(hashes, vec![h1, h3, B256::from([0x70u8; 32])]);
    }

    #[test]
    fn envelope_cache_sort_tiebreak_is_deterministic() {
        let mut cache = EnvelopeCache::with_capacity(4);
        let h1 = B256::from([0x11u8; 32]);
        let h2 = B256::from([0x22u8; 32]);
        let h3 = B256::from([0x33u8; 32]);

        cache.insert(Arc::new(sample_envelope(h2, 7)));
        cache.insert(Arc::new(sample_envelope(h1, 7)));
        cache.insert(Arc::new(sample_envelope(h3, 8)));

        assert_eq!(cache.sorted_hashes_by_block_number(), vec![h1, h2, h3]);
    }

    #[test]
    fn envelope_cache_duplicate_insert_refreshes_recency() {
        let mut cache = EnvelopeCache::with_capacity(2);
        let h1 = B256::from([0x44u8; 32]);
        let h2 = B256::from([0x55u8; 32]);
        let h3 = B256::from([0x66u8; 32]);

        cache.insert(Arc::new(sample_envelope(h1, 1)));
        cache.insert(Arc::new(sample_envelope(h2, 2)));
        cache.insert(Arc::new(sample_envelope(h1, 3)));
        cache.insert(Arc::new(sample_envelope(h3, 4)));

        assert!(cache.get(&h1).is_some());
        assert!(cache.get(&h2).is_none());
        assert!(cache.get(&h3).is_some());
        assert_eq!(cache.sorted_hashes_by_block_number().len(), 2);
    }

    #[test]
    fn request_throttle_applies_cooldown_per_hash() {
        let mut throttle = RequestThrottle::new(Duration::from_secs(10));
        let hash = B256::from([0xaau8; 32]);
        let now = Instant::now();

        assert!(throttle.should_request(hash, now));
        assert!(!throttle.should_request(hash, now + Duration::from_secs(5)));
        assert!(throttle.should_request(hash, now + Duration::from_secs(11)));
    }

    #[test]
    fn request_throttle_prunes_expired_hashes() {
        let mut throttle = RequestThrottle::new(Duration::from_secs(10));
        let h1 = B256::from([0x01u8; 32]);
        let h2 = B256::from([0x02u8; 32]);
        let h3 = B256::from([0x03u8; 32]);
        let now = Instant::now();

        assert!(throttle.should_request(h1, now));
        assert!(throttle.should_request(h2, now + Duration::from_secs(1)));
        assert_eq!(throttle.requested_at.len(), 2);

        assert!(throttle.should_request(h3, now + Duration::from_secs(25)));
        assert_eq!(throttle.requested_at.len(), 1);
        assert!(throttle.requested_at.contains_key(&h3));
    }

    #[tokio::test]
    async fn shared_state_tracks_recent_envelopes_and_eos_markers() {
        let state = SharedPreconfState::new(7);
        let hash = B256::from([0x77u8; 32]);

        assert_eq!(state.highest_unsafe().await, 7);
        assert!(state.get_recent(&hash).await.is_none());

        state.insert_recent(Arc::new(sample_envelope(hash, 8))).await;
        assert!(state.get_recent(&hash).await.is_some());

        state.record_end_of_sequencing(42, hash).await;
        assert_eq!(state.end_of_sequencing_for_epoch(42).await, Some(hash));
        assert_eq!(state.end_of_sequencing_for_epoch(43).await, None);
    }

    #[tokio::test]
    async fn shared_state_highest_unsafe_raise_and_set_semantics() {
        let state = SharedPreconfState::new(10);

        state.raise_highest_unsafe(5).await;
        assert_eq!(state.highest_unsafe().await, 10, "raise must never lower the counter");

        state.raise_highest_unsafe(12).await;
        assert_eq!(state.highest_unsafe().await, 12);

        state.set_highest_unsafe(3).await;
        assert_eq!(state.highest_unsafe().await, 3, "set may lower after an L1 reorg rebuild");
    }
}
