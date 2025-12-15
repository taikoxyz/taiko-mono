// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibTransitionCodec } from "./LibTransitionCodec.sol";

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
        (payload_.input.commitment.firstProposalParentBlockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.input.commitment.lastProposalHash, ptr) = P.unpackBytes32(ptr);
        (payload_.input.commitment.actualProver, ptr) = P.unpackAddress(ptr);
        (payload_.input.commitment.endBlockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.input.commitment.endStateRoot, ptr) = P.unpackBytes32(ptr);

        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        payload_.input.commitment.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (payload_.input.commitment.transitions[i], ptr) =
                LibTransitionCodec.decodeTransition(ptr);
        }

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
            //   firstProposalParentBlockHash: 32 bytes
            //   lastProposalHash: 32 bytes
            //   actualProver: 20 bytes
            //   endBlockNumber: 6 bytes
            //   endStateRoot: 32 bytes
            //   transitions array length: 2 bytes
            //   forceCheckpointSync: 1 byte
            // Total ProveInput fixed: 131 bytes
            //
            // Per Transition:
            //   proposer: 20 bytes
            //   designatedProver: 20 bytes
            //   timestamp: 6 bytes
            //   blockHash: 32 bytes
            // Total per transition: 78 bytes
            //
            // Total = 131 + (numTransitions * 78)
            size_ = 131 + (_numTransitions * LibTransitionCodec.TRANSITION_SIZE);
        }
    }
}
