// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibCodec
/// @notice Library for encoding and decoding event data for gas optimization using assembly
/// @dev Array lengths are encoded as uint24 (3 bytes) to support up to 16,777,215 elements while maintaining gas efficiency.
/// This provides a good balance between array size capacity and storage efficiency compared to uint16 (65,535 max) or uint32 (4 bytes).
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data using super-optimized direct encoding
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return The encoded data as bytes
    /// @dev Blob hashes array length is encoded as uint24 (3 bytes)
    function encodeProposedEventData(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory)
    {
        // Inline encoding with minimal overhead - avoid intermediate variables
        bytes32[] memory hashes = _proposal.blobSlice.blobHashes;

        // Direct encoding using concatenation to minimize gas
        assembly {
            let len := mload(hashes)
            let totalSize := add(183, shl(5, len)) // 183 + len * 32

            let result := mload(0x40)
            mstore(result, totalSize)
            mstore(0x40, add(add(result, 0x20), totalSize))

            let ptr := add(result, 0x20)

            // Use mstore to write 32-byte chunks efficiently
            // Write fixed fields first (most gas efficient)
            mstore(ptr, or(shl(208, mload(_proposal)), shl(88, mload(add(_proposal, 0x20)))))

            let ptr2 := add(ptr, 0x20)
            mstore(
                ptr2,
                or(
                    or(shl(208, mload(add(_proposal, 0x40))), shl(160, mload(add(_proposal, 0x60)))),
                    or(
                        shl(152, mload(add(_proposal, 0x80))),
                        or(shl(144, mload(add(_proposal, 0xA0))), shl(120, len)) // len as uint24
                    )
                )
            )

            // Copy blob hashes in one tight loop
            let hashPtr := add(hashes, 0x20)
            let destPtr := add(ptr, 0x40)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(add(destPtr, shl(5, i)), mload(add(hashPtr, shl(5, i))))
            }

            // Write remaining fields as words
            let finalPtr := add(destPtr, shl(5, len))
            let blobSlicePtr := add(_proposal, 0xC0)

            mstore(
                finalPtr,
                or(
                    shl(232, mload(add(blobSlicePtr, 0x20))),
                    shl(184, mload(add(blobSlicePtr, 0x40)))
                )
            )
            mstore(add(finalPtr, 0x20), mload(add(blobSlicePtr, 0x60))) // coreStateHash
            mstore(add(finalPtr, 0x40), mload(_coreState))
            mstore(add(finalPtr, 0x60), mload(add(_coreState, 0x20)))
            mstore(add(finalPtr, 0x80), mload(add(_coreState, 0x40)))
            mstore(add(finalPtr, 0xA0), mload(add(_coreState, 0x60)))

            return(result, add(0x20, totalSize))
        }
    }

    /// @dev Encodes the proved event data using super-optimized direct encoding
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data as bytes
    /// @dev Bond instructions array length is encoded as uint24 (3 bytes)
    function encodeProveEventData(IInbox.ClaimRecord memory _claimRecord)
        internal
        pure
        returns (bytes memory)
    {
        // Ultra-fast encoding: use only essential assembly operations
        LibBonds.BondInstruction[] memory bonds = _claimRecord.bondInstructions;

        assembly {
            let bondsLen := mload(bonds)
            let totalSize := add(184, mul(bondsLen, 47))

            let result := mload(0x40)
            mstore(result, totalSize)
            mstore(0x40, add(add(result, 0x20), totalSize))

            let ptr := add(result, 0x20)
            let claimPtr := _claimRecord // Direct struct access

            // Write claim fields directly as 32-byte words (most efficient)
            // First word: proposalId + part of proposalHash
            mstore(ptr, or(shl(208, mload(claimPtr)), shr(48, mload(add(claimPtr, 0x20)))))

            // Remaining claim fields in sequence
            mstore(
                add(ptr, 0x20),
                or(shl(208, mload(add(claimPtr, 0x20))), shr(48, mload(add(claimPtr, 0x40))))
            )
            mstore(add(ptr, 0x40), mload(add(claimPtr, 0x40))) // parentClaimHash

            let ptr2 := add(ptr, 0x60)
            mstore(
                ptr2, or(shl(208, mload(add(claimPtr, 0x60))), shr(48, mload(add(claimPtr, 0x80))))
            )
            mstore(add(ptr2, 0x20), mload(add(claimPtr, 0x80))) // endBlockHash
            mstore(add(ptr2, 0x40), mload(add(claimPtr, 0xA0))) // endStateRoot

            let ptr3 := add(ptr2, 0x60)
            // Addresses + span + bondsLen
            mstore(ptr3, or(shl(96, mload(add(claimPtr, 0xC0))), mload(add(claimPtr, 0xE0))))
            mstore(
                add(ptr3, 0x20),
                or(or(shl(248, mload(add(_claimRecord, 0x20))), shl(232, bondsLen)), 0) // bondsLen as uint24
            )

            // Fast bond instructions encoding - minimize operations
            let bondsPtr := add(bonds, 0x20)
            let bondDest := add(ptr3, 0x40)

            for { let i := 0 } lt(i, bondsLen) { i := add(i, 1) } {
                let bondPtr := add(bondsPtr, mul(i, 0x80))
                let destOffset := add(bondDest, mul(i, 47))

                // Pack instruction in minimal operations
                mstore(
                    destOffset,
                    or(
                        or(shl(208, mload(bondPtr)), shl(200, mload(add(bondPtr, 0x20)))),
                        shr(96, mload(add(bondPtr, 0x40)))
                    )
                )
                mstore(
                    add(destOffset, 0x20),
                    or(shl(96, mload(add(bondPtr, 0x40))), mload(add(bondPtr, 0x60)))
                )
            }

            return(result, add(0x20, totalSize))
        }
    }

    /// @dev Decodes the proposed event data that was encoded using abi.encodePacked
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    /// @dev Blob hashes array length is decoded from uint24 (3 bytes)
    function decodeProposedEventData(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        if (_data.length < 183) revert INVALID_DATA_LENGTH();

        uint256 offset = 0;

        // Decode basic proposal fields
        proposal_.id = uint48(
            uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
        );
        offset += 6;

        proposal_.proposer = address(bytes20(_extractBytes(_data, offset, 20)));
        offset += 20;

        proposal_.originTimestamp = uint48(
            uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
        );
        offset += 6;

        proposal_.originBlockNumber = uint48(
            uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
        );
        offset += 6;

        proposal_.isForcedInclusion = _data[offset] != 0;
        offset += 1;

        proposal_.basefeeSharingPctg = uint8(_data[offset]);
        offset += 1;

        // Decode blob slice - array length encoded as uint24 (3 bytes)
        uint24 blobHashesLen = uint24(
            uint256(uint8(_data[offset])) << 16 | uint256(uint8(_data[offset + 1])) << 8 | uint256(uint8(_data[offset + 2]))
        );
        offset += 3;

        bytes32[] memory blobHashes = new bytes32[](blobHashesLen);
        for (uint256 i; i < blobHashesLen; ++i) {
            blobHashes[i] = bytes32(_extractBytes(_data, offset, 32));
            offset += 32;
        }

        proposal_.blobSlice.blobHashes = blobHashes;
        proposal_.blobSlice.offset = uint24(
            uint256(uint8(_data[offset])) << 16 | uint256(uint8(_data[offset + 1])) << 8
                | uint256(uint8(_data[offset + 2]))
        );
        offset += 3;

        proposal_.blobSlice.timestamp = uint48(
            uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
        );
        offset += 6;

        // Decode coreStateHash
        proposal_.coreStateHash = bytes32(_extractBytes(_data, offset, 32));
        offset += 32;

        // Decode CoreState fields
        coreState_.nextProposalId = uint48(
            uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
        );
        offset += 6;

        coreState_.lastFinalizedProposalId = uint48(
            uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
        );
        offset += 6;

        coreState_.lastFinalizedClaimHash = bytes32(_extractBytes(_data, offset, 32));
        offset += 32;

        coreState_.bondInstructionsHash = bytes32(_extractBytes(_data, offset, 32));
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    /// @dev Helper function to extract bytes from data
    function _extractBytes(
        bytes memory _data,
        uint256 _start,
        uint256 _length
    )
        private
        pure
        returns (bytes memory)
    {
        bytes memory result = new bytes(_length);
        for (uint256 i; i < _length; ++i) {
            result[i] = _data[_start + i];
        }
        return result;
    }

    /// @dev Decodes the prove event data that was encoded using abi.encodePacked
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    /// @dev Bond instructions array length is decoded from uint24 (3 bytes)
    function decodeProveEventData(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        if (_data.length < 184) revert INVALID_DATA_LENGTH();

        uint256 offset = 0;

        // Decode claim
        (IInbox.Claim memory claim, uint256 newOffset) = _decodeClaim(_data, offset);
        claimRecord_.claim = claim;
        offset = newOffset;

        // Decode span
        claimRecord_.span = uint8(_data[offset]);
        offset += 1;

        // Decode bond instructions - array length encoded as uint24 (3 bytes)
        uint24 bondInstructionsLen = uint24(
            uint256(uint8(_data[offset])) << 16 | uint256(uint8(_data[offset + 1])) << 8 | uint256(uint8(_data[offset + 2]))
        );
        offset += 3;

        claimRecord_.bondInstructions = _decodeBondInstructions(_data, offset, bondInstructionsLen);
    }

    /// @dev Helper function to decode a Claim from packed data
    function _decodeClaim(
        bytes memory _data,
        uint256 _offset
    )
        private
        pure
        returns (IInbox.Claim memory claim_, uint256 newOffset_)
    {
        newOffset_ = _offset;

        // Decode proposalId (6 bytes -> uint48)
        claim_.proposalId = uint48(
            uint256(uint8(_data[newOffset_])) << 40 | uint256(uint8(_data[newOffset_ + 1])) << 32
                | uint256(uint8(_data[newOffset_ + 2])) << 24
                | uint256(uint8(_data[newOffset_ + 3])) << 16
                | uint256(uint8(_data[newOffset_ + 4])) << 8 | uint256(uint8(_data[newOffset_ + 5]))
        );
        newOffset_ += 6;

        // Decode proposalHash
        claim_.proposalHash = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;

        // Decode parentClaimHash
        claim_.parentClaimHash = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;

        // Decode endBlockNumber (6 bytes -> uint48)
        claim_.endBlockNumber = uint48(
            uint256(uint8(_data[newOffset_])) << 40 | uint256(uint8(_data[newOffset_ + 1])) << 32
                | uint256(uint8(_data[newOffset_ + 2])) << 24
                | uint256(uint8(_data[newOffset_ + 3])) << 16
                | uint256(uint8(_data[newOffset_ + 4])) << 8 | uint256(uint8(_data[newOffset_ + 5]))
        );
        newOffset_ += 6;

        // Decode endBlockHash
        claim_.endBlockHash = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;

        // Decode endStateRoot
        claim_.endStateRoot = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;

        // Decode designatedProver (20 bytes -> address)
        claim_.designatedProver = address(bytes20(_extractBytes(_data, newOffset_, 20)));
        newOffset_ += 20;

        // Decode actualProver (20 bytes -> address)
        claim_.actualProver = address(bytes20(_extractBytes(_data, newOffset_, 20)));
        newOffset_ += 20;
    }

    /// @dev Helper function to decode bond instructions from packed data
    function _decodeBondInstructions(
        bytes memory _data,
        uint256 _offset,
        uint256 _length
    )
        private
        pure
        returns (LibBonds.BondInstruction[] memory instructions_)
    {
        instructions_ = new LibBonds.BondInstruction[](_length);

        for (uint256 i; i < _length; ++i) {
            // Decode proposalId (6 bytes -> uint48)
            instructions_[i].proposalId = uint48(
                uint256(uint8(_data[_offset])) << 40 | uint256(uint8(_data[_offset + 1])) << 32
                    | uint256(uint8(_data[_offset + 2])) << 24
                    | uint256(uint8(_data[_offset + 3])) << 16 | uint256(uint8(_data[_offset + 4])) << 8
                    | uint256(uint8(_data[_offset + 5]))
            );
            _offset += 6;

            // Decode bondType (1 byte -> uint8)
            instructions_[i].bondType = LibBonds.BondType(uint8(_data[_offset]));
            _offset += 1;

            // Decode payer (20 bytes -> address)
            instructions_[i].payer = address(bytes20(_extractBytes(_data, _offset, 20)));
            _offset += 20;

            // Decode receiver (20 bytes -> address)
            instructions_[i].receiver = address(bytes20(_extractBytes(_data, _offset, 20)));
            _offset += 20;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error INVALID_DATA_LENGTH();
}
