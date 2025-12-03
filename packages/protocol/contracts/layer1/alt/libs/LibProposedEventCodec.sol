// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventCodec
/// @notice Compact binary codec for ProposedEventPayload structures emitted by IInbox.
/// @dev Provides gas-efficient encoding/decoding of Proposed event data using LibPackUnpack.
/// The encoded format is optimized for L1 calldata costs while maintaining deterministic
/// ordering consistent with struct field definitions.
///
/// Encoding format (variable length):
/// - Proposal fields: id(5) + timestamp(5) + endOfSubmissionWindowTimestamp(5) + proposer(20)
/// - Derivation fields: originBlockNumber(5) + basefeeSharingPctg(1) + originBlockHash(32)
/// - Sources array: length(2) + [isForcedInclusion(1) + blobHashes + offset(3) + timestamp(5)]...
/// - Proposal hashes: coreStateHash(32) + derivationHash(32) + parentProposalHash(32)
/// - CoreState: all fields packed sequentially
///
/// @custom:security-contact security@taiko.xyz
library LibProposedEventCodec {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposedEventPayload into compact binary format.
    /// @dev Allocates exact buffer size via calculateProposedEventSize, then sequentially
    /// packs all fields using LibPackUnpack. Field order matches struct definitions.
    /// @param _payload The ProposedEventPayload containing proposal, derivation, and core state.
    /// @return encoded_ The compact binary encoding of the payload.
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

        // Encode Proposal (id, timestamp, endOfSubmissionWindowTimestamp, proposer)
        ptr = P.packUint40(ptr, _payload.proposal.id);
        ptr = P.packUint40(ptr, _payload.proposal.timestamp);
        ptr = P.packUint40(ptr, _payload.proposal.endOfSubmissionWindowTimestamp);
        ptr = P.packAddress(ptr, _payload.proposal.proposer);

        // Encode Derivation (originBlockNumber, basefeeSharingPctg, originBlockHash, sources)
        ptr = P.packUint40(ptr, _payload.derivation.originBlockNumber);
        ptr = P.packUint8(ptr, _payload.derivation.basefeeSharingPctg);
        ptr = P.packBytes32(ptr, _payload.derivation.originBlockHash);

        // Encode sources array length
        uint256 sourcesLength = _payload.derivation.sources.length;
        P.checkArrayLength(sourcesLength);
        ptr = P.packUint16(ptr, uint16(sourcesLength));

        // Encode each source
        for (uint256 i; i < sourcesLength; ++i) {
            ptr = P.packUint8(ptr, _payload.derivation.sources[i].isForcedInclusion ? 1 : 0);

            // Encode blob slice for this source
            uint256 blobHashesLength = _payload.derivation.sources[i].blobSlice.blobHashes.length;
            P.checkArrayLength(blobHashesLength);
            ptr = P.packUint16(ptr, uint16(blobHashesLength));

            // Encode each blob hash
            for (uint256 j; j < blobHashesLength; ++j) {
                ptr = P.packBytes32(ptr, _payload.derivation.sources[i].blobSlice.blobHashes[j]);
            }

            ptr = P.packUint24(ptr, _payload.derivation.sources[i].blobSlice.offset);
            ptr = P.packUint40(ptr, _payload.derivation.sources[i].blobSlice.timestamp);
        }

        ptr = P.packBytes32(ptr, _payload.proposal.coreStateHash);
        ptr = P.packBytes32(ptr, _payload.proposal.derivationHash);
        ptr = P.packBytes32(ptr, _payload.proposal.parentProposalHash);

        // Encode core state
        ptr = P.packUint40(ptr, _payload.coreState.proposalHead);
        ptr = P.packUint40(ptr, _payload.coreState.proposalHeadContainerBlock);
        ptr = P.packUint40(ptr, _payload.coreState.finalizationHead);
        ptr = P.packUint40(ptr, _payload.coreState.synchronizationHead);
        ptr = P.packBytes27(ptr, _payload.coreState.finalizationHeadTransitionHash);
        ptr = P.packBytes32(ptr, _payload.coreState.aggregatedBondInstructionsHash);
    }

    /// @notice Decodes compact binary data into a ProposedEventPayload struct.
    /// @dev Sequentially unpacks all fields using LibPackUnpack in the same order as encode.
    /// Allocates new arrays for variable-length fields (sources, blobHashes).
    /// @param _data The compact binary encoding produced by encode().
    /// @return payload_ The reconstructed ProposedEventPayload struct.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Decode Proposal (id, timestamp, endOfSubmissionWindowTimestamp, proposer)
        (payload_.proposal.id, ptr) = P.unpackUint40(ptr);
        (payload_.proposal.timestamp, ptr) = P.unpackUint40(ptr);
        (payload_.proposal.endOfSubmissionWindowTimestamp, ptr) = P.unpackUint40(ptr);
        (payload_.proposal.proposer, ptr) = P.unpackAddress(ptr);

        // Decode Derivation (originBlockNumber, basefeeSharingPctg, originBlockHash, sources)
        (payload_.derivation.originBlockNumber, ptr) = P.unpackUint40(ptr);
        (payload_.derivation.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);
        (payload_.derivation.originBlockHash, ptr) = P.unpackBytes32(ptr);

        // Decode sources array length
        uint16 sourcesLength;
        (sourcesLength, ptr) = P.unpackUint16(ptr);

        payload_.derivation.sources = new IInbox.DerivationSource[](sourcesLength);
        for (uint256 i; i < sourcesLength; ++i) {
            uint8 isForcedInclusion;
            (isForcedInclusion, ptr) = P.unpackUint8(ptr);
            payload_.derivation.sources[i].isForcedInclusion = isForcedInclusion != 0;

            // Decode blob slice for this source
            uint16 blobHashesLength;
            (blobHashesLength, ptr) = P.unpackUint16(ptr);

            payload_.derivation.sources[i].blobSlice.blobHashes = new bytes32[](blobHashesLength);
            for (uint256 j; j < blobHashesLength; ++j) {
                (payload_.derivation.sources[i].blobSlice.blobHashes[j], ptr) = P.unpackBytes32(ptr);
            }

            (payload_.derivation.sources[i].blobSlice.offset, ptr) = P.unpackUint24(ptr);
            (payload_.derivation.sources[i].blobSlice.timestamp, ptr) = P.unpackUint40(ptr);
        }

        (payload_.proposal.coreStateHash, ptr) = P.unpackBytes32(ptr);
        (payload_.proposal.derivationHash, ptr) = P.unpackBytes32(ptr);
        (payload_.proposal.parentProposalHash, ptr) = P.unpackBytes32(ptr);

        // Decode core state
        (payload_.coreState.proposalHead, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.proposalHeadContainerBlock, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.finalizationHead, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.synchronizationHead, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.finalizationHeadTransitionHash, ptr) = P.unpackBytes27(ptr);
        (payload_.coreState.aggregatedBondInstructionsHash, ptr) = P.unpackBytes32(ptr);
    }

    /// @notice Calculates the exact byte size needed for encoding a ProposedEventPayload.
    /// @dev Fixed size is 250 bytes plus variable size from sources array. Each source
    /// contributes 11 bytes fixed overhead plus 32 bytes per blob hash.
    /// @param _sources Array of derivation sources to calculate size for.
    /// @return size_ The total byte size needed for the encoded payload.
    function calculateProposedEventSize(IInbox.DerivationSource[] memory _sources)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 250 bytes (without blob data)
            // Proposal: id(5) + proposer(20) + timestamp(5) + endOfSubmissionWindowTimestamp(5) = 35
            // Derivation: originBlockNumber(5) + originBlockHash(32) + basefeeSharingPctg(1) = 38
            // Sources array length: 2 (uint16)
            // Proposal hashes: coreStateHash(32) + derivationHash(32) + parentProposalHash(32) = 96
            // CoreState: proposalHead(5) + proposalHeadContainerBlock(5) + finalizationHead(5) +
            //           synchronizationHead(5) + finalizationHeadTransitionHash(27) +
            //           aggregatedBondInstructionsHash(32) = 79
            // Total fixed: 35 + 38 + 2 + 96 + 79 = 250

            size_ = 250;

            // Variable size: each source contributes its encoding size
            for (uint256 i; i < _sources.length; ++i) {
                // Per source: isForcedInclusion(1) + blobHashesLength(2) + offset(3) + timestamp(5)
                // = 11
                // Plus each blob hash: 32 bytes each
                size_ += 11 + (_sources[i].blobSlice.blobHashes.length * 32);
            }
        }
    }
}
