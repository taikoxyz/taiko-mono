//! In-memory cache for out-of-order whitelist preconfirmation envelopes.

use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256};
use hashlink::LinkedHashMap;

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Default maximum number of recently validated envelopes retained for serving responses.
const DEFAULT_RECENT_ENVELOPE_CAPACITY: usize = 1024;
/// Default maximum number of pending envelopes retained while waiting for parents.
const DEFAULT_PENDING_ENVELOPE_CAPACITY: usize = 768;
/// Default cooldown, in seconds, between duplicate parent-hash requests.
const DEFAULT_REQUEST_COOLDOWN_SECS: u64 = 10;
/// One L1 epoch (32 slots x 12 seconds).
pub(crate) const L1_EPOCH_DURATION_SECS: u64 = 12 * 32;
/// Default TTL for cached whitelist sequencer addresses (one L1 epoch = 32 slots).
const DEFAULT_SEQUENCER_CACHE_TTL_SECS: u64 = L1_EPOCH_DURATION_SECS;
/// Minimum interval between forced signer-miss refreshes from L1.
const DEFAULT_SEQUENCER_MISS_REFRESH_COOLDOWN_SECS: u64 = 2;

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
    /// End-of-sequencing envelope index keyed by beacon epoch.
    end_of_sequencing_by_epoch: LinkedHashMap<u64, B256>,
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
        Self {
            entries: LinkedHashMap::with_capacity(capacity),
            end_of_sequencing_by_epoch: LinkedHashMap::with_capacity(capacity),
            capacity,
        }
    }

    /// Insert or replace a recent envelope.
    pub fn insert_recent(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        self.insert_recent_with_epoch_hint(envelope, None);
    }

    /// Insert or replace a recent envelope with optional EOS epoch index.
    pub fn insert_recent_with_epoch_hint(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
        eos_epoch: Option<u64>,
    ) {
        let hash = envelope.execution_payload.block_hash;
        self.entries.remove(&hash);
        self.entries.insert(hash, envelope);
        if let Some(epoch) = eos_epoch {
            self.end_of_sequencing_by_epoch.remove(&epoch);
            self.end_of_sequencing_by_epoch.insert(epoch, hash);
        }
        self.evict_oldest();
    }

    /// Evict oldest entries until capacity is satisfied.
    fn evict_oldest(&mut self) {
        while self.entries.len() > self.capacity {
            let Some((evicted_hash, _)) = self.entries.pop_front() else {
                break;
            };
            self.end_of_sequencing_by_epoch.retain(|_, indexed_hash| *indexed_hash != evicted_hash);
        }
        while self.end_of_sequencing_by_epoch.len() > self.capacity {
            let _ = self.end_of_sequencing_by_epoch.pop_front();
        }
    }

    /// Get a recent envelope by block hash.
    pub fn get_recent(&self, hash: &B256) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.entries.get(hash).cloned()
    }

    /// Get the most recently inserted end-of-sequencing envelope.
    #[cfg(test)]
    pub fn latest_end_of_sequencing(&self) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.entries.iter().rev().find_map(|(_, envelope)| {
            envelope.end_of_sequencing.unwrap_or(false).then(|| envelope.clone())
        })
    }

    /// Get an end-of-sequencing envelope for a specific beacon epoch.
    pub fn end_of_sequencing_for_epoch(
        &self,
        epoch: u64,
    ) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        let hash = self.end_of_sequencing_by_epoch.get(&epoch)?;
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

/// Cached pair of current/next whitelist sequencer addresses with a TTL.
#[derive(Debug)]
pub(crate) struct WhitelistSequencerCache {
    /// TTL for cached entries.
    ttl: Duration,
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
}

impl Default for WhitelistSequencerCache {
    fn default() -> Self {
        Self::new(Duration::from_secs(DEFAULT_SEQUENCER_CACHE_TTL_SECS))
    }
}

impl WhitelistSequencerCache {
    /// Create a sequencer cache with a custom TTL.
    pub fn new(ttl: Duration) -> Self {
        Self::with_cooldowns(ttl, Duration::from_secs(DEFAULT_SEQUENCER_MISS_REFRESH_COOLDOWN_SECS))
    }

    /// Create a sequencer cache with custom TTL and signer-miss refresh cooldown.
    ///
    /// `miss_refresh_cooldown` only gates forced refreshes triggered by signer mismatches.
    /// Normal TTL expiry refreshes are still allowed even when `miss_refresh_cooldown > ttl`.
    pub fn with_cooldowns(ttl: Duration, miss_refresh_cooldown: Duration) -> Self {
        Self {
            ttl,
            miss_refresh_cooldown,
            last_miss_refresh_at: None,
            current: None,
            next: None,
            current_epoch_start_timestamp: None,
        }
    }

    /// Return the cached current-epoch sequencer if still fresh.
    pub fn get_current(&self, now: Instant) -> Option<Address> {
        self.current
            .filter(|(_, fetched_at)| now.saturating_duration_since(*fetched_at) < self.ttl)
            .map(|(addr, _)| addr)
    }

    /// Return the cached next-epoch sequencer if still fresh.
    pub fn get_next(&self, now: Instant) -> Option<Address> {
        self.next
            .filter(|(_, fetched_at)| now.saturating_duration_since(*fetched_at) < self.ttl)
            .map(|(addr, _)| addr)
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
    }

    /// Store a paired current/next sequencer snapshot and the corresponding epoch start timestamp.
    pub fn set_pair(
        &mut self,
        current: Address,
        next: Address,
        current_epoch_start_timestamp: u64,
        now: Instant,
    ) {
        self.current = Some((current, now));
        self.next = Some((next, now));
        self.current_epoch_start_timestamp = Some(current_epoch_start_timestamp);
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
        self.current_epoch_start_timestamp
            .map(|cached_epoch_start| {
                l1_block_timestamp >= cached_epoch_start.saturating_add(epoch_duration_secs)
            })
            .unwrap_or(false)
    }

    /// Return `true` if a snapshot taken at `block_timestamp` can replace cached values.
    ///
    /// This prevents a lagging RPC node from overwriting a newer-epoch cached snapshot and
    /// rejects implausibly far-future timestamps from a misbehaving node.
    pub fn should_accept_block_timestamp(&self, block_timestamp: u64) -> bool {
        self.current_epoch_start_timestamp
            .map(|cached_epoch_start| {
                let max_reasonable_timestamp =
                    cached_epoch_start.saturating_add(L1_EPOCH_DURATION_SECS.saturating_mul(2));
                block_timestamp >= cached_epoch_start && block_timestamp < max_reasonable_timestamp
            })
            .unwrap_or(true)
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
    fn recent_cache_tracks_latest_end_of_sequencing_envelope() {
        let mut recent = RecentEnvelopeCache::with_capacity(3);
        let h1 = B256::from([0x11u8; 32]);
        let h2 = B256::from([0x22u8; 32]);
        let h3 = B256::from([0x33u8; 32]);

        let mut first = sample_envelope(h1, 1);
        first.end_of_sequencing = Some(true);
        recent.insert_recent(Arc::new(first));
        recent.insert_recent(Arc::new(sample_envelope(h2, 2)));

        let mut second = sample_envelope(h3, 3);
        second.end_of_sequencing = Some(true);
        recent.insert_recent(Arc::new(second));

        let latest = recent.latest_end_of_sequencing().expect("latest EOS envelope");
        assert_eq!(latest.execution_payload.block_hash, h3);
    }

    #[test]
    fn recent_cache_serves_end_of_sequencing_by_epoch() {
        let mut recent = RecentEnvelopeCache::with_capacity(3);
        let h1 = B256::from([0x41u8; 32]);
        let h2 = B256::from([0x42u8; 32]);

        let mut first = sample_envelope(h1, 1);
        first.end_of_sequencing = Some(true);
        recent.insert_recent_with_epoch_hint(Arc::new(first), Some(100));

        let mut second = sample_envelope(h2, 2);
        second.end_of_sequencing = Some(true);
        recent.insert_recent_with_epoch_hint(Arc::new(second), Some(101));

        let epoch_100 = recent.end_of_sequencing_for_epoch(100).expect("epoch 100 must exist");
        assert_eq!(epoch_100.execution_payload.block_hash, h1);

        let epoch_101 = recent.end_of_sequencing_for_epoch(101).expect("epoch 101 must exist");
        assert_eq!(epoch_101.execution_payload.block_hash, h2);
        assert!(recent.end_of_sequencing_for_epoch(999).is_none());
    }

    #[test]
    fn recent_cache_eviction_prunes_epoch_index() {
        let mut recent = RecentEnvelopeCache::with_capacity(1);
        let h1 = B256::from([0x51u8; 32]);
        let h2 = B256::from([0x52u8; 32]);

        let mut first = sample_envelope(h1, 1);
        first.end_of_sequencing = Some(true);
        recent.insert_recent_with_epoch_hint(Arc::new(first), Some(200));

        let mut second = sample_envelope(h2, 2);
        second.end_of_sequencing = Some(true);
        recent.insert_recent_with_epoch_hint(Arc::new(second), Some(201));

        assert!(recent.end_of_sequencing_for_epoch(200).is_none());
        assert!(recent.end_of_sequencing_for_epoch(201).is_some());
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

    #[test]
    fn sequencer_cache_returns_none_when_empty() {
        let cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        assert!(cache.get_current(now).is_none());
        assert!(cache.get_next(now).is_none());
    }

    #[test]
    fn sequencer_cache_returns_cached_value_within_ttl() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let addr = Address::from([0xaau8; 20]);

        cache.set_pair(addr, addr, 0, now);

        assert_eq!(cache.get_current(now + Duration::from_secs(5)), Some(addr));
        assert_eq!(cache.get_next(now + Duration::from_secs(5)), Some(addr));
    }

    #[test]
    fn sequencer_cache_expires_after_ttl() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let addr = Address::from([0xbbu8; 20]);

        cache.set_pair(addr, addr, 0, now);

        assert!(cache.get_current(now + Duration::from_secs(11)).is_none());
        assert!(cache.get_next(now + Duration::from_secs(11)).is_none());
    }

    #[test]
    fn sequencer_cache_invalidate_clears_both_entries() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let addr = Address::from([0xccu8; 20]);

        cache.set_pair(addr, addr, 0, now);
        assert!(cache.get_current(now).is_some());
        assert!(cache.get_next(now).is_some());

        cache.invalidate();
        assert!(cache.get_current(now).is_none());
        assert!(cache.get_next(now).is_none());
    }

    #[test]
    fn sequencer_cache_set_replaces_previous_entry() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let addr1 = Address::from([0x11u8; 20]);
        let addr2 = Address::from([0x22u8; 20]);

        cache.set_pair(addr1, addr1, 100, now);
        assert_eq!(cache.get_current(now), Some(addr1));

        cache.set_pair(addr2, addr2, 101, now + Duration::from_secs(1));
        assert_eq!(cache.get_current(now + Duration::from_secs(1)), Some(addr2));
    }

    #[test]
    fn sequencer_cache_set_pair_updates_distinct_current_and_next() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let current = Address::from([0x31u8; 20]);
        let next = Address::from([0x42u8; 20]);

        cache.set_pair(current, next, 777, now);

        assert_eq!(cache.get_current(now), Some(current));
        assert_eq!(cache.get_next(now), Some(next));
    }

    #[test]
    fn sequencer_cache_invalidate_resets_timestamp_guard() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        cache.set_pair(Address::from([0x51u8; 20]), Address::from([0x52u8; 20]), 1_500, now);
        assert!(!cache.should_accept_block_timestamp(1_499));

        cache.invalidate();
        assert!(cache.should_accept_block_timestamp(1_000));
    }

    #[test]
    fn sequencer_cache_miss_refresh_is_rate_limited() {
        let mut cache = WhitelistSequencerCache::with_cooldowns(
            Duration::from_secs(10),
            Duration::from_secs(2),
        );
        let now = Instant::now();

        assert!(cache.allow_miss_refresh(now));
        assert!(!cache.allow_miss_refresh(now + Duration::from_secs(1)));
        assert!(cache.allow_miss_refresh(now + Duration::from_secs(3)));
    }

    #[test]
    fn sequencer_cache_stale_values_are_available_after_ttl_expiry() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let current = Address::from([0xddu8; 20]);
        let next = Address::from([0xeeu8; 20]);

        cache.set_pair(current, next, 1_000, now);

        assert!(cache.get_current(now + Duration::from_secs(11)).is_none());
        assert!(cache.get_next(now + Duration::from_secs(11)).is_none());
        assert_eq!(
            cache.get_stale_pair_within(now + Duration::from_secs(11), Duration::from_secs(15)),
            Some((current, next))
        );
    }

    #[test]
    fn sequencer_cache_stale_pair_within_allows_recent_entries() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        let current = Address::from([0x81u8; 20]);
        let next = Address::from([0x82u8; 20]);

        cache.set_pair(current, next, 1_000, now);
        assert_eq!(
            cache.get_stale_pair_within(now + Duration::from_secs(5), Duration::from_secs(7)),
            Some((current, next))
        );
    }

    #[test]
    fn sequencer_cache_stale_pair_within_rejects_old_entries() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        cache.set_pair(Address::from([0x91u8; 20]), Address::from([0x92u8; 20]), 1_000, now);
        assert_eq!(
            cache.get_stale_pair_within(now + Duration::from_secs(9), Duration::from_secs(8)),
            None
        );
    }

    #[test]
    fn sequencer_cache_rejects_regressive_block_timestamp_updates() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();

        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_200, now);
        assert!(!cache.should_accept_block_timestamp(1_199));
        assert!(cache.should_accept_block_timestamp(1_200));
        assert!(cache.should_accept_block_timestamp(1_201));
    }

    #[test]
    fn sequencer_cache_rejects_implausibly_future_block_timestamp_updates() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_200, now);

        let boundary = 1_200 + (L1_EPOCH_DURATION_SECS * 2);
        assert!(cache.should_accept_block_timestamp(boundary - 1));
        assert!(!cache.should_accept_block_timestamp(boundary));
    }

    #[test]
    fn sequencer_cache_reports_cached_epoch_start_timestamp() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        assert_eq!(cache.current_epoch_start_timestamp(), None);

        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_234, now);
        assert_eq!(cache.current_epoch_start_timestamp(), Some(1_234));
    }

    #[test]
    fn sequencer_cache_invalidate_for_l1_timestamp_requires_epoch_crossing() {
        let mut cache = WhitelistSequencerCache::new(Duration::from_secs(10));
        let now = Instant::now();
        cache.set_pair(Address::from([0x01u8; 20]), Address::from([0x02u8; 20]), 1_000, now);

        assert!(!cache.should_invalidate_for_l1_timestamp(1_383, 384));
        assert!(cache.should_invalidate_for_l1_timestamp(1_384, 384));
    }

    #[test]
    fn sequencer_cache_invalidate_for_l1_timestamp_is_false_when_empty() {
        let cache = WhitelistSequencerCache::new(Duration::from_secs(10));
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
