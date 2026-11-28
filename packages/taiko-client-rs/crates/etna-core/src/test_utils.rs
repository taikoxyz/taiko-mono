//! Test-only fixtures shared by the portable consensus regression suites.
#[cfg(test)]
use alloy_primitives::Address;
use alloy_primitives::U256;
#[cfg(test)]
pub(crate) mod vectors;
/// Deterministic valid consensus key derived from a nonzero test scalar.
pub(crate) fn test_key(seed: u64) -> crate::key::ConsensusKey {
    let scalar = U256::from(seed.saturating_add(1)).to_be_bytes::<32>();
    let key = k256::SecretKey::from_slice(&scalar).unwrap();
    use k256::elliptic_curve::sec1::ToEncodedPoint;
    crate::key::ConsensusKey::from_slice(key.public_key().to_encoded_point(true).as_bytes())
        .unwrap()
}

/// Canonical devnet-shaped parameters without host builtin selection or TOML.
#[cfg(test)]
pub(crate) fn params() -> crate::params::ChainParams {
    crate::params::ChainParams {
        l2_chain_id: 167001,
        inbox: Address::from_slice(&alloy_primitives::hex!(
            "00000000000000000000000000000000e7a10001"
        )),
        // The devnet's built-in EtnaStaking proxy on L2.
        staking: alloy_primitives::address!("1670010000000000000000000000000000010003"),
        l1_chain_id: U256::from(1),
        unsettled_limit: 3600,
        fee_recipient: Address::ZERO,
        block_gas_limit: 45_000_000,
        switch: None,
    }
}
