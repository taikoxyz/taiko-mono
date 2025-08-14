// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibCodec
/// @notice Library for encoding and decoding event data for gas optimization
/// @dev Array lengths are encoded as uint24 (3 bytes) to support up to 16,777,215 elements while
/// maintaining gas efficiency. This provides a good balance between array size capacity and storage
/// efficiency compared to uint16 (65,535 max) or uint32 (4 bytes).
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data using gas-optimized packed encoding
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
        // Use bytes.concat with abi.encodePacked for maximum gas efficiency
        unchecked {
            bytes memory proposalBytes = abi.encodePacked(
                _proposal.id,
                _proposal.proposer,
                _proposal.originTimestamp,
                _proposal.originBlockNumber,
                _proposal.isForcedInclusion,
                _proposal.basefeeSharingPctg,
                uint24(_proposal.blobSlice.blobHashes.length)
            );

            // Add blob hashes
            uint256 hashesLength = _proposal.blobSlice.blobHashes.length;
            for (uint256 i = 0; i < hashesLength; ++i) {
                proposalBytes = bytes.concat(proposalBytes, _proposal.blobSlice.blobHashes[i]);
            }

            // Add remaining proposal fields
            proposalBytes = bytes.concat(
                proposalBytes,
                abi.encodePacked(
                    _proposal.blobSlice.offset,
                    _proposal.blobSlice.timestamp,
                    _proposal.coreStateHash
                )
            );

            // Add core state
            bytes memory coreStateBytes = abi.encodePacked(
                _coreState.nextProposalId,
                _coreState.lastFinalizedProposalId,
                _coreState.lastFinalizedClaimHash,
                _coreState.bondInstructionsHash
            );

            return bytes.concat(proposalBytes, coreStateBytes);
        }
    }

    /// @dev Encodes the proved event data using gas-optimized packed encoding
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data as bytes
    /// @dev Bond instructions array length is encoded as uint24 (3 bytes)
    function encodeProveEventData(IInbox.ClaimRecord memory _claimRecord)
        internal
        pure
        returns (bytes memory)
    {
        // Use bytes.concat with abi.encodePacked for maximum gas efficiency
        unchecked {
            bytes memory claimRecordBytes = abi.encodePacked(
                _claimRecord.proposalId,
                _claimRecord.claim.proposalHash,
                _claimRecord.claim.parentClaimHash,
                _claimRecord.claim.endBlockNumber,
                _claimRecord.claim.endBlockHash,
                _claimRecord.claim.endStateRoot,
                _claimRecord.claim.designatedProver,
                _claimRecord.claim.actualProver,
                _claimRecord.span,
                uint24(_claimRecord.bondInstructions.length)
            );

            // Add bond instructions
            uint256 bondInstructionsLength = _claimRecord.bondInstructions.length;
            for (uint256 i = 0; i < bondInstructionsLength; ++i) {
                claimRecordBytes = bytes.concat(
                    claimRecordBytes,
                    abi.encodePacked(
                        _claimRecord.bondInstructions[i].proposalId,
                        uint8(_claimRecord.bondInstructions[i].bondType),
                        _claimRecord.bondInstructions[i].payer,
                        _claimRecord.bondInstructions[i].receiver
                    )
                );
            }

            return claimRecordBytes;
        }
    }

    /// @dev Decodes the proposed event data that was encoded using packed encoding
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decodeProposedEventData(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        if (_data.length < 183) revert INVALID_DATA_LENGTH();

        unchecked {
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
                uint256(uint8(_data[offset])) << 16 | uint256(uint8(_data[offset + 1])) << 8
                    | uint256(uint8(_data[offset + 2]))
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
        unchecked {
            bytes memory result = new bytes(_length);
            for (uint256 i; i < _length; ++i) {
                result[i] = _data[_start + i];
            }
            return result;
        }
    }

    /// @dev Decodes the prove event data that was encoded using packed encoding
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    /// @dev Bond instructions array length is decoded from uint24 (3 bytes)
    function decodeProveEventData(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        if (_data.length < 184) revert INVALID_DATA_LENGTH();

        unchecked {
            uint256 offset = 0;

            // Decode proposalId (6 bytes -> uint48) - now in ClaimRecord
            claimRecord_.proposalId = uint48(
                uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32
                    | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16
                    | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5]))
            );
            offset += 6;

            // Decode claim
            (IInbox.Claim memory claim, uint256 newOffset) = _decodeClaim(_data, offset);
            claimRecord_.claim = claim;
            offset = newOffset;

            // Decode span
            claimRecord_.span = uint8(_data[offset]);
            offset += 1;

            // Decode bond instructions - array length encoded as uint24 (3 bytes)
            uint24 bondInstructionsLen = uint24(
                uint256(uint8(_data[offset])) << 16 | uint256(uint8(_data[offset + 1])) << 8
                    | uint256(uint8(_data[offset + 2]))
            );
            offset += 3;

            claimRecord_.bondInstructions =
                _decodeBondInstructions(_data, offset, bondInstructionsLen);
        }
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
        unchecked {
            newOffset_ = _offset;

            // proposalId is no longer in Claim, skip directly to proposalHash
            // Decode proposalHash
            claim_.proposalHash = bytes32(_extractBytes(_data, newOffset_, 32));
            newOffset_ += 32;

            // Decode parentClaimHash
            claim_.parentClaimHash = bytes32(_extractBytes(_data, newOffset_, 32));
            newOffset_ += 32;

            // Decode endBlockNumber (6 bytes -> uint48)
            claim_.endBlockNumber = uint48(
                uint256(uint8(_data[newOffset_])) << 40
                    | uint256(uint8(_data[newOffset_ + 1])) << 32
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
        unchecked {
            instructions_ = new LibBonds.BondInstruction[](_length);

            for (uint256 i; i < _length; ++i) {
                // Decode proposalId (6 bytes -> uint48)
                instructions_[i].proposalId = uint48(
                    uint256(uint8(_data[_offset])) << 40 | uint256(uint8(_data[_offset + 1])) << 32
                        | uint256(uint8(_data[_offset + 2])) << 24
                        | uint256(uint8(_data[_offset + 3])) << 16
                        | uint256(uint8(_data[_offset + 4])) << 8 | uint256(uint8(_data[_offset + 5]))
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
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error INVALID_DATA_LENGTH();
}
