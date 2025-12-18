// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProposeInputDecoder
/// @notice Library for encoding and decoding propose data with gas optimization using LibPackUnpack
/// @custom:security-contact security@taiko.xyz
library LibProposeInputDecoder {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes propose data using compact encoding
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encode(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProposeDataSize(
            _input.parentProposals, _input.transitionRecords, _input.checkpoint
        );
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode deadline
        ptr = P.packUint48(ptr, _input.deadline);

        // 2. Encode CoreState
        ptr = P.packUint48(ptr, _input.coreState.nextProposalId);
        ptr = P.packUint48(ptr, _input.coreState.lastProposalBlockId);
        ptr = P.packUint48(ptr, _input.coreState.lastFinalizedProposalId);
        ptr = P.packUint48(ptr, _input.coreState.lastCheckpointTimestamp);
        ptr = P.packBytes32(ptr, _input.coreState.lastFinalizedTransitionHash);
        ptr = P.packBytes32(ptr, _input.coreState.bondInstructionsHash);

        // 3. Encode parent proposals array
        P.checkArrayLength(_input.parentProposals.length);
        ptr = P.packUint16(ptr, uint16(_input.parentProposals.length));
        for (uint256 i; i < _input.parentProposals.length; ++i) {
            ptr = _encodeProposal(ptr, _input.parentProposals[i]);
        }

        // 4. Encode BlobReference
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);

        // 5. Encode TransitionRecords array
        P.checkArrayLength(_input.transitionRecords.length);
        ptr = P.packUint16(ptr, uint16(_input.transitionRecords.length));
        for (uint256 i; i < _input.transitionRecords.length; ++i) {
            ptr = _encodeTransitionRecord(ptr, _input.transitionRecords[i]);
        }

        // 6. Encode Checkpoint with optimization for empty header
        // Check if checkpoint is empty (all fields are zero)
        bool isEmpty = _input.checkpoint.blockNumber == 0
            && _input.checkpoint.blockHash == bytes32(0)
            && _input.checkpoint.stateRoot == bytes32(0);

        // Write flag byte: 0 for empty, 1 for non-empty
        ptr = P.packUint8(ptr, isEmpty ? 0 : 1);

        // Only encode the full header if it's not empty
        if (!isEmpty) {
            ptr = P.packUint48(ptr, _input.checkpoint.blockNumber);
            ptr = P.packBytes32(ptr, _input.checkpoint.blockHash);
            ptr = P.packBytes32(ptr, _input.checkpoint.stateRoot);
        }

        // 7. Encode numForcedInclusions
        ptr = P.packUint8(ptr, _input.numForcedInclusions);
    }

    /// @notice Decodes propose data using optimized operations with LibPackUnpack
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decode(bytes memory _data) internal pure returns (IInbox.ProposeInput memory input_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode deadline
        (input_.deadline, ptr) = P.unpackUint48(ptr);

        // 2. Decode CoreState
        (input_.coreState.nextProposalId, ptr) = P.unpackUint48(ptr);
        (input_.coreState.lastProposalBlockId, ptr) = P.unpackUint48(ptr);
        (input_.coreState.lastFinalizedProposalId, ptr) = P.unpackUint48(ptr);
        (input_.coreState.lastCheckpointTimestamp, ptr) = P.unpackUint48(ptr);
        (input_.coreState.lastFinalizedTransitionHash, ptr) = P.unpackBytes32(ptr);
        (input_.coreState.bondInstructionsHash, ptr) = P.unpackBytes32(ptr);

        // 3. Decode parent proposals array
        uint16 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint16(ptr);
        input_.parentProposals = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (input_.parentProposals[i], ptr) = _decodeProposal(ptr);
        }

        // 4. Decode BlobReference
        (input_.blobReference.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.numBlobs, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.offset, ptr) = P.unpackUint24(ptr);

        // 5. Decode TransitionRecords array
        uint16 transitionRecordsLength;
        (transitionRecordsLength, ptr) = P.unpackUint16(ptr);
        input_.transitionRecords = new IInbox.TransitionRecord[](transitionRecordsLength);
        for (uint256 i; i < transitionRecordsLength; ++i) {
            (input_.transitionRecords[i], ptr) = _decodeTransitionRecord(ptr);
        }

        // 6. Decode Checkpoint with optimization for empty header
        uint8 headerFlag;
        (headerFlag, ptr) = P.unpackUint8(ptr);

        // If flag is 0, the header is empty, leave it as default (all zeros)
        // If flag is 1, decode the full header
        if (headerFlag == 1) {
            (input_.checkpoint.blockNumber, ptr) = P.unpackUint48(ptr);
            (input_.checkpoint.blockHash, ptr) = P.unpackBytes32(ptr);
            (input_.checkpoint.stateRoot, ptr) = P.unpackBytes32(ptr);
        }

        // else: checkpoint remains as default (all zeros)
        // 7. Decode numForcedInclusions
        (input_.numForcedInclusions, ptr) = P.unpackUint8(ptr);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Encode a single Proposal
    function _encodeProposal(
        uint256 _ptr,
        IInbox.Proposal memory _proposal
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packUint48(_ptr, _proposal.id);
        newPtr_ = P.packUint48(newPtr_, _proposal.timestamp);
        newPtr_ = P.packUint48(newPtr_, _proposal.endOfSubmissionWindowTimestamp);
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
    }

    /// @notice Encode a single TransitionRecord
    function _encodeTransitionRecord(
        uint256 _ptr,
        IInbox.TransitionRecord memory _transitionRecord
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        // Encode span
        newPtr_ = P.packUint8(_ptr, _transitionRecord.span);

        // Encode BondInstructions array
        P.checkArrayLength(_transitionRecord.bondInstructions.length);
        newPtr_ = P.packUint16(newPtr_, uint16(_transitionRecord.bondInstructions.length));
        for (uint256 i; i < _transitionRecord.bondInstructions.length; ++i) {
            newPtr_ = _encodeBondInstruction(newPtr_, _transitionRecord.bondInstructions[i]);
        }

        // Encode transitionHash
        newPtr_ = P.packBytes32(newPtr_, _transitionRecord.transitionHash);

        // Encode checkpointHash
        newPtr_ = P.packBytes32(newPtr_, _transitionRecord.checkpointHash);
    }

    /// @notice Encode a single BondInstruction
    function _encodeBondInstruction(
        uint256 _ptr,
        LibBonds.BondInstruction memory _bondInstruction
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packUint48(_ptr, _bondInstruction.proposalId);
        newPtr_ = P.packUint8(newPtr_, uint8(_bondInstruction.bondType));
        newPtr_ = P.packAddress(newPtr_, _bondInstruction.payer);
        newPtr_ = P.packAddress(newPtr_, _bondInstruction.payee);
    }

    /// @notice Decode a single Proposal
    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        (proposal_.id, newPtr_) = P.unpackUint48(_ptr);
        (proposal_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.endOfSubmissionWindowTimestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single TransitionRecord
    function _decodeTransitionRecord(uint256 _ptr)
        private
        pure
        returns (IInbox.TransitionRecord memory transitionRecord_, uint256 newPtr_)
    {
        // Decode span
        (transitionRecord_.span, newPtr_) = P.unpackUint8(_ptr);

        // Decode BondInstructions array
        uint16 bondInstructionsLength;
        (bondInstructionsLength, newPtr_) = P.unpackUint16(newPtr_);
        transitionRecord_.bondInstructions = new LibBonds.BondInstruction[](bondInstructionsLength);
        for (uint256 i; i < bondInstructionsLength; ++i) {
            (transitionRecord_.bondInstructions[i], newPtr_) = _decodeBondInstruction(newPtr_);
        }

        // Decode transitionHash
        (transitionRecord_.transitionHash, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode checkpointHash
        (transitionRecord_.checkpointHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single BondInstruction
    function _decodeBondInstruction(uint256 _ptr)
        private
        pure
        returns (LibBonds.BondInstruction memory bondInstruction_, uint256 newPtr_)
    {
        (bondInstruction_.proposalId, newPtr_) = P.unpackUint48(_ptr);

        uint8 bondType;
        (bondType, newPtr_) = P.unpackUint8(newPtr_);
        bondInstruction_.bondType = LibBonds.BondType(bondType);

        (bondInstruction_.payer, newPtr_) = P.unpackAddress(newPtr_);
        (bondInstruction_.payee, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProposeDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.TransitionRecord[] memory _transitionRecords,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed sizes:
            // deadline: 6 bytes (uint48)
            // CoreState: 6 + 6 + 6 + 6 + 32 + 32 = 88 bytes
            // BlobReference: 2 + 2 + 3 = 7 bytes
            // Arrays lengths: 2 + 2 = 4 bytes
            // Checkpoint flag: 1 byte
            // numForcedInclusions: 1 byte (uint8)
            size_ = 107;

            // Add Checkpoint size if not empty
            bool isEmpty = _checkpoint.blockNumber == 0 && _checkpoint.blockHash == bytes32(0)
                && _checkpoint.stateRoot == bytes32(0);

            if (!isEmpty) {
                // Checkpoint when not empty: 6 + 32 + 32 = 70 bytes
                size_ += 70;
            }

            // Proposals - each has fixed size
            // Fixed proposal fields: id(6) + timestamp(6) +
            // endOfSubmissionWindowTimestamp(6) + proposer(20) + coreStateHash(32) +
            // derivationHash(32) = 102
            size_ += _proposals.length * 102;

            // TransitionRecords - each has fixed size + variable bond instructions
            // Fixed: span(1) + array length(2) + transitionHash(32) +
            // checkpointHash(32) = 67
            for (uint256 i; i < _transitionRecords.length; ++i) {
                size_ += 67 + (_transitionRecords[i].bondInstructions.length * 47);
            }
        }
    }
}
