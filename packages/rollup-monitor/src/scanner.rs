use std::collections::{HashSet, VecDeque};

use alloy::primitives::B256;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct LogKey {
    pub chain_id: u64,
    pub block_hash: Option<B256>,
    pub tx_hash: B256,
    pub log_index: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct TxKey {
    pub chain_id: u64,
    pub tx_hash: B256,
}

#[derive(Debug)]
pub struct SeenKeyCache<T>
where
    T: Clone + Eq + std::hash::Hash,
{
    capacity: usize,
    order: VecDeque<T>,
    keys: HashSet<T>,
}

impl<T> SeenKeyCache<T>
where
    T: Clone + Eq + std::hash::Hash,
{
    pub fn new(capacity: usize) -> Self {
        Self {
            capacity: capacity.max(1),
            order: VecDeque::with_capacity(capacity.max(1)),
            keys: HashSet::with_capacity(capacity.max(1)),
        }
    }

    pub fn insert(&mut self, key: T) -> bool {
        if self.keys.contains(&key) {
            return false;
        }

        self.keys.insert(key.clone());
        self.order.push_back(key);

        while self.order.len() > self.capacity {
            if let Some(oldest) = self.order.pop_front() {
                self.keys.remove(&oldest);
            }
        }

        true
    }
}

pub type SeenLogCache = SeenKeyCache<LogKey>;
pub type SeenTxCache = SeenKeyCache<TxKey>;

#[derive(Clone, Debug)]
pub struct ScanCursor {
    explicit_start_block: Option<u64>,
    start_block_lookback: u64,
    overlap_blocks: u64,
    last_scanned: Option<u64>,
}

impl ScanCursor {
    pub fn new(
        explicit_start_block: Option<u64>,
        start_block_lookback: u64,
        overlap_blocks: u64,
    ) -> Self {
        Self { explicit_start_block, start_block_lookback, overlap_blocks, last_scanned: None }
    }

    pub fn next_range(&self, latest_block: u64, confirmations: u64) -> Option<(u64, u64)> {
        let safe_head = latest_block.checked_sub(confirmations)?;
        let from = match self.last_scanned {
            Some(last_scanned) => last_scanned.saturating_sub(self.overlap_blocks),
            None => self
                .explicit_start_block
                .unwrap_or_else(|| safe_head.saturating_sub(self.start_block_lookback)),
        };

        if from > safe_head {
            return None;
        }

        Some((from, safe_head))
    }

    pub fn mark_scanned(&mut self, block: u64) {
        self.last_scanned = Some(block);
    }
}

pub fn chunk_ranges(from: u64, to: u64, max_block_range: u64) -> Vec<(u64, u64)> {
    if from > to {
        return Vec::new();
    }

    let chunk_size = max_block_range.max(1);
    let mut chunks = Vec::new();
    let mut chunk_from = from;

    while chunk_from <= to {
        let chunk_to = chunk_from.saturating_add(chunk_size - 1).min(to);
        chunks.push((chunk_from, chunk_to));

        if chunk_to == u64::MAX {
            break;
        }
        chunk_from = chunk_to + 1;
    }

    chunks
}

#[cfg(test)]
mod tests {
    use alloy::primitives::B256;

    use super::{LogKey, ScanCursor, SeenLogCache, SeenTxCache, TxKey, chunk_ranges};

    fn hash(id: u64) -> B256 {
        let mut bytes = [0u8; 32];
        bytes[24..].copy_from_slice(&id.to_be_bytes());
        B256::from(bytes)
    }

    #[test]
    fn first_range_uses_explicit_start_block() {
        let cursor = ScanCursor::new(Some(100), 500, 20);

        assert_eq!(cursor.next_range(1000, 3), Some((100, 997)));
    }

    #[test]
    fn first_range_uses_lookback_when_start_block_absent() {
        let cursor = ScanCursor::new(None, 500, 20);

        assert_eq!(cursor.next_range(1000, 3), Some((497, 997)));
    }

    #[test]
    fn range_is_none_when_safe_head_is_before_start() {
        let cursor = ScanCursor::new(Some(100), 500, 20);

        assert_eq!(cursor.next_range(90, 3), None);
    }

    #[test]
    fn subsequent_range_uses_overlap() {
        let mut cursor = ScanCursor::new(Some(100), 500, 20);
        cursor.mark_scanned(997);

        assert_eq!(cursor.next_range(1100, 3), Some((977, 1097)));
    }

    #[test]
    fn chunks_large_ranges() {
        assert_eq!(chunk_ranges(10, 25, 7), vec![(10, 16), (17, 23), (24, 25)]);
    }

    #[test]
    fn seen_log_cache_accepts_new_key_and_rejects_duplicate() {
        let mut cache = SeenLogCache::new(10);
        let key =
            LogKey { chain_id: 1, block_hash: Some(hash(10)), tx_hash: hash(1), log_index: 2 };

        assert!(cache.insert(key.clone()));
        assert!(!cache.insert(key));
    }

    #[test]
    fn seen_log_cache_prunes_oldest_key() {
        let mut cache = SeenLogCache::new(2);
        let first =
            LogKey { chain_id: 1, block_hash: Some(hash(10)), tx_hash: hash(1), log_index: 0 };
        let second =
            LogKey { chain_id: 1, block_hash: Some(hash(10)), tx_hash: hash(2), log_index: 0 };
        let third =
            LogKey { chain_id: 1, block_hash: Some(hash(10)), tx_hash: hash(3), log_index: 0 };

        assert!(cache.insert(first.clone()));
        assert!(cache.insert(second));
        assert!(cache.insert(third));
        assert!(cache.insert(first));
    }

    #[test]
    fn seen_tx_cache_accepts_new_key_and_rejects_duplicate() {
        let mut cache = SeenTxCache::new(10);
        let key = TxKey { chain_id: 1, tx_hash: hash(1) };

        assert!(cache.insert(key.clone()));
        assert!(!cache.insert(key));
    }
}
