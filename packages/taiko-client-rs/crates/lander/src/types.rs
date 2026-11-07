//! Serializable, immutable contexts. Contract-independent facts remain separate from ABI types.

use crate::native::{Block, Commit, RawBlock};
use abci::{
    AccountWitness, AnchorState, AnchorWitness, CommitteeState, CommitteeWitness, GRID_INTERVAL,
    GenesisRecord, RawL1Header, valstate::ValState,
};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256};
use prost::Message;
use serde::{Deserialize, Serialize};
use tendermint_proto::v0_38::types::Commit as RawCommit;

use crate::{
    blob::PreparedBlobs,
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result},
};

/// Decode a protocol uint48 carried in an ABI uint256 without truncation.
pub fn protocol_u48(value: U256) -> Result<u64> {
    if value >= U256::from(1u64 << 48) {
        return Err(LanderError::Safety("protocol integer exceeds uint48".into()));
    }
    Ok(value.to::<u64>())
}

/// Network sidecar representation selected explicitly for the target L1 fork.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SidecarMode {
    /// EIP-4844 blob proofs.
    Eip4844,
    /// EIP-7594 cell proofs.
    Eip7594,
}

/// Operator capacity budgets, additionally clamped by fixed V6 protocol ceilings.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Limits {
    /// Maximum complete blocks in one batch, bounded by the deployed Inbox.
    pub max_blocks: usize,
    /// Maximum blobs in one transaction, bounded by the target L1 fork.
    pub max_blobs: usize,
    /// Maximum encoded V6 payload bytes (the version byte and the compressed list), the bytes
    /// blob coding carries.
    pub max_payload_bytes: usize,
    /// Maximum bytes of one protobuf block or commit witness, and of one published header or
    /// execution block.
    pub max_message_bytes: usize,
    /// Maximum bytes of the V6 payload's RLP list after decompression.
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

/// Current Inbox facts pinned to `l1_block_hash`, with separate finalized recovery evidence.
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
    /// Independently verified fixed recovery origin; absent for generation zero.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recovery: Option<abci::recovery::RecoveryOrigin>,
    /// Canonical RLP recovery evidence retained with the immutable proof request.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recovery_witness: Option<Bytes>,
    /// Latest landed L2 height.
    pub checkpoint_height: u64,
    /// Latest landed L2 hash.
    pub checkpoint_hash: B256,
    /// Authenticated Comet hash from the retained landing record at the checkpoint.
    pub checkpoint_comet_hash: B256,
    /// Validator-state hash (appendix A's `valStateHash`, slot 285 word 4) from the retained
    /// landing record at the checkpoint: 0 in the start record, and at a recovery origin the
    /// old generation's value, which the statement binds as stored but no replay starts from.
    pub checkpoint_val_state_hash: B256,
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
    /// Global boundary preceding the first block of this generation.
    pub fn origin_height(&self) -> u64 {
        self.recovery.as_ref().map_or(self.genesis.genesis_height, |r| r.height)
    }
    /// R-selected initial committee, independent of the old parent execution header.
    pub fn initial_committee(&self) -> Option<&CommitteeState> {
        self.recovery.as_ref().map(|r| &r.committee)
    }
}

/// One independently derived committee's authenticated registry witness provenance.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommitteeContext {
    /// Authenticated proving anchor whose number covers the derivation snapshot.
    pub anchor: AnchorState,
    /// Authenticated derivation parent; absent for the genesis cutoff or R initial committee.
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
    pub block: Block,
    /// Original canonical CometBFT block protobuf, retained without a domain round trip.
    /// Evidence powers, nil vote block ids and nested light-client validator sets enter the
    /// signed roots with these exact bytes; every future proof guest must retain them too.
    pub raw_block: Bytes,
    /// Commit whose block id and height identify `block`.
    pub commit: Commit,
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
    pub fn from_raw(raw: RawBlock, commit: Commit) -> Result<Self> {
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
fn domain_block(raw: RawBlock) -> std::result::Result<Block, String> {
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
    /// Exact complete block/commit pairs in increasing height order. Only execution blocks are
    /// published; original envelopes, headers, evidence and signatures remain private.
    pub blocks: Vec<CertifiedBlock>,
    /// Each block's own authenticated L1 anchor, in matching block order.
    pub anchors: Vec<AnchorState>,
    /// Exact raw L1 headers, newest-to-oldest from reference through oldest consumed anchor.
    pub reference_headers: Vec<Bytes>,
    /// All consulted committees in epoch order, including starting and newly derived contexts.
    pub committees: Vec<CommitteeState>,
    /// Registry witnesses deduplicated by epoch, with their authenticated proving roots.
    pub committee_witnesses: Vec<CommitteeContext>,
    /// Nine canonical V1 ABI fields binding the original parent and the terminal EL, Comet and
    /// validator state, reference block, terminal forced cursor and active committee cutoff.
    #[serde(with = "crate::contracts::abi_serde")]
    pub input: LandInput,
    /// The validator state CometBFT holds after the checkpoint, from which every cut leaf's and
    /// the terminal validator-state hash are replayed: the generation's genesis state at its
    /// origin, otherwise the state whose hash the checkpoint record's word 4 holds.
    pub start_val_state: ValState,
    /// Ordered cut leaves for the interior grid points ([`GRID_INTERVAL`]) of the immutable range.
    pub leaves: Vec<B256>,
    /// Sidecar and ordered versioned blob hashes binding the V6 payload.
    pub blobs: PreparedBlobs,
    /// Identity of this job: the exact V1 public statement hash.
    pub statement_hash: B256,
}

/// Fixed bounds for decoding a restored job's blobs, independent of operator limits: the journal
/// allocation bound caps every byte count.
const RESTORE_LIMITS: Limits = Limits {
    max_blocks: 100_000,
    max_blobs: 128,
    max_payload_bytes: crate::store::MAX_JOURNAL_BYTES as usize,
    max_message_bytes: crate::store::MAX_JOURNAL_BYTES as usize,
    max_decompressed_bytes: crate::store::MAX_JOURNAL_BYTES as usize,
};

impl PreparedBatch {
    /// Recheck a restored job against what its statement and signed transaction bind, cheapest
    /// check first: the V1 shape (LAND-6.1-5/7), the terminal Comet hash (PROOF-6.2-15), the
    /// reference number, the statement hash, the blob payload against the retained blocks
    /// (PROOF-6.2-21/37) and the KZG sidecar (PROOF-6.2-35).
    ///
    /// Proof witnesses (the starting validator state, execution history, committees and their
    /// witnesses, anchors and the starting Inbox witness) are not re-derived. A restored job is
    /// at least Prepared, so its proof already exists and nothing reads them again; the builder
    /// checked every one before proving.
    pub fn verify_restored(&self) -> Result<()> {
        let u48 = |value: U256| {
            protocol_u48(value)
                .map_err(|_| LanderError::Journal("job ABI integer exceeds uint48".into()))
        };
        let parent = u48(self.input.parentHeight)?;
        let last = u48(self.input.lastHeight)?;
        for value in [
            self.input.l1ReferenceBlockNumber,
            self.input.forcedInclusionHead,
            self.input.activeCommitteeSnapshot,
        ] {
            u48(value)?;
        }
        if parent != self.snapshot.checkpoint_height ||
            parent >= last ||
            !parent.is_multiple_of(GRID_INTERVAL) ||
            !last.is_multiple_of(GRID_INTERVAL) ||
            self.blocks.len() as u64 != last - parent
        {
            return Err(LanderError::Journal("job has an invalid V1 grid interval".into()));
        }
        if self.leaves.len() as u64 != (last - parent) / GRID_INTERVAL - 1 {
            return Err(LanderError::Journal(
                "job cut leaf count differs from its grid interval".into(),
            ));
        }
        if self.blocks.last().is_none_or(|pair| {
            B256::from_slice(pair.block.header.hash().as_bytes()) != self.input.lastCometHash
        }) {
            return Err(LanderError::Journal("job terminal Comet hash mismatch".into()));
        }
        let raw = self
            .reference_headers
            .first()
            .ok_or_else(|| LanderError::Journal("job has no L1 reference".into()))?;
        let reference = RawL1Header::from_raw(raw.clone())
            .map_err(|error| LanderError::Journal(format!("job reference: {error}")))?;
        if self.input.l1ReferenceBlockNumber != reference.number() {
            return Err(LanderError::Journal(
                "job L1 reference number differs from its reference header".into(),
            ));
        }
        if crate::statement::hash(
            &self.snapshot,
            &self.input,
            reference.hash(),
            &self.blobs.versioned_hashes,
            &self.leaves,
        ) != self.statement_hash
        {
            return Err(LanderError::Journal("job V1 statement identity mismatch".into()));
        }
        let payload = crate::blob::decode(self.blobs.sidecar.blobs(), &RESTORE_LIMITS)
            .map_err(|e| LanderError::Journal(format!("job blobs: {e}")))?;
        if payload.len() != self.blobs.payload_bytes {
            return Err(LanderError::Journal(
                "job blob payload length differs from its record".into(),
            ));
        }
        // Compressed bytes are not canonical, so compare the blocks the payload carries.
        let range = crate::codec::LandedRange {
            parent_height: parent,
            parent_hash: self.snapshot.checkpoint_hash,
            last_height: last,
            last_block_hash: self.input.lastBlockHash,
            last_state_root: self.input.lastStateRoot,
        };
        let published = crate::codec::decode_landed(&payload, &range)
            .map_err(|e| LanderError::Journal(format!("job block codec: {e}")))?;
        let expected = self
            .blocks
            .iter()
            .map(|pair| {
                crate::codec::PublishedBlock::try_from(pair)
                    .map_err(|e| LanderError::Journal(format!("job block pair: {e}")))
            })
            .collect::<Result<Vec<_>>>()?;
        if published != expected {
            return Err(LanderError::Journal("job blocks differ from bound blob payload".into()));
        }
        crate::blob::verify(&self.blobs)
    }
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

    #[test]
    fn prepared_statement_rejects_every_terminal_comet_bit_even_with_rebound_digest() {
        let request = crate::test_utils::runtime::request();
        request.batch.verify_restored().unwrap();
        let reference =
            abci::RawL1Header::from_raw(request.batch.reference_headers[0].clone()).unwrap();
        for bit in 0..256 {
            let mut changed = request.batch.clone();
            changed.input.lastCometHash[bit / 8] ^= 1 << (bit % 8);
            assert!(changed.verify_restored().is_err(), "stale digest bit {bit}");
            changed.statement_hash = crate::statement::hash(
                &changed.snapshot,
                &changed.input,
                reference.hash(),
                &changed.blobs.versioned_hashes,
                &changed.leaves,
            );
            assert!(changed.verify_restored().is_err(), "rebound digest bit {bit}");
        }
        let mut changed = request.batch.clone();
        changed.statement_hash = B256::ZERO;
        assert!(changed.verify_restored().is_err());
        let mut changed = request.batch;
        changed.input.lastCometHash = B256::ZERO;
        assert!(changed.verify_restored().is_err());
    }

    /// Restoration rechecks what the signed transaction and the statement bind: the shape, the
    /// terminal Comet hash, the reference, the statement hash, the blob payload and its KZG
    /// sidecar. It does not re-derive proof witnesses: a restored job's proof already exists, and
    /// the builder checked them all before proving.
    #[test]
    fn restore_rechecks_the_statement_shape_and_blob_binding_but_not_proof_witnesses() {
        use crate::test_utils::runtime::{limits, rebind, request};
        use alloy_eips::eip7594::BlobTransactionSidecarVariant;
        let original = request();
        original.batch.verify_restored().unwrap();
        let mut witnesses = original.batch.clone();
        witnesses.start_val_state.current.entries[0].priority += 1;
        witnesses.anchors.clear();
        witnesses.execution_history.clear();
        witnesses.committee_witnesses.clear();
        witnesses.verify_restored().unwrap();

        let reference =
            abci::RawL1Header::from_raw(original.batch.reference_headers[0].clone()).unwrap();
        let rebound = |batch: &mut PreparedBatch| {
            batch.statement_hash = crate::statement::hash(
                &batch.snapshot,
                &batch.input,
                reference.hash(),
                &batch.blobs.versioned_hashes,
                &batch.leaves,
            );
        };
        let mut cases: Vec<(&str, PreparedBatch)> = Vec::new();
        let mut batch = original.batch.clone();
        batch.statement_hash = B256::ZERO;
        cases.push(("statement", batch));
        let mut batch = original.batch.clone();
        batch.leaves.push(B256::ZERO);
        rebound(&mut batch);
        cases.push(("leaf", batch));
        let mut batch = original.batch.clone();
        batch.input.lastCometHash[0] ^= 1;
        rebound(&mut batch);
        cases.push(("Comet", batch));
        let mut batch = original.batch.clone();
        batch.input.l1ReferenceBlockNumber += U256::from(1);
        rebound(&mut batch);
        cases.push(("reference", batch));
        let mut first = original.clone();
        let payload = crate::codec::encode(&first.batch.blocks[..1], &limits()).unwrap();
        rebind(&mut first, &payload);
        cases.push(("exact landed checkpoint interval", first.batch));
        let mut batch = original.batch.clone();
        let BlobTransactionSidecarVariant::Eip4844(sidecar) = &mut batch.blobs.sidecar else {
            panic!("the runtime request carries an EIP-4844 sidecar");
        };
        sidecar.proofs[0][0] ^= 1;
        cases.push(("KZG", batch));

        for (expected, batch) in cases {
            let error = batch.verify_restored().unwrap_err();
            assert!(matches!(error, LanderError::Journal(_)), "{expected}: {error}");
            assert!(error.to_string().contains(expected), "{expected}: {error}");
        }
    }
}
