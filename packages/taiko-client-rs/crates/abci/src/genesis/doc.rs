//! The CometBFT v0.40 `genesis.json` document.
//!
//! The types mirror CometBFT's JSON exactly: every integer is a decimal string, as Go's amino
//! JSON writes `int64`/`uint64`, and the field order is CometBFT's own. Only the fields an Etna
//! genesis sets are modelled; the values are fixed except `genesis_time`, `chain_id`,
//! `initial_height`, `validators` and `app_state`, which [`build_genesis`](super::build_genesis)
//! derives from L1.

use crate::key::{CometPublicKey, ConsensusKey};
use serde::{Deserialize, Serialize};
use tendermint::Time;

use super::{AppStateJson, GenesisError, GenesisWitness};
use crate::types::Member;

/// The CometBFT `genesis.json` of an Etna chain.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GenesisDoc {
    /// RFC 3339 UTC time of L1 block `L1_0`, whole seconds (`YYYY-MM-DDTHH:MM:SSZ`).
    pub genesis_time: String,
    /// The 48-byte chain ID authenticating the complete deployment domain.
    pub chain_id: String,
    /// The first consensus height, always `"1"`, as a decimal string.
    pub initial_height: String,
    /// The consensus parameters ([`GenesisConsensusParams::etna`]).
    pub consensus_params: GenesisConsensusParams,
    /// The `e_0` committee in set-key order.
    pub validators: Vec<GenesisValidator>,
    /// The initial EL genesis hash H*, uppercase hex as required by stock Comet JSON.
    pub app_hash: String,
    /// The genesis witness, embedded as the JSON object `{"witness": "0x<hex>"}`.
    pub app_state: AppStateJson,
}

/// CometBFT's `consensus_params` (v0.40 shape).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
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
pub struct BlockParams {
    /// Maximum block size in bytes, as a decimal string.
    pub max_bytes: String,
    /// Maximum gas per block, as a decimal string (`-1` = unlimited).
    pub max_gas: String,
}

/// `consensus_params.evidence`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
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
pub struct ValidatorParams {
    /// The accepted validator key types (CometBFT names, `secp256k1eth` for this deployment).
    pub pub_key_types: Vec<String>,
}

/// `consensus_params.version`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VersionParams {
    /// The app protocol version, as a decimal string.
    pub app: String,
}

/// `consensus_params.abci`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AbciParams {
    /// The first height with vote extensions, as a decimal string (`0` = disabled).
    pub vote_extensions_enable_height: String,
}

/// `consensus_params.authority`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuthorityParams {
    /// The account allowed to update consensus parameters (empty = none).
    pub authority: String,
}

impl GenesisConsensusParams {
    /// Canonical parameters representable by the ABCI request type. CometBFT v0.40's
    /// authority field is not exposed by tendermint-rs and cannot be compared here.
    pub(crate) fn abci() -> tendermint_proto::v0_38::types::ConsensusParams {
        use tendermint_proto::{google::protobuf::Duration, v0_38::types};
        types::ConsensusParams {
            block: Some(types::BlockParams { max_bytes: 22_020_096, max_gas: -1 }),
            evidence: Some(types::EvidenceParams {
                max_age_num_blocks: 100_000,
                max_age_duration: Some(Duration { seconds: 172_800, nanos: 0 }),
                max_bytes: 1_048_576,
            }),
            validator: Some(types::ValidatorParams { pub_key_types: vec!["secp256k1eth".into()] }),
            version: Some(types::VersionParams { app: crate::app::APP_VERSION }),
            abci: Some(types::AbciParams { vote_extensions_enable_height: 0 }),
        }
    }

    /// The parameters of every Etna genesis: CometBFT's default `block.max_bytes` (22,020,096,
    /// above any envelope) without a gas limit, the default evidence limits (100,000 blocks,
    /// 48 h, 1 MiB), secp256k1eth keys only, the current app version, vote extensions disabled, and
    /// no update authority.
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
                max_age_duration: "172800000000000".into(),
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

impl GenesisDoc {
    /// The genesis document of a verified genesis: `w` as `app_state` (its `L1_0` timestamp as
    /// `genesis_time`), `chain_id`, `initial_height` and the committee `members` (set-key order)
    /// as validators, with [`GenesisConsensusParams::etna`].
    ///
    /// Fails with [`GenesisError::GenesisTime`] when the `L1_0` timestamp is not a valid
    /// CometBFT time.
    pub(crate) fn assemble(
        w: &GenesisWitness,
        chain_id: String,
        members: &[Member],
    ) -> Result<Self, GenesisError> {
        let genesis_time = genesis_time(w.l1_header.timestamp())?;
        Ok(Self {
            genesis_time: genesis_time.to_rfc3339(),
            chain_id,
            initial_height: "1".to_string(),
            consensus_params: GenesisConsensusParams::etna(),
            validators: members.iter().map(GenesisValidator::from_member).collect(),
            app_hash: alloy_primitives::hex::encode_upper(
                w.inbox
                    .storage
                    .iter()
                    .find(|word| {
                        word.slot ==
                            crate::l1::layout::inbox::slot(
                                crate::l1::layout::inbox::GENESIS_BLOCK_HASH,
                            )
                    })
                    .expect("verified genesis hash slot")
                    .value
                    .to_be_bytes::<32>(),
            ),
            app_state: AppStateJson { witness: alloy_rlp::encode(w).into() },
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
    use crate::test_utils::{Fixture, edit_l1_header, test_key};
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
        assert_eq!(doc.app_hash, alloy_primitives::hex::encode_upper(fx.genesis.genesis_hash));
        assert_eq!(doc.initial_height, "1");
        assert_eq!(serde_json::from_value::<GenesisDoc>(value).unwrap(), doc);
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
