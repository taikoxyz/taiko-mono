//! Shasta protocol constants and limits.

use crate::shasta::error::{ForkConfigResult, ShastaForkConfigError};
use alloy_eips::eip4844::{FIELD_ELEMENTS_PER_BLOB, USABLE_BITS_PER_FIELD_ELEMENT};
use alloy_hardforks::ForkCondition;

/// The maximum number of blocks allowed in a proposal. If we assume block time is as
/// small as one second, 384 blocks will cover an Ethereum epoch.
/// NOTE: Should be same with `PROPOSAL_MAX_BLOCKS` in contracts/layer1/libs/LibManifest.sol.
pub const PROPOSAL_MAX_BLOCKS: usize = 384;

/// The maximum anchor block number offset from the proposal origin block number.
/// NOTE: Should be same with `ANCHOR_MAX_OFFSET` in contracts/layer1/libs/LibManifest.sol.
pub const ANCHOR_MAX_OFFSET: u64 = 128;

/// The minimum anchor block number offset from the proposal origin block number.
/// NOTE: Should be same with `ANCHOR_MIN_OFFSET` in contracts/layer1/libs/LibManifest.sol.
pub const ANCHOR_MIN_OFFSET: u64 = 2;

/// The maximum timestamp offset from the proposal origin timestamp.
/// NOTE: Should be same with `TIMESTAMP_MAX_OFFSET` in
/// contracts/layer1/libs/LibManifest.sol.
pub const TIMESTAMP_MAX_OFFSET: u64 = 12 * 32;

/// The maximum block gas limit change per block, expressed in millionths.
/// NOTE: Should be same with `BLOCK_GAS_LIMIT_MAX_CHANGE` in
/// contracts/layer1/libs/LibManifest.sol.
pub const BLOCK_GAS_LIMIT_MAX_CHANGE: u64 = 10;

/// The minimum block gas limit.
/// NOTE: Should be same with `MIN_BLOCK_GAS_LIMIT` in
/// contracts/layer1/libs/LibConstants.sol.
pub const MIN_BLOCK_GAS_LIMIT: u64 = 15_000_000;

/// The delay in processing bond instructions relative to the current proposal.
/// NOTE: Should be same with `BOND_PROCESSING_DELAY` in
/// contracts/layer1/libs/LibManifest.sol.
pub const BOND_PROCESSING_DELAY: u64 = 6;

/// The current version of the Shasta protocol payload format.
pub const SHASTA_PAYLOAD_VERSION: u8 = 0x1;

/// The maximum size of a blob data, in bytes.
pub const PROPOSAL_MAX_BLOB_BYTES: usize =
    (USABLE_BITS_PER_FIELD_ELEMENT - 1) * FIELD_ELEMENTS_PER_BLOB as usize;

/// Shasta fork activation on Taiko Devnet.
pub const SHASTA_FORK_DEVNET: ForkCondition = ForkCondition::Block(10);

/// Shasta fork activation on Taiko Hoodi. This fork has not been scheduled yet.
pub const SHASTA_FORK_HOODI: ForkCondition = ForkCondition::Never;

/// Shasta fork activation on Taiko Mainnet. This fork has not been scheduled yet.
pub const SHASTA_FORK_MAINNET: ForkCondition = ForkCondition::Never;

/// Returns the configured Shasta fork condition for a given Taiko L2 chain ID.
pub const fn shasta_fork_condition_for_chain(chain_id: u64) -> Option<ForkCondition> {
    match chain_id {
        167_001 => Some(SHASTA_FORK_DEVNET),
        167_013 => Some(SHASTA_FORK_HOODI),
        167_000 => Some(SHASTA_FORK_MAINNET),
        _ => None,
    }
}

/// Returns the scheduled block height for Shasta activation on the given chain, if any.
pub const fn shasta_fork_block_for_chain(chain_id: u64) -> Option<u64> {
    match shasta_fork_condition_for_chain(chain_id) {
        Some(ForkCondition::Block(height)) => Some(height),
        _ => None,
    }
}

/// Returns the Shasta fork activation height for a Taiko chain.
pub fn shasta_fork_height_for_chain(chain_id: u64) -> ForkConfigResult<u64> {
    let condition = shasta_fork_condition_for_chain(chain_id)
        .ok_or(ShastaForkConfigError::UnsupportedChainId(chain_id))?;

    match condition {
        ForkCondition::Block(height) => Ok(height),
        _ => Err(ShastaForkConfigError::UnsupportedActivation),
    }
}
