//! Lossless stock CometBFT native certificates and key-bearing block protobufs.
//!
//! Header/vote/commit wire fields reuse the pinned SDK. Only its unsupported native signature
//! and key-bearing evidence nodes are represented here; no alternate cryptography is used.

use self::evidence::Sum as RawEvidence;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use prost::Message;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tendermint::{
    Time, account,
    block::{Height, Id, Round},
};
use tendermint_proto::{
    google::protobuf::Timestamp,
    v0_38::types::{
        Commit as RawCommit, CommitSig as RawCommitSig, Header as RawHeader, Vote as RawVote,
    },
};

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
    /// Whether the slot contributes no vote.
    pub fn is_absent(&self) -> bool {
        matches!(self, Self::BlockIdFlagAbsent)
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
    /// Restores the Unix epoch that the upstream optional timestamp JSON adapter omits.
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let mut raw = RawCommit::deserialize(deserializer)?;
        restore_commit_times(&mut raw);
        raw.try_into().map_err(serde::de::Error::custom)
    }
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

/// Structurally checked host projection; authentication still requires the original `RawBlock`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Block {
    /// Supported stock header representation and hash algorithm.
    pub header: tendermint::block::Header,
    /// Original consensus transaction bytes, containing one private Etna envelope.
    pub data: Vec<Vec<u8>>,
    /// Previous height's complete native certificate; absent at genesis.
    pub last_commit: Option<Commit>,
}
impl TryFrom<RawBlock> for Block {
    /// Invalid stock header or last certificate.
    type Error = String;
    /// Keeps evidence exclusively in the original witness rather than normalizing it.
    fn try_from(raw: RawBlock) -> Result<Self, Self::Error> {
        let header: tendermint::block::Header = raw
            .header
            .ok_or("missing block header")?
            .try_into()
            .map_err(|e: tendermint::Error| e.to_string())?;
        let last_commit = if header.height.value() == 1 {
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
/// Etna committee keys must separately pass `abci::key::ConsensusKey` validation.
#[derive(Clone, PartialEq, Message, Serialize, Deserialize)]
#[serde(transparent)]
pub struct PublicKey {
    /// Explicit algorithm tag; never recoded as a different consensus algorithm.
    #[prost(oneof = "public_key::Sum", tags = "1, 2, 3, 4, 5")]
    pub sum: Option<public_key::Sum>,
}
/// Supported stock key tags needed for preserving evidence from foreign light-client blocks.
pub mod public_key {
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
/// Decodes stock block RPC JSON, preserving evidence, native keys and canonical timestamps.
pub fn decode_block(mut value: serde_json::Value) -> Result<RawBlock, String> {
    if let Some(evidence) = value.pointer_mut("/evidence/evidence").and_then(Value::as_array_mut) {
        for item in evidence {
            if item.get("type").and_then(Value::as_str) == Some("tendermint/DuplicateVoteEvidence")
            {
                for vote in ["vote_a", "vote_b"] {
                    if let Some(vote) = item.pointer_mut(&format!("/value/{vote}")) {
                        decode_vote_extensions(vote)?;
                    }
                }
                continue;
            }
            if item.get("type").and_then(Value::as_str) !=
                Some("tendermint/LightClientAttackEvidence")
            {
                continue;
            }
            if let Some(fields) = item.get_mut("value").and_then(Value::as_object_mut) {
                for (go, proto) in [
                    ("ConflictingBlock", "conflicting_block"),
                    ("CommonHeight", "common_height"),
                    ("ByzantineValidators", "byzantine_validators"),
                    ("TotalVotingPower", "total_voting_power"),
                    ("Timestamp", "timestamp"),
                ] {
                    if let Some(field) = fields.remove(go) &&
                        fields.insert(proto.into(), field).is_some()
                    {
                        return Err(format!("duplicate light-client evidence field {proto}"));
                    }
                }
            }
        }
    }
    let mut block: RawBlock = serde_json::from_value(value).map_err(|e| e.to_string())?;
    restore_block_times(&mut block);
    Ok(block)
}
/// Decodes a stock decision certificate without the SDK's 64-byte signature restriction.
pub fn decode_commit(value: serde_json::Value) -> Result<Commit, String> {
    serde_json::from_value(value).map_err(|e| e.to_string())
}

/// Restores the Unix-epoch times of `block`'s header, last commit and evidence votes and
/// light-client headers and commits ([`restore_header_time`]).
fn restore_block_times(block: &mut RawBlock) {
    if let Some(header) = &mut block.header {
        restore_header_time(header);
    }
    if let Some(commit) = &mut block.last_commit {
        restore_commit_times(commit);
    }
    for evidence in block.evidence.iter_mut().flat_map(|list| list.evidence.iter_mut()) {
        match evidence.sum.as_mut() {
            Some(RawEvidence::DuplicateVoteEvidence(duplicate)) => {
                for vote in [&mut duplicate.vote_a, &mut duplicate.vote_b].into_iter().flatten() {
                    restore_vote_time(vote);
                }
            }
            Some(RawEvidence::LightClientAttackEvidence(attack)) => {
                let signed = attack
                    .conflicting_block
                    .as_mut()
                    .and_then(|light| light.signed_header.as_mut());
                if let Some(signed) = signed {
                    if let Some(header) = &mut signed.header {
                        restore_header_time(header);
                    }
                    if let Some(commit) = &mut signed.commit {
                        restore_commit_times(commit);
                    }
                }
            }
            None => {}
        }
    }
}

/// Go encodes a header's time, a vote's timestamp and a commit signature's timestamp as
/// non-nullable timestamps, so the JSON always carries them; tendermint-proto's JSON adapter
/// (`serializers::optional`) reads one equal to the Unix epoch as absent. An absent value can
/// therefore only be the epoch: restoring it keeps a validator that signs its precommit at the
/// epoch (valid to CometBFT, and covered by the signature) from making a committed block and
/// its certificate unreadable. The hashes and signatures over these fields still bind them.
fn restore_header_time(header: &mut RawHeader) {
    header.time.get_or_insert_with(Default::default);
}

/// [`restore_header_time`] for every signature of `commit`.
fn restore_commit_times(commit: &mut RawCommit) {
    for signature in &mut commit.signatures {
        signature.timestamp.get_or_insert_with(Default::default);
    }
}

/// [`restore_header_time`] for a vote.
fn restore_vote_time(vote: &mut RawVote) {
    vote.timestamp.get_or_insert_with(Default::default);
}

/// Replaces a vote's base64 `extension` and `extension_signature` strings with the byte arrays the
/// proto JSON adapter reads; `null` (no extension) and absent fields stay as they are.
fn decode_vote_extensions(vote: &mut Value) -> std::result::Result<(), String> {
    for field in ["extension", "extension_signature"] {
        let Some(slot) = vote.get_mut(field) else { continue };
        let Some(encoded) = slot.as_str() else { continue };
        let bytes = STANDARD
            .decode(encoded)
            .map_err(|e| format!("duplicate vote evidence {field} base64: {e}"))?;
        *slot = Value::from(bytes);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use prost::Message;
    use tendermint_proto::v0_38::types::{BlockId, Commit as RawCommit, CommitSig, PartSetHeader};

    #[test]
    fn native_certificate_preserves_all_65_signature_bytes() {
        let raw = RawCommit {
            height: 6,
            round: 0,
            block_id: Some(BlockId {
                hash: vec![1; 32],
                part_set_header: Some(PartSetHeader { total: 1, hash: vec![2; 32] }),
            }),
            signatures: vec![CommitSig {
                block_id_flag: 2,
                validator_address: vec![3; 20],
                timestamp: Some(tendermint_proto::google::protobuf::Timestamp {
                    seconds: 0,
                    nanos: 0,
                }),
                signature: vec![4; 65],
            }],
        };
        let bytes = raw.encode_to_vec();
        let commit = Commit::try_from(raw).expect("native 65-byte certificate is representable");
        assert_eq!(RawCommit::from(commit).encode_to_vec(), bytes);
    }
    fn unhex(value: &str) -> Vec<u8> {
        value
            .as_bytes()
            .chunks_exact(2)
            .map(|pair| u8::from_str_radix(std::str::from_utf8(pair).unwrap(), 16).unwrap())
            .collect()
    }

    #[test]
    fn stock_native_block_protobuf_preserves_nested_evidence_keys() {
        for fixture in [
            include_str!("../testdata/cometbft-v0.40/vectors.json"),
            include_str!("../testdata/cometbft-v0.40/differential.json"),
        ] {
            let fixture: serde_json::Value = serde_json::from_str(fixture).unwrap();
            for vector in fixture["vectors"].as_array().unwrap() {
                let bytes = unhex(vector["block_proto"].as_str().unwrap());
                let raw = RawBlock::decode(bytes.as_slice()).unwrap();
                assert_eq!(
                    raw.encode_to_vec(),
                    bytes,
                    "{}: original evidence must survive",
                    vector["name"]
                );
                Block::try_from(raw).unwrap();
                if let Some(encoded) = vector["commit_proto"].as_str() {
                    let bytes = unhex(encoded);
                    let raw = RawCommit::decode(bytes.as_slice()).unwrap();
                    let commit = Commit::try_from(raw).unwrap();
                    assert_eq!(
                        RawCommit::from(commit).encode_to_vec(),
                        bytes,
                        "{}",
                        vector["name"]
                    );
                }
            }
        }
    }

    #[test]
    fn stock_native_rpc_preserves_original_protobufs() {
        for fixture in [
            include_str!("../testdata/cometbft-v0.40/vectors.json"),
            include_str!("../testdata/cometbft-v0.40/differential.json"),
        ] {
            let fixture: serde_json::Value = serde_json::from_str(fixture).unwrap();
            for vector in fixture["vectors"].as_array().unwrap() {
                let name = &vector["name"];
                let raw = decode_block(vector["block_rpc"]["block"].clone())
                    .unwrap_or_else(|e| panic!("{name}: {e}"));
                let bytes = unhex(vector["block_proto"].as_str().unwrap());
                assert!(raw.encode_to_vec() == bytes, "{name}: block RPC must retain exact bytes");
                let commit = decode_commit(vector["commit_rpc"]["signed_header"]["commit"].clone())
                    .unwrap_or_else(|e| panic!("{name}: {e}"));
                if let Some(encoded) = vector["commit_proto"].as_str() {
                    assert!(
                        RawCommit::from(commit).encode_to_vec() == unhex(encoded),
                        "{name}: commit RPC must retain exact bytes"
                    );
                }
            }
        }
    }

    #[test]
    fn direct_commit_json_keeps_unix_epoch_votes() {
        let fixture: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/cometbft-v0.40/differential.json"))
                .unwrap();
        let vector = fixture["vectors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|v| v["name"] == "own_commit_sig_at_unix_epoch")
            .unwrap();
        let commit: Commit =
            serde_json::from_value(vector["commit_rpc"]["signed_header"]["commit"].clone())
                .expect("all public serde entrypoints preserve the Unix epoch");
        assert_eq!(
            RawCommit::from(commit).encode_to_vec(),
            unhex(vector["commit_proto"].as_str().unwrap())
        );
    }

    #[test]
    fn foreign_evidence_keys_keep_all_stock_algorithm_tags() {
        for (tag, kind) in [
            (1u8, "tendermint/PubKeyEd25519"),
            (2, "tendermint/PubKeySecp256k1"),
            (3, "cometbft/PubKeyBls12_381"),
            (4, "cometbft/PubKeyMlDsa65"),
            (5, "tendermint/PubKeySecp256k1eth"),
        ] {
            // Opaque bytes test representation only; these are deliberately not committee keys.
            let encoded = vec![(tag << 3) | 2, 3, 0, 7, 0];
            let key = PublicKey::decode(encoded.as_slice()).unwrap();
            assert_eq!(key.encode_to_vec(), encoded, "stock key tag {tag} must not disappear");
            let json = serde_json::to_value(&key).unwrap();
            assert_eq!(json["type"], kind);
            assert_eq!(json["value"], "AAcA");
            let restored: PublicKey = serde_json::from_value(json).unwrap();
            assert_eq!(restored.encode_to_vec(), encoded);
        }
    }

    #[test]
    fn rejects_legacy_signature_widths_and_malformed_certificate_metadata() {
        let fixture: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/cometbft-v0.40/differential.json"))
                .unwrap();
        let bytes = unhex(fixture["vectors"][0]["commit_proto"].as_str().unwrap());
        let valid = RawCommit::decode(bytes.as_slice()).unwrap();
        for width in [0, 32, 64, 66, 96] {
            let mut raw = valid.clone();
            raw.signatures[0].signature.resize(width, 0);
            assert!(Commit::try_from(raw).is_err(), "signature width {width}");
        }
        for mutation in 0..9 {
            let mut raw = valid.clone();
            match mutation {
                0 => raw.height = -1,
                1 => raw.round = -1,
                2 => raw.block_id = None,
                3 => raw.signatures[0].block_id_flag = 0,
                4 => {
                    raw.signatures[0].validator_address.pop();
                }
                5 => raw.signatures[0].timestamp = None,
                6 => raw.signatures[0].timestamp.as_mut().unwrap().nanos = 1_000_000_000,
                7 => raw.signatures[0].block_id_flag = 1,
                8 => {
                    raw.signatures[0] = super::CommitSig::BlockIdFlagAbsent.into();
                    raw.signatures[0].timestamp = Some(Timestamp { seconds: 0, nanos: 0 });
                }
                _ => unreachable!(),
            }
            assert!(Commit::try_from(raw).is_err(), "malformed certificate mutation {mutation}");
        }
        let raw = RawCommitSig::from(super::CommitSig::BlockIdFlagAbsent);
        assert!(super::CommitSig::try_from(raw).unwrap().is_absent());
    }

    #[test]
    fn rejects_ambiguous_light_client_json_field_aliases() {
        let fixture: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/cometbft-v0.40/vectors.json")).unwrap();
        let vector = fixture["vectors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|v| v["name"] == "light_client_attack")
            .unwrap();
        let mut block = vector["block_rpc"]["block"].clone();
        let fields = block["evidence"]["evidence"][0]["value"].as_object_mut().unwrap();
        fields.insert("conflicting_block".into(), fields["ConflictingBlock"].clone());
        assert!(decode_block(block).is_err());
    }
}
