// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibTransitionCodec } from "./LibTransitionCodec.sol";

/// @title LibCodec
/// @notice Compact encoder/decoder for Inbox inputs using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibCodec {
    // ---------------------------------------------------------------
    // ProposeInputCodec Functions
    // ---------------------------------------------------------------

    /// @dev Encodes propose input data using compact packing.
    /// Layout: deadline(6) + maxProvingFeeGwei(4) + numForcedInclusions(1) + blobStartIndex(2) +
    /// numBlobs(2) + offset(3) = 18 bytes
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(18);
        uint256 ptr = P.dataPtr(encoded_);
        ptr = P.packUint48(ptr, _input.deadline);
        ptr = P.packUint32(ptr, _input.maxProvingFeeGwei);
        ptr = P.packUint8(ptr, _input.numForcedInclusions);
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);
    }

    /// @dev Decodes propose input data using compact packing.
    function decodeProposeInput(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        uint256 ptr = P.dataPtr(_data);
        (input_.deadline, ptr) = P.unpackUint48(ptr);
        (input_.maxProvingFeeGwei, ptr) = P.unpackUint32(ptr);
        (input_.numForcedInclusions, ptr) = P.unpackUint8(ptr);
        (input_.blobReference.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.numBlobs, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.offset,) = P.unpackUint24(ptr);
    }

    // ---------------------------------------------------------------
    // ProposalCodec Functions
    // ---------------------------------------------------------------

    /// @dev Encodes a proposal (without the id field) for event emission.
    /// @param _proposal The Proposal to encode.
    /// @return encoded_ The encoded data (excludes proposal id).
    function encodeProposal(IInbox.Proposal memory _proposal)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 bufferSize = _calculateProposalSize(_proposal.sources);
        encoded_ = new bytes(bufferSize);
        uint256 ptr = P.dataPtr(encoded_);

        // Fixed fields (excluding id): 125 bytes total
        ptr = P.packUint48(ptr, _proposal.timestamp);
        ptr = P.packUint48(ptr, _proposal.endOfSubmissionWindowTimestamp);
        ptr = P.packAddress(ptr, _proposal.proposer);
        ptr = P.packAddress(ptr, _proposal.designatedProver);
        ptr = P.packBytes32(ptr, _proposal.parentProposalHash);
        ptr = P.packUint48(ptr, _proposal.originBlockNumber);
        ptr = P.packBytes32(ptr, _proposal.originBlockHash);
        ptr = P.packUint8(ptr, _proposal.basefeeSharingPctg);

        // Sources array
        P.checkArrayLength(_proposal.sources.length);
        ptr = P.packUint16(ptr, uint16(_proposal.sources.length));
        for (uint256 i; i < _proposal.sources.length; ++i) {
            ptr = _encodeDerivationSource(ptr, _proposal.sources[i]);
        }
    }

    /// @dev Decodes proposal data (without the id field).
    /// @param _data The encoded data.
    /// @return proposal_ The decoded Proposal (id will be 0, should be set separately).
    function decodeProposal(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_)
    {
        uint256 ptr = P.dataPtr(_data);

        // Fixed fields (id is not encoded, will be 0)
        (proposal_.timestamp, ptr) = P.unpackUint48(ptr);
        (proposal_.endOfSubmissionWindowTimestamp, ptr) = P.unpackUint48(ptr);
        (proposal_.proposer, ptr) = P.unpackAddress(ptr);
        (proposal_.designatedProver, ptr) = P.unpackAddress(ptr);
        (proposal_.parentProposalHash, ptr) = P.unpackBytes32(ptr);
        (proposal_.originBlockNumber, ptr) = P.unpackUint48(ptr);
        (proposal_.originBlockHash, ptr) = P.unpackBytes32(ptr);
        (proposal_.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);

        // Sources array
        uint16 sourcesLength;
        (sourcesLength, ptr) = P.unpackUint16(ptr);
        proposal_.sources = new IInbox.DerivationSource[](sourcesLength);
        for (uint256 i; i < sourcesLength; ++i) {
            (proposal_.sources[i], ptr) = _decodeDerivationSource(ptr);
        }
    }

    // ---------------------------------------------------------------
    // ProveInputCodec Functions
    // ---------------------------------------------------------------

    /// @dev Encodes prove input data using compact packing.
    function encodeProveInput(IInbox.ProveInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        IInbox.Commitment memory c = _input.commitment;
        uint256 bufferSize = _calculateProveInputSize(c.transitions.length);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, c.firstProposalId);
        ptr = P.packBytes32(ptr, c.firstProposalParentBlockHash);
        ptr = P.packBytes32(ptr, c.lastProposalHash);
        ptr = P.packAddress(ptr, c.actualProver);
        ptr = P.packUint48(ptr, c.endBlockNumber);
        ptr = P.packBytes32(ptr, c.endStateRoot);

        P.checkArrayLength(c.transitions.length);
        ptr = P.packUint16(ptr, uint16(c.transitions.length));
        for (uint256 i; i < c.transitions.length; ++i) {
            ptr = LibTransitionCodec.encodeTransition(ptr, c.transitions[i]);
        }

        // Encode forceCheckpointSync
        P.packUint8(ptr, _input.forceCheckpointSync ? 1 : 0);
    }

    /// @dev Decodes prove input data using compact packing.
    function decodeProveInput(bytes memory _data)
        internal
        pure
        returns (IInbox.ProveInput memory input_)
    {
        uint256 ptr = P.dataPtr(_data);

        (input_.commitment.firstProposalId, ptr) = P.unpackUint48(ptr);
        (input_.commitment.firstProposalParentBlockHash, ptr) = P.unpackBytes32(ptr);
        (input_.commitment.lastProposalHash, ptr) = P.unpackBytes32(ptr);
        (input_.commitment.actualProver, ptr) = P.unpackAddress(ptr);
        (input_.commitment.endBlockNumber, ptr) = P.unpackUint48(ptr);
        (input_.commitment.endStateRoot, ptr) = P.unpackBytes32(ptr);

        uint16 transitionsLength;
        (transitionsLength, ptr) = P.unpackUint16(ptr);
        input_.commitment.transitions = new IInbox.Transition[](transitionsLength);
        for (uint256 i; i < transitionsLength; ++i) {
            (input_.commitment.transitions[i], ptr) = LibTransitionCodec.decodeTransition(ptr);
        }

        // Decode forceCheckpointSync
        uint8 forceCheckpointSyncByte;
        (forceCheckpointSyncByte,) = P.unpackUint8(ptr);
        input_.forceCheckpointSync = forceCheckpointSyncByte != 0;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Calculates the size needed for Proposal encoding (without id).
    /// @param _sources The DerivationSource array.
    /// @return size_ Total byte size needed.
    function _calculateProposalSize(IInbox.DerivationSource[] memory _sources)
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed fields (excluding id):
            //   timestamp: 6 bytes
            //   endOfSubmissionWindowTimestamp: 6 bytes
            //   proposer: 20 bytes
            //   designatedProver: 20 bytes
            //   parentProposalHash: 32 bytes
            //   originBlockNumber: 6 bytes
            //   originBlockHash: 32 bytes
            //   basefeeSharingPctg: 1 byte
            //   sources array length: 2 bytes
            // Total fixed: 125 bytes
            size_ = 125;

            for (uint256 i; i < _sources.length; ++i) {
                // Each DerivationSource:
                //   isForcedInclusion: 1 byte
                //   blobHashes array length: 2 bytes
                //   blobHashes: 32 bytes each
                //   offset: 3 bytes
                //   timestamp: 6 bytes
                // Total per source: 12 + (blobHashes.length * 32)
                size_ += 12 + (_sources[i].blobSlice.blobHashes.length * 32);
            }
        }
    }

    /// @dev Encodes a DerivationSource at the given pointer.
    /// @param _ptr The current memory pointer.
    /// @param _source The DerivationSource to encode.
    /// @return newPtr_ The updated memory pointer.
    function _encodeDerivationSource(
        uint256 _ptr,
        IInbox.DerivationSource memory _source
    )
        private
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packUint8(_ptr, _source.isForcedInclusion ? 1 : 0);

        // Encode blobSlice
        P.checkArrayLength(_source.blobSlice.blobHashes.length);
        newPtr_ = P.packUint16(newPtr_, uint16(_source.blobSlice.blobHashes.length));
        for (uint256 i; i < _source.blobSlice.blobHashes.length; ++i) {
            newPtr_ = P.packBytes32(newPtr_, _source.blobSlice.blobHashes[i]);
        }
        newPtr_ = P.packUint24(newPtr_, _source.blobSlice.offset);
        newPtr_ = P.packUint48(newPtr_, _source.blobSlice.timestamp);
    }

    /// @dev Decodes a DerivationSource from the given pointer.
    /// @param _ptr The current memory pointer.
    /// @return source_ The decoded DerivationSource.
    /// @return newPtr_ The updated memory pointer.
    function _decodeDerivationSource(uint256 _ptr)
        private
        pure
        returns (IInbox.DerivationSource memory source_, uint256 newPtr_)
    {
        uint8 isForcedInclusionByte;
        (isForcedInclusionByte, newPtr_) = P.unpackUint8(_ptr);
        source_.isForcedInclusion = isForcedInclusionByte != 0;

        // Decode blobSlice
        uint16 blobHashesLength;
        (blobHashesLength, newPtr_) = P.unpackUint16(newPtr_);
        source_.blobSlice.blobHashes = new bytes32[](blobHashesLength);
        for (uint256 i; i < blobHashesLength; ++i) {
            (source_.blobSlice.blobHashes[i], newPtr_) = P.unpackBytes32(newPtr_);
        }
        (source_.blobSlice.offset, newPtr_) = P.unpackUint24(newPtr_);
        (source_.blobSlice.timestamp, newPtr_) = P.unpackUint48(newPtr_);
    }

    /// @dev Calculates the size needed for ProveInput encoding.
    /// @param _numTransitions Number of transitions in the array.
    /// @return size_ Total byte size needed.
    function _calculateProveInputSize(uint256 _numTransitions)
        private
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed fields:
            //   firstProposalId: 6 bytes
            //   firstProposalParentBlockHash: 32 bytes
            //   lastProposalHash: 32 bytes
            //   actualProver: 20 bytes
            //   endBlockNumber: 6 bytes
            //   endStateRoot: 32 bytes
            //   transitions array length: 2 bytes
            //   forceCheckpointSync: 1 byte
            // Total fixed: 131 bytes
            size_ = 131 + (_numTransitions * LibTransitionCodec.TRANSITION_SIZE);
        }
    }
}
