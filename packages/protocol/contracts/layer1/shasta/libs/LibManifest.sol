// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "./LibBlobs.sol";

/// @title LibManifest
/// @custom:security-contact security@taiko.xyz
library LibManifest {
    // -------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------
    /// @notice The maximum number of blobs allowed in a proposal.
    uint256 internal constant PROPOSAL_MAX_BLOBS = 4;
    /// @notice The maximum number of bytes allowed in a proposal.
    uint256 internal constant PROPOSAL_MAX_BYTES = LibBlobs.BLOB_BYTES * PROPOSAL_MAX_BLOBS;

    /// @notice The maximum number of blocks allowed in a proposal. If we assume block time is as
    /// small as one second, 384 blocks will cover an Ethereum epoch.
    uint256 internal constant PROPOSAL_MAX_BLOCKS = 384;

    /// @notice Maximum number of transactions allowed in proposal's manifest data. This cap ensures
    /// the cost of a worst-case prover attack is bounded.
    uint256 internal constant BLOCK_MAX_RAW_TRANSACTIONS = 4096 * 2;

    /// @notice The maximum anchor block number offset from the proposal origin block number.
    uint256 internal constant ANCHOR_MAX_OFFSET = 128;

    /// @notice The minimum anchor block number offset from the proposal origin block number.
    uint256 internal constant ANCHOR_MIN_OFFSET = 2;

    /// @notice The maximum number timestamp offset from the proposal origin timestamp.
    uint256 internal constant TIMESTAMP_MAX_OFFSET = 12 * 32;

    /// @notice The maximum block gas limit change per block, in millionths (1/1,000,000).
    /// @dev For example, 10 = 10 / 1,000,000 = 0.001%.
    uint256 internal constant MAX_BLOCK_GAS_LIMIT_CHANGE_PERMYRIAD = 10;

    /// @notice The minimum block gas limit.
    /// @dev This ensures block gas limit never drops below a critical threshold.
    uint256 internal constant MIN_BLOCK_GAS_LIMIT = 15_000_000;

    // -------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------

    /// @notice Represents a signed Ethereum transaction
    /// @dev Follows EIP-2718 typed transaction format with EIP-1559 support
    struct SignedTransaction {
        uint8 txType;
        uint64 chainId;
        uint64 nonce;
        uint256 maxPriorityFeePerGas;
        uint256 maxFeePerGas;
        uint64 gasLimit;
        address to;
        uint256 value;
        bytes data;
        bytes accessList;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Represents a block manifest
    struct BlockManifest {
        /// @notice The timestamp of the block.
        uint48 timestamp;
        /// @notice The coinbase of the block.
        address coinbase;
        /// @notice The anchor block number. This field can be zero, if so, this block will use the
        /// most recent anchor in a previous block.
        uint48 anchorBlockNumber;
        /// @notice The block's gas limit.
        uint48 gasLimit;
        /// @notice The transactions for this block.
        SignedTransaction[] transactions;
    }

    /// @notice Represents a proposal manifest
    struct ProposalManifest {
        bytes proverAuthBytes;
        BlockManifest[] blocks;
    }
}
