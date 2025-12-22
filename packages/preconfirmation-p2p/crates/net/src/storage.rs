//! Minimal pluggable storage for commitments and raw txlists used by the network driver.

use std::{
    collections::{BTreeMap, HashMap},
    sync::Mutex,
};

use alloy_primitives::{B256, U256};
use preconfirmation_types::{RawTxListGossip, SignedCommitment};

/// Pluggable storage for commitments/txlists. Implementations must be Send+Sync.
pub trait PreconfStorage: Send + Sync {
    /// Persist a commitment keyed by block number.
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment);
    /// Persist a raw txlist keyed by its hash.
    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip);
    /// Return up to `max` commitments starting from `start` (inclusive).
    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment>;
    /// Fetch a raw txlist by hash, if present.
    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip>;
}

/// Default in-memory storage used when no external backend is supplied.
#[derive(Default)]
pub struct InMemoryStorage {
    /// Commitments keyed by block number.
    commitments: Mutex<BTreeMap<U256, SignedCommitment>>,
    /// Raw txlists keyed by their hash.
    txlists: Mutex<HashMap<B256, RawTxListGossip>>,
}

impl PreconfStorage for InMemoryStorage {
    fn insert_commitment(&self, block: U256, commitment: SignedCommitment) {
        let mut guard = self.commitments.lock().unwrap();
        guard.insert(block, commitment);
    }

    fn insert_txlist(&self, hash: B256, tx: RawTxListGossip) {
        let mut guard = self.txlists.lock().unwrap();
        guard.insert(hash, tx);
    }

    fn commitments_from(&self, start: U256, max: usize) -> Vec<SignedCommitment> {
        let guard = self.commitments.lock().unwrap();
        guard.range(start..).take(max).map(|(_, v)| v.clone()).collect()
    }

    fn get_txlist(&self, hash: &B256) -> Option<RawTxListGossip> {
        self.txlists.lock().unwrap().get(hash).cloned()
    }
}

/// Construct the default in-memory storage backend wrapped in an `Arc`.
pub fn default_storage() -> std::sync::Arc<dyn PreconfStorage> {
    std::sync::Arc::new(InMemoryStorage::default())
}
