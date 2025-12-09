// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProvedEventCodec
/// @notice Compact encoder/decoder for ProvedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProvedEventCodec {
    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding.
    function encodeProvedEventPayload(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 bufferSize = _calculateSize(_payload.input.proposalStates.length);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        // Encode ProveInput
        ptr = P.packUint48(ptr, _payload.input.firstProposalId);
        ptr = P.packBytes32(ptr, _payload.input.firstProposalParentBlockHash);
        ptr = P.packUint48(ptr, _payload.input.lastBlockNumber);
        ptr = P.packBytes32(ptr, _payload.input.lastStateRoot);
        ptr = P.packAddress(ptr, _payload.input.actualProver);

        P.checkArrayLength(_payload.input.proposalStates.length);
        ptr = P.packUint16(ptr, uint16(_payload.input.proposalStates.length));
        for (uint256 i; i < _payload.input.proposalStates.length; ++i) {
            ptr = _encodeProposalState(ptr, _payload.input.proposalStates[i]);
        }
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding.
    function decodeProvedEventPayload(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        // Decode ProveInput
        (payload_.input.firstProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.input.firstProposalParentBlockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.input.lastBlockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.input.lastStateRoot, ptr) = P.unpackBytes32(ptr);
        (payload_.input.actualProver, ptr) = P.unpackAddress(ptr);

        uint16 proposalStatesLength;
        (proposalStatesLength, ptr) = P.unpackUint16(ptr);
        payload_.input.proposalStates = new IInbox.ProposalState[](proposalStatesLength);
        for (uint256 i; i < proposalStatesLength; ++i) {
            (payload_.input.proposalStates[i], ptr) = _decodeProposalState(ptr);
        }
    }

    /// @dev Calculate the exact byte size needed for encoding a ProvedEventPayload.
    /// @param _numProposalStates Number of proposal states in the input.
    /// @return size_ Total byte size needed.
    function _calculateSize(uint256 _numProposalStates) private pure returns (uint256 size_) {
        unchecked {
            // ProveInput fixed fields:
            //   firstProposalId: 6 bytes
            //   firstProposalParentBlockHash: 32 bytes
            //   lastBlockNumber: 6 bytes
            //   lastStateRoot: 32 bytes
            //   actualProver: 20 bytes
            //   proposalStates array length: 2 bytes
            // Total ProveInput fixed: 98 bytes
            //
            // Per ProposalState:
            //   proposer: 20 bytes
            //   designatedProver: 20 bytes
            //   timestamp: 6 bytes
            //   blockHash: 32 bytes
            // Total per proposal state: 78 bytes
            //
            // Total = 98 + (numProposalStates * 78)
            size_ = 98 + (_numProposalStates * 78);
        }
    }

    function _encodeProposalState(
        uint256 _ptr,
        IInbox.ProposalState memory _state
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packAddress(_ptr, _state.proposer);
        newPtr_ = P.packAddress(newPtr_, _state.designatedProver);
        newPtr_ = P.packUint48(newPtr_, _state.timestamp);
        newPtr_ = P.packBytes32(newPtr_, _state.blockHash);
    }

    function _decodeProposalState(uint256 _ptr)
        private
        pure
        returns (IInbox.ProposalState memory state_, uint256 newPtr_)
    {
        (state_.proposer, newPtr_) = P.unpackAddress(_ptr);
        (state_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (state_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (state_.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
    }
}
