//! Chain parameters of the Etna PoS chain and their optional TOML override.

use alloy_primitives::{Address, U256, address};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
use serde::{Deserialize, Deserializer, de};

/// The largest committee size [`ChainParams::validate`] accepts.
///
/// The landing that carries an epoch's last commit settles every member of that epoch's committee
/// in one L1 transaction, which EIP-7825 caps at 16,777,216 gas. Crediting a member's registration
/// owner for the first time costs the reward pool about 34.9k gas, so the worst-case freezing
/// landing needs about 14.5M at 400 members and stops fitting at about 455.
pub const MAX_N_MAX: usize = 400;

/// Per-chain constants consumed by consensus.
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
    /// `D_MAX`: maximum unsettled depth, in L2 blocks (HALT-03); bound by the committee
    /// configuration hash.
    pub d_max: u64,
    /// `MARGIN_V`: safety margin subtracted from `d_max`, in L2 blocks; `d_max > margin_v`;
    /// bound by the committee configuration hash.
    pub margin_v: u64,
    /// `VP_UNIT`: effective stake per unit of voting power, in TAIKO base units; `> 0`.
    pub vp_unit: U256,
    /// `S_min`: minimum effective stake of an eligible entry, in TAIKO base units; `>= vp_unit`.
    pub s_min: U256,
    /// `N_MAX`: maximum committee size; in `1..=`[`MAX_N_MAX`].
    pub n_max: usize,
    /// `HEARTBEAT_WINDOW`: length of the L1 heartbeat windows MEM-13 eligibility is measured
    /// in, in L1 blocks ([`committee::heartbeat_floor`](crate::committee::heartbeat_floor));
    /// `>= 1`.
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
    /// A TOML override changed a consensus constant absent from the authenticated commitment.
    #[error("{parameter} is fixed by the built-in chain parameters and cannot be overridden")]
    FixedConsensusParameter {
        /// The consensus constant whose override differed from its built-in value.
        parameter: &'static str,
    },
    /// `d_max <= margin_v`, so the unsettled cap would not be positive: block 1 could never pass
    /// back-pressure against the genesis checkpoint at height 0.
    #[error("d_max ({d_max}) must be > margin_v ({margin_v})")]
    DMaxNotAboveMargin {
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
    /// `n_max > MAX_N_MAX`, so the landing that settles a full committee's epoch could exceed
    /// the EIP-7825 transaction gas cap and never be included.
    #[error("n_max ({n_max}) must be <= {max}")]
    NMaxTooLarge {
        /// Configured `n_max`.
        n_max: usize,
        /// The largest accepted value, [`MAX_N_MAX`].
        max: usize,
    },
    /// `heartbeat_window == 0`.
    #[error("heartbeat_window must be >= 1")]
    ZeroHeartbeatWindow,
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
                fee_vault: address!("00000000000000000000000000000000E7A10003"),
                d_max: 12,
                margin_v: 2,
                vp_unit: U256::from(1_000_000_000u64),
                s_min: U256::from(1_000_000_000_000_000_000u64),
                n_max: 128,
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
    /// optional and absent keys keep their current value. `fee_vault` and `block_gas_limit` must
    /// equal their built-in values: the authenticated committee commitment does not bind these
    /// consensus constants. `d_max` and `margin_v` may differ, because the commitment binds them:
    /// a node whose values differ from its chain's cannot open the stored committee
    /// configuration hash. Integers are TOML integers, addresses
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
        let builtin = Self::builtin(self.l2_chain_id)?;
        let fixed = [
            ("fee_vault", o.fee_vault.is_some_and(|v| v != builtin.fee_vault)),
            ("block_gas_limit", o.block_gas_limit.is_some_and(|v| v != builtin.block_gas_limit)),
        ];
        if let Some((parameter, _)) = fixed.into_iter().find(|(_, changed)| *changed) {
            return Err(ConfigError::FixedConsensusParameter { parameter });
        }
        self.inbox = o.inbox.unwrap_or(self.inbox);
        self.registry = o.registry.unwrap_or(self.registry);
        self.fee_vault = o.fee_vault.unwrap_or(self.fee_vault);
        self.d_max = o.d_max.unwrap_or(self.d_max);
        self.margin_v = o.margin_v.unwrap_or(self.margin_v);
        self.vp_unit = o.vp_unit.map_or(self.vp_unit, |v| v.0);
        self.s_min = o.s_min.map_or(self.s_min, |v| v.0);
        self.n_max = o.n_max.unwrap_or(self.n_max);
        self.heartbeat_window = o.heartbeat_window.unwrap_or(self.heartbeat_window);
        self.l1_finality_extra_depth =
            o.l1_finality_extra_depth.unwrap_or(self.l1_finality_extra_depth);
        self.block_gas_limit = o.block_gas_limit.unwrap_or(self.block_gas_limit);
        Ok(self)
    }

    /// The unsettled-depth cap `U = d_max - margin_v`, in L2 blocks (HALT-03).
    ///
    /// At least 1 for parameters that pass [`ChainParams::validate`]; saturates at 0 when
    /// `d_max < margin_v`.
    pub fn unsettled_cap(&self) -> u64 {
        self.d_max.saturating_sub(self.margin_v)
    }

    /// Checks `d_max > margin_v`, `vp_unit > 0`, `1 <= n_max <= MAX_N_MAX`,
    /// `heartbeat_window >= 1`, `block_gas_limit > 0` and `s_min >= vp_unit`, returning the first
    /// violation.
    pub fn validate(&self) -> Result<(), ConfigError> {
        if self.d_max <= self.margin_v {
            return Err(ConfigError::DMaxNotAboveMargin {
                d_max: self.d_max,
                margin_v: self.margin_v,
            });
        }
        if self.vp_unit.is_zero() {
            return Err(ConfigError::ZeroVpUnit);
        }
        if self.n_max == 0 {
            return Err(ConfigError::ZeroNMax);
        }
        if self.n_max > MAX_N_MAX {
            return Err(ConfigError::NMaxTooLarge { n_max: self.n_max, max: MAX_N_MAX });
        }
        if self.heartbeat_window == 0 {
            return Err(ConfigError::ZeroHeartbeatWindow);
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
    fn obsolete_snapshot_overrides_are_rejected() {
        for key in ["cutoff_grid", "cutoff_lag"] {
            assert!(matches!(
                devnet().with_overrides(&format!("{key} = 1")),
                Err(ConfigError::Toml(_))
            ));
        }
    }

    #[test]
    fn empty_override_keeps_builtin() {
        assert_eq!(devnet().with_overrides("").unwrap(), devnet());
    }

    #[test]
    fn overrides_reject_changes_to_uncommitted_consensus_parameters() {
        for (parameter, document) in [
            ("fee_vault", "fee_vault = \"0x3333333333333333333333333333333333333333\""),
            ("block_gas_limit", "block_gas_limit = 60000000"),
        ] {
            let err = devnet().with_overrides(document).expect_err("consensus override");
            assert!(
                matches!(err, ConfigError::FixedConsensusParameter { parameter: p } if p == parameter),
                "{document}: {err:?}"
            );
        }
    }

    #[test]
    fn overrides_committed_back_pressure_parameters() {
        let p = devnet().with_overrides("d_max = 1024\nmargin_v = 5").unwrap();
        assert_eq!(p.d_max, 1024);
        assert_eq!(p.margin_v, 5);
        assert_eq!(p.unsettled_cap(), 1019);
        p.validate().expect("overridden back-pressure parameters are valid");
        assert_ne!(
            crate::committee::committee_config_hash(&p),
            crate::committee::committee_config_hash(&devnet()),
            "the committee configuration commits d_max and margin_v"
        );
    }

    #[test]
    fn overrides_allow_explicit_builtin_consensus_parameters() {
        let document = r#"
            fee_vault = "0x00000000000000000000000000000000E7A10003"
            block_gas_limit = 45000000
            d_max = 12
            margin_v = 2
        "#;
        assert_eq!(devnet().with_overrides(document).unwrap(), devnet());
    }

    #[test]
    fn overrides_u64_and_usize_fields() {
        let p = devnet()
            .with_overrides(
                r#"
                n_max = 4
                heartbeat_window = 9223372036854775807
                l1_finality_extra_depth = 3
                "#,
            )
            .unwrap();
        assert_eq!(p.d_max, 12);
        assert_eq!(p.margin_v, 2);
        assert_eq!(p.unsettled_cap(), 10);
        assert_eq!(p.n_max, 4);
        assert_eq!(p.heartbeat_window, i64::MAX as u64);
        assert_eq!(p.l1_finality_extra_depth, 3);
        assert_eq!(p.block_gas_limit, 45_000_000);
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
                "#,
            )
            .unwrap();
        assert_eq!(p.inbox, Address::repeat_byte(0x11));
        assert_eq!(p.registry, Address::repeat_byte(0x22));
        assert_eq!(p.fee_vault, devnet().fee_vault);
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
    fn validate_requires_d_max_above_margin() {
        for (d_max, margin_v) in [(1, 2), (2, 2), (0, 0)] {
            let err = ChainParams { d_max, margin_v, ..devnet() }.validate().unwrap_err();
            let ConfigError::DMaxNotAboveMargin { d_max: d, margin_v: m } = err else {
                panic!("{d_max}/{margin_v}: {err:?}");
            };
            assert_eq!((d, m), (d_max, margin_v));
        }
        // An unsettled cap of 1 lets block 1 pass back-pressure against checkpoint 0.
        let p = ChainParams { d_max: 3, margin_v: 2, ..devnet() };
        p.validate().unwrap();
        assert_eq!(p.unsettled_cap(), 1);
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
    fn validate_bounds_n_max_by_the_freezing_landing_gas() {
        assert_eq!(MAX_N_MAX, 400);
        ChainParams { n_max: MAX_N_MAX, ..devnet() }.validate().unwrap();
        let p = ChainParams { n_max: MAX_N_MAX + 1, ..devnet() };
        assert!(matches!(
            p.validate().unwrap_err(),
            ConfigError::NMaxTooLarge { n_max: 401, max: 400 }
        ));
        // An override cannot raise it either: loaders validate after applying overrides.
        let overridden = devnet().with_overrides("n_max = 401").unwrap();
        assert!(matches!(overridden.validate().unwrap_err(), ConfigError::NMaxTooLarge { .. }));
    }

    #[test]
    fn validate_rejects_zero_heartbeat_window() {
        let p = ChainParams { heartbeat_window: 0, ..devnet() };
        assert!(matches!(p.validate().unwrap_err(), ConfigError::ZeroHeartbeatWindow));
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
