//! Serializable, immutable contexts. Contract-independent facts remain separate from ABI types.

use crate::native::{Block, Commit, RawBlock};
use abci::{
    AccountWitness, AnchorState, AnchorWitness, CommitteeState, CommitteeWitness, GRID_INTERVAL,
    GenesisRecord, RawL1Header,
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
    /// Authenticated Comet hash from the retained landing record at the checkpoint.
    pub checkpoint_comet_hash: B256,
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
    /// Eight canonical V1 ABI fields binding the original parent and terminal EL/Comet state,
    /// reference block, terminal forced cursor and active committee cutoff.
    #[serde(with = "crate::contracts::abi_serde")]
    pub input: LandInput,
    /// Ordered cut leaves for the interior grid points ([`GRID_INTERVAL`]) of the immutable range.
    pub leaves: Vec<B256>,
    /// Executing deployment/config identity rechecked before signing or rebroadcasting.
    pub deployment_identity: B256,
    /// Sidecar and ordered versioned blob hashes binding the V6 payload.
    pub blobs: PreparedBlobs,
    /// Identity of this job: the exact V1 public statement hash.
    pub statement_hash: B256,
}

impl PreparedBatch {
    /// Reconstruct the V1 range, cut leaves, cursors and digest before restoration or signing.
    /// Batch construction authenticates headers; a real proof guest must independently execute.
    pub fn validate_statement(&self) -> Result<()> {
        let headers = self
            .blocks
            .iter()
            .map(|pair| {
                pair.block
                    .data
                    .first()
                    .ok_or_else(|| LanderError::Journal("job has no envelope".into()))
                    .and_then(|bytes| {
                        abci::EtnaEnvelope::decode(bytes)
                            .map_err(|error| LanderError::Journal(format!("job envelope: {error}")))
                    })
                    .map(|envelope| envelope.block.header)
            })
            .collect::<Result<Vec<_>>>()?;
        if self.blocks.iter().any(|pair| pair.block.header.version.app != abci::app::APP_VERSION) {
            return Err(LanderError::Journal("job has unsupported Etna APP_VERSION".into()));
        }
        let parent = protocol_u48(self.input.parentHeight)?;
        let last = protocol_u48(self.input.lastHeight)?;
        for value in [
            self.input.l1ReferenceBlockNumber,
            self.input.forcedInclusionHead,
            self.input.activeCommitteeSnapshot,
        ] {
            protocol_u48(value)?;
        }
        if parent != self.snapshot.checkpoint_height ||
            parent >= last ||
            !parent.is_multiple_of(GRID_INTERVAL) ||
            !last.is_multiple_of(GRID_INTERVAL) ||
            self.snapshot.generation != 0 ||
            self.blocks.len() as u64 != last - parent
        {
            return Err(LanderError::Journal(
                "job has invalid V1 grid interval or generation".into(),
            ));
        }
        if self.blocks.last().is_none_or(|pair| {
            B256::from_slice(pair.block.header.hash().as_bytes()) != self.input.lastCometHash
        }) {
            return Err(LanderError::Journal("job terminal Comet hash mismatch".into()));
        }
        self.validate_cuts()?;
        self.validate_active_committee_snapshot(&headers)?;
        let raw = self
            .reference_headers
            .first()
            .ok_or_else(|| LanderError::Journal("job has no L1 reference".into()))?;
        let header = abci::RawL1Header::from_raw(raw.clone())
            .map_err(|error| LanderError::Journal(format!("job reference: {error}")))?;
        if self.input.l1ReferenceBlockNumber != header.number() ||
            crate::statement::hash(
                &self.snapshot,
                &self.input,
                header.hash(),
                &self.blobs.versioned_hashes,
                &self.leaves,
            ) != self.statement_hash
        {
            return Err(LanderError::Journal("job V1 statement identity mismatch".into()));
        }
        Ok(())
    }

    /// Reconstruct every committed cursor and cut from the retained authenticated envelopes.
    /// A canonical skip was executed by the builder; restoration checks its unchanged pure
    /// classification and witness, while a real proof guest must execute that skip itself.
    fn validate_cuts(&self) -> Result<()> {
        use abci::forced::{ForcedContext, ForcedDecision, check};
        if self.anchors.len() != self.blocks.len() {
            return Err(LanderError::Journal("job anchor count differs from blocks".into()));
        }
        let mut cursor = self.snapshot.forced_inclusion_head;
        let mut leaves = Vec::new();
        for (pair, anchor) in self.blocks.iter().zip(&self.anchors) {
            let envelope = abci::EtnaEnvelope::decode(&pair.block.data[0])
                .map_err(|e| LanderError::Journal(format!("job envelope: {e}")))?;
            let decision = check(
                ForcedContext {
                    cursor,
                    anchor,
                    delay: self.snapshot.genesis.forced_inclusion_delay,
                    inbox: self.snapshot.inbox,
                    l2_chain_id: self.snapshot.l2_chain_id,
                    block_gas_limit: envelope.block.header.gas_limit,
                },
                envelope.forced.as_ref(),
                envelope.block.transactions.first().map(|tx| tx.as_ref()),
            )
            .map_err(|e| LanderError::Journal(format!("job forced cursor: {e}")))?;
            if !matches!(decision, ForcedDecision::Ordinary) {
                cursor = cursor
                    .checked_add(1)
                    .ok_or_else(|| LanderError::Journal("job cursor overflow".into()))?;
            }
            let height = envelope.block.header.number;
            if height.is_multiple_of(GRID_INTERVAL) && U256::from(height) < self.input.lastHeight {
                leaves.push(crate::statement::cut_leaf(
                    height,
                    envelope.block.header.hash_slow(),
                    B256::from_slice(pair.block.header.hash().as_bytes()),
                    cursor,
                ));
            }
        }
        if leaves != self.leaves || U256::from(cursor) != self.input.forcedInclusionHead {
            return Err(LanderError::Journal(
                "job V1 cut leaves or terminal cursor mismatch".into(),
            ));
        }
        Ok(())
    }

    /// Recover the terminal committee cutoff from committed execution ancestry and retained
    /// registry provenance. A recomputed digest cannot authorize a different cutoff or epoch.
    fn validate_active_committee_snapshot(&self, headers: &[Header]) -> Result<()> {
        let invalid =
            || LanderError::Journal("job active committee snapshot provenance mismatch".into());
        let schedule = abci::Schedule::from_genesis(&self.snapshot.genesis);
        schedule.validate().map_err(|_| invalid())?;
        let terminal = headers.last().ok_or_else(invalid)?;
        if self.input.lastHeight != terminal.number ||
            terminal.hash_slow() != self.input.lastBlockHash ||
            terminal.state_root != self.input.lastStateRoot
        {
            return Err(invalid());
        }
        let mut parent_height = self.snapshot.checkpoint_height;
        let mut parent_hash = self.snapshot.checkpoint_hash;
        for header in headers {
            if parent_height.checked_add(1) != Some(header.number) ||
                header.parent_hash != parent_hash
            {
                return Err(invalid());
            }
            parent_height = header.number;
            parent_hash = header.hash_slow();
        }
        let epoch = schedule.epoch_of(terminal.number);
        let cutoff = if epoch == 0 {
            schedule.genesis_cutoff
        } else {
            let derivation_height = schedule.derivation_parent_height(epoch).ok_or_else(invalid)?;
            let derivation = if derivation_height <= self.snapshot.checkpoint_height {
                crate::history::verify(
                    crate::history::HistoryInput {
                        height: self.snapshot.checkpoint_height,
                        hash: self.snapshot.checkpoint_hash,
                        generation: self.snapshot.generation,
                        schedule: &schedule,
                    },
                    &self.execution_history,
                )
                .map_err(|_| invalid())?;
                self.execution_history
                    .iter()
                    .find(|header| header.number == derivation_height)
                    .ok_or_else(invalid)?
            } else {
                headers
                    .iter()
                    .find(|header| header.number == derivation_height)
                    .ok_or_else(invalid)?
            };
            let mut contexts = self
                .committee_witnesses
                .iter()
                .filter(|context| context.witness.record.target_epoch == epoch);
            let context = contexts.next().ok_or_else(invalid)?;
            let mut committees =
                self.committees.iter().filter(|committee| committee.record.target_epoch == epoch);
            let committee = committees.next().ok_or_else(invalid)?;
            if contexts.next().is_some() ||
                committees.next().is_some() ||
                context.derivation_parent.as_ref() != Some(derivation) ||
                context.witness.record != committee.record
            {
                return Err(invalid());
            }
            let cutoff = crate::history::snapshot_number(Some(derivation), &schedule)
                .map_err(|_| invalid())?;
            let anchors = std::iter::once(self.parent_anchor.clone())
                .chain(self.anchors.iter().cloned())
                .collect::<Vec<_>>();
            let reference = self
                .reference_headers
                .iter()
                .map(|raw| RawL1Header::from_raw(raw.clone()).map_err(|_| invalid()))
                .collect::<Result<Vec<_>>>()?;
            crate::batch::verify_reference_chain(&reference, &anchors).map_err(|_| invalid())?;
            if context.witness.record.cutoff_l1_block != cutoff ||
                context.anchor.number < cutoff ||
                !anchors.contains(&context.anchor)
            {
                return Err(invalid());
            }
            cutoff
        };
        if self.input.activeCommitteeSnapshot != cutoff ||
            cutoff < schedule.genesis_cutoff ||
            self.input.l1ReferenceBlockNumber < U256::from(cutoff)
        {
            return Err(invalid());
        }
        Ok(())
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
        request.batch.validate_statement().unwrap();
        let reference =
            abci::RawL1Header::from_raw(request.batch.reference_headers[0].clone()).unwrap();
        for bit in 0..256 {
            let mut changed = request.batch.clone();
            changed.input.lastCometHash[bit / 8] ^= 1 << (bit % 8);
            assert!(changed.validate_statement().is_err(), "stale digest bit {bit}");
            changed.statement_hash = crate::statement::hash(
                &changed.snapshot,
                &changed.input,
                reference.hash(),
                &changed.blobs.versioned_hashes,
                &changed.leaves,
            );
            assert!(changed.validate_statement().is_err(), "rebound digest bit {bit}");
        }
        let mut changed = request.batch.clone();
        changed.statement_hash = B256::ZERO;
        assert!(changed.validate_statement().is_err());
        let mut changed = request.batch;
        changed.input.lastCometHash = B256::ZERO;
        assert!(changed.validate_statement().is_err());
    }
}
