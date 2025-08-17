// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "./LibCodec.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibProposedEventCodec
/// @notice Library for encoding and decoding event data for gas optimization using assembly
/// @dev Array lengths are encoded as uint24 (3 bytes) to support up to 16,777,215 elements while
/// maintaining gas efficiency.
/// This provides a good balance between array size capacity and storage efficiency compared to
/// uint16 (65,535 max) or uint32 (4 bytes).
/// @custom:security-contact security@taiko.xyz
library LibProposedEventCodec {
    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data using LibCodec for optimal gas efficiency
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return The encoded data as bytes
    function encode(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory)
    {
        unchecked {
            // Calculate buffer size
            uint256 size = calculateProposedEventSize(_proposal.blobSlice.blobHashes.length);
            bytes memory buffer = new bytes(size);
            uint256 pos = LibCodec.dataPtr(buffer);

            // Encode Proposal
            pos = LibCodec.packUint48(pos, _proposal.id);
            pos = LibCodec.packAddress(pos, _proposal.proposer);
            pos = LibCodec.packUint48(pos, _proposal.originTimestamp);
            pos = LibCodec.packUint48(pos, _proposal.originBlockNumber);
            pos = LibCodec.packUint8(pos, _proposal.isForcedInclusion ? 1 : 0);
            pos = LibCodec.packUint8(pos, _proposal.basefeeSharingPctg);

            // Encode BlobSlice
            // First encode the length of blobHashes array as uint24
            uint256 blobHashesLength = _proposal.blobSlice.blobHashes.length;
            pos = LibCodec.packUint24(pos, uint24(blobHashesLength));

            // Encode each blob hash
            for (uint256 i; i < blobHashesLength; ++i) {
                pos = LibCodec.packBytes32(pos, _proposal.blobSlice.blobHashes[i]);
            }

            pos = LibCodec.packUint24(pos, _proposal.blobSlice.offset);
            pos = LibCodec.packUint48(pos, _proposal.blobSlice.timestamp);

            pos = LibCodec.packBytes32(pos, _proposal.coreStateHash);

            // Encode CoreState
            pos = LibCodec.packUint48(pos, _coreState.nextProposalId);
            pos = LibCodec.packUint48(pos, _coreState.lastFinalizedProposalId);
            pos = LibCodec.packBytes32(pos, _coreState.lastFinalizedClaimHash);
            pos = LibCodec.packBytes32(pos, _coreState.bondInstructionsHash);

            return buffer;
        }
    }

    /// @dev Decodes the proposed event data using LibCodec for optimal gas efficiency
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        unchecked {
            uint256 pos = LibCodec.dataPtr(_data);

            // Decode Proposal
            (proposal_.id, pos) = LibCodec.unpackUint48(pos);
            (proposal_.proposer, pos) = LibCodec.unpackAddress(pos);
            (proposal_.originTimestamp, pos) = LibCodec.unpackUint48(pos);
            (proposal_.originBlockNumber, pos) = LibCodec.unpackUint48(pos);

            uint8 isForcedInclusion;
            (isForcedInclusion, pos) = LibCodec.unpackUint8(pos);
            proposal_.isForcedInclusion = isForcedInclusion != 0;

            (proposal_.basefeeSharingPctg, pos) = LibCodec.unpackUint8(pos);

            // Decode BlobSlice
            uint24 blobHashesLength;
            (blobHashesLength, pos) = LibCodec.unpackUint24(pos);

            proposal_.blobSlice.blobHashes = new bytes32[](blobHashesLength);
            for (uint256 i; i < blobHashesLength; ++i) {
                (proposal_.blobSlice.blobHashes[i], pos) = LibCodec.unpackBytes32(pos);
            }

            (proposal_.blobSlice.offset, pos) = LibCodec.unpackUint24(pos);
            (proposal_.blobSlice.timestamp, pos) = LibCodec.unpackUint48(pos);

            (proposal_.coreStateHash, pos) = LibCodec.unpackBytes32(pos);

            // Decode CoreState
            (coreState_.nextProposalId, pos) = LibCodec.unpackUint48(pos);
            (coreState_.lastFinalizedProposalId, pos) = LibCodec.unpackUint48(pos);
            (coreState_.lastFinalizedClaimHash, pos) = LibCodec.unpackBytes32(pos);
            (coreState_.bondInstructionsHash, pos) = LibCodec.unpackBytes32(pos);
        }
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    /// @dev Calculate the exact byte size needed for encoding a ProposedEvent
    function calculateProposedEventSize(uint256 _blobHashesCount)
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Proposal fields:
            size_ = 6; // id (uint48)
            size_ += 20; // proposer (address)
            size_ += 6; // originTimestamp (uint48)
            size_ += 6; // originBlockNumber (uint48)
            size_ += 1; // isForcedInclusion (uint8 as bool)
            size_ += 1; // basefeeSharingPctg (uint8)

            // BlobSlice fields:
            size_ += 3; // blobHashes array length (uint24)
            size_ += _blobHashesCount * 32; // each blob hash is bytes32
            size_ += 3; // offset (uint24)
            size_ += 6; // timestamp (uint48)

            size_ += 32; // coreStateHash (bytes32)

            // CoreState fields:
            size_ += 6; // nextProposalId (uint48)
            size_ += 6; // lastFinalizedProposalId (uint48)
            size_ += 32; // lastFinalizedClaimHash (bytes32)
            size_ += 32; // bondInstructionsHash (bytes32)
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error INVALID_DATA_LENGTH();
}
