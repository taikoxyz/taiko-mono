//! In-memory cache for out-of-order whitelist preconfirmation envelopes.

use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256};
use hashlink::LinkedHashMap;
use tokio::sync::Mutex;

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Default maximum number of recently validated envelopes retained for serving responses.
const DEFAULT_RECENT_ENVELOPE_CAPACITY: usize = 1024;
/// Default maximum number of pending envelopes retained while waiting for parents.
const DEFAULT_PENDING_ENVELOPE_CAPACITY: usize = 768;
/// Maximum number of EOS cache entries retained.
const DEFAULT_EOS_CACHE_CAPACITY: usize = DEFAULT_PENDING_ENVELOPE_CAPACITY;
/// Default cooldown, in seconds, between duplicate parent-hash requests.
const DEFAULT_REQUEST_COOLDOWN_SECS: u64 = 10;
/// One L1 epoch (32 slots x 12 seconds).
pub(crate) const L1_EPOCH_DURATION_SECS: u64 = 12 * 32;
/// Minimum interval between forced signer-miss refreshes from L1.
const DEFAULT_SEQUENCER_MISS_REFRESH_COOLDOWN_SECS: u64 = 2;

/// Shared cache state surfaced through REST status and high-throughput request handlers.
#[derive(Debug, Clone)]
pub(crate) struct SharedPreconfCacheState {
    /// End-of-sequencing markers tracked per epoch.
    end_of_sequencing_by_epoch: Arc<Mutex<LinkedHashMap<u64, B256>>>,
}

impl SharedPreconfCacheState {
    /// Create shared cache state with empty epoch mapping.
    pub(crate) fn new() -> Self {
        Self { end_of_sequencing_by_epoch: Arc::new(Mutex::new(LinkedHashMap::new())) }
    }

    /// Record an EOS hash for the given epoch with bounded cache size.
    pub(crate) async fn record_end_of_sequencing(&self, epoch: u64, block_hash: B256) {
        let mut entries = self.end_of_sequencing_by_epoch.lock().await;
        entries.insert(epoch, block_hash);

        if entries.len() > DEFAULT_EOS_CACHE_CAPACITY {
            let _ = entries.pop_front();
        }
    }

    /// Fetch EOS hash for an epoch, if known.
    pub(crate) async fn end_of_sequencing_for_epoch(&self, epoch: u64) -> Option<B256> {
        self.end_of_sequencing_by_epoch.lock().await.get(&epoch).copied()
    }
}

/// Simple in-memory cache keyed by block hash with bounded capacity.
pub(crate) struct EnvelopeCache {
    /// Fast lookup table keyed by payload block hash.
    entries: LinkedHashMap<B256, Arc<WhitelistExecutionPayloadEnvelope>>,
    /// Maximum number of envelopes to retain.
    capacity: usize,
}

impl Default for EnvelopeCache {
    /// Build an envelope cache with the standard pending-capacity default.
    fn default() -> Self {
        Self::with_capacity(DEFAULT_PENDING_ENVELOPE_CAPACITY)
    }
}

impl EnvelopeCache {
    /// Construct a pending-envelope cache with a fixed capacity.
    pub fn with_capacity(capacity: usize) -> Self {
        let capacity = capacity.max(1);
        Self { entries: LinkedHashMap::with_capacity(capacity), capacity }
    }

    /// Insert or replace a cached envelope.
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

/// Recently seen validated envelopes used for serving request topic responses.
#[derive(Debug)]
pub(crate) struct RecentEnvelopeCache {
    /// Fast lookup table keyed by payload block hash.
    entries: LinkedHashMap<B256, Arc<WhitelistExecutionPayloadEnvelope>>,
    /// Maximum number of envelopes to retain.
    capacity: usize,
}

impl Default for RecentEnvelopeCache {
    /// Build a recent cache with the standard bounded-capacity default.
    fn default() -> Self {
        Self::with_capacity(DEFAULT_RECENT_ENVELOPE_CAPACITY)
    }
}

impl RecentEnvelopeCache {
    /// Construct a recent-envelope cache with a fixed capacity.
    pub fn with_capacity(capacity: usize) -> Self {
        let capacity = capacity.max(1);
        Self { entries: LinkedHashMap::with_capacity(capacity), capacity }
    }

    /// Insert or replace a recent envelope.
    pub fn insert_recent(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
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

    /// Get a recent envelope by block hash.
    pub fn get_recent(&self, hash: &B256) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.entries.get(hash).cloned()
    }

    /// Returns current number of recent envelopes.
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

/// Cached pair of current/next whitelist sequencer addresses with epoch-boundary expiry.
#[derive(Debug)]
pub(crate) struct WhitelistSequencerCache {
    /// Minimum interval between L1 refreshes triggered by signer mismatches.
    miss_refresh_cooldown: Duration,
    /// Last time a signer mismatch forced invalidation + refresh.
    last_miss_refresh_at: Option<Instant>,
    /// Cached current-epoch sequencer address and fetch time.
    current: Option<(Address, Instant)>,
    /// Cached next-epoch sequencer address and fetch time.
    next: Option<(Address, Instant)>,
    /// Cached current epoch start timestamp for the stored sequencer pair.
    current_epoch_start_timestamp: Option<u64>,
    /// Block timestamp for the block used to fetch the cached sequencer pair.
    current_snapshot_block_timestamp: Option<u64>,
}

impl Default for WhitelistSequencerCache {
    /// Create a sequencer cache using the default configuration.
    fn default() -> Self {
        Self::new()
    }
}

impl WhitelistSequencerCache {
    /// Create a sequencer cache with default miss-refresh cooldown.
    pub fn new() -> Self {
        Self::with_cooldowns(Duration::from_secs(DEFAULT_SEQUENCER_MISS_REFRESH_COOLDOWN_SECS))
    }

    /// Create a sequencer cache with a custom signer-miss refresh cooldown.
    ///
    /// `miss_refresh_cooldown` only gates forced refreshes triggered by signer mismatches.
    pub fn with_cooldowns(miss_refresh_cooldown: Duration) -> Self {
        Self {
            miss_refresh_cooldown,
            last_miss_refresh_at: None,
            current: None,
            next: None,
            current_epoch_start_timestamp: None,
            current_snapshot_block_timestamp: None,
        }
    }

    /// Return the cached current-epoch sequencer if the current epoch has not ended.
    ///
    /// Expiry is derived from the epoch boundary: the cache is valid while
    /// `snapshot_block_timestamp + elapsed <= current_epoch_start_timestamp +
    /// L1_EPOCH_DURATION_SECS`.
    pub fn get_current(&self) -> Option<Address> {
        let (addr, _) = self.current?;
        self.is_epoch_valid().then_some(addr)
    }

    /// Return the cached next-epoch sequencer if the current epoch has not ended.
    ///
    /// Expiry is derived from the epoch boundary: the cache is valid while
    /// `snapshot_block_timestamp + elapsed <= current_epoch_start_timestamp +
    /// L1_EPOCH_DURATION_SECS`.
    pub fn get_next(&self) -> Option<Address> {
        let (addr, _) = self.next?;
        self.is_epoch_valid().then_some(addr)
    }

    /// Return `true` when the estimated current L1 time is still within the cached epoch.
    fn is_epoch_valid(&self) -> bool {
        let Some(epoch_start) = self.current_epoch_start_timestamp else { return false };
        let Some(snapshot_ts) = self.current_snapshot_block_timestamp else { return false };
        let Some(fetched_at) = self.current_fetched_at() else { return false };
        let elapsed = Instant::now().saturating_duration_since(fetched_at).as_secs();
        let estimated_now = snapshot_ts.saturating_add(elapsed);
        estimated_now < epoch_start.saturating_add(L1_EPOCH_DURATION_SECS)
    }

    /// Return the `Instant` at which the current-epoch entry was cached.
    fn current_fetched_at(&self) -> Option<Instant> {
        self.current.map(|(_, fetched_at)| fetched_at)
    }

    /// Return true when signer-mismatch handling may force a fresh L1 read.
    pub fn allow_miss_refresh(&mut self, now: Instant) -> bool {
        if let Some(last) = self.last_miss_refresh_at &&
            now.saturating_duration_since(last) < self.miss_refresh_cooldown
        {
            return false;
        }
        self.last_miss_refresh_at = Some(now);
        true
    }

    /// Clear both cached entries, forcing the next lookup to re-fetch from L1.
    pub fn invalidate(&mut self) {
        self.current = None;
        self.next = None;
        self.current_epoch_start_timestamp = None;
        self.current_snapshot_block_timestamp = None;
    }

    /// Store a paired current/next sequencer snapshot and the corresponding epoch start timestamp.
    pub fn set_pair(
        &mut self,
        current: Address,
        next: Address,
        current_epoch_start_timestamp: u64,
        snapshot_block_timestamp: u64,
        now: Instant,
    ) {
        self.current = Some((current, now));
        self.next = Some((next, now));
        self.current_epoch_start_timestamp = Some(current_epoch_start_timestamp);
        self.current_snapshot_block_timestamp = Some(snapshot_block_timestamp);
    }

    /// Return stale current/next pair only when both entries are not older than `max_stale`.
    pub fn get_stale_pair_within(
        &self,
        now: Instant,
        max_stale: Duration,
    ) -> Option<(Address, Address)> {
        let (current, current_fetched_at) = self.current?;
        let (next, next_fetched_at) = self.next?;
        if now.saturating_duration_since(current_fetched_at) > max_stale {
            return None;
        }
        if now.saturating_duration_since(next_fetched_at) > max_stale {
            return None;
        }
        Some((current, next))
    }

    /// Return the cached current epoch start timestamp, if a sequencer pair is present.
    pub fn current_epoch_start_timestamp(&self) -> Option<u64> {
        self.current_epoch_start_timestamp
    }

    /// Return true if `l1_block_timestamp` is in a later epoch than the cached pair.
    pub fn should_invalidate_for_l1_timestamp(
        &self,
        l1_block_timestamp: u64,
        epoch_duration_secs: u64,
    ) -> bool {
        self.current_epoch_start_timestamp.is_some_and(|cached_epoch_start| {
            l1_block_timestamp >= cached_epoch_start.saturating_add(epoch_duration_secs)
        })
    }

    /// Return `true` if a snapshot taken at `block_timestamp` can replace cached values.
    ///
    /// This prevents a lagging RPC node from overwriting a newer-epoch cached snapshot and
    /// rejects implausibly far-future timestamps from a misbehaving node.
    pub fn should_accept_block_timestamp(&self, block_timestamp: u64) -> bool {
        self.current_epoch_start_timestamp.is_none_or(|cached_epoch_start| {
            let max_reasonable_timestamp =
                cached_epoch_start.saturating_add(L1_EPOCH_DURATION_SECS.saturating_mul(2));
            block_timestamp >= cached_epoch_start && block_timestamp < max_reasonable_timestamp
        })
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
    fn recent_cache_gets_by_hash_and_eviction_is_bounded() {
        let mut recent = RecentEnvelopeCache::with_capacity(2);
        let h1 = B256::from([0x01u8; 32]);
        let h2 = B256::from([0x02u8; 32]);
        let h3 = B256::from([0x03u8; 32]);

        recent.insert_recent(Arc::new(sample_envelope(h1, 1)));
        recent.insert_recent(Arc::new(sample_envelope(h2, 2)));
        assert!(recent.get_recent(&h1).is_some());
        assert!(recent.get_recent(&h2).is_some());

        recent.insert_recent(Arc::new(sample_envelope(h3, 3)));
        assert!(recent.get_recent(&h1).is_none());
        assert!(recent.get_recent(&h2).is_some());
        assert!(recent.get_recent(&h3).is_some());
        assert_eq!(recent.len(), 2);
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

    #[test]
    fn pending_cache_eviction_is_bounded() {
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
    }

    #[test]
    fn pending_cache_remove_keeps_insertion_order_consistent() {
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
    fn pending_cache_sort_tiebreak_is_deterministic() {
        let mut cache = EnvelopeCache::with_capacity(4);
        let h1 = B256::from([0x11u8; 32]);
        let h2 = B256::from([0x22u8; 32]);
        let h3 = B256::from([0x33u8; 32]);

        cache.insert(Arc::new(sample_envelope(h2, 7)));
        cache.insert(Arc::new(sample_envelope(h1, 7)));
        cache.insert(Arc::new(sample_envelope(h3, 8)));

        assert_eq!(cache.sorted_hashes_by_block_number(), vec![h1, h2, h3]);
    }

    /// Fixed epoch start used by tests — far enough from any boundary to avoid flakiness.
    const TEST_EPOCH_START: u64 = 1_000_000;

    #[test]
    fn sequencer_cache_returns_none_when_empty() {
        let cache = WhitelistSequencerCache::new();
        assert!(cache.get_current().is_none());
        assert!(cache.get_next().is_none());
    }

    #[test]
    fn sequencer_cache_returns_cached_value_within_epoch() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let addr = Address::from([0xaau8; 20]);

        cache.set_pair(addr, addr, TEST_EPOCH_START, TEST_EPOCH_START + 12, now);

        assert_eq!(cache.get_current(), Some(addr));
        assert_eq!(cache.get_next(), Some(addr));
    }

    #[test]
    fn sequencer_cache_expires_at_epoch_boundary() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let addr = Address::from([0xbbu8; 20]);

        cache.set_pair(
            addr,
            addr,
            TEST_EPOCH_START,
            TEST_EPOCH_START,
            now - Duration::from_secs(L1_EPOCH_DURATION_SECS + 1),
        );

        assert!(cache.get_current().is_none());
        assert!(cache.get_next().is_none());
    }

    #[test]
    fn sequencer_cache_invalidate_clears_both_entries() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let addr = Address::from([0xccu8; 20]);

        cache.set_pair(addr, addr, TEST_EPOCH_START, TEST_EPOCH_START + 10, now);
        assert!(cache.get_current().is_some());
        assert!(cache.get_next().is_some());

        cache.invalidate();
        assert!(cache.get_current().is_none());
        assert!(cache.get_next().is_none());
    }

    #[test]
    fn sequencer_cache_set_replaces_previous_entry() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let addr1 = Address::from([0x11u8; 20]);
        let addr2 = Address::from([0x22u8; 20]);

        cache.set_pair(addr1, addr1, TEST_EPOCH_START, TEST_EPOCH_START + 10, now);
        assert_eq!(cache.get_current(), Some(addr1));

        cache.set_pair(
            addr2,
            addr2,
            TEST_EPOCH_START,
            TEST_EPOCH_START + 11,
            now + Duration::from_secs(1),
        );
        assert_eq!(cache.get_current(), Some(addr2));
    }

    #[test]
    fn sequencer_cache_set_pair_updates_distinct_current_and_next() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let current = Address::from([0x31u8; 20]);
        let next = Address::from([0x42u8; 20]);

        cache.set_pair(current, next, TEST_EPOCH_START, TEST_EPOCH_START + 5, now);

        assert_eq!(cache.get_current(), Some(current));
        assert_eq!(cache.get_next(), Some(next));
    }

    #[test]
    fn sequencer_cache_invalidate_resets_timestamp_guard() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        cache.set_pair(Address::from([0x51u8; 20]), Address::from([0x52u8; 20]), 1_500, 1_500, now);
        assert!(!cache.should_accept_block_timestamp(1_499));

        cache.invalidate();
        assert!(cache.should_accept_block_timestamp(1_000));
    }

    #[test]
    fn sequencer_cache_miss_refresh_is_rate_limited() {
        let mut cache = WhitelistSequencerCache::with_cooldowns(Duration::from_secs(2));
        let now = Instant::now();

        assert!(cache.allow_miss_refresh(now));
        assert!(!cache.allow_miss_refresh(now + Duration::from_secs(1)));
        assert!(cache.allow_miss_refresh(now + Duration::from_secs(3)));
    }

    #[test]
    fn sequencer_cache_stale_values_are_available_after_epoch_expiry() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let current = Address::from([0xddu8; 20]);
        let next = Address::from([0xeeu8; 20]);

        // Snapshot block timestamp is already at the epoch boundary, so even
        // a tiny Instant elapsed pushes estimated_now past the epoch end.
        // The Instant `fetched_at` stays recent so get_stale_pair_within still works.
        let snapshot_ts = TEST_EPOCH_START + L1_EPOCH_DURATION_SECS - 1;
        cache.set_pair(current, next, TEST_EPOCH_START, snapshot_ts, now);

        // Allow a moment so Instant::now() inside get_current/get_next advances
        // past the epoch boundary (snapshot_ts + elapsed >= epoch_end).
        std::thread::sleep(Duration::from_secs(2));

        assert!(cache.get_current().is_none());
        assert!(cache.get_next().is_none());
        // Stale pair is still available via the Instant-based staleness window.
        assert_eq!(
            cache.get_stale_pair_within(Instant::now(), Duration::from_secs(15)),
            Some((current, next))
        );
    }

    #[test]
    fn sequencer_cache_stale_pair_within_allows_recent_entries() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        let current = Address::from([0x81u8; 20]);
        let next = Address::from([0x82u8; 20]);

        cache.set_pair(current, next, 1_000, 1_000, now);
        assert_eq!(
            cache.get_stale_pair_within(now + Duration::from_secs(5), Duration::from_secs(7)),
            Some((current, next))
        );
    }

    #[test]
    fn sequencer_cache_stale_pair_within_rejects_old_entries() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        cache.set_pair(Address::from([0x91u8; 20]), Address::from([0x92u8; 20]), 1_000, 1_000, now);
        assert_eq!(
            cache.get_stale_pair_within(now + Duration::from_secs(9), Duration::from_secs(8)),
            None
        );
    }

    #[test]
    fn sequencer_cache_rejects_regressive_block_timestamp_updates() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();

        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_200, 1_300, now);
        assert!(!cache.should_accept_block_timestamp(1_199));
        assert!(cache.should_accept_block_timestamp(1_200));
        assert!(cache.should_accept_block_timestamp(1_201));
    }

    #[test]
    fn sequencer_cache_rejects_implausibly_future_block_timestamp_updates() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_200, 1_300, now);

        let boundary = 1_200 + (L1_EPOCH_DURATION_SECS * 2);
        assert!(cache.should_accept_block_timestamp(boundary - 1));
        assert!(!cache.should_accept_block_timestamp(boundary));
    }

    #[test]
    fn sequencer_cache_reports_cached_epoch_start_timestamp() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        assert_eq!(cache.current_epoch_start_timestamp(), None);

        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_234, 1_234, now);
        assert_eq!(cache.current_epoch_start_timestamp(), Some(1_234));
    }

    #[test]
    fn sequencer_cache_invalidate_for_l1_timestamp_requires_epoch_crossing() {
        let mut cache = WhitelistSequencerCache::new();
        let now = Instant::now();
        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_000, 1_000, now);

        assert!(!cache.should_invalidate_for_l1_timestamp(1_383, 384));
        assert!(cache.should_invalidate_for_l1_timestamp(1_384, 384));
    }

    #[test]
    fn sequencer_cache_invalidate_for_l1_timestamp_is_false_when_empty() {
        let cache = WhitelistSequencerCache::new();
        assert!(!cache.should_invalidate_for_l1_timestamp(1_384, 384));
    }

    #[test]
    fn pending_cache_duplicate_insert_refreshes_recency() {
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
}
