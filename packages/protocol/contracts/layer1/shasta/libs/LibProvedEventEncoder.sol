// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventEncoder
/// @notice Library for encoding and decoding ProvedEventPayload structures using compact encoding
/// @custom:security-contact security@taiko.xyz
library LibProvedEventEncoder {
    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
    function encode(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize =
            calculateProvedEventSize(_payload.transitionRecord.bondInstructions.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Encode proposalId (uint48)
        ptr = P.packUint48(ptr, _payload.proposalId);

        // Encode Transition struct
        ptr = P.packBytes32(ptr, _payload.transition.proposalHash);
        ptr = P.packBytes32(ptr, _payload.transition.parentTransitionHash);
        // Encode Checkpoint
        ptr = P.packUint48(ptr, _payload.transition.checkpoint.blockNumber);
        ptr = P.packBytes32(ptr, _payload.transition.checkpoint.blockHash);
        ptr = P.packBytes32(ptr, _payload.transition.checkpoint.stateRoot);

        // Encode TransitionRecord
        ptr = P.packUint8(ptr, _payload.transitionRecord.span);
        ptr = P.packBytes32(ptr, _payload.transitionRecord.transitionHash);
        ptr = P.packBytes32(ptr, _payload.transitionRecord.checkpointHash);

        // Encode TransitionMetadata
        ptr = P.packAddress(ptr, _payload.metadata.designatedProver);
        ptr = P.packAddress(ptr, _payload.metadata.actualProver);

        // Encode bond instructions array length (uint16)
        require(
            _payload.transitionRecord.bondInstructions.length <= type(uint16).max,
            BondInstructionsLengthExceeded()
        );
        ptr = P.packUint16(ptr, uint16(_payload.transitionRecord.bondInstructions.length));

        // Encode each bond instruction
        for (uint256 i; i < _payload.transitionRecord.bondInstructions.length; ++i) {
            ptr = P.packUint48(ptr, _payload.transitionRecord.bondInstructions[i].proposalId);
            ptr = P.packUint8(ptr, uint8(_payload.transitionRecord.bondInstructions[i].bondType));
            ptr = P.packAddress(ptr, _payload.transitionRecord.bondInstructions[i].payer);
            ptr = P.packAddress(ptr, _payload.transitionRecord.bondInstructions[i].receiver);
        }
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);
        ptr = _decodeBasicPayload(payload_, ptr);
        _decodeBondInstructions(payload_, ptr);
    }

    /// @notice Decodes basic payload fields
    function _decodeBasicPayload(
        IInbox.ProvedEventPayload memory payload_,
        uint256 ptr
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        // Decode proposalId (uint48)
        (payload_.proposalId, newPtr_) = P.unpackUint48(ptr);

        // Decode Transition struct
        (payload_.transition.proposalHash, newPtr_) = P.unpackBytes32(newPtr_);
        (payload_.transition.parentTransitionHash, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode Checkpoint
        (payload_.transition.checkpoint.blockNumber, newPtr_) = P.unpackUint48(newPtr_);
        (payload_.transition.checkpoint.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (payload_.transition.checkpoint.stateRoot, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode TransitionRecord basic fields
        (payload_.transitionRecord.span, newPtr_) = P.unpackUint8(newPtr_);
        (payload_.transitionRecord.transitionHash, newPtr_) = P.unpackBytes32(newPtr_);
        (payload_.transitionRecord.checkpointHash, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode TransitionMetadata
        (payload_.metadata.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (payload_.metadata.actualProver, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Decodes bond instructions array
    function _decodeBondInstructions(
        IInbox.ProvedEventPayload memory payload_,
        uint256 ptr
    )
        private
        pure
    {
        // Decode bond instructions array length
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
            (payload_.transitionRecord.bondInstructions[i].receiver, ptr) = P.unpackAddress(ptr);
        }
    }

    /// @notice Calculate the exact byte size needed for encoding a ProvedEventPayload
    /// @param _bondInstructionsCount Number of bond instructions (max 65535 due to uint16 encoding)
    /// @return size_ The total byte size needed for encoding
    function calculateProvedEventSize(uint256 _bondInstructionsCount)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 247 bytes
            // proposalId: 6
            // Transition: proposalHash(32) + parentTransitionHash(32) = 64
            //        Checkpoint: number(6) + hash(32) + stateRoot(32) = 70
            // TransitionRecord: span(1) + transitionHash(32) + checkpointHash(32) = 65
            // TransitionMetadata: designatedProver(20) + actualProver(20) = 40
            // bondInstructions array length: 2
            // Total fixed: 6 + 64 + 70 + 65 + 40 + 2 = 247

            // Variable size: each bond instruction is 47 bytes
            // proposalId(6) + bondType(1) + payer(20) + receiver(20) = 47
            size_ = 247 + (_bondInstructionsCount * 47);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BondInstructionsLengthExceeded();
    error InvalidBondType();
}
