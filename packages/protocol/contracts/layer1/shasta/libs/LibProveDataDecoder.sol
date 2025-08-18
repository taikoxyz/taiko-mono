// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProveDataDecoder
/// @notice Library for encoding and decoding prove data with gas optimization using LibPackUnpack.
/// Fields are reordered during encoding to pack smaller fields together within 32-byte boundaries,
/// minimizing the number of storage slots accessed and reducing gas costs.
/// @custom:security-contact security@taiko.xyz
library LibProveDataDecoder {
    /// @notice Encodes prove data using compact encoding
    /// @param _proposals The array of Proposals to be proven
    /// @param _claims The array of Claims corresponding to the proposals
    /// @return encoded_ The encoded data
    function encode(
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        internal
        pure
        returns (bytes memory encoded_)
    {
        require(_proposals.length == _claims.length, ProposalClaimLengthMismatch());

        // Calculate total size needed
        uint256 bufferSize = _calculateProveDataSize(_proposals);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode Proposals array
        ptr = P.packUint24(ptr, uint24(_proposals.length));
        for (uint256 i; i < _proposals.length; ++i) {
            ptr = _encodeProposal(ptr, _proposals[i]);
        }

        // 2. Encode Claims array
        ptr = P.packUint24(ptr, uint24(_claims.length));
        for (uint256 i; i < _claims.length; ++i) {
            ptr = _encodeClaim(ptr, _claims[i]);
        }
    }

    /// @notice Decodes prove data using optimized operations with LibPackUnpack
    /// @param _data The encoded data
    /// @return proposals_ The decoded array of Proposals
    /// @return claims_ The decoded array of Claims
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal[] memory proposals_, IInbox.Claim[] memory claims_)
    {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode Proposals array
        uint24 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint24(ptr);
        proposals_ = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (proposals_[i], ptr) = _decodeProposal(ptr);
        }

        // 2. Decode Claims array
        uint24 claimsLength;
        (claimsLength, ptr) = P.unpackUint24(ptr);
        require(claimsLength == proposalsLength, ProposalClaimLengthMismatch());
        claims_ = new IInbox.Claim[](claimsLength);
        for (uint256 i; i < claimsLength; ++i) {
            (claims_[i], ptr) = _decodeClaim(ptr);
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
        // Pack small fields together: id(6) + originTimestamp(6) + originBlockNumber(6) +
        // isForcedInclusion(1) + basefeeSharingPctg(1) = 20 bytes
        newPtr_ = P.packUint48(_ptr, _proposal.id);
        newPtr_ = P.packUint48(newPtr_, _proposal.originTimestamp);
        newPtr_ = P.packUint48(newPtr_, _proposal.originBlockNumber);
        newPtr_ = P.packUint8(newPtr_, _proposal.isForcedInclusion ? 1 : 0);
        newPtr_ = P.packUint8(newPtr_, _proposal.basefeeSharingPctg);

        // Pack address separately (20 bytes)
        newPtr_ = P.packAddress(newPtr_, _proposal.proposer);

        // Pack bytes32 fields
        newPtr_ = P.packBytes32(newPtr_, _proposal.originBlockHash);
        newPtr_ = P.packBytes32(newPtr_, _proposal.coreStateHash);

        // Encode BlobSlice - pack small fields together: arrayLength(3) + offset(3) + timestamp(6)
        // = 12 bytes
        newPtr_ = P.packUint24(newPtr_, uint24(_proposal.blobSlice.blobHashes.length));
        newPtr_ = P.packUint24(newPtr_, _proposal.blobSlice.offset);
        newPtr_ = P.packUint48(newPtr_, _proposal.blobSlice.timestamp);

        // Pack blob hashes
        for (uint256 i; i < _proposal.blobSlice.blobHashes.length; ++i) {
            newPtr_ = P.packBytes32(newPtr_, _proposal.blobSlice.blobHashes[i]);
        }
    }

    /// @notice Decode a single Proposal
    function _decodeProposal(uint256 _ptr)
        private
        pure
        returns (IInbox.Proposal memory proposal_, uint256 newPtr_)
    {
        // Unpack small fields together: id(6) + originTimestamp(6) + originBlockNumber(6) +
        // isForcedInclusion(1) + basefeeSharingPctg(1) = 20 bytes
        (proposal_.id, newPtr_) = P.unpackUint48(_ptr);
        (proposal_.originTimestamp, newPtr_) = P.unpackUint48(newPtr_);
        (proposal_.originBlockNumber, newPtr_) = P.unpackUint48(newPtr_);

        uint8 isForcedInclusion;
        (isForcedInclusion, newPtr_) = P.unpackUint8(newPtr_);
        proposal_.isForcedInclusion = isForcedInclusion != 0;

        (proposal_.basefeeSharingPctg, newPtr_) = P.unpackUint8(newPtr_);

        // Unpack address separately (20 bytes)
        (proposal_.proposer, newPtr_) = P.unpackAddress(newPtr_);

        // Unpack bytes32 fields
        (proposal_.originBlockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (proposal_.coreStateHash, newPtr_) = P.unpackBytes32(newPtr_);

        // Decode BlobSlice - unpack small fields together: arrayLength(3) + offset(3) +
        // timestamp(6) = 12 bytes
        uint24 blobHashesLength;
        (blobHashesLength, newPtr_) = P.unpackUint24(newPtr_);
        (proposal_.blobSlice.offset, newPtr_) = P.unpackUint24(newPtr_);
        (proposal_.blobSlice.timestamp, newPtr_) = P.unpackUint48(newPtr_);

        // Unpack blob hashes
        proposal_.blobSlice.blobHashes = new bytes32[](blobHashesLength);
        for (uint256 i; i < blobHashesLength; ++i) {
            (proposal_.blobSlice.blobHashes[i], newPtr_) = P.unpackBytes32(newPtr_);
        }
    }

    /// @notice Encode a single Claim
    function _encodeClaim(
        uint256 _ptr,
        IInbox.Claim memory _claim
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        // Pack endBlockNumber separately (6 bytes)
        newPtr_ = P.packUint48(_ptr, _claim.endBlockNumber);

        // Pack addresses together (20 + 20 = 40 bytes)
        newPtr_ = P.packAddress(newPtr_, _claim.designatedProver);
        newPtr_ = P.packAddress(newPtr_, _claim.actualProver);

        // Pack bytes32 fields
        newPtr_ = P.packBytes32(newPtr_, _claim.proposalHash);
        newPtr_ = P.packBytes32(newPtr_, _claim.parentClaimHash);
        newPtr_ = P.packBytes32(newPtr_, _claim.endBlockHash);
        newPtr_ = P.packBytes32(newPtr_, _claim.endStateRoot);
    }

    /// @notice Decode a single Claim
    function _decodeClaim(uint256 _ptr)
        private
        pure
        returns (IInbox.Claim memory claim_, uint256 newPtr_)
    {
        // Unpack endBlockNumber separately (6 bytes)
        (claim_.endBlockNumber, newPtr_) = P.unpackUint48(_ptr);

        // Unpack addresses together (20 + 20 = 40 bytes)
        (claim_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (claim_.actualProver, newPtr_) = P.unpackAddress(newPtr_);

        // Unpack bytes32 fields
        (claim_.proposalHash, newPtr_) = P.unpackBytes32(newPtr_);
        (claim_.parentClaimHash, newPtr_) = P.unpackBytes32(newPtr_);
        (claim_.endBlockHash, newPtr_) = P.unpackBytes32(newPtr_);
        (claim_.endStateRoot, newPtr_) = P.unpackBytes32(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProveDataSize(IInbox.Proposal[] memory _proposals)
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Array lengths: 3 + 3 = 6 bytes
            size_ = 6;

            // Proposals - each has fixed size + variable blob hashes
            // Fixed proposal fields: 6 + 20 + 6 + 6 + 32 + 1 + 1 + 32 = 104
            // BlobSlice fixed: 3 + 3 + 6 = 12
            for (uint256 i; i < _proposals.length; ++i) {
                size_ += 116 + (_proposals[i].blobSlice.blobHashes.length * 32);
            }

            // Claims - each has fixed size: endBlockNumber(6) + addresses(20+20) +
            // bytes32(32+32+32+32) = 174
            size_ += _proposals.length * 174;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ProposalClaimLengthMismatch();
}
