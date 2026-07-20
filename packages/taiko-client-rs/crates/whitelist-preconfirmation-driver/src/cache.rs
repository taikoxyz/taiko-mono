//! In-memory caches and shared runtime state for whitelist preconfirmation envelopes.

use std::{
    collections::HashMap,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use hashlink::LinkedHashMap;
use tokio::sync::{Mutex, broadcast};

use crate::{
    api::types::EndOfSequencingNotification, codec::WhitelistExecutionPayloadEnvelope,
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Maximum number of recently validated envelopes retained for serving responses.
const RECENT_ENVELOPE_CAPACITY: usize = 1024;
/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;
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
/// recently validated envelopes served to request topics, and the most
/// recently observed L2 head reported by `/status`.
#[derive(Debug, Clone)]
pub(crate) struct SharedPreconfState {
    /// End-of-sequencing markers tracked per epoch.
    end_of_sequencing_by_epoch: Arc<Mutex<LinkedHashMap<u64, B256>>>,
    /// Recently validated envelopes retained for serving request-topic responses.
    recent_envelopes: Arc<Mutex<EnvelopeCache>>,
    /// Most recent L2 head observed by `/status` or advanced by locally inserted blocks,
    /// reported as a fallback when the head is unreadable. Seeded with the head at startup.
    last_reported_l2_head: Arc<AtomicU64>,
    /// Broadcast channel feeding `/ws` end-of-sequencing notifications; the importer
    /// sends when an EOS block arrives via the payload topic, the API server subscribes.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

impl SharedPreconfState {
    /// Create shared state seeded with the current L2 head block number.
    pub(crate) fn new(initial_l2_head: u64) -> Self {
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        Self {
            end_of_sequencing_by_epoch: Arc::new(Mutex::new(LinkedHashMap::new())),
            recent_envelopes: Arc::new(Mutex::new(EnvelopeCache::with_capacity(
                RECENT_ENVELOPE_CAPACITY,
            ))),
            last_reported_l2_head: Arc::new(AtomicU64::new(initial_l2_head)),
            eos_notification_tx,
        }
    }

    /// Subscribe to end-of-sequencing `/ws` notifications.
    pub(crate) fn subscribe_end_of_sequencing(
        &self,
    ) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.eos_notification_tx.subscribe()
    }

    /// Notify `/ws` subscribers that an end-of-sequencing block has materialized.
    ///
    /// `current_epoch` is the wall-clock epoch at push time (the Go client
    /// re-reads `CurrentEpoch()` when pushing, ignoring the block's own epoch).
    /// A send error only means no subscriber is currently connected, which is normal.
    pub(crate) fn notify_end_of_sequencing(&self, current_epoch: u64) {
        let _ = self
            .eos_notification_tx
            .send(EndOfSequencingNotification { current_epoch, end_of_sequencing: true });
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

    /// Whether any recorded per-epoch EOS marker points at this block hash.
    ///
    /// Markers are only recorded from authenticated sites (payload-topic
    /// ingress and the local build path), so this is the trustworthy source for
    /// an envelope's EOS flag — the Go server derives the flag for rebuilt
    /// responses by scanning the same marker cache.
    pub(crate) async fn is_end_of_sequencing_hash(&self, hash: &B256) -> bool {
        self.end_of_sequencing_by_epoch.lock().await.values().any(|marked| marked == hash)
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

    /// Remove a recent envelope that is no longer safe to serve.
    pub(crate) async fn remove_recent(
        &self,
        hash: &B256,
    ) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        let mut recent = self.recent_envelopes.lock().await;
        let removed = recent.remove(hash);
        WhitelistPreconfirmationDriverMetrics::set_cache_recent_count(recent.len());
        removed
    }

    /// Record a freshly observed L2 head and return it; when the head is `None` (a failed RPC
    /// read) return the most recently recorded value instead.
    ///
    /// The Catalyst sync gate only opens when the reported value equals the execution head
    /// exactly, and every canonical block is inserted by this driver, so the live head is
    /// always the honest answer. The stored value exists purely to keep `/status` answering
    /// through transient L2 RPC failures; [`Self::record_inserted_block`] keeps it fresh for
    /// blocks inserted between polls.
    pub(crate) fn reconcile_reported_head(&self, head: Option<u64>) -> u64 {
        match head {
            Some(head) => {
                self.last_reported_l2_head.store(head, Ordering::Relaxed);
                head
            }
            None => self.last_reported_l2_head.load(Ordering::Relaxed),
        }
    }

    /// Record a block this process just inserted (cached import or local build) so the
    /// `/status` fallback covers blocks inserted since the last successful head read.
    ///
    /// A plain store suffices: cached imports drain in ascending block order, local builds
    /// insert sequentially, and any successful status poll overwrites the value with the
    /// live head anyway.
    pub(crate) fn record_inserted_block(&self, block_number: u64) {
        self.last_reported_l2_head.store(block_number, Ordering::Relaxed);
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

/// Bounded set of block hashes whose end-of-sequencing flag arrived on the
/// wire-signed payload topic and still awaits its `/ws` notification.
///
/// The flag must be captured at admission rather than read from the pending
/// envelope cache at import time: that cache overwrites same-hash entries, and
/// a later response-topic envelope — whose embedded signature covers only the
/// block hash, leaving the EOS flag unauthenticated — could otherwise flip the
/// flag in either direction (spoofing a handover, or suppressing a real one)
/// before the block imports. Terminally removed envelopes discard their marks;
/// any remaining entries for blocks that never return age out by capacity.
#[derive(Debug)]
pub(crate) struct PayloadEosTracker {
    /// Marked hashes in insertion order, oldest first.
    hashes: LinkedHashMap<B256, ()>,
    /// Maximum number of hashes retained.
    capacity: usize,
}

impl PayloadEosTracker {
    /// Create a tracker retaining at most `capacity` pending hashes.
    pub(crate) fn with_capacity(capacity: usize) -> Self {
        Self { hashes: LinkedHashMap::new(), capacity }
    }

    /// Record an operator-authenticated EOS block hash from the payload topic.
    pub(crate) fn mark(&mut self, hash: B256) {
        self.hashes.insert(hash, ());
        while self.hashes.len() > self.capacity {
            let _ = self.hashes.pop_front();
        }
    }

    /// Consume the pending notification for a hash, returning whether one existed.
    pub(crate) fn take(&mut self, hash: &B256) -> bool {
        self.hashes.remove(hash).is_some()
    }

    /// Discard a terminal envelope's pending notification without sending it.
    pub(crate) fn discard(&mut self, hash: &B256) {
        self.hashes.remove(hash);
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use alloy_primitives::{Address, Bloom, Bytes, U256};
    use alloy_rpc_types_engine::ExecutionPayloadV1;

    use super::*;

    fn sample_envelope(hash: B256, block_number: u64) -> WhitelistExecutionPayloadEnvelope {
        WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: None,
            is_forced_inclusion: None,
            parent_beacon_block_root: None,
            header_difficulty: Some(U256::from(1_000_000u64)),
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::from([0x10u8; 32]),
                fee_recipient: Address::from([0x11u8; 20]),
                state_root: B256::from([0x12u8; 32]),
                receipts_root: B256::from([0x13u8; 32]),
                logs_bloom: Bloom::default(),
                prev_randao: B256::from([0x14u8; 32]),
                block_number,
                gas_limit: 30_000_000,
                gas_used: 21_000,
                timestamp: 1_735_000_000,
                extra_data: Bytes::from(vec![0x55u8; 8]),
                base_fee_per_gas: U256::from(1_000_000_000u64),
                block_hash: hash,
                transactions: vec![Bytes::from(vec![0x99u8; 4])],
            },
            signature: Some([0x22u8; 65]),
        }
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

        assert_eq!(state.reconcile_reported_head(None), 7, "seed backs the fallback");
        assert!(state.get_recent(&hash).await.is_none());

        state.insert_recent(Arc::new(sample_envelope(hash, 8))).await;
        assert!(state.get_recent(&hash).await.is_some());

        state.record_end_of_sequencing(42, hash).await;
        assert_eq!(state.end_of_sequencing_for_epoch(42).await, Some(hash));
        assert_eq!(state.end_of_sequencing_for_epoch(43).await, None);
        assert!(state.is_end_of_sequencing_hash(&hash).await);
        assert!(!state.is_end_of_sequencing_hash(&B256::from([0x78u8; 32])).await);
    }

    #[tokio::test]
    async fn shared_state_removes_recent_envelopes() {
        let state = SharedPreconfState::new(0);
        let hash = B256::from([0x42u8; 32]);
        state.insert_recent(Arc::new(sample_envelope(hash, 8))).await;

        assert!(state.remove_recent(&hash).await.is_some());
        assert!(state.get_recent(&hash).await.is_none());
    }

    #[tokio::test]
    async fn shared_state_notifies_eos_subscribers() {
        let state = SharedPreconfState::new(0);
        let mut subscriber = state.subscribe_end_of_sequencing();

        state.notify_end_of_sequencing(42);

        let notification = subscriber.recv().await.expect("notification delivered");
        assert_eq!(notification.current_epoch, 42);
        assert!(notification.end_of_sequencing);
    }

    #[test]
    fn notify_without_subscribers_is_a_no_op() {
        SharedPreconfState::new(0).notify_end_of_sequencing(7);
    }

    #[test]
    fn payload_eos_tracker_takes_marked_hashes_once() {
        let mut tracker = PayloadEosTracker::with_capacity(4);
        let marked = B256::from([0x01u8; 32]);
        let unmarked = B256::from([0x02u8; 32]);

        tracker.mark(marked);

        // A hash never marked by the payload topic (e.g. response-sourced EOS)
        // has no pending notification.
        assert!(!tracker.take(&unmarked));
        assert!(tracker.take(&marked));
        assert!(!tracker.take(&marked), "a notification is consumed exactly once");
    }

    #[test]
    fn payload_eos_tracker_remark_is_idempotent() {
        let mut tracker = PayloadEosTracker::with_capacity(4);
        let hash = B256::from([0x03u8; 32]);

        // Duplicate gossip deliveries of the same payload envelope re-mark the
        // same hash; that must still yield a single pending notification.
        tracker.mark(hash);
        tracker.mark(hash);

        assert!(tracker.take(&hash));
        assert!(!tracker.take(&hash));
    }

    #[test]
    fn payload_eos_tracker_evicts_oldest_beyond_capacity() {
        let mut tracker = PayloadEosTracker::with_capacity(2);
        let hashes: Vec<B256> = (1u8..=3).map(|byte| B256::from([byte; 32])).collect();

        for hash in &hashes {
            tracker.mark(*hash);
        }

        assert!(!tracker.take(&hashes[0]), "oldest entry is evicted at capacity");
        assert!(tracker.take(&hashes[1]));
        assert!(tracker.take(&hashes[2]));
    }

    #[test]
    fn payload_eos_tracker_discards_terminal_hash_without_evicting_pending_hash() {
        let mut tracker = PayloadEosTracker::with_capacity(2);
        let pending = B256::from([0x01u8; 32]);
        let terminal = B256::from([0x02u8; 32]);
        let newer = B256::from([0x03u8; 32]);

        tracker.mark(pending);
        tracker.mark(terminal);
        tracker.discard(&terminal);
        tracker.mark(newer);

        assert!(tracker.take(&pending), "terminal cleanup must preserve pending provenance");
        assert!(!tracker.take(&terminal));
        assert!(tracker.take(&newer));
    }
}
