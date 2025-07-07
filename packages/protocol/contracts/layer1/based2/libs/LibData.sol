// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

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

    /// @notice Populates batch metadata from batch and batch context data
    /// @param _blockNumber The block number in which the batch is proposed
    /// @param _blockTimestamp The timestamp of the block in which the batch is proposed
    /// @param _batch The batch being proposed
    /// @param _context The batch context data containing computed values
    /// @return meta_ The populated batch metadata
    function buildBatchMetadata(
        uint48 _blockNumber,
        uint48 _blockTimestamp,
        I.Batch calldata _batch,
        I.BatchContext memory _context
    )
        internal
        pure
        returns (I.BatchMetadata memory meta_)
    {
        // Build metadata section
        meta_.buildMeta = I.BatchBuildMetadata({
            txsHash: _context.txsHash,
            blobHashes: _context.blobHashes,
            extraData: _encodeExtraDataLower128Bits(_context.baseFeeConfig.sharingPctg, _batch),
            coinbase: _batch.coinbase,
            proposedIn: _blockNumber,
            blobCreatedIn: _batch.blobs.createdIn,
            blobByteOffset: _batch.blobs.byteOffset,
            blobByteSize: _batch.blobs.byteSize,
            gasLimit: _context.blockMaxGasLimit,
            lastBlockId: _context.lastBlockId,
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            anchorBlockIds: _batch.anchorBlockIds,
            anchorBlockHashes: _context.anchorBlockHashes,
            encodedBlocks: _batch.encodedBlocks,
            baseFeeConfig: _context.baseFeeConfig
        });

        // Propose metadata section
        meta_.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            lastBlockId: meta_.buildMeta.lastBlockId,
            lastAnchorBlockId: _context.lastAnchorBlockId
        });

        // Prove metadata section
        meta_.proveMeta = I.BatchProveMetadata({
            proposer: _batch.proposer,
            prover: _batch.prover,
            proposedAt: _blockTimestamp,
            firstBlockId: _context.lastBlockId + 1 - uint48(_batch.encodedBlocks.length),
            lastBlockId: meta_.buildMeta.lastBlockId,
            livenessBond: _context.livenessBond,
            provabilityBond: _context.provabilityBond
        });
    }

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

    /// @notice Packs a TransitionMeta struct into a fixed-size byte array
    /// @param _tranMeta The TransitionMeta struct to be packed
    /// @return encoded_ The packed byte array representation of the TransitionMeta
    function packTransitionMeta(I.TransitionMeta memory _tranMeta)
        internal
        pure
        returns (bytes[122] memory encoded_)
    {
        assembly {
            // Store blockHash (32 bytes)
            mstore(add(encoded_, 0x20), mload(add(_tranMeta, 0x20)))
            // Store stateRoot (32 bytes)
            mstore(add(encoded_, 0x40), mload(add(_tranMeta, 0x40)))
            // Store prover (20 bytes)
            mstore(add(encoded_, 0x60), mload(add(_tranMeta, 0x60)))
            // Store proofTiming (1 byte)
            mstore8(add(encoded_, 0x74), mload(add(_tranMeta, 0x80)))
            // Store createdAt (6 bytes)
            mstore(add(encoded_, 0x75), shr(0xA0, mload(add(_tranMeta, 0x81))))
            // Store byAssignedProver (1 byte)
            mstore8(add(encoded_, 0x7B), mload(add(_tranMeta, 0x87)))
            // Store lastBlockId (6 bytes)
            mstore(add(encoded_, 0x7C), shr(0xA0, mload(add(_tranMeta, 0x88))))
            // Store provabilityBond (12 bytes)
            mstore(add(encoded_, 0x82), shr(0x80, mload(add(_tranMeta, 0x8E))))
            // Store livenessBond (12 bytes)
            mstore(add(encoded_, 0x8E), shr(0x80, mload(add(_tranMeta, 0x9A))))
        }
    }

    /// @notice Unpacks a fixed-size byte array into a TransitionMeta struct
    /// @param _encoded The packed byte array representation of the TransitionMeta
    /// @return tranMeta_ The unpacked TransitionMeta struct
    function unpackTransitionMeta(bytes[122] memory _encoded)
        internal
        pure
        returns (I.TransitionMeta memory tranMeta_)
    {
        assembly {
            // Load blockHash (32 bytes)
            mstore(add(tranMeta_, 0x20), mload(add(_encoded, 0x20)))
            // Load stateRoot (32 bytes)
            mstore(add(tranMeta_, 0x40), mload(add(_encoded, 0x40)))
            // Load prover (20 bytes)
            mstore(add(tranMeta_, 0x60), mload(add(_encoded, 0x60)))
            // Load proofTiming (1 byte)
            mstore(add(tranMeta_, 0x80), mload(add(_encoded, 0x74)))
            // Load createdAt (6 bytes)
            mstore(add(tranMeta_, 0x81), shl(0xA0, mload(add(_encoded, 0x75))))
            // Load byAssignedProver (1 byte)
            mstore(add(tranMeta_, 0x87), mload(add(_encoded, 0x7B)))
            // Load lastBlockId (6 bytes)
            mstore(add(tranMeta_, 0x88), shl(0xA0, mload(add(_encoded, 0x7C))))
            // Load provabilityBond (12 bytes)
            mstore(add(tranMeta_, 0x8E), shl(0x80, mload(add(_encoded, 0x82))))
            // Load livenessBond (12 bytes)
            mstore(add(tranMeta_, 0x9A), shl(0x80, mload(add(_encoded, 0x8E))))
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Encodes configuration and batch information into the lower 128 bits
    /// @dev Bit-level encoding for efficient storage:
    ///      - Bits 0-7: Base fee sharing percentage (0-100)
    ///      - Bit 8: Forced inclusion flag (0 or 1)
    ///      - Bits 9-127: Reserved for future use
    /// @param _baseFeeSharingPctg Base fee sharing percentage (0-100)
    /// @param _batch Batch information containing forced inclusion flag
    /// @return Encoded data as bytes32 with information packed in lower 128 bits
    function _encodeExtraDataLower128Bits(
        uint8 _baseFeeSharingPctg,
        I.Batch memory _batch
    )
        private
        pure
        returns (bytes32)
    {
        uint128 v = _baseFeeSharingPctg; // bits 0-7
        v |= _batch.isForcedInclusion ? 1 << 8 : 0; // bit 8

        return bytes32(uint256(v));
    }
}
