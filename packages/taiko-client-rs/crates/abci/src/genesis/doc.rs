//! The CometBFT v0.40 `genesis.json` document (spec §5.1).
//!
//! The types mirror CometBFT's JSON exactly: every integer is a decimal string, as Go's amino
//! JSON writes `int64`/`uint64`, and the field order is CometBFT's own. Only the fields an Etna
//! genesis sets are modelled; the values are fixed except `genesis_time`, `chain_id`,
//! `initial_height`, `validators` and `app_state`, which [`build_genesis`](super::build_genesis)
//! derives from L1.

use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
use tendermint::{PublicKey, Time, account};

use super::{AppStateJson, GenesisError, GenesisWitness};
use crate::types::Member;

/// The CometBFT `genesis.json` of an Etna chain.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GenesisDoc {
    /// RFC 3339 UTC time of L1 block `L1_0`, whole seconds (`YYYY-MM-DDTHH:MM:SSZ`).
    pub genesis_time: String,
    /// `taiko-etna-<L2 chain id>-g<recoveryGeneration>`.
    pub chain_id: String,
    /// `B* + 1`, as a decimal string (D8).
    pub initial_height: String,
    /// The consensus parameters ([`GenesisConsensusParams::etna`]).
    pub consensus_params: GenesisConsensusParams,
    /// The `e_0` committee in MEM-08 order.
    pub validators: Vec<GenesisValidator>,
    /// The initial app hash; empty, as `InitChain` answers `H*`.
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
    /// The accepted validator key types (CometBFT names, e.g. `ed25519`).
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
    /// The parameters of every Etna genesis (spec §5.1): CometBFT's default
    /// `block.max_bytes` (22,020,096, above any envelope) without a gas limit, the default
    /// evidence limits (100,000 blocks, 48 h, 1 MiB), Ed25519 keys only, app version 0, vote
    /// extensions disabled, and no update authority.
    pub fn etna() -> Self {
        Self {
            block: BlockParams { max_bytes: "22020096".into(), max_gas: "-1".into() },
            evidence: EvidenceParams {
                max_age_num_blocks: "100000".into(),
                max_age_duration: "172800000000000".into(),
                max_bytes: "1048576".into(),
            },
            validator: ValidatorParams { pub_key_types: vec!["ed25519".into()] },
            version: VersionParams { app: "0".into() },
            abci: AbciParams { vote_extensions_enable_height: "0".into() },
            authority: AuthorityParams { authority: String::new() },
        }
    }
}

/// One genesis validator.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GenesisValidator {
    /// [`validator_address`] of the key.
    pub address: String,
    /// The Ed25519 key: `{"type": "tendermint/PubKeyEd25519", "value": "<base64>"}`.
    pub pub_key: PublicKey,
    /// The voting power, as a decimal string.
    pub power: String,
    /// The validator name; always empty.
    pub name: String,
}

impl GenesisValidator {
    /// The genesis validator of committee member `m`: its Ed25519 key and mapped power.
    pub fn from_member(m: &Member) -> Self {
        Self {
            address: validator_address(m.pubkey),
            pub_key: ed25519(m.pubkey),
            power: m.power.to_string(),
            name: String::new(),
        }
    }
}

/// The CometBFT address of the Ed25519 key `pubkey`: the upper-case hex of the first 20 bytes
/// of `sha256(pubkey)`.
pub fn validator_address(pubkey: B256) -> String {
    account::Id::from(ed25519(pubkey)).to_string()
}

/// `pubkey` as a CometBFT Ed25519 public key.
fn ed25519(pubkey: B256) -> PublicKey {
    PublicKey::from_raw_ed25519(pubkey.as_slice()).expect("a 32-byte string is an Ed25519 key")
}

impl GenesisDoc {
    /// The genesis document of a verified genesis: `w` as `app_state` (its `L1_0` timestamp as
    /// `genesis_time`), `chain_id`, `initial_height` and the committee `members` (MEM-08 order)
    /// as validators, with [`GenesisConsensusParams::etna`].
    ///
    /// Fails with [`GenesisError::GenesisTime`] when the `L1_0` timestamp is not a valid
    /// CometBFT time.
    pub(crate) fn assemble(
        w: &GenesisWitness,
        chain_id: String,
        initial_height: u64,
        members: &[Member],
    ) -> Result<Self, GenesisError> {
        let timestamp = w.l1_header.timestamp;
        let genesis_time = i64::try_from(timestamp)
            .ok()
            .and_then(|secs| Time::from_unix_timestamp(secs, 0).ok())
            .ok_or(GenesisError::GenesisTime(timestamp))?;
        Ok(Self {
            genesis_time: genesis_time.to_rfc3339(),
            chain_id,
            initial_height: initial_height.to_string(),
            consensus_params: GenesisConsensusParams::etna(),
            validators: members.iter().map(GenesisValidator::from_member).collect(),
            app_hash: String::new(),
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
    use alloy_primitives::{U256, keccak256};
    use serde_json::{Value, json};

    use super::*;
    use crate::{genesis::encode_app_state, test_utils::Fixture};

    fn member(pubkey: B256, power: u64) -> Member {
        Member { pubkey, eff_stake: U256::from(power), power }
    }

    #[test]
    fn validator_address_is_the_upper_hex_sha256_prefix() {
        // sha256(0x01 × 32)[..20]
        assert_eq!(
            validator_address(B256::repeat_byte(0x01)),
            "72CD6E8422C407FB6D098690F1130B7DED7EC2F7"
        );
        // sha256(keccak256("etna validator 0"))[..20]
        assert_eq!(
            validator_address(keccak256("etna validator 0")),
            "3F2BC0483D8C553B9C58E1E4B1A26D9166FAF7C7"
        );
    }

    /// Every key CometBFT v0.40 reads, with string-typed numbers and `authority` present.
    #[test]
    fn json_has_the_cometbft_v040_shape() {
        let fx = Fixture::genesis(1);
        let doc = GenesisDoc::assemble(&fx.witness, "taiko-etna-7-g0".into(), 1_001, &fx.members)
            .expect("assembles");
        let mut json: Value = serde_json::from_str(&doc.to_json_pretty()).expect("JSON");
        let app_state = json["app_state"].take();
        assert_eq!(
            json,
            json!({
                "genesis_time": "2025-10-09T09:06:08Z",
                "chain_id": "taiko-etna-7-g0",
                "initial_height": "1001",
                "consensus_params": {
                    "block": { "max_bytes": "22020096", "max_gas": "-1" },
                    "evidence": {
                        "max_age_num_blocks": "100000",
                        "max_age_duration": "172800000000000",
                        "max_bytes": "1048576"
                    },
                    "validator": { "pub_key_types": ["ed25519"] },
                    "version": { "app": "0" },
                    "abci": { "vote_extensions_enable_height": "0" },
                    "authority": { "authority": "" }
                },
                "validators": [{
                    "address": "3F2BC0483D8C553B9C58E1E4B1A26D9166FAF7C7",
                    "pub_key": {
                        "type": "tendermint/PubKeyEd25519",
                        "value": "WSQNhIRIGWt2/OrBNsKLMUXc17k/0ap6JI96t/b9hU8="
                    },
                    "power": "1000000000",
                    "name": ""
                }],
                "app_hash": "",
                "app_state": null
            })
        );
        // app_state is the object encode_app_state writes, not a string.
        let expected: Value = serde_json::from_slice(&encode_app_state(&fx.witness)).unwrap();
        assert!(app_state.is_object());
        assert_eq!(app_state, expected);
    }

    #[test]
    fn json_keys_follow_the_cometbft_order() {
        let fx = Fixture::genesis(1);
        let doc = GenesisDoc::assemble(&fx.witness, "taiko-etna-7-g0".into(), 1_001, &fx.members)
            .expect("assembles");
        let text = doc.to_json_pretty();
        let at = |key: &str| text.find(&format!("\"{key}\"")).expect("key present");
        let keys = [
            "genesis_time",
            "chain_id",
            "initial_height",
            "consensus_params",
            "validators",
            "app_hash",
            "app_state",
        ];
        assert!(keys.windows(2).all(|w| at(w[0]) < at(w[1])), "{text}");
        assert_eq!(serde_json::from_str::<GenesisDoc>(&text).expect("parses back"), doc);
    }

    #[test]
    fn validators_keep_the_member_order_and_powers() {
        let fx = Fixture::genesis(1);
        let members = [member(B256::repeat_byte(9), 7), member(B256::repeat_byte(1), u64::MAX)];
        let doc = GenesisDoc::assemble(&fx.witness, "c".into(), 1, &members).expect("assembles");
        let addresses: Vec<&str> = doc.validators.iter().map(|v| v.address.as_str()).collect();
        assert_eq!(addresses[1], "72CD6E8422C407FB6D098690F1130B7DED7EC2F7");
        assert_eq!(addresses[0], validator_address(B256::repeat_byte(9)));
        assert_eq!(doc.validators[0].power, "7");
        assert_eq!(doc.validators[1].power, u64::MAX.to_string());
        assert_eq!(doc.validators[1].pub_key, ed25519(B256::repeat_byte(1)));
    }

    #[test]
    fn genesis_time_out_of_range_is_rejected() {
        let mut fx = Fixture::genesis(1);
        fx.witness.l1_header.timestamp = u64::MAX;
        let err = GenesisDoc::assemble(&fx.witness, "c".into(), 1, &fx.members).unwrap_err();
        assert!(matches!(err, GenesisError::GenesisTime(u64::MAX)), "{err:?}");
    }
}
