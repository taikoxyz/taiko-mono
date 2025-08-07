// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibManifest
/// @custom:security-contact security@taiko.xyz
library LibManifest {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice The maximum number of bytes allowed for a proposal slice.
    uint256 internal constant MAX_PROPOSAL_SLICE_BYTES = 10 * 1024;
    /// @notice The maximum number of blocks allowed in a proposal.
    uint256 internal constant MAX_BLOCKS_PER_PROPOSAL = 1024;
    /// @notice The maximum number of transactions allowed in a block.
    uint256 internal constant MAX_TRANSACTIONS_PER_BLOCK = 4096;

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

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
        BlockManifest[] blocks;
    }
}
