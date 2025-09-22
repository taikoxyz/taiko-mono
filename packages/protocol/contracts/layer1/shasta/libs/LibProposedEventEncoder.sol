// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventEncoder
/// @notice Library for encoding and decoding ProposedEventPayload structures using compact
/// encoding
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Decodes bytes into a ProposedEventPayload using compact encoding
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    function decode(bytes memory _data)
        public
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Decode Proposal
        (payload_.proposal.id, ptr) = P.unpackUint48(ptr);
        (payload_.proposal.proposer, ptr) = P.unpackAddress(ptr);
        (payload_.proposal.timestamp, ptr) = P.unpackUint48(ptr);
        (payload_.proposal.endOfSubmissionWindowTimestamp, ptr) = P.unpackUint48(ptr);

        // Decode derivation fields
        (payload_.derivation.originBlockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.derivation.originBlockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.derivation.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);

        // Decode sources array length
        uint24 sourcesLength;
        (sourcesLength, ptr) = P.unpackUint24(ptr);

        payload_.derivation.sources = new IInbox.DerivationSource[](sourcesLength);
        for (uint256 i; i < sourcesLength; ++i) {
            uint8 isForcedInclusion;
            (isForcedInclusion, ptr) = P.unpackUint8(ptr);
            payload_.derivation.sources[i].isForcedInclusion = isForcedInclusion != 0;

            // Decode blob slice for this source
            uint24 blobHashesLength;
            (blobHashesLength, ptr) = P.unpackUint24(ptr);

            payload_.derivation.sources[i].blobSlice.blobHashes = new bytes32[](blobHashesLength);
            for (uint256 j; j < blobHashesLength; ++j) {
                (payload_.derivation.sources[i].blobSlice.blobHashes[j], ptr) = P.unpackBytes32(ptr);
            }

            (payload_.derivation.sources[i].blobSlice.offset, ptr) = P.unpackUint24(ptr);
            (payload_.derivation.sources[i].blobSlice.timestamp, ptr) = P.unpackUint48(ptr);
        }

        (payload_.proposal.coreStateHash, ptr) = P.unpackBytes32(ptr);
        (payload_.proposal.derivationHash, ptr) = P.unpackBytes32(ptr);

        // Decode core state
        (payload_.coreState.nextProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.coreState.nextProposalBlockId, ptr) = P.unpackUint48(ptr);
        (payload_.coreState.lastFinalizedProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.coreState.lastFinalizedTransitionHash, ptr) = P.unpackBytes32(ptr);
        (payload_.coreState.bondInstructionsHash, ptr) = P.unpackBytes32(ptr);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposedEventPayload into bytes using compact encoding
    /// @param _payload The payload to encode
    /// @return encoded_ The encoded bytes
    function encode(IInbox.ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = calculateProposedEventSize(_payload.derivation.sources);
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
        ptr = P.packUint8(ptr, _payload.derivation.basefeeSharingPctg);

        // Encode sources array length
        uint256 sourcesLength = _payload.derivation.sources.length;
        P.checkArrayLength(sourcesLength);
        ptr = P.packUint24(ptr, uint24(sourcesLength));

        // Encode each source
        for (uint256 i; i < sourcesLength; ++i) {
            ptr = P.packUint8(ptr, _payload.derivation.sources[i].isForcedInclusion ? 1 : 0);

            // Encode blob slice for this source
            uint256 blobHashesLength = _payload.derivation.sources[i].blobSlice.blobHashes.length;
            P.checkArrayLength(blobHashesLength);
            ptr = P.packUint24(ptr, uint24(blobHashesLength));

            // Encode each blob hash
            for (uint256 j; j < blobHashesLength; ++j) {
                ptr = P.packBytes32(ptr, _payload.derivation.sources[i].blobSlice.blobHashes[j]);
            }

            ptr = P.packUint24(ptr, _payload.derivation.sources[i].blobSlice.offset);
            ptr = P.packUint48(ptr, _payload.derivation.sources[i].blobSlice.timestamp);
        }

        ptr = P.packBytes32(ptr, _payload.proposal.coreStateHash);
        ptr = P.packBytes32(ptr, _payload.proposal.derivationHash);

        // Encode core state
        ptr = P.packUint48(ptr, _payload.coreState.nextProposalId);
        ptr = P.packUint48(ptr, _payload.coreState.nextProposalBlockId);
        ptr = P.packUint48(ptr, _payload.coreState.lastFinalizedProposalId);
        ptr = P.packBytes32(ptr, _payload.coreState.lastFinalizedTransitionHash);
        ptr = P.packBytes32(ptr, _payload.coreState.bondInstructionsHash);
    }
    /// @notice Calculate the exact byte size needed for encoding a ProposedEvent
    /// @param _sources Array of derivation sources
    /// @return size_ The total byte size needed for encoding

    function calculateProposedEventSize(IInbox.DerivationSource[] memory _sources)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 235 bytes (without blob data)
            // Proposal: id(6) + proposer(20) + timestamp(6) + endOfSubmissionWindowTimestamp(6) =
            // 38
            // Derivation: originBlockNumber(6) + originBlockHash(32) + basefeeSharingPctg(1) = 39
            // Sources array length: 3
            // Proposal hashes: coreStateHash(32) + derivationHash(32) = 64
            // CoreState: nextProposalId(6) + nextProposalBlockId(6) + lastFinalizedProposalId(6) +
            //           lastFinalizedTransitionHash(32) + bondInstructionsHash(32) = 82
            // Total fixed: 38 + 39 + 3 + 64 + 82 = 226

            size_ = 226;

            // Variable size: each source contributes its encoding size
            for (uint256 i; i < _sources.length; ++i) {
                // Per source: isForcedInclusion(1) + blobHashesLength(3) + offset(3) + timestamp(6)
                // = 13
                // Plus each blob hash: 32 bytes each
                size_ += 13 + (_sources[i].blobSlice.blobHashes.length * 32);
            }
        }
    }
}
