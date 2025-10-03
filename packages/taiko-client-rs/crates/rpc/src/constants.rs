use alloy_eips::eip4844::{FIELD_ELEMENTS_PER_BLOB, USABLE_BITS_PER_FIELD_ELEMENT};

/// The maximum number of blocks allowed in a proposal. If we assume block time is as
/// small as one second, 384 blocks will cover an Ethereum epoch.
/// NOTE: Should be same with `PROPOSAL_MAX_BLOCKS` in contracts/layer1/shasta/libs/LibManifest.sol.
pub const PROPOSAL_MAX_BLOCKS: usize = 384;

/// The maximum size of a blob data, in bytes.
pub const PROPOSAL_MAX_BLOB_BYTES: usize =
    (USABLE_BITS_PER_FIELD_ELEMENT - 1) * FIELD_ELEMENTS_PER_BLOB as usize;

/// The minimum block gas limit.
/// NOTE: Should be same with `MIN_BLOCK_GAS_LIMIT` in contracts/layer1/shasta/libs/LibConstants.sol.
pub const MIN_BLOCK_GAS_LIMIT: u64 = 15_000_000;
