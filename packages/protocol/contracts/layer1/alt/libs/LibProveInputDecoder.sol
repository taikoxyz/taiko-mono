// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProveInputDecoder
/// @notice Library for encoding and decoding prove input data for IInbox
/// @custom:security-contact security@taiko.xyz
library LibProveInputDecoder {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes prove input data using compact encoding
    /// @param _inputs The ProveInput array to encode
    /// @return encoded_ The encoded data
    function encode(IInbox.ProveInput[] memory _inputs)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProveDataSize(_inputs);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Encode ProveInput array length
        P.checkArrayLength(_inputs.length);
        ptr = P.packUint16(ptr, uint16(_inputs.length));

        for (uint256 i; i < _inputs.length; ++i) {
            ptr = _encodeProveInput(ptr, _inputs[i]);
        }
    }

    /// @notice Decodes prove input data using optimized operations
    /// @param _data The encoded data
    /// @return inputs_ The decoded ProveInput array
    function decode(bytes memory _data) internal pure returns (IInbox.ProveInput[] memory inputs_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Decode ProveInput array length
        uint16 inputsLength;
        (inputsLength, ptr) = P.unpackUint16(ptr);

        inputs_ = new IInbox.ProveInput[](inputsLength);
        for (uint256 i; i < inputsLength; ++i) {
            (inputs_[i], ptr) = _decodeProveInput(ptr);
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Encode a single ProveInput
    function _encodeProveInput(
        uint256 _ptr,
        IInbox.ProveInput memory _input
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        // Encode endProposal
        newPtr_ = _encodeProposal(_ptr, _input.proposal);

        // Encode checkpoint
        newPtr_ = P.packUint48(newPtr_, _input.checkpoint.blockNumber);
        newPtr_ = P.packBytes32(newPtr_, _input.checkpoint.blockHash);
        newPtr_ = P.packBytes32(newPtr_, _input.checkpoint.stateRoot);

        // Encode metadata
        newPtr_ = _encodeProofMetadata(newPtr_, _input.metadata);

        // Encode parentTransitionHash
        newPtr_ = P.packBytes27(newPtr_, _input.parentTransitionHash);
    }

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
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packUint40(newPtr_, _proposal.timestamp);
        newPtr_ = P.packUint40(newPtr_, _proposal.endOfSubmissionWindowTimestamp);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.parentProposalHash);
    }

    /// @notice Encode a single ProofMetadata
    function _encodeProofMetadata(
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

    /// @notice Decode a single ProveInput
    function _decodeProveInput(uint256 _ptr)
        private
        pure
        returns (IInbox.ProveInput memory input_, uint256 newPtr_)
    {
        // Decode endProposal
        (input_.proposal, newPtr_) = _decodeProposal(_ptr);

        // Decode checkpoint
        (input_.checkpoint.blockNumber, newPtr_) = P.unpackUint48(newPtr_);
        (input_.checkpoint.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (input_.checkpoint.stateRoot, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode metadata
        (input_.metadata, newPtr_) = _decodeTransitionMetadata(newPtr_);

        // Decode parentTransitionHash
        (input_.parentTransitionHash, newPtr_) = P.unpackBytes27(newPtr_);
    }

    /// @notice Decode a single Proposal
    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        (proposal_.id, newPtr_) = P.unpackUint40(_ptr);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (proposal_.timestamp, newPtr_) = P.unpackUint40(newPtr_);
        (proposal_.endOfSubmissionWindowTimestamp, newPtr_) = P.unpackUint40(newPtr_);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.parentProposalHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single ProofMetadata
    function _decodeTransitionMetadata(uint256 _ptr)
        private
        pure
        returns (IInbox.TransitionMetadata memory metadata_, uint256 newPtr_)
    {
        (metadata_.designatedProver, newPtr_) = P.unpackAddress(_ptr);
        (metadata_.actualProver, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProveDataSize(IInbox.ProveInput[] memory _inputs)
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Array length: 2 bytes
            size_ = 2;

            for (uint256 i; i < _inputs.length; ++i) {
                // Proposal: id(5) + proposer(20) + timestamp(5) +
                // endOfSubmissionWindowTimestamp(5) + coreStateHash(32) +
                // derivationHash(32) + parentProposalHash(32) = 131

                // Checkpoint: blockNumber(6) + blockHash(32) + stateRoot(32) = 70

                // ProofMetadata: proposer(20) + proposalTimestamp(5) + designatedProver(20) +
                // actualProver(20) = 65

                // parentTransitionHash: 27

                // Per ProveInput: 131 + 70 + 65 + 27 = 293
                size_ += 293;
            }
        }
    }
}
