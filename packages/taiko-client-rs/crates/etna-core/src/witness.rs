//! Canonical EIP-1186 witness data and wire encodings. No I/O.

use alloc::vec::Vec;
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_rlp::{RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};

/// One EIP-1186 storage proof: a storage slot, its value and the MPT nodes proving it.
///
/// RLP: `[slot, value, proof_nodes]`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
pub struct StorageProof {
    /// The un-hashed 32-byte storage slot; the storage-trie key is `keccak256(slot)`.
    pub slot: B256,
    /// The 32-byte storage word at `slot`. Zero iff the proof is an exclusion proof.
    pub value: U256,
    /// RLP-encoded storage-trie nodes from the account's storage root down to the leaf (or the
    /// point of exclusion), root first.
    pub proof: Vec<Bytes>,
}

/// EIP-1186 proof of one L1 account and a fixed list of its storage slots.
///
/// The account proof verifies against an L1 header's `stateRoot`; every storage proof verifies
/// against `storage_root`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
pub struct AccountWitness {
    /// The proven account; the state-trie key is `keccak256(address)`.
    pub address: Address,
    /// Account nonce.
    pub nonce: u64,
    /// Account balance, in wei.
    pub balance: U256,
    /// Root of the account's storage trie, against which every entry of `storage` verifies.
    pub storage_root: B256,
    /// `keccak256` of the account's code.
    pub code_hash: B256,
    /// RLP-encoded state-trie nodes from the state root down to the account leaf, root first.
    pub account_proof: Vec<Bytes>,
    /// Storage proofs, in exactly the slot order the verifier expects (no extras, no gaps).
    pub storage: Vec<StorageProof>,
}
