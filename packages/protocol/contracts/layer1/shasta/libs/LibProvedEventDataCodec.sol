// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibCodec } from "./LibCodec.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventDataCodec
/// @notice Library for encoding and decoding ClaimRecord structures using compact encoding
/// @custom:security-contact security@taiko.xyz
library LibProvedEventDataCodec {
    /// @notice Encodes a ClaimRecord into bytes using compact encoding
    /// @param _record The ClaimRecord to encode
    /// @return encoded_ The encoded bytes
    function encode(IInbox.ClaimRecord memory _record)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = LibCodec.calculateClaimRecordSize(_record.bondInstructions.length);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibCodec.dataPtr(encoded_);

        // Encode proposalId (uint48)
        ptr = LibCodec.packUint48(encoded_, ptr, _record.proposalId);

        // Encode Claim struct
        ptr = LibCodec.packBytes32(encoded_, ptr, _record.claim.proposalHash);
        ptr = LibCodec.packBytes32(encoded_, ptr, _record.claim.parentClaimHash);
        ptr = LibCodec.packUint48(encoded_, ptr, _record.claim.endBlockNumber);
        ptr = LibCodec.packBytes32(encoded_, ptr, _record.claim.endBlockHash);
        ptr = LibCodec.packBytes32(encoded_, ptr, _record.claim.endStateRoot);
        ptr = LibCodec.packAddress(encoded_, ptr, _record.claim.designatedProver);
        ptr = LibCodec.packAddress(encoded_, ptr, _record.claim.actualProver);

        // Encode span (uint8)
        ptr = LibCodec.packUint8(encoded_, ptr, _record.span);

        // Encode bond instructions array length (uint16)
        require(_record.bondInstructions.length <= type(uint16).max, "Too many bond instructions");
        ptr = LibCodec.packUint16(encoded_, ptr, uint16(_record.bondInstructions.length));

        // Encode each bond instruction
        for (uint256 i = 0; i < _record.bondInstructions.length; i++) {
            ptr = LibCodec.packUint48(encoded_, ptr, _record.bondInstructions[i].proposalId);
            ptr = LibCodec.packUint8(encoded_, ptr, uint8(_record.bondInstructions[i].bondType));
            ptr = LibCodec.packAddress(encoded_, ptr, _record.bondInstructions[i].payer);
            ptr = LibCodec.packAddress(encoded_, ptr, _record.bondInstructions[i].receiver);
        }
    }

    /// @notice Decodes bytes into a ClaimRecord using compact encoding
    /// @param _data The bytes to decode
    /// @return record_ The decoded ClaimRecord
    function decode(bytes memory _data) internal pure returns (IInbox.ClaimRecord memory record_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibCodec.dataPtr(_data);

        // Decode proposalId (uint48)
        (record_.proposalId, ptr) = LibCodec.unpackUint48(_data, ptr);

        // Decode Claim struct
        (record_.claim.proposalHash, ptr) = LibCodec.unpackBytes32(_data, ptr);
        (record_.claim.parentClaimHash, ptr) = LibCodec.unpackBytes32(_data, ptr);
        (record_.claim.endBlockNumber, ptr) = LibCodec.unpackUint48(_data, ptr);
        (record_.claim.endBlockHash, ptr) = LibCodec.unpackBytes32(_data, ptr);
        (record_.claim.endStateRoot, ptr) = LibCodec.unpackBytes32(_data, ptr);
        (record_.claim.designatedProver, ptr) = LibCodec.unpackAddress(_data, ptr);
        (record_.claim.actualProver, ptr) = LibCodec.unpackAddress(_data, ptr);

        // Decode span (uint8)
        (record_.span, ptr) = LibCodec.unpackUint8(_data, ptr);

        // Decode bond instructions array length (uint16)
        uint16 arrayLength;
        (arrayLength, ptr) = LibCodec.unpackUint16(_data, ptr);

        // Decode bond instructions
        record_.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            (record_.bondInstructions[i].proposalId, ptr) = LibCodec.unpackUint48(_data, ptr);

            uint8 bondTypeValue;
            (bondTypeValue, ptr) = LibCodec.unpackUint8(_data, ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), "Invalid bond type");
            record_.bondInstructions[i].bondType = LibBonds.BondType(bondTypeValue);

            (record_.bondInstructions[i].payer, ptr) = LibCodec.unpackAddress(_data, ptr);
            (record_.bondInstructions[i].receiver, ptr) = LibCodec.unpackAddress(_data, ptr);
        }
    }
}
