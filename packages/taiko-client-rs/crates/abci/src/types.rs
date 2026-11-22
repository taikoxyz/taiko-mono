//! Plain data shared across the `abci` modules. No I/O.
//!
//! The witness-carried types ([`StorageProof`], [`AccountWitness`]) travel inside block
//! envelopes or the genesis and recovery witnesses and therefore have an RLP encoding (each is an
//! RLP list of its fields in declaration order). Everything here is also serde-serializable
//! so it can be persisted in `AppState` and exposed through ABCI queries.

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

/// Inbox facts proven by an anchor (or genesis) witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct InboxFacts {
    /// Authenticated packed rules schedule (slot 293): four low-order uint48 fields.
    pub rules_schedule: U256,
    /// `recoveryGeneration` (slot 268); also bound into the CometBFT domain and the `extraData`
    /// generation of every block of that generation.
    pub recovery_generation: u64,
    /// `lastCheckpoint.height` (slot 270): L2 block number of the last L1-accepted checkpoint.
    pub last_checkpoint_height: u64,
    /// `lastCheckpoint.blockHash` (slot 271): L2 block hash of that checkpoint.
    pub last_checkpoint_hash: B256,
    /// The forced inclusion queue's `head` (slot 281, `uint48` at bits 0–47): the next entry
    /// not yet settled on L1. Zero at genesis.
    pub forced_inclusion_head: u64,
    /// The forced inclusion queue's `tail` (slot 281, `uint48` at bits 48–95): the next free
    /// index, so entries `head..tail` are stored. Zero at genesis.
    pub forced_inclusion_tail: u64,
    /// `fallbackKeysHash` (slot 278), the whole word: the hash of the DAO's fallback key list,
    /// whose keys sign at power 1 when the block's candidate is not usable.
    pub fallback_keys_hash: B256,
    /// `minTotalStake` (slot 279), the whole word, never masked: the least `snapshotTotalStake`
    /// of a usable candidate. 2^256 − 1 makes no candidate usable, so the fallback keys sign
    /// whatever L2 state holds.
    pub min_total_stake: U256,
}

/// The Etna genesis record read from the Inbox: the configuration hash (slot 269), the start
/// write (slots 272–274) and the forced inclusion configuration (slot 282).
pub use etna_core::types::GenesisRecord;

/// The L1 anchor a block uses: the L1 header facts plus the Inbox facts proven at it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnchorState {
    /// L1 block number `n` of the anchor.
    pub number: u64,
    /// L1 block hash: `keccak256` of the raw L1 header.
    pub hash: B256,
    /// L1 state root; also the L2 block's `parentBeaconBlockRoot`.
    pub state_root: B256,
    /// L1 block timestamp, in seconds since the Unix epoch.
    pub timestamp: u64,
    /// Inbox facts proven against `state_root`.
    pub inbox: InboxFacts,
}

/// Summary of the committed L2 parent block needed to derive the next header
/// ([`rules::expected_header`](crate::rules::expected_header)).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParentInfo {
    /// L2 block number (== CometBFT height).
    pub number: u64,
    /// L2 block hash.
    pub hash: B256,
    /// Block timestamp, in seconds since the Unix epoch.
    pub timestamp: u64,
    /// Block gas limit, in gas.
    pub gas_limit: u64,
    /// Gas used by the block, in gas.
    pub gas_used: u64,
    /// Base fee per gas, in wei.
    pub base_fee: u64,
    /// Header `difficulty`; under alethia-reth this carries the block's zk gas.
    pub difficulty: U256,
    /// Timestamp of the parent's parent, in seconds (EIP-4396 base-fee input).
    pub grandparent_timestamp: u64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::ChainParamsExt;
    use alloy_primitives::{address, bytes};
    use alloy_rlp::{Decodable, Encodable};
    use serde::de::DeserializeOwned;

    fn rlp_round_trip<T: Encodable + Decodable + PartialEq + std::fmt::Debug>(value: &T) {
        let encoded = alloy_rlp::encode(value);
        let mut buf = encoded.as_slice();
        let decoded = T::decode(&mut buf).expect("decodes");
        assert!(buf.is_empty(), "trailing bytes after decode");
        assert_eq!(&decoded, value);
    }

    fn json_round_trip<T: Serialize + DeserializeOwned + PartialEq + std::fmt::Debug>(value: &T) {
        let json = serde_json::to_string(value).expect("serializes");
        let decoded: T = serde_json::from_str(&json).expect("deserializes");
        assert_eq!(&decoded, value);
    }

    fn storage_proof(seed: u8) -> StorageProof {
        StorageProof {
            slot: B256::repeat_byte(seed),
            value: U256::from(seed) << 200,
            proof: vec![bytes!("f851a0"), Bytes::from(vec![seed; 40])],
        }
    }

    fn account_witness() -> AccountWitness {
        AccountWitness {
            address: address!("00000000000000000000000000000000e7a10001"),
            nonce: 7,
            balance: U256::from(10).pow(U256::from(30)),
            storage_root: B256::repeat_byte(0x11),
            code_hash: B256::repeat_byte(0x22),
            account_proof: vec![bytes!("f90211a0"), bytes!("")],
            storage: vec![storage_proof(1), storage_proof(2), storage_proof(0)],
        }
    }

    fn inbox_facts() -> InboxFacts {
        InboxFacts {
            rules_schedule: alloy_primitives::U256::ZERO,
            recovery_generation: 2,
            last_checkpoint_height: 1_000,
            last_checkpoint_hash: B256::repeat_byte(0x33),
            forced_inclusion_head: 4,
            forced_inclusion_tail: 7,
            // Whole words: the JSON round trip keeps every bit.
            fallback_keys_hash: B256::repeat_byte(0xff),
            min_total_stake: U256::MAX,
        }
    }

    #[test]
    fn storage_proof_rlp_round_trips() {
        rlp_round_trip(&storage_proof(9));
        rlp_round_trip(&StorageProof { slot: B256::ZERO, value: U256::ZERO, proof: vec![] });
    }

    #[test]
    fn account_witness_rlp_round_trips() {
        rlp_round_trip(&account_witness());
        rlp_round_trip(&AccountWitness {
            address: Address::ZERO,
            nonce: 0,
            balance: U256::ZERO,
            storage_root: B256::ZERO,
            code_hash: B256::ZERO,
            account_proof: vec![],
            storage: vec![],
        });
    }

    #[test]
    fn inbox_facts_json_round_trips() {
        json_round_trip(&inbox_facts());
    }

    /// The genesis record is etna-core's: the configuration hash, the start write and the
    /// forced inclusion configuration, and a record saved with a removed field is refused.
    #[test]
    fn genesis_record_json_round_trips() {
        let record = GenesisRecord {
            config_hash: crate::config::ChainParams::builtin(
                protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID,
            )
            .unwrap()
            .config_hash(),
            genesis_height: 0,
            l1_0: 100,
            genesis_hash: B256::repeat_byte(0x66),
            genesis_state_root: B256::repeat_byte(0x77),
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        };
        json_round_trip(&record);
        let mut json = serde_json::to_value(&record).unwrap();
        json["epoch_len"] = 20.into();
        assert!(serde_json::from_value::<GenesisRecord>(json).is_err());
    }

    #[test]
    fn anchor_state_json_round_trips() {
        json_round_trip(&AnchorState {
            number: u64::MAX,
            hash: B256::repeat_byte(0x88),
            state_root: B256::repeat_byte(0x99),
            timestamp: 1_760_000_000,
            inbox: inbox_facts(),
        });
    }

    #[test]
    fn parent_info_json_round_trips() {
        json_round_trip(&ParentInfo {
            number: 42,
            hash: B256::repeat_byte(0xbb),
            timestamp: 1_760_000_001,
            gas_limit: 45_000_000,
            gas_used: 21_000,
            base_fee: 10_000_000,
            difficulty: U256::from(123_456_789u64),
            grandparent_timestamp: 1_760_000_000,
        });
    }
}
