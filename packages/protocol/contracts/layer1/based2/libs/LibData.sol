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
        uint48 firstBlockId;
        unchecked {
            firstBlockId = _context.lastBlockId + 1 - uint48(_batch.encodedBlocks.length);
        }
        meta_.proveMeta = I.BatchProveMetadata({
            proposer: _batch.proposer,
            prover: _batch.prover,
            proposedAt: _blockTimestamp,
            firstBlockId: firstBlockId,
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

    function packTransitionMeta(I.TransitionMeta memory _tranMeta)
        internal
        pure
        returns (bytes[122] memory encoded_)
    {
        assembly {
            let ptr := encoded_

            // blockHash (32 bytes) at offset 0
            mstore(ptr, mload(_tranMeta))
            
            // stateRoot (32 bytes) at offset 32
            mstore(add(ptr, 32), mload(add(_tranMeta, 32)))

            // prover (20 bytes) at offset 64
            let proverValue := mload(add(_tranMeta, 64))
            mstore(add(ptr, 64), shl(96, proverValue))

            // proofTiming (1 byte) at offset 84
            let proofTimingValue := and(mload(add(_tranMeta, 96)), 0xFF)
            mstore8(add(ptr, 84), proofTimingValue)
            
            // createdAt (6 bytes) at offset 85
            let createdAtValue := and(mload(add(_tranMeta, 128)), 0xFFFFFFFFFFFF)
            mstore(add(ptr, 85), shl(208, createdAtValue))
            
            // byAssignedProver (1 byte) at offset 91
            let byAssignedProverValue := and(mload(add(_tranMeta, 160)), 0xFF)
            mstore8(add(ptr, 91), byAssignedProverValue)
            
            // lastBlockId (6 bytes) at offset 92
            let lastBlockIdValue := and(mload(add(_tranMeta, 192)), 0xFFFFFFFFFFFF)
            mstore(add(ptr, 92), shl(208, lastBlockIdValue))

            // provabilityBond (12 bytes) at offset 98
            let provabilityBondValue := and(mload(add(_tranMeta, 224)), 0xFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(add(ptr, 98), shl(160, provabilityBondValue))
            
            // livenessBond (12 bytes) at offset 110
            let livenessBondValue := and(mload(add(_tranMeta, 256)), 0xFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(add(ptr, 110), shl(160, livenessBondValue))
        }
    }

    function unpackTransitionMeta(bytes[122] memory _encoded)
        internal
        pure
        returns (I.TransitionMeta memory tranMeta_)
    {
        assembly {
            let ptr := _encoded

            // blockHash (32 bytes) at offset 0
            mstore(tranMeta_, mload(ptr))
            
            // stateRoot (32 bytes) at offset 32
            mstore(add(tranMeta_, 32), mload(add(ptr, 32)))

            // prover (20 bytes) at offset 64
            mstore(add(tranMeta_, 64), shr(96, mload(add(ptr, 64))))

            // proofTiming (1 byte) at offset 84
            let proofTimingByte := byte(0, mload(add(ptr, 84)))
            mstore(add(tranMeta_, 96), proofTimingByte)
            
            // createdAt (6 bytes) at offset 85
            let createdAtValue := shr(208, mload(add(ptr, 85)))
            mstore(add(tranMeta_, 128), createdAtValue)
            
            // byAssignedProver (1 byte) at offset 91
            let byAssignedProverByte := byte(0, mload(add(ptr, 91)))
            mstore(add(tranMeta_, 160), byAssignedProverByte)
            
            // lastBlockId (6 bytes) at offset 92
            let lastBlockIdValue := shr(208, mload(add(ptr, 92)))
            mstore(add(tranMeta_, 192), lastBlockIdValue)

            // provabilityBond (12 bytes) at offset 98
            let provabilityBondValue := shr(160, mload(add(ptr, 98)))
            mstore(add(tranMeta_, 224), provabilityBondValue)
            
            // livenessBond (12 bytes) at offset 110
            let livenessBondValue := shr(160, mload(add(ptr, 110)))
            mstore(add(tranMeta_, 256), livenessBondValue)
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
