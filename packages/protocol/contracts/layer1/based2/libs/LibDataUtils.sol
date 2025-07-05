// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibDataUtils
/// @notice Library for data encoding and hashing utilities
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
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Hashes a batch with its metadata
    /// @param _batchId The batch ID
    /// @param _meta The batch metadata
    /// @return The hash of the batch
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

    /// @notice Hashes a batch using evidence structure
    /// @param _evidence The batch proposal metadata evidence
    /// @return The hash of the batch
    function hashBatch(I.BatchProposeMetadataEvidence memory _evidence)
        public
        pure
        returns (bytes32)
    {
        bytes32 proposeMetaHash = keccak256(abi.encode(_evidence.proposeMeta));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, _evidence.proveMetaHash));

        return keccak256(abi.encode(_evidence.idAndBuildHash, rightHash));
    }

    /// @notice Encodes configuration and batch information into lower 128 bits
    /// @dev The encoding format:
    ///      - bits 0-7: used to store _conf.baseFeeConfig.sharingPctg
    ///      - bit 8: used to store _batch.isForcedInclusion
    /// @param _conf The configuration
    /// @param _batch The batch information
    /// @return The encoded data as bytes32
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

    /// @notice Packs batch metadata into bytes
    /// @param _meta The batch metadata to pack
    /// @return The packed metadata as bytes
    function packBatchMetadata(I.BatchMetadata memory _meta) internal pure returns (bytes memory) {
        return abi.encode(_meta);
    }
}
