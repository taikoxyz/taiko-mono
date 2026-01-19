// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibTransitionCodec } from "./LibTransitionCodec.sol";

/// @title LibCodec
/// @notice Compact encoder/decoder for Inbox inputs using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    // ---------------------------------------------------------------
    // ProposeInputCodec Functions
    // ---------------------------------------------------------------

    /// @dev Encodes propose input data using compact packing.
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(14);
        uint256 ptr = P.dataPtr(encoded_);
        ptr = P.packUint48(ptr, _input.deadline);
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);
        ptr = P.packUint8(ptr, _input.numForcedInclusions);
    }

    /// @dev Decodes propose input data using compact packing.
    function decodeProposeInput(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        uint256 ptr = P.dataPtr(_data);
        (input_.deadline, ptr) = P.unpackUint48(ptr);
        (input_.blobReference.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.numBlobs, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.offset, ptr) = P.unpackUint24(ptr);
        (input_.numForcedInclusions,) = P.unpackUint8(ptr);
    }

    // ---------------------------------------------------------------
    // ProveInputCodec Functions
    // ---------------------------------------------------------------

    /// @dev Encodes prove input data using compact packing.
    function encodeProveInput(IInbox.ProveInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        IInbox.Commitment memory c = _input.commitment;
        uint256 bufferSize = _calculateProveInputSize(c.transitions.length);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, c.firstProposalId);
        ptr = P.packBytes32(ptr, c.firstProposalParentBlockHash);
        ptr = P.packBytes32(ptr, c.lastProposalHash);
        ptr = P.packAddress(ptr, c.actualProver);
        ptr = P.packUint48(ptr, c.endBlockNumber);
        ptr = P.packBytes32(ptr, c.endStateRoot);

        P.checkArrayLength(c.transitions.length);
        ptr = P.packUint16(ptr, uint16(c.transitions.length));
        for (uint256 i; i < c.transitions.length; ++i) {
            ptr = LibTransitionCodec.encodeTransition(ptr, c.transitions[i]);
        }
    }

    /// @dev Decodes prove input data using compact packing.
    function decodeProveInput(bytes memory _data)
        internal
        pure
        returns (IInbox.ProveInput memory input_)
    {
        uint256 ptr = P.dataPtr(_data);

        (input_.commitment.firstProposalId, ptr) = P.unpackUint48(ptr);
        (input_.commitment.firstProposalParentBlockHash, ptr) = P.unpackBytes32(ptr);
        (input_.commitment.lastProposalHash, ptr) = P.unpackBytes32(ptr);
        (input_.commitment.actualProver, ptr) = P.unpackAddress(ptr);
        (input_.commitment.endBlockNumber, ptr) = P.unpackUint48(ptr);
        (input_.commitment.endStateRoot, ptr) = P.unpackBytes32(ptr);

        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        input_.commitment.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.commitment.transitions[i], ptr) = LibTransitionCodec.decodeTransition(ptr);
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Calculates the size needed for ProveInput encoding.
    /// @param _numTransitions Number of transitions in the array.
    /// @return size_ Total byte size needed.
    function _calculateProveInputSize(uint256 _numTransitions)
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed fields:
            //   firstProposalId: 6 bytes
            //   firstProposalParentBlockHash: 32 bytes
            //   lastProposalHash: 32 bytes
            //   actualProver: 20 bytes
            //   endBlockNumber: 6 bytes
            //   endStateRoot: 32 bytes
            //   transitions array length: 2 bytes
            // Total fixed: 130 bytes
            size_ = 130 + (_numTransitions * LibTransitionCodec.TRANSITION_SIZE);
        }
    }
}
