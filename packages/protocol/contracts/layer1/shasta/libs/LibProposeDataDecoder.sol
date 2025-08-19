// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBlobs } from "./LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposeDataDecoder
/// @notice Library for encoding and decoding propose data with gas optimization using LibPackUnpack
/// @custom:security-contact security@taiko.xyz
library LibProposeDataDecoder {
    /// @notice Encodes propose data using compact encoding
    /// @param _deadline The deadline
    /// @param _coreState The CoreState
    /// @param _proposals The array of Proposals
    /// @param _blobReference The BlobReference
    /// @param _claimRecords The array of ClaimRecords
    /// @return encoded_ The encoded data
    function encode(
        uint48 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobReference,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProposeDataSize(_proposals, _claimRecords);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode deadline
        ptr = P.packUint48(ptr, _deadline);

        // 2. Encode CoreState
        ptr = P.packUint48(ptr, _coreState.nextProposalId);
        ptr = P.packUint48(ptr, _coreState.lastFinalizedProposalId);
        ptr = P.packBytes32(ptr, _coreState.lastFinalizedClaimHash);
        ptr = P.packBytes32(ptr, _coreState.bondInstructionsHash);

        // 3. Encode Proposals array
        ptr = P.packUint24(ptr, uint24(_proposals.length));
        for (uint256 i; i < _proposals.length; ++i) {
            ptr = _encodeProposal(ptr, _proposals[i]);
        }

        // 4. Encode BlobReference
        ptr = P.packUint16(ptr, _blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _blobReference.numBlobs);
        ptr = P.packUint24(ptr, _blobReference.offset);

        // 5. Encode ClaimRecords array
        ptr = P.packUint24(ptr, uint24(_claimRecords.length));
        for (uint256 i; i < _claimRecords.length; ++i) {
            ptr = _encodeClaimRecord(ptr, _claimRecords[i]);
        }
    }

    /// @notice Decodes propose data using optimized operations with LibPackUnpack
    /// @param _data The encoded data
    /// @return deadline_ The decoded deadline
    /// @return coreState_ The decoded CoreState
    /// @return proposals_ The decoded array of Proposals
    /// @return blobReference_ The decoded BlobReference
    /// @return claimRecords_ The decoded array of ClaimRecords
    function decode(bytes memory _data)
        internal
        pure
        returns (
            uint48 deadline_,
            IInbox.CoreState memory coreState_,
            IInbox.Proposal[] memory proposals_,
            LibBlobs.BlobReference memory blobReference_,
            IInbox.ClaimRecord[] memory claimRecords_
        )
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode deadline
        (deadline_, ptr) = P.unpackUint48(ptr);

        // 2. Decode CoreState
        (coreState_.nextProposalId, ptr) = P.unpackUint48(ptr);
        (coreState_.lastFinalizedProposalId, ptr) = P.unpackUint48(ptr);
        (coreState_.lastFinalizedClaimHash, ptr) = P.unpackBytes32(ptr);
        (coreState_.bondInstructionsHash, ptr) = P.unpackBytes32(ptr);

        // 3. Decode Proposals array
        uint24 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint24(ptr);
        proposals_ = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (proposals_[i], ptr) = _decodeProposal(ptr);
        }

        // 4. Decode BlobReference
        (blobReference_.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (blobReference_.numBlobs, ptr) = P.unpackUint16(ptr);
        (blobReference_.offset, ptr) = P.unpackUint24(ptr);

        // 5. Decode ClaimRecords array
        uint24 claimRecordsLength;
        (claimRecordsLength, ptr) = P.unpackUint24(ptr);
        claimRecords_ = new IInbox.ClaimRecord[](claimRecordsLength);
        for (uint256 i; i < claimRecordsLength; ++i) {
            (claimRecords_[i], ptr) = _decodeClaimRecord(ptr);
        }
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
        newPtr_ = P.packUint48(_ptr, _claimRecord.proposalId);

        // Encode Claim
        newPtr_ = P.packBytes32(newPtr_, _claimRecord.claim.proposalHash);
        newPtr_ = P.packBytes32(newPtr_, _claimRecord.claim.parentClaimHash);
        newPtr_ = P.packUint48(newPtr_, _claimRecord.claim.endBlockNumber);
        newPtr_ = P.packBytes32(newPtr_, _claimRecord.claim.endBlockHash);
        newPtr_ = P.packBytes32(newPtr_, _claimRecord.claim.endStateRoot);
        newPtr_ = P.packAddress(newPtr_, _claimRecord.claim.designatedProver);
        newPtr_ = P.packAddress(newPtr_, _claimRecord.claim.actualProver);

        newPtr_ = P.packUint8(newPtr_, _claimRecord.span);

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
        (claimRecord_.proposalId, newPtr_) = P.unpackUint48(_ptr);

        // Decode Claim
        (claimRecord_.claim.proposalHash, newPtr_) = P.unpackBytes32(newPtr_);
        (claimRecord_.claim.parentClaimHash, newPtr_) = P.unpackBytes32(newPtr_);
        (claimRecord_.claim.endBlockNumber, newPtr_) = P.unpackUint48(newPtr_);
        (claimRecord_.claim.endBlockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (claimRecord_.claim.endStateRoot, newPtr_) = P.unpackBytes32(newPtr_);
        (claimRecord_.claim.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (claimRecord_.claim.actualProver, newPtr_) = P.unpackAddress(newPtr_);

        (claimRecord_.span, newPtr_) = P.unpackUint8(newPtr_);

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
        IInbox.ClaimRecord[] memory _claimRecords
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
            size_ = 95;

            // Proposals - each has fixed size
            // Fixed proposal fields: id(6) + proposer(20) + timestamp(6) + coreStateHash(32) +
            // derivationHash(32) = 96
            for (uint256 i; i < _proposals.length; ++i) {
                size_ += 96;
            }

            // ClaimRecords - each has fixed size + variable bond instructions
            // Fixed: proposalId(6) + Claim(32+32+6+32+32+20+20) + span(1) + array length(3) = 184
            for (uint256 i; i < _claimRecords.length; ++i) {
                size_ += 184 + (_claimRecords[i].bondInstructions.length * 47);
            }
        }
    }
}
