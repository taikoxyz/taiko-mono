//! Canonical committee and generation-start data with unchanged wire encodings.
use alloc::vec::Vec;
use alloy_primitives::{B256, U256};
use alloy_rlp::{RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};
/// One staking-registry entry as captured by a registry checkpoint (layout in
/// [`crate::registry`]).
///
/// Entries are indexed by slot number, independently of permanent bond IDs. A registration
/// takes the lowest-numbered empty slot (STAKE-4.1-14a), so a slot freed by a withdrawal can
/// hold a later bond's entry; historical checkpoints retain the earlier occupant.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
#[serde(deny_unknown_fields)]
pub struct RegistryEntry {
    /// SEC1 parity prefix; zero only for a released all-zero entry.
    pub ck_prefix: u8,
    /// Full 32-byte SEC1 X coordinate, preserving leading zeros.
    pub ck_x: B256,
    /// Effective stake in token base units.
    pub eff_stake: U256,
    /// First eligible L1 block, inclusive.
    pub active_from_l1: u64,
    /// First ineligible L1 block, exclusive end of activity.
    pub exit_effective_l1: u64,
}

impl RegistryEntry {
    /// Validates and returns the canonical compressed consensus key.
    pub fn consensus_key(&self) -> Result<crate::key::ConsensusKey, crate::key::KeyError> {
        let mut bytes = [0; 33];
        bytes[0] = self.ck_prefix;
        bytes[1..].copy_from_slice(self.ck_x.as_slice());
        crate::key::ConsensusKey::from_slice(&bytes)
    }
}

/// The committee record for one target epoch, as deterministically derived from a fixed L1 snapshot
/// ([`committee::record_hash`](crate::committee::record_hash)).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
#[serde(deny_unknown_fields)]
pub struct CommitteeRecord {
    /// The epoch this committee signs.
    pub target_epoch: u64,
    /// Snapshot cutoff `C`, an L1 block number: the snapshot is the last registry checkpoint with
    /// `l1Block <= C`.
    pub cutoff_l1_block: u64,
    /// Index `i` of that registry checkpoint in `checkpoints[]`.
    pub checkpoint_index: u64,
    /// Set hash ([`set_hash`](crate::committee::set_hash)) over the members, with `l2ChainId` =
    /// the L2 EVM chain id (ENC-A-39a).
    pub set_hash: B256,
    /// Sum of the members' voting power; at most `(2^63 - 1) / 8` (CometBFT's total-power cap).
    pub total_power: u64,
}

/// One committee member, derived from an eligible registry entry.
///
/// Member lists are kept in set-key order: ascending by
/// `keccak256(abi.encode(bytes32("ETNA_SET_KEY_V1"), l2ChainId, ckPrefix, ckX))`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Member {
    /// The member's validated compressed secp256k1eth consensus key.
    pub pubkey: crate::key::ConsensusKey,
    /// Effective stake, in TAIKO base units.
    pub eff_stake: U256,
    /// CometBFT voting power: `floor(eff_stake / VP_UNIT)`, always >= 1 for a member.
    pub power: u64,
}

/// The Etna genesis record read from the Inbox (the compatibility `activation` slots 272–274), with
/// the genesis committee's snapshot cutoff (slot 279) and the forced inclusion configuration
/// (slot 282). Unknown fields are refused, so a record saved with a removed parameter is not
/// silently migrated.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GenesisRecord {
    /// Authenticated slot-269 derivation configuration hash; required for persisted state.
    pub committee_config_hash: B256,
    /// Etna start height S: zero on a fresh network, the last Unzen height on a switching network.
    pub genesis_height: u64,
    /// `L1_0`: L1 block number of initialization; the minimum anchor of every block.
    pub l1_0: u64,
    /// `L`: epoch length in L2 blocks (validated `>= 3`; independent of the unsettled cap).
    pub epoch_len: u64,
    /// `H*`: L2 block hash of `B*`.
    pub genesis_hash: B256,
    /// `S*`: L2 state root of `B*`.
    pub genesis_state_root: B256,
    /// `genesisCutoff`: the snapshot cutoff `C` of the genesis committee `e_0`, an L1 block
    /// number; validated `< l1_0`. Genesis names it explicitly before `L1_0` is known.
    /// Runtime epochs select the committed derivation parent anchor instead.
    pub genesis_cutoff: u64,
    /// `forcedInclusionDelay` (`D`, slot 282 bits 0–47), in seconds: an entry is due once an
    /// anchor's timestamp reaches its own plus `D`. Validated positive with no upper bound.
    pub forced_inclusion_delay: u64,
    /// `maxAnchorAge` (`M`, slot 282 bits 48–95), in seconds: a block's timestamp may exceed
    /// its anchor's by at most `M`. Validated `>= 1152`.
    pub max_anchor_age: u64,
}

/// One epoch's committee: its record (as deterministically derived from a fixed L1 snapshot) and
/// members.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommitteeState {
    /// The committee record of the epoch.
    pub record: CommitteeRecord,
    /// The members, in set-key order; their powers are the CometBFT validator set.
    pub members: Vec<Member>,
}

impl AsRef<CommitteeState> for CommitteeState {
    /// The committee itself.
    fn as_ref(&self) -> &CommitteeState {
        self
    }
}
