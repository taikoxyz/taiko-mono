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
        // Manual packing without assembly for clarity and correctness
        bytes memory packed = new bytes(122);
        
        // Pack blockHash (32 bytes, offset 0)
        bytes32 blockHash = _tranMeta.blockHash;
        for (uint i = 0; i < 32; i++) {
            packed[i] = blockHash[i];
        }
        
        // Pack stateRoot (32 bytes, offset 32)
        bytes32 stateRoot = _tranMeta.stateRoot;
        for (uint i = 0; i < 32; i++) {
            packed[32 + i] = stateRoot[i];
        }
        
        // Pack prover (20 bytes, offset 64)
        bytes20 prover = bytes20(_tranMeta.prover);
        for (uint i = 0; i < 20; i++) {
            packed[64 + i] = prover[i];
        }
        
        // Pack proofTiming (1 byte, offset 84)
        packed[84] = bytes1(uint8(_tranMeta.proofTiming));
        
        // Pack createdAt (6 bytes, offset 85)
        bytes6 createdAt = bytes6(_tranMeta.createdAt);
        for (uint i = 0; i < 6; i++) {
            packed[85 + i] = createdAt[i];
        }
        
        // Pack byAssignedProver (1 byte, offset 91)
        packed[91] = _tranMeta.byAssignedProver ? bytes1(0x01) : bytes1(0x00);
        
        // Pack lastBlockId (6 bytes, offset 92)
        bytes6 lastBlockId = bytes6(_tranMeta.lastBlockId);
        for (uint i = 0; i < 6; i++) {
            packed[92 + i] = lastBlockId[i];
        }
        
        // Pack provabilityBond (12 bytes, offset 98)
        bytes12 provabilityBond = bytes12(_tranMeta.provabilityBond);
        for (uint i = 0; i < 12; i++) {
            packed[98 + i] = provabilityBond[i];
        }
        
        // Pack livenessBond (12 bytes, offset 110)
        bytes12 livenessBond = bytes12(_tranMeta.livenessBond);
        for (uint i = 0; i < 12; i++) {
            packed[110 + i] = livenessBond[i];
        }
        
        // Convert to fixed-size array
        assembly {
            encoded_ := packed
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
        // Convert fixed-size array to dynamic bytes for easier manipulation
        bytes memory data;
        assembly {
            data := _encoded
        }
        
        // Unpack blockHash (32 bytes, offset 0)
        bytes32 blockHash;
        assembly {
            blockHash := mload(add(data, 0x20))
        }
        tranMeta_.blockHash = blockHash;
        
        // Unpack stateRoot (32 bytes, offset 32)
        bytes32 stateRoot;
        assembly {
            stateRoot := mload(add(data, 0x40))
        }
        tranMeta_.stateRoot = stateRoot;
        
        // Unpack prover (20 bytes, offset 64)
        address prover;
        assembly {
            prover := mload(add(data, 0x54))
        }
        tranMeta_.prover = prover;
        
        // Unpack proofTiming (1 byte, offset 84)
        uint8 proofTiming = uint8(data[84]);
        tranMeta_.proofTiming = I.ProofTiming(proofTiming);
        
        // Unpack createdAt (6 bytes, offset 85)
        uint48 createdAt;
        assembly {
            createdAt := shr(208, mload(add(data, 0x75)))
        }
        tranMeta_.createdAt = createdAt;
        
        // Unpack byAssignedProver (1 byte, offset 91)
        tranMeta_.byAssignedProver = data[91] != 0x00;
        
        // Unpack lastBlockId (6 bytes, offset 92)
        uint48 lastBlockId;
        assembly {
            lastBlockId := shr(208, mload(add(data, 0x7c)))
        }
        tranMeta_.lastBlockId = lastBlockId;
        
        // Unpack provabilityBond (12 bytes, offset 98)
        uint96 provabilityBond;
        assembly {
            provabilityBond := shr(160, mload(add(data, 0x82)))
        }
        tranMeta_.provabilityBond = provabilityBond;
        
        // Unpack livenessBond (12 bytes, offset 110)
        uint96 livenessBond;
        assembly {
            livenessBond := shr(160, mload(add(data, 0x8e)))
        }
        tranMeta_.livenessBond = livenessBond;
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
