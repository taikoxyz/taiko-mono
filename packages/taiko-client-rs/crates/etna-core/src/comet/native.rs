//! Lossless stock CometBFT native certificates and key-bearing block protobufs.
//!
//! Header/vote/commit wire fields reuse the pinned SDK. Only its unsupported native signature
//! and key-bearing evidence nodes are represented here; no alternate cryptography is used.

use alloc::{
    string::{String, ToString},
    vec,
    vec::Vec,
};
use prost::Message;
use serde::{Deserialize, Serialize};
use tendermint::{
    Time, account,
    block::{Height, Id, Round},
};
use tendermint_proto::google::protobuf::Timestamp;
/// SDK protobuf certificate aliases, retaining native signature bytes.
pub use tendermint_proto::v0_38::types::{Commit as RawCommit, CommitSig as RawCommitSig};

/// Native signature bytes; cryptographic validity is checked against the authenticated key.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Signature(
    /// Exactly 65 bytes retained without scalar normalization or recovery-byte rewriting.
    Vec<u8>,
);
impl Signature {
    /// Returns all 65 bytes, including the recovery identifier.
    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }
}
impl TryFrom<Vec<u8>> for Signature {
    /// Incorrect native signature width.
    type Error = String;
    /// Rejects generic 64-byte signatures rather than truncating or padding them.
    fn try_from(bytes: Vec<u8>) -> Result<Self, Self::Error> {
        if bytes.len() != 65 {
            return Err("native signature must contain 65 bytes".into());
        }
        Ok(Self(bytes))
    }
}

/// One validator slot in the native precommit certificate.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CommitSig {
    /// No vote received; contributes no voting power.
    BlockIdFlagAbsent,
    /// Vote for this certificate's block identifier.
    BlockIdFlagCommit {
        /// Ethereum identity derived from the native consensus key.
        validator_address: account::Id,
        /// Canonical stock vote timestamp, including the Unix epoch.
        timestamp: Time,
        /// Full native signature, absent only in malformed in-memory input.
        signature: Option<Signature>,
    },
    /// Authenticated nil vote; contributes no block voting power.
    BlockIdFlagNil {
        /// Ethereum identity derived from the native consensus key.
        validator_address: account::Id,
        /// Canonical stock vote timestamp.
        timestamp: Time,
        /// Full native signature.
        signature: Option<Signature>,
    },
}
impl CommitSig {
    /// Address of a present vote, irrespective of its block/nil flag.
    pub fn validator_address(&self) -> Option<account::Id> {
        match self {
            Self::BlockIdFlagAbsent => None,
            Self::BlockIdFlagCommit { validator_address, .. } |
            Self::BlockIdFlagNil { validator_address, .. } => Some(*validator_address),
        }
    }
}
impl TryFrom<RawCommitSig> for CommitSig {
    /// Malformed flag, address, timestamp or native signature width.
    type Error = String;
    /// Preserves native signed fields and enforces the stock absent-slot shape.
    fn try_from(raw: RawCommitSig) -> Result<Self, Self::Error> {
        if raw.block_id_flag == 1 {
            if !raw.validator_address.is_empty() ||
                !raw.signature.is_empty() ||
                raw.timestamp != Some(zero_timestamp())
            {
                return Err("noncanonical absent commit slot".into());
            }
            return Ok(Self::BlockIdFlagAbsent);
        }
        let validator_address =
            raw.validator_address.try_into().map_err(|e: tendermint::Error| e.to_string())?;
        let timestamp = raw
            .timestamp
            .ok_or("missing vote timestamp")?
            .try_into()
            .map_err(|e: tendermint::Error| e.to_string())?;
        let signature = Some(raw.signature.try_into()?);
        match raw.block_id_flag {
            2 => Ok(Self::BlockIdFlagCommit { validator_address, timestamp, signature }),
            3 => Ok(Self::BlockIdFlagNil { validator_address, timestamp, signature }),
            _ => Err("invalid native commit flag".into()),
        }
    }
}
/// Go's zero time for an absent signature, distinct from a signed Unix-epoch timestamp.
fn zero_timestamp() -> Timestamp {
    Timestamp { seconds: -62135596800, nanos: 0 }
}
impl From<CommitSig> for RawCommitSig {
    /// Reconstructs the exact stock protobuf fields without a signature-domain adapter.
    fn from(sig: CommitSig) -> Self {
        let (flag, address, time, signature) = match sig {
            CommitSig::BlockIdFlagAbsent => {
                return Self {
                    block_id_flag: 1,
                    validator_address: vec![],
                    timestamp: Some(zero_timestamp()),
                    signature: vec![],
                }
            }
            CommitSig::BlockIdFlagCommit { validator_address, timestamp, signature } => {
                (2, validator_address, timestamp, signature)
            }
            CommitSig::BlockIdFlagNil { validator_address, timestamp, signature } => {
                (3, validator_address, timestamp, signature)
            }
        };
        Self {
            block_id_flag: flag,
            validator_address: address.as_bytes().to_vec(),
            timestamp: Some(time.into()),
            signature: signature.map(|s| s.0).unwrap_or_default(),
        }
    }
}

/// Native certificate retaining all stock metadata and ordered signature slots.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(into = "RawCommit")]
pub struct Commit {
    /// Decided Comet height.
    pub height: Height,
    /// Nonnegative stock consensus round.
    pub round: Round,
    /// Header hash and original-block part-set commitment.
    pub block_id: Id,
    /// Received slot order; authentication must compare descending power/ascending address order.
    pub signatures: Vec<CommitSig>,
}
impl<'de> Deserialize<'de> for Commit {
    /// Requires explicit signature timestamps before the SDK can collapse epoch and null values.
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let json = CommitJson::deserialize(deserializer)?;
        RawCommit {
            height: json.height,
            round: json.round,
            block_id: json.block_id,
            signatures: json
                .signatures
                .into_iter()
                .map(|sig| RawCommitSig {
                    block_id_flag: sig.block_id_flag,
                    validator_address: sig.validator_address,
                    timestamp: Some(sig.timestamp),
                    signature: sig.signature,
                })
                .collect(),
        }
        .try_into()
        .map_err(serde::de::Error::custom)
    }
}
/// Stock commit JSON metadata with a timestamp-preserving signature adapter.
/// Typed serde retains its duplicate-field rejection for direct JSON deserialization.
#[derive(Deserialize)]
struct CommitJson {
    /// Stock string-encoded signed height; domain conversion checks its range.
    #[serde(with = "tendermint_proto::serializers::from_str")]
    height: i64,
    /// Stock numeric round; domain conversion rejects negative values.
    round: i32,
    /// Supported SDK block ID, required by the domain conversion.
    block_id: Option<tendermint_proto::v0_38::types::BlockId>,
    /// Received slot order; stock JSON permits a null list for an empty commit.
    #[serde(with = "tendermint_proto::serializers::nullable")]
    signatures: Vec<CommitSigJson>,
}

/// Stock signature JSON with a required timestamp rather than SDK's lossy optional adapter.
#[derive(Deserialize)]
struct CommitSigJson {
    /// Original absent, block or nil discriminator, checked by the native conversion.
    block_id_flag: i32,
    /// Original hexadecimal validator identity, without address rewriting.
    #[serde(with = "tendermint_proto::serializers::bytes::hexstring")]
    validator_address: Vec<u8>,
    /// Required RFC3339 stock timestamp; null and missing are errors, Unix epoch is retained.
    timestamp: Timestamp,
    /// Original base64 signature bytes, including the native recovery byte.
    #[serde(with = "tendermint_proto::serializers::bytes::base64string")]
    signature: Vec<u8>,
}

impl TryFrom<RawCommit> for Commit {
    /// Invalid metadata or native signature slot.
    type Error = String;
    /// Converts supported metadata while retaining each full native signature.
    fn try_from(raw: RawCommit) -> Result<Self, Self::Error> {
        Ok(Self {
            height: raw.height.try_into().map_err(|e: tendermint::Error| e.to_string())?,
            round: raw.round.try_into().map_err(|e: tendermint::Error| e.to_string())?,
            block_id: raw
                .block_id
                .ok_or("missing commit block id")?
                .try_into()
                .map_err(|e: tendermint::Error| e.to_string())?,
            signatures: raw
                .signatures
                .into_iter()
                .map(TryInto::try_into)
                .collect::<Result<_, _>>()?,
        })
    }
}
impl From<Commit> for RawCommit {
    /// Produces exact canonical stock protobuf bytes, including all recovery bytes.
    fn from(commit: Commit) -> Self {
        Self {
            height: commit.height.into(),
            round: commit.round.into(),
            block_id: Some(commit.block_id.into()),
            signatures: commit.signatures.into_iter().map(Into::into).collect(),
        }
    }
}
impl Default for Commit {
    /// Empty height-zero last commit used only by the stock genesis block shape.
    fn default() -> Self {
        Self {
            height: 0u32.into(),
            round: Default::default(),
            block_id: Default::default(),
            signatures: vec![],
        }
    }
}

/// Structurally checked block projection; authentication still requires the original `RawBlock`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Block {
    /// Supported stock header representation and hash algorithm.
    pub header: tendermint::block::Header,
    /// Original consensus transaction bytes, containing one private Etna envelope.
    pub data: Vec<Vec<u8>>,
    /// Previous height's native certificate; absent at a generation's first consensus height.
    pub last_commit: Option<Commit>,
}
impl TryFrom<RawBlock> for Block {
    /// Invalid stock header or last certificate.
    type Error = String;
    /// Keeps evidence exclusively in the original witness rather than normalizing it.
    /// Empty ancestry is structural here; origin-aware body verification authorizes its height.
    fn try_from(raw: RawBlock) -> Result<Self, Self::Error> {
        let header: tendermint::block::Header = raw
            .header
            .ok_or("missing block header")?
            .try_into()
            .map_err(|e: tendermint::Error| e.to_string())?;
        let last_commit = if header.height.value() == 1 ||
            raw.last_commit.as_ref().is_none_or(|c| c == &RawCommit::from(Commit::default()))
        {
            if raw.last_commit.as_ref().is_some_and(|c| c != &RawCommit::from(Commit::default())) {
                return Err("nonempty genesis last commit".into());
            }
            None
        } else {
            Some(raw.last_commit.ok_or("missing last commit")?.try_into()?)
        };
        Ok(Self { header, data: raw.data.ok_or("missing block data")?.txs, last_commit })
    }
}

/// Lossless stock `ValidatorSet` wire node with native key support.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
pub struct ValidatorSet {
    #[prost(message, repeated, tag = "1")]
    /// All validators in the conflicting light-client block, in their original order.
    pub validators: Vec<Validator>,
    #[prost(message, optional, tag = "2")]
    /// Selected proposer, including its original priority and full public key.
    pub proposer: Option<Validator>,
    #[prost(int64, tag = "3")]
    #[serde(with = "tendermint_proto::serializers::from_str", default)]
    #[serde(skip_serializing)]
    /// Signed total power retained in protobuf; stock set JSON omits this cached field.
    pub total_voting_power: i64,
}
/// Lossless stock `Validator` wire node with native key support.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
pub struct Validator {
    #[prost(bytes = "vec", tag = "1")]
    #[serde(with = "tendermint_proto::serializers::bytes::hexstring")]
    /// Stock validator identity bytes; native committee authentication checks the Ethereum
    /// address.
    pub address: Vec<u8>,
    #[prost(message, optional, tag = "2")]
    /// Exact algorithm discriminator and public bytes, without substituting a supported SDK key.
    pub pub_key: Option<PublicKey>,
    #[prost(int64, tag = "3")]
    #[serde(alias = "power", with = "tendermint_proto::serializers::from_str")]
    /// Signed stock voting-power field; evidence hashing must not normalize it.
    pub voting_power: i64,
    #[prost(int64, tag = "4")]
    #[serde(with = "tendermint_proto::serializers::from_str_allow_null")]
    #[serde(default)]
    /// Signed proposer priority retained for the conflicting validator-set protobuf.
    pub proposer_priority: i64,
}
/// Lossless stock `LightBlock` wire node with native key support.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
pub struct LightBlock {
    #[prost(message, optional, tag = "1")]
    /// Foreign header and raw commit, preserving signature bytes without Etna-key conversion.
    pub signed_header: Option<tendermint_proto::v0_38::types::SignedHeader>,
    #[prost(message, optional, tag = "2")]
    /// Original conflicting validator set, including every key-bearing node.
    pub validator_set: Option<ValidatorSet>,
}
/// Lossless stock `LightClientAttackEvidence` wire node with native key support.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
pub struct LightClientAttackEvidence {
    #[prost(message, optional, tag = "1")]
    /// Complete conflicting light-client block whose original encoding enters evidence hashes.
    pub conflicting_block: Option<LightBlock>,
    #[prost(int64, tag = "2")]
    #[serde(with = "tendermint_proto::serializers::from_str")]
    /// Stock common ancestor height, retained as signed int64.
    pub common_height: i64,
    #[prost(message, repeated, tag = "3")]
    /// Accused validators with original keys, powers and priorities.
    pub byzantine_validators: Vec<Validator>,
    #[prost(int64, tag = "4")]
    #[serde(with = "tendermint_proto::serializers::from_str")]
    /// Evidence-reported signed total power; hashing must preserve its exact value.
    pub total_voting_power: i64,
    #[prost(message, optional, tag = "5")]
    /// Original evidence time in seconds/nanoseconds, including Go zero and Unix epoch.
    pub timestamp: Option<tendermint_proto::google::protobuf::Timestamp>,
}
/// Lossless stock `EvidenceList` wire node with native key support.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
pub struct EvidenceList {
    #[prost(message, repeated, tag = "1")]
    #[serde(with = "tendermint_proto::serializers::nullable")]
    /// Original ordered evidence bodies; never publish these as execution DA.
    pub evidence: Vec<Evidence>,
}
/// Lossless stock `Block` wire node with native key support.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
pub struct RawBlock {
    #[prost(message, optional, tag = "1")]
    /// Supported stock header fields, including the original nullable protobuf shapes.
    pub header: Option<tendermint_proto::v0_38::types::Header>,
    #[prost(message, optional, tag = "2")]
    /// Original consensus transactions; their hashes bind the private Etna envelope.
    pub data: Option<tendermint_proto::v0_38::types::Data>,
    #[prost(message, optional, tag = "3")]
    /// Original ordered evidence bodies; never publish these as execution DA.
    pub evidence: Option<EvidenceList>,
    #[prost(message, optional, tag = "4")]
    /// Raw previous certificate, retaining its full native signatures and genesis empty form.
    pub last_commit: Option<RawCommit>,
}

/// Evidence wrapper whose protobuf oneof retains the concrete stock evidence bytes.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Evidence {
    /// Duplicate-vote or native light-client attack evidence.
    #[prost(oneof = "evidence::Sum", tags = "1, 2")]
    pub sum: Option<evidence::Sum>,
}
/// Concrete evidence variants; only the light-client key-bearing subtree differs from the SDK.
pub mod evidence {
    /// Stock evidence discriminator and exact concrete protobuf body.
    #[derive(Clone, PartialEq, prost::Oneof, serde::Serialize, serde::Deserialize)]
    #[serde(tag = "type", content = "value")]
    pub enum Sum {
        /// Stock duplicate-vote evidence, with raw native signature bytes.
        #[prost(message, tag = "1")]
        #[serde(rename = "tendermint/DuplicateVoteEvidence")]
        DuplicateVoteEvidence(tendermint_proto::v0_38::types::DuplicateVoteEvidence),
        /// Light-client attack evidence retaining every native validator key.
        #[prost(message, tag = "2")]
        #[serde(rename = "tendermint/LightClientAttackEvidence")]
        LightClientAttackEvidence(super::LightClientAttackEvidence),
    }
}
/// Opaque key wire wrapper for evidence, including foreign algorithms.
/// Etna committee keys must separately pass `crate::key::ConsensusKey` validation.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
#[serde(transparent)]
pub struct PublicKey {
    /// Explicit algorithm tag; never recoded as a different consensus algorithm.
    #[prost(oneof = "public_key::Sum", tags = "1, 2, 3, 4, 5")]
    pub sum: Option<public_key::Sum>,
}
/// Supported stock key tags needed for preserving evidence from foreign light-client blocks.
pub mod public_key {
    use alloc::vec::Vec;
    /// Exact protobuf oneof and stock JSON key discriminator.
    #[derive(Clone, PartialEq, prost::Oneof, serde::Serialize, serde::Deserialize)]
    #[serde(tag = "type", content = "value")]
    pub enum Sum {
        /// Historical/foreign Ed25519 evidence key, never accepted as an Etna committee key.
        #[prost(bytes, tag = "1")]
        #[serde(
            rename = "tendermint/PubKeyEd25519",
            with = "tendermint_proto::serializers::bytes::base64string"
        )]
        Ed25519(Vec<u8>),
        /// Foreign generic-secp evidence key, never accepted as an Etna committee key.
        #[prost(bytes, tag = "2")]
        #[serde(
            rename = "tendermint/PubKeySecp256k1",
            with = "tendermint_proto::serializers::bytes::base64string"
        )]
        Secp256k1(Vec<u8>),
        /// Foreign BLS evidence key, preserved opaquely without enabling it for Etna consensus.
        #[prost(bytes, tag = "3")]
        #[serde(
            rename = "cometbft/PubKeyBls12_381",
            with = "tendermint_proto::serializers::bytes::base64string"
        )]
        Bls12381(Vec<u8>),
        /// Foreign ML-DSA evidence key, preserved opaquely without enabling it for Etna consensus.
        #[prost(bytes, tag = "4")]
        #[serde(
            rename = "cometbft/PubKeyMlDsa65",
            with = "tendermint_proto::serializers::bytes::base64string"
        )]
        MlDsa65(Vec<u8>),
        /// Native tag5 bytes; valid Etna keys contain 33 canonical compressed SEC1 bytes.
        #[prost(bytes, tag = "5")]
        #[serde(
            rename = "tendermint/PubKeySecp256k1eth",
            with = "tendermint_proto::serializers::bytes::base64string"
        )]
        Secp256k1eth(Vec<u8>),
    }
}
