// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventEncoder
/// @notice Library for encoding and decoding Proposal and CoreState structures using compact
/// encoding
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
    /// @notice Encodes a Proposal, Derivation and CoreState into bytes using compact encoding
    /// @param _proposal The proposal to encode
    /// @param _derivation The derivation data to encode
    /// @param _coreState The core state to encode
    /// @return encoded_ The encoded bytes
    function encode(
        IInbox.Proposal memory _proposal,
        IInbox.Derivation memory _derivation,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = calculateProposedEventSize(_derivation.blobSlice.blobHashes.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Encode Proposal
        ptr = P.packUint48(ptr, _proposal.id);
        ptr = P.packAddress(ptr, _proposal.proposer);
        ptr = P.packUint48(ptr, _proposal.timestamp);
        ptr = P.packUint48(ptr, _derivation.originBlockNumber);
        ptr = P.packUint8(ptr, _derivation.isForcedInclusion ? 1 : 0);
        ptr = P.packUint8(ptr, _derivation.basefeeSharingPctg);

        // Encode BlobSlice
        // First encode the length of blobHashes array as uint24
        uint256 blobHashesLength = _derivation.blobSlice.blobHashes.length;
        require(blobHashesLength <= type(uint24).max, BlobHashesLengthExceeded());
        ptr = P.packUint24(ptr, uint24(blobHashesLength));

        // Encode each blob hash
        for (uint256 i; i < blobHashesLength; ++i) {
            ptr = P.packBytes32(ptr, _derivation.blobSlice.blobHashes[i]);
        }

        ptr = P.packUint24(ptr, _derivation.blobSlice.offset);
        ptr = P.packUint48(ptr, _derivation.blobSlice.timestamp);

        ptr = P.packBytes32(ptr, _proposal.coreStateHash);

        // Encode CoreState
        ptr = P.packUint48(ptr, _coreState.nextProposalId);
        ptr = P.packUint48(ptr, _coreState.lastFinalizedProposalId);
        ptr = P.packBytes32(ptr, _coreState.lastFinalizedClaimHash);
        ptr = P.packBytes32(ptr, _coreState.bondInstructionsHash);
    }

    /// @notice Decodes bytes into a Proposal, Derivation and CoreState using compact encoding
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return derivation_ The decoded derivation
    /// @return coreState_ The decoded core state
    function decode(bytes memory _data)
        internal
        pure
        returns (
            IInbox.Proposal memory proposal_,
            IInbox.Derivation memory derivation_,
            IInbox.CoreState memory coreState_
        )
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Decode Proposal
        (proposal_.id, ptr) = P.unpackUint48(ptr);
        (proposal_.proposer, ptr) = P.unpackAddress(ptr);
        (proposal_.timestamp, ptr) = P.unpackUint48(ptr);

        // Decode Derivation fields
        (derivation_.originBlockNumber, ptr) = P.unpackUint48(ptr);

        uint8 isForcedInclusion;
        (isForcedInclusion, ptr) = P.unpackUint8(ptr);
        derivation_.isForcedInclusion = isForcedInclusion != 0;

        (derivation_.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);

        // Decode BlobSlice
        uint24 blobHashesLength;
        (blobHashesLength, ptr) = P.unpackUint24(ptr);

        derivation_.blobSlice.blobHashes = new bytes32[](blobHashesLength);
        for (uint256 i; i < blobHashesLength; ++i) {
            (derivation_.blobSlice.blobHashes[i], ptr) = P.unpackBytes32(ptr);
        }

        (derivation_.blobSlice.offset, ptr) = P.unpackUint24(ptr);
        (derivation_.blobSlice.timestamp, ptr) = P.unpackUint48(ptr);

        (proposal_.coreStateHash, ptr) = P.unpackBytes32(ptr);

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
            // Proposal: id(6) + proposer(20) + timestamp(6) + originBlockNumber(6) +
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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlobHashesLengthExceeded();
}