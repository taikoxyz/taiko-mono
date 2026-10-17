//! Dependency-free scalar Etna consensus rules, shared by ABCI and the lander.
//!
//! Inputs are facts authenticated by adapters; these rules do not verify proofs or signatures.
#![no_std]

pub mod forced;
pub mod schedule;
pub mod transition;

/// Largest committee size accepted by the registry discovery and consensus bounds.
pub const MAX_N_MAX: usize = 4096;

/// Upper committee-size bound only; adapters reject zero separately in the original order.
pub fn committee_size_bounded(n_max: usize) -> bool {
    n_max <= MAX_N_MAX
}

/// Whether configured depth exceeds its margin, ensuring a strictly positive saturated cap.
pub fn positive_unsettled_cap(d_max: u64, margin: u64) -> bool {
    d_max > margin
}

/// Whether authenticated signed power exceeds two thirds of authenticated total power.
/// Works over the entire u128 domain without overflowing either multiplication.
pub fn has_strict_quorum(signed_power: u128, total_power: u128) -> bool {
    signed_power > (total_power / 3) * 2 + ((total_power % 3) * 2) / 3
}

#[cfg(test)]
mod tests;
