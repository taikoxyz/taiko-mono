// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposeInputDecoder
/// @notice Library for encoding and decoding propose data with gas optimization using LibPackUnpack
/// @custom:security-contact security@taiko.xyz
library LibProposeInputDecoder {
    /// @notice Encodes propose data using compact encoding
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encode(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProposeDataSize(
            _input.parentProposals, _input.claimRecords, _input.endBlockMiniHeader
        );
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode deadline
        ptr = P.packUint48(ptr, _input.deadline);

        // 2. Encode CoreState
        ptr = P.packUint48(ptr, _input.coreState.nextProposalId);
        ptr = P.packUint48(ptr, _input.coreState.lastFinalizedProposalId);
        ptr = P.packBytes32(ptr, _input.coreState.lastFinalizedClaimHash);
        ptr = P.packBytes32(ptr, _input.coreState.bondInstructionsHash);

        // 3. Encode parent proposals array
        ptr = P.packUint24(ptr, uint24(_input.parentProposals.length));
        for (uint256 i; i < _input.parentProposals.length; ++i) {
            ptr = _encodeProposal(ptr, _input.parentProposals[i]);
        }

        // 4. Encode BlobReference
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);

        // 5. Encode ClaimRecords array
        ptr = P.packUint24(ptr, uint24(_input.claimRecords.length));
        for (uint256 i; i < _input.claimRecords.length; ++i) {
            ptr = _encodeClaimRecord(ptr, _input.claimRecords[i]);
        }

        // 6. Encode BlockMiniHeader with optimization for empty header
        // Check if endBlockMiniHeader is empty (all fields are zero)
        bool isEmpty = _input.endBlockMiniHeader.number == 0
            && _input.endBlockMiniHeader.hash == bytes32(0)
            && _input.endBlockMiniHeader.stateRoot == bytes32(0);

        // Write flag byte: 0 for empty, 1 for non-empty
        ptr = P.packUint8(ptr, isEmpty ? 0 : 1);

        // Only encode the full header if it's not empty
        if (!isEmpty) {
            ptr = P.packUint48(ptr, _input.endBlockMiniHeader.number);
            ptr = P.packBytes32(ptr, _input.endBlockMiniHeader.hash);
            ptr = P.packBytes32(ptr, _input.endBlockMiniHeader.stateRoot);
        }
    }

    /// @notice Decodes propose data using optimized operations with LibPackUnpack
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decode(bytes memory _data) internal pure returns (IInbox.ProposeInput memory input_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode deadline
        (input_.deadline, ptr) = P.unpackUint48(ptr);

        // 2. Decode CoreState
        (input_.coreState.nextProposalId, ptr) = P.unpackUint48(ptr);
        (input_.coreState.lastFinalizedProposalId, ptr) = P.unpackUint48(ptr);
        (input_.coreState.lastFinalizedClaimHash, ptr) = P.unpackBytes32(ptr);
        (input_.coreState.bondInstructionsHash, ptr) = P.unpackBytes32(ptr);

        // 3. Decode parent proposals array
        uint24 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint24(ptr);
        input_.parentProposals = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (input_.parentProposals[i], ptr) = _decodeProposal(ptr);
        }

        // 4. Decode BlobReference
        (input_.blobReference.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.numBlobs, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.offset, ptr) = P.unpackUint24(ptr);

        // 5. Decode ClaimRecords array
        uint24 claimRecordsLength;
        (claimRecordsLength, ptr) = P.unpackUint24(ptr);
        input_.claimRecords = new IInbox.ClaimRecord[](claimRecordsLength);
        for (uint256 i; i < claimRecordsLength; ++i) {
            (input_.claimRecords[i], ptr) = _decodeClaimRecord(ptr);
        }

        // 6. Decode BlockMiniHeader with optimization for empty header
        uint8 headerFlag;
        (headerFlag, ptr) = P.unpackUint8(ptr);

        // If flag is 0, the header is empty, leave it as default (all zeros)
        // If flag is 1, decode the full header
        if (headerFlag == 1) {
            (input_.endBlockMiniHeader.number, ptr) = P.unpackUint48(ptr);
            (input_.endBlockMiniHeader.hash, ptr) = P.unpackBytes32(ptr);
            (input_.endBlockMiniHeader.stateRoot, ptr) = P.unpackBytes32(ptr);
        }
        // else: endBlockMiniHeader remains as default (all zeros)
    }

    /// @notice Encode a single Proposal
    function _encodeProposal(
        uint256 _ptr,
        IInbox.Proposal memory _proposal
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packUint48(_ptr, _proposal.id);
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);
        newPtr_ = P.packUint48(newPtr_, _proposal.timestamp);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.derivationHash);
    }

    /// @notice Decode a single Proposal
    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        (proposal_.id, newPtr_) = P.unpackUint48(_ptr);
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);
        (proposal_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.derivationHash, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Encode a single ClaimRecord
    function _encodeClaimRecord(
        uint256 _ptr,
        IInbox.ClaimRecord memory _claimRecord
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        // Encode span
        newPtr_ = P.packUint8(_ptr, _claimRecord.span);

        // Encode claimHash
        newPtr_ = P.packBytes32(newPtr_, _claimRecord.claimHash);

        // Encode endBlockMiniHeaderHash
        newPtr_ = P.packBytes32(newPtr_, _claimRecord.endBlockMiniHeaderHash);

        // Encode BondInstructions array
        newPtr_ = P.packUint24(newPtr_, uint24(_claimRecord.bondInstructions.length));
        for (uint256 i; i < _claimRecord.bondInstructions.length; ++i) {
            newPtr_ = _encodeBondInstruction(newPtr_, _claimRecord.bondInstructions[i]);
        }
    }

    /// @notice Decode a single ClaimRecord
    function _decodeClaimRecord(uint256 _ptr)
        private
        pure
        returns (IInbox.ClaimRecord memory claimRecord_, uint256 newPtr_)
    {
        // Decode span
        (claimRecord_.span, newPtr_) = P.unpackUint8(_ptr);

        // Decode claimHash
        (claimRecord_.claimHash, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode endBlockMiniHeaderHash
        (claimRecord_.endBlockMiniHeaderHash, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode BondInstructions array
        uint24 bondInstructionsLength;
        (bondInstructionsLength, newPtr_) = P.unpackUint24(newPtr_);
        claimRecord_.bondInstructions = new LibBonds.BondInstruction[](bondInstructionsLength);
        for (uint256 i; i < bondInstructionsLength; ++i) {
            (claimRecord_.bondInstructions[i], newPtr_) = _decodeBondInstruction(newPtr_);
        }
    }

    /// @notice Encode a single BondInstruction
    function _encodeBondInstruction(
        uint256 _ptr,
        LibBonds.BondInstruction memory _bondInstruction
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packUint48(_ptr, _bondInstruction.proposalId);
        newPtr_ = P.packUint8(newPtr_, uint8(_bondInstruction.bondType));
        newPtr_ = P.packAddress(newPtr_, _bondInstruction.payer);
        newPtr_ = P.packAddress(newPtr_, _bondInstruction.receiver);
    }

    /// @notice Decode a single BondInstruction
    function _decodeBondInstruction(uint256 _ptr)
        private
        pure
        returns (LibBonds.BondInstruction memory bondInstruction_, uint256 newPtr_)
    {
        (bondInstruction_.proposalId, newPtr_) = P.unpackUint48(_ptr);

        uint8 bondType;
        (bondType, newPtr_) = P.unpackUint8(newPtr_);
        bondInstruction_.bondType = LibBonds.BondType(bondType);

        (bondInstruction_.payer, newPtr_) = P.unpackAddress(newPtr_);
        (bondInstruction_.receiver, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProposeDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.ClaimRecord[] memory _claimRecords,
        IInbox.BlockMiniHeader memory _endBlockMiniHeader
    )
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed sizes:
            // deadline: 6 bytes (uint48)
            // CoreState: 6 + 6 + 32 + 32 = 76 bytes
            // BlobReference: 2 + 2 + 3 = 7 bytes
            // Arrays lengths: 3 + 3 = 6 bytes
            // BlockMiniHeader flag: 1 byte
            size_ = 96;

            // Add BlockMiniHeader size if not empty
            bool isEmpty = _endBlockMiniHeader.number == 0 && _endBlockMiniHeader.hash == bytes32(0)
                && _endBlockMiniHeader.stateRoot == bytes32(0);

            if (!isEmpty) {
                // BlockMiniHeader when not empty: 6 + 32 + 32 = 70 bytes
                size_ += 70;
            }

            // Proposals - each has fixed size
            // Fixed proposal fields: id(6) + proposer(20) + timestamp(6) + coreStateHash(32) +
            // derivationHash(32) = 96
            for (uint256 i; i < _proposals.length; ++i) {
                size_ += 96;
            }

            // ClaimRecords - each has fixed size + variable bond instructions
            // Fixed: span(1) + claimHash(32) + endBlockMiniHeaderHash(32) + array length(3) =
            // 68
            for (uint256 i; i < _claimRecords.length; ++i) {
                size_ += 68 + (_claimRecords[i].bondInstructions.length * 47);
            }
        }
    }
}
