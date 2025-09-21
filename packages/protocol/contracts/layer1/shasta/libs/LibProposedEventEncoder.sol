// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventEncoder
/// @notice Library for encoding and decoding ProposedEventPayload structures using compact
/// encoding
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
    /// @notice Encodes a ProposedEventPayload into bytes using compact encoding
    /// @param _payload The payload to encode
    /// @return encoded_ The encoded bytes
    function encode(IInbox.ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize =
            calculateProposedEventSize(_payload.derivation.blobSlice.blobHashes.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Encode Proposal
        ptr = P.packUint48(ptr, _payload.proposal.id);
        ptr = P.packAddress(ptr, _payload.proposal.proposer);
        ptr = P.packUint48(ptr, _payload.proposal.timestamp);
        ptr = P.packUint48(ptr, _payload.proposal.endOfSubmissionWindowTimestamp);
        ptr = P.packUint48(ptr, _payload.derivation.originBlockNumber);
        ptr = P.packBytes32(ptr, _payload.derivation.originBlockHash);
        ptr = P.packUint8(ptr, _payload.derivation.isForcedInclusion ? 1 : 0);
        ptr = P.packUint8(ptr, _payload.derivation.basefeeSharingPctg);

        // Encode blob slice (length + hashes + offset + timestamp)
        uint256 blobHashesLength = _payload.derivation.blobSlice.blobHashes.length;
        P.checkArrayLength(blobHashesLength);
        ptr = P.packUint24(ptr, uint24(blobHashesLength));

        // Encode each blob hash
        for (uint256 i; i < blobHashesLength; ++i) {
            ptr = P.packBytes32(ptr, _payload.derivation.blobSlice.blobHashes[i]);
        }

        ptr = P.packUint24(ptr, _payload.derivation.blobSlice.offset);
        ptr = P.packUint48(ptr, _payload.derivation.blobSlice.timestamp);

        ptr = P.packBytes32(ptr, _payload.proposal.coreStateHash);
        ptr = P.packBytes32(ptr, _payload.proposal.derivationHash);

        // Encode core state
        ptr = P.packUint48(ptr, _payload.coreState.nextProposalId);
        ptr = P.packUint48(ptr, _payload.coreState.nextProposalBlockId);
        ptr = P.packUint48(ptr, _payload.coreState.lastFinalizedProposalId);
        ptr = P.packBytes32(ptr, _payload.coreState.lastFinalizedTransitionHash);
        ptr = P.packBytes32(ptr, _payload.coreState.bondInstructionsHash);
    }

    /// @notice Decodes bytes into a ProposedEventPayload using compact encoding
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);
        ptr = _decodeProposal(payload_, ptr);
        ptr = _decodeDerivation(payload_, ptr);
        _decodeCoreState(payload_, ptr);
    }

    /// @notice Decodes proposal fields
    function _decodeProposal(
        IInbox.ProposedEventPayload memory payload_,
        uint256 ptr
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        (payload_.proposal.id, newPtr_) = P.unpackUint48(ptr);
        (payload_.proposal.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (payload_.proposal.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (payload_.proposal.endOfSubmissionWindowTimestamp, newPtr_) = P.unpackUint48(newPtr_);
    }

    /// @notice Decodes derivation fields and blob slice
    function _decodeDerivation(
        IInbox.ProposedEventPayload memory payload_,
        uint256 ptr
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        (payload_.derivation.originBlockNumber, newPtr_) = P.unpackUint48(ptr);
        (payload_.derivation.originBlockHash, newPtr_) = P.unpackBytes32(newPtr_);

        uint8 isForcedInclusion;
        (isForcedInclusion, newPtr_) = P.unpackUint8(newPtr_);
        payload_.derivation.isForcedInclusion = isForcedInclusion != 0;

        (payload_.derivation.basefeeSharingPctg, newPtr_) = P.unpackUint8(newPtr_);

        // Decode blob slice
        uint24 blobHashesLength;
        (blobHashesLength, newPtr_) = P.unpackUint24(newPtr_);

        payload_.derivation.blobSlice.blobHashes = new bytes32[](blobHashesLength);
        for (uint256 i; i < blobHashesLength; ++i) {
            (payload_.derivation.blobSlice.blobHashes[i], newPtr_) = P.unpackBytes32(newPtr_);
        }

        (payload_.derivation.blobSlice.offset, newPtr_) = P.unpackUint24(newPtr_);
        (payload_.derivation.blobSlice.timestamp, newPtr_) = P.unpackUint48(newPtr_);

        (payload_.proposal.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (payload_.proposal.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decodes core state fields
    function _decodeCoreState(
        IInbox.ProposedEventPayload memory payload_,
        uint256 ptr
    )
        private
        pure
    {
        (payload_.coreState.nextProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.coreState.nextProposalBlockId, ptr) = P.unpackUint48(ptr);
        (payload_.coreState.lastFinalizedProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.coreState.lastFinalizedTransitionHash, ptr) = P.unpackBytes32(ptr);
        (payload_.coreState.bondInstructionsHash,) = P.unpackBytes32(ptr);
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
            // Fixed size: 236 bytes
            // Proposal: id(6) + proposer(20) + timestamp(6) + endOfSubmissionWindowTimestamp(6) =
            // 38
            // Derivation: originBlockNumber(6) + originBlockHash(32) + isForcedInclusion(1) +
            // basefeeSharingPctg(1) = 40
            // BlobSlice: arrayLength(3) + offset(3) + timestamp(6) = 12
            // Proposal hashes: coreStateHash(32) + derivationHash(32) = 64
            // CoreState: nextProposalId(6) + nextProposalBlockId(6) + lastFinalizedProposalId(6) +
            //           lastFinalizedTransitionHash(32) + bondInstructionsHash(32) = 82
            // Total fixed: 38 + 40 + 12 + 64 + 82 = 236

            // Variable size: each blob hash is 32 bytes
            size_ = 236 + (_blobHashesCount * 32);
        }
    }
}
