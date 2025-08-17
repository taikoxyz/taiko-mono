// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "./LibPackUnpack.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibProposedEventCodec
/// @notice Library for encoding and decoding Proposal and CoreState structures using compact
/// encoding
/// @custom:security-contact security@taiko.xyz
library LibProposedEventCodec {
    /// @notice Encodes a Proposal and CoreState into bytes using compact encoding
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return encoded_ The encoded bytes
    function encode(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = calculateProposedEventSize(_proposal.blobSlice.blobHashes.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibPackUnpack.dataPtr(encoded_);

        // Encode Proposal
        ptr = LibPackUnpack.packUint48(ptr, _proposal.id);
        ptr = LibPackUnpack.packAddress(ptr, _proposal.proposer);
        ptr = LibPackUnpack.packUint48(ptr, _proposal.originTimestamp);
        ptr = LibPackUnpack.packUint48(ptr, _proposal.originBlockNumber);
        ptr = LibPackUnpack.packUint8(ptr, _proposal.isForcedInclusion ? 1 : 0);
        ptr = LibPackUnpack.packUint8(ptr, _proposal.basefeeSharingPctg);

        // Encode BlobSlice
        // First encode the length of blobHashes array as uint24
        uint256 blobHashesLength = _proposal.blobSlice.blobHashes.length;
        require(blobHashesLength <= type(uint24).max);
        ptr = LibPackUnpack.packUint24(ptr, uint24(blobHashesLength));

        // Encode each blob hash
        for (uint256 i = 0; i < blobHashesLength; i++) {
            ptr = LibPackUnpack.packBytes32(ptr, _proposal.blobSlice.blobHashes[i]);
        }

        ptr = LibPackUnpack.packUint24(ptr, _proposal.blobSlice.offset);
        ptr = LibPackUnpack.packUint48(ptr, _proposal.blobSlice.timestamp);

        ptr = LibPackUnpack.packBytes32(ptr, _proposal.coreStateHash);

        // Encode CoreState
        ptr = LibPackUnpack.packUint48(ptr, _coreState.nextProposalId);
        ptr = LibPackUnpack.packUint48(ptr, _coreState.lastFinalizedProposalId);
        ptr = LibPackUnpack.packBytes32(ptr, _coreState.lastFinalizedClaimHash);
        ptr = LibPackUnpack.packBytes32(ptr, _coreState.bondInstructionsHash);
    }

    /// @notice Decodes bytes into a Proposal and CoreState using compact encoding
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibPackUnpack.dataPtr(_data);

        // Decode Proposal
        (proposal_.id, ptr) = LibPackUnpack.unpackUint48(ptr);
        (proposal_.proposer, ptr) = LibPackUnpack.unpackAddress(ptr);
        (proposal_.originTimestamp, ptr) = LibPackUnpack.unpackUint48(ptr);
        (proposal_.originBlockNumber, ptr) = LibPackUnpack.unpackUint48(ptr);

        uint8 isForcedInclusion;
        (isForcedInclusion, ptr) = LibPackUnpack.unpackUint8(ptr);
        proposal_.isForcedInclusion = isForcedInclusion != 0;

        (proposal_.basefeeSharingPctg, ptr) = LibPackUnpack.unpackUint8(ptr);

        // Decode BlobSlice
        uint24 blobHashesLength;
        (blobHashesLength, ptr) = LibPackUnpack.unpackUint24(ptr);

        proposal_.blobSlice.blobHashes = new bytes32[](blobHashesLength);
        for (uint256 i = 0; i < blobHashesLength; i++) {
            (proposal_.blobSlice.blobHashes[i], ptr) = LibPackUnpack.unpackBytes32(ptr);
        }

        (proposal_.blobSlice.offset, ptr) = LibPackUnpack.unpackUint24(ptr);
        (proposal_.blobSlice.timestamp, ptr) = LibPackUnpack.unpackUint48(ptr);

        (proposal_.coreStateHash, ptr) = LibPackUnpack.unpackBytes32(ptr);

        // Decode CoreState
        (coreState_.nextProposalId, ptr) = LibPackUnpack.unpackUint48(ptr);
        (coreState_.lastFinalizedProposalId, ptr) = LibPackUnpack.unpackUint48(ptr);
        (coreState_.lastFinalizedClaimHash, ptr) = LibPackUnpack.unpackBytes32(ptr);
        (coreState_.bondInstructionsHash, ptr) = LibPackUnpack.unpackBytes32(ptr);
    }

    /// @notice Calculate the exact byte size needed for encoding a ProposedEvent
    /// @param _blobHashesCount Number of blob hashes (max 16777215 due to uint24 encoding)
    /// @return size_ The total byte size needed for encoding
    function calculateProposedEventSize(uint256 _blobHashesCount)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 160 bytes
            // Proposal: id(6) + proposer(20) + originTimestamp(6) + originBlockNumber(6) +
            //           isForcedInclusion(1) + basefeeSharingPctg(1) = 40
            // BlobSlice: arrayLength(3) + offset(3) + timestamp(6) = 12
            // coreStateHash: 32
            // CoreState: nextProposalId(6) + lastFinalizedProposalId(6) +
            //           lastFinalizedClaimHash(32) + bondInstructionsHash(32) = 76
            // Total fixed: 40 + 12 + 32 + 76 = 160

            // Variable size: each blob hash is 32 bytes
            size_ = 160 + (_blobHashesCount * 32);
        }
    }
}
