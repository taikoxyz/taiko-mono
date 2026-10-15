//! Dependency-free scalar Etna consensus rules, shared by ABCI and the lander.
//!
//! Inputs are facts authenticated by adapters; these rules do not verify proofs or signatures.
#![no_std]

pub mod forced;
pub mod schedule;
pub mod transition;

/// Whether authenticated signed power exceeds two thirds of authenticated total power.
/// Works over the entire u128 domain without overflowing either multiplication.
pub fn has_strict_quorum(signed_power: u128, total_power: u128) -> bool {
    signed_power > (total_power / 3) * 2 + ((total_power % 3) * 2) / 3
}

#[cfg(test)]
mod tests;
