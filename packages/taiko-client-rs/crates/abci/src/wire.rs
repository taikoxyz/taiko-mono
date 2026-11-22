//! Narrow stock CometBFT v0.40 adapter for the secp256k1eth public-key variant.
//!
//! The pinned Rust types implement the remaining ABCI fields. They cannot represent key tag5;
//! this module carries that key natively without converting it to a different algorithm.

use crate::key::KeyError;
use etna_core::validator::WireValidator;
pub use etna_core::validator::{ValidatorUpdate, validators_hash, validators_hash_in_order};
use prost::Message;

/// Requests retaining native InitChain keys and uninterpreted Query/snapshot fields.
pub mod request {
    pub use tendermint::v0_38::abci::request::*;
    // These methods consume only Query.path or ignore their inputs entirely. Keep the stock
    // protobuf domains rather than rejecting unused fields in tendermint-rs conversions.
    pub use tendermint_proto::v0_38::abci::{
        RequestApplySnapshotChunk as ApplySnapshotChunk,
        RequestLoadSnapshotChunk as LoadSnapshotChunk, RequestOfferSnapshot as OfferSnapshot,
        RequestQuery as Query,
    };
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

/// Stock ABCI request retaining native keys and the full domains of ignored fields.
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
        use WireRequestValue as Raw;
        let value = WireRequest::decode(bytes)?
            .value
            .ok_or_else(|| WireError::Field("request value missing".into()))?;
        Ok(match value {
            Raw::InitChain(raw) => Self::InitChain(request::InitChain {
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
            }),
            Raw::Echo(value) => Self::Echo(value.try_into().map_err(field_error)?),
            Raw::Flush(_) => Self::Flush,
            Raw::Info(value) => Self::Info(value.try_into().map_err(field_error)?),
            Raw::Query(value) => Self::Query(value),
            Raw::CheckTx(value) => Self::CheckTx(value.try_into().map_err(field_error)?),
            Raw::Commit(_) => Self::Commit,
            Raw::ListSnapshots(_) => Self::ListSnapshots,
            Raw::OfferSnapshot(value) => Self::OfferSnapshot(value),
            Raw::LoadSnapshotChunk(value) => Self::LoadSnapshotChunk(value),
            Raw::ApplySnapshotChunk(value) => Self::ApplySnapshotChunk(value),
            Raw::PrepareProposal(value) => {
                Self::PrepareProposal(value.try_into().map_err(field_error)?)
            }
            Raw::ProcessProposal(value) => {
                Self::ProcessProposal(value.try_into().map_err(field_error)?)
            }
            Raw::ExtendVote(value) => Self::ExtendVote(value.try_into().map_err(field_error)?),
            Raw::VerifyVoteExtension(value) => {
                Self::VerifyVoteExtension(value.try_into().map_err(field_error)?)
            }
            Raw::FinalizeBlock(value) => {
                Self::FinalizeBlock(value.try_into().map_err(field_error)?)
            }
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
    use crate::key::ConsensusKey;
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
    fn request_oneof_selects_the_last_variant_before_native_field_validation() {
        use tendermint_proto::v0_38::abci as pb;
        let echo = pb::Request {
            value: Some(pb::request::Value::Echo(pb::RequestEcho { message: "last".into() })),
        }
        .encode_to_vec();
        let init = fixture("init_chain");
        let init_then_echo = [init.as_ref(), echo.as_slice()].concat();
        assert!(matches!(
            Request::decode(&init_then_echo).unwrap(),
            Request::Echo(value) if value.message == "last"
        ));
        let echo_then_init = [echo.as_slice(), init.as_ref()].concat();
        assert!(matches!(Request::decode(&echo_then_init).unwrap(), Request::InitChain(_)));
        // The superseded InitChain is syntactically valid but lacks required native fields.
        assert!(matches!(
            Request::decode(&[&[0x2a, 0][..], &echo].concat()).unwrap(),
            Request::Echo(_)
        ));
        assert!(Request::decode(&[echo.as_slice(), &[0x2a, 0]].concat()).is_err());
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

/// Selects the stock Request oneof before validating application-consumed fields.
/// InitChain shares the oneof so a superseded native-key request cannot override the last tag.
#[derive(Clone, PartialEq, Message)]
struct WireRequest {
    /// Stock Request variants, including the native-key InitChain representation.
    #[prost(
        oneof = "WireRequestValue",
        tags = "1, 2, 3, 5, 6, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20"
    )]
    value: Option<WireRequestValue>,
}

/// Stock request variants with full protobuf fields and native InitChain validators.
#[derive(Clone, PartialEq, prost::Oneof)]
enum WireRequestValue {
    /// Stock Echo request.
    #[prost(message, tag = "1")]
    Echo(tendermint_proto::v0_38::abci::RequestEcho),
    /// Stock Flush request.
    #[prost(message, tag = "2")]
    Flush(tendermint_proto::v0_38::abci::RequestFlush),
    /// Stock Info request.
    #[prost(message, tag = "3")]
    Info(tendermint_proto::v0_38::abci::RequestInfo),
    /// Stock InitChain request.
    #[prost(message, tag = "5")]
    InitChain(WireInit),
    /// Stock Query request.
    #[prost(message, tag = "6")]
    Query(tendermint_proto::v0_38::abci::RequestQuery),
    /// Stock CheckTx request.
    #[prost(message, tag = "8")]
    CheckTx(tendermint_proto::v0_38::abci::RequestCheckTx),
    /// Stock Commit request.
    #[prost(message, tag = "11")]
    Commit(tendermint_proto::v0_38::abci::RequestCommit),
    /// Stock ListSnapshots request.
    #[prost(message, tag = "12")]
    ListSnapshots(tendermint_proto::v0_38::abci::RequestListSnapshots),
    /// Stock OfferSnapshot request.
    #[prost(message, tag = "13")]
    OfferSnapshot(tendermint_proto::v0_38::abci::RequestOfferSnapshot),
    /// Stock LoadSnapshotChunk request.
    #[prost(message, tag = "14")]
    LoadSnapshotChunk(tendermint_proto::v0_38::abci::RequestLoadSnapshotChunk),
    /// Stock ApplySnapshotChunk request.
    #[prost(message, tag = "15")]
    ApplySnapshotChunk(tendermint_proto::v0_38::abci::RequestApplySnapshotChunk),
    /// Stock PrepareProposal request.
    #[prost(message, tag = "16")]
    PrepareProposal(tendermint_proto::v0_38::abci::RequestPrepareProposal),
    /// Stock ProcessProposal request.
    #[prost(message, tag = "17")]
    ProcessProposal(tendermint_proto::v0_38::abci::RequestProcessProposal),
    /// Stock ExtendVote request.
    #[prost(message, tag = "18")]
    ExtendVote(tendermint_proto::v0_38::abci::RequestExtendVote),
    /// Stock VerifyVoteExtension request.
    #[prost(message, tag = "19")]
    VerifyVoteExtension(tendermint_proto::v0_38::abci::RequestVerifyVoteExtension),
    /// Stock FinalizeBlock request.
    #[prost(message, tag = "20")]
    FinalizeBlock(tendermint_proto::v0_38::abci::RequestFinalizeBlock),
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
