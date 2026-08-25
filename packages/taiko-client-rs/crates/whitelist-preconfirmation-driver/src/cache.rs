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
    last_observed_l2_head: Arc<AtomicU64>,
    /// Highest block number of any well-formed, signature-valid envelope this node has
    /// *received*, whether or not it could be imported. Seeded with the head at startup.
    highest_seen_block: Arc<AtomicU64>,
    /// Latest L1-confirmed canonical tip observed at envelope admission, used only to detect a
    /// tip moving backwards. Starts at zero so the first observation reads as an advance.
    last_confirmed_tip: Arc<AtomicU64>,
}

impl SharedPreconfState {
    /// Create shared state seeded with the current L2 head block number.
    pub(crate) fn new(initial_l2_head: u64) -> Self {
        Self {
            end_of_sequencing_by_epoch: Arc::new(Mutex::new(LinkedHashMap::new())),
            recent_envelopes: Arc::new(Mutex::new(EnvelopeCache::with_capacity(
                RECENT_ENVELOPE_CAPACITY,
            ))),
            last_observed_l2_head: Arc::new(AtomicU64::new(initial_l2_head)),
            highest_seen_block: Arc::new(AtomicU64::new(initial_l2_head)),
            last_confirmed_tip: Arc::new(AtomicU64::new(0)),
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
    /// This is the node's own execution head, which `/status` floors its report at rather than
    /// reporting directly — see [`Self::highest_unsafe_floored_at`]. Reporting it directly made
    /// the preconfer client's sync gate, which opens when the reported value equals the execution
    /// head exactly, a tautology: a node that had fallen behind still read as synced. The stored
    /// value keeps `/status` answering through transient L2 RPC failures, and
    /// [`Self::record_inserted_block`] keeps it fresh for blocks inserted between polls.
    pub(crate) fn reconcile_observed_head(&self, head: Option<u64>) -> u64 {
        match head {
            Some(head) => {
                self.last_observed_l2_head.store(head, Ordering::Relaxed);
                head
            }
            None => self.last_observed_l2_head.load(Ordering::Relaxed),
        }
    }

    /// Record a block this process just inserted (cached import or local build) so the
    /// `/status` fallback covers blocks inserted since the last successful head read.
    ///
    /// A plain store suffices: cached imports drain in ascending block order, local builds
    /// insert sequentially, and any successful status poll overwrites the value with the
    /// live head anyway.
    pub(crate) fn record_inserted_block(&self, block_number: u64) {
        self.last_observed_l2_head.store(block_number, Ordering::Relaxed);
    }

    /// Advance the highest seen block number, monotonically.
    ///
    /// Called for every envelope that passes payload validation, before any decision about
    /// whether it can be imported. A node holding a backlog it cannot apply therefore reports a
    /// value above its execution head, which is what lets the preconfer client's parity check
    /// fail closed instead of comparing two equally stale values.
    ///
    /// The value is clamped to [`PENDING_ENVELOPE_CAPACITY`] beyond the last observed head: an
    /// envelope further ahead than the pending cache can ever bridge needs L1 confirmation to
    /// recover either way, so letting a malformed or hostile block number park the counter
    /// arbitrarily high would only keep the node reporting itself out of sync forever.
    pub(crate) fn record_seen_block(&self, block_number: u64) {
        let previous = self.highest_seen_block.fetch_max(block_number, Ordering::Relaxed);
        if block_number > previous {
            WhitelistPreconfirmationDriverMetrics::set_highest_seen_block(block_number);
        }
    }

    /// Record the latest L1-confirmed canonical tip, pulling the highest seen block back down
    /// when that tip moves *backwards* — an L1 reorg rewinding the chain past envelopes this node
    /// had already counted.
    ///
    /// Without this, an envelope from the discarded branch keeps `/status` reporting a height the
    /// chain no longer reaches, and the node reports a permanent mismatch until the new branch
    /// grows past it — the preconfer client exits after roughly half an L2 epoch of that.
    ///
    /// Only a backwards move resets. In steady state the highest seen block runs *ahead* of the
    /// confirmed tip, because preconfirmations outpace L1 confirmation by design; resetting on
    /// every observation would destroy the counter. The confirmed tip is also the only authority
    /// safe to reset against — resetting to the local execution head would let a node that is
    /// genuinely behind declare itself synced, the exact failure this counter exists to prevent.
    pub(crate) fn note_confirmed_tip(&self, confirmed_tip: u64) {
        let previous = self.last_confirmed_tip.swap(confirmed_tip, Ordering::Relaxed);
        if confirmed_tip >= previous {
            return;
        }

        let seen = self.highest_seen_block.swap(confirmed_tip, Ordering::Relaxed);
        WhitelistPreconfirmationDriverMetrics::set_highest_seen_block(confirmed_tip);
        tracing::info!(
            previous_confirmed_tip = previous,
            confirmed_tip,
            previous_highest_seen = seen,
            "confirmed tip rewound; reset highest seen preconfirmation block"
        );
    }

    /// Highest block number received from the P2P network, imported or not.
    pub(crate) fn highest_seen_block(&self) -> u64 {
        self.highest_seen_block.load(Ordering::Relaxed)
    }

    /// The value `/status` reports as `highestUnsafeL2PayloadBlockID`: the highest envelope seen,
    /// floored at `head` as returned by [`Self::reconcile_observed_head`].
    ///
    /// Above the head, this node is holding envelopes it has not applied and must read as out of
    /// sync. At or below it, the node is merely ahead of the gossip it has seen — right after a
    /// beacon sync, for example — and must not report a spurious backlog, because the preconfer
    /// client exits after roughly half an L2 epoch of continuous mismatch.
    ///
    /// The value is also capped one pending-cache span above the head, so a malformed or hostile
    /// block number cannot park the node out of sync indefinitely: past that span the backlog
    /// needs L1 confirmation to clear either way.
    pub(crate) fn highest_unsafe_floored_at(&self, head: u64) -> u64 {
        self.highest_seen_block().clamp(head, head.saturating_add(PENDING_ENVELOPE_CAPACITY as u64))
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

        assert_eq!(state.reconcile_observed_head(None), 7, "seed backs the fallback");
        assert!(state.get_recent(&hash).await.is_none());

        state.insert_recent(Arc::new(sample_envelope(hash, 8))).await;
        assert!(state.get_recent(&hash).await.is_some());

        state.record_end_of_sequencing(42, hash).await;
        assert_eq!(state.end_of_sequencing_for_epoch(42).await, Some(hash));
        assert_eq!(state.end_of_sequencing_for_epoch(43).await, None);
    }

    #[tokio::test]
    async fn shared_state_removes_recent_envelopes() {
        let state = SharedPreconfState::new(0);
        let hash = B256::from([0x42u8; 32]);
        state.insert_recent(Arc::new(sample_envelope(hash, 8))).await;

        assert!(state.remove_recent(&hash).await.is_some());
        assert!(state.get_recent(&hash).await.is_none());
    }
}
