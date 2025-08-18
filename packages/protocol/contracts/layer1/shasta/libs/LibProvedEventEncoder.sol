// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventEncoder
/// @notice Library for encoding and decoding ClaimRecord structures using compact encoding.
/// Fields are reordered during encoding to pack smaller fields together within 32-byte boundaries,
/// minimizing the number of storage slots accessed and reducing gas costs.
/// @custom:security-contact security@taiko.xyz
library LibProvedEventEncoder {
    /// @notice Encodes a ClaimRecord into bytes using compact encoding
    /// @param _record The ClaimRecord to encode
    /// @return encoded_ The encoded bytes
    function encode(IInbox.ClaimRecord memory _record)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = calculateClaimRecordSize(_record.bondInstructions.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // Pack small fields together: proposalId(6) + endBlockNumber(6) + span(1) + arrayLength(2)
        // = 15 bytes
        ptr = P.packUint48(ptr, _record.proposalId);
        ptr = P.packUint48(ptr, _record.claim.endBlockNumber);
        ptr = P.packUint8(ptr, _record.span);

        require(
            _record.bondInstructions.length <= type(uint16).max, BondInstructionsLengthExceeded()
        );
        ptr = P.packUint16(ptr, uint16(_record.bondInstructions.length));

        // Pack addresses together (20 + 20 = 40 bytes)
        ptr = P.packAddress(ptr, _record.claim.designatedProver);
        ptr = P.packAddress(ptr, _record.claim.actualProver);

        // Pack bytes32 fields
        ptr = P.packBytes32(ptr, _record.claim.proposalHash);
        ptr = P.packBytes32(ptr, _record.claim.parentClaimHash);
        ptr = P.packBytes32(ptr, _record.claim.endBlockHash);
        ptr = P.packBytes32(ptr, _record.claim.endStateRoot);

        // Encode each bond instruction with optimized field packing
        for (uint256 i; i < _record.bondInstructions.length; ++i) {
            // Pack small fields: proposalId(6) + bondType(1) = 7 bytes
            ptr = P.packUint48(ptr, _record.bondInstructions[i].proposalId);
            ptr = P.packUint8(ptr, uint8(_record.bondInstructions[i].bondType));
            // Pack addresses: payer(20) + receiver(20) = 40 bytes
            ptr = P.packAddress(ptr, _record.bondInstructions[i].payer);
            ptr = P.packAddress(ptr, _record.bondInstructions[i].receiver);
        }
    }

    /// @notice Decodes bytes into a ClaimRecord using compact encoding
    /// @param _data The bytes to decode
    /// @return record_ The decoded ClaimRecord
    function decode(bytes memory _data) internal pure returns (IInbox.ClaimRecord memory record_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // Unpack small fields together: proposalId(6) + endBlockNumber(6) + span(1) +
        // arrayLength(2) = 15 bytes
        (record_.proposalId, ptr) = P.unpackUint48(ptr);
        (record_.claim.endBlockNumber, ptr) = P.unpackUint48(ptr);
        (record_.span, ptr) = P.unpackUint8(ptr);

        uint16 arrayLength;
        (arrayLength, ptr) = P.unpackUint16(ptr);

        // Unpack addresses together (20 + 20 = 40 bytes)
        (record_.claim.designatedProver, ptr) = P.unpackAddress(ptr);
        (record_.claim.actualProver, ptr) = P.unpackAddress(ptr);

        // Unpack bytes32 fields
        (record_.claim.proposalHash, ptr) = P.unpackBytes32(ptr);
        (record_.claim.parentClaimHash, ptr) = P.unpackBytes32(ptr);
        (record_.claim.endBlockHash, ptr) = P.unpackBytes32(ptr);
        (record_.claim.endStateRoot, ptr) = P.unpackBytes32(ptr);

        // Decode bond instructions with optimized field unpacking
        record_.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i; i < arrayLength; ++i) {
            // Unpack small fields: proposalId(6) + bondType(1) = 7 bytes
            (record_.bondInstructions[i].proposalId, ptr) = P.unpackUint48(ptr);

            uint8 bondTypeValue;
            (bondTypeValue, ptr) = P.unpackUint8(ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), InvalidBondType());
            record_.bondInstructions[i].bondType = LibBonds.BondType(bondTypeValue);

            // Unpack addresses: payer(20) + receiver(20) = 40 bytes
            (record_.bondInstructions[i].payer, ptr) = P.unpackAddress(ptr);
            (record_.bondInstructions[i].receiver, ptr) = P.unpackAddress(ptr);
        }
    }

    /// @notice Calculate the exact byte size needed for encoding a ClaimRecord
    /// @param _bondInstructionsCount Number of bond instructions (max 65535 due to uint16 encoding)
    /// @return size_ The total byte size needed for encoding
    function calculateClaimRecordSize(uint256 _bondInstructionsCount)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size: 183 bytes
            // Small fields: proposalId(6) + endBlockNumber(6) + span(1) + arrayLength(2) = 15
            // Addresses: designatedProver(20) + actualProver(20) = 40
            // Bytes32 fields: proposalHash(32) + parentClaimHash(32) + endBlockHash(32) +
            // endStateRoot(32) = 128
            // Total fixed: 15 + 40 + 128 = 183

            // Variable size: each bond instruction is 47 bytes
            // proposalId(6) + bondType(1) + payer(20) + receiver(20) = 47
            size_ = 183 + (_bondInstructionsCount * 47);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BondInstructionsLengthExceeded();
    error InvalidBondType();
}
