// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";

/// @title InboxTestUtils
/// @notice Utility library for Inbox test helpers
/// @custom:security-contact security@taiko.xyz
library InboxTestUtils {
    // ---------------------------------------------------------------
    // Proposal builders
    // ---------------------------------------------------------------

    /// @dev Creates a standard proposal with default values
    function createProposal(
        uint48 _id,
        address _proposer,
        uint8 _basefeeSharingPctg
    )
        internal
        view
        returns (IInbox.Proposal memory proposal_)
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", uint256(_id)));

        proposal_ = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
    }

    /// @dev Creates a proposal with custom blob configuration
    function createProposalWithBlobs(
        uint48 _id,
        address _proposer,
        uint8 _basefeeSharingPctg,
        bytes32[] memory _blobHashes,
        uint48 _offset
    )
        internal
        view
        returns (IInbox.Proposal memory proposal_)
    {
        proposal_ = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _blobHashes,
                offset: uint24(_offset),
                timestamp: uint48(block.timestamp)
            })
        });
    }

    // ---------------------------------------------------------------
    // Claim builders
    // ---------------------------------------------------------------

    /// @dev Creates a standard claim for a proposal
    function createClaim(
        IInbox.Proposal memory _proposal,
        bytes32 _parentClaimHash,
        address _actualProver
    )
        internal
        pure
        returns (IInbox.Claim memory claim_)
    {
        claim_ = IInbox.Claim({
            proposalHash: keccak256(abi.encode(_proposal)),
            parentClaimHash: _parentClaimHash,
            endBlockNumber: _proposal.id * 100,
            endBlockHash: keccak256(abi.encode(_proposal.id, "endBlockHash")),
            endStateRoot: keccak256(abi.encode(_proposal.id, "stateRoot")),
            designatedProver: _proposal.proposer,
            actualProver: _actualProver
        });
    }

    /// @dev Creates a claim with custom block data
    function createClaimWithBlock(
        bytes32 _proposalHash,
        bytes32 _parentClaimHash,
        uint48 _endBlockNumber,
        bytes32 _endBlockHash,
        bytes32 _endStateRoot,
        address _designatedProver,
        address _actualProver
    )
        internal
        pure
        returns (IInbox.Claim memory claim_)
    {
        claim_ = IInbox.Claim({
            proposalHash: _proposalHash,
            parentClaimHash: _parentClaimHash,
            endBlockNumber: _endBlockNumber,
            endBlockHash: _endBlockHash,
            endStateRoot: _endStateRoot,
            designatedProver: _designatedProver,
            actualProver: _actualProver
        });
    }

    // ---------------------------------------------------------------
    // ClaimRecord builders
    // ---------------------------------------------------------------

    /// @dev Creates a claim record without bond instructions
    function createClaimRecord(
        IInbox.Claim memory _claim,
        uint48 _span
    )
        internal
        pure
        returns (IInbox.ClaimRecord memory record_)
    {
        record_ = IInbox.ClaimRecord({
            claim: _claim,
            span: uint8(_span),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });
    }

    /// @dev Creates a claim record with bond instructions
    function createClaimRecordWithBonds(
        IInbox.Claim memory _claim,
        uint48 _span,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        internal
        pure
        returns (IInbox.ClaimRecord memory record_)
    {
        record_ = IInbox.ClaimRecord({
            claim: _claim,
            span: uint8(_span),
            bondInstructions: _bondInstructions
        });
    }

    // ---------------------------------------------------------------
    // CoreState builders
    // ---------------------------------------------------------------

    /// @dev Creates a core state with minimal fields
    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    )
        internal
        pure
        returns (IInbox.CoreState memory state_)
    {
        state_ = IInbox.CoreState({
            nextProposalId: _nextProposalId,
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
    }

    /// @dev Creates a core state with all fields
    function createCoreStateFull(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedClaimHash,
        bytes32 _bondInstructionsHash
    )
        internal
        pure
        returns (IInbox.CoreState memory state_)
    {
        state_ = IInbox.CoreState({
            nextProposalId: _nextProposalId,
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedClaimHash: _lastFinalizedClaimHash,
            bondInstructionsHash: _bondInstructionsHash
        });
    }

    // ---------------------------------------------------------------
    // BlobReference builders
    // ---------------------------------------------------------------

    /// @dev Creates a blob reference with single blob
    function createBlobReference(uint8 _blobIndex)
        internal
        pure
        returns (LibBlobs.BlobReference memory ref_)
    {
        ref_ = LibBlobs.BlobReference({ blobStartIndex: _blobIndex, numBlobs: 1, offset: 0 });
    }

    /// @dev Creates a blob reference with multiple blobs
    function createBlobReferenceMulti(
        uint8 _blobStartIndex,
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        pure
        returns (LibBlobs.BlobReference memory ref_)
    {
        ref_ = LibBlobs.BlobReference({
            blobStartIndex: _blobStartIndex,
            numBlobs: _numBlobs,
            offset: _offset
        });
    }

    // ---------------------------------------------------------------
    // Encoding helpers
    // ---------------------------------------------------------------

    /// @dev Encodes proposal data with default deadline
    function encodeProposalData(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory data_)
    {
        data_ = abi.encode(uint64(0), _coreState, _blobRef, _claimRecords);
    }

    /// @dev Encodes proposal data with custom deadline
    function encodeProposalDataWithDeadline(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory data_)
    {
        data_ = abi.encode(_deadline, _coreState, _blobRef, _claimRecords);
    }

    /// @dev Encodes prove data
    function encodeProveData(
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        internal
        pure
        returns (bytes memory data_)
    {
        data_ = abi.encode(_proposals, _claims);
    }

    // ---------------------------------------------------------------
    // Hash helpers
    // ---------------------------------------------------------------

    /// @dev Computes proposal hash
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(_proposal));
    }

    /// @dev Computes claim hash
    function hashClaim(IInbox.Claim memory _claim) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(_claim));
    }

    /// @dev Computes claim record hash
    function hashClaimRecord(IInbox.ClaimRecord memory _record)
        internal
        pure
        returns (bytes32 hash_)
    {
        hash_ = keccak256(abi.encode(_record));
    }

    /// @dev Computes core state hash
    function hashCoreState(IInbox.CoreState memory _state) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(_state));
    }

    // ---------------------------------------------------------------
    // Blob hash generators
    // ---------------------------------------------------------------

    /// @dev Generates standard blob hashes for testing
    function generateBlobHashes(uint256 _count) internal pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            hashes_[i] = keccak256(abi.encode("blob", i));
        }
    }

    /// @dev Generates blob hashes with custom seed
    function generateBlobHashesWithSeed(
        uint256 _count,
        string memory _seed
    )
        internal
        pure
        returns (bytes32[] memory hashes_)
    {
        hashes_ = new bytes32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            hashes_[i] = keccak256(abi.encode(_seed, i));
        }
    }
}
