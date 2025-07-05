// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibDataUtils
/// @notice Library for data encoding, hashing, and utility functions in Taiko's Layer 1 protocol
/// @dev This library provides core data manipulation functions:
///      - Batch metadata hashing and encoding
///      - Function pointer abstractions for read/write operations
///      - Configuration and batch data encoding utilities
///      - Metadata packing and unpacking functions
/// @custom:security-contact security@taiko.xyz
library LibDataUtils {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Structure containing function pointers for read and write operations
    /// @dev This pattern allows libraries to interact with external contracts
    ///      without direct dependencies
    struct ReadWrite {
        // Read functions
        /// @notice Loads a batch metadata hash
        function (I.Config memory, uint256) view returns (bytes32) loadBatchMetaHash;
        /// @notice Checks if a signal has been sent
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        /// @notice Gets the blob hash for a given index
        function(uint256) view returns (bytes32) getBlobHash;
        function (I.Config memory, bytes32, uint256) view returns (bytes32 , bool)
            loadTransitionMetaHash;
        // Write functions
        /// @notice Saves a transition
        function(I.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        /// @notice Transfers fees between addresses
        function(address, address, address, uint256) transferFee;
        /// @notice Credits bond to a user
        function(address, uint256) creditBond;
        /// @notice Debits bond from a user
        function(I.Config memory, address, uint256) debitBond;
        /// @notice Syncs chain data
        function(I.Config memory, uint64, bytes32) syncChainData;
        /// @notice Saves a batch metadata hash
        function(I.Config memory, uint, bytes32) saveBatchMetaHash;
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Batch Hashing
    // -------------------------------------------------------------------------

    /// @notice Computes a deterministic hash for a batch and its metadata
    /// @dev Creates a hierarchical hash structure:
    ///      - Left hash: batchId + buildMeta hash
    ///      - Right hash: proposeMeta hash + proveMeta hash
    ///      - Final hash: keccak256(leftHash, rightHash)
    /// @param _batchId Unique identifier for the batch
    /// @param _meta Complete batch metadata containing build, propose, and prove data
    /// @return Deterministic hash representing the batch and its metadata
    function hashBatch(
        uint256 _batchId,
        I.BatchMetadata memory _meta
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 buildMetaHash = keccak256(abi.encode(_meta.buildMeta));
        bytes32 proposeMetaHash = keccak256(abi.encode(_meta.proposeMeta));
        bytes32 proveMetaHash = keccak256(abi.encode(_meta.proveMeta));

        bytes32 leftHash = keccak256(abi.encode(_batchId, buildMetaHash));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, proveMetaHash));

        return keccak256(abi.encode(leftHash, rightHash));
    }

    /// @notice Computes a batch hash using evidence structure (optimized version)
    /// @dev Alternative hashing method using pre-computed evidence data:
    ///      - Uses pre-computed idAndBuildHash instead of separate batchId and buildMeta
    ///      - Combines with proposeMeta and proveMetaHash
    ///      - More efficient when evidence is already available
    /// @param _evidence Pre-computed batch proposal metadata evidence
    /// @return Deterministic hash representing the batch
    function hashBatch(I.BatchProposeMetadataEvidence memory _evidence)
        public
        pure
        returns (bytes32)
    {
        bytes32 proposeMetaHash = keccak256(abi.encode(_evidence.proposeMeta));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, _evidence.proveMetaHash));

        return keccak256(abi.encode(_evidence.idAndBuildHash, rightHash));
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Data Encoding
    // -------------------------------------------------------------------------

    /// @notice Encodes configuration and batch information into the lower 128 bits
    /// @dev Bit-level encoding for efficient storage:
    ///      - Bits 0-7: Base fee sharing percentage (0-100)
    ///      - Bit 8: Forced inclusion flag (0 or 1)
    ///      - Bits 9-127: Reserved for future use
    /// @param _conf Protocol configuration containing base fee parameters
    /// @param _batch Batch information containing forced inclusion flag
    /// @return Encoded data as bytes32 with information packed in lower 128 bits
    function encodeExtraDataLower128Bits(
        I.Config memory _conf,
        I.Batch memory _batch
    )
        internal
        pure
        returns (bytes32)
    {
        uint128 v = _conf.baseFeeConfig.sharingPctg; // bits 0-7
        v |= _batch.isForcedInclusion ? 1 << 8 : 0; // bit 8

        return bytes32(uint256(v));
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Metadata Packing
    // -------------------------------------------------------------------------

    /// @notice Packs batch metadata into a byte array for efficient storage or transmission
    /// @dev Uses ABI encoding to serialize the complete metadata structure
    /// @param _meta Complete batch metadata containing build, propose, and prove information
    /// @return Packed metadata as bytes array suitable for storage or hashing
    function packBatchMetadata(I.BatchMetadata memory _meta) internal pure returns (bytes memory) {
        return abi.encode(_meta);
    }
}
