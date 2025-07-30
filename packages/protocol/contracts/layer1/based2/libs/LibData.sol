// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../codec/LibCodecHeaderExtraInfo.sol";

/// @title LibData
/// @notice Library for batch metadata hashing and data encoding in Taiko protocol
/// @dev Provides core data processing functions including:
///      - Hierarchical batch metadata hashing with deterministic structure
///      - Alternative batch hashing using pre-computed evidence
///      - Configuration and batch data encoding for efficient storage
///      - Bit-level encoding for base fee sharing and forced inclusion flags
/// @custom:security-contact security@taiko.xyz
library LibData {
    // -------------------------------------------------------------------------
    // Internal Functions
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
        uint64 _batchId,
        IInbox.BatchMetadata memory _meta
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

    /// @notice Computes a batch hash using ProposeBatchEvidence
    /// @dev Alternative hashing method using pre-computed evidence data:
    ///      - Uses pre-computed idAndBuildHash instead of separate batchId and buildMeta
    ///      - Combines with proposeMeta and proveMetaHash
    ///      - More efficient when evidence is already available
    /// @param _evidence Pre-computed batch proposal metadata evidence
    /// @return Deterministic hash representing the batch
    function hashBatch(IInbox.ProposeBatchEvidence memory _evidence)
        public
        pure
        returns (bytes32)
    {
        bytes32 proposeMetaHash = keccak256(abi.encode(_evidence.proposeMeta));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, _evidence.proveMetaHash));

        return keccak256(abi.encode(_evidence.leftHash, rightHash));
    }

    /// @notice  Computes a batch hash using ProveBatchInput
    /// @param _proveBatchInput The batch prove input containing metadata to validate
    function hashBatch(IInbox.ProveBatchInput memory _proveBatchInput)
        internal
        pure
        returns (bytes32)
    {
        bytes32 proveMetaHash = keccak256(abi.encode(_proveBatchInput.proveMeta));
        bytes32 rightHash = keccak256(abi.encode(_proveBatchInput.proposeMetaHash, proveMetaHash));
        return keccak256(abi.encode(_proveBatchInput.leftHash, rightHash));
    }
}
