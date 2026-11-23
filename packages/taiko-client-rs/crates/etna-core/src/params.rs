//! Canonical deployment parameters and pure validation.

use crate::committee::{tag, word};
use alloy_primitives::{Address, B256, U256, keccak256};
use serde::Deserialize;

/// `type(uint48).max`: the largest generation the signing domain and `extraData` encode, the
/// largest L2 height `land` accepts and the largest anchor L1 block number `extraData` encodes.
/// CometBFT's `int64` heights are wider.
pub const UINT48_MAX: u64 = (1 << 48) - 1;

/// The largest unsettled limit U, in L2 blocks: U is in `1..=MAX_UNSETTLED_LIMIT`.
pub const MAX_UNSETTLED_LIMIT: u64 = 262_144;

/// The most members any validator set has: a usable candidate and every fallback key list both
/// have 1 to this many, whatever the staking contract's seat limit is.
pub const MAX_SET_MEMBERS: usize = 128;

/// `bytes32("ETNA_CONFIG_V1")`: domain tag of the configuration hash ([`config_hash`]).
const CONFIG_TAG: B256 = tag(b"ETNA_CONFIG_V1");

/// The configuration hash the Inbox stores at initialization and nodes and guests check:
/// `keccak256(abi.encode(bytes32("ETNA_CONFIG_V1"), l2ChainId, staking, U))`, four words.
/// `staking` is the address of the `EtnaStaking` proxy on L2.
pub fn config_hash(l2_chain_id: u64, staking: Address, unsettled_limit: u64) -> B256 {
    keccak256([CONFIG_TAG, word(l2_chain_id), staking.into_word(), word(unsettled_limit)].concat())
}

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
    /// the start, and a start where it does not is refused.
    pub staking_implementation: Address,
}

/// Per-chain constants consumed by consensus.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ChainParams {
    /// L2 EVM chain id.
    pub l2_chain_id: u64,
    /// `ETNA_INBOX`: L1 address of the Etna Inbox.
    pub inbox: Address,
    /// Address of the `EtnaStaking` proxy on L2, built into the client for the L2 chain id; the
    /// configuration hash commits it.
    pub staking: Address,
    /// Full L1 chain identifier used to bind the Comet signing domain.
    pub l1_chain_id: U256,
    /// Maximum unsettled depth U, in L2 blocks; the configuration hash commits it.
    pub unsettled_limit: u64,
    /// Local execution beneficiary chosen by this proposer; not signing set data.
    pub fee_recipient: Address,
    /// `L2_BLOCK_GAS_LIMIT`: gas limit of every L2 block, in gas; `> 0`.
    pub block_gas_limit: u64,
    /// Switching-network deployment constants; absent for a fresh network starting at S=0.
    pub switch: Option<SwitchConfig>,
}

/// Invalid consensus deployment parameters.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ParamsError {
    /// A switch requires a nonzero Unzen Inbox, fork timestamp, L2 SignalService implementation
    /// and staking implementation.
    #[error(
        "switch configuration requires nonzero Unzen Inbox, fork timestamp, L2 SignalService \
         implementation and staking implementation"
    )]
    InvalidSwitch,
    /// U must lie within the protocol unsettled-depth bounds, `1..=`[`MAX_UNSETTLED_LIMIT`].
    #[error("unsettled_limit must be in 1..={MAX_UNSETTLED_LIMIT}")]
    InvalidUnsettledLimit,
    /// `block_gas_limit == 0`.
    #[error("block_gas_limit must be > 0")]
    ZeroBlockGasLimit,
}

impl ChainParams {
    /// Returns the unsettled limit U, in L2 blocks.
    pub fn unsettled_cap(&self) -> u64 {
        self.unsettled_limit
    }

    /// The configuration hash of this chain's L2 chain id, staking proxy and U ([`config_hash`]).
    pub fn config_hash(&self) -> B256 {
        config_hash(self.l2_chain_id, self.staking, self.unsettled_limit)
    }

    /// Checks a switch's nonzero deployment constants, the unsettled-depth bounds and a positive
    /// block gas limit. Returns the first invalid deployment parameter.
    pub fn validate(&self) -> Result<(), ParamsError> {
        if self.switch.as_ref().is_some_and(|switch| {
            switch.unzen_inbox.is_zero() ||
                switch.fork_timestamp == 0 ||
                switch.signal_service_implementation.is_zero() ||
                switch.staking_implementation.is_zero()
        }) {
            return Err(ParamsError::InvalidSwitch);
        }
        if !(1..=MAX_UNSETTLED_LIMIT).contains(&self.unsettled_limit) {
            return Err(ParamsError::InvalidUnsettledLimit);
        }
        if self.block_gas_limit == 0 {
            return Err(ParamsError::ZeroBlockGasLimit);
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
                    "fork_timestamp": 1800000000,
                    "staking_implementation": "0x0000000000000000000000000000000000000003",
                    {keys}}}"#
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

    /// The configuration hash is four words, the tag, the L2 chain id, the staking proxy address
    /// and U, and matches the appendix vector and the shared configuration vector.
    #[test]
    fn config_hash_matches_the_appendix_vector() {
        use crate::test_utils::vectors::{b256_at, str_at, u64_at};
        let example = "/appendix_a_examples/enc_a_36_a";
        let l2_chain_id = u64_at(&format!("{example}/inputs/l2_chain_id"));
        let staking: Address = str_at(&format!("{example}/inputs/staking")).parse().unwrap();
        let unsettled_limit = u64_at(&format!("{example}/inputs/unsettled_limit"));
        let expected = b256_at(&format!("{example}/hash"));
        assert_eq!(config_hash(l2_chain_id, staking, unsettled_limit), expected);
        let params =
            ChainParams { l2_chain_id, staking, unsettled_limit, ..crate::test_utils::params() };
        assert_eq!(params.config_hash(), expected);
        assert_ne!(config_hash(l2_chain_id, staking, unsettled_limit + 1), expected);
        assert_ne!(config_hash(l2_chain_id + 1, staking, unsettled_limit), expected);
        assert_ne!(
            config_hash(l2_chain_id, Address::with_last_byte(0x11), unsettled_limit),
            expected
        );
        assert_eq!(
            config_hash(
                u64_at("/config/inputs/l2_chain_id"),
                str_at("/config/inputs/staking").parse().unwrap(),
                u64_at("/config/inputs/unsettled_limit"),
            ),
            b256_at("/config/hash")
        );
    }

    /// U is any integer from 1 to 262,144, not only a multiple of a grid interval.
    #[test]
    fn unsettled_limit_is_any_value_from_one_to_262144() {
        let base = crate::test_utils::params();
        for limit in [1, 7, 65_536, 65_537, 151_200, MAX_UNSETTLED_LIMIT] {
            assert_eq!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate(),
                Ok(()),
                "U={limit}"
            );
        }
        assert_eq!(MAX_UNSETTLED_LIMIT, 262_144);
        for limit in [0, 262_145, u64::MAX] {
            assert_eq!(
                ChainParams { unsettled_limit: limit, ..base.clone() }.validate(),
                Err(ParamsError::InvalidUnsettledLimit),
                "U={limit}"
            );
        }
    }

    /// A switch names the staking implementation the proxy must hold at the start: the key is
    /// required, and a zero address is an invalid switch.
    #[test]
    fn switch_requires_a_staking_implementation() {
        let switch = SwitchConfig {
            unzen_inbox: Address::with_last_byte(1),
            fork_timestamp: 1_800_000_000,
            signal_service_implementation: Address::with_last_byte(2),
            staking_implementation: Address::with_last_byte(3),
        };
        let base = crate::test_utils::params();
        assert_eq!(ChainParams { switch: Some(switch.clone()), ..base.clone() }.validate(), Ok(()));
        let zero = SwitchConfig { staking_implementation: Address::ZERO, ..switch };
        assert_eq!(
            ChainParams { switch: Some(zero), ..base }.validate(),
            Err(ParamsError::InvalidSwitch)
        );

        let missing = serde_json::from_str::<SwitchConfig>(
            r#"{"unzen_inbox": "0x0000000000000000000000000000000000000001",
                "fork_timestamp": 1800000000,
                "signal_service_implementation": "0x0000000000000000000000000000000000000002"}"#,
        )
        .unwrap_err();
        assert!(missing.to_string().contains("staking_implementation"), "{missing}");
    }
}
