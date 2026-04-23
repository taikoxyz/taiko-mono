//! Shasta protocol constants and limits.

use crate::shasta::error::{ForkConfigError, ForkConfigResult};
use alethia_reth_consensus::eip4396::{MAINNET_MIN_BASE_FEE, MIN_BASE_FEE};
use alloy_eips::eip4844::BYTES_PER_BLOB;
use alloy_hardforks::ForkCondition;

/// The maximum number of blocks allowed in a derivation source before Unzen.
///
/// With 1-second blocks, 192 blocks cover one Ethereum epoch.
pub const DERIVATION_SOURCE_MAX_BLOCKS: usize = 192;

/// The maximum number of blocks allowed in a derivation source once Unzen is active.
///
/// This allows room for faster block times after the fork without changing the
/// pre-Unzen manifest validation rules.
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

/// Shasta fork activation on Taiko Devnet.
pub const SHASTA_FORK_DEVNET: ForkCondition = ForkCondition::Timestamp(0);

/// Shasta fork activation on Taiko Masaya.
pub const SHASTA_FORK_MASAYA: ForkCondition = ForkCondition::Timestamp(0);

/// Shasta fork activation on Taiko Hoodi.
pub const SHASTA_FORK_HOODI: ForkCondition = ForkCondition::Timestamp(1_770_296_400);

/// Shasta fork activation on Taiko Mainnet.
pub const SHASTA_FORK_MAINNET: ForkCondition = ForkCondition::Timestamp(1_775_135_700);

/// Unzen fork activation on Taiko Devnet.
pub const UNZEN_FORK_DEVNET: ForkCondition = ForkCondition::Timestamp(0);

/// Unzen fork activation on Taiko Masaya.
pub const UNZEN_FORK_MASAYA: ForkCondition = ForkCondition::Never;

/// Unzen fork activation on Taiko Hoodi.
pub const UNZEN_FORK_HOODI: ForkCondition = ForkCondition::Never;

/// Unzen fork activation on Taiko Mainnet.
pub const UNZEN_FORK_MAINNET: ForkCondition = ForkCondition::Never;

/// Taiko chain IDs where the Shasta fork is configured.
pub const TAIKO_DEVNET_CHAIN_ID: u64 = 167_001;
/// Chain ID for the Taiko Masaya network.
pub const TAIKO_MASAYA_CHAIN_ID: u64 = 167_011;
/// Chain ID for the Taiko Hoodi network.
pub const TAIKO_HOODI_CHAIN_ID: u64 = 167_013;
/// Chain ID for Taiko mainnet.
pub const TAIKO_MAINNET_CHAIN_ID: u64 = 167_000;

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

/// Returns the configured Shasta fork condition for a given Taiko L2 chain ID.
pub const fn shasta_fork_condition_for_chain(chain_id: u64) -> Option<ForkCondition> {
    match chain_id {
        TAIKO_DEVNET_CHAIN_ID => Some(SHASTA_FORK_DEVNET),
        TAIKO_MASAYA_CHAIN_ID => Some(SHASTA_FORK_MASAYA),
        TAIKO_HOODI_CHAIN_ID => Some(SHASTA_FORK_HOODI),
        TAIKO_MAINNET_CHAIN_ID => Some(SHASTA_FORK_MAINNET),
        _ => None,
    }
}

/// Returns the configured Unzen fork condition for a given Taiko L2 chain ID.
pub const fn unzen_fork_condition_for_chain(chain_id: u64) -> Option<ForkCondition> {
    match chain_id {
        TAIKO_DEVNET_CHAIN_ID => Some(UNZEN_FORK_DEVNET),
        TAIKO_MASAYA_CHAIN_ID => Some(UNZEN_FORK_MASAYA),
        TAIKO_HOODI_CHAIN_ID => Some(UNZEN_FORK_HOODI),
        TAIKO_MAINNET_CHAIN_ID => Some(UNZEN_FORK_MAINNET),
        _ => None,
    }
}

/// Returns the Shasta fork activation timestamp for a Taiko chain.
pub fn shasta_fork_timestamp_for_chain(chain_id: u64) -> ForkConfigResult<u64> {
    let condition = shasta_fork_condition_for_chain(chain_id)
        .ok_or(ForkConfigError::UnsupportedChainId(chain_id))?;

    match condition {
        ForkCondition::Timestamp(timestamp) => Ok(timestamp),
        _ => Err(ForkConfigError::UnsupportedActivation),
    }
}

/// Returns the Unzen fork activation timestamp for a Taiko chain.
pub fn unzen_fork_timestamp_for_chain(chain_id: u64) -> ForkConfigResult<u64> {
    let condition = unzen_fork_condition_for_chain(chain_id)
        .ok_or(ForkConfigError::UnsupportedChainId(chain_id))?;

    match condition {
        ForkCondition::Timestamp(timestamp) => Ok(timestamp),
        _ => Err(ForkConfigError::UnsupportedActivation),
    }
}

/// Returns whether Unzen is active for a Taiko chain at the provided block timestamp.
pub fn unzen_active_for_chain_timestamp(chain_id: u64, timestamp: u64) -> ForkConfigResult<bool> {
    let condition = unzen_fork_condition_for_chain(chain_id)
        .ok_or(ForkConfigError::UnsupportedChainId(chain_id))?;

    match condition {
        ForkCondition::Timestamp(fork_timestamp) => Ok(timestamp >= fork_timestamp),
        ForkCondition::Never => Ok(false),
        _ => Err(ForkConfigError::UnsupportedActivation),
    }
}

/// Returns the per-source derivation block limit for a Taiko chain at the provided timestamp.
pub fn derivation_source_max_blocks_for_timestamp(
    chain_id: u64,
    timestamp: u64,
) -> ForkConfigResult<usize> {
    if unzen_active_for_chain_timestamp(chain_id, timestamp)? {
        Ok(UNZEN_DERIVATION_SOURCE_MAX_BLOCKS)
    } else {
        Ok(DERIVATION_SOURCE_MAX_BLOCKS)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        DERIVATION_SOURCE_MAX_BLOCKS, ForkConfigError, MAX_ANCHOR_OFFSET,
        MAX_ANCHOR_OFFSET_MAINNET, TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID,
        TAIKO_MAINNET_CHAIN_ID, TAIKO_MASAYA_CHAIN_ID, TIMESTAMP_MAX_OFFSET,
        TIMESTAMP_MAX_OFFSET_MAINNET, UNZEN_DERIVATION_SOURCE_MAX_BLOCKS,
        derivation_source_max_blocks_for_timestamp, max_anchor_offset_for_chain,
        shasta_fork_timestamp_for_chain, timestamp_max_offset_for_chain,
        unzen_fork_condition_for_chain, unzen_fork_timestamp_for_chain,
    };
    use alloy_hardforks::ForkCondition;

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
    fn mainnet_fork_timestamp_is_configured() {
        assert_eq!(
            shasta_fork_timestamp_for_chain(TAIKO_MAINNET_CHAIN_ID)
                .expect("mainnet shasta timestamp should resolve"),
            1_775_135_700
        );
    }

    #[test]
    fn unzen_fork_conditions_are_configured() {
        assert_eq!(
            unzen_fork_condition_for_chain(TAIKO_DEVNET_CHAIN_ID),
            Some(super::UNZEN_FORK_DEVNET)
        );
        assert_eq!(
            unzen_fork_condition_for_chain(TAIKO_MASAYA_CHAIN_ID),
            Some(ForkCondition::Never)
        );
        assert_eq!(
            unzen_fork_condition_for_chain(TAIKO_HOODI_CHAIN_ID),
            Some(ForkCondition::Never)
        );
        assert_eq!(
            unzen_fork_condition_for_chain(TAIKO_MAINNET_CHAIN_ID),
            Some(ForkCondition::Never)
        );
    }

    #[test]
    fn unzen_fork_timestamps_are_configured() {
        assert_eq!(
            unzen_fork_timestamp_for_chain(TAIKO_DEVNET_CHAIN_ID)
                .expect("devnet unzen timestamp should resolve"),
            0
        );
        assert!(matches!(
            unzen_fork_timestamp_for_chain(TAIKO_MASAYA_CHAIN_ID),
            Err(ForkConfigError::UnsupportedActivation)
        ));
        assert!(matches!(
            unzen_fork_timestamp_for_chain(TAIKO_HOODI_CHAIN_ID),
            Err(ForkConfigError::UnsupportedActivation)
        ));
        assert!(matches!(
            unzen_fork_timestamp_for_chain(TAIKO_MAINNET_CHAIN_ID),
            Err(ForkConfigError::UnsupportedActivation)
        ));
    }

    #[test]
    fn derivation_source_max_blocks_switches_at_unzen() {
        assert_eq!(
            derivation_source_max_blocks_for_timestamp(TAIKO_DEVNET_CHAIN_ID, 0)
                .expect("devnet unzen max blocks should resolve"),
            UNZEN_DERIVATION_SOURCE_MAX_BLOCKS
        );
        assert_eq!(
            derivation_source_max_blocks_for_timestamp(TAIKO_HOODI_CHAIN_ID, u64::MAX)
                .expect("hoodi max blocks should resolve"),
            DERIVATION_SOURCE_MAX_BLOCKS
        );
        assert_eq!(
            derivation_source_max_blocks_for_timestamp(TAIKO_MAINNET_CHAIN_ID, u64::MAX)
                .expect("mainnet max blocks should resolve"),
            DERIVATION_SOURCE_MAX_BLOCKS
        );
    }
}
