// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProveInputCodec
/// @notice Compact encoder/decoder for ProveInput using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProveInputCodec {
    /// @notice Encodes ProveInput data using compact packing.
    function encode(IInbox.ProveInput memory _input) internal pure returns (bytes memory encoded_) {
        uint256 bufferSize = _calculateSize(_input.transitions.length);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, _input.firstProposalId);
        ptr = P.packBytes32(ptr, _input.firstProposalParentCheckpointHash);
        ptr = P.packAddress(ptr, _input.actualProver);

        P.checkArrayLength(_input.transitions.length);
        ptr = P.packUint16(ptr, uint16(_input.transitions.length));
        for (uint256 i; i < _input.transitions.length; ++i) {
            _encodeTransition(ptr, _input.transitions[i]);
            ptr += 78; // Transition size: 20 + 20 + 6 + 32 = 78 bytes
        }

        // Encode lastCheckpoint
        ptr = P.packUint48(ptr, _input.lastCheckpoint.blockNumber);
        ptr = P.packBytes32(ptr, _input.lastCheckpoint.blockHash);
        ptr = P.packBytes32(ptr, _input.lastCheckpoint.stateRoot);
    }

    /// @notice Decodes ProveInput data using compact packing.
    function decode(bytes memory _data) internal pure returns (IInbox.ProveInput memory input_) {
        uint256 ptr = P.dataPtr(_data);

        (input_.firstProposalId, ptr) = P.unpackUint48(ptr);
        (input_.firstProposalParentCheckpointHash, ptr) = P.unpackBytes32(ptr);
        (input_.actualProver, ptr) = P.unpackAddress(ptr);

        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        input_.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.transitions[i], ptr) = _decodeTransition(ptr);
        }

        // Decode lastCheckpoint
        (input_.lastCheckpoint.blockNumber, ptr) = P.unpackUint48(ptr);
        (input_.lastCheckpoint.blockHash, ptr) = P.unpackBytes32(ptr);
        (input_.lastCheckpoint.stateRoot, ptr) = P.unpackBytes32(ptr);
    }

    /// @dev Calculate the size needed for encoding.
    /// @param _numTransitions Number of transitions in the array.
    /// @return size_ Total byte size needed.
    function _calculateSize(uint256 _numTransitions) private pure returns (uint256 size_) {
        unchecked {
            // Fixed fields:
            //   firstProposalId: 6 bytes
            //   firstProposalParentCheckpointHash: 32 bytes
            //   actualProver: 20 bytes
            //   transitions array length: 2 bytes
            //   lastCheckpoint.blockNumber: 6 bytes
            //   lastCheckpoint.blockHash: 32 bytes
            //   lastCheckpoint.stateRoot: 32 bytes
            // Total fixed: 130 bytes
            //
            // Per Transition:
            //   proposer: 20 bytes
            //   designatedProver: 20 bytes
            //   timestamp: 6 bytes
            //   checkpointHash: 32 bytes
            // Total per transition: 78 bytes
            size_ = 130 + (_numTransitions * 78);
        }
    }

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
        newPtr_ = P.packBytes32(newPtr_, _transition.checkpointHash);
    }

    function _decodeTransition(uint256 _ptr)
        private
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.proposer, newPtr_) = P.unpackAddress(_ptr);
        (transition_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (transition_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (transition_.checkpointHash, newPtr_) = P.unpackBytes32(newPtr_);
    }
}
