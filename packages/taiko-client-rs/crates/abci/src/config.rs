//! Chain parameters of the Etna PoS chain: etna-core's one definition and validation, the
//! client's built-in table and its optional TOML override ([`ChainParamsExt`]).

use alloy_primitives::{Address, U256, address};
pub use etna_core::params::{
    ChainParams, MAX_SET_MEMBERS, MAX_UNSETTLED_LIMIT, ParamsError, SwitchConfig,
};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
use serde::{Deserialize, Deserializer, de};

/// The devnet's (167001) `EtnaStaking` proxy on L2, `getConstantAddress(167001, 10003)`: the
/// chain id's decimal digits, zero padding, then `10003`, as the devnet L2 genesis predeploys it.
pub const DEVNET_STAKING: Address = address!("1670010000000000000000000000000000010003");

/// Errors building or validating [`ChainParams`].
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    /// The L2 chain id has no built-in Etna PoS parameters (mainnet and Hoodi included).
    #[error("no built-in Etna PoS chain parameters for L2 chain id {chain_id}")]
    NotConfigured {
        /// The requested L2 chain id.
        chain_id: u64,
    },
    /// The override TOML failed to parse, had an unknown key or a malformed value.
    #[error("invalid chain config TOML: {0}")]
    Toml(#[from] toml::de::Error),
    /// The override TOML set `l2_chain_id` to a different chain than the built-in parameters.
    #[error(
        "chain config sets l2_chain_id = {got}, but the built-in parameters are for {expected}"
    )]
    ChainIdMismatch {
        /// The chain id of the parameters being overridden.
        expected: u64,
        /// The chain id found in the TOML.
        got: u64,
    },
    /// A TOML override changed a consensus constant absent from the authenticated commitment.
    #[error("{parameter} is fixed by the built-in chain parameters and cannot be overridden")]
    FixedConsensusParameter {
        /// The consensus constant whose override differed from its built-in value.
        parameter: &'static str,
    },
    /// The parameters fail etna-core's validation ([`ChainParams::validate`]).
    #[error(transparent)]
    Params(#[from] ParamsError),
}

/// The client's built-in chain parameters and their TOML override, on etna-core's
/// [`ChainParams`].
pub trait ChainParamsExt: Sized {
    /// Built-in parameters for `l2_chain_id`.
    ///
    /// Only the devnet (`TAIKO_DEVNET_CHAIN_ID`, 167001) is configured, with its `EtnaStaking`
    /// proxy at [`DEVNET_STAKING`] and U = 151,200; mainnet (167000), Hoodi (167013) and every
    /// other chain return [`ConfigError::NotConfigured`] until their Etna PoS values exist, so
    /// Etna cannot start on a chain without a built-in staking address. The returned parameters
    /// pass [`ChainParams::validate`].
    fn builtin(l2_chain_id: u64) -> Result<ChainParams, ConfigError>;

    /// Applies optional snake_case TOML fields; omitted fields retain their values.
    /// L2 chain id cannot be retargeted and block gas limit stays fixed by the pinned EL.
    /// The full L1 chain id accepts a decimal or 0x-prefixed U256 string. Unknown and obsolete
    /// fields fail parsing. Call validate after applying overrides.
    fn with_overrides(self, toml: &str) -> Result<ChainParams, ConfigError>;
}

impl ChainParamsExt for ChainParams {
    fn builtin(l2_chain_id: u64) -> Result<Self, ConfigError> {
        match l2_chain_id {
            TAIKO_DEVNET_CHAIN_ID => Ok(Self {
                l2_chain_id,
                inbox: address!("00000000000000000000000000000000E7A10001"),
                staking: DEVNET_STAKING,
                l1_chain_id: U256::from(1),
                unsettled_limit: 151_200,
                fee_recipient: Address::ZERO,
                block_gas_limit: 45_000_000,
                switch: None,
            }),
            chain_id => Err(ConfigError::NotConfigured { chain_id }),
        }
    }

    fn with_overrides(mut self, toml: &str) -> Result<Self, ConfigError> {
        let o: Overrides = toml::from_str(toml)?;
        if let Some(got) = o.l2_chain_id &&
            got != self.l2_chain_id
        {
            return Err(ConfigError::ChainIdMismatch { expected: self.l2_chain_id, got });
        }
        let builtin = Self::builtin(self.l2_chain_id)?;
        let fixed =
            [("block_gas_limit", o.block_gas_limit.is_some_and(|v| v != builtin.block_gas_limit))];
        if let Some((parameter, _)) = fixed.into_iter().find(|(_, changed)| *changed) {
            return Err(ConfigError::FixedConsensusParameter { parameter });
        }
        self.inbox = o.inbox.unwrap_or(self.inbox);
        self.staking = o.staking.unwrap_or(self.staking);
        self.l1_chain_id = o.l1_chain_id.map_or(self.l1_chain_id, |v| v.0);
        self.unsettled_limit = o.unsettled_limit.unwrap_or(self.unsettled_limit);
        self.fee_recipient = o.fee_recipient.unwrap_or(self.fee_recipient);
        self.block_gas_limit = o.block_gas_limit.unwrap_or(self.block_gas_limit);
        if let Some(switch) = o.switch {
            if self.l2_chain_id != TAIKO_DEVNET_CHAIN_ID && builtin.switch.as_ref() != Some(&switch)
            {
                return Err(ConfigError::FixedConsensusParameter { parameter: "switch" });
            }
            self.switch = Some(switch);
        }
        Ok(self)
    }
}

/// The TOML override document: one optional entry per [`ChainParams`] field.
#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
struct Overrides {
    /// Must equal the overridden parameters' chain id when present.
    l2_chain_id: Option<u64>,
    /// See [`ChainParams::inbox`].
    inbox: Option<Address>,
    /// See [`ChainParams::staking`].
    staking: Option<Address>,
    /// See [`ChainParams::l1_chain_id`].
    l1_chain_id: Option<U256String>,
    /// See [`ChainParams::unsettled_limit`].
    unsettled_limit: Option<u64>,
    /// See [`ChainParams::fee_recipient`].
    fee_recipient: Option<Address>,
    /// See [`ChainParams::block_gas_limit`].
    block_gas_limit: Option<u64>,
    /// Explicit switching-network deployment configuration; see [`ChainParams::switch`].
    switch: Option<SwitchConfig>,
}

/// A `U256` written in TOML as a decimal or `0x`-hex string (TOML integers stop at `i64::MAX`).
#[derive(Debug)]
struct U256String(U256);

impl<'de> Deserialize<'de> for U256String {
    /// Parses a decimal or `0x`-prefixed hex string with at least one digit; rejects any other
    /// TOML type.
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let s = String::deserialize(deserializer)?;
        let (digits, radix) = match s.strip_prefix("0x") {
            Some(hex) => (hex, 16),
            None => (s.as_str(), 10),
        };
        // ruint parses an empty digit string as zero; require at least one digit.
        let parsed = if digits.is_empty() {
            Err("no digits".to_string())
        } else {
            U256::from_str_radix(digits, radix).map_err(|e| e.to_string())
        };
        parsed.map(Self).map_err(|e| {
            de::Error::custom(format!("expected a decimal or 0x-hex U256 string, got {s:?}: {e}"))
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn devnet() -> ChainParams {
        ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).unwrap()
    }
    #[test]
    fn defaults_and_direct_u_are_valid() {
        let p = devnet();
        p.validate().unwrap();
        assert_eq!(p.unsettled_limit, 151_200);
    }
    /// The devnet's built-in staking proxy is `getConstantAddress(167001, 10003)`: the chain
    /// id's decimal digits, zero padding to 40 hex digits, then `10003`.
    #[test]
    fn devnet_builtin_staking_is_the_constant_address() {
        let expected = address!("1670010000000000000000000000000000010003");
        assert_eq!(devnet().staking, expected);
        assert_eq!(DEVNET_STAKING, expected);
        let digits = format!("{TAIKO_DEVNET_CHAIN_ID}");
        let constant = format!("{digits}{}10003", "0".repeat(40 - digits.len() - 5));
        assert_eq!(alloy_primitives::hex::encode(expected), constant);
    }
    /// Mainnet and Hoodi have no built-in Etna parameters, so no staking address either.
    #[test]
    fn mainnet_and_hoodi_are_not_configured() {
        for chain in [167_000, 167_013] {
            assert!(
                matches!(
                    ChainParams::builtin(chain),
                    Err(ConfigError::NotConfigured { chain_id }) if chain_id == chain
                ),
                "{chain}"
            );
        }
    }
    /// The configuration hash commits the built-in L2 chain id, staking proxy and U: the shared
    /// configuration vector's inputs and hash.
    #[test]
    fn config_hash_uses_the_builtin_staking_address() {
        use crate::test_utils::vectors;
        let p = devnet();
        let expected = vectors::b256_at("/config/hash");
        assert_eq!(
            etna_core::params::config_hash(p.l2_chain_id, p.staking, p.unsettled_limit),
            expected
        );
        assert_eq!(
            (p.l2_chain_id, p.staking, p.unsettled_limit),
            (
                vectors::u64_at("/config/inputs/l2_chain_id"),
                vectors::str_at("/config/inputs/staking").parse().unwrap(),
                vectors::u64_at("/config/inputs/unsettled_limit"),
            )
        );
        assert_eq!(p.config_hash(), expected);
        assert_ne!(ChainParams { staking: Address::repeat_byte(1), ..p }.config_hash(), expected);
    }
    /// A devnet override may name another staking proxy; the configuration hash follows it.
    #[test]
    fn staking_override_replaces_the_builtin_proxy() {
        let p = devnet()
            .with_overrides("staking = '0x2222222222222222222222222222222222222222'")
            .unwrap();
        assert_eq!(p.staking, Address::repeat_byte(0x22));
        assert_ne!(p.config_hash(), devnet().config_hash());
        assert!(devnet().with_overrides("staking = '0x1234'").is_err());
    }
    /// U is any integer from 1 to 262,144; etna-core's validation refuses every other value.
    #[test]
    fn config_u_bounds() {
        for limit in [1, 262_144] {
            ChainParams { unsettled_limit: limit, ..devnet() }.validate().unwrap();
        }
        for limit in [0, 262_145] {
            assert_eq!(
                ChainParams { unsettled_limit: limit, ..devnet() }.validate(),
                Err(ParamsError::InvalidUnsettledLimit),
                "U={limit}"
            );
        }
    }
    #[test]
    fn overrides_authenticate_u_and_accept_full_l1_chain_id() {
        let p=devnet().with_overrides("unsettled_limit = 7200\nl1_chain_id = '0x100000000000000000000000000000000000000000000000000'\nfee_recipient = '0x1111111111111111111111111111111111111111'").unwrap();
        assert_eq!(p.unsettled_limit, 7200);
        assert!(p.l1_chain_id > U256::from(u64::MAX));
        assert_eq!(p.fee_recipient, Address::repeat_byte(0x11));
    }
    #[test]
    fn bounds_reject_invalid_config() {
        for p in [
            ChainParams { unsettled_limit: 0, ..devnet() },
            ChainParams { block_gas_limit: 0, ..devnet() },
        ] {
            assert!(p.validate().is_err());
        }
    }
    /// The staking registry and its stake parameters are gone: their TOML keys are unknown and
    /// refused, as is every other removed key.
    #[test]
    fn malformed_unknown_and_retargeted_overrides_fail() {
        for input in [
            "l1_chain_id = '12abc'",
            "l1_chain_id = ''",
            "l1_chain_id = '0x'",
            "l1_chain_id = -1",
            "inbox = '0x1234'",
            "unsettled_limit = -1",
            "registry = '0x2222222222222222222222222222222222222222'",
            "vp_unit = '1000000000'",
            "min_stake = '300000000000000000000000'",
            "n_max = 128",
            "epoch_len = 12",
            "l1_finality_extra_depth = 0",
            "l2_chain_id = 1",
            "block_gas_limit = 10",
        ] {
            assert!(devnet().with_overrides(input).is_err(), "{input}");
        }
    }
    /// The `[switch]` table names the Etna L2 SignalService implementation; the replaced
    /// `anchor_implementation` key is unknown and refused, alone or beside the new key.
    #[test]
    fn switch_table_refuses_the_old_anchor_implementation_key() {
        let table = "[switch]\nunzen_inbox = '0x0000000000000000000000000000000000000001'\n\
                     fork_timestamp = 1800000000\n\
                     staking_implementation = '0x0000000000000000000000000000000000000003'\n";
        let new_key =
            "signal_service_implementation = '0x0000000000000000000000000000000000000002'";
        let old_key = "anchor_implementation = '0x0000000000000000000000000000000000000002'";
        let p = devnet().with_overrides(&format!("{table}{new_key}")).unwrap();
        assert_eq!(p.switch.unwrap().signal_service_implementation, Address::with_last_byte(2));
        for keys in [old_key.to_string(), format!("{new_key}\n{old_key}")] {
            let error = devnet().with_overrides(&format!("{table}{keys}")).unwrap_err();
            assert!(matches!(error, ConfigError::Toml(_)), "{error}");
            assert!(error.to_string().contains("anchor_implementation"), "{error}");
        }
    }
    #[test]
    fn unconfigured_chains_fail() {
        for chain in [1, 167000, 167013] {
            assert!(ChainParams::builtin(chain).is_err());
        }
    }
    /// The `[switch]` table names the staking implementation the proxy must hold at the start:
    /// the key is required, and a zero address is an invalid switch.
    #[test]
    fn switch_table_requires_a_staking_implementation() {
        let table = "[switch]\nunzen_inbox = '0x0000000000000000000000000000000000000001'\n\
                     fork_timestamp = 1800000000\n\
                     signal_service_implementation = '0x0000000000000000000000000000000000000002'\n";
        let missing = devnet().with_overrides(table).unwrap_err();
        assert!(missing.to_string().contains("staking_implementation"), "{missing}");
        let p = devnet()
            .with_overrides(&format!(
                "{table}staking_implementation = '0x0000000000000000000000000000000000000003'"
            ))
            .unwrap();
        assert_eq!(p.switch.as_ref().unwrap().staking_implementation, Address::with_last_byte(3));
        p.validate().unwrap();
        let zero = devnet()
            .with_overrides(&format!(
                "{table}staking_implementation = '0x0000000000000000000000000000000000000000'"
            ))
            .unwrap();
        assert_eq!(zero.validate(), Err(ParamsError::InvalidSwitch));
    }
}
