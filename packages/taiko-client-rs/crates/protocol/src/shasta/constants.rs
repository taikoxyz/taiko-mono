//! Shasta protocol constants and limits.

use crate::shasta::error::{ForkConfigResult, ShastaForkConfigError};
use alethia_reth_consensus::eip4396::{MAINNET_MIN_BASE_FEE, MIN_BASE_FEE};
use alloy_eips::eip4844::BYTES_PER_BLOB;
use alloy_hardforks::ForkCondition;

/// The maximum number of blocks allowed in a proposal. If we assume block time is as
/// small as one second, 192 blocks will cover an Ethereum epoch.
pub const DERIVATION_SOURCE_MAX_BLOCKS: usize = 192;

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

/// Shasta fork activation on Taiko Mainnet. This fork has not been scheduled yet.
pub const SHASTA_FORK_MAINNET: ForkCondition = ForkCondition::Never;

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

/// Returns the Shasta fork activation timestamp for a Taiko chain.
pub fn shasta_fork_timestamp_for_chain(chain_id: u64) -> ForkConfigResult<u64> {
    let condition = shasta_fork_condition_for_chain(chain_id)
        .ok_or(ShastaForkConfigError::UnsupportedChainId(chain_id))?;

    match condition {
        ForkCondition::Timestamp(timestamp) => Ok(timestamp),
        _ => Err(ShastaForkConfigError::UnsupportedActivation),
    }
}

#[cfg(test)]
mod tests {
    use super::{
        MAX_ANCHOR_OFFSET, MAX_ANCHOR_OFFSET_MAINNET, TAIKO_HOODI_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID,
        TIMESTAMP_MAX_OFFSET, TIMESTAMP_MAX_OFFSET_MAINNET, max_anchor_offset_for_chain,
        timestamp_max_offset_for_chain,
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
}
