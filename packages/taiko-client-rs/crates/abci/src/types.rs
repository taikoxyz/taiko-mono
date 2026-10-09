//! Plain data shared across the `abci` modules. No I/O.
//!
//! The four witness-carried types ([`StorageProof`], [`AccountWitness`], [`RegistryEntry`],
//! [`CommitteeRecord`]) travel inside the block envelope and therefore have an RLP encoding (each
//! is an RLP list of its fields in declaration order). Everything here is also serde-serializable
//! so it can be persisted in `AppState` and exposed through ABCI queries.

use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_rlp::{RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};

/// One EIP-1186 storage proof: a storage slot, its value and the MPT nodes proving it.
///
/// RLP: `[slot, value, proof_nodes]` (spec §4.1).
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

/// One staking-registry entry as captured by a registry checkpoint (spec §6.2).
///
/// Entries are append-only by index (`bondId`); exited entries stay with `exit_effective_l1` set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
pub struct RegistryEntry {
    /// The validator's Ed25519 consensus public key (32 raw bytes).
    pub pubkey: B256,
    /// Effective stake, in TAIKO base units (10^-18 TAIKO).
    pub eff_stake: U256,
    /// First L1 block number at which the entry is active (inclusive).
    pub active_from_l1: u64,
    /// First L1 block number at which the entry is exited (exclusive end of activity);
    /// `u64::MAX` means no exit is scheduled.
    pub exit_effective_l1: u64,
    /// L1 block number of the last heartbeat; 0 means the validator never sent one.
    pub last_heartbeat_at: u64,
}

/// The committee record for one target epoch, as hashed into `committee[epoch]` on L1 (spec §6.4).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
pub struct CommitteeRecord {
    /// The epoch this committee signs.
    pub target_epoch: u64,
    /// Snapshot cutoff `C`, an L1 block number: the snapshot is the last registry checkpoint with
    /// `l1Block <= C`.
    pub cutoff_l1_block: u64,
    /// Index `i` of that registry checkpoint in `checkpoints[]`.
    pub checkpoint_index: u64,
    /// MEM-08 set root over the members, with `chainId` = the L2 EVM chain id.
    pub set_root: B256,
    /// Sum of the members' effective stake, in TAIKO base units.
    pub total_stake: U256,
    /// Sum of the members' voting power; at most `(2^63 - 1) / 8` (CometBFT's total-power cap).
    pub total_power: u64,
    /// Record encoding version; currently always 1.
    pub encoding_version: u8,
}

/// One committee member, derived from an eligible registry entry.
///
/// Member lists are kept sorted by the MEM-08 sort key
/// `keccak256(abi.encode("ETNA_SET_KEY", chainId, pubkey))`, ascending.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Member {
    /// The member's Ed25519 consensus public key (32 raw bytes).
    pub pubkey: B256,
    /// Effective stake, in TAIKO base units.
    pub eff_stake: U256,
    /// CometBFT voting power: `floor(eff_stake / VP_UNIT)`, always >= 1 for a member.
    pub power: u64,
}

/// Inbox facts proven by an anchor (or genesis) witness (spec §6.2).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct InboxFacts {
    /// `migrationState` (slot 258); `ETNA_ACTIVE = 3` once Etna PoS is live.
    pub migration_state: u8,
    /// `recoveryGeneration` (slot 268); also the CometBFT `chain_id` suffix and the `extraData`
    /// generation of every block of that generation.
    pub recovery_generation: u64,
    /// `lastCheckpoint.height` (slot 270): L2 block number of the last L1-accepted checkpoint.
    pub last_checkpoint_height: u64,
    /// `lastCheckpoint.blockHash` (slot 271): L2 block hash of that checkpoint.
    pub last_checkpoint_hash: B256,
    /// `(epoch, committee[epoch])` when the witness also proved a committee record hash (switch
    /// heights and genesis); `None` otherwise. Persisted only; never RLP-encoded.
    pub committee: Option<(u64, B256)>,
}

/// The Etna activation record read from the Inbox (slots 272–274, spec §6.2).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActivationRecord {
    /// `B*`: L2 block number of the genesis anchor (an existing, uncertified L2 block).
    pub genesis_height: u64,
    /// `L1_0`: L1 block number of the activation; epoch `e_0` starts its L1 view here.
    pub l1_0: u64,
    /// `L`: epoch length in L2 blocks (validated `>= 3` and `>= unsettled_cap + 3`).
    pub epoch_len: u64,
    /// `EPOCH_LEN_L1`: epoch length in L1 blocks, for the per-epoch minimum anchor (validated
    /// `>= 1`).
    pub epoch_len_l1: u64,
    /// `H*`: L2 block hash of `B*`.
    pub genesis_hash: B256,
    /// `S*`: L2 state root of `B*`.
    pub genesis_state_root: B256,
}

/// The L1 anchor a block uses: the L1 header facts plus the Inbox facts proven at it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnchorState {
    /// L1 block number `n` of the anchor.
    pub number: u64,
    /// L1 block hash, `keccak256(rlp(l1_header))`.
    pub hash: B256,
    /// L1 state root; also the L2 block's `parentBeaconBlockRoot`.
    pub state_root: B256,
    /// L1 block timestamp, in seconds since the Unix epoch.
    pub timestamp: u64,
    /// Inbox facts proven against `state_root`.
    pub inbox: InboxFacts,
}

/// Summary of the committed L2 parent block needed to derive the next header (spec §4.2).
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
    /// Header `difficulty`; under alethia-reth #248 this carries the block's zk gas.
    pub difficulty: U256,
    /// Timestamp of the parent's parent, in seconds (EIP-4396 base-fee input).
    pub grandparent_timestamp: u64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::{address, b256, bytes};
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

    fn inbox_facts(committee: Option<(u64, B256)>) -> InboxFacts {
        InboxFacts {
            migration_state: 3,
            recovery_generation: 2,
            last_checkpoint_height: 1_000,
            last_checkpoint_hash: B256::repeat_byte(0x33),
            committee,
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
    fn registry_entry_rlp_round_trips() {
        rlp_round_trip(&RegistryEntry {
            pubkey: b256!("aa00000000000000000000000000000000000000000000000000000000000001"),
            eff_stake: U256::from(10).pow(U256::from(24)),
            active_from_l1: 12,
            exit_effective_l1: u64::MAX,
            last_heartbeat_at: 0,
        });
    }

    #[test]
    fn committee_record_rlp_round_trips() {
        rlp_round_trip(&CommitteeRecord {
            target_epoch: 1,
            cutoff_l1_block: 64,
            checkpoint_index: 3,
            set_root: B256::repeat_byte(0x44),
            total_stake: U256::MAX,
            total_power: (i64::MAX as u64) / 8,
            encoding_version: 1,
        });
    }

    #[test]
    fn inbox_facts_json_round_trips() {
        json_round_trip(&inbox_facts(None));
        json_round_trip(&inbox_facts(Some((5, B256::repeat_byte(0x55)))));
    }

    #[test]
    fn activation_record_json_round_trips() {
        json_round_trip(&ActivationRecord {
            genesis_height: 0,
            l1_0: 100,
            epoch_len: 20,
            epoch_len_l1: 4,
            genesis_hash: B256::repeat_byte(0x66),
            genesis_state_root: B256::repeat_byte(0x77),
        });
    }

    #[test]
    fn anchor_state_json_round_trips() {
        json_round_trip(&AnchorState {
            number: u64::MAX,
            hash: B256::repeat_byte(0x88),
            state_root: B256::repeat_byte(0x99),
            timestamp: 1_760_000_000,
            inbox: inbox_facts(Some((0, B256::repeat_byte(0xaa)))),
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

    #[test]
    fn member_json_round_trips() {
        json_round_trip(&Member {
            pubkey: B256::repeat_byte(0xcc),
            eff_stake: U256::from(5_000_000_000u64),
            power: 5,
        });
    }
}
