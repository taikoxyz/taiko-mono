//! In-memory cache for out-of-order whitelist preconfirmation envelopes.

use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use hashlink::LinkedHashMap;

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Default maximum number of recently validated envelopes retained for serving responses.
const DEFAULT_RECENT_ENVELOPE_CAPACITY: usize = 1024;
/// Default maximum number of pending envelopes retained while waiting for parents.
const DEFAULT_PENDING_ENVELOPE_CAPACITY: usize = 768;
/// Default cooldown, in seconds, between duplicate parent-hash requests.
const DEFAULT_REQUEST_COOLDOWN_SECS: u64 = 10;

/// Simple in-memory cache keyed by block hash with bounded capacity.
pub(crate) struct EnvelopeCache {
    /// Fast lookup table keyed by payload block hash.
    entries: LinkedHashMap<B256, WhitelistExecutionPayloadEnvelope>,
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
    pub fn insert(&mut self, envelope: WhitelistExecutionPayloadEnvelope) {
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
    pub fn remove(&mut self, hash: &B256) -> Option<WhitelistExecutionPayloadEnvelope> {
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
    pub fn get(&self, hash: &B256) -> Option<&WhitelistExecutionPayloadEnvelope> {
        self.entries.get(hash)
    }

    /// Returns true when the cache is empty.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

/// Recently seen validated envelopes used for serving request topic responses.
#[derive(Debug)]
pub(crate) struct RecentEnvelopeCache {
    /// Fast lookup table keyed by payload block hash.
    entries: LinkedHashMap<B256, WhitelistExecutionPayloadEnvelope>,
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
    pub fn insert_recent(&mut self, envelope: WhitelistExecutionPayloadEnvelope) {
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
    pub fn get_recent(&self, hash: &B256) -> Option<WhitelistExecutionPayloadEnvelope> {
        self.entries.get(hash).cloned()
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

    /// Return `true` if the hash should be requested at `now`, then records the request.
    pub fn should_request(&mut self, hash: B256, now: Instant) -> bool {
        match self.requested_at.get(&hash) {
            Some(last) if now.duration_since(*last) < self.cooldown => false,
            _ => {
                self.requested_at.insert(hash, now);
                true
            }
        }
    }
}

#[cfg(test)]
mod tests {
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

        recent.insert_recent(sample_envelope(h1, 1));
        recent.insert_recent(sample_envelope(h2, 2));
        assert!(recent.get_recent(&h1).is_some());
        assert!(recent.get_recent(&h2).is_some());

        recent.insert_recent(sample_envelope(h3, 3));
        assert!(recent.get_recent(&h1).is_none());
        assert!(recent.get_recent(&h2).is_some());
        assert!(recent.get_recent(&h3).is_some());
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
    fn pending_cache_eviction_is_bounded() {
        let mut cache = EnvelopeCache::with_capacity(2);
        let h1 = B256::from([0x10u8; 32]);
        let h2 = B256::from([0x20u8; 32]);
        let h3 = B256::from([0x30u8; 32]);

        cache.insert(sample_envelope(h1, 1));
        cache.insert(sample_envelope(h2, 2));
        cache.insert(sample_envelope(h3, 3));

        let hashes = cache.sorted_hashes_by_block_number();
        assert_eq!(hashes, vec![h2, h3]);
    }

    #[test]
    fn pending_cache_remove_keeps_insertion_order_consistent() {
        let mut cache = EnvelopeCache::with_capacity(3);
        let h1 = B256::from([0x40u8; 32]);
        let h2 = B256::from([0x50u8; 32]);
        let h3 = B256::from([0x60u8; 32]);

        cache.insert(sample_envelope(h1, 1));
        cache.insert(sample_envelope(h2, 2));
        cache.insert(sample_envelope(h3, 3));
        let removed = cache.remove(&h2);
        assert!(removed.is_some());

        cache.insert(sample_envelope(B256::from([0x70u8; 32]), 4));
        let hashes = cache.sorted_hashes_by_block_number();
        assert_eq!(hashes, vec![h1, h3, B256::from([0x70u8; 32])]);
    }

    #[test]
    fn pending_cache_sort_tiebreak_is_deterministic() {
        let mut cache = EnvelopeCache::with_capacity(4);
        let h1 = B256::from([0x11u8; 32]);
        let h2 = B256::from([0x22u8; 32]);
        let h3 = B256::from([0x33u8; 32]);

        cache.insert(sample_envelope(h2, 7));
        cache.insert(sample_envelope(h1, 7));
        cache.insert(sample_envelope(h3, 8));

        assert_eq!(cache.sorted_hashes_by_block_number(), vec![h1, h2, h3]);
    }

    #[test]
    fn pending_cache_duplicate_insert_refreshes_recency() {
        let mut cache = EnvelopeCache::with_capacity(2);
        let h1 = B256::from([0x44u8; 32]);
        let h2 = B256::from([0x55u8; 32]);
        let h3 = B256::from([0x66u8; 32]);

        cache.insert(sample_envelope(h1, 1));
        cache.insert(sample_envelope(h2, 2));
        cache.insert(sample_envelope(h1, 3));
        cache.insert(sample_envelope(h3, 4));

        assert!(cache.get(&h1).is_some());
        assert!(cache.get(&h2).is_none());
        assert!(cache.get(&h3).is_some());
        assert_eq!(cache.sorted_hashes_by_block_number().len(), 2);
    }
}
