// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProvedEventCodec
/// @notice Library for encoding and decoding ProvedEventPayload structures for IInbox
/// @custom:security-contact security@taiko.xyz
library LibProvedEventCodec {
    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
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
        ptr = P.packUint48(ptr, _payload.checkpoint.blockNumber);
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

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
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
        (payload_.checkpoint.blockNumber, ptr) = P.unpackUint48(ptr);
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

    /// @notice Calculate the exact byte size needed for encoding a ProvedEventPayload
    /// @param _bondInstructionsCount Number of bond instructions (max 65535 due to uint16 encoding)
    /// @return size_ The total byte size needed for encoding
    function calculateProvedEventSize(uint256 _bondInstructionsCount)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 109 bytes
            // startProposalId: 5
            // parentTransitionHash: 27
            // finalizationDeadline: 5
            // Checkpoint: number(6) + hash(32) + stateRoot(32) = 70
            // bondInstructions array length: 2
            // Total fixed: 5 + 27 + 5 + 70 + 2 = 109

            // Variable size: each bond instruction is 46 bytes
            // proposalId(5) + bondType(1) + payer(20) + payee(20) = 46
            size_ = 82 + _bondInstructionsCount * 46;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidBondType();
}
