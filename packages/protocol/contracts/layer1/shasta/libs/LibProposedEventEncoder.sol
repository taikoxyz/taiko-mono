// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventEncoder
/// @notice Library for encoding and decoding Proposal and CoreState structures using compact
/// encoding. Fields are reordered during encoding to pack smaller fields together within
/// 32-byte boundaries, minimizing the number of storage slots accessed and reducing gas costs.
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
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
        uint256 ptr = P.dataPtr(encoded_);

        // Encode Proposal - pack small fields together: id(6) + originTimestamp(6) +
        // originBlockNumber(6) + isForcedInclusion(1) + basefeeSharingPctg(1) = 20 bytes
        ptr = P.packUint48(ptr, _proposal.id);
        ptr = P.packUint48(ptr, _proposal.originTimestamp);
        ptr = P.packUint48(ptr, _proposal.originBlockNumber);
        ptr = P.packUint8(ptr, _proposal.isForcedInclusion ? 1 : 0);
        ptr = P.packUint8(ptr, _proposal.basefeeSharingPctg);

        // Pack address separately (20 bytes)
        ptr = P.packAddress(ptr, _proposal.proposer);

        // Pack coreStateHash (bytes32)
        ptr = P.packBytes32(ptr, _proposal.coreStateHash);

        // Encode BlobSlice - pack small fields together
        uint256 blobHashesLength = _proposal.blobSlice.blobHashes.length;
        require(blobHashesLength <= type(uint24).max, BlobHashesLengthExceeded());
        // Pack: arrayLength(3) + offset(3) + timestamp(6) = 12 bytes
        ptr = P.packUint24(ptr, uint24(blobHashesLength));
        ptr = P.packUint24(ptr, _proposal.blobSlice.offset);
        ptr = P.packUint48(ptr, _proposal.blobSlice.timestamp);

        // Encode each blob hash
        for (uint256 i; i < blobHashesLength; ++i) {
            ptr = P.packBytes32(ptr, _proposal.blobSlice.blobHashes[i]);
        }

        // Encode CoreState
        ptr = P.packUint48(ptr, _coreState.nextProposalId);
        ptr = P.packUint48(ptr, _coreState.lastFinalizedProposalId);
        ptr = P.packBytes32(ptr, _coreState.lastFinalizedClaimHash);
        ptr = P.packBytes32(ptr, _coreState.bondInstructionsHash);
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
        uint256 ptr = P.dataPtr(_data);

        // Decode Proposal - unpack small fields together: id(6) + originTimestamp(6) +
        // originBlockNumber(6) + isForcedInclusion(1) + basefeeSharingPctg(1) = 20 bytes
        (proposal_.id, ptr) = P.unpackUint48(ptr);
        (proposal_.originTimestamp, ptr) = P.unpackUint48(ptr);
        (proposal_.originBlockNumber, ptr) = P.unpackUint48(ptr);

        uint8 isForcedInclusion;
        (isForcedInclusion, ptr) = P.unpackUint8(ptr);
        proposal_.isForcedInclusion = isForcedInclusion != 0;

        (proposal_.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);

        // Unpack address separately (20 bytes)
        (proposal_.proposer, ptr) = P.unpackAddress(ptr);

        // Unpack coreStateHash (bytes32)
        (proposal_.coreStateHash, ptr) = P.unpackBytes32(ptr);

        // Decode BlobSlice - unpack small fields together: arrayLength(3) + offset(3) +
        // timestamp(6) = 12 bytes
        uint24 blobHashesLength;
        (blobHashesLength, ptr) = P.unpackUint24(ptr);
        (proposal_.blobSlice.offset, ptr) = P.unpackUint24(ptr);
        (proposal_.blobSlice.timestamp, ptr) = P.unpackUint48(ptr);

        // Decode blob hashes
        proposal_.blobSlice.blobHashes = new bytes32[](blobHashesLength);
        for (uint256 i; i < blobHashesLength; ++i) {
            (proposal_.blobSlice.blobHashes[i], ptr) = P.unpackBytes32(ptr);
        }

        // Decode CoreState
        (coreState_.nextProposalId, ptr) = P.unpackUint48(ptr);
        (coreState_.lastFinalizedProposalId, ptr) = P.unpackUint48(ptr);
        (coreState_.lastFinalizedClaimHash, ptr) = P.unpackBytes32(ptr);
        (coreState_.bondInstructionsHash, ptr) = P.unpackBytes32(ptr);
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
            // Proposal: id(6) + originTimestamp(6) + originBlockNumber(6) + isForcedInclusion(1) +
            // basefeeSharingPctg(1) = 20
            //           proposer(20) + coreStateHash(32) = 52
            // BlobSlice: arrayLength(3) + offset(3) + timestamp(6) = 12
            // CoreState: nextProposalId(6) + lastFinalizedProposalId(6) +
            //           lastFinalizedClaimHash(32) + bondInstructionsHash(32) = 76
            // Total fixed: 20 + 52 + 12 + 76 = 160

            // Variable size: each blob hash is 32 bytes
            size_ = 160 + (_blobHashesCount * 32);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlobHashesLengthExceeded();
}
