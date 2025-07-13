// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodec
/// @custom:security-contact security@taiko.xyz
/// @notice A library for encoding and decoding TransitionMeta structs to optimize storage and gas
/// costs.
/// @dev This library provides functions to pack and unpack arrays of TransitionMeta structs
/// into/from
/// tightly packed byte arrays. Each TransitionMeta is packed into exactly 109 bytes to minimize
/// storage costs while maintaining data integrity.
library LibCodec {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Packs an array of TransitionMeta structs into a tightly packed byte array.
    /// @dev The packed format uses exactly 109 bytes per TransitionMeta:
    /// - blockHash: 32 bytes
    /// - stateRoot: 32 bytes
    /// - prover: 20 bytes (address)
    /// - proofTiming + byAssignedProver: 1 byte (2 bits for proofTiming, 1 bit for
    /// byAssignedProver)
    /// - createdAt: 6 bytes (uint48)
    /// - lastBlockId: 6 bytes (uint48)
    /// - provabilityBond: 6 bytes (uint48)
    /// - livenessBond: 6 bytes (uint48)
    /// Total: 109 bytes per TransitionMeta
    /// @param _tranMetas Array of TransitionMeta structs to pack
    /// @return encoded_ The packed byte array
    function packTransitionMetas(I.TransitionMeta[] memory _tranMetas)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 length = _tranMetas.length;

        // Each TransitionMeta takes 109 bytes when packed
        encoded_ = new bytes(length * 109);

        uint256 offset;
        for (uint256 i; i < length; ++i) {
            I.TransitionMeta memory meta = _tranMetas[i];

            // Pack data in the order of the struct fields
            assembly {
                let ptr := add(encoded_, add(0x20, offset))

                // blockHash (32 bytes)
                mstore(ptr, mload(meta))
                ptr := add(ptr, 32)

                // stateRoot (32 bytes)
                mstore(ptr, mload(add(meta, 0x20)))
                ptr := add(ptr, 32)

                // prover (20 bytes) - store in lower 20 bytes
                mstore(ptr, shl(96, mload(add(meta, 0x40))))
                ptr := add(ptr, 20)

                // proofTiming (2 bits) + byAssignedProver (1 bit) in 1 byte
                let proofTiming := mload(add(meta, 0x60))
                let byAssignedProver := mload(add(meta, 0xa0))
                let combinedByte := or(proofTiming, shl(2, byAssignedProver))
                mstore8(ptr, combinedByte)
                ptr := add(ptr, 1)

                // createdAt (6 bytes) - store in lower 6 bytes
                let createdAt := mload(add(meta, 0x80))
                mstore(ptr, shl(208, createdAt))
                ptr := add(ptr, 6)

                // lastBlockId (6 bytes) - store in lower 6 bytes
                let lastBlockId := mload(add(meta, 0xc0))
                mstore(ptr, shl(208, lastBlockId))
                ptr := add(ptr, 6)

                // provabilityBond (6 bytes) - store in lower 6 bytes
                let provabilityBond := mload(add(meta, 0xe0))
                mstore(ptr, shl(208, provabilityBond))
                ptr := add(ptr, 6)

                // livenessBond (6 bytes) - store in lower 6 bytes
                let livenessBond := mload(add(meta, 0x100))
                mstore(ptr, shl(208, livenessBond))
            }

            offset += 109;
        }
    }

    /// @notice Unpacks a byte array back into an array of TransitionMeta structs.
    /// @dev Reverses the packing performed by packTransitionMetas. The input must be
    /// a multiple of 109 bytes, with each 109-byte segment representing one TransitionMeta.
    /// @param _encoded The packed byte array to unpack
    /// @return tranMetas_ Array of unpacked TransitionMeta structs
    function unpackTransitionMetas(bytes memory _encoded)
        internal
        pure
        returns (I.TransitionMeta[] memory tranMetas_)
    {
        require(_encoded.length % 109 == 0, InvalidDataLength());

        // Calculate length from encoded data size
        uint256 length = _encoded.length / 109;

        tranMetas_ = new I.TransitionMeta[](length);

        uint256 offset;
        for (uint256 i; i < length; ++i) {
            I.TransitionMeta memory meta;

            assembly {
                let dataOffset := add(add(_encoded, 0x20), offset)

                // blockHash (32 bytes)
                meta := mload(0x40) // allocate memory
                mstore(meta, mload(dataOffset))

                // stateRoot (32 bytes)
                mstore(add(meta, 0x20), mload(add(dataOffset, 32)))

                // prover (20 bytes) - right-aligned in 32-byte slot
                let proverData := mload(add(dataOffset, 64))
                mstore(add(meta, 0x40), shr(96, proverData))

                // proofTiming (2 bits) + byAssignedProver (1 bit) from 1 byte
                let combinedByte := byte(0, mload(add(dataOffset, 84)))
                let proofTiming := and(combinedByte, 0x03) // Extract lower 2 bits
                let byAssignedProver := and(shr(2, combinedByte), 0x01) // Extract bit 2
                mstore(add(meta, 0x60), proofTiming)
                mstore(add(meta, 0xa0), byAssignedProver)

                // createdAt (6 bytes) - stored as uint48
                let createdAtData := mload(add(dataOffset, 85))
                mstore(add(meta, 0x80), shr(208, createdAtData))

                // lastBlockId (6 bytes) - stored as uint48
                let lastBlockIdData := mload(add(dataOffset, 91))
                mstore(add(meta, 0xc0), shr(208, lastBlockIdData))

                // provabilityBond (6 bytes) - stored as uint48
                let provabilityBondData := mload(add(dataOffset, 97))
                mstore(add(meta, 0xe0), shr(208, provabilityBondData))

                // livenessBond (6 bytes) - stored as uint48
                let livenessBondData := mload(add(dataOffset, 103))
                mstore(add(meta, 0x100), shr(208, livenessBondData))

                // Update free memory pointer
                mstore(0x40, add(meta, 0x120))
            }

            tranMetas_[i] = meta;
            offset += 109;
        }
    }

    // TODO:
    function packBatchContext(I.BatchContext memory _context)
        internal
        pure
        returns (bytes memory packed_)
    {
        return abi.encode(_context);
    }

    // TODO:
    function unpackBatchContext(bytes memory _packed)
        internal
        pure
        returns (I.BatchContext memory context_)
    {
        return abi.decode(_packed, (I.BatchContext));
    }

    function packSummary(I.Summary memory _summary) internal pure returns (bytes memory encoded_) {
        return abi.encode(_summary);
    }

    function unpackSummary(bytes memory _encoded)
        internal
        pure
        returns (I.Summary memory summary_)
    {
        return abi.decode(_encoded, (I.Summary));
    }

    function packBatches(I.Batch[] memory _batches) internal pure returns (bytes memory encoded_) {
        return abi.encode(_batches);
    }

    function unpackBatches(bytes memory _encoded)
        internal
        pure
        returns (I.Batch[] memory batches_)
    {
        return abi.decode(_encoded, (I.Batch[]));
    }

    function packBatchProveInputs(I.BatchProveInput[] memory _batches)
        internal
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_batches);
    }

    function unpackBatchProveInputs(bytes memory _encoded)
        internal
        pure
        returns (I.BatchProveInput[] memory batches_)
    {
        return abi.decode(_encoded, (I.BatchProveInput[]));
    }

    function packBatchProposeMetadataEvidence(I.BatchProposeMetadataEvidence memory _evidence)
        internal
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_evidence);
    }

    function unpackBatchProposeMetadataEvidence(bytes memory _encoded)
        internal
        pure
        returns (I.BatchProposeMetadataEvidence memory evidence_)
    {
        return abi.decode(_encoded, (I.BatchProposeMetadataEvidence));
    }

    /// @notice Encodes a block structure into a single uint256 value
    /// @dev Packs block properties into a uint256 using bitwise operations
    /// @param _block The block structure to encode
    /// @return encoded_ The encoded block as a uint256
    function packBlock(I.Block memory _block) internal pure returns (uint256 encoded_) {
        encoded_ = uint256(_block.numTransactions) | (uint256(_block.timeShift) << 16)
            | (uint256(_block.anchorBlockId) << 24) | (uint256(_block.numSignals) << 72)
            | (uint256(_block.hasAnchor ? 1 : 0) << 80);
    }

    /// @notice Decodes a uint256 value into a block structure
    /// @dev Unpacks block properties from a uint256 using bitwise operations
    /// @param _encoded The encoded block as a uint256
    /// @return The decoded block structure
    function unpackBlock(uint256 _encoded) internal pure returns (I.Block memory) {
        return I.Block({
            numTransactions: uint16(_encoded),
            timeShift: uint8(_encoded >> 16),
            anchorBlockId: uint48(_encoded >> 24),
            numSignals: uint8(_encoded >> 72),
            hasAnchor: (_encoded >> 80 & 0x01) != 0
        });
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error ArrayTooLarge();
    error InvalidDataLength();
    error EmptyInput();
}
