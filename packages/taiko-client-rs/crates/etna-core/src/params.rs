//! Canonical deployment parameters and pure validation.

use alloy_primitives::{Address, U256};
use serde::Deserialize;

/// The largest committee size accepted by the registry discovery and consensus bounds.
pub const MAX_N_MAX: usize = 4096;

/// Deployment constants for authenticating an Unzen to Etna switch (SPEC PARAM-11-12a).
/// Production networks compile these values into their chain parameters; private devnets may
/// set the explicit `[switch]` TOML table before creating the signing domain.
#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SwitchConfig {
    /// Live L1 Unzen Inbox proxy whose closed proposal history defines the final Unzen block.
    pub unzen_inbox: Address,
    /// Shared Unzen cutoff and Etna activation timestamp, in Unix seconds.
    pub fork_timestamp: u64,
    /// Etna L2 SignalService implementation built into the client: the L2 SignalService proxy's
    /// EIP-1967 slot holds it at S, and its `beaconRootsFrom()` equals `fork_timestamp`
    /// (SYNC-9-5a, PARAM-11-12a).
    pub signal_service_implementation: Address,
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
    /// Full L1 chain identifier used to bind the Comet signing domain.
    pub l1_chain_id: U256,
    /// Authenticated maximum unsettled depth U in L2 blocks, independent of epoch length.
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

/// Invalid consensus deployment parameters.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ParamsError {
    /// A switch requires a nonzero Unzen Inbox, fork timestamp and L2 SignalService
    /// implementation.
    #[error(
        "switch configuration requires nonzero Unzen Inbox, fork timestamp and L2 SignalService \
         implementation"
    )]
    InvalidSwitch,
    /// U must lie within the protocol unsettled-depth bounds (BACKP-6.4-2).
    #[error("unsettled_limit must be in 1..=65536")]
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
    /// Returns the directly authenticated unsettled limit U in L2 blocks, independent of L.
    pub fn unsettled_cap(&self) -> u64 {
        self.unsettled_limit
    }

    /// Checks the unsettled-depth bounds, token-supply voting-power safety, committee capacity,
    /// positive block gas limit, `min_stake >= vp_unit` and `4096 × min_stake > 10^27`
    /// (START-10-12). Returns the first invalid deployment
    /// parameter.
    pub fn validate(&self) -> Result<(), ParamsError> {
        if self.switch.as_ref().is_some_and(|switch| {
            switch.unzen_inbox.is_zero() ||
                switch.fork_timestamp == 0 ||
                switch.signal_service_implementation.is_zero()
        }) {
            return Err(ParamsError::InvalidSwitch);
        }
        if !(1..=65_536).contains(&self.unsettled_limit) {
            return Err(ParamsError::InvalidUnsettledLimit);
        }
        if self.vp_unit < U256::from(867_361_738) {
            return Err(ParamsError::VpUnitTooSmall);
        }
        if self.n_max == 0 {
            return Err(ParamsError::ZeroNMax);
        }
        if self.n_max > MAX_N_MAX {
            return Err(ParamsError::NMaxTooLarge { n_max: self.n_max, max: MAX_N_MAX });
        }
        if self.block_gas_limit == 0 {
            return Err(ParamsError::ZeroBlockGasLimit);
        }
        if self.min_stake < self.vp_unit {
            return Err(ParamsError::MinStakeBelowVpUnit {
                min_stake: self.min_stake,
                vp_unit: self.vp_unit,
            });
        }
        if self.min_stake.saturating_mul(U256::from(4096)) <= U256::from(10).pow(U256::from(27)) {
            return Err(ParamsError::MinStakeTooSmall { min_stake: self.min_stake });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A switch configuration names the Etna L2 SignalService implementation; the replaced
    /// `anchor_implementation` key is unknown and refused, alone or beside the new key.
    #[test]
    fn switch_configuration_refuses_the_old_anchor_implementation_key() {
        let config = |keys: &str| {
            serde_json::from_str::<SwitchConfig>(&format!(
                r#"{{"unzen_inbox": "0x0000000000000000000000000000000000000001",
                    "fork_timestamp": 1800000000, {keys}}}"#
            ))
        };
        let new_key =
            r#""signal_service_implementation": "0x0000000000000000000000000000000000000002""#;
        let old_key = r#""anchor_implementation": "0x0000000000000000000000000000000000000002""#;
        assert_eq!(
            config(new_key).unwrap().signal_service_implementation,
            Address::with_last_byte(2)
        );
        for keys in [old_key.to_string(), format!("{new_key}, {old_key}")] {
            let error = config(&keys).unwrap_err();
            assert!(error.to_string().contains("anchor_implementation"), "{error}");
        }
    }

    /// BACKP-6.4-2, PARAM-11-8: U is any integer in 1..=65,536, not only a multiple of a grid
    /// interval.
    #[test]
    fn unsettled_limit_is_any_value_from_one_to_65536() {
        let base = crate::test_utils::params();
        for limit in [1, 5, 6, 7, 3600, 65_536] {
            assert_eq!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate(),
                Ok(()),
                "U={limit}"
            );
        }
        for limit in [0, 65_537, u64::MAX] {
            assert_eq!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate(),
                Err(ParamsError::InvalidUnsettledLimit),
                "U={limit}"
            );
        }
    }

    /// START-10-12, COMM-4.3-3: `min_stake` is at least `vp_unit` and `4096 × min_stake`
    /// exceeds 10^27.
    #[test]
    fn min_stake_is_at_least_vp_unit_and_above_the_supply_bound() {
        let base = crate::test_utils::params();
        let floor = U256::from(10).pow(U256::from(27)) / U256::from(4096);
        assert_eq!(
            ChainParams { min_stake: floor, ..base.clone() }.validate(),
            Err(ParamsError::MinStakeTooSmall { min_stake: floor })
        );
        assert_eq!(
            ChainParams { min_stake: floor + U256::from(1), ..base.clone() }.validate(),
            Ok(())
        );
        let huge = U256::MAX / U256::from(2);
        assert_eq!(
            ChainParams { min_stake: huge, vp_unit: huge + U256::from(1), ..base }.validate(),
            Err(ParamsError::MinStakeBelowVpUnit {
                min_stake: huge,
                vp_unit: huge + U256::from(1)
            })
        );
    }
}
