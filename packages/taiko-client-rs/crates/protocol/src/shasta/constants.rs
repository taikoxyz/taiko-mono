//! Shasta protocol constants and limits.

use crate::shasta::error::{ForkConfigResult, ShastaForkConfigError};
use alloy_eips::eip4844::BYTES_PER_BLOB;
use alloy_hardforks::ForkCondition;

/// The maximum number of blocks allowed in a proposal. If we assume block time is as
/// small as one second, 384 blocks will cover an Ethereum epoch.
pub const PROPOSAL_MAX_BLOCKS: usize = 384;

/// The maximum anchor block number offset from the proposal origin block number.
pub const MAX_ANCHOR_OFFSET: u64 = 128;

/// The maximum timestamp offset from the proposal origin timestamp.
pub const TIMESTAMP_MAX_OFFSET: u64 = 12 * 128;

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

/// Shasta fork activation on Taiko Devnet.
pub const SHASTA_FORK_DEVNET: ForkCondition = ForkCondition::Timestamp(0);

/// Shasta fork activation on Taiko Hoodi. This fork has not been scheduled yet.
pub const SHASTA_FORK_HOODI: ForkCondition = ForkCondition::Never;

/// Shasta fork activation on Taiko Mainnet. This fork has not been scheduled yet.
pub const SHASTA_FORK_MAINNET: ForkCondition = ForkCondition::Never;

/// Taiko chain IDs where the Shasta fork is configured.
pub const TAIKO_DEVNET_CHAIN_ID: u64 = 167_001;
pub const TAIKO_HOODI_CHAIN_ID: u64 = 167_013;
pub const TAIKO_MAINNET_CHAIN_ID: u64 = 167_000;

/// Returns the configured Shasta fork condition for a given Taiko L2 chain ID.
pub const fn shasta_fork_condition_for_chain(chain_id: u64) -> Option<ForkCondition> {
    match chain_id {
        TAIKO_DEVNET_CHAIN_ID => Some(SHASTA_FORK_DEVNET),
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
