// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "src/layer1/core/libs/LibPackUnpack.sol";

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

        // Encode proofMetadatas array
        newPtr_ = _encodeProposalProofMetadata(newPtr_, _input.proofMetadata);

        // Encode parentTransitionHash
        newPtr_ = P.packBytes32(newPtr_, _input.parentTransitionHash);
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
        newPtr_ = P.packUint48(_ptr, _proposal.id);
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packUint48(newPtr_, _proposal.timestamp);
        newPtr_ = P.packUint48(newPtr_, _proposal.endOfSubmissionWindowTimestamp);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.parentProposalHash);
    }

    /// @notice Encode a single ProposalProofMetadata
    function _encodeProposalProofMetadata(
        uint256 _ptr,
        IInbox.ProposalProofMetadata memory _metadata
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packAddress(_ptr, _metadata.proposer);
        newPtr_ = P.packUint48(newPtr_, _metadata.proposalTimestamp);
        newPtr_ = P.packAddress(newPtr_, _metadata.designatedProver);
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

        // Decode proofMetadatas array
        (input_.proofMetadata, newPtr_) = _decodeProposalProofMetadata(newPtr_);

        // Decode parentTransitionHash
        (input_.parentTransitionHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single Proposal
    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        uint48 temp;
        (temp, newPtr_) = P.unpackUint48(_ptr);
        proposal_.id = uint40(temp);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (temp, newPtr_) = P.unpackUint48(newPtr_);
        proposal_.timestamp = uint40(temp);
        (temp, newPtr_) = P.unpackUint48(newPtr_);
        proposal_.endOfSubmissionWindowTimestamp = uint40(temp);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.parentProposalHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Decode a single ProposalProofMetadata
    function _decodeProposalProofMetadata(uint256 _ptr)
        private
        pure
        returns (IInbox.ProposalProofMetadata memory metadata_, uint256 newPtr_)
    {
        uint48 temp;
        (metadata_.proposer, newPtr_) = P.unpackAddress(_ptr);
        (temp, newPtr_) = P.unpackUint48(newPtr_);
        metadata_.proposalTimestamp = uint40(temp);
        (metadata_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
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
                // Proposal: id(6) + proposer(20) + timestamp(6) +
                // endOfSubmissionWindowTimestamp(6) + coreStateHash(32) +
                // derivationHash(32) + parentProposalHash(32) = 134

                // Checkpoint: blockNumber(6) + blockHash(32) + stateRoot(32) = 70

                // ProposalProofMetadata: proposer(20) + proposalTimestamp(6) + designatedProver(20) +
                // actualProver(20) = 66

                // parentTransitionHash: 32

                // Per ProveInput: 134 + 70 + 66 + 32 = 302
                size_ += 302;
            }
        }
    }
}
