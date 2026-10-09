//! Chain parameters of the Etna PoS chain (spec §7) and their optional TOML override.

use alloy_primitives::{Address, U256, address};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
use serde::{Deserialize, Deserializer, de};

/// Per-chain constants consumed by consensus (spec §7).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ChainParams {
    /// L2 EVM chain id.
    pub l2_chain_id: u64,
    /// `ETNA_INBOX`: L1 address of the Etna Inbox.
    pub inbox: Address,
    /// `ETNA_REGISTRY`: L1 address of the staking registry.
    pub registry: Address,
    /// `L2FeeVault`: L2 coinbase and suggested fee recipient of every block.
    pub fee_vault: Address,
    /// `D_MAX`: maximum unsettled depth, in L2 blocks (HALT-03).
    pub d_max: u64,
    /// `MARGIN_V`: safety margin subtracted from `d_max`, in L2 blocks; `d_max >= margin_v`.
    pub margin_v: u64,
    /// `VP_UNIT`: effective stake per unit of voting power, in TAIKO base units; `> 0`.
    pub vp_unit: U256,
    /// `S_min`: minimum effective stake of an eligible entry, in TAIKO base units; `>= vp_unit`.
    pub s_min: U256,
    /// `N_MAX`: maximum committee size; `>= 1`.
    pub n_max: usize,
    /// `G`: snapshot cutoff grid, in L1 blocks; `>= 1`.
    pub cutoff_grid: u64,
    /// `LAG`: snapshot cutoff lag behind the parent's anchor, in L1 blocks.
    pub cutoff_lag: u64,
    /// `HEARTBEAT_WINDOW`: maximum heartbeat age at the cutoff, in L1 blocks.
    pub heartbeat_window: u64,
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
    /// `d_max < margin_v`, so the unsettled cap would be negative.
    #[error("d_max ({d_max}) must be >= margin_v ({margin_v})")]
    DMaxBelowMargin {
        /// Configured `d_max`.
        d_max: u64,
        /// Configured `margin_v`.
        margin_v: u64,
    },
    /// `vp_unit == 0`.
    #[error("vp_unit must be > 0")]
    ZeroVpUnit,
    /// `n_max == 0`.
    #[error("n_max must be >= 1")]
    ZeroNMax,
    /// `cutoff_grid == 0`.
    #[error("cutoff_grid must be >= 1")]
    ZeroCutoffGrid,
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
    /// chain return [`ConfigError::NotConfigured`] until their Etna PoS values exist (spec §7).
    /// The returned parameters pass [`ChainParams::validate`].
    pub fn builtin(l2_chain_id: u64) -> Result<Self, ConfigError> {
        match l2_chain_id {
            TAIKO_DEVNET_CHAIN_ID => Ok(Self {
                l2_chain_id,
                inbox: address!("00000000000000000000000000000000E7A10001"),
                registry: address!("00000000000000000000000000000000E7A10002"),
                fee_vault: address!("00000000000000000000000000000000E7A10003"),
                d_max: 12,
                margin_v: 2,
                vp_unit: U256::from(1_000_000_000u64),
                s_min: U256::from(1_000_000_000_000_000_000u64),
                n_max: 128,
                cutoff_grid: 1,
                cutoff_lag: 0,
                heartbeat_window: u64::MAX / 2,
                l1_finality_extra_depth: 0,
                block_gas_limit: 45_000_000,
            }),
            chain_id => Err(ConfigError::NotConfigured { chain_id }),
        }
    }

    /// Applies a TOML override on top of `self` and returns the result.
    ///
    /// The TOML is a table whose keys are this struct's snake_case field names; every key is
    /// optional and absent keys keep their current value. Integers are TOML integers, addresses
    /// are hex strings and `U256` values (`vp_unit`, `s_min`) are decimal or `0x`-hex strings.
    /// Unknown keys and malformed values are rejected with [`ConfigError::Toml`]; an
    /// `l2_chain_id` different from `self.l2_chain_id` is rejected with
    /// [`ConfigError::ChainIdMismatch`] so an override cannot re-target the built-in parameters
    /// at another chain.
    ///
    /// The result is not validated; call [`ChainParams::validate`] afterwards.
    pub fn with_overrides(mut self, toml: &str) -> Result<Self, ConfigError> {
        let o: Overrides = toml::from_str(toml)?;
        if let Some(got) = o.l2_chain_id &&
            got != self.l2_chain_id
        {
            return Err(ConfigError::ChainIdMismatch { expected: self.l2_chain_id, got });
        }
        self.inbox = o.inbox.unwrap_or(self.inbox);
        self.registry = o.registry.unwrap_or(self.registry);
        self.fee_vault = o.fee_vault.unwrap_or(self.fee_vault);
        self.d_max = o.d_max.unwrap_or(self.d_max);
        self.margin_v = o.margin_v.unwrap_or(self.margin_v);
        self.vp_unit = o.vp_unit.map_or(self.vp_unit, |v| v.0);
        self.s_min = o.s_min.map_or(self.s_min, |v| v.0);
        self.n_max = o.n_max.unwrap_or(self.n_max);
        self.cutoff_grid = o.cutoff_grid.unwrap_or(self.cutoff_grid);
        self.cutoff_lag = o.cutoff_lag.unwrap_or(self.cutoff_lag);
        self.heartbeat_window = o.heartbeat_window.unwrap_or(self.heartbeat_window);
        self.l1_finality_extra_depth =
            o.l1_finality_extra_depth.unwrap_or(self.l1_finality_extra_depth);
        self.block_gas_limit = o.block_gas_limit.unwrap_or(self.block_gas_limit);
        Ok(self)
    }

    /// The unsettled-depth cap `U = d_max - margin_v`, in L2 blocks (HALT-03).
    ///
    /// Saturates at 0 when `d_max < margin_v`, which [`ChainParams::validate`] rejects.
    pub fn unsettled_cap(&self) -> u64 {
        self.d_max.saturating_sub(self.margin_v)
    }

    /// Checks `d_max >= margin_v`, `vp_unit > 0`, `n_max >= 1`, `cutoff_grid >= 1`,
    /// `block_gas_limit > 0` and `s_min >= vp_unit`, returning the first violation.
    pub fn validate(&self) -> Result<(), ConfigError> {
        if self.d_max < self.margin_v {
            return Err(ConfigError::DMaxBelowMargin { d_max: self.d_max, margin_v: self.margin_v });
        }
        if self.vp_unit.is_zero() {
            return Err(ConfigError::ZeroVpUnit);
        }
        if self.n_max == 0 {
            return Err(ConfigError::ZeroNMax);
        }
        if self.cutoff_grid == 0 {
            return Err(ConfigError::ZeroCutoffGrid);
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
    /// See [`ChainParams::fee_vault`].
    fee_vault: Option<Address>,
    /// See [`ChainParams::d_max`].
    d_max: Option<u64>,
    /// See [`ChainParams::margin_v`].
    margin_v: Option<u64>,
    /// See [`ChainParams::vp_unit`].
    vp_unit: Option<U256String>,
    /// See [`ChainParams::s_min`].
    s_min: Option<U256String>,
    /// See [`ChainParams::n_max`].
    n_max: Option<usize>,
    /// See [`ChainParams::cutoff_grid`].
    cutoff_grid: Option<u64>,
    /// See [`ChainParams::cutoff_lag`].
    cutoff_lag: Option<u64>,
    /// See [`ChainParams::heartbeat_window`].
    heartbeat_window: Option<u64>,
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
    use alloy_primitives::address;
    use protocol::shasta::constants::{
        TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID,
    };

    fn devnet() -> ChainParams {
        ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).expect("devnet is built in")
    }

    #[test]
    fn builtin_devnet_values() {
        let p = devnet();
        assert_eq!(p.l2_chain_id, TAIKO_DEVNET_CHAIN_ID);
        assert_eq!(p.inbox, address!("00000000000000000000000000000000E7A10001"));
        assert_eq!(p.registry, address!("00000000000000000000000000000000E7A10002"));
        assert_eq!(p.fee_vault, address!("00000000000000000000000000000000E7A10003"));
        assert_eq!(p.d_max, 12);
        assert_eq!(p.margin_v, 2);
        assert_eq!(p.vp_unit, U256::from(1_000_000_000u64));
        assert_eq!(p.s_min, U256::from(1_000_000_000_000_000_000u64));
        assert_eq!(p.n_max, 128);
        assert_eq!(p.cutoff_grid, 1);
        assert_eq!(p.cutoff_lag, 0);
        assert_eq!(p.heartbeat_window, u64::MAX / 2);
        assert_eq!(p.l1_finality_extra_depth, 0);
        assert_eq!(p.block_gas_limit, 45_000_000);
        assert_eq!(p.unsettled_cap(), 10);
        p.validate().expect("devnet defaults are valid");
    }

    #[test]
    fn builtin_rejects_unconfigured_chains() {
        for chain_id in [TAIKO_MAINNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID, 167_000, 167_013, 1] {
            let err = ChainParams::builtin(chain_id).unwrap_err();
            assert!(
                matches!(err, ConfigError::NotConfigured { chain_id: c } if c == chain_id),
                "{chain_id}: {err:?}"
            );
        }
    }

    #[test]
    fn empty_override_keeps_builtin() {
        assert_eq!(devnet().with_overrides("").unwrap(), devnet());
    }

    #[test]
    fn overrides_u64_and_usize_fields() {
        let p = devnet()
            .with_overrides(
                r#"
                d_max = 30
                margin_v = 5
                n_max = 4
                cutoff_grid = 8
                cutoff_lag = 2
                heartbeat_window = 9223372036854775807
                l1_finality_extra_depth = 3
                block_gas_limit = 60000000
                "#,
            )
            .unwrap();
        assert_eq!(p.d_max, 30);
        assert_eq!(p.margin_v, 5);
        assert_eq!(p.unsettled_cap(), 25);
        assert_eq!(p.n_max, 4);
        assert_eq!(p.cutoff_grid, 8);
        assert_eq!(p.cutoff_lag, 2);
        assert_eq!(p.heartbeat_window, i64::MAX as u64);
        assert_eq!(p.l1_finality_extra_depth, 3);
        assert_eq!(p.block_gas_limit, 60_000_000);
        // Untouched fields keep their built-in values.
        assert_eq!(p.inbox, devnet().inbox);
        assert_eq!(p.vp_unit, devnet().vp_unit);
    }

    #[test]
    fn overrides_address_fields() {
        let p = devnet()
            .with_overrides(
                r#"
                inbox = "0x1111111111111111111111111111111111111111"
                registry = "0x2222222222222222222222222222222222222222"
                fee_vault = "0x3333333333333333333333333333333333333333"
                "#,
            )
            .unwrap();
        assert_eq!(p.inbox, Address::repeat_byte(0x11));
        assert_eq!(p.registry, Address::repeat_byte(0x22));
        assert_eq!(p.fee_vault, Address::repeat_byte(0x33));
        assert_eq!(p.d_max, devnet().d_max);
    }

    #[test]
    fn overrides_u256_fields_from_decimal_and_hex() {
        let p = devnet()
            .with_overrides(
                r#"
                vp_unit = "1000"
                s_min = "0xde0b6b3a7640000"
                "#,
            )
            .unwrap();
        assert_eq!(p.vp_unit, U256::from(1_000u64));
        assert_eq!(p.s_min, U256::from(1_000_000_000_000_000_000u64));

        let big = devnet()
            .with_overrides(r#"s_min = "115792089237316195423570985008687907853269984665640564039457584007913129639935""#)
            .unwrap();
        assert_eq!(big.s_min, U256::MAX);
    }

    #[test]
    fn overrides_accept_same_chain_id_and_reject_another() {
        let same = format!("l2_chain_id = {TAIKO_DEVNET_CHAIN_ID}");
        assert_eq!(devnet().with_overrides(&same).unwrap(), devnet());

        let err = devnet().with_overrides("l2_chain_id = 167000").unwrap_err();
        assert!(
            matches!(
                err,
                ConfigError::ChainIdMismatch { expected: TAIKO_DEVNET_CHAIN_ID, got: 167_000 }
            ),
            "{err:?}"
        );
    }

    #[test]
    fn overrides_reject_unknown_keys() {
        let err = devnet().with_overrides("d_max = 12\nepoch_len = 20").unwrap_err();
        assert!(matches!(err, ConfigError::Toml(_)), "{err:?}");
        assert!(err.to_string().contains("epoch_len"), "{err}");
    }

    #[test]
    fn overrides_reject_malformed_values() {
        for toml in [
            r#"vp_unit = "12abc""#,
            r#"vp_unit = """#,
            r#"vp_unit = "0x""#,
            r#"vp_unit = "-1""#,
            r#"vp_unit = 1000"#,
            r#"inbox = "0x1234""#,
            r#"d_max = -1"#,
            r#"d_max = "12""#,
            "d_max = ",
        ] {
            let err = devnet().with_overrides(toml).unwrap_err();
            assert!(matches!(err, ConfigError::Toml(_)), "{toml}: {err:?}");
        }
    }

    #[test]
    fn validate_rejects_d_max_below_margin() {
        let p = ChainParams { d_max: 1, margin_v: 2, ..devnet() };
        assert!(matches!(
            p.validate().unwrap_err(),
            ConfigError::DMaxBelowMargin { d_max: 1, margin_v: 2 }
        ));
        ChainParams { d_max: 2, margin_v: 2, ..devnet() }.validate().unwrap();
    }

    #[test]
    fn validate_rejects_zero_vp_unit() {
        let p = ChainParams { vp_unit: U256::ZERO, ..devnet() };
        assert!(matches!(p.validate().unwrap_err(), ConfigError::ZeroVpUnit));
    }

    #[test]
    fn validate_rejects_zero_n_max() {
        let p = ChainParams { n_max: 0, ..devnet() };
        assert!(matches!(p.validate().unwrap_err(), ConfigError::ZeroNMax));
    }

    #[test]
    fn validate_rejects_zero_cutoff_grid() {
        let p = ChainParams { cutoff_grid: 0, ..devnet() };
        assert!(matches!(p.validate().unwrap_err(), ConfigError::ZeroCutoffGrid));
    }

    #[test]
    fn validate_rejects_zero_block_gas_limit() {
        let p = ChainParams { block_gas_limit: 0, ..devnet() };
        assert!(matches!(p.validate().unwrap_err(), ConfigError::ZeroBlockGasLimit));
    }

    #[test]
    fn validate_rejects_s_min_below_vp_unit() {
        let p =
            ChainParams { s_min: U256::from(999u64), vp_unit: U256::from(1_000u64), ..devnet() };
        assert!(matches!(p.validate().unwrap_err(), ConfigError::SMinBelowVpUnit { .. }));
        ChainParams { s_min: U256::from(1_000u64), vp_unit: U256::from(1_000u64), ..devnet() }
            .validate()
            .unwrap();
    }
}
