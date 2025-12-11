// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProvedEventCodec
/// @notice Compact encoder/decoder for ProvedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProvedEventCodec {
    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding.
    function encode(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        IInbox.Commitment memory c = _payload.input.commitment;
        uint256 bufferSize = _calculateSize(c.transitions.length);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        // Encode Commitment
        ptr = P.packUint48(ptr, c.firstProposalId);
        ptr = P.packBytes32(ptr, c.firstProposalParentCheckpointHash);
        ptr = P.packBytes32(ptr, c.lastProposalHash);
        ptr = P.packAddress(ptr, c.actualProver);

        P.checkArrayLength(c.transitions.length);
        ptr = P.packUint16(ptr, uint16(c.transitions.length));
        for (uint256 i; i < c.transitions.length; ++i) {
            ptr = _encodeTransition(ptr, c.transitions[i]);
        }

        // Encode lastCheckpoint
        ptr = P.packUint48(ptr, c.lastCheckpoint.blockNumber);
        ptr = P.packBytes32(ptr, c.lastCheckpoint.blockHash);
        ptr = P.packBytes32(ptr, c.lastCheckpoint.stateRoot);

        // Encode forceCheckpointSync
        P.packUint8(ptr, _payload.input.forceCheckpointSync ? 1 : 0);
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        // Decode Commitment
        (payload_.input.commitment.firstProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.input.commitment.firstProposalParentCheckpointHash, ptr) = P.unpackBytes32(ptr);
        (payload_.input.commitment.lastProposalHash, ptr) = P.unpackBytes32(ptr);
        (payload_.input.commitment.actualProver, ptr) = P.unpackAddress(ptr);

        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        payload_.input.commitment.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (payload_.input.commitment.transitions[i], ptr) = _decodeTransition(ptr);
        }

        // Decode lastCheckpoint
        (payload_.input.commitment.lastCheckpoint.blockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.input.commitment.lastCheckpoint.blockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.input.commitment.lastCheckpoint.stateRoot, ptr) = P.unpackBytes32(ptr);

        // Decode forceCheckpointSync
        uint8 forceCheckpointSyncByte;
        (forceCheckpointSyncByte,) = P.unpackUint8(ptr);
        payload_.input.forceCheckpointSync = forceCheckpointSyncByte != 0;
    }

    /// @dev Calculate the exact byte size needed for encoding a ProvedEventPayload.
    /// @param _numTransitions Number of transitions in the input.
    /// @return size_ Total byte size needed.
    function _calculateSize(uint256 _numTransitions) private pure returns (uint256 size_) {
        unchecked {
            // ProveInput fixed fields:
            //   firstProposalId: 6 bytes
            //   firstProposalParentCheckpointHash: 32 bytes
            //   lastProposalHash: 32 bytes
            //   actualProver: 20 bytes
            //   transitions array length: 2 bytes
            //   lastCheckpoint.blockNumber: 6 bytes
            //   lastCheckpoint.blockHash: 32 bytes
            //   lastCheckpoint.stateRoot: 32 bytes
            //   forceCheckpointSync: 1 byte
            // Total ProveInput fixed: 163 bytes
            //
            // Per Transition:
            //   proposer: 20 bytes
            //   designatedProver: 20 bytes
            //   timestamp: 6 bytes
            //   checkpointHash: 32 bytes
            // Total per transition: 78 bytes
            //
            // Total = 163 + (numTransitions * 78)
            size_ = 163 + (_numTransitions * 78);
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
