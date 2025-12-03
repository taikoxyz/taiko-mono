// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProvedEventCodec
/// @notice Compact binary codec for ProvedEventPayload structures emitted by IInbox.
/// @dev Provides gas-efficient encoding/decoding of Proved event data using LibPackUnpack.
/// The encoded format is optimized for L1 calldata costs while maintaining deterministic
/// ordering consistent with struct field definitions.
///
/// Encoding format (variable length):
/// - finalizationDeadline(5) + Checkpoint(70) + bondInstructions array
/// - Each bond instruction: proposalId(5) + bondType(1) + payer(20) + payee(20) = 46 bytes
///
/// @custom:security-contact security@taiko.xyz
library LibProvedEventCodec {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProvedEventPayload into compact binary format.
    /// @dev Allocates exact buffer size via calculateProvedEventSize, then sequentially
    /// packs all fields using LibPackUnpack. Field order matches struct definitions.
    /// @param _payload The ProvedEventPayload containing proof result data.
    /// @return encoded_ The compact binary encoding of the payload.
    function encode(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = calculateProvedEventSize(_payload.bondInstructions.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Encode finalizationDeadline (uint40)
        ptr = P.packUint40(ptr, _payload.finalizationDeadline);

        // Encode Checkpoint
        ptr = P.packUint40(ptr, _payload.checkpoint.blockNumber);
        ptr = P.packBytes32(ptr, _payload.checkpoint.blockHash);
        ptr = P.packBytes32(ptr, _payload.checkpoint.stateRoot);

        // Encode bond instructions array length (uint16)
        P.checkArrayLength(_payload.bondInstructions.length);
        ptr = P.packUint16(ptr, uint16(_payload.bondInstructions.length));

        // Encode each bond instruction
        for (uint256 i; i < _payload.bondInstructions.length; ++i) {
            ptr = P.packUint40(ptr, uint40(_payload.bondInstructions[i].proposalId));
            ptr = P.packUint8(ptr, uint8(_payload.bondInstructions[i].bondType));
            ptr = P.packAddress(ptr, _payload.bondInstructions[i].payer);
            ptr = P.packAddress(ptr, _payload.bondInstructions[i].payee);
        }
    }

    /// @notice Decodes compact binary data into a ProvedEventPayload struct.
    /// @dev Sequentially unpacks all fields using LibPackUnpack in the same order as encode.
    /// Validates bondType enum values during decoding.
    /// @param _data The compact binary encoding produced by encode().
    /// @return payload_ The reconstructed ProvedEventPayload struct.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Decode finalizationDeadline (uint40)
        (payload_.finalizationDeadline, ptr) = P.unpackUint40(ptr);

        // Decode Checkpoint
        (payload_.checkpoint.blockNumber, ptr) = P.unpackUint40(ptr);
        (payload_.checkpoint.blockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.checkpoint.stateRoot, ptr) = P.unpackBytes32(ptr);

        // Decode bond instructions array length (uint16)
        uint16 arrayLength;
        (arrayLength, ptr) = P.unpackUint16(ptr);

        // Decode bond instructions
        payload_.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i; i < arrayLength; ++i) {
            uint40 temp;
            (temp, ptr) = P.unpackUint40(ptr);
            payload_.bondInstructions[i].proposalId = temp;

            uint8 bondTypeValue;
            (bondTypeValue, ptr) = P.unpackUint8(ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), InvalidBondType());
            payload_.bondInstructions[i].bondType = LibBonds.BondType(bondTypeValue);

            (payload_.bondInstructions[i].payer, ptr) = P.unpackAddress(ptr);
            (payload_.bondInstructions[i].payee, ptr) = P.unpackAddress(ptr);
        }
    }

    /// @notice Calculates the exact byte size needed for encoding a ProvedEventPayload.
    /// @dev Fixed size is 77 bytes (finalizationDeadline + checkpoint + array length) plus
    /// 46 bytes per bond instruction.
    /// @param _bondInstructionsCount Number of bond instructions (max 65535 due to uint16 encoding).
    /// @return size_ The total byte size needed for the encoded payload.
    function calculateProvedEventSize(uint256 _bondInstructionsCount)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 77 bytes
            // finalizationDeadline: 5 (uint40)
            // Checkpoint: blockNumber(6) + blockHash(32) + stateRoot(32) = 70
            // bondInstructions array length: 2 (uint16)
            // Total fixed: 5 + 70 + 2 = 77

            // Variable size: each bond instruction is 46 bytes
            // proposalId(5) + bondType(1) + payer(20) + payee(20) = 46
            size_ = 77 + _bondInstructionsCount * 46;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @notice Thrown when decoding encounters an invalid BondType enum value.
    error InvalidBondType();
}
