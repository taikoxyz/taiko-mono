// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProveInputDecoder
/// @notice Library for encoding and decoding prove input data with gas optimization using
/// LibPackUnpack
/// @custom:security-contact security@taiko.xyz
library LibProveInputDecoder {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes prove input data using compact encoding
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encode(IInbox.ProveInput memory _input) internal pure returns (bytes memory encoded_) {
        // Calculate total size needed
        uint256 bufferSize =
            _calculateProveDataSize(_input.proposals, _input.transitions, _input.metadata);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode Proposals array
        P.checkArrayLength(_input.proposals.length);
        ptr = P.packUint16(ptr, uint16(_input.proposals.length));
        for (uint256 i; i < _input.proposals.length; ++i) {
            ptr = _encodeProposal(ptr, _input.proposals[i]);
        }

        // 2. Encode Transitions array
        P.checkArrayLength(_input.transitions.length);
        ptr = P.packUint16(ptr, uint16(_input.transitions.length));
        for (uint256 i; i < _input.transitions.length; ++i) {
            ptr = _encodeTransition(ptr, _input.transitions[i]);
        }

        // 3. Encode Metadata array (no need to encode length, reuse transitions length)
        P.checkArrayLength(_input.metadata.length);
        for (uint256 i; i < _input.metadata.length; ++i) {
            ptr = _encodeMetadata(ptr, _input.metadata[i]);
        }
    }

    /// @notice Decodes prove input data using optimized operations with LibPackUnpack
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    function decode(bytes memory _data) internal pure returns (IInbox.ProveInput memory input_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode Proposals array
        uint16 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint16(ptr);
        input_.proposals = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (input_.proposals[i], ptr) = _decodeProposal(ptr);
        }

        // 2. Decode Transitions array
        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        require(transitionsLength == proposalsLength, ProposalTransitionLengthMismatch());
        input_.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.transitions[i], ptr) = _decodeTransition(ptr);
        }

        // 3. Decode Metadata array (reuse transitions length)
        input_.metadata = new IInbox.TransitionMetadata[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.metadata[i], ptr) = _decodeMetadata(ptr);
        }
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
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packUint48(newPtr_, _proposal.timestamp);
        newPtr_ = P.packUint48(newPtr_, _proposal.endOfSubmissionWindowTimestamp);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
    }

    /// @notice Decode a single Proposal
    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        (proposal_.id, newPtr_) = P.unpackUint48(_ptr);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (proposal_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.endOfSubmissionWindowTimestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
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
        newPtr_ = P.packBytes32(_ptr, _transition.proposalHash);
        newPtr_ = P.packBytes32(newPtr_, _transition.parentTransitionHash);
        // Encode Checkpoint
        newPtr_ = P.packUint48(newPtr_, _transition.checkpoint.blockNumber);
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpoint.blockHash);
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpoint.stateRoot);
    }

    /// @notice Decode a single Transition
    function _decodeTransition(uint256 _ptr)
        private
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.proposalHash, newPtr_) = P.unpackBytes32(_ptr);
        (transition_.parentTransitionHash, newPtr_) = P.unpackBytes32(newPtr_);
        // Decode Checkpoint
        (transition_.checkpoint.blockNumber, newPtr_) = P.unpackUint48(newPtr_);
        (transition_.checkpoint.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (transition_.checkpoint.stateRoot, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Encode a single TransitionMetadata
    function _encodeMetadata(
        uint256 _ptr,
        IInbox.TransitionMetadata memory _metadata
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packAddress(_ptr, _metadata.designatedProver);
        newPtr_ = P.packAddress(newPtr_, _metadata.actualProver);
    }

    /// @notice Decode a single TransitionMetadata
    function _decodeMetadata(uint256 _ptr)
        private
        pure
        returns (IInbox.TransitionMetadata memory metadata_, uint256 newPtr_)
    {
        (metadata_.designatedProver, newPtr_) = P.unpackAddress(_ptr);
        (metadata_.actualProver, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProveDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
        IInbox.TransitionMetadata[] memory _metadata
    )
        private
        pure
        returns (uint256 size_)
    {
        require(_proposals.length == _transitions.length, ProposalTransitionLengthMismatch());
        require(_metadata.length == _transitions.length, MetadataLengthMismatch());

        unchecked {
            // Array lengths: 2 + 2 = 4 bytes (proposals and transitions lengths only)
            size_ = 4;

            // Proposals - each has fixed size
            // Fixed proposal fields: id(6) + proposer(20) + timestamp(6) +
            // endOfSubmissionWindowTimestamp(6) + coreStateHash(32) +
            // derivationHash(32) = 102
            //
            // Transitions - each has fixed size (no provers): proposalHash(32) +
            // parentTransitionHash(32) +
            // Checkpoint(6 + 32 + 32) = 134
            //
            // Metadata - each has fixed size: designatedProver(20) + actualProver(20) = 40
            //
            size_ += _proposals.length * (102 + 134 + 40);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ProposalTransitionLengthMismatch();
    error MetadataLengthMismatch();
}
