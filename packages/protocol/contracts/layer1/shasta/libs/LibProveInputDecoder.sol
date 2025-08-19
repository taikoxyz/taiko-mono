// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProveInputDecoder
/// @notice Library for encoding and decoding prove input data with gas optimization using LibPackUnpack
/// @custom:security-contact security@taiko.xyz
library LibProveInputDecoder {
    /// @notice Encodes prove input data using compact encoding
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encode(IInbox.ProveInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        // Calculate total size needed
        uint256 bufferSize = _calculateProveDataSize(_input.proposals, _input.claims);
        encoded_ = new bytes(bufferSize);

        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(encoded_);

        // 1. Encode Proposals array
        ptr = P.packUint24(ptr, uint24(_input.proposals.length));
        for (uint256 i; i < _input.proposals.length; ++i) {
            ptr = _encodeProposal(ptr, _input.proposals[i]);
        }

        // 2. Encode Claims array
        ptr = P.packUint24(ptr, uint24(_input.claims.length));
        for (uint256 i; i < _input.claims.length; ++i) {
            ptr = _encodeClaim(ptr, _input.claims[i]);
        }
    }

    /// @notice Decodes prove input data using optimized operations with LibPackUnpack
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    function decode(bytes memory _data) internal pure returns (IInbox.ProveInput memory input_) {
        // Get pointer to data section (skip length prefix)
        uint256 ptr = P.dataPtr(_data);

        // 1. Decode Proposals array
        uint24 proposalsLength;
        (proposalsLength, ptr) = P.unpackUint24(ptr);
        input_.proposals = new IInbox.Proposal[](proposalsLength);
        for (uint256 i; i < proposalsLength; ++i) {
            (input_.proposals[i], ptr) = _decodeProposal(ptr);
        }

        // 2. Decode Claims array
        uint24 claimsLength;
        (claimsLength, ptr) = P.unpackUint24(ptr);
        if (claimsLength != proposalsLength) revert ProposalClaimLengthMismatch();
        input_.claims = new IInbox.Claim[](claimsLength);
        for (uint256 i; i < claimsLength; ++i) {
            (input_.claims[i], ptr) = _decodeClaim(ptr);
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

    /// @notice Encode a single Claim
    function _encodeClaim(
        uint256 _ptr,
        IInbox.Claim memory _claim
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packBytes32(_ptr, _claim.proposalHash);
        newPtr_ = P.packBytes32(newPtr_, _claim.parentClaimHash);
        // Encode BlockMiniHeader
        newPtr_ = P.packUint48(newPtr_, _claim.endBlockMiniHeader.number);
        newPtr_ = P.packBytes32(newPtr_, _claim.endBlockMiniHeader.hash);
        newPtr_ = P.packBytes32(newPtr_, _claim.endBlockMiniHeader.stateRoot);
        newPtr_ = P.packAddress(newPtr_, _claim.designatedProver);
        newPtr_ = P.packAddress(newPtr_, _claim.actualProver);
    }

    /// @notice Decode a single Claim
    function _decodeClaim(uint256 _ptr)
        private
        pure
        returns (IInbox.Claim memory claim_, uint256 newPtr_)
    {
        (claim_.proposalHash, newPtr_) = P.unpackBytes32(_ptr);
        (claim_.parentClaimHash, newPtr_) = P.unpackBytes32(newPtr_);
        // Decode BlockMiniHeader
        (claim_.endBlockMiniHeader.number, newPtr_) = P.unpackUint48(newPtr_);
        (claim_.endBlockMiniHeader.hash, newPtr_) = P.unpackBytes32(newPtr_);
        (claim_.endBlockMiniHeader.stateRoot, newPtr_) = P.unpackBytes32(newPtr_);
        (claim_.designatedProver, newPtr_) = P.unpackAddress(newPtr_);
        (claim_.actualProver, newPtr_) = P.unpackAddress(newPtr_);
    }

    /// @notice Calculate the size needed for encoding
    function _calculateProveDataSize(
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        private
        pure
        returns (uint256 size_)
    {
        if (_proposals.length != _claims.length) revert ProposalClaimLengthMismatch();
        
        unchecked {
            // Array lengths: 3 + 3 = 6 bytes
            size_ = 6;

            // Proposals - each has fixed size
            // Fixed proposal fields: id(6) + proposer(20) + timestamp(6) + coreStateHash(32) +
            // derivationHash(32) = 96
            for (uint256 i; i < _proposals.length; ++i) {
                size_ += 96;
            }

            // Claims - each has fixed size: proposalHash(32) + parentClaimHash(32) + 
            // BlockMiniHeader(6 + 32 + 32) + designatedProver(20) + actualProver(20) = 174
            size_ += _proposals.length * 174;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ProposalClaimLengthMismatch();
}