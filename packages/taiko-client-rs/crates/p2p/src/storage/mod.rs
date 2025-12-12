use std::collections::HashMap;

use parking_lot::RwLock;
use preconfirmation_types::{Bytes32, PreconfHead, RawTxListGossip, SignedCommitment};

use crate::error::Result;

pub trait SdkStorage: Send + Sync {
    fn store_commitment(&self, hash: Bytes32, commitment: SignedCommitment) -> Result<()>;
    fn get_commitment(&self, hash: &Bytes32) -> Option<SignedCommitment>;
    fn store_raw_txlist(&self, hash: Bytes32, tx: RawTxListGossip) -> Result<()>;
    fn get_raw_txlist(&self, hash: &Bytes32) -> Option<RawTxListGossip>;
    fn set_head(&self, head: PreconfHead) -> Result<()>;
    fn head(&self) -> Option<PreconfHead>;
}

fn to_key(hash: &Bytes32) -> [u8; 32] {
    let mut out = [0u8; 32];
    out.copy_from_slice(hash.as_ref());
    out
}

/// Simple in-memory storage suitable for early development and tests.
#[derive(Default)]
pub struct InMemoryStorage {
    commitments: RwLock<HashMap<[u8; 32], SignedCommitment>>,
    txlists: RwLock<HashMap<[u8; 32], RawTxListGossip>>,
    head: RwLock<Option<PreconfHead>>,
}

impl InMemoryStorage {
    pub fn new() -> Self {
        Self::default()
    }
}

impl SdkStorage for InMemoryStorage {
    fn store_commitment(&self, hash: Bytes32, commitment: SignedCommitment) -> Result<()> {
        self.commitments.write().insert(to_key(&hash), commitment);
        Ok(())
    }

    fn get_commitment(&self, hash: &Bytes32) -> Option<SignedCommitment> {
        self.commitments.read().get(&to_key(hash)).cloned()
    }

    fn store_raw_txlist(&self, hash: Bytes32, tx: RawTxListGossip) -> Result<()> {
        self.txlists.write().insert(to_key(&hash), tx);
        Ok(())
    }

    fn get_raw_txlist(&self, hash: &Bytes32) -> Option<RawTxListGossip> {
        self.txlists.read().get(&to_key(hash)).cloned()
    }

    fn set_head(&self, head: PreconfHead) -> Result<()> {
        *self.head.write() = Some(head);
        Ok(())
    }

    fn head(&self) -> Option<PreconfHead> {
        self.head.read().clone()
    }
}

pub mod memory;
