// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibProposalCoreStateCodec
/// @notice Fully optimized codec applying all proven optimization techniques
/// @dev Optimizations applied:
/// - unchecked blocks for safe arithmetic
/// - bit shifts instead of multiplication
/// - loop unrolling for small arrays
/// - cached memory pointers
/// - combined operations where possible
/// @custom:security-contact security@taiko.xyz
library LibProposalCoreStateCodec{
    // ---------------------------------------------------------------
    // Constants for field validation (based on annotations)
    // ---------------------------------------------------------------

    uint256 private constant MAX_BASEFEE_PCTG = 100;
    uint256 private constant MAX_BLOB_HASHES = 64;

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error INVALID_DATA_LENGTH();
    error BASEFEE_SHARING_PCTG_EXCEEDS_MAX();
    error BLOB_HASHES_ARRAY_EXCEEDS_MAX();

    // ---------------------------------------------------------------
    // Optimized encoding function
    // ---------------------------------------------------------------

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

        // Calculate total size with unchecked and bit shift
        uint256 size;
        unchecked {
            size = 158 + (hashCount << 5); // bit shift for *32
        }
        
        bytes memory result = new bytes(size);

        assembly ("memory-safe") {
            let ptr := add(result, 0x20)
            let p := _proposal
            
            // Cache frequently accessed pointers
            let p20 := add(p, 0x20)
            let p40 := add(p, 0x40)
            let p60 := add(p, 0x60)
            let p80 := add(p, 0x80)
            let pa0 := add(p, 0xa0)
            let pc0 := add(p, 0xc0)
            let pe0 := add(p, 0xe0)
            
            let b := mload(pc0) // blobSlice pointer
            let b20 := add(b, 0x20)
            let b40 := add(b, 0x40)

            // Store id (6 bytes) and proposer (20 bytes) in one word
            let word := or(shl(208, mload(p)), shl(48, mload(p20)))
            mstore(ptr, word)

            // Store timestamps and block number (6+6+6 bytes) - cached pointers
            word := or(
                shl(208, mload(p40)), // originTimestamp
                or(shl(160, mload(p60)), shl(112, mload(p80))) // originBlockNumber + isForcedInclusion start
            )
            mstore(add(ptr, 26), word)

            // Store bools and array length
            let ptr38 := add(ptr, 38)
            mstore8(ptr38, mload(p80)) // isForcedInclusion
            mstore8(add(ptr38, 1), mload(pa0)) // basefeeSharingPctg

            // Store array length (3 bytes)
            let len := mload(mload(b))
            let lenWord := shl(232, len)
            mstore(add(ptr38, 2), lenWord)

            // Copy blob hashes with loop unrolling for small arrays
            let src := add(mload(b), 0x20)
            let dst := add(ptr, 43)
            
            // Unroll for common small sizes (1-4 hashes)
            if lt(len, 5) {
                if iszero(iszero(len)) {
                    mstore(dst, mload(src))
                    if gt(len, 1) {
                        mstore(add(dst, 32), mload(add(src, 32)))
                        if gt(len, 2) {
                            mstore(add(dst, 64), mload(add(src, 64)))
                            if gt(len, 3) {
                                mstore(add(dst, 96), mload(add(src, 96)))
                            }
                        }
                    }
                }
                dst := add(dst, shl(5, len)) // bit shift for *32
            }
            
            // Regular loop for larger arrays (5+ hashes)
            if gt(len, 4) {
                let end := add(src, shl(5, len)) // bit shift for *32
                for { } lt(src, end) { } {
                    mstore(dst, mload(src))
                    src := add(src, 32)
                    dst := add(dst, 32)
                }
            }

            // Store remaining BlobSlice fields - use cached pointers
            let nextPtr := add(add(ptr, 43), shl(5, len)) // bit shift for *32
            word := or(shl(232, mload(b20)), shl(184, mload(b40))) // offset (3 bytes) + timestamp (6 bytes)
            mstore(nextPtr, word)

            // Store coreStateHash - cached pointer
            mstore(add(nextPtr, 9), mload(pe0))

            // Store CoreState fields with cached pointers
            let c := _coreState
            let c20 := add(c, 0x20)
            let c40 := add(c, 0x40)
            let c60 := add(c, 0x60)
            
            let finalPtr := add(nextPtr, 41)

            // Pack nextProposalId and lastFinalizedProposalId
            word := or(shl(208, mload(c)), shl(160, mload(c20)))
            mstore(finalPtr, word)

            // Store hashes - cached pointers
            mstore(add(finalPtr, 12), mload(c40)) // lastFinalizedClaimHash
            mstore(add(finalPtr, 44), mload(c60)) // bondInstructionsHash
        }

        return result;
    }

    // ---------------------------------------------------------------
    // Optimized decoding function
    // ---------------------------------------------------------------

    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        if (_data.length < 158) revert INVALID_DATA_LENGTH();

        assembly ("memory-safe") {
            let ptr := add(_data, 0x20)
            
            // Cache proposal memory locations
            let p20 := add(proposal_, 0x20)
            let p40 := add(proposal_, 0x40)
            let p60 := add(proposal_, 0x60)
            let p80 := add(proposal_, 0x80)
            let pa0 := add(proposal_, 0xa0)
            let pc0 := add(proposal_, 0xc0)
            let pe0 := add(proposal_, 0xe0)

            // Read first word containing id and proposer
            let word := mload(ptr)
            mstore(proposal_, shr(208, word)) // id (6 bytes)
            mstore(p20, and(shr(48, word), 0xffffffffffffffffffffffffffffffffffffffff)) // proposer (20 bytes)

            // Read timestamps and block number - use cached pointers
            let ptr26 := add(ptr, 26)
            word := mload(ptr26)
            mstore(p40, shr(208, word)) // originTimestamp (6 bytes)
            mstore(p60, and(shr(160, word), 0xffffffffffff)) // originBlockNumber (6 bytes)

            // Read booleans - cached pointer
            let ptr38 := add(ptr, 38)
            mstore(p80, byte(0, mload(ptr38))) // isForcedInclusion
            mstore(pa0, byte(0, mload(add(ptr38, 1)))) // basefeeSharingPctg

            // Decode BlobSlice
            let blobSlice := mload(0x40)
            mstore(0x40, add(blobSlice, 0x60))
            mstore(pc0, blobSlice)

            // Read array length (3 bytes)
            let arrayLen := shr(232, mload(add(ptr38, 2)))
            let hashArray := mload(0x40)
            mstore(hashArray, arrayLen)
            
            // Use bit shift for memory allocation
            unchecked {
                let newFreePtr := add(hashArray, shl(5, add(arrayLen, 1))) // bit shift for *32
                mstore(0x40, newFreePtr)
            }
            mstore(blobSlice, hashArray)

            // Copy blob hashes with loop unrolling
            let src := add(ptr, 43)
            let dst := add(hashArray, 0x20)
            
            // Unroll for small arrays
            if lt(arrayLen, 5) {
                if iszero(iszero(arrayLen)) {
                    mstore(dst, mload(src))
                    if gt(arrayLen, 1) {
                        mstore(add(dst, 32), mload(add(src, 32)))
                        if gt(arrayLen, 2) {
                            mstore(add(dst, 64), mload(add(src, 64)))
                            if gt(arrayLen, 3) {
                                mstore(add(dst, 96), mload(add(src, 96)))
                            }
                        }
                    }
                }
                src := add(src, shl(5, arrayLen)) // bit shift for *32
            }
            
            // Regular loop for larger arrays
            if gt(arrayLen, 4) {
                let end := add(src, shl(5, arrayLen)) // bit shift for *32
                for { } lt(src, end) { } {
                    mstore(dst, mload(src))
                    src := add(src, 32)
                    dst := add(dst, 0x20)
                }
            }

            // Read remaining BlobSlice fields - calculate with bit shift
            let nextPtr := add(add(ptr, 43), shl(5, arrayLen))
            word := mload(nextPtr)
            mstore(add(blobSlice, 0x20), shr(232, word)) // offset (3 bytes)
            mstore(add(blobSlice, 0x40), and(shr(184, word), 0xffffffffffff)) // timestamp (6 bytes)

            // Read coreStateHash - cached pointer
            mstore(pe0, mload(add(nextPtr, 9)))

            // Decode CoreState with cached pointers
            let finalPtr := add(nextPtr, 41)
            word := mload(finalPtr)
            
            let c20 := add(coreState_, 0x20)
            let c40 := add(coreState_, 0x40)
            let c60 := add(coreState_, 0x60)
            
            mstore(coreState_, shr(208, word)) // nextProposalId (6 bytes)
            mstore(c20, and(shr(160, word), 0xffffffffffff)) // lastFinalizedProposalId (6 bytes)

            // Read hashes - cached pointers
            mstore(c40, mload(add(finalPtr, 12))) // lastFinalizedClaimHash
            mstore(c60, mload(add(finalPtr, 44))) // bondInstructionsHash
        }

        return (proposal_, coreState_);
    }
}