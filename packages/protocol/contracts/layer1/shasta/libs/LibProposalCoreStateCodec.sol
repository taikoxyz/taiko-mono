// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibProposalCoreStateCodec
/// @notice Optimized library for encoding/decoding proposal and core state event data with
/// bit-packing and validation
/// @dev Encodes data more efficiently than abi.encode by:
/// - Using exact bit widths for each field type (e.g., 48 bits for uint48)
/// - Packing boolean values as single bytes
/// - Using 24-bit length prefixes for arrays (supports up to 16M elements)
/// - Validating annotated fields during encoding
/// @custom:security-contact security@taiko.xyz
library LibProposalCoreStateCodec {
    // ---------------------------------------------------------------
    // Constants for field validation (based on annotations)
    // ---------------------------------------------------------------

    uint256 private constant MAX_BASEFEE_PCTG = 100; // @max=100 for basefeeSharingPctg
    uint256 private constant MAX_BLOB_HASHES = 64; // @maxLength=64 for blobHashes array

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error INVALID_DATA_LENGTH();
    error BASEFEE_SHARING_PCTG_EXCEEDS_MAX();
    error BLOB_HASHES_ARRAY_EXCEEDS_MAX();

    // ---------------------------------------------------------------
    // Encoding function
    // ---------------------------------------------------------------

    /// @notice Encodes proposal and core state data with optimized packing
    /// @dev Uses efficient memory operations while maintaining compact encoding
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return Encoded bytes with minimal size
    function encode(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory)
    {
        // Validate annotated fields
        if (_proposal.basefeeSharingPctg > MAX_BASEFEE_PCTG) {
            revert BASEFEE_SHARING_PCTG_EXCEEDS_MAX();
        }

        uint256 hashCount = _proposal.blobSlice.blobHashes.length;
        if (hashCount > MAX_BLOB_HASHES) {
            revert BLOB_HASHES_ARRAY_EXCEEDS_MAX();
        }

        // Calculate total size: fixed fields + dynamic array
        uint256 size = 158 + (hashCount * 32); // 158 = sum of all fixed-size fields
        bytes memory result = new bytes(size);

        assembly {
            let ptr := add(result, 0x20)
            let p := _proposal
            let b := mload(add(p, 0xc0)) // blobSlice pointer

            // Store id (6 bytes) and proposer (20 bytes) in one word
            let word := or(shl(208, mload(p)), shl(48, mload(add(p, 0x20))))
            mstore(ptr, word)

            // Store timestamps and block number (6+6+6 bytes)
            word := or(
                shl(208, mload(add(p, 0x40))), // originTimestamp
                or(shl(160, mload(add(p, 0x60))), shl(112, mload(add(p, 0x80)))) // originBlockNumber + isForcedInclusion start
            )
            mstore(add(ptr, 26), word)

            // Store bools and array length
            mstore8(add(ptr, 38), mload(add(p, 0x80))) // isForcedInclusion
            mstore8(add(ptr, 39), mload(add(p, 0xa0))) // basefeeSharingPctg
            
            // Store array length (3 bytes)
            let len := mload(mload(b))
            let lenWord := shl(232, len)
            mstore(add(ptr, 40), lenWord)

            // Copy blob hashes efficiently
            let src := add(mload(b), 0x20)
            let dst := add(ptr, 43)
            for { let end := add(src, mul(len, 32)) } lt(src, end) { } {
                mstore(dst, mload(src))
                src := add(src, 32)
                dst := add(dst, 32)
            }

            // Store remaining BlobSlice fields
            let nextPtr := add(add(ptr, 43), mul(len, 32))
            word := or(shl(232, mload(add(b, 0x20))), shl(184, mload(add(b, 0x40)))) // offset (3 bytes) + timestamp (6 bytes)
            mstore(nextPtr, word)

            // Store coreStateHash
            mstore(add(nextPtr, 9), mload(add(p, 0xe0)))

            // Store CoreState fields
            let c := _coreState
            let finalPtr := add(nextPtr, 41)
            
            // Pack nextProposalId and lastFinalizedProposalId
            word := or(shl(208, mload(c)), shl(160, mload(add(c, 0x20))))
            mstore(finalPtr, word)
            
            // Store hashes
            mstore(add(finalPtr, 12), mload(add(c, 0x40))) // lastFinalizedClaimHash
            mstore(add(finalPtr, 44), mload(add(c, 0x60))) // bondInstructionsHash
        }

        return result;
    }

    // ---------------------------------------------------------------
    // Decoding function
    // ---------------------------------------------------------------

    /// @notice Decodes the packed event data back to structs
    /// @dev Reverses the encoding process using efficient memory operations
    /// @param _data The encoded bytes to decode
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        if (_data.length < 176) revert INVALID_DATA_LENGTH();

        assembly {
            let ptr := add(_data, 0x20)

            // Read first word and extract fields
            let word1 := mload(ptr)
            mstore(proposal_, shr(192, word1)) // id (top 8 bytes -> uint48)
            mstore(add(proposal_, 0x20), and(shr(32, word1), 0xffffffffffffffffffffffffffffffffffffffff)) // proposer (20 bytes)
            
            // Read second word
            let word2 := mload(add(ptr, 32))
            // Combine timestamp from word1 (last 4 bytes) and word2 (first 4 bytes)
            mstore(add(proposal_, 0x40), or(shl(32, and(word1, 0xffffffff)), shr(224, word2))) // originTimestamp
            mstore(add(proposal_, 0x60), and(shr(160, word2), 0xffffffffffff)) // originBlockNumber
            mstore(add(proposal_, 0x80), and(shr(152, word2), 0xff)) // isForcedInclusion
            mstore(add(proposal_, 0xa0), and(shr(144, word2), 0xff)) // basefeeSharingPctg

            // Decode BlobSlice
            let blobSlice := mload(0x40)
            mstore(0x40, add(blobSlice, 0x60))
            mstore(add(proposal_, 0xc0), blobSlice)

            // Read array length from word2
            let arrayLen := and(shr(112, word2), 0xffffffff)
            let hashArray := mload(0x40)
            mstore(hashArray, arrayLen)
            mstore(0x40, add(hashArray, mul(add(arrayLen, 1), 0x20)))
            mstore(blobSlice, hashArray)

            // Copy blob hashes efficiently
            let src := add(ptr, 64)
            let dst := add(hashArray, 0x20)
            for { let end := add(src, mul(arrayLen, 32)) } lt(src, end) { } {
                mstore(dst, mload(src))
                src := add(src, 32)
                dst := add(dst, 0x20)
            }

            // Continue decoding from after blob hashes
            let nextPtr := add(add(ptr, 64), mul(arrayLen, 32))
            let word3 := mload(nextPtr)
            mstore(add(blobSlice, 0x20), shr(224, word3)) // offset (top 4 bytes -> uint24)
            mstore(add(blobSlice, 0x40), and(shr(160, word3), 0xffffffffffff)) // timestamp (next 8 bytes -> uint48)
            
            // Start extracting coreStateHash (first 12 bytes from word3, rest from word4)
            let word4 := mload(add(nextPtr, 32))
            mstore(add(proposal_, 0xe0), or(shl(160, and(word3, 0xffffffffffffffffffffffff)), shr(96, word4))) // coreStateHash

            // Decode CoreState
            mstore(coreState_, and(shr(32, word4), 0xffffffffffff)) // nextProposalId
            
            // Get lastFinalizedProposalId from word4 (last 4 bytes) and word5 (first 4 bytes)
            let word5 := mload(add(nextPtr, 64))
            mstore(add(coreState_, 0x20), or(shl(32, and(word4, 0xffffffff)), shr(224, word5))) // lastFinalizedProposalId
            
            // Get lastFinalizedClaimHash from word5 (28 bytes) and word6 (4 bytes)
            let word6 := mload(add(nextPtr, 96))
            mstore(add(coreState_, 0x40), or(shl(32, and(word5, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffff)), shr(224, word6))) // lastFinalizedClaimHash
            
            // Get bondInstructionsHash from word6 (28 bytes) and last 4 individual bytes
            let hash := shl(32, and(word6, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffff))
            hash := or(hash, shl(24, byte(0, mload(add(nextPtr, 128)))))
            hash := or(hash, shl(16, byte(0, mload(add(nextPtr, 129)))))
            hash := or(hash, shl(8, byte(0, mload(add(nextPtr, 130)))))
            hash := or(hash, byte(0, mload(add(nextPtr, 131))))
            mstore(add(coreState_, 0x60), hash) // bondInstructionsHash
        }

        return (proposal_, coreState_);
    }
}
