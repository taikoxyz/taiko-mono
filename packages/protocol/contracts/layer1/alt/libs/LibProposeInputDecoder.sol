// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProposeInputDecoder
/// @notice Library for encoding and decoding propose input data for IInbox
/// @custom:security-contact security@taiko.xyz
library LibProposeInputDecoder {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes propose input data using compact encoding
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encode(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProposeDataSize(
            _input.headProposalAndProof,
            _input.transitions,
            _input.bondInstructions,
            _input.checkpoint
        );
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode deadline
        ptr = P.packUint40(ptr, _input.deadline);

        // 2. Encode CoreState
        ptr = P.packUint40(ptr, _input.coreState.nextProposalId);
        ptr = P.packUint40(ptr, _input.coreState.lastProposalBlockId);
        ptr = P.packUint40(ptr, _input.coreState.lastFinalizedProposalId);
        ptr = P.packUint40(ptr, _input.coreState.lastSyncTimestamp);
        ptr = P.packBytes27(ptr, _input.coreState.lastFinalizedTransitionHash);
        ptr = P.packBytes32(ptr, _input.coreState.bondInstructionsHashOld);
        ptr = P.packBytes32(ptr, _input.coreState.bondInstructionsHashNew);

        // 3. Encode head proposals array
        P.checkArrayLength(_input.headProposalAndProof.length);
        ptr = P.packUint16(ptr, uint16(_input.headProposalAndProof.length));
        for (uint256 i; i < _input.headProposalAndProof.length; ++i) {
            ptr = _encodeProposal(ptr, _input.headProposalAndProof[i]);
        }

        // 4. Encode BlobReference
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);

        // 5. Encode Transitions array
        P.checkArrayLength(_input.transitions.length);
        ptr = P.packUint16(ptr, uint16(_input.transitions.length));
        for (uint256 i; i < _input.transitions.length; ++i) {
            ptr = _encodeTransition(ptr, _input.transitions[i]);
        }

        // 6. Encode BondInstructions 2D array
        P.checkArrayLength(_input.bondInstructions.length);
        ptr = P.packUint16(ptr, uint16(_input.bondInstructions.length));
        for (uint256 i; i < _input.bondInstructions.length; ++i) {
            P.checkArrayLength(_input.bondInstructions[i].length);
            ptr = P.packUint16(ptr, uint16(_input.bondInstructions[i].length));
            for (uint256 j; j < _input.bondInstructions[i].length; ++j) {
                ptr = _encodeBondInstruction(ptr, _input.bondInstructions[i][j]);
            }
        }

        // 7. Encode Checkpoint with optimization for empty header
        bool isEmpty = _input.checkpoint.blockNumber == 0
            && _input.checkpoint.blockHash == bytes32(0)
            && _input.checkpoint.stateRoot == bytes32(0);

        ptr = P.packUint8(ptr, isEmpty ? 0 : 1);

        if (!isEmpty) {
            ptr = P.packUint48(ptr, _input.checkpoint.blockNumber);
            ptr = P.packBytes32(ptr, _input.checkpoint.blockHash);
            ptr = P.packBytes32(ptr, _input.checkpoint.stateRoot);
        }

        // 8. Encode numForcedInclusions
        ptr = P.packUint8(ptr, _input.numForcedInclusions);
    }

    /// @notice Decodes propose input data using optimized operations
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decode(bytes memory _data) internal pure returns (IInbox.ProposeInput memory input_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode deadline
        (input_.deadline, ptr) = P.unpackUint40(ptr);

        // 2. Decode CoreState
        (input_.coreState.nextProposalId, ptr) = P.unpackUint40(ptr);
        (input_.coreState.lastProposalBlockId, ptr) = P.unpackUint40(ptr);
        (input_.coreState.lastFinalizedProposalId, ptr) = P.unpackUint40(ptr);
        (input_.coreState.lastSyncTimestamp, ptr) = P.unpackUint40(ptr);
        (input_.coreState.lastFinalizedTransitionHash, ptr) = P.unpackBytes27(ptr);
        (input_.coreState.bondInstructionsHashOld, ptr) = P.unpackBytes32(ptr);
        (input_.coreState.bondInstructionsHashNew, ptr) = P.unpackBytes32(ptr);

        // 3. Decode head proposals array
        uint16 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint16(ptr);
        input_.headProposalAndProof = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (input_.headProposalAndProof[i], ptr) = _decodeProposal(ptr);
        }

        // 4. Decode BlobReference
        (input_.blobReference.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.numBlobs, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.offset, ptr) = P.unpackUint24(ptr);

        // 5. Decode Transitions array
        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        input_.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.transitions[i], ptr) = _decodeTransition(ptr);
        }

        // 6. Decode BondInstructions 2D array
        uint16 bondInstructionsOuterLength;
        (bondInstructionsOuterLength, ptr) = P.unpackUint16(ptr);
        input_.bondInstructions = new LibBonds.BondInstruction[][](bondInstructionsOuterLength);
        for (uint256 i; i < bondInstructionsOuterLength; ++i) {
            uint16 innerLength;
            (innerLength, ptr) = P.unpackUint16(ptr);
            input_.bondInstructions[i] = new LibBonds.BondInstruction[](innerLength);
            for (uint256 j; j < innerLength; ++j) {
                (input_.bondInstructions[i][j], ptr) = _decodeBondInstruction(ptr);
            }
        }

        // 7. Decode Checkpoint with optimization for empty header
        uint8 headerFlag;
        (headerFlag, ptr) = P.unpackUint8(ptr);

        if (headerFlag == 1) {
            (input_.checkpoint.blockNumber, ptr) = P.unpackUint48(ptr);
            (input_.checkpoint.blockHash, ptr) = P.unpackBytes32(ptr);
            (input_.checkpoint.stateRoot, ptr) = P.unpackBytes32(ptr);
        }

        // 8. Decode numForcedInclusions
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
        newPtr_ = P.packUint40(_ptr, _proposal.id);
        newPtr_ = P.packUint40(newPtr_, _proposal.timestamp);
        newPtr_ = P.packUint40(newPtr_, _proposal.endOfSubmissionWindowTimestamp);
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.parentProposalHash);
    }

    /// @notice Encode a single Transition
    function _encodeTransition(
        uint256 _ptr,
        IInbox.Transition memory _transition
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packBytes32(_ptr, _transition.bondInstructionsHash);
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpointHash);
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
        newPtr_ = P.packUint40(_ptr, uint40(_bondInstruction.proposalId));
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
        (proposal_.id, newPtr_) = P.unpackUint40(_ptr);
        (proposal_.timestamp, newPtr_) = P.unpackUint40(newPtr_);
        (proposal_.endOfSubmissionWindowTimestamp, newPtr_) = P.unpackUint40(newPtr_);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.parentProposalHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single Transition
    function _decodeTransition(uint256 _ptr)
        private
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.bondInstructionsHash, newPtr_) = P.unpackBytes32(_ptr);
        (transition_.checkpointHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single BondInstruction
    function _decodeBondInstruction(uint256 _ptr)
        private
        pure
        returns (LibBonds.BondInstruction memory bondInstruction_, uint256 newPtr_)
    {
        uint40 temp;
        (temp, newPtr_) = P.unpackUint40(_ptr);
        bondInstruction_.proposalId = temp;

        uint8 bondType;
        (bondType, newPtr_) = P.unpackUint8(newPtr_);
        bondInstruction_.bondType = LibBonds.BondType(bondType);

        (bondInstruction_.payer, newPtr_) = P.unpackAddress(newPtr_);
        (bondInstruction_.payee, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProposeDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
        LibBonds.BondInstruction[][] memory _bondInstructions,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed sizes:
            // deadline: 5 bytes (uint40)
            // CoreState: 5 + 5 + 5 + 5 + 27 + 32 + 32 = 111 bytes
            // BlobReference: 2 + 2 + 3 = 7 bytes
            // Arrays lengths: 2 + 2 + 2 = 6 bytes (proposals, transitions, bondInstructions outer)
            // Checkpoint flag: 1 byte
            // numForcedInclusions: 1 byte (uint8)
            size_ = 131;

            // Add Checkpoint size if not empty
            bool isEmpty = _checkpoint.blockNumber == 0 && _checkpoint.blockHash == bytes32(0)
                && _checkpoint.stateRoot == bytes32(0);

            if (!isEmpty) {
                // Checkpoint when not empty: 6 + 32 + 32 = 70 bytes
                size_ += 70;
            }

            // Proposals - each has fixed size
            // Fixed proposal fields: id(5) + timestamp(5) +
            // endOfSubmissionWindowTimestamp(5) + proposer(20) + coreStateHash(32) +
            // derivationHash(32) + parentProposalHash(32) = 131
            size_ += _proposals.length * 131;

            // Transitions - each has fixed size
            // bondInstructionsHash(32) + checkpointHash(32) = 64
            size_ += _transitions.length * 64;

            // BondInstructions 2D array
            for (uint256 i; i < _bondInstructions.length; ++i) {
                // Inner array length: 2 bytes
                size_ += 2;
                // Each bond instruction: proposalId(5) + bondType(1) + payer(20) + payee(20) = 46
                size_ += _bondInstructions[i].length * 46;
            }
        }
    }
}
