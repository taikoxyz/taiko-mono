// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPackUnpack } from "./LibPackUnpack.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventCodec
/// @notice Library for encoding and decoding ClaimRecord structures using compact encoding
/// @custom:security-contact security@taiko.xyz
library LibProvedEventCodec {
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
        uint256 ptr = LibPackUnpack.dataPtr(encoded_);

        // Encode proposalId (uint48)
        ptr = LibPackUnpack.packUint48(ptr, _record.proposalId);

        // Encode Claim struct
        ptr = LibPackUnpack.packBytes32(ptr, _record.claim.proposalHash);
        ptr = LibPackUnpack.packBytes32(ptr, _record.claim.parentClaimHash);
        ptr = LibPackUnpack.packUint48(ptr, _record.claim.endBlockNumber);
        ptr = LibPackUnpack.packBytes32(ptr, _record.claim.endBlockHash);
        ptr = LibPackUnpack.packBytes32(ptr, _record.claim.endStateRoot);
        ptr = LibPackUnpack.packAddress(ptr, _record.claim.designatedProver);
        ptr = LibPackUnpack.packAddress(ptr, _record.claim.actualProver);

        // Encode span (uint8)
        ptr = LibPackUnpack.packUint8(ptr, _record.span);

        // Encode bond instructions array length (uint16)
        require(_record.bondInstructions.length <= type(uint16).max);
        ptr = LibPackUnpack.packUint16(ptr, uint16(_record.bondInstructions.length));

        // Encode each bond instruction
        for (uint256 i = 0; i < _record.bondInstructions.length; i++) {
            ptr = LibPackUnpack.packUint48(ptr, _record.bondInstructions[i].proposalId);
            ptr = LibPackUnpack.packUint8(ptr, uint8(_record.bondInstructions[i].bondType));
            ptr = LibPackUnpack.packAddress(ptr, _record.bondInstructions[i].payer);
            ptr = LibPackUnpack.packAddress(ptr, _record.bondInstructions[i].receiver);
        }
    }

    /// @notice Decodes bytes into a ClaimRecord using compact encoding
    /// @param _data The bytes to decode
    /// @return record_ The decoded ClaimRecord
    function decode(bytes memory _data) internal pure returns (IInbox.ClaimRecord memory record_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibPackUnpack.dataPtr(_data);

        // Decode proposalId (uint48)
        (record_.proposalId, ptr) = LibPackUnpack.unpackUint48(ptr);

        // Decode Claim struct
        (record_.claim.proposalHash, ptr) = LibPackUnpack.unpackBytes32(ptr);
        (record_.claim.parentClaimHash, ptr) = LibPackUnpack.unpackBytes32(ptr);
        (record_.claim.endBlockNumber, ptr) = LibPackUnpack.unpackUint48(ptr);
        (record_.claim.endBlockHash, ptr) = LibPackUnpack.unpackBytes32(ptr);
        (record_.claim.endStateRoot, ptr) = LibPackUnpack.unpackBytes32(ptr);
        (record_.claim.designatedProver, ptr) = LibPackUnpack.unpackAddress(ptr);
        (record_.claim.actualProver, ptr) = LibPackUnpack.unpackAddress(ptr);

        // Decode span (uint8)
        (record_.span, ptr) = LibPackUnpack.unpackUint8(ptr);

        // Decode bond instructions array length (uint16)
        uint16 arrayLength;
        (arrayLength, ptr) = LibPackUnpack.unpackUint16(ptr);

        // Decode bond instructions
        record_.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            (record_.bondInstructions[i].proposalId, ptr) = LibPackUnpack.unpackUint48(ptr);

            uint8 bondTypeValue;
            (bondTypeValue, ptr) = LibPackUnpack.unpackUint8(ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS));
            record_.bondInstructions[i].bondType = LibBonds.BondType(bondTypeValue);

            (record_.bondInstructions[i].payer, ptr) = LibPackUnpack.unpackAddress(ptr);
            (record_.bondInstructions[i].receiver, ptr) = LibPackUnpack.unpackAddress(ptr);
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
}
