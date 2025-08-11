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

    /// @notice The maximum number of transactions allowed in a block in the manifest.
    uint256 internal constant BLOCK_MAX_RAW_TRANSACTIONS = 4096 * 2;

    /// @notice The maximum number of transactions allowed in the actual L2 block.
    uint256 internal constant BLOCK_MAX_TRANSACTIONS = 4096;

    /// @notice The maximum anchor block number offset from the proposal origin block number.
    uint256 internal constant ANCHOR_MAX_OFFSET = 128;

    /// @notice The maximum number timestamp offset from the proposal origin timestamp.
    uint256 internal constant TIMESTAMP_MAX_OFFSET = 12 * 32;

    /// @notice The block gas limit.
    uint256 internal constant BLOCK_GAS_LIMIT = 100_000_000;

    /// @notice The maximum gas issuance change per block in permyriad (1/10,000).
    /// @dev E.g., 10 = 0.1 basis points = 0.001% = 10/100,000
    uint256 internal constant MAX_GAS_ISSUANCE_CHANGE_PERMYRIAD = 10;

    /// @notice The minimum gas issuance per second.
    /// @dev This ensures gas issuance never drops below a critical threshold.
    uint256 internal constant MIN_GAS_ISSUANCE_PER_SECOND = 1_000_000;

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
        /// @notice The gas issuance per second for this block. This number can be zero to indicate
        /// that the gas issuance should be the same as the previous block.
        uint32 gasIssuancePerSecond;
        /// @notice The transactions for this block.
        SignedTransaction[] transactions;
    }

    /// @notice Represents a proposal manifest
    struct ProposalManifest {
        bytes proverAuthBytes;
        BlockManifest[] blocks;
    }
}
