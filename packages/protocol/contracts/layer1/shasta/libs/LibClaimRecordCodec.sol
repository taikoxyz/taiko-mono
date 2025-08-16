// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPackCodec } from "./LibPackCodec.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibClaimRecordCodec
/// @notice Library for encoding and decoding ClaimRecord structures using compact encoding
/// @custom:security-contact security@taiko.xyz
library LibClaimRecordCodec {
    /// @notice Encodes a ClaimRecord into bytes using compact encoding
    /// @param _record The ClaimRecord to encode
    /// @return encoded_ The encoded bytes
    function encode(IInbox.ClaimRecord memory _record)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = LibPackCodec.calculateClaimRecordSize(_record.bondInstructions.length);
        encoded_ = new bytes(bufferSize);
        
        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibPackCodec.dataPtr(encoded_);
        
        // Encode proposalId (uint48)
        ptr = LibPackCodec.packUint48(encoded_, ptr, _record.proposalId);
        
        // Encode Claim struct
        ptr = LibPackCodec.packBytes32(encoded_, ptr, _record.claim.proposalHash);
        ptr = LibPackCodec.packBytes32(encoded_, ptr, _record.claim.parentClaimHash);
        ptr = LibPackCodec.packUint48(encoded_, ptr, _record.claim.endBlockNumber);
        ptr = LibPackCodec.packBytes32(encoded_, ptr, _record.claim.endBlockHash);
        ptr = LibPackCodec.packBytes32(encoded_, ptr, _record.claim.endStateRoot);
        ptr = LibPackCodec.packAddress(encoded_, ptr, _record.claim.designatedProver);
        ptr = LibPackCodec.packAddress(encoded_, ptr, _record.claim.actualProver);
        
        // Encode span (uint8)
        ptr = LibPackCodec.packUint8(encoded_, ptr, _record.span);
        
        // Encode bond instructions array length (uint16)
        require(_record.bondInstructions.length <= type(uint16).max, "Too many bond instructions");
        ptr = LibPackCodec.packUint16(encoded_, ptr, uint16(_record.bondInstructions.length));
        
        // Encode each bond instruction
        for (uint256 i = 0; i < _record.bondInstructions.length; i++) {
            ptr = LibPackCodec.packUint48(encoded_, ptr, _record.bondInstructions[i].proposalId);
            ptr = LibPackCodec.packUint8(encoded_, ptr, uint8(_record.bondInstructions[i].bondType));
            ptr = LibPackCodec.packAddress(encoded_, ptr, _record.bondInstructions[i].payer);
            ptr = LibPackCodec.packAddress(encoded_, ptr, _record.bondInstructions[i].receiver);
        }
    }

    /// @notice Decodes bytes into a ClaimRecord using compact encoding
    /// @param _data The bytes to decode
    /// @return record_ The decoded ClaimRecord
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory record_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = LibPackCodec.dataPtr(_data);
        
        // Decode proposalId (uint48)
        (record_.proposalId, ptr) = LibPackCodec.unpackUint48(_data, ptr);
        
        // Decode Claim struct
        (record_.claim.proposalHash, ptr) = LibPackCodec.unpackBytes32(_data, ptr);
        (record_.claim.parentClaimHash, ptr) = LibPackCodec.unpackBytes32(_data, ptr);
        (record_.claim.endBlockNumber, ptr) = LibPackCodec.unpackUint48(_data, ptr);
        (record_.claim.endBlockHash, ptr) = LibPackCodec.unpackBytes32(_data, ptr);
        (record_.claim.endStateRoot, ptr) = LibPackCodec.unpackBytes32(_data, ptr);
        (record_.claim.designatedProver, ptr) = LibPackCodec.unpackAddress(_data, ptr);
        (record_.claim.actualProver, ptr) = LibPackCodec.unpackAddress(_data, ptr);
        
        // Decode span (uint8)
        (record_.span, ptr) = LibPackCodec.unpackUint8(_data, ptr);
        
        // Decode bond instructions array length (uint16)
        uint16 arrayLength;
        (arrayLength, ptr) = LibPackCodec.unpackUint16(_data, ptr);
        
        // Decode bond instructions
        record_.bondInstructions = new LibBonds.BondInstruction[](arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            (record_.bondInstructions[i].proposalId, ptr) = LibPackCodec.unpackUint48(_data, ptr);
            
            uint8 bondTypeValue;
            (bondTypeValue, ptr) = LibPackCodec.unpackUint8(_data, ptr);
            require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), "Invalid bond type");
            record_.bondInstructions[i].bondType = LibBonds.BondType(bondTypeValue);
            
            (record_.bondInstructions[i].payer, ptr) = LibPackCodec.unpackAddress(_data, ptr);
            (record_.bondInstructions[i].receiver, ptr) = LibPackCodec.unpackAddress(_data, ptr);
        }
    }
}