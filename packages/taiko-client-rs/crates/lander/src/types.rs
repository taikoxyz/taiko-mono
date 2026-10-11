//! Serializable, immutable contexts. Contract-independent facts remain separate from ABI types.

use abci::{AnchorState, CommitteeState, GenesisRecord};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256};
use serde::{Deserialize, Serialize};

use crate::{
    blob::PreparedBlobs,
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result},
};

/// Network sidecar representation selected explicitly for the target L1 fork.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SidecarMode {
    /// EIP-4844 blob proofs.
    Eip4844,
    /// EIP-7594 cell proofs.
    Eip7594,
}

/// Operator-enforced allocation and batch limits.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Limits {
    /// Maximum complete blocks in one batch, bounded by the deployed Inbox.
    pub max_blocks: usize,
    /// Maximum blobs in one transaction, bounded by the target L1 fork.
    pub max_blobs: usize,
    /// Maximum total encoded V1 payload bytes.
    pub max_payload_bytes: usize,
    /// Maximum bytes of one protobuf block or commit message.
    pub max_message_bytes: usize,
}

impl Limits {
    /// Reject zero limits before any decoding, allocation, or RPC work.
    pub fn validate(&self) -> Result<()> {
        if self.max_blocks == 0 ||
            self.max_blobs == 0 ||
            self.max_payload_bytes == 0 ||
            self.max_message_bytes == 0
        {
            return Err(LanderError::Configuration(
                "all batch and codec limits must be nonzero".into(),
            ));
        }
        Ok(())
    }
}

/// One coherent Inbox snapshot: every storage getter is pinned to `l1_block_hash`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LandingSnapshot {
    /// L1 state block hash to which all Inbox reads are pinned.
    pub l1_block_hash: B256,
    /// Number of that L1 state block.
    pub l1_block_number: u64,
    /// L1 EVM chain id, encoded as a full uint256 in the statement.
    pub l1_chain_id: U256,
    /// L2 EVM chain id.
    pub l2_chain_id: u64,
    /// Executing Inbox proxy identity.
    pub inbox: Address,
    /// Configured staking-registry identity.
    pub registry: Address,
    /// Recovery generation from the pinned Inbox state.
    pub generation: u64,
    /// Latest landed L2 height.
    pub checkpoint_height: u64,
    /// Latest landed L2 hash.
    pub checkpoint_hash: B256,
    /// Authenticated genesis and epoch parameters, including the genesis cutoff.
    pub genesis: GenesisRecord,
    /// On-chain record of the batch's starting committee.
    pub start_committee_record_hash: B256,
}

/// A complete CometBFT block paired with the decision certificate for that same height.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CertifiedBlock {
    /// Unmodified CometBFT block; its single transaction contains the Etna envelope.
    pub block: tendermint::Block,
    /// Commit whose block id and height identify `block`.
    pub commit: tendermint::block::Commit,
}

/// Immutable public inputs and authenticated host context of a prepared landing job.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreparedBatch {
    /// Coherent Inbox state from which this batch extends.
    pub snapshot: LandingSnapshot,
    /// Public EL parent header, verified against the checkpoint height and hash.
    pub parent_header: Header,
    /// Timestamp of the parent's parent; zero when the parent is genesis.
    pub grandparent_timestamp: u64,
    /// Anchor consumed by the parent; genesis uses the initialization L1 block.
    pub parent_anchor: AnchorState,
    /// Exact complete block/commit pairs in increasing height order.
    pub blocks: Vec<CertifiedBlock>,
    /// Each block's own authenticated L1 anchor, in matching block order.
    pub anchors: Vec<AnchorState>,
    /// Exact raw L1 headers, newest-to-oldest from reference through oldest consumed anchor.
    pub reference_headers: Vec<Bytes>,
    /// All consulted committees in epoch order, including starting and newly derived contexts.
    pub committees: Vec<CommitteeState>,
    /// Exact contract public output fields, including only new committee records.
    #[serde(with = "crate::contracts::land_input_serde")]
    pub input: LandInput,
    /// Sidecar and ordered versioned blob hashes binding the V1 payload.
    pub blobs: PreparedBlobs,
    /// Identity of this job: the exact V3 public statement hash.
    pub statement_hash: B256,
}
