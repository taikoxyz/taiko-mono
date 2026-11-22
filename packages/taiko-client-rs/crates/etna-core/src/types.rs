//! Canonical genesis and generation origin records.
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};

/// The Etna genesis record read from the Inbox: the configuration hash (slot 269), the start write
/// (slots 272–274) and the forced inclusion configuration (slot 282). Unknown fields are refused,
/// so a record saved with a removed parameter is not silently migrated.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GenesisRecord {
    /// The configuration hash (slot 269) over the L2 chain id, the staking proxy and U
    /// ([`config_hash`](crate::params::config_hash)).
    pub config_hash: B256,
    /// Etna start height S: zero on a fresh network, the last Unzen height on a switching network.
    pub genesis_height: u64,
    /// `L1_0`: L1 block number of initialization; the minimum anchor of every block.
    pub l1_0: u64,
    /// The start hash: the L2 block hash of the Etna start block (height S).
    pub genesis_hash: B256,
    /// The start state root: the L2 state root of the Etna start block.
    pub genesis_state_root: B256,
    /// `forcedInclusionDelay` (`D`, slot 282 bits 0–47), in seconds: an entry is due once an
    /// anchor's timestamp reaches its own plus `D`. Validated positive with no upper bound.
    pub forced_inclusion_delay: u64,
    /// `maxAnchorAge` (slot 282 bits 48–95), in seconds: a block's timestamp may exceed its
    /// anchor's by at most this. Validated `>= 1152`.
    pub max_anchor_age: u64,
}

/// A generation's fixed origin record: the four words the Inbox stores for it at slot 290,
/// written once by the start write for generation 0 and by `recover` for every later one.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OriginRecord {
    /// The generation's start height o: S for generation 0, the recovery origin c after a
    /// governance recovery.
    pub start_height: u64,
    /// The L1 block that wrote the record: `L1_0` for generation 0, the block that executed
    /// `recover` after a recovery.
    pub l1_number: u64,
    /// That L1 block's timestamp, in Unix seconds: the generation's CometBFT genesis time.
    pub l1_timestamp: u64,
    /// The Inbox's fallback key list hash when the record was written: the keys whose list
    /// hashes to it sign o + 1 and o + 2, each at power 1, whatever the Inbox's list is later.
    pub fallback_keys_hash: B256,
}
