// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventEncoder
/// @notice Library for encoding and decoding ClaimRecord structures using compact encoding
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

        // Encode proposalId (uint48)
        ptr = P.packUint48(ptr, _record.proposalId);

        // Encode Claim struct
        ptr = P.packBytes32(ptr, _record.claim.proposalHash);
        ptr = P.packBytes32(ptr, _record.claim.parentClaimHash);
        ptr = P.packUint48(ptr, _record.claim.endBlockNumber);
        ptr = P.packBytes32(ptr, _record.claim.endBlockHash);
        ptr = P.packBytes32(ptr, _record.claim.endStateRoot);
        ptr = P.packAddress(ptr, _record.claim.designatedProver);
        ptr = P.packAddress(ptr, _record.claim.actualProver);

        // Encode span (uint8)
        ptr = P.packUint8(ptr, _record.span);

        // Encode bond instructions array length (uint16)
        require(
            _record.bondInstructions.length <= type(uint16).max, BondInstructionsLengthExceeded()
        );
        ptr = P.packUint16(ptr, uint16(_record.bondInstructions.length));

        // Encode each bond instruction
        for (uint256 i; i < _record.bondInstructions.length; ++i) {
            ptr = P.packUint48(ptr, _record.bondInstructions[i].proposalId);
            ptr = P.packUint8(ptr, uint8(_record.bondInstructions[i].bondType));
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

        // Decode proposalId (uint48)
        (record_.proposalId, ptr) = P.unpackUint48(ptr);

        // Decode Claim struct
        (record_.claim.proposalHash, ptr) = P.unpackBytes32(ptr);
        (record_.claim.parentClaimHash, ptr) = P.unpackBytes32(ptr);
        (record_.claim.endBlockNumber, ptr) = P.unpackUint48(ptr);
        (record_.claim.endBlockHash, ptr) = P.unpackBytes32(ptr);
        (record_.claim.endStateRoot, ptr) = P.unpackBytes32(ptr);
        (record_.claim.designatedProver, ptr) = P.unpackAddress(ptr);
        (record_.claim.actualProver, ptr) = P.unpackAddress(ptr);

        // Decode span (uint8)
        (record_.span, ptr) = P.unpackUint8(ptr);

        // Decode bond instructions array length (uint16)
        uint16 arrayLength;
        (arrayLength, ptr) = P.unpackUint16(ptr);

        // Decode bond instructions
        record_.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i; i < arrayLength; ++i) {
            (record_.bondInstructions[i].proposalId, ptr) = P.unpackUint48(ptr);

            uint8 bondTypeValue;
            (bondTypeValue, ptr) = P.unpackUint8(ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), InvalidBondType());
            record_.bondInstructions[i].bondType = LibBonds.BondType(bondTypeValue);

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
            // proposalId: 6
            // Claim: proposalHash(32) + parentClaimHash(32) + endBlockHash(32) + endStateRoot(32) =
            // 128
            //        endBlockNumber(6) + designatedProver(20) + actualProver(20) = 46
            // span: 1
            // bondInstructions array length: 2
            // Total fixed: 6 + 128 + 46 + 1 + 2 = 183

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
