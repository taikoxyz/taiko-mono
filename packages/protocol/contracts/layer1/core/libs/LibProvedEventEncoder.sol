// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProvedEventEncoder
/// @notice Compact encoder/decoder for ProvedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProvedEventEncoder {
    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding.
    function encode(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 bufferSize =
            calculateProvedEventSize(_payload.transitionRecord.bondInstructions.length);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, _payload.proposalId);

        ptr = P.packBytes32(ptr, _payload.transition.proposalHash);
        ptr = P.packBytes32(ptr, _payload.transition.parentTransitionHash);
        ptr = P.packUint48(ptr, _payload.transition.checkpoint.blockNumber);
        ptr = P.packBytes32(ptr, _payload.transition.checkpoint.blockHash);
        ptr = P.packBytes32(ptr, _payload.transition.checkpoint.stateRoot);

        ptr = P.packBytes32(ptr, _payload.transitionRecord.transitionHash);
        ptr = P.packBytes32(ptr, _payload.transitionRecord.checkpointHash);

        ptr = P.packAddress(ptr, _payload.metadata.designatedProver);
        ptr = P.packAddress(ptr, _payload.metadata.actualProver);

        P.checkArrayLength(_payload.transitionRecord.bondInstructions.length);
        ptr = P.packUint16(ptr, uint16(_payload.transitionRecord.bondInstructions.length));
        for (uint256 i; i < _payload.transitionRecord.bondInstructions.length; ++i) {
            ptr = P.packUint48(ptr, _payload.transitionRecord.bondInstructions[i].proposalId);
            ptr = P.packUint8(ptr, uint8(_payload.transitionRecord.bondInstructions[i].bondType));
            ptr = P.packAddress(ptr, _payload.transitionRecord.bondInstructions[i].payer);
            ptr = P.packAddress(ptr, _payload.transitionRecord.bondInstructions[i].payee);
        }
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        (payload_.proposalId, ptr) = P.unpackUint48(ptr);

        (payload_.transition.proposalHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.parentTransitionHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.checkpoint.blockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.transition.checkpoint.blockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.checkpoint.stateRoot, ptr) = P.unpackBytes32(ptr);

        (payload_.transitionRecord.transitionHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transitionRecord.checkpointHash, ptr) = P.unpackBytes32(ptr);

        (payload_.metadata.designatedProver, ptr) = P.unpackAddress(ptr);
        (payload_.metadata.actualProver, ptr) = P.unpackAddress(ptr);

        uint16 arrayLength;
        (arrayLength, ptr) = P.unpackUint16(ptr);

        payload_.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i; i < arrayLength; ++i) {
            (payload_.transitionRecord.bondInstructions[i].proposalId, ptr) = P.unpackUint48(ptr);

            uint8 bondTypeValue;
            (bondTypeValue, ptr) = P.unpackUint8(ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), InvalidBondType());
            payload_.transitionRecord.bondInstructions[i].bondType =
                LibBonds.BondType(bondTypeValue);

            (payload_.transitionRecord.bondInstructions[i].payer, ptr) = P.unpackAddress(ptr);
            (payload_.transitionRecord.bondInstructions[i].payee, ptr) = P.unpackAddress(ptr);
        }
    }

    /// @notice Calculate the exact byte size needed for encoding a ProvedEventPayload.
    function calculateProvedEventSize(uint256 _bondInstructionsCount)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 246 bytes
            // proposalId: 6
            // Transition: 134
            // TransitionRecord (without bond instructions): transitionHash(32) +
            //   checkpointHash(32) = 64
            // Metadata: 40
            // Bond instructions length: 2
            size_ = 246 + (_bondInstructionsCount * 47);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidBondType();
}
