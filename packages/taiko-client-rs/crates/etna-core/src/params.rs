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
    /// `S_min`: minimum effective stake of an eligible entry, in TAIKO base units; `>= vp_unit`.
    pub s_min: U256,
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
    /// Returns the directly authenticated unsettled limit U in L2 blocks, independent of L.
    pub fn unsettled_cap(&self) -> u64 {
        self.unsettled_limit
    }

    /// Checks the unsettled-depth bounds, token-supply voting-power safety, committee capacity,
    /// positive block gas limit and s_min >= vp_unit. Returns the first invalid deployment
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
        if self.s_min < self.vp_unit {
            return Err(ParamsError::SMinBelowVpUnit { s_min: self.s_min, vp_unit: self.vp_unit });
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
}
