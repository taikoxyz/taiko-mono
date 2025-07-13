// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodec
/// @notice Library for encoding and decoding protocol data structures to optimize storage and gas
/// costs
/// @dev Provides functions to pack and unpack various protocol data structures into tightly packed
///      byte arrays. The packing is designed to minimize storage costs while maintaining data
/// integrity.
///      All pack/unpack operations use assembly for gas optimization.
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Packs an array of TransitionMeta structs into a tightly packed byte array.
    /// @dev Packed format (109 bytes per TransitionMeta):
    /// | Field               | Bytes | Offset | Type         |
    /// |---------------------|-------|--------|--------------|
    /// | blockHash           | 32    | 0      | bytes32      |
    /// | stateRoot           | 32    | 32     | bytes32      |
    /// | prover              | 20    | 64     | address      |
    /// | timing+byAssigned   | 1     | 84     | uint8 packed |
    /// | createdAt           | 6     | 85     | uint48       |
    /// | lastBlockId         | 6     | 91     | uint48       |
    /// | provabilityBond     | 6     | 97     | uint48       |
    /// | livenessBond        | 6     | 103    | uint48       |
    /// @param _transitionMetas Array of TransitionMeta structs to pack
    /// @return encoded_ The packed byte array
    function packTransitionMetas(I.TransitionMeta[] memory _transitionMetas)
        internal
        pure
        returns (bytes memory encoded_)
    {
        unchecked {
            uint256 length = _transitionMetas.length;

            // Each TransitionMeta takes 109 bytes when packed
            encoded_ = new bytes(length * 109);

            uint256 offset;
            for (uint256 i; i < length; ++i) {
                I.TransitionMeta memory metadata = _transitionMetas[i];

                assembly {
                    let ptr := add(add(encoded_, 0x20), offset)

                    // Pack first 64 bytes (blockHash + stateRoot) directly
                    mstore(ptr, mload(metadata))
                    mstore(add(ptr, 32), mload(add(metadata, 0x20)))

                    // Pack prover (20 bytes) - shift left to align
                    mstore(add(ptr, 64), shl(96, mload(add(metadata, 0x40))))

                    // Pack timing data and remaining fields in one go
                    let proofTiming := mload(add(metadata, 0x60))
                    let byAssignedProver := mload(add(metadata, 0xa0))
                    let combinedByte := or(proofTiming, shl(2, byAssignedProver))

                    // Store combined byte
                    mstore8(add(ptr, 84), combinedByte)

                    // Pack remaining uint48 fields efficiently
                    mstore(add(ptr, 85), shl(208, mload(add(metadata, 0x80))))
                    mstore(add(ptr, 91), shl(208, mload(add(metadata, 0xc0))))
                    mstore(add(ptr, 97), shl(208, mload(add(metadata, 0xe0))))
                    mstore(add(ptr, 103), shl(208, mload(add(metadata, 0x100))))
                }

                offset += 109;
            }
        }
    }

    /// @notice Unpacks a byte array back into an array of TransitionMeta structs.
    /// @dev Reverses the packing performed by packTransitionMetas. Input must be
    /// a multiple of 109 bytes. See packTransitionMetas for data layout.
    /// @param _encoded The packed byte array to unpack
    /// @return transitionMetas_ Array of unpacked TransitionMeta structs
    function unpackTransitionMetas(bytes memory _encoded)
        internal
        pure
        returns (I.TransitionMeta[] memory transitionMetas_)
    {
        require(_encoded.length % 109 == 0, InvalidDataLength());

        unchecked {
            // Calculate length from encoded data size
            uint256 length = _encoded.length / 109;

            transitionMetas_ = new I.TransitionMeta[](length);

            assembly {
                let dataPtr := add(_encoded, 0x20)
                let arrayPtr := add(transitionMetas_, 0x20)

                for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                    let dataOffset := add(dataPtr, mul(i, 109))

                    // Allocate memory for meta
                    let meta := mload(0x40)
                    mstore(0x40, add(meta, 0x120))

                    // Read and store blockHash and stateRoot in one operation
                    let data1 := mload(dataOffset)
                    let data2 := mload(add(dataOffset, 32))
                    mstore(meta, data1)
                    mstore(add(meta, 0x20), data2)

                    // Read next 32 bytes containing prover and more
                    let data3 := mload(add(dataOffset, 64))
                    mstore(add(meta, 0x40), shr(96, data3))

                    // Read combined byte at offset 84
                    let combinedByte := byte(0, mload(add(dataOffset, 84)))
                    mstore(add(meta, 0x60), and(combinedByte, 0x03))
                    mstore(add(meta, 0xa0), and(shr(2, combinedByte), 0x01))

                    // Read remaining fields more efficiently
                    let data4 := mload(add(dataOffset, 85))
                    mstore(add(meta, 0x80), shr(208, data4))

                    let data5 := mload(add(dataOffset, 91))
                    mstore(add(meta, 0xc0), shr(208, data5))

                    let data6 := mload(add(dataOffset, 97))
                    mstore(add(meta, 0xe0), shr(208, data6))
                    mstore(add(meta, 0x100), shr(208, mload(add(dataOffset, 103))))

                    // Store meta in array
                    mstore(add(arrayPtr, mul(i, 0x20)), meta)
                }
            }
        }
    }

    /// @notice Packs a BatchContext struct into a tightly packed byte array.
    /// @dev Packed format (85 bytes fixed + dynamic arrays):
    /// | Field               | Bytes | Offset | Type    |
    /// |---------------------|-------|--------|---------|
    /// | prover              | 20    | 0      | address |
    /// | txsHash             | 32    | 20     | bytes32 |
    /// | lastAnchorBlockId   | 6     | 52     | uint48  |
    /// | lastBlockId         | 6     | 58     | uint48  |
    /// | blobsCreatedIn      | 6     | 64     | uint48  |
    /// | blockMaxGasLimit    | 4     | 70     | uint32  |
    /// | livenessBond        | 6     | 74     | uint48  |
    /// | provabilityBond     | 6     | 80     | uint48  |
    /// | baseFeeSharingPctg  | 1     | 86     | uint8   |
    /// | anchorBlockHashes   | var   | 87     | dynamic |
    /// | blobHashes          | var   | var    | dynamic |
    /// @param _context The BatchContext struct to pack
    /// @return packed_ The packed byte array
    function packBatchContext(I.BatchContext memory _context)
        internal
        pure
        returns (bytes memory packed_)
    {
        unchecked {
            uint256 anchorHashesLen = _context.anchorBlockHashes.length;
            uint256 blobHashesLen = _context.blobHashes.length;

            require(anchorHashesLen <= type(uint8).max, ArrayTooLarge());
            require(blobHashesLen <= type(uint8).max, ArrayTooLarge());

            // Calculate total size: 85 fixed bytes + 1 byte for each array length
            // + 32 bytes per hash in each array
            uint256 totalSize = 85 + 1 + 1 + (anchorHashesLen * 32) + (blobHashesLen * 32);
            packed_ = new bytes(totalSize);

            assembly {
                let ptr := add(packed_, 0x20)

                // Pack prover (20 bytes) aligned left
                mstore(ptr, shl(96, mload(_context)))

                // Pack txsHash (32 bytes) directly
                mstore(add(ptr, 20), mload(add(_context, 0x20)))

                // Pack multiple uint48 fields efficiently
                mstore(add(ptr, 52), shl(208, mload(add(_context, 0x40)))) // lastAnchorBlockId
                mstore(add(ptr, 58), shl(208, mload(add(_context, 0x60)))) // lastBlockId
                mstore(add(ptr, 64), shl(208, mload(add(_context, 0x80)))) // blobsCreatedIn

                // Pack uint32 and remaining uint48s
                mstore(add(ptr, 70), shl(224, mload(add(_context, 0xa0)))) // blockMaxGasLimit
                mstore(add(ptr, 74), shl(208, mload(add(_context, 0xc0)))) // livenessBond
                mstore(add(ptr, 80), shl(208, mload(add(_context, 0xe0)))) // provabilityBond

                // Pack uint8
                mstore8(add(ptr, 86), mload(add(_context, 0x100)))

                // Update pointer for dynamic arrays
                ptr := add(ptr, 87)

                // Pack anchorBlockHashes array
                mstore8(ptr, anchorHashesLen)
                ptr := add(ptr, 1)

                let anchorArray := mload(add(_context, 0x120))
                let anchorDataPtr := add(anchorArray, 0x20)
                for { let i := 0 } lt(i, anchorHashesLen) { i := add(i, 1) } {
                    mstore(ptr, mload(anchorDataPtr))
                    ptr := add(ptr, 32)
                    anchorDataPtr := add(anchorDataPtr, 32)
                }

                // Pack blobHashes array
                mstore8(ptr, blobHashesLen)
                ptr := add(ptr, 1)

                let blobArray := mload(add(_context, 0x140))
                let blobDataPtr := add(blobArray, 0x20)
                for { let i := 0 } lt(i, blobHashesLen) { i := add(i, 1) } {
                    mstore(ptr, mload(blobDataPtr))
                    ptr := add(ptr, 32)
                    blobDataPtr := add(blobDataPtr, 32)
                }
            }
        }
    }

    /// @notice Unpacks a byte array back into a BatchContext struct.
    /// @dev Reverses the packing performed by packBatchContext. Input must have
    /// at least 87 bytes (85 fixed + 2 array length bytes). See packBatchContext for data layout.
    /// @param _packed The packed byte array to unpack
    /// @return context_ The unpacked BatchContext struct
    function unpackBatchContext(bytes memory _packed)
        internal
        pure
        returns (I.BatchContext memory context_)
    {
        require(_packed.length >= 87, InvalidDataLength()); // 85 fixed + 2 lengths (1 byte each)

        unchecked {
            uint256 offset;

            // Extract fixed-size fields
            assembly {
                let dataPtr := add(_packed, 0x20)

                // prover (20 bytes) - extract from packed data
                let prover := shr(96, mload(add(dataPtr, offset)))
                offset := add(offset, 20)

                // txsHash (32 bytes)
                let txsHash := mload(add(dataPtr, offset))
                offset := add(offset, 32)

                // lastAnchorBlockId (6 bytes) - stored as uint48
                let lastAnchorBlockId := shr(208, mload(add(dataPtr, offset)))
                offset := add(offset, 6)

                // lastBlockId (6 bytes) - stored as uint48
                let lastBlockId := shr(208, mload(add(dataPtr, offset)))
                offset := add(offset, 6)

                // blobsCreatedIn (6 bytes) - stored as uint48
                let blobsCreatedIn := shr(208, mload(add(dataPtr, offset)))
                offset := add(offset, 6)

                // blockMaxGasLimit (4 bytes) - stored as uint32
                let blockMaxGasLimit := shr(224, mload(add(dataPtr, offset)))
                offset := add(offset, 4)

                // livenessBond (6 bytes) - stored as uint48
                let livenessBond := shr(208, mload(add(dataPtr, offset)))
                offset := add(offset, 6)

                // provabilityBond (6 bytes) - stored as uint48
                let provabilityBond := shr(208, mload(add(dataPtr, offset)))
                offset := add(offset, 6)

                // baseFeeSharingPctg (1 byte) - stored as uint8
                let baseFeeSharingPctg := byte(0, mload(add(dataPtr, offset)))
                offset := add(offset, 1)

                // Store fixed fields in context_ struct
                context_ := mload(0x40)
                mstore(0x40, add(context_, 0x160)) // Update free memory pointer

                mstore(context_, prover)
                mstore(add(context_, 0x20), txsHash)
                mstore(add(context_, 0x40), lastAnchorBlockId)
                mstore(add(context_, 0x60), lastBlockId)
                mstore(add(context_, 0x80), blobsCreatedIn)
                mstore(add(context_, 0xa0), blockMaxGasLimit)
                mstore(add(context_, 0xc0), livenessBond)
                mstore(add(context_, 0xe0), provabilityBond)
                mstore(add(context_, 0x100), baseFeeSharingPctg)
            }

            // Extract dynamic arrays
            uint256 anchorHashesLen;
            uint256 blobHashesLen;

            assembly {
                let dataPtr := add(_packed, 0x20)

                // anchorBlockHashes length (1 byte)
                anchorHashesLen := shr(248, mload(add(dataPtr, offset)))
                offset := add(offset, 1)
            }

            // Allocate and populate anchorBlockHashes array
            bytes32[] memory anchorHashes = new bytes32[](anchorHashesLen);
            assembly {
                let dataPtr := add(_packed, 0x20)
                let anchorArrayData := add(anchorHashes, 0x20)

                for { let i := 0 } lt(i, anchorHashesLen) { i := add(i, 1) } {
                    mstore(add(anchorArrayData, mul(i, 0x20)), mload(add(dataPtr, offset)))
                    offset := add(offset, 32)
                }
            }

            assembly {
                let dataPtr := add(_packed, 0x20)

                // blobHashes length (1 byte)
                blobHashesLen := shr(248, mload(add(dataPtr, offset)))
                offset := add(offset, 1)
            }

            // Allocate and populate blobHashes array
            bytes32[] memory blobHashes = new bytes32[](blobHashesLen);
            assembly {
                let dataPtr := add(_packed, 0x20)
                let blobArrayData := add(blobHashes, 0x20)

                for { let i := 0 } lt(i, blobHashesLen) { i := add(i, 1) } {
                    mstore(add(blobArrayData, mul(i, 0x20)), mload(add(dataPtr, offset)))
                    offset := add(offset, 32)
                }
            }

            // Store array references in context_
            assembly {
                mstore(add(context_, 0x120), anchorHashes)
                mstore(add(context_, 0x140), blobHashes)
            }
        }
    }

    /// @notice Packs a Summary struct into a tightly packed byte array.
    /// @dev Packed format (98 bytes total):
    /// | Field                  | Bytes | Offset | Type    |
    /// |------------------------|-------|--------|---------|
    /// | nextBatchId            | 6     | 0      | uint48  |
    /// | lastSyncedBlockId      | 6     | 6      | uint48  |
    /// | lastSyncedAt           | 6     | 12     | uint48  |
    /// | lastVerifiedBatchId    | 6     | 18     | uint48  |
    /// | gasIssuanceUpdatedAt   | 6     | 24     | uint48  |
    /// | gasIssuancePerSecond   | 4     | 30     | uint32  |
    /// | lastVerifiedBlockHash  | 32    | 34     | bytes32 |
    /// | lastBatchMetaHash      | 32    | 66     | bytes32 |
    /// @param _summary The Summary struct to pack
    /// @return encoded_ The packed byte array (98 bytes)
    function packSummary(I.Summary memory _summary) internal pure returns (bytes memory encoded_) {
        // Using abi.encodePacked for simplicity as it's already optimized for this use case
        encoded_ = abi.encodePacked(
            _summary.nextBatchId,
            _summary.lastSyncedBlockId,
            _summary.lastSyncedAt,
            _summary.lastVerifiedBatchId,
            _summary.gasIssuanceUpdatedAt,
            _summary.gasIssuancePerSecond,
            _summary.lastVerifiedBlockHash,
            _summary.lastBatchMetaHash
        );
    }

    /// @notice Unpacks a byte array back into a Summary struct.
    /// @dev Reverses the packing performed by packSummary. Input must be exactly
    /// 98 bytes. See packSummary for data layout.
    /// @param _encoded The packed byte array to unpack (must be 98 bytes)
    /// @return summary_ The unpacked Summary struct
    function unpackSummary(bytes memory _encoded)
        internal
        pure
        returns (I.Summary memory summary_)
    {
        require(_encoded.length == 98, InvalidDataLength());

        unchecked {
            assembly {
                let dataPtr := add(_encoded, 0x20)

                // Allocate memory for summary_
                summary_ := mload(0x40)
                mstore(0x40, add(summary_, 0x100))

                // Read and extract first 6 fields more efficiently
                let data1 := mload(dataPtr)
                mstore(summary_, shr(208, data1))

                let data2 := mload(add(dataPtr, 6))
                mstore(add(summary_, 0x20), shr(208, data2))

                let data3 := mload(add(dataPtr, 12))
                mstore(add(summary_, 0x40), shr(208, data3))

                let data4 := mload(add(dataPtr, 18))
                mstore(add(summary_, 0x60), shr(208, data4))

                let data5 := mload(add(dataPtr, 24))
                mstore(add(summary_, 0x80), shr(208, data5))

                let data6 := mload(add(dataPtr, 30))
                mstore(add(summary_, 0xa0), shr(224, data6))

                // Read hashes directly
                mstore(add(summary_, 0xc0), mload(add(dataPtr, 34)))
                mstore(add(summary_, 0xe0), mload(add(dataPtr, 66)))
            }
        }
    }

    /// @notice Packs an array of Batch structs into a tightly packed byte array.
    /// @dev Packed format (variable size per batch):
    /// Array header: 1 byte (length)
    /// Per batch:
    /// | Field               | Bytes | Type    | Notes                     |
    /// |---------------------|-------|---------|---------------------------|
    /// | proposer            | 20    | address | Fixed                     |
    /// | coinbase            | 20    | address | Fixed                     |
    /// | timestamp+forced    | 7     | packed  | 48 bits + 1 bit           |
    /// | gasIssuancePerSec   | 4     | uint32  | Fixed                     |
    /// | proverAuth          | var   | bytes   | 1 byte len + data         |
    /// | signalSlots         | var   | array   | 1 byte len + 32*count     |
    /// | anchorBlockIds      | var   | array   | 1 byte len + 6*count      |
    /// | blocks              | var   | array   | 1 byte len + 10*count     |
    /// | blobs               | var   | struct  | Fixed header + hashes     |
    /// @param _batches Array of Batch structs to pack
    /// @return encoded_ The packed byte array
    function packBatches(I.Batch[] memory _batches) internal pure returns (bytes memory encoded_) {
        unchecked {
            uint256 length = _batches.length;
            require(length <= type(uint8).max, ArrayTooLarge());

            // Pre-calculate total size to minimize memory allocations
            uint256 totalSize = 1; // Array length byte

            for (uint256 i; i < length; ++i) {
                I.Batch memory batch = _batches[i];

                // Calculate size for each batch component
                totalSize += 51; // Fixed fields (20+20+7+4)
                totalSize += 1 + batch.proverAuth.length; // proverAuth with length prefix
                totalSize += 1 + (batch.signalSlots.length * 32); // signalSlots with length prefix
                totalSize += 1 + (batch.anchorBlockIds.length * 6); // anchorBlockIds with length
                    // prefix
                totalSize += 1 + (batch.blocks.length * 10); // blocks with length prefix (each
                    // block is 10 bytes packed)
                totalSize += 17; // blobs fixed part (1+1+4+4+6+1 = 17 bytes)
                totalSize += (batch.blobs.hashes.length * 32); // blob hashes
            }

            encoded_ = new bytes(totalSize);

            assembly {
                let ptr := add(encoded_, 0x20)

                // Store array length (1 byte)
                mstore(ptr, shl(248, length))
                ptr := add(ptr, 1)

                // Pack each batch
                for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                    let batch := mload(add(_batches, mul(add(i, 1), 0x20)))

                    // Pack fixed fields efficiently
                    // proposer (20 bytes) - left-aligned
                    mstore(ptr, shl(96, mload(batch)))
                    // coinbase (20 bytes) - left-aligned
                    mstore(add(ptr, 20), shl(96, mload(add(batch, 0x20))))

                    // Pack timestamp (48 bits) + forced flag (1 bit) in 7 bytes
                    let blockTimestamp := mload(add(batch, 0x40))
                    let isForcedInclusion := mload(add(batch, 0x80))
                    let combined := or(blockTimestamp, shl(48, isForcedInclusion))
                    mstore(add(ptr, 40), shl(200, combined))

                    // gasIssuancePerSecond (4 bytes)
                    mstore(add(ptr, 47), shl(224, mload(add(batch, 0x60))))

                    ptr := add(ptr, 51)

                    // proverAuth - get bytes array
                    let proverAuth := mload(add(batch, 0xa0))
                    let proverAuthLen := mload(proverAuth)

                    // Store proverAuth length (1 byte)
                    mstore(ptr, shl(248, proverAuthLen))
                    ptr := add(ptr, 1)

                    // Copy proverAuth data efficiently
                    let proverAuthData := add(proverAuth, 0x20)
                    let remaining := proverAuthLen

                    // Copy in 32-byte chunks when possible
                    for { } gt(remaining, 31) { } {
                        mstore(ptr, mload(proverAuthData))
                        ptr := add(ptr, 32)
                        proverAuthData := add(proverAuthData, 32)
                        remaining := sub(remaining, 32)
                    }

                    // Handle remaining bytes
                    if gt(remaining, 0) {
                        // Create mask for partial word
                        let shift := mul(sub(32, remaining), 8)
                        let mask := sub(shl(mul(remaining, 8), 1), 1)
                        let data := and(mload(proverAuthData), shl(shift, mask))
                        mstore(ptr, data)
                        ptr := add(ptr, remaining)
                    }

                    // signalSlots array
                    let signalSlots := mload(add(batch, 0xc0))
                    let signalSlotsLen := mload(signalSlots)

                    // Store signalSlots length (1 byte)
                    mstore(ptr, shl(248, signalSlotsLen))
                    ptr := add(ptr, 1)

                    // Copy signalSlots data efficiently
                    let signalDataPtr := add(signalSlots, 0x20)
                    for { let j := 0 } lt(j, signalSlotsLen) { j := add(j, 1) } {
                        mstore(ptr, mload(signalDataPtr))
                        ptr := add(ptr, 32)
                        signalDataPtr := add(signalDataPtr, 32)
                    }

                    // anchorBlockIds array
                    let anchorBlockIds := mload(add(batch, 0xe0))
                    let anchorBlockIdsLen := mload(anchorBlockIds)

                    // Store anchorBlockIds length (1 byte)
                    mstore(ptr, shl(248, anchorBlockIdsLen))
                    ptr := add(ptr, 1)

                    // Copy anchorBlockIds data efficiently (6 bytes each)
                    let anchorDataPtr := add(anchorBlockIds, 0x20)
                    for { let j := 0 } lt(j, anchorBlockIdsLen) { j := add(j, 1) } {
                        mstore(ptr, shl(208, mload(anchorDataPtr)))
                        ptr := add(ptr, 6)
                        anchorDataPtr := add(anchorDataPtr, 32)
                    }

                    // blocks array
                    let blocks := mload(add(batch, 0x100))
                    let blocksLen := mload(blocks)

                    // Store blocks length (1 byte)
                    mstore(ptr, shl(248, blocksLen))
                    ptr := add(ptr, 1)

                    // Pack each block (10 bytes total)
                    for { let j := 0 } lt(j, blocksLen) { j := add(j, 1) } {
                        let blockPtr := add(blocks, mul(add(j, 1), 0x20))
                        let blockData := mload(blockPtr)

                        // Use the existing packBlock function logic
                        let numTransactions := and(mload(blockData), 0xFFFF)
                        let timeShift := and(mload(add(blockData, 0x20)), 0xFF)
                        let anchorBlockId := and(mload(add(blockData, 0x40)), 0xFFFFFFFFFFFF)
                        let numSignals := and(mload(add(blockData, 0x60)), 0xFF)
                        let hasAnchor := mload(add(blockData, 0x80))

                        let encoded := or(numTransactions, shl(16, timeShift))
                        encoded := or(encoded, shl(24, anchorBlockId))
                        encoded := or(encoded, shl(72, numSignals))
                        encoded := or(encoded, shl(80, hasAnchor))

                        // Store 10 bytes (80 bits) of the encoded block
                        mstore(ptr, shl(176, encoded))
                        ptr := add(ptr, 10)
                    }

                    // blobs structure (fixed size fields)
                    let blobs := mload(add(batch, 0x120))

                    // firstBlobIndex (1 byte)
                    mstore8(ptr, mload(add(blobs, 0x20)))
                    ptr := add(ptr, 1)

                    // numBlobs (1 byte)
                    mstore8(ptr, mload(add(blobs, 0x40)))
                    ptr := add(ptr, 1)

                    // byteOffset (4 bytes)
                    mstore(ptr, shl(224, mload(add(blobs, 0x60))))
                    ptr := add(ptr, 4)

                    // byteSize (4 bytes)
                    mstore(ptr, shl(224, mload(add(blobs, 0x80))))
                    ptr := add(ptr, 4)

                    // createdIn (6 bytes)
                    mstore(ptr, shl(208, mload(add(blobs, 0xa0))))
                    ptr := add(ptr, 6)

                    // hashes array
                    let hashes := mload(blobs)
                    let hashesLen := mload(hashes)

                    // Store hashes length (1 byte)
                    mstore(ptr, shl(248, hashesLen))
                    ptr := add(ptr, 1)

                    // Copy hashes data efficiently
                    let hashDataPtr := add(hashes, 0x20)
                    for { let j := 0 } lt(j, hashesLen) { j := add(j, 1) } {
                        mstore(ptr, mload(hashDataPtr))
                        ptr := add(ptr, 32)
                        hashDataPtr := add(hashDataPtr, 32)
                    }
                }
            }
        }
    }

    /// @notice Unpacks a byte array back into an array of Batch structs.
    /// @dev Reverses the packing performed by packBatches. Input must have
    /// at least 1 byte for array length. See packBatches for data layout.
    /// Note: This function only unpacks essential fields for gas efficiency.
    /// @param _encoded The packed byte array to unpack
    /// @return batches_ Array of unpacked Batch structs (with simplified data)
    function unpackBatches(bytes memory _encoded)
        internal
        pure
        returns (I.Batch[] memory batches_)
    {
        require(_encoded.length >= 1, InvalidDataLength());

        unchecked {
            uint256 offset;
            uint256 length;

            assembly {
                let dataPtr := add(_encoded, 0x20)
                length := shr(248, mload(dataPtr))
                offset := 1
            }

            batches_ = new I.Batch[](length);

            for (uint256 i; i < length; ++i) {
                I.Batch memory batch;

                assembly {
                    let dataPtr := add(_encoded, 0x20)
                    let ptr := add(dataPtr, offset)

                    // Allocate memory for batch
                    batch := mload(0x40)
                    mstore(0x40, add(batch, 0x140))

                    // proposer (20 bytes)
                    mstore(batch, shr(96, mload(ptr)))
                    ptr := add(ptr, 20)

                    // coinbase (20 bytes)
                    mstore(add(batch, 0x20), shr(96, mload(ptr)))
                    ptr := add(ptr, 20)

                    // lastBlockTimestamp (48 bits) + isForcedInclusion (1 bit) from 7 bytes
                    let combined := shr(200, mload(ptr))
                    let blockTimestamp := and(combined, 0xFFFFFFFFFFFF) // Extract lower 48 bits
                    let isForcedInclusion := shr(48, combined) // Extract bit 48
                    mstore(add(batch, 0x40), blockTimestamp)
                    mstore(add(batch, 0x80), isForcedInclusion)
                    ptr := add(ptr, 7)

                    // gasIssuancePerSecond (4 bytes)
                    mstore(add(batch, 0x60), shr(224, mload(ptr)))
                    ptr := add(ptr, 4)

                    offset := sub(ptr, dataPtr)
                }

                // Extract proverAuth
                uint256 proverAuthLen;
                assembly {
                    let dataPtr := add(_encoded, 0x20)
                    let ptr := add(dataPtr, offset)
                    proverAuthLen := shr(248, mload(ptr))
                    offset := add(offset, 1)
                }

                bytes memory proverAuth = new bytes(proverAuthLen);
                assembly {
                    let dataPtr := add(_encoded, 0x20)
                    let src := add(dataPtr, offset)
                    let dest := add(proverAuth, 0x20)

                    let remaining := proverAuthLen
                    for { } gt(remaining, 0) { } {
                        let chunk := mload(src)
                        mstore(dest, chunk)
                        let copySize := 32
                        if lt(remaining, 32) { copySize := remaining }
                        src := add(src, 32)
                        dest := add(dest, 32)
                        remaining := sub(remaining, copySize)
                    }

                    offset := add(offset, proverAuthLen)
                    mstore(add(batch, 0xa0), proverAuth)
                }

                // Extract remaining arrays in simplified form for space efficiency
                assembly {
                    let dataPtr := add(_encoded, 0x20)
                    let ptr := add(dataPtr, offset)

                    // Skip signalSlots
                    let signalSlotsLen := shr(248, mload(ptr))
                    ptr := add(ptr, 1)
                    ptr := add(ptr, mul(signalSlotsLen, 32))

                    // Skip anchorBlockIds
                    let anchorBlockIdsLen := shr(248, mload(ptr))
                    ptr := add(ptr, 1)
                    ptr := add(ptr, mul(anchorBlockIdsLen, 6))

                    // Skip blocks
                    let blocksLen := shr(248, mload(ptr))
                    ptr := add(ptr, 1)
                    ptr := add(ptr, mul(blocksLen, 10))

                    // Extract blobs metadata
                    let blobs := mload(0x40)
                    mstore(0x40, add(blobs, 0xc0))

                    // firstBlobIndex (1 byte)
                    mstore(add(blobs, 0x20), byte(0, mload(ptr)))
                    ptr := add(ptr, 1)

                    // numBlobs (1 byte)
                    mstore(add(blobs, 0x40), byte(0, mload(ptr)))
                    ptr := add(ptr, 1)

                    // byteOffset (4 bytes)
                    mstore(add(blobs, 0x60), shr(224, mload(ptr)))
                    ptr := add(ptr, 4)

                    // byteSize (4 bytes)
                    mstore(add(blobs, 0x80), shr(224, mload(ptr)))
                    ptr := add(ptr, 4)

                    // createdIn (6 bytes)
                    mstore(add(blobs, 0xa0), shr(208, mload(ptr)))
                    ptr := add(ptr, 6)

                    // Skip blob hashes
                    let hashesLen := shr(248, mload(ptr))
                    ptr := add(ptr, 1)
                    ptr := add(ptr, mul(hashesLen, 32))

                    // Create empty arrays for all complex fields
                    let emptyArray := mload(0x40)
                    mstore(emptyArray, 0)
                    mstore(0x40, add(emptyArray, 0x20))

                    mstore(blobs, emptyArray) // empty hashes
                    mstore(add(batch, 0xc0), emptyArray) // signalSlots
                    mstore(add(batch, 0xe0), emptyArray) // anchorBlockIds
                    mstore(add(batch, 0x100), emptyArray) // blocks
                    mstore(add(batch, 0x120), blobs)

                    offset := sub(ptr, dataPtr)
                }

                batches_[i] = batch;
            }
        }
    }

    /// @notice Packs an array of BatchProveInput structs into a tightly packed byte array.
    /// @dev Packed format (354 bytes per input):
    /// Array header: 1 byte (length)
    /// Per BatchProveInput:
    /// | Section        | Bytes | Content                           |
    /// |----------------|-------|-----------------------------------|
    /// | idAndBuildHash | 32    | bytes32                           |
    /// | proposeMetaHash| 32    | bytes32                           |
    /// | proveMeta      | 140   | 70 bytes data + 70 bytes padding  |
    /// | tran           | 150   | 102 bytes data + 48 bytes padding |
    /// @param _batches Array of BatchProveInput structs to pack
    /// @return encoded_ The packed byte array
    function packBatchProveInputs(I.BatchProveInput[] memory _batches)
        internal
        pure
        returns (bytes memory encoded_)
    {
        unchecked {
            uint256 length = _batches.length;
            require(length <= type(uint8).max, ArrayTooLarge());

            encoded_ = new bytes(1 + (length * 354));

            assembly {
                let ptr := add(encoded_, 0x20)

                // Store array length
                mstore8(ptr, length)
                ptr := add(ptr, 1)

                for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                    let input := mload(add(_batches, mul(add(i, 1), 0x20)))

                    // Pack hashes directly (64 bytes)
                    mstore(ptr, mload(input))
                    mstore(add(ptr, 32), mload(add(input, 0x20)))
                    ptr := add(ptr, 64)

                    // Pack proveMeta struct efficiently
                    let proveMeta := mload(add(input, 0x40))

                    // Pack addresses (40 bytes)
                    mstore(ptr, shl(96, mload(proveMeta)))
                    mstore(add(ptr, 20), shl(96, mload(add(proveMeta, 0x20))))

                    // Pack uint48 fields (30 bytes total)
                    mstore(add(ptr, 40), shl(208, mload(add(proveMeta, 0x40)))) // proposedAt
                    mstore(add(ptr, 46), shl(208, mload(add(proveMeta, 0x60)))) // firstBlockId
                    mstore(add(ptr, 52), shl(208, mload(add(proveMeta, 0x80)))) // lastBlockId
                    mstore(add(ptr, 58), shl(208, mload(add(proveMeta, 0xa0)))) // livenessBond
                    mstore(add(ptr, 64), shl(208, mload(add(proveMeta, 0xc0)))) // provabilityBond

                    ptr := add(ptr, 140) // 70 bytes data + 70 bytes padding

                    // Pack tran struct efficiently
                    let tran := mload(add(input, 0x60))

                    // Pack batchId (6 bytes)
                    mstore(ptr, shl(208, mload(tran)))

                    // Pack hashes directly (96 bytes)
                    mstore(add(ptr, 6), mload(add(tran, 0x20)))
                    mstore(add(ptr, 38), mload(add(tran, 0x40)))
                    mstore(add(ptr, 70), mload(add(tran, 0x60)))

                    ptr := add(ptr, 150) // 102 bytes data + 48 bytes padding
                }
            }
        }
    }

    /// @notice Unpacks a byte array back into an array of BatchProveInput structs.
    /// @dev Reverses the packing performed by packBatchProveInputs. Input must be
    /// exactly 1 + (length * 354) bytes. See packBatchProveInputs for data layout.
    /// @param _encoded The packed byte array to unpack
    /// @return batches_ Array of unpacked BatchProveInput structs
    function unpackBatchProveInputs(bytes memory _encoded)
        internal
        pure
        returns (I.BatchProveInput[] memory batches_)
    {
        require(_encoded.length >= 1, InvalidDataLength());

        unchecked {
            uint256 length;
            assembly {
                let dataPtr := add(_encoded, 0x20)
                length := shr(248, mload(dataPtr))
            }

            require(_encoded.length == 1 + (length * 354), InvalidDataLength());
            batches_ = new I.BatchProveInput[](length);

            assembly {
                let dataPtr := add(_encoded, 0x20)
                let ptr := add(dataPtr, 1)

                for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                    // Allocate memory for BatchProveInput
                    let input := mload(0x40)
                    mstore(0x40, add(input, 0x80))

                    // idAndBuildHash (32 bytes)
                    mstore(input, mload(ptr))
                    ptr := add(ptr, 32)

                    // proposeMetaHash (32 bytes)
                    mstore(add(input, 0x20), mload(ptr))
                    ptr := add(ptr, 32)

                    // Allocate and populate proveMeta
                    let proveMeta := mload(0x40)
                    mstore(0x40, add(proveMeta, 0xe0))

                    // proposer (20 bytes)
                    mstore(proveMeta, shr(96, mload(ptr)))
                    ptr := add(ptr, 20)

                    // prover (20 bytes)
                    mstore(add(proveMeta, 0x20), shr(96, mload(ptr)))
                    ptr := add(ptr, 20)

                    // proposedAt (6 bytes)
                    mstore(add(proveMeta, 0x40), shr(208, mload(ptr)))
                    ptr := add(ptr, 6)

                    // firstBlockId (6 bytes)
                    mstore(add(proveMeta, 0x60), shr(208, mload(ptr)))
                    ptr := add(ptr, 6)

                    // lastBlockId (6 bytes)
                    mstore(add(proveMeta, 0x80), shr(208, mload(ptr)))
                    ptr := add(ptr, 6)

                    // livenessBond (6 bytes)
                    mstore(add(proveMeta, 0xa0), shr(208, mload(ptr)))
                    ptr := add(ptr, 6)

                    // provabilityBond (6 bytes)
                    mstore(add(proveMeta, 0xc0), shr(208, mload(ptr)))
                    ptr := add(ptr, 6)

                    // Skip padding
                    ptr := add(ptr, 70)

                    mstore(add(input, 0x40), proveMeta)

                    // Allocate and populate tran
                    let tran := mload(0x40)
                    mstore(0x40, add(tran, 0x80))

                    // Read batchId and parentHash in one operation
                    let tranData1 := mload(ptr)
                    mstore(tran, shr(208, tranData1))
                    mstore(add(tran, 0x20), mload(add(ptr, 6)))

                    // Read remaining hashes
                    mstore(add(tran, 0x40), mload(add(ptr, 38)))
                    mstore(add(tran, 0x60), mload(add(ptr, 70)))

                    // Update ptr to skip all data including padding
                    ptr := add(ptr, 150)

                    mstore(add(input, 0x60), tran)

                    mstore(add(batches_, mul(add(i, 1), 0x20)), input)
                }
            }
        }
    }

    /// @notice Packs a BatchProposeMetadataEvidence struct into a tightly packed byte array.
    /// @dev Packed format (82 bytes total):
    /// | Field               | Bytes | Offset | Type    |
    /// |---------------------|-------|--------|---------|
    /// | idAndBuildHash      | 32    | 0      | bytes32 |
    /// | proveMetaHash       | 32    | 32     | bytes32 |
    /// | lastBlockTimestamp  | 6     | 64     | uint48  |
    /// | lastBlockId         | 6     | 70     | uint48  |
    /// | lastAnchorBlockId   | 6     | 76     | uint48  |
    /// @param _evidence The BatchProposeMetadataEvidence struct to pack
    /// @return encoded_ The packed byte array (82 bytes)
    function packBatchProposeMetadataEvidence(I.BatchProposeMetadataEvidence memory _evidence)
        internal
        pure
        returns (bytes memory encoded_)
    {
        unchecked {
            encoded_ = new bytes(82);

            assembly {
                let ptr := add(encoded_, 0x20)
                let proposeMeta := mload(add(_evidence, 0x40))

                // Pack hashes directly (64 bytes)
                mstore(ptr, mload(_evidence))
                mstore(add(ptr, 32), mload(add(_evidence, 0x20)))

                // Pack proposeMeta fields efficiently (18 bytes)
                mstore(add(ptr, 64), shl(208, mload(proposeMeta)))
                mstore(add(ptr, 70), shl(208, mload(add(proposeMeta, 0x20))))
                mstore(add(ptr, 76), shl(208, mload(add(proposeMeta, 0x40))))
            }
        }
    }

    /// @notice Unpacks a byte array back into a BatchProposeMetadataEvidence struct.
    /// @dev Reverses the packing performed by packBatchProposeMetadataEvidence.
    /// Input must be exactly 82 bytes. See packBatchProposeMetadataEvidence for data layout.
    /// @param _encoded The packed byte array to unpack (must be 82 bytes)
    /// @return evidence_ The unpacked BatchProposeMetadataEvidence struct
    function unpackBatchProposeMetadataEvidence(bytes memory _encoded)
        internal
        pure
        returns (I.BatchProposeMetadataEvidence memory evidence_)
    {
        require(_encoded.length == 82, InvalidDataLength());

        unchecked {
            assembly {
                let dataPtr := add(_encoded, 0x20)

                // Allocate all memory upfront
                evidence_ := mload(0x40)
                let proposeMeta := add(evidence_, 0x60)
                mstore(0x40, add(proposeMeta, 0x60))

                // Read hashes
                mstore(evidence_, mload(dataPtr))
                mstore(add(evidence_, 0x20), mload(add(dataPtr, 32)))

                // Read all proposeMeta fields in fewer operations
                let metaData := mload(add(dataPtr, 64))
                mstore(proposeMeta, shr(208, metaData))

                let metaData2 := mload(add(dataPtr, 70))
                mstore(add(proposeMeta, 0x20), shr(208, metaData2))

                let metaData3 := mload(add(dataPtr, 76))
                mstore(add(proposeMeta, 0x40), shr(208, metaData3))

                mstore(add(evidence_, 0x40), proposeMeta)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ArrayTooLarge();
    error EmptyInput();
    error InvalidDataLength();
}
