// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibCodec
/// @notice Compact encoder/decoder for Inbox inputs using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    uint256 internal constant TRANSITION_SIZE = 78;
    // ---------------------------------------------------------------
    // ProposeInputCodec Functions
    // ---------------------------------------------------------------

    /// @dev Encodes propose input data using compact packing.
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(15);
        uint256 ptr = P.dataPtr(encoded_);
        ptr = P.packUint48(ptr, _input.deadline);
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);
        ptr = P.packUint8(ptr, _input.numForcedInclusions);
        P.packUint8(ptr, _input.isSelfProving ? 1 : 0);
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
        uint8 isSelfProving;
        (input_.numForcedInclusions, ptr) = P.unpackUint8(ptr);
        (isSelfProving,) = P.unpackUint8(ptr);
        input_.isSelfProving = isSelfProving != 0;
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
            ptr = _encodeTransition(ptr, c.transitions[i]);
        }

        // Encode forceCheckpointSync
        P.packUint8(ptr, _input.forceCheckpointSync ? 1 : 0);
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
            (input_.commitment.transitions[i], ptr) = _decodeTransition(ptr);
        }

        // Decode forceCheckpointSync
        uint8 forceCheckpointSyncByte;
        (forceCheckpointSyncByte,) = P.unpackUint8(ptr);
        input_.forceCheckpointSync = forceCheckpointSyncByte != 0;
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
            //   forceCheckpointSync: 1 byte
            // Total fixed: 131 bytes
            size_ = 131 + (_numTransitions * TRANSITION_SIZE);
        }
    }

    /// @dev Encodes a single transition struct.
    function _encodeTransition(
        uint256 _ptr,
        IInbox.Transition memory _transition
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packAddress(_ptr, _transition.proposer);
        newPtr_ = P.packAddress(newPtr_, _transition.designatedProver);
        newPtr_ = P.packUint48(newPtr_, _transition.timestamp);
        newPtr_ = P.packBytes32(newPtr_, _transition.blockHash);
    }

    /// @dev Decodes a single transition struct.
    function _decodeTransition(uint256 _ptr)
        private
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.proposer, newPtr_) = P.unpackAddress(_ptr);
        (transition_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (transition_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (transition_.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
    }
}
