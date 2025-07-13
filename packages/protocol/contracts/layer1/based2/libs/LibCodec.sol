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
    /// @dev The packed format uses exactly 109 bytes per TransitionMeta
    /// @param _tranMetas Array of TransitionMeta structs to pack
    /// @return encoded_ The packed byte array
    function packTransitionMetas(I.TransitionMeta[] memory _tranMetas)
        internal
        pure
        returns (bytes memory encoded_)
    {
        unchecked {
            uint256 length = _tranMetas.length;
            encoded_ = new bytes(length * 109);

            for (uint256 i; i < length; ++i) {
                uint256 ptr;
                assembly {
                    ptr := add(add(encoded_, 0x20), mul(i, 109))
                }
                _packTransitionMeta(ptr, _tranMetas[i]);
            }
        }
    }

    /// @notice Unpacks a byte array back into an array of TransitionMeta structs.
    /// @param _encoded The packed byte array to unpack
    /// @return tranMetas_ Array of unpacked TransitionMeta structs
    function unpackTransitionMetas(bytes memory _encoded)
        internal
        pure
        returns (I.TransitionMeta[] memory tranMetas_)
    {
        require(_encoded.length % 109 == 0, InvalidDataLength());

        unchecked {
            uint256 length = _encoded.length / 109;
            tranMetas_ = new I.TransitionMeta[](length);

            for (uint256 i; i < length; ++i) {
                uint256 ptr;
                assembly {
                    ptr := add(add(_encoded, 0x20), mul(i, 109))
                }
                tranMetas_[i] = _unpackTransitionMeta(ptr);
            }
        }
    }

    /// @notice Packs a BatchContext struct into a tightly packed byte array.
    /// @dev The packed format uses:
    /// - prover: 20 bytes (address)
    /// - txsHash: 32 bytes
    /// - lastAnchorBlockId: 6 bytes (uint48)
    /// - lastBlockId: 6 bytes (uint48)
    /// - blobsCreatedIn: 6 bytes (uint48)
    /// - blockMaxGasLimit: 4 bytes (uint32)
    /// - livenessBond: 6 bytes (uint48)
    /// - provabilityBond: 6 bytes (uint48)
    /// - baseFeeSharingPctg: 1 byte (uint8)
    /// - anchorBlockHashes: dynamic (1 byte length + 32 bytes per hash)
    /// - blobHashes: dynamic (1 byte length + 32 bytes per hash)
    /// Total fixed size: 85 bytes + dynamic arrays
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

            uint256 ptr;
            assembly { ptr := add(packed_, 0x20) }

            // Pack fixed fields using helper functions
            ptr = _packAddress(ptr, _context.prover);
            ptr = _packBytes32(ptr, _context.txsHash);
            ptr = _packUint48(ptr, _context.lastAnchorBlockId);
            ptr = _packUint48(ptr, _context.lastBlockId);
            ptr = _packUint48(ptr, _context.blobsCreatedIn);
            ptr = _packUint32(ptr, _context.blockMaxGasLimit);
            ptr = _packUint48(ptr, _context.livenessBond);
            ptr = _packUint48(ptr, _context.provabilityBond);
            ptr = _packUint8(ptr, _context.baseFeeSharingPctg);
            
            // Pack arrays using helper functions
            ptr = _packBytes32Array(ptr, _context.anchorBlockHashes);
            _packBytes32Array(ptr, _context.blobHashes);
        }
    }

    /// @notice Unpacks a byte array back into a BatchContext struct.
    /// @dev Reverses the packing performed by packBatchContext. The input must have
    /// the correct format: 85 fixed bytes + dynamic array data.
    /// @param _packed The packed byte array to unpack
    /// @return context_ The unpacked BatchContext struct
    function unpackBatchContext(bytes memory _packed)
        internal
        pure
        returns (I.BatchContext memory context_)
    {
        require(_packed.length >= 87, InvalidDataLength()); // 85 fixed + 2 lengths (1 byte each)

        unchecked {
            uint256 ptr;
            assembly { 
                ptr := add(_packed, 0x20)
                context_ := mload(0x40)
                mstore(0x40, add(context_, 0x160))
            }

            // Unpack fixed fields using helper functions
            uint256 value;
            (context_.prover, ptr) = _unpackAddress(ptr);
            (context_.txsHash, ptr) = _unpackBytes32(ptr);
            (value, ptr) = _unpackUint48(ptr); context_.lastAnchorBlockId = uint48(value);
            (value, ptr) = _unpackUint48(ptr); context_.lastBlockId = uint48(value);
            (value, ptr) = _unpackUint48(ptr); context_.blobsCreatedIn = uint48(value);
            (value, ptr) = _unpackUint32(ptr); context_.blockMaxGasLimit = uint32(value);
            (value, ptr) = _unpackUint48(ptr); context_.livenessBond = uint48(value);
            (value, ptr) = _unpackUint48(ptr); context_.provabilityBond = uint48(value);
            (value, ptr) = _unpackUint8(ptr); context_.baseFeeSharingPctg = uint8(value);
            
            // Unpack arrays using helper functions
            (context_.anchorBlockHashes, ptr) = _unpackBytes32Array(ptr);
            (context_.blobHashes,) = _unpackBytes32Array(ptr);
        }
    }

    function packSummary(I.Summary memory _summary) internal pure returns (bytes memory encoded_) {
        encoded_ = new bytes(98);
        uint256 ptr;
        assembly { ptr := add(encoded_, 0x20) }
        
        ptr = _packUint48(ptr, _summary.numBatches);
        ptr = _packUint48(ptr, _summary.lastSyncedBlockId);
        ptr = _packUint48(ptr, _summary.lastSyncedAt);
        ptr = _packUint48(ptr, _summary.lastVerifiedBatchId);
        ptr = _packUint48(ptr, _summary.gasIssuanceUpdatedAt);
        ptr = _packUint32(ptr, _summary.gasIssuancePerSecond);
        ptr = _packBytes32(ptr, _summary.lastVerifiedBlockHash);
        _packBytes32(ptr, _summary.lastBatchMetaHash);
    }

    function unpackSummary(bytes memory _encoded)
        internal
        pure
        returns (I.Summary memory summary_)
    {
        require(_encoded.length == 98, InvalidDataLength());

        uint256 ptr;
        assembly { 
            ptr := add(_encoded, 0x20)
            summary_ := mload(0x40)
            mstore(0x40, add(summary_, 0x100))
        }
        
        uint256 value;
        (value, ptr) = _unpackUint48(ptr); summary_.numBatches = uint48(value);
        (value, ptr) = _unpackUint48(ptr); summary_.lastSyncedBlockId = uint48(value);
        (value, ptr) = _unpackUint48(ptr); summary_.lastSyncedAt = uint48(value);
        (value, ptr) = _unpackUint48(ptr); summary_.lastVerifiedBatchId = uint48(value);
        (value, ptr) = _unpackUint48(ptr); summary_.gasIssuanceUpdatedAt = uint48(value);
        (value, ptr) = _unpackUint32(ptr); summary_.gasIssuancePerSecond = uint32(value);
        (summary_.lastVerifiedBlockHash, ptr) = _unpackBytes32(ptr);
        (summary_.lastBatchMetaHash,) = _unpackBytes32(ptr);
    }

    function packBatches(I.Batch[] memory _batches) internal pure returns (bytes memory encoded_) {
        unchecked {
            uint256 length = _batches.length;
            require(length <= type(uint8).max, ArrayTooLarge());

            uint256 totalSize = _calculateBatchesTotalSize(_batches);
            encoded_ = new bytes(totalSize);

            uint256 ptr;
            assembly { 
                ptr := add(encoded_, 0x20)
                mstore(ptr, shl(248, length))
                ptr := add(ptr, 1)
            }
            
            for (uint256 i; i < length; ++i) {
                ptr = _packSingleBatch(ptr, _batches[i]);
            }
        }
    }

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

    function packBatchProveInputs(I.BatchProveInput[] memory _batches)
        internal
        pure
        returns (bytes memory encoded_)
    {
        unchecked {
            uint256 length = _batches.length;
            require(length <= type(uint8).max, ArrayTooLarge());

            // Each BatchProveInput: 32+32+140+150 = 354 bytes fixed
            encoded_ = new bytes(1 + (length * 354));

            uint256 ptr;
            assembly { ptr := add(encoded_, 0x20) }
            
            ptr = _packUint8(ptr, length);

            for (uint256 i; i < length; ++i) {
                I.BatchProveInput memory input = _batches[i];
                
                // Pack fixed fields using helper functions
                ptr = _packBytes32(ptr, input.idAndBuildHash);
                ptr = _packBytes32(ptr, input.proposeMetaHash);
                
                // Pack proveMeta struct fields
                ptr = _packAddress(ptr, input.proveMeta.proposer);
                ptr = _packAddress(ptr, input.proveMeta.prover);
                ptr = _packUint48(ptr, input.proveMeta.proposedAt);
                ptr = _packUint48(ptr, input.proveMeta.firstBlockId);
                ptr = _packUint48(ptr, input.proveMeta.lastBlockId);
                ptr = _packUint48(ptr, input.proveMeta.livenessBond);
                ptr = _packUint48(ptr, input.proveMeta.provabilityBond);
                
                // Skip padding for proveMeta (140-70=70 bytes)
                assembly { ptr := add(ptr, 70) }
                
                // Pack tran struct fields
                ptr = _packUint48(ptr, input.tran.batchId);
                ptr = _packBytes32(ptr, input.tran.parentHash);
                ptr = _packBytes32(ptr, input.tran.blockHash);
                ptr = _packBytes32(ptr, input.tran.stateRoot);
                
                // Skip padding for tran (150-102=48 bytes)
                assembly { ptr := add(ptr, 48) }
            }
        }
    }

    function unpackBatchProveInputs(bytes memory _encoded)
        internal
        pure
        returns (I.BatchProveInput[] memory batches_)
    {
        require(_encoded.length >= 1, InvalidDataLength());

        unchecked {
            uint256 ptr;
            assembly { ptr := add(_encoded, 0x20) }
            
            uint256 length;
            (length, ptr) = _unpackUint8(ptr);

            require(_encoded.length == 1 + (length * 354), InvalidDataLength());
            batches_ = new I.BatchProveInput[](length);

            for (uint256 i; i < length; ++i) {
                I.BatchProveInput memory input;
                uint256 value;
                
                // Unpack fixed fields using helper functions
                (input.idAndBuildHash, ptr) = _unpackBytes32(ptr);
                (input.proposeMetaHash, ptr) = _unpackBytes32(ptr);
                
                // Unpack proveMeta struct fields
                (input.proveMeta.proposer, ptr) = _unpackAddress(ptr);
                (input.proveMeta.prover, ptr) = _unpackAddress(ptr);
                (value, ptr) = _unpackUint48(ptr); input.proveMeta.proposedAt = uint48(value);
                (value, ptr) = _unpackUint48(ptr); input.proveMeta.firstBlockId = uint48(value);
                (value, ptr) = _unpackUint48(ptr); input.proveMeta.lastBlockId = uint48(value);
                (value, ptr) = _unpackUint48(ptr); input.proveMeta.livenessBond = uint48(value);
                (value, ptr) = _unpackUint48(ptr); input.proveMeta.provabilityBond = uint48(value);
                
                // Skip padding for proveMeta (140-70=70 bytes)
                assembly { ptr := add(ptr, 70) }
                
                // Unpack tran struct fields
                (value, ptr) = _unpackUint48(ptr); input.tran.batchId = uint48(value);
                (input.tran.parentHash, ptr) = _unpackBytes32(ptr);
                (input.tran.blockHash, ptr) = _unpackBytes32(ptr);
                (input.tran.stateRoot, ptr) = _unpackBytes32(ptr);
                
                // Skip padding for tran (150-102=48 bytes)
                assembly { ptr := add(ptr, 48) }
                
                batches_[i] = input;
            }
        }
    }

    function packBatchProposeMetadataEvidence(I.BatchProposeMetadataEvidence memory _evidence)
        internal
        pure
        returns (bytes memory encoded_)
    {
        unchecked {
            // Fixed size: 32+32+18 = 82 bytes
            encoded_ = new bytes(82);

            uint256 ptr;
            assembly { ptr := add(encoded_, 0x20) }

            // Pack fields using helper functions
            ptr = _packBytes32(ptr, _evidence.idAndBuildHash);
            ptr = _packBytes32(ptr, _evidence.proveMetaHash);
            ptr = _packUint48(ptr, _evidence.proposeMeta.lastBlockTimestamp);
            ptr = _packUint48(ptr, _evidence.proposeMeta.lastBlockId);
            _packUint48(ptr, _evidence.proposeMeta.lastAnchorBlockId);
        }
    }

    function unpackBatchProposeMetadataEvidence(bytes memory _encoded)
        internal
        pure
        returns (I.BatchProposeMetadataEvidence memory evidence_)
    {
        require(_encoded.length == 82, InvalidDataLength());

        unchecked {
            uint256 ptr;
            assembly { 
                ptr := add(_encoded, 0x20)
                evidence_ := mload(0x40)
                mstore(0x40, add(evidence_, 0x60))
                
                // Allocate memory for proposeMeta struct
                let proposeMeta := mload(0x40)
                mstore(0x40, add(proposeMeta, 0x60))
                mstore(add(evidence_, 0x40), proposeMeta)
            }

            // Unpack fields using helper functions
            uint256 value;
            (evidence_.idAndBuildHash, ptr) = _unpackBytes32(ptr);
            (evidence_.proveMetaHash, ptr) = _unpackBytes32(ptr);
            (value, ptr) = _unpackUint48(ptr); evidence_.proposeMeta.lastBlockTimestamp = uint48(value);
            (value, ptr) = _unpackUint48(ptr); evidence_.proposeMeta.lastBlockId = uint48(value);
            (value,) = _unpackUint48(ptr); evidence_.proposeMeta.lastAnchorBlockId = uint48(value);
        }
    }

    // -------------------------------------------------------------------------
    // Private Helper Functions
    // -------------------------------------------------------------------------

    /// @dev Packs address into 20 bytes at ptr, returns updated ptr
    function _packAddress(uint256 ptr, address addr) private pure returns (uint256) {
        assembly {
            mstore(ptr, shl(96, addr))
        }
        return ptr + 20;
    }

    /// @dev Unpacks address from ptr, returns (address, updated ptr)
    function _unpackAddress(uint256 ptr) private pure returns (address addr, uint256 newPtr) {
        assembly {
            addr := shr(96, mload(ptr))
        }
        return (addr, ptr + 20);
    }

    /// @dev Packs uint48 into 6 bytes at ptr, returns updated ptr
    function _packUint48(uint256 ptr, uint256 value) private pure returns (uint256) {
        assembly {
            mstore(ptr, shl(208, value))
        }
        return ptr + 6;
    }

    /// @dev Unpacks uint48 from ptr, returns (value, updated ptr)
    function _unpackUint48(uint256 ptr) private pure returns (uint256 value, uint256 newPtr) {
        assembly {
            value := shr(208, mload(ptr))
        }
        return (value, ptr + 6);
    }

    /// @dev Packs uint32 into 4 bytes at ptr, returns updated ptr
    function _packUint32(uint256 ptr, uint256 value) private pure returns (uint256) {
        assembly {
            mstore(ptr, shl(224, value))
        }
        return ptr + 4;
    }

    /// @dev Unpacks uint32 from ptr, returns (value, updated ptr)
    function _unpackUint32(uint256 ptr) private pure returns (uint256 value, uint256 newPtr) {
        assembly {
            value := shr(224, mload(ptr))
        }
        return (value, ptr + 4);
    }

    /// @dev Packs bytes32 at ptr, returns updated ptr
    function _packBytes32(uint256 ptr, bytes32 value) private pure returns (uint256) {
        assembly {
            mstore(ptr, value)
        }
        return ptr + 32;
    }

    /// @dev Unpacks bytes32 from ptr, returns (value, updated ptr)
    function _unpackBytes32(uint256 ptr) private pure returns (bytes32 value, uint256 newPtr) {
        assembly {
            value := mload(ptr)
        }
        return (value, ptr + 32);
    }

    /// @dev Packs uint8 into 1 byte at ptr, returns updated ptr
    function _packUint8(uint256 ptr, uint256 value) private pure returns (uint256) {
        assembly {
            mstore8(ptr, value)
        }
        return ptr + 1;
    }

    /// @dev Unpacks uint8 from ptr, returns (value, updated ptr)
    function _unpackUint8(uint256 ptr) private pure returns (uint256 value, uint256 newPtr) {
        assembly {
            value := byte(0, mload(ptr))
        }
        return (value, ptr + 1);
    }

    /// @dev Allocates memory for struct, returns pointer and updates free memory
    function _allocateMemory(uint256 size) private pure returns (uint256 ptr) {
        assembly {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, size))
        }
    }

    /// @dev Packs bytes array length and data, returns updated ptr
    function _packBytes(uint256 ptr, bytes memory data) private pure returns (uint256) {
        uint256 len = data.length;
        assembly {
            // Store length (1 byte)
            mstore(ptr, shl(248, len))
            ptr := add(ptr, 1)
            
            // Copy data
            let src := add(data, 0x20)
            let remaining := len
            for { } gt(remaining, 0) { } {
                let chunk := mload(src)
                mstore(ptr, chunk)
                let copySize := 32
                if lt(remaining, 32) { copySize := remaining }
                ptr := add(ptr, copySize)
                src := add(src, 32)
                remaining := sub(remaining, copySize)
            }
        }
        return ptr;
    }

    /// @dev Creates empty array and returns pointer
    function _createEmptyArray() private pure returns (uint256 arrayPtr) {
        assembly {
            arrayPtr := mload(0x40)
            mstore(arrayPtr, 0) // length = 0
            mstore(0x40, add(arrayPtr, 0x20))
        }
    }

    /// @dev Calculates total size needed for packing batches
    function _calculateBatchesTotalSize(I.Batch[] memory _batches) private pure returns (uint256 totalSize) {
        totalSize = 1; // 1 byte for array length
        for (uint256 i; i < _batches.length; ++i) {
            I.Batch memory batch = _batches[i];
            totalSize += 51; // Fixed fields: 20+20+7+4
            totalSize += 1 + batch.proverAuth.length;
            totalSize += 1 + (batch.signalSlots.length * 32);
            totalSize += 1 + (batch.anchorBlockIds.length * 6);
            totalSize += 1 + (batch.blocks.length * 10);
            totalSize += 17; // blobs fixed: 1+1+4+4+6+1
            totalSize += (batch.blobs.hashes.length * 32);
        }
    }

    /// @dev Packs a single batch at ptr, returns updated ptr
    function _packSingleBatch(uint256 ptr, I.Batch memory batch) private pure returns (uint256) {
        // Pack fixed fields
        ptr = _packAddress(ptr, batch.proposer);
        ptr = _packAddress(ptr, batch.coinbase);
        
        // Pack timestamp + forced inclusion in 7 bytes
        assembly {
            let combined := or(mload(add(batch, 0x40)), shl(48, mload(add(batch, 0x80))))
            mstore(ptr, shl(200, combined))
            ptr := add(ptr, 7)
        }
        
        ptr = _packUint32(ptr, batch.gasIssuancePerSecond);
        ptr = _packBytes(ptr, batch.proverAuth);
        
        // Pack arrays
        ptr = _packBytes32Array(ptr, batch.signalSlots);
        ptr = _packUint48Array(ptr, batch.anchorBlockIds);
        ptr = _packBlockArray(ptr, batch.blocks);
        ptr = _packBlobsStruct(ptr, batch.blobs);
        
        return ptr;
    }

    /// @dev Packs bytes32 array with length prefix
    function _packBytes32Array(uint256 ptr, bytes32[] memory arr) private pure returns (uint256) {
        uint256 len = arr.length;
        assembly {
            mstore(ptr, shl(248, len))
            ptr := add(ptr, 1)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(ptr, mload(add(arr, mul(add(i, 1), 0x20))))
                ptr := add(ptr, 32)
            }
        }
        return ptr;
    }

    /// @dev Unpacks bytes32 array with length prefix
    function _unpackBytes32Array(uint256 ptr) private pure returns (bytes32[] memory arr, uint256 newPtr) {
        uint256 len;
        assembly {
            len := shr(248, mload(ptr))
            ptr := add(ptr, 1)
        }
        
        arr = new bytes32[](len);
        assembly {
            let arrData := add(arr, 0x20)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(add(arrData, mul(i, 0x20)), mload(ptr))
                ptr := add(ptr, 32)
            }
        }
        return (arr, ptr);
    }

    /// @dev Packs uint48 array with length prefix
    function _packUint48Array(uint256 ptr, uint48[] memory arr) private pure returns (uint256) {
        uint256 len = arr.length;
        assembly {
            mstore(ptr, shl(248, len))
            ptr := add(ptr, 1)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(ptr, shl(208, mload(add(arr, mul(add(i, 1), 0x20)))))
                ptr := add(ptr, 6)
            }
        }
        return ptr;
    }

    /// @dev Packs block array with length prefix
    function _packBlockArray(uint256 ptr, I.Block[] memory blocks) private pure returns (uint256) {
        uint256 len = blocks.length;
        assembly {
            mstore(ptr, shl(248, len))
            ptr := add(ptr, 1)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                let blockPtr := add(blocks, mul(add(i, 1), 0x20))
                let blockData := mload(blockPtr)
                let numTransactions := and(mload(blockData), 0xFFFF)
                let timeShift := and(mload(add(blockData, 0x20)), 0xFF)
                let anchorBlockId := and(mload(add(blockData, 0x40)), 0xFFFFFFFFFFFF)
                let numSignals := and(mload(add(blockData, 0x60)), 0xFF)
                let hasAnchor := mload(add(blockData, 0x80))
                let encoded := or(numTransactions, shl(16, timeShift))
                encoded := or(encoded, shl(24, anchorBlockId))
                encoded := or(encoded, shl(72, numSignals))
                encoded := or(encoded, shl(80, hasAnchor))
                mstore(ptr, shl(176, encoded))
                ptr := add(ptr, 10)
            }
        }
        return ptr;
    }

    /// @dev Packs blobs struct
    function _packBlobsStruct(uint256 ptr, I.Blobs memory blobs) private pure returns (uint256) {
        ptr = _packUint8(ptr, blobs.firstBlobIndex);
        ptr = _packUint8(ptr, blobs.numBlobs);
        ptr = _packUint32(ptr, blobs.byteOffset);
        ptr = _packUint32(ptr, blobs.byteSize);
        ptr = _packUint48(ptr, blobs.createdIn);
        ptr = _packBytes32Array(ptr, blobs.hashes);
        return ptr;
    }

    /// @dev Packs a single TransitionMeta struct at ptr
    function _packTransitionMeta(uint256 ptr, I.TransitionMeta memory meta) private pure returns (uint256) {
        // Pack fields using helper functions
        ptr = _packBytes32(ptr, meta.blockHash);
        ptr = _packBytes32(ptr, meta.stateRoot);
        ptr = _packAddress(ptr, meta.prover);
        
        // Pack proofTiming + byAssignedProver in 1 byte
        uint256 combinedByte = uint256(meta.proofTiming) | (meta.byAssignedProver ? (1 << 2) : 0);
        ptr = _packUint8(ptr, combinedByte);
        
        // Pack four uint48 values
        ptr = _packUint48(ptr, meta.createdAt);
        ptr = _packUint48(ptr, meta.lastBlockId);
        ptr = _packUint48(ptr, meta.provabilityBond);
        ptr = _packUint48(ptr, meta.livenessBond);
        
        return ptr;
    }

    /// @dev Unpacks a single TransitionMeta struct from ptr
    function _unpackTransitionMeta(uint256 ptr) private pure returns (I.TransitionMeta memory meta) {
        // Allocate memory for the struct
        assembly {
            meta := mload(0x40)
            mstore(0x40, add(meta, 0x120))
        }
        
        // Unpack fields using helper functions
        uint256 value;
        (meta.blockHash, ptr) = _unpackBytes32(ptr);
        (meta.stateRoot, ptr) = _unpackBytes32(ptr);
        (meta.prover, ptr) = _unpackAddress(ptr);
        
        // Unpack proofTiming + byAssignedProver from 1 byte
        (value, ptr) = _unpackUint8(ptr);
        meta.proofTiming = I.ProofTiming(value & 0x03);
        meta.byAssignedProver = (value >> 2) & 0x01 == 1;
        
        // Unpack four uint48 values
        (value, ptr) = _unpackUint48(ptr); meta.createdAt = uint48(value);
        (value, ptr) = _unpackUint48(ptr); meta.lastBlockId = uint48(value);
        (value, ptr) = _unpackUint48(ptr); meta.provabilityBond = uint48(value);
        (value,) = _unpackUint48(ptr); meta.livenessBond = uint48(value);
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error ArrayTooLarge();
    error InvalidDataLength();
    error EmptyInput();
}
