//! Chain parameters of the Etna PoS chain and their optional TOML override.

use alloy_primitives::{Address, B256, U256, address};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
use serde::{Deserialize, Deserializer, de};

/// The largest committee size accepted by the registry discovery and consensus bounds.
pub const MAX_N_MAX: usize = 4096;

pub use etna_core::params::MAX_UNSETTLED_LIMIT;

/// The devnet's (167001) `EtnaStaking` proxy on L2, `getConstantAddress(167001, 10003)`: the
/// chain id's decimal digits, zero padding, then `10003`, as the devnet L2 genesis predeploys it.
pub const DEVNET_STAKING: Address = address!("1670010000000000000000000000000000010003");

/// Deployment constants for authenticating an Unzen to Etna switch (SPEC PARAM-11-12a).
/// Production networks compile these values into their chain parameters; private devnets may
/// set the explicit `[switch]` TOML table before creating the signing domain.
#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SwitchConfig {
    /// Live L1 Unzen Inbox proxy whose closed proposal history defines the final Unzen block.
    pub unzen_inbox: Address,
    /// The node's Etna fork time (`ETNA_FORK_TIME`), in Unix seconds: the shared Unzen cutoff
    /// and Etna activation timestamp. Trust requires it to equal the switching EtnaInbox's
    /// immutable `etnaForkTime()` in the own finalized L1 view (SYNC-9-5a).
    pub fork_timestamp: u64,
    /// Etna L2 SignalService implementation built into the client for the L2 chain id: the L2
    /// SignalService proxy's EIP-1967 slot holds it at S (SYNC-9-5a, PARAM-11-12a).
    pub signal_service_implementation: Address,
    /// `EtnaStaking` implementation built into the client for the L2 chain id: the EIP-1967
    /// implementation slot of the staking proxy that the configuration hash commits holds it at
    /// the start.
    pub staking_implementation: Address,
}

/// Per-chain constants consumed by consensus.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ChainParams {
    /// L2 EVM chain id.
    pub l2_chain_id: u64,
    /// `ETNA_INBOX`: L1 address of the Etna Inbox.
    pub inbox: Address,
    /// `ETNA_REGISTRY`: L1 address of the staking registry.
    pub registry: Address,
    /// Address of the `EtnaStaking` proxy on L2, built into the client for the L2 chain id; the
    /// configuration hash in slot 269 commits it ([`ChainParams::config_hash`]).
    pub staking: Address,
    /// Full L1 chain identifier used to bind the Comet signing domain.
    pub l1_chain_id: U256,
    /// U, the unsettled-block limit: the maximum unsettled depth in L2 blocks, in
    /// `1..=`[`MAX_UNSETTLED_LIMIT`]; the configuration hash commits it.
    pub unsettled_limit: u64,
    /// Local execution beneficiary chosen by this proposer; not committee authentication data.
    pub fee_recipient: Address,
    /// `VP_UNIT`: effective stake per unit of voting power, in TAIKO base units; at least the
    /// START-10-12 floor ([`ChainParams::validate`]).
    pub vp_unit: U256,
    /// `minStake`: the staking registry's immutable minimum stake, in TAIKO base units. It is
    /// both the registration minimum and the selection eligibility floor (COMM-4.3-3), the fifth
    /// word of the committee config hash (START-10-14, ENC-A-36), and `>= vp_unit` (START-10-12).
    pub min_stake: U256,
    /// `N_MAX`: maximum committee size; in `1..=`[`MAX_N_MAX`].
    pub n_max: usize,
    /// `L2_BLOCK_GAS_LIMIT`: gas limit of every L2 block, in gas; `> 0`.
    pub block_gas_limit: u64,
    /// Switching-network deployment constants; absent for a fresh network starting at S=0.
    pub switch: Option<SwitchConfig>,
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
    /// A switch requires a nonzero Unzen Inbox, fork timestamp, L2 SignalService
    /// implementation and staking implementation.
    #[error(
        "switch configuration requires nonzero Unzen Inbox, fork timestamp, L2 SignalService \
         implementation and staking implementation"
    )]
    InvalidSwitch,
    /// U must lie within the protocol unsettled-depth bounds, `1..=`[`MAX_UNSETTLED_LIMIT`].
    #[error("unsettled_limit must be in 1..={MAX_UNSETTLED_LIMIT}")]
    InvalidUnsettledLimit,
    /// Voting power units must respect the token-supply safety bound.
    #[error("vp_unit must be at least 867361738 base units")]
    VpUnitTooSmall,
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
    /// `4096 × min_stake <= 10^27`: the registry could hold more eligible bonds than its 4096
    /// slots (START-10-12, START-10-18).
    #[error("4096 × min_stake ({min_stake}) must exceed 10^27")]
    MinStakeTooSmall {
        /// Configured `min_stake`.
        min_stake: U256,
    },
    /// `min_stake < vp_unit`, so an eligible entry could map to zero voting power.
    #[error("min_stake ({min_stake}) must be >= vp_unit ({vp_unit})")]
    MinStakeBelowVpUnit {
        /// Configured `min_stake`.
        min_stake: U256,
        /// Configured `vp_unit`.
        vp_unit: U256,
    },
}

impl ChainParams {
    /// Built-in parameters for `l2_chain_id`.
    ///
    /// Only the devnet (`TAIKO_DEVNET_CHAIN_ID`, 167001) is configured, with its `EtnaStaking`
    /// proxy at [`DEVNET_STAKING`] and U = 151,200; mainnet (167000), Hoodi (167013) and every
    /// other chain return [`ConfigError::NotConfigured`] until their Etna PoS values exist, so
    /// Etna cannot start on a chain without a built-in staking address. The returned parameters
    /// pass [`ChainParams::validate`].
    pub fn builtin(l2_chain_id: u64) -> Result<Self, ConfigError> {
        match l2_chain_id {
            TAIKO_DEVNET_CHAIN_ID => Ok(Self {
                l2_chain_id,
                inbox: address!("00000000000000000000000000000000E7A10001"),
                registry: address!("00000000000000000000000000000000E7A10002"),
                staking: DEVNET_STAKING,
                l1_chain_id: U256::from(1),
                unsettled_limit: 151_200,
                fee_recipient: Address::ZERO,
                vp_unit: U256::from(1_000_000_000u64),
                // The registry default of the devnet deployment (`DEFAULT_REGISTRY_MIN_STAKE`):
                // 7,600,000 TAIKO, above the 10^27 / 4096 = 244,140.625 TAIKO floor of
                // START-10-12, so that K = floor(10^27 / minStake) = 131 fits the devnet
                // recovery capacity F = 131 (START-10-14).
                min_stake: U256::from(7_600_000u64) * U256::from(10u64).pow(U256::from(18)),
                n_max: 128,
                block_gas_limit: 45_000_000,
                switch: None,
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
        self.staking = o.staking.unwrap_or(self.staking);
        self.l1_chain_id = o.l1_chain_id.map_or(self.l1_chain_id, |v| v.0);
        self.unsettled_limit = o.unsettled_limit.unwrap_or(self.unsettled_limit);
        self.fee_recipient = o.fee_recipient.unwrap_or(self.fee_recipient);
        self.vp_unit = o.vp_unit.map_or(self.vp_unit, |v| v.0);
        self.min_stake = o.min_stake.map_or(self.min_stake, |v| v.0);
        self.n_max = o.n_max.unwrap_or(self.n_max);
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

    /// Returns the unsettled-block limit U, in L2 blocks.
    pub fn unsettled_limit(&self) -> u64 {
        self.unsettled_limit
    }

    /// The configuration hash of this chain's L2 chain id, staking proxy and U, which Inbox
    /// initialization writes in slot 269 and every node and guest checks
    /// ([`config_hash`](etna_core::params::config_hash)).
    pub fn config_hash(&self) -> B256 {
        etna_core::params::config_hash(self.l2_chain_id, self.staking, self.unsettled_limit)
    }

    /// Checks a switch's nonzero deployment constants, the unsettled-depth bounds, token-supply
    /// voting-power safety, committee capacity, positive block gas limit, `min_stake >= vp_unit`
    /// and `4096 × min_stake > 10^27`. Returns the first invalid deployment parameter.
    pub fn validate(&self) -> Result<(), ConfigError> {
        if self.switch.as_ref().is_some_and(|switch| {
            switch.unzen_inbox.is_zero() ||
                switch.fork_timestamp == 0 ||
                switch.signal_service_implementation.is_zero() ||
                switch.staking_implementation.is_zero()
        }) {
            return Err(ConfigError::InvalidSwitch);
        }
        if !(1..=MAX_UNSETTLED_LIMIT).contains(&self.unsettled_limit) {
            return Err(ConfigError::InvalidUnsettledLimit);
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
        if self.min_stake < self.vp_unit {
            return Err(ConfigError::MinStakeBelowVpUnit {
                min_stake: self.min_stake,
                vp_unit: self.vp_unit,
            });
        }
        if self.min_stake.saturating_mul(U256::from(4096)) <= U256::from(10).pow(U256::from(27)) {
            return Err(ConfigError::MinStakeTooSmall { min_stake: self.min_stake });
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
    /// See [`ChainParams::staking`].
    staking: Option<Address>,
    /// See [`ChainParams::l1_chain_id`].
    l1_chain_id: Option<U256String>,
    /// See [`ChainParams::unsettled_limit`].
    unsettled_limit: Option<u64>,
    /// See [`ChainParams::fee_recipient`].
    fee_recipient: Option<Address>,
    /// See [`ChainParams::vp_unit`].
    vp_unit: Option<U256String>,
    /// See [`ChainParams::min_stake`].
    min_stake: Option<U256String>,
    /// See [`ChainParams::n_max`].
    n_max: Option<usize>,
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
        assert_eq!(p.unsettled_limit(), 151_200);
        assert_eq!(p.n_max, 128);
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
    /// The configuration hash commits the built-in L2 chain id, staking proxy and U.
    #[test]
    fn config_hash_uses_the_builtin_staking_address() {
        let p = devnet();
        let expected = alloy_primitives::b256!(
            "ce98efd6a337c78d7b268a407f9cd0dbfeee0e8724f07bc924087437497b4650"
        );
        assert_eq!(
            etna_core::params::config_hash(p.l2_chain_id, p.staking, p.unsettled_limit),
            expected
        );
        assert_eq!(
            etna_core::params::config_hash(
                167_001,
                address!("1670010000000000000000000000000000010003"),
                151_200
            ),
            expected
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
    /// U is any integer from 1 to 262,144.
    #[test]
    fn config_u_bounds() {
        for limit in [1, 262_144] {
            ChainParams { unsettled_limit: limit, ..devnet() }.validate().unwrap();
        }
        for limit in [0, 262_145] {
            assert!(
                matches!(
                    ChainParams { unsettled_limit: limit, ..devnet() }.validate(),
                    Err(ConfigError::InvalidUnsettledLimit)
                ),
                "U={limit}"
            );
        }
    }
    #[test]
    fn overrides_authenticate_u_and_accept_full_l1_chain_id() {
        let p=devnet().with_overrides("unsettled_limit = 7200\nl1_chain_id = '0x100000000000000000000000000000000000000000000000000'\nfee_recipient = '0x1111111111111111111111111111111111111111'").unwrap();
        assert_eq!(p.unsettled_limit(), 7200);
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
            ChainParams { min_stake: U256::ZERO, ..devnet() },
        ] {
            assert!(p.validate().is_err());
        }
    }
    /// START-10-12/14, COMM-4.3-3: `min_stake` is the registry's minimum, at least `vp_unit` and
    /// with `4096 × min_stake > 10^27`; the TOML key is `min_stake`, and the replaced `s_min`
    /// is an unknown key.
    #[test]
    fn min_stake_is_bounded_and_the_old_s_min_key_is_refused() {
        let floor = U256::from(10).pow(U256::from(27)) / U256::from(4096); // 244,140.625 TAIKO
        assert_eq!(
            devnet().min_stake,
            U256::from(7_600_000u64) * U256::from(10u64).pow(U256::from(18))
        );
        assert!(matches!(
            ChainParams { min_stake: floor, ..devnet() }.validate(),
            Err(ConfigError::MinStakeTooSmall { .. })
        ));
        ChainParams { min_stake: floor + U256::from(1), ..devnet() }.validate().unwrap();
        let huge = U256::MAX / U256::from(2);
        assert!(matches!(
            ChainParams { min_stake: huge, vp_unit: huge + U256::from(1), ..devnet() }.validate(),
            Err(ConfigError::MinStakeBelowVpUnit { .. })
        ));
        let p = devnet().with_overrides("min_stake = '300000000000000000000000'").unwrap();
        assert_eq!(p.min_stake, U256::from(300_000u64) * U256::from(10u64).pow(U256::from(18)));
        assert!(devnet().with_overrides("s_min = '300000000000000000000000'").is_err());
    }
    #[test]
    fn zero_values_hit_the_range_checks() {
        assert!(matches!(
            ChainParams { unsettled_limit: 0, ..devnet() }.validate(),
            Err(ConfigError::InvalidUnsettledLimit)
        ));
        assert!(matches!(
            ChainParams { vp_unit: U256::ZERO, ..devnet() }.validate(),
            Err(ConfigError::VpUnitTooSmall)
        ));
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
        assert!(matches!(zero.validate(), Err(ConfigError::InvalidSwitch)));
    }
}

#[cfg(test)]
mod v1_deployment_bounds {
    use super::*;
    #[test]
    fn unsettled_limit_and_voting_power_deployment_bounds() {
        let base = ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).unwrap();
        for limit in [0, 262_145, u64::MAX] {
            assert!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate().is_err(),
                "U={limit}"
            );
        }
        for limit in [1, 5, 6, 7, 3600, 65_536, 65_537, 151_200, 262_144] {
            assert!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate().is_ok(),
                "U={limit}"
            );
        }
        assert!(
            ChainParams { vp_unit: U256::from(867_361_737), ..base.clone() }.validate().is_err()
        );
        assert!(ChainParams { vp_unit: U256::from(867_361_738), ..base }.validate().is_ok());
    }
}
