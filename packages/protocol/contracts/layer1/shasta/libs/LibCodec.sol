// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibCodec
/// @notice Library for encoding and decoding event data for gas optimization using assembly
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    /// @dev Encodes the proposed event data using abi.encodePacked for gas optimization
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return encoded The encoded data
    function encodeProposedEventData(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory encoded)
    {
        uint256 blobHashesLen = _proposal.blobSlice.blobHashes.length;

        // Calculate total size:
        // 6 (id) + 20 (proposer) + 6 (originTimestamp) + 6 (originBlockNumber) +
        // 1 (isForcedInclusion) + 1 (basefeeSharingPctg) + 2 (blobHashes length) +
        // 32 * blobHashesLen + 3 (offset) + 6 (timestamp) + 32 (coreStateHash) +
        // 6 (nextProposalId) + 6 (lastFinalizedProposalId) + 32 (lastFinalizedClaimHash) +
        // 32 (bondInstructionsHash)
        uint256 totalSize = 182 + (32 * blobHashesLen);

        encoded = new bytes(totalSize);
        uint256 offset = 0;
        
        // Encode Proposal fields
        offset = _encodeUint48(encoded, offset, _proposal.id);
        offset = _encodeAddress(encoded, offset, _proposal.proposer);
        offset = _encodeUint48(encoded, offset, _proposal.originTimestamp);
        offset = _encodeUint48(encoded, offset, _proposal.originBlockNumber);
        encoded[offset++] = _proposal.isForcedInclusion ? bytes1(0x01) : bytes1(0x00);
        encoded[offset++] = bytes1(_proposal.basefeeSharingPctg);
        
        // Encode blob hashes length
        encoded[offset++] = bytes1(uint8(blobHashesLen >> 8));
        encoded[offset++] = bytes1(uint8(blobHashesLen));
        
        // Encode blob hashes
        for (uint256 i = 0; i < blobHashesLen; i++) {
            offset = _encodeBytes32(encoded, offset, _proposal.blobSlice.blobHashes[i]);
        }
        
        // Encode blob slice fields
        offset = _encodeUint24(encoded, offset, _proposal.blobSlice.offset);
        offset = _encodeUint48(encoded, offset, _proposal.blobSlice.timestamp);
        
        // Encode coreStateHash
        offset = _encodeBytes32(encoded, offset, _proposal.coreStateHash);
        
        // Encode CoreState fields
        offset = _encodeUint48(encoded, offset, _coreState.nextProposalId);
        offset = _encodeUint48(encoded, offset, _coreState.lastFinalizedProposalId);
        offset = _encodeBytes32(encoded, offset, _coreState.lastFinalizedClaimHash);
        _encodeBytes32(encoded, offset, _coreState.bondInstructionsHash);
    }
    
    function _encodeUint48(bytes memory _data, uint256 _offset, uint48 _value)
        private
        pure
        returns (uint256)
    {
        _data[_offset] = bytes1(uint8(_value >> 40));
        _data[_offset + 1] = bytes1(uint8(_value >> 32));
        _data[_offset + 2] = bytes1(uint8(_value >> 24));
        _data[_offset + 3] = bytes1(uint8(_value >> 16));
        _data[_offset + 4] = bytes1(uint8(_value >> 8));
        _data[_offset + 5] = bytes1(uint8(_value));
        return _offset + 6;
    }
    
    function _encodeUint24(bytes memory _data, uint256 _offset, uint24 _value)
        private
        pure
        returns (uint256)
    {
        _data[_offset] = bytes1(uint8(_value >> 16));
        _data[_offset + 1] = bytes1(uint8(_value >> 8));
        _data[_offset + 2] = bytes1(uint8(_value));
        return _offset + 3;
    }
    
    function _encodeAddress(bytes memory _data, uint256 _offset, address _value)
        private
        pure
        returns (uint256)
    {
        bytes20 addrBytes = bytes20(_value);
        for (uint256 i = 0; i < 20; i++) {
            _data[_offset + i] = addrBytes[i];
        }
        return _offset + 20;
    }
    
    function _encodeBytes32(bytes memory _data, uint256 _offset, bytes32 _value)
        private
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < 32; i++) {
            _data[_offset + i] = _value[i];
        }
        return _offset + 32;
    }

    /// @dev Encodes the proved event data using abi.encodePacked for gas optimization
    /// @param _claimRecord The claim record to encode
    /// @return encoded The encoded data
    function encodeProveEventData(IInbox.ClaimRecord memory _claimRecord)
        internal
        pure
        returns (bytes memory encoded)
    {
        uint256 bondInstructionsLen = _claimRecord.bondInstructions.length;

        // Calculate total size:
        // 6 (proposalId) + 32 (proposalHash) + 32 (parentClaimHash) + 6 (endBlockNumber) +
        // 32 (endBlockHash) + 32 (endStateRoot) + 20 (designatedProver) + 20 (actualProver) +
        // 1 (span) + 2 (bondInstructions length) + 47 * bondInstructionsLen
        uint256 totalSize = 183 + (47 * bondInstructionsLen);

        encoded = new bytes(totalSize);
        
        // Encode claim data
        uint256 offset = _encodeClaim(encoded, 0, _claimRecord.claim);
        
        // Encode span
        encoded[offset] = bytes1(uint8(_claimRecord.span));
        offset += 1;
        
        // Encode bond instructions length
        encoded[offset] = bytes1(uint8(bondInstructionsLen >> 8));
        encoded[offset + 1] = bytes1(uint8(bondInstructionsLen));
        offset += 2;
        
        // Encode bond instructions
        _encodeBondInstructions(encoded, offset, _claimRecord.bondInstructions);
    }
    
    /// @dev Helper function to encode a Claim into packed data
    function _encodeClaim(
        bytes memory _data,
        uint256 _offset,
        IInbox.Claim memory _claim
    )
        private
        pure
        returns (uint256 newOffset_)
    {
        newOffset_ = _offset;
        newOffset_ = _encodeUint48(_data, newOffset_, _claim.proposalId);
        newOffset_ = _encodeBytes32(_data, newOffset_, _claim.proposalHash);
        newOffset_ = _encodeBytes32(_data, newOffset_, _claim.parentClaimHash);
        newOffset_ = _encodeUint48(_data, newOffset_, _claim.endBlockNumber);
        newOffset_ = _encodeBytes32(_data, newOffset_, _claim.endBlockHash);
        newOffset_ = _encodeBytes32(_data, newOffset_, _claim.endStateRoot);
        newOffset_ = _encodeAddress(_data, newOffset_, _claim.designatedProver);
        newOffset_ = _encodeAddress(_data, newOffset_, _claim.actualProver);
    }
    
    /// @dev Helper function to encode bond instructions into packed data
    function _encodeBondInstructions(
        bytes memory _data,
        uint256 _offset,
        LibBonds.BondInstruction[] memory _instructions
    )
        private
        pure
    {
        for (uint256 i = 0; i < _instructions.length; i++) {
            _offset = _encodeUint48(_data, _offset, _instructions[i].proposalId);
            _data[_offset++] = bytes1(uint8(_instructions[i].bondType));
            _offset = _encodeAddress(_data, _offset, _instructions[i].payer);
            _offset = _encodeAddress(_data, _offset, _instructions[i].receiver);
        }
    }

    /// @dev Decodes the proposed event data that was encoded using abi.encodePacked
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decodeProposedEventData(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        require(_data.length >= 182, "Invalid data length");

        uint256 offset = 0;
        
        // Decode basic proposal fields
        proposal_.id = uint48(uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32 | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16 | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5])));
        offset += 6;
        
        proposal_.proposer = address(bytes20(_extractBytes(_data, offset, 20)));
        offset += 20;
        
        proposal_.originTimestamp = uint48(uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32 | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16 | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5])));
        offset += 6;
        
        proposal_.originBlockNumber = uint48(uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32 | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16 | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5])));
        offset += 6;
        
        proposal_.isForcedInclusion = _data[offset] != 0;
        offset += 1;
        
        proposal_.basefeeSharingPctg = uint8(_data[offset]);
        offset += 1;
        
        // Decode blob slice
        uint16 blobHashesLen = uint16(uint8(_data[offset]) << 8 | uint8(_data[offset + 1]));
        offset += 2;
        
        bytes32[] memory blobHashes = new bytes32[](blobHashesLen);
        for (uint256 i = 0; i < blobHashesLen; i++) {
            blobHashes[i] = bytes32(_extractBytes(_data, offset, 32));
            offset += 32;
        }
        
        proposal_.blobSlice.blobHashes = blobHashes;
        proposal_.blobSlice.offset = uint24(uint256(uint8(_data[offset])) << 16 | uint256(uint8(_data[offset + 1])) << 8 | uint256(uint8(_data[offset + 2])));
        offset += 3;
        
        proposal_.blobSlice.timestamp = uint48(uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32 | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16 | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5])));
        offset += 6;
        
        // Decode coreStateHash
        proposal_.coreStateHash = bytes32(_extractBytes(_data, offset, 32));
        offset += 32;
        
        // Decode CoreState fields
        coreState_.nextProposalId = uint48(uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32 | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16 | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5])));
        offset += 6;
        
        coreState_.lastFinalizedProposalId = uint48(uint256(uint8(_data[offset])) << 40 | uint256(uint8(_data[offset + 1])) << 32 | uint256(uint8(_data[offset + 2])) << 24 | uint256(uint8(_data[offset + 3])) << 16 | uint256(uint8(_data[offset + 4])) << 8 | uint256(uint8(_data[offset + 5])));
        offset += 6;
        
        coreState_.lastFinalizedClaimHash = bytes32(_extractBytes(_data, offset, 32));
        offset += 32;
        
        coreState_.bondInstructionsHash = bytes32(_extractBytes(_data, offset, 32));
    }
    
    /// @dev Helper function to extract bytes from data
    function _extractBytes(bytes memory _data, uint256 _start, uint256 _length)
        private
        pure
        returns (bytes memory)
    {
        bytes memory result = new bytes(_length);
        for (uint256 i = 0; i < _length; i++) {
            result[i] = _data[_start + i];
        }
        return result;
    }

    /// @dev Decodes the prove event data that was encoded using abi.encodePacked
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    function decodeProveEventData(bytes memory _data)
        internal
        pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        require(_data.length >= 183, "Invalid data length");

        uint256 offset = 0;
        
        // Decode claim
        (IInbox.Claim memory claim, uint256 newOffset) = _decodeClaim(_data, offset);
        claimRecord_.claim = claim;
        offset = newOffset;
        
        // Decode span
        claimRecord_.span = uint8(_data[offset]);
        offset += 1;
        
        // Decode bond instructions
        uint16 bondInstructionsLen = uint16(uint8(_data[offset]) << 8 | uint8(_data[offset + 1]));
        offset += 2;
        
        claimRecord_.bondInstructions = _decodeBondInstructions(_data, offset, bondInstructionsLen);
    }
    
    /// @dev Helper function to decode a Claim from packed data
    function _decodeClaim(bytes memory _data, uint256 _offset)
        private
        pure
        returns (IInbox.Claim memory claim_, uint256 newOffset_)
    {
        newOffset_ = _offset;
        
        // Decode proposalId (6 bytes -> uint48)
        claim_.proposalId = uint48(uint256(uint8(_data[newOffset_])) << 40 | uint256(uint8(_data[newOffset_ + 1])) << 32 | uint256(uint8(_data[newOffset_ + 2])) << 24 | uint256(uint8(_data[newOffset_ + 3])) << 16 | uint256(uint8(_data[newOffset_ + 4])) << 8 | uint256(uint8(_data[newOffset_ + 5])));
        newOffset_ += 6;
        
        // Decode proposalHash
        claim_.proposalHash = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;
        
        // Decode parentClaimHash
        claim_.parentClaimHash = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;
        
        // Decode endBlockNumber (6 bytes -> uint48)
        claim_.endBlockNumber = uint48(uint256(uint8(_data[newOffset_])) << 40 | uint256(uint8(_data[newOffset_ + 1])) << 32 | uint256(uint8(_data[newOffset_ + 2])) << 24 | uint256(uint8(_data[newOffset_ + 3])) << 16 | uint256(uint8(_data[newOffset_ + 4])) << 8 | uint256(uint8(_data[newOffset_ + 5])));
        newOffset_ += 6;
        
        // Decode endBlockHash
        claim_.endBlockHash = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;
        
        // Decode endStateRoot
        claim_.endStateRoot = bytes32(_extractBytes(_data, newOffset_, 32));
        newOffset_ += 32;
        
        // Decode designatedProver (20 bytes -> address)
        claim_.designatedProver = address(bytes20(_extractBytes(_data, newOffset_, 20)));
        newOffset_ += 20;
        
        // Decode actualProver (20 bytes -> address)
        claim_.actualProver = address(bytes20(_extractBytes(_data, newOffset_, 20)));
        newOffset_ += 20;
    }
    
    /// @dev Helper function to decode bond instructions from packed data
    function _decodeBondInstructions(
        bytes memory _data,
        uint256 _offset,
        uint256 _length
    )
        private
        pure
        returns (LibBonds.BondInstruction[] memory instructions_)
    {
        instructions_ = new LibBonds.BondInstruction[](_length);
        
        for (uint256 i = 0; i < _length; i++) {
            // Decode proposalId (6 bytes -> uint48)
            instructions_[i].proposalId = uint48(uint256(uint8(_data[_offset])) << 40 | uint256(uint8(_data[_offset + 1])) << 32 | uint256(uint8(_data[_offset + 2])) << 24 | uint256(uint8(_data[_offset + 3])) << 16 | uint256(uint8(_data[_offset + 4])) << 8 | uint256(uint8(_data[_offset + 5])));
            _offset += 6;
            
            // Decode bondType (1 byte -> uint8)
            instructions_[i].bondType = LibBonds.BondType(uint8(_data[_offset]));
            _offset += 1;
            
            // Decode payer (20 bytes -> address)
            instructions_[i].payer = address(bytes20(_extractBytes(_data, _offset, 20)));
            _offset += 20;
            
            // Decode receiver (20 bytes -> address)  
            instructions_[i].receiver = address(bytes20(_extractBytes(_data, _offset, 20)));
            _offset += 20;
        }
    }
}
