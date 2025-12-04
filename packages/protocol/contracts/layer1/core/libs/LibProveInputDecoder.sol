// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProveInputDecoder
/// @notice Compact encoder/decoder for prove inputs using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProveInputDecoder {
    /// @notice Encodes prove input data using compact packing.
    function encode(IInbox.ProveInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 bufferSize = _calculateProveDataSize(_input.proposals, _input.transitions);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        P.checkArrayLength(_input.proposals.length);
        ptr = P.packUint16(ptr, uint16(_input.proposals.length));
        for (uint256 i; i < _input.proposals.length; ++i) {
            ptr = _encodeProposal(ptr, _input.proposals[i]);
        }

        P.checkArrayLength(_input.transitions.length);
        ptr = P.packUint16(ptr, uint16(_input.transitions.length));
        for (uint256 i; i < _input.transitions.length; ++i) {
            ptr = _encodeTransition(ptr, _input.transitions[i]);
        }

        ptr = P.packUint8(ptr, _input.syncCheckpoint ? 1 : 0);
    }

    /// @notice Decodes prove input data using compact packing.
    function decode(bytes memory _data) internal pure returns (IInbox.ProveInput memory input_) {
        uint256 ptr = P.dataPtr(_data);

        uint16 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint16(ptr);
        input_.proposals = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (input_.proposals[i], ptr) = _decodeProposal(ptr);
        }

        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        require(transitionsLength == proposalsLength, ProposalTransitionLengthMismatch());

        input_.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.transitions[i], ptr) = _decodeTransition(ptr);
        }

        uint8 syncCheckpoint;
        (syncCheckpoint, ptr) = P.unpackUint8(ptr);
        input_.syncCheckpoint = syncCheckpoint != 0;
    }

    /// @notice Calculate the size needed for encoding.
    function _calculateProveDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions
    )
        private
        pure
        returns (uint256 size_)
    {
        require(_proposals.length == _transitions.length, ProposalTransitionLengthMismatch());

        unchecked {
            // Array lengths: 2 + 2 = 4 bytes
            // syncCheckpoint flag: 1 byte
            // Per item:
            //   Proposal: 70 bytes
            //   Transition: 174 bytes
            size_ = 5 + (_proposals.length * (70 + 174));
        }
    }

    function _encodeProposal(uint256 _ptr, IInbox.Proposal memory _proposal)
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packUint48(_ptr, _proposal.id);
        newPtr_ = P.packUint48(newPtr_, _proposal.timestamp);
        newPtr_ = P.packUint48(newPtr_, _proposal.endOfSubmissionWindowTimestamp);
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
    }

    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        (proposal_.id, newPtr_) = P.unpackUint48(_ptr);
        (proposal_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.endOfSubmissionWindowTimestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    function _encodeTransition(uint256 _ptr, IInbox.Transition memory _transition)
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packBytes32(_ptr, _transition.proposalHash);
        newPtr_ = P.packBytes32(newPtr_, _transition.parentTransitionHash);
        newPtr_ = P.packUint48(newPtr_, _transition.checkpoint.blockNumber);
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpoint.blockHash);
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpoint.stateRoot);
        newPtr_ = P.packAddress(newPtr_, _transition.designatedProver);
        newPtr_ = P.packAddress(newPtr_, _transition.actualProver);
    }

    function _decodeTransition(uint256 _ptr)
        private
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.proposalHash, newPtr_) = P.unpackBytes32(_ptr);
        (transition_.parentTransitionHash, newPtr_) = P.unpackBytes32(newPtr_);
        (transition_.checkpoint.blockNumber, newPtr_) = P.unpackUint48(newPtr_);
        (transition_.checkpoint.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (transition_.checkpoint.stateRoot, newPtr_) = P.unpackBytes32(newPtr_);
        (transition_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (transition_.actualProver, newPtr_) = P.unpackAddress(newPtr_);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ProposalTransitionLengthMismatch();
}
