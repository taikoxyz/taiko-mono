//! Shasta protocol constants and limits.

use std::{cmp::min, sync::OnceLock};

use crate::shasta::error::{ForkConfigError, ForkConfigResult};
use alethia_reth_chainspec::hardfork::{
    TAIKO_DEVNET_HARDFORKS, TAIKO_HOODI_HARDFORKS, TAIKO_MAINNET_HARDFORKS, TAIKO_MASAYA_HARDFORKS,
    TaikoHardfork,
};
pub use alethia_reth_chainspec::{
    TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID, TAIKO_MASAYA_CHAIN_ID,
};
use alethia_reth_consensus::eip4396::{
    BASE_FEE_MAX_CHANGE_DENOMINATOR, BLOCK_TIME_TARGET, ELASTICITY_MULTIPLIER,
    MAINNET_MIN_BASE_FEE, MAX_BASE_FEE, MAX_GAS_TARGET_PERCENT, MIN_BASE_FEE,
    SHASTA_INITIAL_BASE_FEE,
};
use alloy_eips::eip4844::BYTES_PER_BLOB;
use alloy_hardforks::ForkCondition;

/// The maximum number of blocks allowed in a proposal. If we assume block time is as
/// small as one second, 192 blocks will cover an Ethereum epoch.
pub const DERIVATION_SOURCE_MAX_BLOCKS: usize = 192;

/// The maximum number of blocks allowed in a proposal source at and after Unzen.
pub const UNZEN_DERIVATION_SOURCE_MAX_BLOCKS: usize = 768;

/// The maximum anchor block number offset from the proposal origin block number.
pub const MAX_ANCHOR_OFFSET: u64 = 128;
/// The maximum anchor block number offset from the proposal origin block number on mainnet.
pub const MAX_ANCHOR_OFFSET_MAINNET: u64 = 512;

/// The maximum timestamp offset from the proposal origin timestamp.
pub const TIMESTAMP_MAX_OFFSET: u64 = 12 * 128;
/// The maximum timestamp offset from the proposal origin timestamp on mainnet.
pub const TIMESTAMP_MAX_OFFSET_MAINNET: u64 = 12 * 512;

/// The minimum block gas limit.
pub const MIN_BLOCK_GAS_LIMIT: u64 = 10_000_000;

/// The maximum block gas limit.
pub const MAX_BLOCK_GAS_LIMIT: u64 = 45_000_000;

/// The maximum block gas limit change per block, expressed in millionths.
pub const BLOCK_GAS_LIMIT_MAX_CHANGE: u64 = 200;

/// Denominator (parts per million) used when clamping gas limits (10 ppm = 0.001%).
pub const GAS_LIMIT_DENOMINATOR: u64 = 1_000_000;

/// The delay in processing bond instructions relative to the current proposal.
pub const BOND_PROCESSING_DELAY: u64 = 6;

/// On Taiko mainnet, early bootstrap proposals recover the parent anchor from the embedded
/// `anchorV4` / `anchorV3` transaction instead of the anchor contract state.
pub const MAINNET_ANCHOR_CHECK_SKIP_PROPOSAL_OFFSET: u64 = 7;

/// The current version of the Shasta protocol payload format.
pub const SHASTA_PAYLOAD_VERSION: u8 = 0x1;

/// The maximum size of a blob data, in bytes.
pub const PROPOSAL_MAX_BLOB_BYTES: usize = BYTES_PER_BLOB;

/// Maximum number of forced inclusions processed per proposal.
pub const MAX_FORCED_INCLUSIONS_PER_PROPOSAL: u16 = 10;

/// Process-global override for the devnet Unzen activation timestamp.
///
/// Set once at startup (typically from a CLI flag mirroring alethia-reth's
/// `--devnet-unzen-timestamp`) so client and node agree on devnet fork timing.
/// Only the first call takes effect; subsequent calls are silently ignored.
static DEVNET_UNZEN_OVERRIDE: OnceLock<u64> = OnceLock::new();

/// Set the devnet Unzen activation timestamp override. Must be called before
/// any fork-condition lookup runs for the internal devnet. Subsequent calls
/// after the first are ignored. Logs the applied value on the first
/// successful set so operators see confirmation at startup.
pub fn set_devnet_unzen_override(timestamp: u64) {
    if DEVNET_UNZEN_OVERRIDE.set(timestamp).is_ok() {
        tracing::info!(timestamp, "applied devnet Unzen activation time override");
    }
}

/// Returns the maximum anchor block offset for a Taiko chain.
pub const fn max_anchor_offset_for_chain(chain_id: u64) -> u64 {
    if chain_id == TAIKO_MAINNET_CHAIN_ID { MAX_ANCHOR_OFFSET_MAINNET } else { MAX_ANCHOR_OFFSET }
}

/// Returns the maximum timestamp offset for a Taiko chain.
pub const fn timestamp_max_offset_for_chain(chain_id: u64) -> u64 {
    if chain_id == TAIKO_MAINNET_CHAIN_ID {
        TIMESTAMP_MAX_OFFSET_MAINNET
    } else {
        TIMESTAMP_MAX_OFFSET
    }
}

/// Returns the EIP-4396 minimum base-fee clamp for a Taiko chain.
///
/// Taiko mainnet uses a distinct clamp value; all other supported chains use the default.
pub const fn min_base_fee_for_chain(chain_id: u64) -> u64 {
    if chain_id == TAIKO_MAINNET_CHAIN_ID { MAINNET_MIN_BASE_FEE } else { MIN_BASE_FEE }
}

/// Calculate the next EIP-4396 base fee from parent-header values.
///
/// This mirrors alethia-reth's calculation while accepting raw values, so callers using the
/// workspace's Alloy 1 header type do not need to depend on alethia-reth's Alloy 2 header trait.
pub fn calculate_next_block_eip4396_base_fee_from_parent_values(
    parent_number: u64,
    parent_gas_limit: u64,
    parent_gas_used: u64,
    parent_block_time: u64,
    parent_base_fee_per_gas: u64,
    min_base_fee_to_clamp: u64,
) -> u64 {
    if parent_number == 0 {
        return SHASTA_INITIAL_BASE_FEE;
    }

    let parent_base_gas_target = parent_gas_limit / ELASTICITY_MULTIPLIER;
    let parent_adjusted_gas_target = min(
        parent_base_gas_target * parent_block_time / BLOCK_TIME_TARGET,
        parent_gas_limit * MAX_GAS_TARGET_PERCENT / 100,
    );
    let mut base_fee = parent_base_fee_per_gas;

    match parent_gas_used.cmp(&parent_adjusted_gas_target) {
        core::cmp::Ordering::Equal => {}
        core::cmp::Ordering::Greater => {
            let gas_used_delta = parent_gas_used - parent_adjusted_gas_target;
            let base_fee_per_gas_delta = core::cmp::max(
                parent_base_fee_per_gas as u128 * gas_used_delta as u128 /
                    parent_base_gas_target as u128 /
                    BASE_FEE_MAX_CHANGE_DENOMINATOR,
                1,
            ) as u64;
            base_fee = base_fee.saturating_add(base_fee_per_gas_delta);
        }
        core::cmp::Ordering::Less => {
            let gas_used_delta = parent_adjusted_gas_target - parent_gas_used;
            let base_fee_per_gas_delta = (parent_base_fee_per_gas as u128 * gas_used_delta as u128 /
                parent_base_gas_target as u128 /
                BASE_FEE_MAX_CHANGE_DENOMINATOR) as u64;
            base_fee = base_fee.saturating_sub(base_fee_per_gas_delta);
        }
    }

    base_fee.clamp(min_base_fee_to_clamp, MAX_BASE_FEE)
}

/// Returns the configured hardfork condition for a given Taiko L2 chain ID.
fn fork_condition_for_chain(
    chain_id: u64,
    hardfork: TaikoHardfork,
) -> ForkConfigResult<ForkCondition> {
    match chain_id {
        TAIKO_DEVNET_CHAIN_ID => Ok(TAIKO_DEVNET_HARDFORKS.fork(hardfork)),
        TAIKO_MASAYA_CHAIN_ID => Ok(TAIKO_MASAYA_HARDFORKS.fork(hardfork)),
        TAIKO_HOODI_CHAIN_ID => Ok(TAIKO_HOODI_HARDFORKS.fork(hardfork)),
        TAIKO_MAINNET_CHAIN_ID => Ok(TAIKO_MAINNET_HARDFORKS.fork(hardfork)),
        _ => Err(ForkConfigError::UnsupportedChainId(chain_id)),
    }
}

/// Returns the configured Shasta fork condition for a given Taiko L2 chain ID.
pub fn shasta_fork_condition_for_chain(chain_id: u64) -> ForkConfigResult<ForkCondition> {
    fork_condition_for_chain(chain_id, TaikoHardfork::Shasta)
}

/// Returns the configured Unzen fork condition for a given Taiko L2 chain ID.
///
/// For the internal devnet, honors any override installed via
/// `set_devnet_unzen_override`; falls back to the chainspec schedule otherwise.
pub fn unzen_fork_condition_for_chain(chain_id: u64) -> ForkConfigResult<ForkCondition> {
    match chain_id {
        TAIKO_DEVNET_CHAIN_ID => Ok(DEVNET_UNZEN_OVERRIDE
            .get()
            .copied()
            .map(ForkCondition::Timestamp)
            .unwrap_or(fork_condition_for_chain(chain_id, TaikoHardfork::Unzen)?)),
        _ => fork_condition_for_chain(chain_id, TaikoHardfork::Unzen),
    }
}

/// Returns the Shasta fork activation timestamp for a Taiko chain.
pub fn shasta_fork_timestamp_for_chain(chain_id: u64) -> ForkConfigResult<u64> {
    let condition = shasta_fork_condition_for_chain(chain_id)?;

    match condition {
        ForkCondition::Timestamp(timestamp) => Ok(timestamp),
        _ => Err(ForkConfigError::UnsupportedActivation),
    }
}

/// Returns the Unzen fork activation timestamp for a Taiko chain.
pub fn unzen_fork_timestamp_for_chain(chain_id: u64) -> ForkConfigResult<u64> {
    let condition = unzen_fork_condition_for_chain(chain_id)?;

    match condition {
        ForkCondition::Timestamp(timestamp) => Ok(timestamp),
        _ => Err(ForkConfigError::UnsupportedActivation),
    }
}

/// Returns whether Unzen is active for a Taiko chain at the provided block timestamp.
pub fn unzen_active_for_chain_timestamp(chain_id: u64, timestamp: u64) -> ForkConfigResult<bool> {
    let condition = unzen_fork_condition_for_chain(chain_id)?;

    match condition {
        ForkCondition::Timestamp(fork_timestamp) => Ok(timestamp >= fork_timestamp),
        ForkCondition::Never => Ok(false),
        _ => Err(ForkConfigError::UnsupportedActivation),
    }
}

/// Returns the per-source derivation block limit for a proposal timestamp.
pub fn derivation_source_max_blocks_for_chain_timestamp(
    chain_id: u64,
    proposal_timestamp: u64,
) -> usize {
    match unzen_active_for_chain_timestamp(chain_id, proposal_timestamp) {
        Ok(true) => UNZEN_DERIVATION_SOURCE_MAX_BLOCKS,
        Ok(false) | Err(_) => DERIVATION_SOURCE_MAX_BLOCKS,
    }
}

#[cfg(test)]
mod tests {
    use super::{
        DERIVATION_SOURCE_MAX_BLOCKS, ForkConfigError, MAX_ANCHOR_OFFSET,
        MAX_ANCHOR_OFFSET_MAINNET, TAIKO_HOODI_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID,
        TIMESTAMP_MAX_OFFSET, TIMESTAMP_MAX_OFFSET_MAINNET, max_anchor_offset_for_chain,
        shasta_fork_condition_for_chain, timestamp_max_offset_for_chain,
        unzen_fork_condition_for_chain,
    };

    #[test]
    fn offsets_are_chain_aware() {
        assert_eq!(max_anchor_offset_for_chain(TAIKO_HOODI_CHAIN_ID), MAX_ANCHOR_OFFSET);
        assert_eq!(max_anchor_offset_for_chain(TAIKO_MAINNET_CHAIN_ID), MAX_ANCHOR_OFFSET_MAINNET);
        assert_eq!(timestamp_max_offset_for_chain(TAIKO_HOODI_CHAIN_ID), TIMESTAMP_MAX_OFFSET);
        assert_eq!(
            timestamp_max_offset_for_chain(TAIKO_MAINNET_CHAIN_ID),
            TIMESTAMP_MAX_OFFSET_MAINNET
        );
    }

    #[test]
    fn unsupported_chain_ids_error_on_fork_condition_lookup() {
        assert!(matches!(
            shasta_fork_condition_for_chain(u64::MAX),
            Err(ForkConfigError::UnsupportedChainId(chain_id)) if chain_id == u64::MAX
        ));
        assert!(matches!(
            unzen_fork_condition_for_chain(u64::MAX),
            Err(ForkConfigError::UnsupportedChainId(chain_id)) if chain_id == u64::MAX
        ));
    }

    #[test]
    fn derivation_source_max_blocks_falls_back_for_unsupported_chains() {
        assert_eq!(
            super::derivation_source_max_blocks_for_chain_timestamp(u64::MAX, u64::MAX),
            DERIVATION_SOURCE_MAX_BLOCKS
        );
    }
}
