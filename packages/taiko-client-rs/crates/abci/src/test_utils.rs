//! Shared test builders (compiled only under `cfg(test)`).
//!
//! [`TestState`] is an in-memory L1 state: it builds real storage tries and a real account trie
//! with `alloy_trie::HashBuilder`, so the [`AccountWitness`]es it hands out carry genuine
//! EIP-1186 proofs (inclusion proofs for non-zero slots, exclusion proofs for zero/absent ones).

use std::collections::BTreeMap;

use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};

use crate::types::{AccountWitness, StorageProof};

/// One account of a [`TestState`]: `(address, nonce, balance, code_hash, storage)`, where
/// `storage` lists `(slot, value)` pairs (zero values are the same as absent slots; on duplicate
/// slots the last pair wins).
pub(crate) type AccountSpec = (Address, u64, U256, B256, Vec<(B256, U256)>);

/// One account with its non-zero storage and the derived storage root.
#[derive(Clone, Debug)]
struct TestAccount {
    nonce: u64,
    balance: U256,
    code_hash: B256,
    storage: BTreeMap<B256, U256>,
    storage_root: B256,
}

impl TestAccount {
    fn trie_account(&self) -> TrieAccount {
        TrieAccount {
            nonce: self.nonce,
            balance: self.balance,
            storage_root: self.storage_root,
            code_hash: self.code_hash,
        }
    }

    /// Storage-trie leaves: `keccak256(slot) -> rlp(value)` for every non-zero slot.
    fn storage_leaves(&self) -> BTreeMap<B256, Vec<u8>> {
        self.storage
            .iter()
            .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
            .collect()
    }
}

/// An in-memory L1 state with real MPT roots and proofs.
#[derive(Clone, Debug)]
pub(crate) struct TestState {
    accounts: BTreeMap<Address, TestAccount>,
    state_root: B256,
}

impl TestState {
    /// Builds the storage tries and the account trie for `accounts`.
    pub(crate) fn new(accounts: Vec<AccountSpec>) -> Self {
        let accounts: BTreeMap<Address, TestAccount> = accounts
            .into_iter()
            .map(|(address, nonce, balance, code_hash, slots)| {
                let mut storage = BTreeMap::new();
                for (slot, value) in slots {
                    if value.is_zero() {
                        storage.remove(&slot);
                    } else {
                        storage.insert(slot, value);
                    }
                }
                let mut account =
                    TestAccount { nonce, balance, code_hash, storage, storage_root: B256::ZERO };
                account.storage_root = build_trie(&account.storage_leaves(), vec![]).0;
                (address, account)
            })
            .collect();
        let state_root = build_trie(&account_leaves(&accounts), vec![]).0;
        Self { accounts, state_root }
    }

    /// The state root over every account.
    pub(crate) fn state_root(&self) -> B256 {
        self.state_root
    }

    /// An EIP-1186 witness for `address` and `slots` (in the given order), as `eth_getProof`
    /// would return it. Panics if `address` is not part of the state.
    pub(crate) fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
        let account = self.accounts.get(&address).expect("address is part of the test state");

        let account_key = keccak256(address);
        let (state_root, account_nodes) =
            build_trie(&account_leaves(&self.accounts), vec![Nibbles::unpack(account_key)]);
        assert_eq!(state_root, self.state_root, "account trie rebuilds deterministically");

        let storage_keys = slots.iter().map(|slot| Nibbles::unpack(keccak256(slot))).collect();
        let (storage_root, storage_nodes) = build_trie(&account.storage_leaves(), storage_keys);
        assert_eq!(storage_root, account.storage_root, "storage trie rebuilds deterministically");

        AccountWitness {
            address,
            nonce: account.nonce,
            balance: account.balance,
            storage_root: account.storage_root,
            code_hash: account.code_hash,
            account_proof: proof_for(&account_nodes, account_key),
            storage: slots
                .iter()
                .map(|slot| StorageProof {
                    slot: *slot,
                    value: account.storage.get(slot).copied().unwrap_or_default(),
                    proof: proof_for(&storage_nodes, keccak256(slot)),
                })
                .collect(),
        }
    }
}

/// Account-trie leaves: `keccak256(address) -> rlp(TrieAccount)`.
fn account_leaves(accounts: &BTreeMap<Address, TestAccount>) -> BTreeMap<B256, Vec<u8>> {
    accounts
        .iter()
        .map(|(address, account)| (keccak256(address), alloy_rlp::encode(account.trie_account())))
        .collect()
}

/// Builds a trie over `leaves` (sorted by hashed key) and retains the proof nodes on the paths to
/// `targets`.
fn build_trie(leaves: &BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}

/// The proof nodes on the path to `key`, root first.
fn proof_for(nodes: &ProofNodes, key: B256) -> Vec<Bytes> {
    nodes.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
}
