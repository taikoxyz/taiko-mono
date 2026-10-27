//! Chain parameters of the Etna PoS chain and their optional TOML override.

use alloy_primitives::{Address, U256, address};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
use serde::{Deserialize, Deserializer, de};

/// The largest committee size accepted by the registry discovery and consensus bounds.
pub const MAX_N_MAX: usize = 4096;

/// Per-chain constants consumed by consensus.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ChainParams {
    /// L2 EVM chain id.
    pub l2_chain_id: u64,
    /// `ETNA_INBOX`: L1 address of the Etna Inbox.
    pub inbox: Address,
    /// `ETNA_REGISTRY`: L1 address of the staking registry.
    pub registry: Address,
    /// Full L1 chain identifier used to bind the Comet signing domain.
    pub l1_chain_id: U256,
    /// Authenticated maximum unsettled depth U in L2 blocks, independent of epoch length.
    pub unsettled_limit: u64,
    /// Local execution beneficiary chosen by this proposer; not committee authentication data.
    pub fee_recipient: Address,
    /// `VP_UNIT`: effective stake per unit of voting power, in TAIKO base units; `> 0`.
    pub vp_unit: U256,
    /// `S_min`: minimum effective stake of an eligible entry, in TAIKO base units; `>= vp_unit`.
    pub s_min: U256,
    /// `N_MAX`: maximum committee size; in `1..=`[`MAX_N_MAX`].
    pub n_max: usize,
    /// `F_L1`: extra L1 depth required on top of the own L1 node's `finalized` block.
    pub l1_finality_extra_depth: u64,
    /// `L2_BLOCK_GAS_LIMIT`: gas limit of every L2 block, in gas; `> 0`.
    pub block_gas_limit: u64,
}

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
    /// Back-pressure must allow at least the first block.
    #[error("unsettled_limit must be positive")]
    ZeroUnsettledLimit,
    /// U must be a K=6 grid multiple within the protocol unsettled-depth bounds.
    #[error("unsettled_limit must be a multiple of 6 in 6..=65536")]
    InvalidUnsettledLimit,
    /// Voting power units must respect the token-supply safety bound.
    #[error("vp_unit must be at least 867361738 base units")]
    VpUnitTooSmall,
    /// `vp_unit == 0`.
    #[error("vp_unit must be > 0")]
    ZeroVpUnit,
    /// `n_max == 0`.
    #[error("n_max must be >= 1")]
    ZeroNMax,
    /// `n_max` exceeds the authenticated registry discovery capacity.
    #[error("n_max ({n_max}) must be <= {max}")]
    NMaxTooLarge {
        /// Configured `n_max`.
        n_max: usize,
        /// The largest accepted value, [`MAX_N_MAX`].
        max: usize,
    },
    /// `block_gas_limit == 0`.
    #[error("block_gas_limit must be > 0")]
    ZeroBlockGasLimit,
    /// `s_min < vp_unit`, so an eligible entry could map to zero voting power.
    #[error("s_min ({s_min}) must be >= vp_unit ({vp_unit})")]
    SMinBelowVpUnit {
        /// Configured `s_min`.
        s_min: U256,
        /// Configured `vp_unit`.
        vp_unit: U256,
    },
}

impl ChainParams {
    /// Built-in parameters for `l2_chain_id`.
    ///
    /// Only the devnet (`TAIKO_DEVNET_CHAIN_ID`) is configured; mainnet, Hoodi and every other
    /// chain return [`ConfigError::NotConfigured`] until their Etna PoS values exist.
    /// The returned parameters pass [`ChainParams::validate`].
    pub fn builtin(l2_chain_id: u64) -> Result<Self, ConfigError> {
        match l2_chain_id {
            TAIKO_DEVNET_CHAIN_ID => Ok(Self {
                l2_chain_id,
                inbox: address!("00000000000000000000000000000000E7A10001"),
                registry: address!("00000000000000000000000000000000E7A10002"),
                l1_chain_id: U256::from(1),
                unsettled_limit: 3600,
                fee_recipient: Address::ZERO,
                vp_unit: U256::from(1_000_000_000u64),
                s_min: U256::from(1_000_000_000_000_000_000u64),
                n_max: 128,
                l1_finality_extra_depth: 0,
                block_gas_limit: 45_000_000,
            }),
            chain_id => Err(ConfigError::NotConfigured { chain_id }),
        }
    }

    /// Applies optional snake_case TOML fields; omitted fields retain their values.
    /// L2 chain id cannot be retargeted and block gas limit stays fixed by the pinned EL.
    /// Stake units and full L1 chain id accept decimal or 0x-prefixed U256 strings. Unknown and
    /// obsolete fields fail parsing. Call validate after applying overrides.
    pub fn with_overrides(mut self, toml: &str) -> Result<Self, ConfigError> {
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
        self.registry = o.registry.unwrap_or(self.registry);
        self.l1_chain_id = o.l1_chain_id.map_or(self.l1_chain_id, |v| v.0);
        self.unsettled_limit = o.unsettled_limit.unwrap_or(self.unsettled_limit);
        self.fee_recipient = o.fee_recipient.unwrap_or(self.fee_recipient);
        self.vp_unit = o.vp_unit.map_or(self.vp_unit, |v| v.0);
        self.s_min = o.s_min.map_or(self.s_min, |v| v.0);
        self.n_max = o.n_max.unwrap_or(self.n_max);
        self.l1_finality_extra_depth =
            o.l1_finality_extra_depth.unwrap_or(self.l1_finality_extra_depth);
        self.block_gas_limit = o.block_gas_limit.unwrap_or(self.block_gas_limit);
        Ok(self)
    }

    /// Returns the directly authenticated unsettled limit U in L2 blocks, independent of L.
    pub fn unsettled_cap(&self) -> u64 {
        self.unsettled_limit
    }

    /// Checks K=6 grid depth bounds, token-supply voting-power safety, committee capacity,
    /// positive block gas limit and s_min >= vp_unit. Returns the first invalid deployment
    /// parameter.
    pub fn validate(&self) -> Result<(), ConfigError> {
        if self.unsettled_limit == 0 {
            return Err(ConfigError::ZeroUnsettledLimit);
        }
        if !(6..=65_536).contains(&self.unsettled_limit) || !self.unsettled_limit.is_multiple_of(6)
        {
            return Err(ConfigError::InvalidUnsettledLimit);
        }
        if self.vp_unit.is_zero() {
            return Err(ConfigError::ZeroVpUnit);
        }
        if self.vp_unit < U256::from(867_361_738) {
            return Err(ConfigError::VpUnitTooSmall);
        }
        if self.n_max == 0 {
            return Err(ConfigError::ZeroNMax);
        }
        if self.n_max > MAX_N_MAX {
            return Err(ConfigError::NMaxTooLarge { n_max: self.n_max, max: MAX_N_MAX });
        }
        if self.block_gas_limit == 0 {
            return Err(ConfigError::ZeroBlockGasLimit);
        }
        if self.s_min < self.vp_unit {
            return Err(ConfigError::SMinBelowVpUnit { s_min: self.s_min, vp_unit: self.vp_unit });
        }
        Ok(())
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
    /// See [`ChainParams::registry`].
    registry: Option<Address>,
    /// See [`ChainParams::l1_chain_id`].
    l1_chain_id: Option<U256String>,
    /// See [`ChainParams::unsettled_limit`].
    unsettled_limit: Option<u64>,
    /// See [`ChainParams::fee_recipient`].
    fee_recipient: Option<Address>,
    /// See [`ChainParams::vp_unit`].
    vp_unit: Option<U256String>,
    /// See [`ChainParams::s_min`].
    s_min: Option<U256String>,
    /// See [`ChainParams::n_max`].
    n_max: Option<usize>,
    /// See [`ChainParams::l1_finality_extra_depth`].
    l1_finality_extra_depth: Option<u64>,
    /// See [`ChainParams::block_gas_limit`].
    block_gas_limit: Option<u64>,
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
        assert_eq!(p.unsettled_cap(), 3600);
        assert_eq!(p.n_max, 128);
    }
    #[test]
    fn old_configuration_fields_are_rejected() {
        for input in [
            "d_max = 12",
            "margin_v = 2",
            "heartbeat_window = 10",
            "fee_vault = '0x0000000000000000000000000000000000000001'",
        ] {
            assert!(devnet().with_overrides(input).is_err());
        }
    }
    #[test]
    fn overrides_authenticate_u_and_accept_full_l1_chain_id() {
        let p=devnet().with_overrides("unsettled_limit = 7200\nl1_chain_id = '0x100000000000000000000000000000000000000000000000000'\nfee_recipient = '0x1111111111111111111111111111111111111111'").unwrap();
        assert_eq!(p.unsettled_cap(), 7200);
        assert!(p.l1_chain_id > U256::from(u64::MAX));
        assert_eq!(p.fee_recipient, Address::repeat_byte(0x11));
    }
    #[test]
    fn bounds_reject_invalid_config() {
        for p in [
            ChainParams { unsettled_limit: 0, ..devnet() },
            ChainParams { vp_unit: U256::ZERO, ..devnet() },
            ChainParams { n_max: 0, ..devnet() },
            ChainParams { n_max: 4097, ..devnet() },
            ChainParams { block_gas_limit: 0, ..devnet() },
            ChainParams { s_min: U256::ZERO, ..devnet() },
        ] {
            assert!(p.validate().is_err());
        }
    }
    #[test]
    fn malformed_unknown_and_retargeted_overrides_fail() {
        for input in [
            "vp_unit = '12abc'",
            "vp_unit = ''",
            "vp_unit = '0x'",
            "vp_unit = -1",
            "inbox = '0x1234'",
            "unsettled_limit = -1",
            "epoch_len = 12",
            "l2_chain_id = 1",
            "block_gas_limit = 10",
        ] {
            assert!(devnet().with_overrides(input).is_err(), "{input}");
        }
    }
    #[test]
    fn unconfigured_chains_fail() {
        for chain in [1, 167000, 167013] {
            assert!(ChainParams::builtin(chain).is_err());
        }
    }
}

#[cfg(test)]
mod v1_deployment_bounds {
    use super::*;
    #[test]
    fn grid_and_voting_power_deployment_bounds() {
        let base = ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).unwrap();
        for limit in [0, 1, 5, 7, 65_536, 65_538] {
            assert!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate().is_err(),
                "U={limit}"
            );
        }
        for limit in [6, 12, 3600, 65_532] {
            assert!(ChainParams { unsettled_limit: limit, ..base.clone() }.validate().is_ok());
        }
        assert!(
            ChainParams { vp_unit: U256::from(867_361_737), ..base.clone() }.validate().is_err()
        );
        assert!(ChainParams { vp_unit: U256::from(867_361_738), ..base }.validate().is_ok());
    }
}
