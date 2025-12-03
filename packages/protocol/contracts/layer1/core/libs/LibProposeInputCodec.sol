// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProposeInputCodec
/// @notice Compact binary codec for ProposeInput structures used by IInbox.propose().
/// @dev Provides gas-efficient encoding/decoding of proposal submission calldata using LibPackUnpack.
/// The encoded format is optimized for L1 calldata costs while maintaining deterministic
/// ordering consistent with struct field definitions.
///
/// Encoding format (variable length):
/// - deadline(5) + CoreState(79) + proposals array + BlobReference(7) + transitions array
/// - Checkpoint with isEmpty optimization (1 byte flag + optional 70 bytes)
/// - numForcedInclusions(1)
///
/// @custom:security-contact security@taiko.xyz
library LibProposeInputCodec {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposeInput into compact binary format.
    /// @dev Allocates exact buffer size via _calculateProposeDataSize, then sequentially
    /// packs all fields using LibPackUnpack. Empty checkpoints are optimized to 1 byte.
    /// @param _input The ProposeInput containing deadline, core state, proposals, and transitions.
    /// @return encoded_ The compact binary encoding of the input.
    function encode(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProposeDataSize(
            _input.headProposalAndProof, _input.transitions, _input.checkpoint
        );
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode deadline
        ptr = P.packUint40(ptr, _input.deadline);

        // 2. Encode CoreState
        ptr = P.packUint40(ptr, _input.coreState.proposalHead);
        ptr = P.packUint40(ptr, _input.coreState.proposalHeadContainerBlock);
        ptr = P.packUint40(ptr, _input.coreState.finalizationHead);
        ptr = P.packUint40(ptr, _input.coreState.synchronizationHead);
        ptr = P.packBytes27(ptr, _input.coreState.finalizationHeadTransitionHash);
        ptr = P.packBytes32(ptr, _input.coreState.aggregatedBondInstructionsHash);

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

        // 6. Encode Checkpoint with optimization for empty header
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

    /// @notice Decodes compact binary data into a ProposeInput struct.
    /// @dev Sequentially unpacks all fields using LibPackUnpack in the same order as encode.
    /// Handles the isEmpty optimization for checkpoints.
    /// @param _data The compact binary encoding produced by encode().
    /// @return input_ The reconstructed ProposeInput struct.
    function decode(bytes memory _data) internal pure returns (IInbox.ProposeInput memory input_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode deadline
        (input_.deadline, ptr) = P.unpackUint40(ptr);

        // 2. Decode CoreState
        (input_.coreState.proposalHead, ptr) = P.unpackUint40(ptr);
        (input_.coreState.proposalHeadContainerBlock, ptr) = P.unpackUint40(ptr);
        (input_.coreState.finalizationHead, ptr) = P.unpackUint40(ptr);
        (input_.coreState.synchronizationHead, ptr) = P.unpackUint40(ptr);
        (input_.coreState.finalizationHeadTransitionHash, ptr) = P.unpackBytes27(ptr);
        (input_.coreState.aggregatedBondInstructionsHash, ptr) = P.unpackBytes32(ptr);

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

        // 6. Decode Checkpoint with optimization for empty header
        uint8 headerFlag;
        (headerFlag, ptr) = P.unpackUint8(ptr);

        if (headerFlag == 1) {
            (input_.checkpoint.blockNumber, ptr) = P.unpackUint48(ptr);
            (input_.checkpoint.blockHash, ptr) = P.unpackBytes32(ptr);
            (input_.checkpoint.stateRoot, ptr) = P.unpackBytes32(ptr);
        }

        // 7. Decode numForcedInclusions
        (input_.numForcedInclusions, ptr) = P.unpackUint8(ptr);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a single Proposal struct at the given memory position.
    /// @dev Packs fields in definition order: id, timestamp, endOfSubmissionWindowTimestamp,
    /// proposer, coreStateHash, derivationHash, parentProposalHash (131 bytes total).
    /// @param _ptr The memory position to start writing at.
    /// @param _proposal The Proposal struct to encode.
    /// @return newPtr_ The updated memory position after encoding.
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

    /// @notice Encodes a single Transition struct at the given memory position.
    /// @dev Packs bondInstructionHash and checkpointHash (64 bytes total).
    /// @param _ptr The memory position to start writing at.
    /// @param _transition The Transition struct to encode.
    /// @return newPtr_ The updated memory position after encoding.
    function _encodeTransition(
        uint256 _ptr,
        IInbox.Transition memory _transition
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packBytes32(_ptr, _transition.bondInstructionHash);
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpointHash);
    }

    /// @notice Decodes a single Proposal struct from the given memory position.
    /// @dev Unpacks fields in definition order: id, timestamp, endOfSubmissionWindowTimestamp,
    /// proposer, coreStateHash, derivationHash, parentProposalHash (131 bytes total).
    /// @param _ptr The memory position to start reading from.
    /// @return proposal_ The decoded Proposal struct.
    /// @return newPtr_ The updated memory position after decoding.
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

    /// @notice Decodes a single Transition struct from the given memory position.
    /// @dev Unpacks bondInstructionHash and checkpointHash (64 bytes total).
    /// @param _ptr The memory position to start reading from.
    /// @return transition_ The decoded Transition struct.
    /// @return newPtr_ The updated memory position after decoding.
    function _decodeTransition(uint256 _ptr)
        private
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.bondInstructionHash, newPtr_) = P.unpackBytes32(_ptr);
        (transition_.checkpointHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Calculates the exact byte size needed for encoding a ProposeInput.
    /// @dev Fixed base size is 131 bytes. Adds 131 bytes per proposal, 64 bytes per transition,
    /// and 70 bytes for non-empty checkpoints.
    /// @param _proposals Array of head proposals to calculate size for.
    /// @param _transitions Array of transitions to calculate size for.
    /// @param _checkpoint The checkpoint to check for isEmpty optimization.
    /// @return size_ The total byte size needed for the encoded input.
    function _calculateProposeDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
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
        }
    }
}
