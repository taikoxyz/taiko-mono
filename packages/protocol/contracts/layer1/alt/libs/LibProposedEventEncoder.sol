// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "src/layer1/core/libs/LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProposedEventEncoder
/// @notice Library for encoding and decoding ProposedEventPayload structures for IInbox
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
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
        uint256 bufferSize =
            calculateProposedEventSize(_payload.derivation.sources, _payload.bondInstructions);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Encode Proposal
        ptr = P.packUint40(ptr, _payload.proposal.id);
        ptr = P.packAddress(ptr, _payload.proposal.proposer);
        ptr = P.packUint40(ptr, _payload.proposal.timestamp);
        ptr = P.packUint40(ptr, _payload.proposal.endOfSubmissionWindowTimestamp);
        ptr = P.packUint40(ptr, _payload.derivation.originBlockNumber);
        ptr = P.packBytes32(ptr, _payload.derivation.originBlockHash);
        ptr = P.packUint8(ptr, _payload.derivation.basefeeSharingPctg);

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
            ptr = P.packUint48(ptr, _payload.derivation.sources[i].blobSlice.timestamp);
        }

        ptr = P.packBytes32(ptr, _payload.proposal.coreStateHash);
        ptr = P.packBytes32(ptr, _payload.proposal.derivationHash);
        ptr = P.packBytes32(ptr, _payload.proposal.parentProposalHash);

        // Encode core state
        ptr = P.packUint40(ptr, _payload.coreState.nextProposalId);
        ptr = P.packUint40(ptr, _payload.coreState.lastProposalBlockId);
        ptr = P.packUint40(ptr, _payload.coreState.lastFinalizedProposalId);
        ptr = P.packUint40(ptr, _payload.coreState.lastSyncTimestamp);
        ptr = P.packBytes27(ptr, _payload.coreState.lastFinalizedTransitionHash);
        ptr = P.packBytes32(ptr, _payload.coreState.bondInstructionsHashOld);
        ptr = P.packBytes32(ptr, _payload.coreState.bondInstructionsHashNew);

        uint256 bondInstructionsLength = _payload.bondInstructions.length;
        P.checkArrayLength(bondInstructionsLength);
        ptr = P.packUint16(ptr, uint16(bondInstructionsLength));

        for (uint256 i; i < bondInstructionsLength; ++i) {
            LibBonds.BondInstruction memory instruction = _payload.bondInstructions[i];
            ptr = P.packUint40(ptr, uint40(instruction.proposalId));
            ptr = P.packUint8(ptr, uint8(instruction.bondType));
            ptr = P.packAddress(ptr, instruction.payer);
            ptr = P.packAddress(ptr, instruction.payee);
        }
    }

    /// @notice Decodes bytes into a ProposedEventPayload using compact encoding
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Decode Proposal
        (payload_.proposal.id, ptr) = P.unpackUint40(ptr);
        (payload_.proposal.proposer, ptr) = P.unpackAddress(ptr);
        (payload_.proposal.timestamp, ptr) = P.unpackUint40(ptr);
        (payload_.proposal.endOfSubmissionWindowTimestamp, ptr) = P.unpackUint40(ptr);

        // Decode derivation fields
        (payload_.derivation.originBlockNumber, ptr) = P.unpackUint40(ptr);
        (payload_.derivation.originBlockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.derivation.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);

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
        (payload_.coreState.nextProposalId, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.lastProposalBlockId, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.lastFinalizedProposalId, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.lastSyncTimestamp, ptr) = P.unpackUint40(ptr);
        (payload_.coreState.lastFinalizedTransitionHash, ptr) = P.unpackBytes27(ptr);
        (payload_.coreState.bondInstructionsHashOld, ptr) = P.unpackBytes32(ptr);
        (payload_.coreState.bondInstructionsHashNew, ptr) = P.unpackBytes32(ptr);

        uint16 bondInstructionsLength;
        (bondInstructionsLength, ptr) = P.unpackUint16(ptr);

        if (bondInstructionsLength > 0) {
            payload_.bondInstructions = new LibBonds.BondInstruction[](bondInstructionsLength);

            for (uint256 i; i < bondInstructionsLength; ++i) {
                uint40 temp;
                (temp, ptr) = P.unpackUint40(ptr);
                payload_.bondInstructions[i].proposalId = temp;

                uint8 bondType;
                (bondType, ptr) = P.unpackUint8(ptr);
                require(bondType <= uint8(LibBonds.BondType.LIVENESS), InvalidBondType());
                payload_.bondInstructions[i].bondType = LibBonds.BondType(bondType);

                (payload_.bondInstructions[i].payer, ptr) = P.unpackAddress(ptr);
                (payload_.bondInstructions[i].payee, ptr) = P.unpackAddress(ptr);
            }
        }
    }

    /// @notice Calculate the exact byte size needed for encoding a ProposedEvent
    /// @param _sources Array of derivation sources
    /// @param _bondInstructions Array of bond instructions
    /// @return size_ The total byte size needed for encoding
    function calculateProposedEventSize(
        IInbox.DerivationSource[] memory _sources,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 284 bytes (without blob data)
            // Proposal: id(5) + proposer(20) + timestamp(5) + endOfSubmissionWindowTimestamp(5) = 35
            // Derivation: originBlockNumber(5) + originBlockHash(32) + basefeeSharingPctg(1) = 38
            // Sources array length: 2 (uint16)
            // Proposal hashes: coreStateHash(32) + derivationHash(32) + parentProposalHash(32) = 96
            // CoreState: nextProposalId(5) + lastProposalBlockId(5) + lastFinalizedProposalId(5) +
            //           lastSyncTimestamp(5) + lastFinalizedTransitionHash(27) +
            //           bondInstructionsHashOld(32) + bondInstructionsHashNew(32) = 111
            // Bond instructions length prefix: 2
            // Total fixed: 35 + 38 + 2 + 96 + 111 + 2 = 284

            size_ = 284;

            // Variable size: each source contributes its encoding size
            for (uint256 i; i < _sources.length; ++i) {
                // Per source: isForcedInclusion(1) + blobHashesLength(2) + offset(3) + timestamp(6)
                // = 12
                // Plus each blob hash: 32 bytes each
                size_ += 12 + (_sources[i].blobSlice.blobHashes.length * 32);
            }

            // Bond instruction: proposalId(5) + bondType(1) + payer(20) + payee(20) = 46
            size_ += _bondInstructions.length * 46;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidBondType();
}
