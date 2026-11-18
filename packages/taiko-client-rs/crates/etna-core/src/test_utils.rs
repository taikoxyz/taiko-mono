//! Test-only fixtures shared by the portable consensus regression suites.
use alloy_primitives::U256;
#[cfg(test)]
use alloy_primitives::{Address, B256, keccak256};
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

/// Maps arbitrary old test entropy to a valid native key, preserving deterministic identities.
#[cfg(test)]
pub(crate) fn key_from_seed(seed: B256) -> crate::key::ConsensusKey {
    use k256::elliptic_curve::sec1::ToEncodedPoint;
    let scalar = keccak256(seed);
    let key = k256::SecretKey::from_slice(scalar.as_slice()).unwrap();
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
        registry: Address::from_slice(&alloy_primitives::hex!(
            "00000000000000000000000000000000e7a10002"
        )),
        l1_chain_id: U256::from(1),
        unsettled_limit: 3600,
        fee_recipient: Address::ZERO,
        vp_unit: U256::from(1_000_000_000u64),
        s_min: U256::from(1_000_000_000_000_000_000u64),
        n_max: 128,
        block_gas_limit: 45_000_000,
        switch: None,
    }
}
