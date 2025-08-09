// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibManifest
/// @custom:security-contact security@taiko.xyz
library LibManifest {
    // -------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------
    uint256 internal constant FIELD_ELEMENT_BYTE_SIZE = 32;

    uint256 internal constant BLOB_FIELD_ELEMENT_SIZE = 4096;

    /// @notice The maximum number of transactions allowed in a block.
    uint256 internal constant BLOB_BYTE_SIZE = BLOB_FIELD_ELEMENT_SIZE * FIELD_ELEMENT_BYTE_SIZE;
    /// @notice The maximum number of bytes allowed for a proposal slice.
    uint256 internal constant PROPOSAL_MAX_FIELD_ELEMENTS_SIZE = 6 * BLOB_FIELD_ELEMENT_SIZE;

    uint256 internal constant PROPOSAL_MAX_BLOBS = 10;
    /// @notice The maximum number of blocks allowed in a proposal. If we assume block time is as
    /// small as one second, 384 blocks will cover an Ethereum epoch.
    uint256 internal constant PROPOSAL_MAX_BLOCKS = 384;

    uint256 internal constant BLOCK_MAX_TRANSACTIONS = 4096;

    uint256 internal constant ANCHOR_BLOCK_MAX_ORIGIN_OFFSET = 128;

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

    struct ProverAuth {
        uint48 proposalId;
        address proposer;
        uint48 provingFeeGwei;
        bytes signature;
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
        ProverAuth proverAuth;
        BlockManifest[] blocks;
    }
}
