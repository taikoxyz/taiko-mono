//! Minimal pluggable storage for commitments and raw txlists used by the network driver.

use alloy_primitives::{B256, U256};
use crossbeam_skiplist::SkipMap;
use dashmap::DashMap;
use preconfirmation_types::{RawTxListGossip, SignedCommitment};
use std::sync::Arc;

/// Pluggable storage for commitments/txlists. Implementations must be Send+Sync.
pub trait PreconfStorage: Send + Sync {
    /// Persist a commitment keyed by block number.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment);
    /// Persist a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip);
    /// Return up to `max` commitments starting from `start` (inclusive).
    ///
    /// Implementations may return a weakly consistent view under concurrent writes.
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment>;
    /// Fetch a raw txlist by hash, if present.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip>;
}

/// Default in-memory storage used when no external backend is supplied.
pub struct InMemoryStorage {
    /// Commitments keyed by block number.
    commitments: SkipMap<U256, SignedCommitment>,
    /// Raw txlists keyed by their hash.
    txlists: DashMap<B256, RawTxListGossip>,
}

impl Default for InMemoryStorage {
    /// Create a fresh in-memory storage instance.
    fn default() -> Self {
        Self { commitments: SkipMap::new(), txlists: DashMap::new() }
    }
}

impl PreconfStorage for InMemoryStorage {
    /// Insert a commitment into the in-memory store.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        self.commitments.insert(block, commitment);
    }

    /// Insert a raw txlist into the in-memory store.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        self.txlists.insert(hash, tx);
    }

    /// Return a range of commitments from the in-memory store.
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        self.commitments.range(start..).take(max).map(|entry| entry.value().clone()).collect()
    }

    /// Fetch a raw txlist by hash from the in-memory store.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        self.txlists.get(hash).map(|entry| entry.value().clone())
    }
}

/// Construct the default in-memory storage backend wrapped in an `Arc`.
pub fn default_storage() -> Arc<dyn PreconfStorage> {
    Arc::new(InMemoryStorage::default())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crossbeam_skiplist::SkipMap;
    use dashmap::DashMap;
    use preconfirmation_types::{Bytes32, Bytes65, RawTxListGossip, SignedCommitment, TxListBytes};

    fn assert_commitment_map_type(_map: &SkipMap<U256, SignedCommitment>) {}
    fn assert_txlist_map_type(_map: &DashMap<B256, RawTxListGossip>) {}

    fn signature_with(byte: u8) -> Bytes65 {
        Bytes65::try_from(vec![byte; 65]).expect("65-byte signature")
    }

    fn commitment_with_sig(byte: u8) -> SignedCommitment {
        SignedCommitment { signature: signature_with(byte), ..Default::default() }
    }

    fn txlist_with_byte(byte: u8) -> RawTxListGossip {
        let raw_tx_list_hash = Bytes32::try_from(vec![byte; 32]).expect("32-byte hash");
        let txlist = TxListBytes::try_from(vec![byte; 3]).expect("txlist bytes");
        RawTxListGossip { raw_tx_list_hash, txlist }
    }

    #[test]
    fn storage_uses_concurrent_collections() {
        let storage = InMemoryStorage::default();

        assert_commitment_map_type(&storage.commitments);
        assert_txlist_map_type(&storage.txlists);
    }

    #[test]
    fn commitments_from_returns_ordered_range() {
        let storage = InMemoryStorage::default();

        storage.insert_commitment(U256::from(3), commitment_with_sig(3));
        storage.insert_commitment(U256::from(1), commitment_with_sig(1));
        storage.insert_commitment(U256::from(2), commitment_with_sig(2));

        let commitments = storage.commitments_from(U256::from(2), 2);
        let signatures: Vec<_> = commitments.into_iter().map(|c| c.signature).collect();

        assert_eq!(signatures, vec![signature_with(2), signature_with(3)]);
    }

    #[test]
    fn get_txlist_returns_cloned_value() {
        let storage = InMemoryStorage::default();
        let hash = B256::from([0x11; 32]);
        let txlist = txlist_with_byte(0xAA);

        storage.insert_txlist(hash, txlist.clone());

        assert_eq!(storage.get_txlist(&hash), Some(txlist));
    }
}
