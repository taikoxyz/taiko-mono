//! Cache for proofs that arrived out of order, keyed by proposal id.
//!
//! Proofs enter the [`ProofBuffer`] only contiguously; anything ahead of the
//! buffer cursor parks here until the gap fills (Go `proof_submitter.go:281-332`
//! routing plus the `flushContiguousProofCache`/`flushProofCacheRange` helpers).

use dashmap::DashMap;
use thiserror::Error;

use crate::{buffer::ProofBuffer, producer::ProofResponse};

/// Cache outcomes that are control flow, not failures.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum CacheError {
    /// The requested id was not cached; flushing stops there. Callers treat
    /// this as "done for now" (Go ignores `ErrCacheNotFound`,
    /// `proof_submitter.go:626-635`).
    #[error("proof cache miss for proposal {0}")]
    CacheMiss(u64),
}

/// Out-of-order proof cache for one proof type.
#[derive(Debug, Default)]
pub struct ProofCache {
    /// Cached proofs keyed by proposal id.
    map: DashMap<u64, ProofResponse>,
}

impl ProofCache {
    /// Create an empty cache.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Insert a proof, replacing any previous entry for the same proposal
    /// (last-write-wins, like Go's `cacheMap.Set`).
    pub fn insert(&self, response: ProofResponse) {
        self.map.insert(response.proposal_id(), response);
    }

    /// After `written_id` entered the buffer, drain `written_id + 1, + 2, ...`
    /// from the cache into the buffer until the first gap or the buffer fills.
    /// Entries leave the cache only once the buffer accepted them.
    ///
    /// Delegates to [`Self::flush_range`] over `written_id + 1 ..= written_id +
    /// available_capacity`, mirroring Go's `flushContiguousProofCache` ->
    /// `flushProofCacheRange`. A gap surfaces as [`CacheError::CacheMiss`] and
    /// simply means "done for now" (Go ignores `ErrCacheNotFound`).
    pub fn flush_contiguous(&self, written_id: u64, buffer: &ProofBuffer) {
        let from = written_id.saturating_add(1);
        let to = written_id.saturating_add(buffer.available_capacity());
        let _ = self.flush_range(from, to, buffer);
    }

    /// Flush `from..=to` strictly in order; the first missing id aborts with
    /// [`CacheError::CacheMiss`]. Stops early (without error) when the buffer
    /// fills. Entries leave the cache only once the buffer accepted them.
    pub fn flush_range(&self, from: u64, to: u64, buffer: &ProofBuffer) -> Result<(), CacheError> {
        for id in from..=to {
            if buffer.available_capacity() == 0 {
                return Ok(());
            }
            let Some(entry) = self.cloned(id) else {
                return Err(CacheError::CacheMiss(id));
            };
            if buffer.write(entry).is_err() {
                return Ok(());
            }
            self.map.remove(&id);
        }
        Ok(())
    }

    /// Clone the cached proof for `id` without removing it.
    fn cloned(&self, id: u64) -> Option<ProofResponse> {
        self.map.get(&id).map(|entry| entry.value().clone())
    }

    /// Drop all entries with id at or below `last_finalized` (stale-cache
    /// cleanup); returns how many were removed.
    pub fn prune_finalized(&self, last_finalized: u64) -> usize {
        let before = self.map.len();
        self.map.retain(|id, _| *id > last_finalized);
        before - self.map.len()
    }

    /// Remove and return every cached proof (used when flushing ZK caches on
    /// entering SGX-draining mode). Keys are collected before removal so the
    /// `DashMap` is never iterated while a shard is being mutated.
    pub fn drain_all(&self) -> Vec<ProofResponse> {
        let ids: Vec<u64> = self.map.iter().map(|entry| *entry.key()).collect();
        ids.into_iter().filter_map(|id| self.map.remove(&id).map(|(_, value)| value)).collect()
    }

    /// Number of cached proofs.
    #[must_use]
    pub fn len(&self) -> usize {
        self.map.len()
    }

    /// True when no proofs are cached.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.map.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, B256, Bytes};

    use super::{CacheError, ProofCache};
    use crate::{
        buffer::ProofBuffer,
        producer::{ProofRequest, ProofResponse},
        raiko::ProofType,
    };

    /// Build a minimal proof response for the given proposal id.
    fn test_response(proposal_id: u64) -> ProofResponse {
        ProofResponse {
            request: ProofRequest {
                proposal_id,
                proposer: Address::repeat_byte(0x11),
                proposal_timestamp: 1_000,
                event_l1_block_number: 42,
                event_l1_block_hash: B256::repeat_byte(0x22),
                prover_address: Address::repeat_byte(0x33),
                l2_block_numbers: vec![100],
                end_block_number: 100,
                end_block_hash: B256::repeat_byte(0x44),
                end_state_root: B256::repeat_byte(0x55),
                last_anchor_block_number: 40,
                geth_proof_generated: false,
                reth_proof_generated: false,
                geth_aggregation_generated: false,
                reth_aggregation_generated: false,
            },
            proof: Bytes::from_static(&[0xbb]),
            proof_type: ProofType::Sgx,
        }
    }

    /// Buffer pre-loaded with the given ids.
    fn buffer_with(max: u64, ids: &[u64]) -> ProofBuffer {
        let buffer = ProofBuffer::new(max);
        for id in ids {
            buffer.write(test_response(*id)).unwrap();
        }
        buffer
    }

    #[test]
    fn flush_contiguous_drains_cache_in_order_until_gap() {
        let buffer = buffer_with(10, &[5]);
        let cache = ProofCache::new();
        for id in [6, 7, 9] {
            cache.insert(test_response(id));
        }

        cache.flush_contiguous(5, &buffer);

        assert_eq!(buffer.len(), 3);
        assert_eq!(buffer.last_insert_id(), 7);
        assert_eq!(cache.len(), 1);
        assert!(matches!(cache.flush_range(9, 9, &buffer), Ok(())));
    }

    #[test]
    fn flush_range_stops_at_first_missing_id() {
        let buffer = buffer_with(10, &[]);
        let cache = ProofCache::new();
        for id in [8, 9, 11] {
            cache.insert(test_response(id));
        }

        assert_eq!(cache.flush_range(8, 10, &buffer), Err(CacheError::CacheMiss(10)));
        assert_eq!(buffer.len(), 2);
        assert_eq!(buffer.last_insert_id(), 9);
        assert_eq!(cache.len(), 1, "id 11 must stay cached");
    }

    #[test]
    fn flush_respects_buffer_capacity() {
        let buffer = buffer_with(2, &[5]);
        let cache = ProofCache::new();
        cache.insert(test_response(6));
        cache.insert(test_response(7));

        cache.flush_contiguous(5, &buffer);

        assert_eq!(buffer.len(), 2);
        assert_eq!(buffer.last_insert_id(), 6);
        assert_eq!(cache.len(), 1, "id 7 must stay cached once the buffer fills");
    }

    #[test]
    fn prune_finalized_drops_entries_at_or_below_watermark() {
        let cache = ProofCache::new();
        for id in [3, 4, 5, 8] {
            cache.insert(test_response(id));
        }

        assert_eq!(cache.prune_finalized(5), 3);
        assert_eq!(cache.len(), 1);
        assert!(!cache.is_empty());
        assert_eq!(cache.prune_finalized(8), 1);
        assert!(cache.is_empty());
    }

    #[test]
    fn drain_all_removes_and_returns_every_entry() {
        let cache = ProofCache::new();
        for id in [3, 4, 7] {
            cache.insert(test_response(id));
        }

        let mut drained: Vec<u64> =
            cache.drain_all().iter().map(ProofResponse::proposal_id).collect();
        drained.sort_unstable();

        assert_eq!(drained, vec![3, 4, 7]);
        assert!(cache.is_empty(), "cache emptied after drain_all");
        assert!(cache.drain_all().is_empty(), "second drain returns nothing");
    }
}
