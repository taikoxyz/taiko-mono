//! Serializable, immutable contexts. Contract-independent facts remain separate from ABI types.

use crate::native::{Block, Commit, RawBlock};
use abci::{
    AccountWitness, AnchorState, AnchorWitness, GenesisRecord, RawL1Header, fallback::FallbackKeys,
    key::ConsensusKey,
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

/// EIP-1967 implementation key, shared by the switch's proxy-state checks and proof input.
pub(crate) const IMPLEMENTATION_SLOT: B256 =
    alloy_primitives::b256!("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc");

/// Authenticate the first proof's raw L2 proxy witnesses against the fixed S header. Under S's
/// state root, the L2 SignalService proxy's EIP-1967 implementation slot must hold the built-in
/// SignalService implementation, and the `EtnaStaking` proxy's, at the staking address the
/// configuration hash commits, the built-in `EtnaStaking` implementation. A batch from S on a
/// switching network carries both witnesses; any other batch carries neither, as its start is
/// already settled.
pub(crate) fn verify_start_witness(
    snapshot: &LandingSnapshot,
    parent_header: &Header,
    params: &abci::ChainParams,
    signal_service: Option<&AccountWitness>,
    staking: Option<&AccountWitness>,
) -> Result<()> {
    let Some(config) = params
        .switch
        .as_ref()
        .filter(|_| snapshot.checkpoint_height == snapshot.genesis.genesis_height)
    else {
        if signal_service.is_some() || staking.is_some() {
            return Err(LanderError::Safety("unexpected start proxy witness".into()));
        }
        return Ok(());
    };
    let (Some(signal_service), Some(staking)) = (signal_service, staking) else {
        return Err(LanderError::Unavailable(
            "first landing requires the L2 SignalService and EtnaStaking implementation proofs \
             at S"
                .into(),
        ));
    };
    if parent_header.number != snapshot.genesis.genesis_height ||
        parent_header.hash_slow() != snapshot.genesis.genesis_hash ||
        parent_header.state_root != snapshot.genesis.genesis_state_root ||
        parent_header.timestamp >= config.fork_timestamp
    {
        return Err(LanderError::Safety("start proxy witness contradicts the S header".into()));
    }
    // The snapshot was authenticated under the same parameters; checking the hash again here
    // ties the staking proxy checked below to the one the configuration hash commits.
    if snapshot.config_hash != params.config_hash() {
        return Err(LanderError::Configuration(
            "Inbox configuration hash does not commit the built-in staking proxy".into(),
        ));
    }
    for (contract, witness, proxy, built_in) in [
        (
            "SignalService",
            signal_service,
            abci::l2_signal_service_address(params.l2_chain_id),
            config.signal_service_implementation,
        ),
        ("EtnaStaking", staking, params.staking, config.staking_implementation),
    ] {
        if witness.address != proxy {
            return Err(LanderError::Safety(format!(
                "start {contract} witness proves another account than its proxy"
            )));
        }
        let storage = abci::l1::mpt::verify_account_witness(
            parent_header.state_root,
            witness,
            &[IMPLEMENTATION_SLOT],
        )
        .map_err(|error| {
            LanderError::Safety(format!("start {contract} implementation proof: {error}"))
        })?;
        let value = storage.get(IMPLEMENTATION_SLOT).expect("verified implementation slot");
        if value >> 160 != U256::ZERO || Address::from_word(B256::from(value)) != built_in {
            return Err(LanderError::Safety(format!(
                "start L2 {contract} implementation differs from switch configuration"
            )));
        }
    }
    Ok(())
}

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
///
/// The `checkpoint_*` fields hold the latest checkpoint c at `l1_block_hash`. A
/// [`PreparedBatch`] keeps the snapshot it was built on, and there the same fields are the
/// batch's proof origin p (`LandInput.parentHeight` and the statement's parent words): p stays
/// fixed while c may advance on L1 before the landing executes (LAND-6.1-2..4, PROOF-6.2-8).
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
    /// Recovery generation from the pinned Inbox state.
    pub generation: u64,
    /// Independently verified fixed recovery origin, with the `fallbackKeysHash` whose list signs
    /// the generation's first two blocks; absent for generation zero.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recovery: Option<abci::recovery::RecoveryOrigin>,
    /// Canonical RLP recovery evidence retained with the immutable proof request.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recovery_witness: Option<Bytes>,
    /// Latest landed L2 height: the latest checkpoint c when this snapshot was read, and the
    /// proof origin p of a batch built on it.
    pub checkpoint_height: u64,
    /// Latest landed L2 hash, at the same height (c when read, proof origin p in a batch).
    pub checkpoint_hash: B256,
    /// Authenticated Comet hash from the retained landing record at the checkpoint (c when read,
    /// proof origin p in a batch).
    pub checkpoint_comet_hash: B256,
    /// Forced inclusion queue `head` (slot 281, bits 0–47): the next entry not yet settled on L1.
    pub forced_inclusion_head: u64,
    /// Forced inclusion queue `tail` (slot 281, bits 48–95): the next free entry index.
    pub forced_inclusion_tail: u64,
    /// Authenticated genesis record, with the configuration hash and the forced inclusion
    /// configuration.
    pub genesis: GenesisRecord,
    /// The configuration hash (slot 269) over the L2 chain id, the `EtnaStaking` proxy and U,
    /// the genesis record's, which the built-in values open.
    pub config_hash: B256,
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
    /// Coherent Inbox state from which this batch extends. Its `checkpoint_*` fields are this
    /// batch's proof origin p, not the latest checkpoint c at execution.
    pub snapshot: LandingSnapshot,
    /// Public EL parent header, verified against the checkpoint height and hash.
    pub parent_header: Header,
    /// Timestamp of the parent's parent; zero when the parent is genesis.
    pub grandparent_timestamp: u64,
    /// The anchor the parent p uses: above the generation's start, the one `p_anchor_witness`
    /// proves; at the start, the origin anchor (`L1_0` or R), whose words no rule reads.
    pub parent_anchor: AnchorState,
    /// The reference header and the fixed starting Inbox facts proven under its root: the start
    /// record, configuration hash, slot 282 and the generation's origin record.
    #[serde(with = "rlp_serde")]
    pub starting_inbox_witness: AnchorWitness,
    /// p's anchor witness, its raw L1 header and Inbox proofs, from the block that carried it,
    /// present exactly when p is above the generation's start. p's EL header authenticates it
    /// through its `extraData` anchor number and `parentBeaconBlockRoot`, and so does the EL
    /// header of p + 1 when p + 1 inherits it. Its `minTotalStake` and `fallbackKeysHash` are p's
    /// for the set that signs p + 2.
    #[serde(with = "rlp_serde_option")]
    pub p_anchor_witness: Option<AnchorWitness>,
    /// The fallback key list whose hash the generation's origin record holds: its keys, each at
    /// power 1, sign o + 1 and o + 2.
    pub origin_fallback_keys: FallbackKeys,
    /// The set that signs p, keys and powers in CometBFT's order, which header(p)'s
    /// `validators_hash` commits and p + 1's LastCommit lists; present exactly when p is above
    /// the generation's start o, as o + 1 has no LastCommit.
    pub validators_p: Option<Vec<(ConsensusKey, u64)>>,
    /// The set that signs p + 1, keys and powers in CometBFT's order, which header(p)'s
    /// `next_validators_hash` commits; present exactly when p + 1 is above o + 2, as the origin
    /// list signs o + 1 and o + 2.
    pub validators_p1: Option<Vec<(ConsensusKey, u64)>>,
    /// Raw EIP-1186 proof of the `EtnaStaking` proxy's candidate snapshot slots and the
    /// key-to-seat slot of each validator p + 1's LastCommit lacks, in p's post-state under the
    /// state root of p's EL header; present exactly when p is above o. Its snapshot, with the
    /// `minTotalStake` and `fallbackKeysHash` p's anchor proves, decides the set that signs
    /// p + 2, and its seats give p + 1's `missBitmap`.
    pub staking_at_p: Option<AccountWitness>,
    /// Raw EIP-1186 proof of the L2 SignalService proxy's EIP-1967 implementation slot under S's
    /// state root, retained only for a switching batch whose parent is S. A real proof backend
    /// must verify this private input: the slot holds the built-in SignalService implementation.
    pub start_signal_service_witness: Option<AccountWitness>,
    /// Raw EIP-1186 proof of the `EtnaStaking` proxy's EIP-1967 implementation slot, at the
    /// staking address the configuration hash commits, under S's state root, retained exactly
    /// when `start_signal_service_witness` is. A real proof backend must verify this private
    /// input: the slot holds the built-in `EtnaStaking` implementation.
    pub start_staking_witness: Option<AccountWitness>,
    /// Exact complete block/commit pairs in increasing height order. Only execution blocks are
    /// published; original envelopes, headers, evidence and signatures remain private.
    pub blocks: Vec<CertifiedBlock>,
    /// Each block's own authenticated L1 anchor, in matching block order.
    pub anchors: Vec<AnchorState>,
    /// The staking words of every height H in (p, h − 1] that the signing-set rules read from
    /// H's post-state, in increasing height order: the proof's own execution reads them there.
    pub staking_reads: Vec<HeightReads>,
    /// Each fallback key list a decision at a height of [p, h − 1] above o fell back to, once, in
    /// ascending order of hash; each decision's anchor proves the hash of the list it used.
    pub fallback_key_lists: Vec<FallbackKeys>,
    /// Exact raw L1 headers, newest-to-oldest from reference through oldest consumed anchor.
    pub reference_headers: Vec<Bytes>,
    /// The seven canonical V1 ABI fields binding the original parent and the terminal EL and
    /// Comet identity, state root, reference block and terminal forced cursor.
    #[serde(with = "crate::contracts::abi_serde")]
    pub input: LandInput,
    /// Ordered cut leaves of every height strictly inside the immutable range (p, h), one per
    /// height (ENC-A-31); empty for a single-block landing.
    pub leaves: Vec<B256>,
    /// The heights whose commits the proof verifies, ascending: every x in (p, h) whose
    /// successor is signed by another set than x, the sets compared as (key, power) multisets,
    /// then h. Every other block is an ancestor of the next commit height through its
    /// `last_block_id` link, signed by the same set.
    pub commit_heights: Vec<u64>,
    /// Sidecar and ordered versioned blob hashes binding the V6 payload.
    pub blobs: PreparedBlobs,
    /// Identity of this job: the exact V1 public statement hash.
    pub statement_hash: B256,
}

/// The staking words of one height H's post-state that the signing-set rules read, as the
/// builder verified them from the staking proof of H's post-state under H's EL state root.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HeightReads {
    /// The height H.
    pub height: u64,
    /// The candidate snapshot, whole and unmasked, in [`abci::staking::snapshot_slots`] order:
    /// `snapshotHeight`, `snapshotTotalStake`, then each seat record's two words, 258 words. With
    /// the `minTotalStake` and `fallbackKeysHash` H's anchor proves, it decides the set that
    /// signs H + 2.
    pub values: Vec<U256>,
    /// The key-to-seat word of each validator H + 1's LastCommit lacks, by its address, in the
    /// CometBFT order of the set that signs H: they give H + 1's `missBitmap`.
    pub seat_words: Vec<(Address, U256)>,
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
    /// The commit heights, which the statement does not bind, must still have the shape the
    /// builder gives them: strictly ascending inside (p, h] and ending at h.
    ///
    /// Proof witnesses (anchors, p's anchor witness, the starting Inbox witness, the sets of p and
    /// p + 1, the origin and fallback key lists, p's staking proof and the per-height staking
    /// reads) are not re-derived. A restored job is at least Prepared, so its proof already
    /// exists and nothing reads them again; the builder checked every one before proving.
    pub fn verify_restored(&self) -> Result<()> {
        let u48 = |value: U256| {
            protocol_u48(value)
                .map_err(|_| LanderError::Journal("job ABI integer exceeds uint48".into()))
        };
        let parent = u48(self.input.parentHeight)?;
        let last = u48(self.input.lastHeight)?;
        for value in [self.input.l1ReferenceBlockNumber, self.input.forcedInclusionHead] {
            u48(value)?;
        }
        if parent != self.snapshot.checkpoint_height ||
            parent >= last ||
            self.blocks.len() as u64 != last - parent
        {
            return Err(LanderError::Journal("job has an invalid V1 interval".into()));
        }
        if self.leaves.len() as u64 != last - parent - 1 {
            return Err(LanderError::Journal("job cut leaf count differs from its interval".into()));
        }
        if self.commit_heights.last() != Some(&last) ||
            self.commit_heights.first().is_some_and(|first| *first <= parent) ||
            !self.commit_heights.is_sorted_by(|lower, higher| lower < higher)
        {
            return Err(LanderError::Journal(
                "job commit heights are not strictly ascending inside (p, h] ending at h".into(),
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

/// [`rlp_serde`] for an optional witness: `null` when absent.
mod rlp_serde_option {
    use alloy_primitives::Bytes;
    use alloy_rlp::{Decodable, Encodable};
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Retain exact protocol RLP bytes of a present witness.
    pub fn serialize<T: Encodable, S: Serializer>(
        value: &Option<T>,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        value.as_ref().map(|value| Bytes::from(alloy_rlp::encode(value))).serialize(serializer)
    }

    /// Require canonical complete RLP when restoring a present journaled witness.
    pub fn deserialize<'de, T: Decodable + Encodable, D: Deserializer<'de>>(
        deserializer: D,
    ) -> Result<Option<T>, D::Error> {
        Option::<Bytes>::deserialize(deserializer)?
            .map(|bytes| super::rlp_serde::decode_canonical(&bytes))
            .transpose()
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
        decode_canonical(&Bytes::deserialize(deserializer)?)
    }

    /// The witness `bytes` encode, refusing trailing or noncanonical RLP.
    pub(super) fn decode_canonical<T: Decodable + Encodable, E: serde::de::Error>(
        bytes: &[u8],
    ) -> Result<T, E> {
        let value: T = alloy_rlp::decode_exact(bytes).map_err(E::custom)?;
        if alloy_rlp::encode(&value).as_slice() != bytes {
            return Err(E::custom("noncanonical witness RLP"));
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
    /// sidecar, and the shape of the commit heights, which nothing binds. It does not re-derive
    /// proof witnesses: a restored job's proof already exists, and the builder checked them all
    /// before proving. The anchors, p's anchor witness, the sets of p and p + 1, the origin
    /// list, the fallback key lists, p's staking proof and the per-height staking reads may each
    /// be dropped or replaced by values no proof would accept.
    #[test]
    fn restore_rechecks_the_statement_shape_and_blob_binding_but_not_proof_witnesses() {
        use crate::test_utils::{
            consensus::{fallback_keys, public_key},
            consensus_mpt::seed_key,
            runtime::{limits, rebind, request},
        };
        use alloy_eips::eip7594::BlobTransactionSidecarVariant;
        let original = request();
        original.batch.verify_restored().unwrap();
        let other = fallback_keys(&[seed_key(0x51)]);
        let mut witnesses = original.batch.clone();
        witnesses.anchors.clear();
        witnesses.p_anchor_witness = Some(witnesses.starting_inbox_witness.clone());
        witnesses.validators_p = Some(Vec::new());
        witnesses.validators_p1 = Some(vec![(public_key(&seed_key(0x52)), 0)]);
        witnesses.origin_fallback_keys = other.clone();
        witnesses.fallback_key_lists = vec![other.clone(), other];
        witnesses.staking_at_p = Some(witnesses.snapshot.inbox_witness.clone());
        witnesses.staking_reads = vec![HeightReads {
            height: 99,
            values: Vec::new(),
            seat_words: vec![(Address::ZERO, U256::MAX)],
        }];
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
        // The statement binds no block count, so a rebound statement cannot hide a dropped block.
        let mut batch = original.batch.clone();
        batch.blocks.pop();
        rebound(&mut batch);
        cases.push(("invalid V1 interval", batch));
        let mut batch = original.batch.clone();
        batch.input.parentHeight = U256::from(1u64 << 48);
        cases.push(("uint48", batch));
        let mut batch = original.batch.clone();
        batch.reference_headers.clear();
        cases.push(("no L1 reference", batch));
        let mut batch = original.batch.clone();
        batch.blobs.payload_bytes += 1;
        cases.push(("payload length", batch));
        // The commit heights rise strictly inside (p, h] and end at h = 12.
        for heights in [vec![], vec![11], vec![12, 12], vec![6, 4, 12], vec![0, 12], vec![12, 13]] {
            let mut batch = original.batch.clone();
            batch.commit_heights = heights;
            cases.push(("commit heights", batch));
        }

        for (expected, batch) in cases {
            let error = batch.verify_restored().unwrap_err();
            assert!(matches!(error, LanderError::Journal(_)), "{expected}: {error}");
            assert!(error.to_string().contains(expected), "{expected}: {error}");
        }
    }

    /// A request of 300 blocks, the average batch of the 4 s block and 20 min landing operating
    /// targets, journals within the journal bound with every per-height witness at its largest:
    /// 128 seat words at each height of (p, h), a 128-key fallback key list for each of the 300
    /// decisions, 128-member sets of p and p + 1, and p's staking proof of the 258 snapshot and
    /// 128 seat slots, each proof a path of 65 full branch nodes. The bound holds with the
    /// private block and commit witnesses at the whole budget the codec reserves for them.
    #[test]
    fn request_of_300_blocks_stays_under_the_journal_bound() {
        use crate::{
            store::MAX_JOURNAL_BYTES,
            test_utils::{
                consensus::{committee, fallback_keys, pair},
                consensus_mpt::seed_key,
                protocol::request,
                runtime::leaves,
            },
        };
        const BLOCKS: u64 = 300;
        let mut request = request();
        let batch = &mut request.batch;
        let (_, signers, keys) = committee(&[3, 3, 3]);
        let mut parent = batch.snapshot.checkpoint_hash;
        for height in 1..=BLOCKS {
            let block = pair(height, parent, &signers, &keys, batch.blocks.last());
            parent =
                abci::EtnaEnvelope::decode(&block.block.data[0]).unwrap().block.header.hash_slow();
            batch.blocks.push(block);
        }
        batch.leaves = leaves(&batch.blocks);
        batch.anchors = vec![batch.parent_anchor.clone(); BLOCKS as usize];
        batch.commit_heights = (1..=BLOCKS).collect();
        batch.input.lastHeight = U256::from(BLOCKS);

        let list = fallback_keys(&(1..=128).map(seed_key).collect::<Vec<_>>());
        let power = abci::committee::MAX_TOTAL_POWER / 128;
        let set = list.keys().iter().map(|key| (*key, power)).collect::<Vec<_>>();
        // A full branch node: 16 child hashes and an empty value under a three-byte list header.
        let path = vec![Bytes::from(vec![0xff; 532]); 65];
        let seats = [Address::repeat_byte(0xff); 128];
        batch.staking_at_p = Some(AccountWitness {
            address: Address::repeat_byte(0xff),
            nonce: u64::MAX,
            balance: U256::MAX,
            storage_root: B256::repeat_byte(0xff),
            code_hash: B256::repeat_byte(0xff),
            account_proof: path.clone(),
            storage: crate::l1::staking_slots(&seats)
                .into_iter()
                .map(|slot| abci::StorageProof { slot, value: U256::MAX, proof: path.clone() })
                .collect(),
        });
        batch.staking_reads = (1..BLOCKS)
            .map(|height| HeightReads {
                height,
                values: vec![U256::MAX; abci::staking::SNAPSHOT_SLOT_COUNT],
                seat_words: seats.iter().map(|address| (*address, U256::MAX)).collect(),
            })
            .collect();
        batch.fallback_key_lists = vec![list.clone(); BLOCKS as usize];
        batch.origin_fallback_keys = list;
        batch.validators_p = Some(set.clone());
        batch.validators_p1 = Some(set);

        let bytes = serde_json::to_vec(&request).unwrap().len() as u64;
        // The blocks above are small; the codec admits up to a quarter of the bound of block and
        // commit protobufs, which journal as base64.
        let block_budget = (MAX_JOURNAL_BYTES / 4).div_ceil(3) * 4;
        assert!(
            bytes + block_budget < MAX_JOURNAL_BYTES,
            "a 300-block request journals {bytes} bytes"
        );
    }

    /// The Etna start S of the switching start-witness tests, and their fork time.
    const S: u64 = 7;
    const FORK: u64 = 1_000;
    /// The built-in L2 SignalService and `EtnaStaking` implementations of those tests.
    const SIGNAL_SERVICE_IMPLEMENTATION: Address = Address::repeat_byte(0x42);
    const STAKING_IMPLEMENTATION: Address = Address::repeat_byte(0x56);
    /// An account that is neither proxy.
    const OTHER_ACCOUNT: Address = Address::repeat_byte(0x43);

    /// The EIP-1967 implementation slot word naming `address`.
    fn implementation_word(address: Address) -> U256 {
        U256::from_be_bytes(address.into_word().0)
    }

    /// Switching chain parameters with the built-in implementations above, and a snapshot whose
    /// configuration hash commits their staking proxy.
    fn switching() -> (abci::ChainParams, LandingSnapshot) {
        let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 2);
        let mut params = fixture.params.clone();
        params.switch = Some(abci::SwitchConfig {
            unzen_inbox: Address::repeat_byte(0x41),
            fork_timestamp: FORK,
            signal_service_implementation: SIGNAL_SERVICE_IMPLEMENTATION,
            staking_implementation: STAKING_IMPLEMENTATION,
        });
        assert_eq!(fixture.snapshot.config_hash, params.config_hash());
        (params, fixture.snapshot.clone())
    }

    /// An L2 state whose accounts `words` each hold the paired word in the EIP-1967 slot.
    fn proxy_state(words: &[(Address, U256)]) -> crate::test_utils::consensus_mpt::State {
        crate::test_utils::consensus_mpt::State::new(
            words
                .iter()
                .map(|(account, word)| (*account, vec![(IMPLEMENTATION_SLOT, *word)]))
                .collect(),
        )
    }

    /// The header of S over the L2 state root `root`, one second before the fork.
    fn start_header(root: B256) -> Header {
        Header {
            number: S,
            parent_hash: B256::repeat_byte(6),
            state_root: root,
            timestamp: FORK - 1,
            ..Default::default()
        }
    }

    /// `snapshot` at the checkpoint S whose start record names `header`.
    fn at_s(snapshot: &LandingSnapshot, header: &Header) -> LandingSnapshot {
        let mut snapshot = snapshot.clone();
        snapshot.genesis.genesis_height = S;
        snapshot.genesis.genesis_hash = header.hash_slow();
        snapshot.genesis.genesis_state_root = header.state_root;
        snapshot.checkpoint_height = S;
        snapshot.checkpoint_hash = header.hash_slow();
        snapshot
    }

    /// Asserts a `Safety` refusal whose reason contains `expected`.
    fn assert_safety(result: Result<()>, expected: &str) {
        assert!(
            matches!(&result, Err(LanderError::Safety(reason)) if reason.contains(expected)),
            "{expected}: {result:?}"
        );
    }

    /// The host side of the first proof from S: it carries EIP-1186 proofs, under S's own
    /// header, that the L2 SignalService proxy's EIP-1967 slot holds the built-in implementation,
    /// and so does the staking proxy's. A proof from a later parent, or on a network without a
    /// switch, carries neither.
    #[test]
    fn start_signal_service_witness_proves_the_built_in_implementation_at_s() {
        let (params, snapshot) = switching();
        let proxy = abci::l2_signal_service_address(params.l2_chain_id);
        // S's L2 state whose SignalService proxy, and another account, hold `value`, and whose
        // staking proxy holds its built-in implementation.
        let state = |value: U256| {
            proxy_state(&[
                (proxy, value),
                (OTHER_ACCOUNT, value),
                (params.staking, implementation_word(STAKING_IMPLEMENTATION)),
            ])
        };
        let check = |snapshot: &LandingSnapshot,
                     header: &Header,
                     signal_service: Option<&AccountWitness>,
                     staking: Option<&AccountWitness>| {
            verify_start_witness(snapshot, header, &params, signal_service, staking)
        };

        let l2 = state(implementation_word(SIGNAL_SERVICE_IMPLEMENTATION));
        let header = start_header(l2.root);
        let snapshot = at_s(&snapshot, &header);
        let witness = l2.witness(proxy, &[IMPLEMENTATION_SLOT]);
        let staking = l2.witness(params.staking, &[IMPLEMENTATION_SLOT]);
        check(&snapshot, &header, Some(&witness), Some(&staking)).unwrap();
        for (signal_service, staking) in
            [(None, Some(&staking)), (Some(&witness), None), (None, None)]
        {
            assert!(matches!(
                check(&snapshot, &header, signal_service, staking),
                Err(LanderError::Unavailable(_))
            ));
        }

        // Another implementation, or the built-in one with dirty address padding.
        for value in [
            implementation_word(Address::repeat_byte(0x44)),
            implementation_word(SIGNAL_SERVICE_IMPLEMENTATION) | (U256::from(1) << 160),
        ] {
            let other = state(value);
            let header = start_header(other.root);
            let witness = other.witness(proxy, &[IMPLEMENTATION_SLOT]);
            let staking = other.witness(params.staking, &[IMPLEMENTATION_SLOT]);
            assert_safety(
                check(&at_s(&snapshot, &header), &header, Some(&witness), Some(&staking)),
                "SignalService implementation differs from switch",
            );
        }

        // A header at another height, under another parent or state root, or at the fork, is
        // not the S the Inbox recorded; another account's proof is not the proxy's.
        for changed in [
            Header { number: S + 1, ..header.clone() },
            Header { parent_hash: B256::repeat_byte(9), ..header.clone() },
            Header { state_root: state(U256::from(1)).root, ..header.clone() },
        ] {
            assert_safety(
                check(&snapshot, &changed, Some(&witness), Some(&staking)),
                "contradicts the S header",
            );
        }
        let at_fork = Header { timestamp: FORK, ..header.clone() };
        assert_safety(
            check(&at_s(&snapshot, &at_fork), &at_fork, Some(&witness), Some(&staking)),
            "contradicts the S header",
        );
        let foreign = l2.witness(OTHER_ACCOUNT, &[IMPLEMENTATION_SLOT]);
        assert_safety(
            check(&snapshot, &header, Some(&foreign), Some(&staking)),
            "SignalService witness proves another account",
        );

        // Malformed proofs: a tampered node, a value the proof does not carry, no slot proof.
        let mut tampered = witness.clone();
        let mut node = tampered.account_proof[0].to_vec();
        node[3] ^= 1;
        tampered.account_proof[0] = node.into();
        let mut forged = witness.clone();
        forged.storage[0].value = implementation_word(Address::repeat_byte(0x44));
        let mut missing = witness.clone();
        missing.storage.clear();
        for malformed in [tampered, forged, missing] {
            assert_safety(
                check(&snapshot, &header, Some(&malformed), Some(&staking)),
                "SignalService implementation proof",
            );
        }

        // After S, and on a network without a switch, the proof carries neither witness.
        let later = LandingSnapshot { checkpoint_height: S + 1, ..snapshot.clone() };
        let fresh = abci::ChainParams { switch: None, ..params.clone() };
        for (snapshot, params) in [(&later, &params), (&snapshot, &fresh)] {
            verify_start_witness(snapshot, &header, params, None, None).unwrap();
            for (signal_service, staking) in
                [(Some(&witness), None), (None, Some(&staking)), (Some(&witness), Some(&staking))]
            {
                assert_safety(
                    verify_start_witness(snapshot, &header, params, signal_service, staking),
                    "unexpected",
                );
            }
        }
    }

    /// The first proof from S fails unless the staking proxy's EIP-1967 slot holds the
    /// `EtnaStaking` implementation built in for the L2 chain id, with the SignalService proxy's
    /// holding its own: another implementation, the SignalService one, the built-in one with
    /// dirty address padding, an empty slot, no proxy at all, or a proof of a value S's state
    /// does not hold.
    #[test]
    fn start_wrong_staking_implementation_fails() {
        let (params, snapshot) = switching();
        let proxy = abci::l2_signal_service_address(params.l2_chain_id);
        let signal_service = (proxy, implementation_word(SIGNAL_SERVICE_IMPLEMENTATION));
        let check = |words: &[(Address, U256)], forge: Option<U256>| {
            let l2 = proxy_state(words);
            let header = start_header(l2.root);
            let mut staking = l2.witness(params.staking, &[IMPLEMENTATION_SLOT]);
            if let Some(value) = forge {
                staking.storage[0].value = value;
            }
            verify_start_witness(
                &at_s(&snapshot, &header),
                &header,
                &params,
                Some(&l2.witness(proxy, &[IMPLEMENTATION_SLOT])),
                Some(&staking),
            )
        };
        let built_in = implementation_word(STAKING_IMPLEMENTATION);
        check(&[signal_service, (params.staking, built_in)], None).unwrap();

        for value in [
            implementation_word(Address::repeat_byte(0x44)),
            implementation_word(SIGNAL_SERVICE_IMPLEMENTATION),
            built_in | (U256::from(1) << 160),
            U256::ZERO,
        ] {
            assert_safety(
                check(&[signal_service, (params.staking, value)], None),
                "EtnaStaking implementation differs from switch",
            );
        }
        assert_safety(check(&[signal_service], None), "EtnaStaking implementation proof");
        assert_safety(
            check(
                &[
                    signal_service,
                    (params.staking, implementation_word(Address::repeat_byte(0x44))),
                ],
                Some(built_in),
            ),
            "EtnaStaking implementation proof",
        );
    }

    /// The staking proxy checked is the one at the staking address the configuration hash
    /// commits: a proof of another account holding the built-in implementation, such as the
    /// SignalService proxy's, fails, and so does checking at a staking address the snapshot's
    /// configuration hash does not commit. Under a configuration hash that commits that other
    /// address, the same proof passes.
    #[test]
    fn start_staking_checked_at_the_config_hash_address() {
        let (params, snapshot) = switching();
        let proxy = abci::l2_signal_service_address(params.l2_chain_id);
        let built_in = implementation_word(STAKING_IMPLEMENTATION);
        let l2 = proxy_state(&[
            (proxy, implementation_word(SIGNAL_SERVICE_IMPLEMENTATION)),
            (params.staking, built_in),
            (OTHER_ACCOUNT, built_in),
        ]);
        let header = start_header(l2.root);
        let snapshot = at_s(&snapshot, &header);
        let signal_service = l2.witness(proxy, &[IMPLEMENTATION_SLOT]);
        let staking = l2.witness(params.staking, &[IMPLEMENTATION_SLOT]);
        let other = l2.witness(OTHER_ACCOUNT, &[IMPLEMENTATION_SLOT]);
        let check = |snapshot: &LandingSnapshot,
                     params: &abci::ChainParams,
                     staking: &AccountWitness| {
            verify_start_witness(snapshot, &header, params, Some(&signal_service), Some(staking))
        };
        check(&snapshot, &params, &staking).unwrap();
        for foreign in [&other, &signal_service] {
            assert_safety(
                check(&snapshot, &params, foreign),
                "EtnaStaking witness proves another account",
            );
        }

        let moved = abci::ChainParams { staking: OTHER_ACCOUNT, ..params.clone() };
        let error = check(&snapshot, &moved, &other).unwrap_err();
        let LanderError::Configuration(reason) = &error else { panic!("{error}") };
        assert!(reason.contains("configuration hash"), "{error}");
        let committed = LandingSnapshot { config_hash: moved.config_hash(), ..snapshot.clone() };
        check(&committed, &moved, &other).unwrap();
        assert_safety(
            check(&committed, &moved, &staking),
            "EtnaStaking witness proves another account",
        );
    }
}
