// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibTransitionCodec } from "./LibTransitionCodec.sol";

/// @title LibProveInputCodec
/// @notice Compact encoder/decoder for ProveInput using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProveInputCodec {
    /// @notice Encodes ProveInput data using compact packing.
    function encode(IInbox.ProveInput memory _input) internal pure returns (bytes memory encoded_) {
        IInbox.Commitment memory c = _input.commitment;
        uint256 bufferSize = _calculateSize(c.transitions.length);
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

        // Encode forceCheckpointSync
        P.packUint8(ptr, _input.forceCheckpointSync ? 1 : 0);
    }

    /// @notice Decodes ProveInput data using compact packing.
    function decode(bytes memory _data) internal pure returns (IInbox.ProveInput memory input_) {
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

        // Decode forceCheckpointSync
        uint8 forceCheckpointSyncByte;
        (forceCheckpointSyncByte,) = P.unpackUint8(ptr);
        input_.forceCheckpointSync = forceCheckpointSyncByte != 0;
    }

    /// @dev Calculate the size needed for encoding.
    /// @param _numTransitions Number of transitions in the array.
    /// @return size_ Total byte size needed.
    function _calculateSize(uint256 _numTransitions) private pure returns (uint256 size_) {
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
            //
            // Per Transition:
            //   proposer: 20 bytes
            //   designatedProver: 20 bytes
            //   timestamp: 6 bytes
            //   blockHash: 32 bytes
            // Total per transition: 78 bytes
            size_ = 131 + (_numTransitions * LibTransitionCodec.TRANSITION_SIZE);
        }
    }
}
