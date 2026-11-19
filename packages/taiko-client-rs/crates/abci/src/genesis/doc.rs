//! The CometBFT v0.40 `genesis.json` document.
//!
//! The types mirror CometBFT's JSON exactly: every integer is a decimal string, as Go's amino
//! JSON writes `int64`/`uint64`, and the field order is CometBFT's own. Only the fields an Etna
//! genesis sets are modelled; the values are fixed except `genesis_time`, `chain_id`,
//! `initial_height`, `validators` and `app_state`, which [`build_genesis`](super::build_genesis)
//! derives from L1.

use crate::key::{CometPublicKey, ConsensusKey};
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
use tendermint::Time;

use super::{AppStateJson, GenesisError, GenesisWitness};
use crate::{
    types::Member,
    valstate::{ValState, ValStateError, app_hash},
};

/// The CometBFT `genesis.json` of an Etna chain.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GenesisDoc {
    /// RFC 3339 UTC time of `L1_0` (deployment) or R (recovery), whole seconds
    /// (`YYYY-MM-DDTHH:MM:SSZ`).
    pub genesis_time: String,
    /// The 48-byte chain ID authenticating the complete deployment domain.
    pub chain_id: String,
    /// First global consensus height: S+1 for deployment, c+1 for recovery.
    pub initial_height: String,
    /// The consensus parameters ([`GenesisConsensusParams::etna`]).
    pub consensus_params: GenesisConsensusParams,
    /// Initial committee in set-key order, derived at genesis cutoff or recovery R.
    pub validators: Vec<GenesisValidator>,
    /// appHash(o) of the origin o (CONS-3.1-8, ENC-A-29b.e): the start hash or ELHash(c) with the
    /// genesis validator state of `validators` at o, uppercase hex for stock Comet JSON
    /// ([`genesis_app_hash`]).
    pub app_hash: String,
    /// The genesis witness, embedded as the JSON object `{"witness": "0x<hex>"}`.
    pub app_state: AppStateJson,
}

/// CometBFT's `consensus_params` (v0.40 shape).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GenesisConsensusParams {
    /// Block size limits.
    pub block: BlockParams,
    /// Evidence age and size limits.
    pub evidence: EvidenceParams,
    /// Accepted validator key types.
    pub validator: ValidatorParams,
    /// The app protocol version.
    pub version: VersionParams,
    /// ABCI feature switches.
    pub abci: AbciParams,
    /// The consensus-parameter update authority.
    pub authority: AuthorityParams,
}

/// `consensus_params.block`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BlockParams {
    /// Maximum block size in bytes, as a decimal string.
    pub max_bytes: String,
    /// Maximum gas per block, as a decimal string (`-1` = unlimited).
    pub max_gas: String,
}

/// `consensus_params.evidence`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EvidenceParams {
    /// Maximum evidence age in blocks, as a decimal string.
    pub max_age_num_blocks: String,
    /// Maximum evidence age in nanoseconds, as a decimal string.
    pub max_age_duration: String,
    /// Maximum total evidence size per block in bytes, as a decimal string.
    pub max_bytes: String,
}

/// `consensus_params.validator`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValidatorParams {
    /// The accepted validator key types (CometBFT names, `secp256k1eth` for this deployment).
    pub pub_key_types: Vec<String>,
}

/// `consensus_params.version`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VersionParams {
    /// The app protocol version, as a decimal string.
    pub app: String,
}

/// `consensus_params.abci`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AbciParams {
    /// The first height with vote extensions, as a decimal string (`0` = disabled).
    pub vote_extensions_enable_height: String,
}

/// `consensus_params.authority`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AuthorityParams {
    /// The account allowed to update consensus parameters (empty = none).
    pub authority: String,
}

/// START-10-21's evidence age limit in blocks. Stock CometBFT v0.40.0 accepts evidence until it
/// is older than both this and [`EVIDENCE_MAX_AGE_DURATION`].
pub const EVIDENCE_MAX_AGE_NUM_BLOCKS: u64 = 900;
/// START-10-21's evidence age limit in time: 1 h.
pub const EVIDENCE_MAX_AGE_DURATION: std::time::Duration = std::time::Duration::from_secs(3_600);

impl GenesisConsensusParams {
    /// Stock v0.40 ConsensusParams.Hash for the immutable Etna parameters. Comet hashes only
    /// HashedParams' block-byte and gas limits, using canonical protobuf and SHA-256.
    pub fn etna_hash() -> alloy_primitives::B256 {
        use prost::Message;
        use sha2::{Digest, Sha256};
        let block = Self::abci().block.expect("fixed block parameters");
        let bytes = tendermint_proto::v0_38::types::HashedParams {
            block_max_bytes: block.max_bytes,
            block_max_gas: block.max_gas,
        }
        .encode_to_vec();
        alloy_primitives::B256::from_slice(&Sha256::digest(bytes))
    }

    /// Canonical parameters representable by the ABCI request type. CometBFT v0.40.0 also passes
    /// the parameter-update authority to InitChain, which tendermint-rs does not decode; it need
    /// not be compared, as the app never changes consensus params (START-10-23).
    pub(crate) fn abci() -> tendermint_proto::v0_38::types::ConsensusParams {
        use tendermint_proto::{google::protobuf::Duration, v0_38::types};
        types::ConsensusParams {
            block: Some(types::BlockParams { max_bytes: 22_020_096, max_gas: -1 }),
            evidence: Some(types::EvidenceParams {
                max_age_num_blocks: EVIDENCE_MAX_AGE_NUM_BLOCKS as i64,
                max_age_duration: Some(Duration {
                    seconds: EVIDENCE_MAX_AGE_DURATION.as_secs() as i64,
                    nanos: 0,
                }),
                max_bytes: 1_048_576,
            }),
            validator: Some(types::ValidatorParams { pub_key_types: vec!["secp256k1eth".into()] }),
            version: Some(types::VersionParams { app: crate::app::APP_VERSION }),
            abci: Some(types::AbciParams { vote_extensions_enable_height: 0 }),
        }
    }

    /// The parameters of every Etna genesis: CometBFT's default `block.max_bytes` (22,020,096,
    /// above any envelope) without a gas limit, START-10-21's evidence limits (900 blocks, 1 h,
    /// 1 MiB), secp256k1eth keys only, the current app version, vote extensions disabled, and no
    /// update authority.
    pub fn etna() -> Self {
        let params = Self::abci();
        Self {
            block: BlockParams {
                max_bytes: params.block.as_ref().expect("block params").max_bytes.to_string(),
                max_gas: params.block.as_ref().expect("block params").max_gas.to_string(),
            },
            evidence: EvidenceParams {
                max_age_num_blocks: params
                    .evidence
                    .as_ref()
                    .expect("evidence params")
                    .max_age_num_blocks
                    .to_string(),
                max_age_duration: EVIDENCE_MAX_AGE_DURATION.as_nanos().to_string(),
                max_bytes: params.evidence.as_ref().expect("evidence params").max_bytes.to_string(),
            },
            validator: ValidatorParams { pub_key_types: vec!["secp256k1eth".into()] },
            version: VersionParams { app: crate::app::APP_VERSION.to_string() },
            abci: AbciParams { vote_extensions_enable_height: "0".into() },
            authority: AuthorityParams { authority: String::new() },
        }
    }
}

/// Converts an authenticated whole-second L1 timestamp to a valid CometBFT genesis time.
pub(crate) fn genesis_time(timestamp: u64) -> Result<Time, GenesisError> {
    i64::try_from(timestamp)
        .ok()
        .and_then(|secs| Time::from_unix_timestamp(secs, 0).ok())
        .ok_or(GenesisError::GenesisTime(timestamp))
}

/// One genesis validator.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GenesisValidator {
    /// [`validator_address`] of the key.
    pub address: String,
    /// The native SEC1 key in stock Comet JSON with a base64 value.
    pub pub_key: CometPublicKey,
    /// The voting power, as a decimal string.
    pub power: String,
    /// The validator name; always empty.
    pub name: String,
}

impl GenesisValidator {
    /// The genesis validator of committee member `m`: its native key and mapped power.
    pub fn from_member(m: &Member) -> Self {
        Self {
            address: validator_address(m.pubkey),
            pub_key: CometPublicKey(m.pubkey),
            power: m.power.to_string(),
            name: String::new(),
        }
    }
}

/// Upper-case hex of the native key's full 20-byte Ethereum address.
pub fn validator_address(pubkey: ConsensusKey) -> String {
    alloy_primitives::hex::encode_upper(pubkey.address())
}

/// A genesis document's `app_hash`, appHash(o) (CONS-3.1-8, ENC-A-29b.e) as uppercase hex: the
/// origin's EL hash `el_hash` with CometBFT's genesis validator state of the committee `members`
/// at the origin height `height`. Fails exactly where CometBFT refuses that set.
pub fn genesis_app_hash(
    height: u64,
    el_hash: B256,
    members: &[Member],
) -> Result<String, ValStateError> {
    let validators: Vec<_> = members.iter().map(|m| (m.pubkey, m.power)).collect();
    let val_state = ValState::genesis(height, &validators)?;
    Ok(alloy_primitives::hex::encode_upper(app_hash(el_hash, val_state.hash())))
}

impl GenesisDoc {
    /// The genesis document of a verified genesis: `w` as `app_state` (its `L1_0` timestamp as
    /// `genesis_time`), `chain_id`, `initial_height` and the committee `members` (set-key order)
    /// as validators, with [`GenesisConsensusParams::etna`] and appHash(S) of the start hash and
    /// their genesis validator state ([`genesis_app_hash`]).
    ///
    /// Fails with [`GenesisError::GenesisTime`] when the `L1_0` timestamp is not a valid
    /// CometBFT time, and with [`GenesisError::ValidatorSet`] when CometBFT refuses `members`.
    pub(crate) fn assemble(
        w: &GenesisWitness,
        chain_id: String,
        members: &[Member],
    ) -> Result<Self, GenesisError> {
        let genesis_time = genesis_time(w.l1_header.timestamp())?;
        let word = |slot: u64| {
            w.inbox
                .storage
                .iter()
                .find(|word| word.slot == crate::l1::layout::inbox::slot(slot))
                .expect("verified genesis slot")
                .value
        };
        let start_height =
            crate::l1::layout::word_u48(word(crate::l1::layout::inbox::GENESIS_PACKED), 0);
        let start_hash = B256::from(word(crate::l1::layout::inbox::START_BLOCK_HASH));
        Ok(Self {
            genesis_time: genesis_time.to_rfc3339(),
            chain_id,
            initial_height: (start_height + 1).to_string(),
            consensus_params: GenesisConsensusParams::etna(),
            validators: members.iter().map(GenesisValidator::from_member).collect(),
            app_hash: genesis_app_hash(start_height, start_hash, members)?,
            app_state: AppStateJson::from(w),
        })
    }

    /// The document as pretty-printed JSON (no trailing newline).
    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self).expect("a genesis document always serializes")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{Fixture, edit_l1_header, powers, test_key};
    #[test]
    fn validator_identity_is_full_ethereum_address() {
        let k = ConsensusKey::from_slice(&alloy_primitives::hex!(
            "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        ))
        .unwrap();
        assert_eq!(validator_address(k), "7E5F4552091A69125D5DFCB7B8C2659029395BDF");
    }
    #[test]
    fn json_preserves_stock_parameters_and_genesis_app_hash() {
        let fx = Fixture::genesis(2);
        let doc =
            GenesisDoc::assemble(&fx.witness, fx.request.chain_id.clone(), &fx.members).unwrap();
        let value = serde_json::to_value(&doc).unwrap();
        assert_eq!(
            value["consensus_params"]["validator"]["pub_key_types"],
            serde_json::json!(["secp256k1eth"])
        );
        assert_eq!(value["consensus_params"]["version"]["app"], "1");
        assert_eq!(value["consensus_params"]["block"]["max_bytes"], "22020096");
        let genesis = ValState::genesis(fx.genesis.genesis_height, &powers(&fx.members)).unwrap();
        assert_eq!(
            doc.app_hash,
            alloy_primitives::hex::encode_upper(app_hash(fx.genesis.genesis_hash, genesis.hash()))
        );
        assert_eq!(doc.initial_height, "1");
        assert_eq!(serde_json::from_value::<GenesisDoc>(value).unwrap(), doc);
    }
    /// START-10-21's evidence limits (900 blocks, 1 h, 1 MiB), in the genesis JSON (stock
    /// CometBFT writes the duration as nanoseconds in a string) and in InitChain's parameters.
    #[test]
    fn genesis_consensus_params_use_the_spec_evidence_limits() {
        let json = serde_json::to_value(GenesisConsensusParams::etna()).unwrap();
        assert_eq!(
            json["evidence"],
            serde_json::json!({
                "max_age_num_blocks": "900",
                "max_age_duration": "3600000000000",
                "max_bytes": "1048576",
            })
        );
        let evidence = GenesisConsensusParams::abci().evidence.unwrap();
        assert_eq!(evidence.max_age_num_blocks, 900);
        assert_eq!(
            evidence.max_age_duration,
            Some(tendermint_proto::google::protobuf::Duration { seconds: 3_600, nanos: 0 })
        );
        assert_eq!(evidence.max_bytes, 1_048_576);
    }
    #[test]
    fn validator_power_and_order_are_preserved() {
        let members = [
            Member { pubkey: test_key(9), eff_stake: alloy_primitives::U256::from(1), power: 7 },
            Member { pubkey: test_key(1), eff_stake: alloy_primitives::U256::from(1), power: 8 },
        ];
        let vals = members.iter().map(GenesisValidator::from_member).collect::<Vec<_>>();
        assert_eq!(vals[0].pub_key.0, members[0].pubkey);
        assert_eq!(vals[1].power, "8");
    }
    #[test]
    fn genesis_time_out_of_range_is_rejected() {
        let mut fx = Fixture::genesis(1);
        fx.witness.l1_header = edit_l1_header(&fx.witness.l1_header, |h| h.timestamp = u64::MAX);
        assert!(matches!(
            GenesisDoc::assemble(&fx.witness, "c".into(), &fx.members),
            Err(GenesisError::GenesisTime(u64::MAX))
        ));
    }
}

#[cfg(test)]
mod v1_native_tests {
    use super::*;
    #[test]
    fn v1_genesis_accepts_stock_secp256k1eth_key() {
        let native = serde_json::json!({ "address":"7E5F4552091A69125D5DFCB7B8C2659029395BDF", "pub_key": {"type":"tendermint/PubKeySecp256k1eth", "value":"Anm+Zn753LusVaBilc6HCwcCm/zbLc4o2VnygVsW+BeY"}, "power":"10", "name":"" });
        assert!(serde_json::from_value::<GenesisValidator>(native).is_ok());
    }
}
