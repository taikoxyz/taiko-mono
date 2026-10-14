//! Serializable, immutable contexts. Contract-independent facts remain separate from ABI types.

use abci::{
    AccountWitness, AnchorState, AnchorWitness, CommitteeState, CommitteeWitness, GenesisRecord,
    RawL1Header,
};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256, aliases::U48};
use prost::Message;
use serde::{Deserialize, Serialize};
use tendermint_proto::v0_38::types::{Block as RawBlock, Commit as RawCommit};

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
    /// Maximum encoded V3 payload bytes (the version byte and the compressed list), the bytes
    /// blob coding carries.
    pub max_payload_bytes: usize,
    /// Maximum bytes of one protobuf block or commit witness, and of one published header or
    /// envelope.
    pub max_message_bytes: usize,
    /// Maximum bytes of the V3 payload's RLP list after decompression.
    pub max_decompressed_bytes: usize,
}

impl Limits {
    /// Reject zero limits before any decoding, allocation, or RPC work.
    pub fn validate(&self) -> Result<()> {
        if self.max_blocks == 0 ||
            self.max_blobs == 0 ||
            self.max_payload_bytes == 0 ||
            self.max_message_bytes == 0 ||
            self.max_decompressed_bytes == 0
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
    /// Forced inclusion queue `head` (slot 281, bits 0–47): the next entry not yet settled on L1.
    pub forced_inclusion_head: u64,
    /// Forced inclusion queue `tail` (slot 281, bits 48–95): the next free entry index.
    pub forced_inclusion_tail: u64,
    /// Authenticated genesis and epoch parameters, including the genesis cutoff and the forced
    /// inclusion configuration.
    pub genesis: GenesisRecord,
    /// Authenticated deployment configuration commitment.
    pub committee_config_hash: B256,
    /// Genesis-only bootstrap record commitment, stored directly at slot 278.
    pub genesis_committee_record_hash: B256,
    /// Raw canonical header authenticating every snapshot storage field.
    #[serde(with = "rlp_serde")]
    pub l1_header: RawL1Header,
    /// Inbox account and storage proof for the complete snapshot slot set.
    pub inbox_witness: AccountWitness,
}

impl LandingSnapshot {
    /// The stored forced inclusion head as the Inbox's `uint48`; storage decoding cannot produce
    /// a wider value, so one is an inconsistent snapshot.
    pub fn forced_inclusion_head_u48(&self) -> Result<U48> {
        U48::try_from(self.forced_inclusion_head).map_err(|_| {
            LanderError::Safety(format!(
                "forced inclusion head {} exceeds uint48",
                self.forced_inclusion_head
            ))
        })
    }
}

/// One independently derived committee's authenticated registry witness provenance.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommitteeContext {
    /// Authenticated proving anchor whose number covers the derivation snapshot.
    pub anchor: AnchorState,
    /// Authenticated execution derivation parent; absent only for explicit genesis cutoff.
    pub derivation_parent: Option<Header>,
    /// Registry proof and complete entries used to recompute this committee.
    #[serde(with = "rlp_serde")]
    pub witness: CommitteeWitness,
}

/// A complete CometBFT block paired with the decision certificate for that same height.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "CertifiedBlockWire", into = "CertifiedBlockWire")]
pub struct CertifiedBlock {
    /// Validated domain projection; its single transaction contains the Etna envelope.
    pub block: tendermint::Block,
    /// Original canonical CometBFT block protobuf, retained without a domain round trip.
    /// Evidence powers, nil vote block ids and nested light-client validator sets enter the
    /// signed roots with these exact bytes; every future proof guest must retain them too.
    pub raw_block: Bytes,
    /// Commit whose block id and height identify `block`.
    pub commit: tendermint::block::Commit,
}

/// Journal/proof wire representation, in protobufs only: a domain JSON serialization can rewrite
/// consensus evidence, and its JSON adapter reads a Unix-epoch vote time as absent.
#[derive(Clone, Serialize, Deserialize)]
struct CertifiedBlockWire {
    /// Canonical original block protobuf, required on every restored witness.
    #[serde(with = "protobuf_serde")]
    raw_block: Bytes,
    /// Canonical protobuf of the decision certificate paired with that original block.
    #[serde(with = "protobuf_serde")]
    raw_commit: Bytes,
}

/// Canonical base64 keeps journaled protobuf growth within the existing four-thirds bound.
mod protobuf_serde {
    use alloy_primitives::Bytes;
    use base64::{Engine as _, engine::general_purpose::STANDARD};
    use serde::{Deserialize, Deserializer, Serializer};

    /// Serializes the unchanged original protobuf as padded standard base64.
    pub fn serialize<S: Serializer>(
        bytes: &Bytes,
        serializer: S,
    ) -> std::result::Result<S::Ok, S::Error> {
        serializer.serialize_str(&STANDARD.encode(bytes))
    }

    /// Rejects invalid or noncanonical base64 before the protobuf witness is restored.
    pub fn deserialize<'de, D: Deserializer<'de>>(
        deserializer: D,
    ) -> std::result::Result<Bytes, D::Error> {
        let encoded = String::deserialize(deserializer)?;
        let bytes = STANDARD.decode(&encoded).map_err(serde::de::Error::custom)?;
        if STANDARD.encode(&bytes) != encoded {
            return Err(serde::de::Error::custom("noncanonical protobuf base64"));
        }
        Ok(bytes.into())
    }
}

impl CertifiedBlock {
    /// Retains the original protobuf before creating a validated domain projection.
    pub fn from_raw(raw: RawBlock, commit: tendermint::block::Commit) -> Result<Self> {
        let raw_block = Bytes::from(raw.encode_to_vec());
        let block = domain_block(raw)
            .map_err(|e| LanderError::Encoding(format!("invalid CometBFT block protobuf: {e}")))?;
        Ok(Self { block, raw_block, commit })
    }

    /// Decodes the canonical witness and rejects any disagreement with its domain projection.
    pub fn block_proto(&self) -> Result<RawBlock> {
        let raw = RawBlock::decode(self.raw_block.as_ref()).map_err(|e| {
            LanderError::Encoding(format!("invalid original CometBFT block protobuf: {e}"))
        })?;
        if raw.encode_to_vec().as_slice() != self.raw_block.as_ref() {
            return Err(LanderError::Encoding("noncanonical original block protobuf".into()));
        }
        let projection = domain_block(raw.clone())
            .map_err(|e| LanderError::Encoding(format!("invalid original CometBFT block: {e}")))?;
        if projection != self.block {
            return Err(LanderError::Safety("original block differs from domain projection".into()));
        }
        Ok(raw)
    }
}

/// The domain projection of `raw`, without its evidence.
///
/// Nothing reads the projection's evidence: body verification hashes the original evidence
/// bytes. The domain conversion would reject evidence CometBFT commits: duplicate-vote extension
/// signatures that are not 64 bytes (vote signatures do not cover extensions, and evidence
/// verification never reads them), and inside a light-client attack, nil-vote signatures of other
/// lengths (never verified) or validator key types this build does not convert. The original
/// bytes, evidence included, remain the witness the evidence hash and part set are built from.
fn domain_block(mut raw: RawBlock) -> std::result::Result<tendermint::Block, tendermint::Error> {
    raw.evidence = None;
    raw.try_into()
}

impl TryFrom<CertifiedBlockWire> for CertifiedBlock {
    type Error = LanderError;

    /// Restores the domain from canonical original bytes rather than rewriting evidence.
    fn try_from(wire: CertifiedBlockWire) -> Result<Self> {
        let raw = RawBlock::decode(wire.raw_block.as_ref()).map_err(|e| {
            LanderError::Encoding(format!("invalid restored CometBFT block protobuf: {e}"))
        })?;
        let raw_commit = RawCommit::decode(wire.raw_commit.as_ref()).map_err(|e| {
            LanderError::Encoding(format!("invalid restored CometBFT commit protobuf: {e}"))
        })?;
        if raw_commit.encode_to_vec().as_slice() != wire.raw_commit.as_ref() {
            return Err(LanderError::Encoding("noncanonical restored commit protobuf".into()));
        }
        let commit = raw_commit
            .try_into()
            .map_err(|e| LanderError::Encoding(format!("invalid restored CometBFT commit: {e}")))?;
        let pair = Self::from_raw(raw, commit)?;
        if pair.raw_block != wire.raw_block {
            return Err(LanderError::Encoding("noncanonical restored block protobuf".into()));
        }
        Ok(pair)
    }
}

impl From<CertifiedBlock> for CertifiedBlockWire {
    /// Persists the original witness and certificate; the domain projection is reconstructed.
    fn from(pair: CertifiedBlock) -> Self {
        Self {
            raw_block: pair.raw_block,
            raw_commit: RawCommit::from(pair.commit).encode_to_vec().into(),
        }
    }
}

/// Immutable public inputs and authenticated host context of a prepared landing job.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreparedBatch {
    /// Coherent Inbox state from which this batch extends.
    pub snapshot: LandingSnapshot,
    /// Public EL parent header, verified against the checkpoint height and hash.
    pub parent_header: Header,
    /// Minimal descending EL ancestry rooted at the contract checkpoint hash.
    pub execution_history: Vec<Header>,
    /// Timestamp of the parent's parent; zero when the parent is genesis.
    pub grandparent_timestamp: u64,
    /// Anchor consumed by the parent; genesis uses the initialization L1 block.
    pub parent_anchor: AnchorState,
    /// Inbox schedule/config/bootstrap and anchor-facts proof under the parent root in reference
    /// ancestry.
    #[serde(with = "rlp_serde")]
    pub starting_inbox_witness: AnchorWitness,
    /// Exact complete block/commit pairs in increasing height order. Only their headers and
    /// envelopes are published; commits and signatures reach the proof only as witnesses.
    pub blocks: Vec<CertifiedBlock>,
    /// Each block's own authenticated L1 anchor, in matching block order.
    pub anchors: Vec<AnchorState>,
    /// Exact raw L1 headers, newest-to-oldest from reference through oldest consumed anchor.
    pub reference_headers: Vec<Bytes>,
    /// All consulted committees in epoch order, including starting and newly derived contexts.
    pub committees: Vec<CommitteeState>,
    /// Registry witnesses deduplicated by epoch, with their authenticated proving roots.
    pub committee_witnesses: Vec<CommitteeContext>,
    /// The exact six `LandInput` fields the contract receives: the terminal height, block hash
    /// and state root, the L1 reference block number, the forced inclusion head after the batch
    /// and the fee recipient.
    #[serde(with = "crate::contracts::land_input_serde")]
    pub input: LandInput,
    /// Sidecar and ordered versioned blob hashes binding the V3 payload.
    pub blobs: PreparedBlobs,
    /// Identity of this job: the exact V6 public statement hash.
    pub statement_hash: B256,
}

/// Canonical RLP journal encoding for protocol witness types that intentionally have no JSON wire
/// API.
mod rlp_serde {
    use alloy_primitives::Bytes;
    use alloy_rlp::{Decodable, Encodable};
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Retain exact protocol RLP bytes rather than duplicating consensus witness fields.
    pub fn serialize<T: Encodable, S: Serializer>(
        value: &T,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        Bytes::from(alloy_rlp::encode(value)).serialize(serializer)
    }

    /// Require canonical complete RLP when restoring a journaled witness.
    pub fn deserialize<'de, T: Decodable + Encodable, D: Deserializer<'de>>(
        deserializer: D,
    ) -> Result<T, D::Error> {
        let bytes = Bytes::deserialize(deserializer)?;
        let value: T = alloy_rlp::decode_exact(&bytes).map_err(serde::de::Error::custom)?;
        if alloy_rlp::encode(&value).as_slice() != bytes.as_ref() {
            return Err(serde::de::Error::custom("noncanonical witness RLP"));
        }
        Ok(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::protocol::request;

    #[test]
    fn forced_inclusion_head_converts_exactly_up_to_uint48() {
        let mut snapshot = request().batch.snapshot;
        snapshot.forced_inclusion_head = (1 << 48) - 1;
        assert_eq!(snapshot.forced_inclusion_head_u48().unwrap(), U48::MAX);
        snapshot.forced_inclusion_head = 1 << 48;
        assert!(matches!(snapshot.forced_inclusion_head_u48(), Err(LanderError::Safety(_))));
    }
}
