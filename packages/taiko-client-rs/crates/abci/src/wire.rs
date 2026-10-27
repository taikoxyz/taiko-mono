//! Narrow stock CometBFT v0.40 adapter for the secp256k1eth public-key variant.
//!
//! The pinned Rust types implement the remaining ABCI fields. They cannot represent key tag5;
//! this module carries that key natively without converting it to a different algorithm.

use crate::key::{ConsensusKey, KeyError};
use prost::Message;

/// A native validator update, including zero power for removal at H+2.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ValidatorUpdate {
    /// Validated compressed secp256k1eth key.
    pub pub_key: ConsensusKey,
    /// Stock nonnegative voting power; zero removes an existing validator.
    pub power: tendermint::vote::Power,
}

/// The stock ValidatorUpdate/SimpleValidator two-field protobuf layout.
#[derive(Clone, PartialEq, Message)]
struct WireValidator {
    /// Native crypto.PublicKey rather than tendermint-rs's incomplete key enum.
    #[prost(bytes = "vec", optional, tag = "1")]
    pub_key: Option<Vec<u8>>,
    /// Stock int64 nonnegative voting power.
    #[prost(int64, tag = "2")]
    power: i64,
}

impl ValidatorUpdate {
    /// Canonical stock protobuf bytes, including the secp256k1eth oneof tag5.
    pub fn encode(self) -> Vec<u8> {
        self.into_wire().encode_to_vec()
    }

    /// Converts the native update to its exact stock protobuf message.
    fn into_wire(self) -> WireValidator {
        WireValidator {
            pub_key: Some([&[0x2a, 33][..], self.pub_key.as_bytes()].concat()),
            power: i64::from(self.power),
        }
    }

    /// Decodes a stock validator update and rejects absent, legacy or malformed keys.
    pub fn decode(bytes: &[u8]) -> Result<Self, KeyError> {
        Self::from_wire(WireValidator::decode(bytes).map_err(|_| KeyError)?)
    }

    /// Requires exactly the supported key type and nonnegative stock voting power.
    fn from_wire(raw: WireValidator) -> Result<Self, KeyError> {
        let bytes = raw.pub_key.ok_or(KeyError)?;
        // Preserve the native oneof exactly; accepting another algorithm alongside tag5 could
        // disagree with stock protobuf's last-oneof-field-wins semantics.
        if bytes.len() != 35 || bytes[..2] != [0x2a, 33] {
            return Err(KeyError);
        }
        Ok(Self {
            pub_key: ConsensusKey::from_slice(&bytes[2..])?,
            power: raw.power.try_into().map_err(|_| KeyError)?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::hex;
    #[test]
    fn validator_update_uses_tag_five_and_rejects_legacy_key_tags() {
        let bytes =
            hex!("0a232a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798100a");
        let update = ValidatorUpdate::decode(&bytes).expect("stock tag5");
        assert_eq!(update.power.value(), 10);
        assert_eq!(update.encode(), bytes);
        for tag in [0x0a, 0x12] {
            let mut legacy = bytes;
            legacy[2] = tag;
            assert!(ValidatorUpdate::decode(&legacy).is_err());
        }
    }
    #[test]
    fn ambiguous_key_algorithm_fields_are_rejected() {
        let native = hex!("2a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798");
        let legacy = [vec![0x0a, 32], vec![7; 32]].concat();
        for key in [[native.to_vec(), legacy.clone()].concat(), [legacy, native.to_vec()].concat()]
        {
            let update = [vec![0x0a, key.len() as u8], key, vec![0x10, 1]].concat();
            assert!(ValidatorUpdate::decode(&update).is_err());
        }
    }
}

/// Native requests whose key-bearing InitChain cannot pass through tendermint-rs.
pub mod request {
    pub use tendermint::v0_38::abci::request::*;
    /// Stock InitChain with native tag5 validators and raw consensus key-type strings.
    #[derive(Clone, Debug, PartialEq)]
    pub struct InitChain {
        /// Fixed canonical L1 origin timestamp.
        pub time: tendermint::Time,
        /// Exact deployment/generation domain string.
        pub chain_id: String,
        /// Stock parameters, retaining the unsupported-in-Rust secp256k1eth type string.
        pub consensus_params: tendermint_proto::v0_38::types::ConsensusParams,
        /// Genesis validators, validated without substituting another key algorithm.
        pub validators: Vec<super::ValidatorUpdate>,
        /// Authenticated genesis witness, encoded by the application.
        pub app_state_bytes: prost::bytes::Bytes,
        /// First new-generation Comet block, distinct from the EL bootstrap boundary.
        pub initial_height: tendermint::block::Height,
    }
}

/// Native responses retaining stock non-key fields.
pub mod response {
    pub use tendermint::v0_38::abci::response::*;
    /// Stock FinalizeBlock with native secp256k1eth H+2 validator updates.
    #[derive(Clone, Debug, PartialEq)]
    pub struct FinalizeBlock {
        /// Application events.
        pub events: Vec<tendermint::abci::Event>,
        /// Canonical per-transaction execution results.
        pub tx_results: Vec<tendermint::abci::types::ExecTxResult>,
        /// Validator authority changes effective two heights later.
        pub validator_updates: Vec<super::ValidatorUpdate>,
        /// Etna never updates consensus parameters; always None.
        pub consensus_param_updates: Option<tendermint_proto::v0_38::types::ConsensusParams>,
        /// Executed EL block hash.
        pub app_hash: tendermint::AppHash,
    }
}

/// Invalid protobuf, key type or required stock field at the native ABCI boundary.
#[derive(Debug, thiserror::Error)]
pub enum WireError {
    /// Malformed protobuf wire bytes.
    #[error(transparent)]
    Protobuf(#[from] prost::DecodeError),
    /// A key is missing, legacy or malformed.
    #[error(transparent)]
    Key(#[from] KeyError),
    /// A required or typed field is invalid.
    #[error("invalid ABCI field: {0}")]
    Field(String),
}

/// Stock ABCI request with only key-bearing messages adapted.
#[derive(Clone, Debug, PartialEq)]
pub enum Request {
    /// Stock Echo request.
    Echo(request::Echo),
    /// Stock Flush request.
    Flush,
    /// Stock Info request.
    Info(request::Info),
    /// Stock InitChain request.
    InitChain(request::InitChain),
    /// Stock Query request.
    Query(request::Query),
    /// Stock CheckTx request.
    CheckTx(request::CheckTx),
    /// Stock Commit request.
    Commit,
    /// Stock ListSnapshots request.
    ListSnapshots,
    /// Stock OfferSnapshot request.
    OfferSnapshot(request::OfferSnapshot),
    /// Stock LoadSnapshotChunk request.
    LoadSnapshotChunk(request::LoadSnapshotChunk),
    /// Stock ApplySnapshotChunk request.
    ApplySnapshotChunk(request::ApplySnapshotChunk),
    /// Stock PrepareProposal request.
    PrepareProposal(request::PrepareProposal),
    /// Stock ProcessProposal request.
    ProcessProposal(request::ProcessProposal),
    /// Stock ExtendVote request.
    ExtendVote(request::ExtendVote),
    /// Stock VerifyVoteExtension request.
    VerifyVoteExtension(request::VerifyVoteExtension),
    /// Stock FinalizeBlock request.
    FinalizeBlock(request::FinalizeBlock),
}

/// Stock ABCI response with only key-bearing messages adapted.
#[derive(Clone, Debug, PartialEq)]
pub enum Response {
    /// Stock Exception response.
    Exception(response::Exception),
    /// Stock Echo response.
    Echo(response::Echo),
    /// Stock Flush response.
    Flush,
    /// Stock Info response.
    Info(response::Info),
    /// Stock InitChain response.
    InitChain(response::InitChain),
    /// Stock Query response.
    Query(response::Query),
    /// Stock CheckTx response.
    CheckTx(response::CheckTx),
    /// Stock Commit response.
    Commit(response::Commit),
    /// Stock ListSnapshots response.
    ListSnapshots(response::ListSnapshots),
    /// Stock OfferSnapshot response.
    OfferSnapshot(response::OfferSnapshot),
    /// Stock LoadSnapshotChunk response.
    LoadSnapshotChunk(response::LoadSnapshotChunk),
    /// Stock ApplySnapshotChunk response.
    ApplySnapshotChunk(response::ApplySnapshotChunk),
    /// Stock PrepareProposal response.
    PrepareProposal(response::PrepareProposal),
    /// Stock ProcessProposal response.
    ProcessProposal(response::ProcessProposal),
    /// Stock ExtendVote response.
    ExtendVote(response::ExtendVote),
    /// Stock VerifyVoteExtension response.
    VerifyVoteExtension(response::VerifyVoteExtension),
    /// Stock FinalizeBlock response.
    FinalizeBlock(response::FinalizeBlock),
}

impl Request {
    /// Decodes an unframed stock ABCI request, retaining tag5 InitChain validators.
    pub fn decode(bytes: &[u8]) -> Result<Self, WireError> {
        if let Some(raw) = InitEnvelope::decode(bytes)?.init {
            return Ok(Self::InitChain(request::InitChain {
                time: raw
                    .time
                    .ok_or_else(|| WireError::Field("genesis time missing".into()))?
                    .try_into()
                    .map_err(field_error)?,
                chain_id: raw.chain_id,
                consensus_params: raw
                    .consensus_params
                    .ok_or_else(|| WireError::Field("consensus params missing".into()))?,
                validators: raw
                    .validators
                    .into_iter()
                    .map(ValidatorUpdate::from_wire)
                    .collect::<Result<_, _>>()?,
                app_state_bytes: raw.app_state_bytes,
                initial_height: raw.initial_height.try_into().map_err(field_error)?,
            }));
        }
        let raw = tendermint_proto::v0_38::abci::Request::decode(bytes)?;
        let typed = tendermint::v0_38::abci::Request::try_from(raw).map_err(field_error)?;
        use tendermint::v0_38::abci::Request as Legacy;
        Ok(match typed {
            Legacy::Echo(value) => Self::Echo(value),
            Legacy::Flush => Self::Flush,
            Legacy::Info(value) => Self::Info(value),
            Legacy::Query(value) => Self::Query(value),
            Legacy::CheckTx(value) => Self::CheckTx(value),
            Legacy::Commit => Self::Commit,
            Legacy::ListSnapshots => Self::ListSnapshots,
            Legacy::OfferSnapshot(value) => Self::OfferSnapshot(value),
            Legacy::LoadSnapshotChunk(value) => Self::LoadSnapshotChunk(value),
            Legacy::ApplySnapshotChunk(value) => Self::ApplySnapshotChunk(value),
            Legacy::PrepareProposal(value) => Self::PrepareProposal(value),
            Legacy::ProcessProposal(value) => Self::ProcessProposal(value),
            Legacy::ExtendVote(value) => Self::ExtendVote(value),
            Legacy::VerifyVoteExtension(value) => Self::VerifyVoteExtension(value),
            Legacy::FinalizeBlock(value) => Self::FinalizeBlock(value),
            Legacy::InitChain(_) => return Err(WireError::Field("unrecognized InitChain".into())),
        })
    }
}

impl Response {
    /// Encodes an unframed stock ABCI response with canonical native validator keys.
    pub fn encode(self) -> Vec<u8> {
        use tendermint::v0_38::abci::Response as Legacy;
        let typed = match self {
            Self::FinalizeBlock(value) => {
                return FinalizeEnvelope {
                    finalize: Some(WireFinalize {
                        events: value.events.into_iter().map(Into::into).collect(),
                        tx_results: value.tx_results.into_iter().map(Into::into).collect(),
                        validators: value
                            .validator_updates
                            .into_iter()
                            .map(ValidatorUpdate::into_wire)
                            .collect(),
                        params: value.consensus_param_updates,
                        app_hash: value.app_hash.into(),
                    }),
                }
                .encode_to_vec()
            }
            Self::Exception(value) => Legacy::Exception(value),
            Self::Echo(value) => Legacy::Echo(value),
            Self::Flush => Legacy::Flush,
            Self::Info(value) => Legacy::Info(value),
            Self::InitChain(value) => Legacy::InitChain(value),
            Self::Query(value) => Legacy::Query(value),
            Self::CheckTx(value) => Legacy::CheckTx(value),
            Self::Commit(value) => Legacy::Commit(value),
            Self::ListSnapshots(value) => Legacy::ListSnapshots(value),
            Self::OfferSnapshot(value) => Legacy::OfferSnapshot(value),
            Self::LoadSnapshotChunk(value) => Legacy::LoadSnapshotChunk(value),
            Self::ApplySnapshotChunk(value) => Legacy::ApplySnapshotChunk(value),
            Self::PrepareProposal(value) => Legacy::PrepareProposal(value),
            Self::ProcessProposal(value) => Legacy::ProcessProposal(value),
            Self::ExtendVote(value) => Legacy::ExtendVote(value),
            Self::VerifyVoteExtension(value) => Legacy::VerifyVoteExtension(value),
        };
        tendermint_proto::v0_38::abci::Response::from(typed).encode_to_vec()
    }
}

#[cfg(test)]
mod stock_wire_tests {
    use super::*;
    use alloy_primitives::Bytes;
    fn fixture(name: &str) -> Bytes {
        let value: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/comet-wire.json")).unwrap();
        value[name].as_str().unwrap().parse().unwrap()
    }
    #[test]
    fn decodes_stock_init_chain_without_losing_tag5() {
        let Request::InitChain(request) = Request::decode(&fixture("init_chain")).unwrap() else {
            panic!("InitChain");
        };
        assert_eq!(request.initial_height.value(), 1);
        assert_eq!(request.validators.len(), 3);
        assert_eq!(request.validators[0].power.value(), 10);
        assert_eq!(
            request.validators[0].pub_key.address().to_string().to_lowercase(),
            "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf"
        );
        assert_eq!(request.consensus_params.validator.unwrap().pub_key_types, ["secp256k1eth"]);
    }
    #[test]
    fn emits_exact_stock_finalize_block_validator_updates() {
        let value: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/comet-wire.json")).unwrap();
        let updates = value["members"]
            .as_array()
            .unwrap()
            .iter()
            .map(|m| ValidatorUpdate {
                pub_key: ConsensusKey::from_slice(
                    &m["key"].as_str().unwrap().parse::<Bytes>().unwrap(),
                )
                .unwrap(),
                power: m["power"].as_u64().unwrap().try_into().unwrap(),
            })
            .collect();
        let bytes = Response::FinalizeBlock(response::FinalizeBlock {
            events: vec![],
            tx_results: vec![],
            validator_updates: updates,
            consensus_param_updates: None,
            app_hash: vec![1, 2, 3].try_into().unwrap(),
        })
        .encode();
        assert_eq!(bytes.as_slice(), fixture("finalize_block").as_ref());
    }
}

/// Converts typed protobuf validation errors to one boundary error.
fn field_error(error: impl std::fmt::Display) -> WireError {
    WireError::Field(error.to_string())
}

/// Reads only the key-bearing InitChain variant; all other request fields stay upstream.
#[derive(Clone, PartialEq, Message)]
struct InitEnvelope {
    /// Stock Request.InitChain tag5.
    #[prost(message, optional, tag = "5")]
    init: Option<WireInit>,
}
/// Exact stock InitChain fields with native validator keys.
#[derive(Clone, PartialEq, Message)]
struct WireInit {
    /// Fixed genesis timestamp.
    #[prost(message, optional, tag = "1")]
    time: Option<tendermint_proto::google::protobuf::Timestamp>,
    /// Deployment/generation signing domain.
    #[prost(string, tag = "2")]
    chain_id: String,
    /// Stock params retain string algorithm identifiers without typed narrowing.
    #[prost(message, optional, tag = "3")]
    consensus_params: Option<tendermint_proto::v0_38::types::ConsensusParams>,
    /// Native stock validators.
    #[prost(message, repeated, tag = "4")]
    validators: Vec<WireValidator>,
    /// Private authenticated genesis bundle.
    #[prost(bytes = "bytes", tag = "5")]
    app_state_bytes: prost::bytes::Bytes,
    /// First new-generation block height.
    #[prost(int64, tag = "6")]
    initial_height: i64,
}
/// Writes only the key-bearing FinalizeBlock response variant.
#[derive(Clone, PartialEq, Message)]
struct FinalizeEnvelope {
    /// Stock Response.FinalizeBlock tag21.
    #[prost(message, optional, tag = "21")]
    finalize: Option<WireFinalize>,
}
/// Exact stock FinalizeBlock fields with native validator keys.
#[derive(Clone, PartialEq, Message)]
struct WireFinalize {
    /// Application events.
    #[prost(message, repeated, tag = "1")]
    events: Vec<tendermint_proto::v0_38::abci::Event>,
    /// Canonical per-transaction execution results.
    #[prost(message, repeated, tag = "2")]
    tx_results: Vec<tendermint_proto::v0_38::abci::ExecTxResult>,
    /// H+2 authority updates.
    #[prost(message, repeated, tag = "3")]
    validators: Vec<WireValidator>,
    /// Always absent for Etna.
    #[prost(message, optional, tag = "4")]
    params: Option<tendermint_proto::v0_38::types::ConsensusParams>,
    /// Executed EL block hash.
    #[prost(bytes = "bytes", tag = "5")]
    app_hash: prost::bytes::Bytes,
}

/// Computes the stock Comet validator-set Merkle hash in voting-power/address order.
pub fn validators_hash(
    members: &[crate::types::Member],
) -> Result<alloy_primitives::B256, KeyError> {
    let mut sorted = members.iter().collect::<Vec<_>>();
    sorted.sort_by_key(|m| (core::cmp::Reverse(m.power), m.pubkey.address()));
    let leaves = sorted
        .into_iter()
        .map(|m| {
            let power = m.power.try_into().map_err(|_| KeyError)?;
            Ok(ValidatorUpdate { pub_key: m.pubkey, power }.encode())
        })
        .collect::<Result<Vec<_>, KeyError>>()?;
    Ok(tendermint::merkle::simple_hash_from_byte_vectors::<tendermint::crypto::default::Sha256>(
        &leaves,
    )
    .into())
}

#[cfg(test)]
mod validator_hash_tests {
    use super::*;
    #[test]
    fn validators_hash_matches_stock_native_power_address_order() {
        let oracle: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/comet-wire.json")).unwrap();
        let members = oracle["members"]
            .as_array()
            .unwrap()
            .iter()
            .map(|m| crate::types::Member {
                pubkey: ConsensusKey::from_slice(
                    &alloy_primitives::hex::decode(m["key"].as_str().unwrap()).unwrap(),
                )
                .unwrap(),
                power: m["power"].as_u64().unwrap(),
                eff_stake: alloy_primitives::U256::ZERO,
            })
            .collect::<Vec<_>>();
        assert_eq!(
            validators_hash(&members).unwrap(),
            oracle["validators_hash"].as_str().unwrap().parse::<alloy_primitives::B256>().unwrap()
        );
    }
}
