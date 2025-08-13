// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "./InboxTestUtils.sol";

/// @title InboxTestBuilder
/// @notice Fluent builder pattern for constructing test data
/// @custom:security-contact security@taiko.xyz
library InboxTestBuilder {
    using InboxTestUtils for *;

    // ---------------------------------------------------------------
    // Test Context for Chain Operations
    // ---------------------------------------------------------------

    struct TestChain {
        IInbox.CoreState coreState;
        IInbox.Proposal[] proposals;
        IInbox.Claim[] claims;
        IInbox.ClaimRecord[] claimRecords;
        bytes32 currentParentHash;
        uint48 nextProposalId;
        uint48 lastFinalizedId;
    }

    /// @dev Creates a new test chain
    function newChain(bytes32 _genesisHash) internal pure returns (TestChain memory chain_) {
        chain_.currentParentHash = _genesisHash;
        chain_.nextProposalId = 1;
        chain_.lastFinalizedId = 0;
        chain_.coreState = InboxTestUtils.createCoreState(1, 0);
    }

    /// @dev Adds a proposal to the chain
    function addProposal(
        TestChain memory _chain,
        address _proposer
    )
        internal
        view
        returns (TestChain memory)
    {
        uint256 newLength = _chain.proposals.length + 1;
        IInbox.Proposal[] memory newProposals = new IInbox.Proposal[](newLength);
        
        for (uint256 i = 0; i < _chain.proposals.length; i++) {
            newProposals[i] = _chain.proposals[i];
        }
        
        newProposals[newLength - 1] = InboxTestUtils.createProposal(_chain.nextProposalId, _proposer, 10);
        _chain.proposals = newProposals;
        _chain.nextProposalId++;
        
        return _chain;
    }

    /// @dev Adds a claim to the chain
    function addClaim(
        TestChain memory _chain,
        address _prover
    )
        internal
        pure
        returns (TestChain memory)
    {
        require(_chain.proposals.length > _chain.claims.length, "No proposal to prove");
        
        uint256 newLength = _chain.claims.length + 1;
        IInbox.Claim[] memory newClaims = new IInbox.Claim[](newLength);
        
        for (uint256 i = 0; i < _chain.claims.length; i++) {
            newClaims[i] = _chain.claims[i];
        }
        
        IInbox.Proposal memory proposal = _chain.proposals[_chain.claims.length];
        newClaims[newLength - 1] = InboxTestUtils.createClaim(proposal, _chain.currentParentHash, _prover);
        
        _chain.claims = newClaims;
        _chain.currentParentHash = InboxTestUtils.hashClaim(newClaims[newLength - 1]);
        
        return _chain;
    }

    /// @dev Marks proposals as finalized
    function finalizeUpTo(
        TestChain memory _chain,
        uint48 _proposalId
    )
        internal
        pure
        returns (TestChain memory)
    {
        require(_proposalId <= _chain.proposals.length, "Invalid proposal ID");
        require(_proposalId <= _chain.claims.length, "Proposal not proven");
        
        _chain.lastFinalizedId = _proposalId;
        _chain.coreState.lastFinalizedProposalId = _proposalId;
        _chain.coreState.lastFinalizedClaimHash = InboxTestUtils.hashClaim(_chain.claims[_proposalId - 1]);
        
        return _chain;
    }

    /// @dev Builds claim records from the chain
    function buildClaimRecords(TestChain memory _chain)
        internal
        pure
        returns (IInbox.ClaimRecord[] memory records_)
    {
        uint256 unfinalized = _chain.claims.length - _chain.lastFinalizedId;
        if (unfinalized == 0) return new IInbox.ClaimRecord[](0);
        
        records_ = new IInbox.ClaimRecord[](unfinalized);
        for (uint256 i = 0; i < unfinalized; i++) {
            uint256 claimIndex = _chain.lastFinalizedId + i;
            records_[i] = InboxTestUtils.createClaimRecord(_chain.claims[claimIndex], 1);
        }
    }

    // ---------------------------------------------------------------
    // Batch Data Generators
    // ---------------------------------------------------------------

    /// @dev Creates a batch of sequential proposals
    function createSequentialProposals(
        uint48 _startId,
        uint48 _count,
        address _proposer
    )
        internal
        view
        returns (IInbox.Proposal[] memory proposals_)
    {
        proposals_ = new IInbox.Proposal[](_count);
        for (uint48 i = 0; i < _count; i++) {
            proposals_[i] = InboxTestUtils.createProposal(_startId + i, _proposer, 10);
        }
    }

    /// @dev Creates a chain of claims with proper parent hashing
    function createClaimChain(
        IInbox.Proposal[] memory _proposals,
        bytes32 _initialParentHash,
        address _prover
    )
        internal
        pure
        returns (IInbox.Claim[] memory claims_)
    {
        claims_ = new IInbox.Claim[](_proposals.length);
        bytes32 parentHash = _initialParentHash;
        
        for (uint256 i = 0; i < _proposals.length; i++) {
            claims_[i] = InboxTestUtils.createClaim(_proposals[i], parentHash, _prover);
            parentHash = InboxTestUtils.hashClaim(claims_[i]);
        }
    }

    /// @dev Creates claim records for batch finalization
    function createFinalizationBatch(
        IInbox.Claim[] memory _claims,
        uint48 _startIndex,
        uint48 _count
    )
        internal
        pure
        returns (IInbox.ClaimRecord[] memory records_)
    {
        require(_startIndex + _count <= _claims.length, "Invalid range");
        
        records_ = new IInbox.ClaimRecord[](_count);
        for (uint48 i = 0; i < _count; i++) {
            records_[i] = InboxTestUtils.createClaimRecord(_claims[_startIndex + i], 1);
        }
    }

    // ---------------------------------------------------------------
    // Data Encoders with Context
    // ---------------------------------------------------------------

    /// @dev Encodes proposal data from test chain
    function encodeChainProposal(
        TestChain memory _chain,
        LibBlobs.BlobReference memory _blobRef
    )
        internal
        pure
        returns (bytes memory)
    {
        IInbox.ClaimRecord[] memory records = buildClaimRecords(_chain);
        return InboxTestUtils.encodeProposalData(_chain.coreState, _blobRef, records);
    }

    /// @dev Encodes prove data from test chain
    function encodeChainProve(
        TestChain memory _chain,
        uint48 _startIndex,
        uint48 _count
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_startIndex + _count <= _chain.proposals.length, "Invalid proposal range");
        require(_startIndex + _count <= _chain.claims.length, "Invalid claim range");
        
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](_count);
        IInbox.Claim[] memory claims = new IInbox.Claim[](_count);
        
        for (uint48 i = 0; i < _count; i++) {
            proposals[i] = _chain.proposals[_startIndex + i];
            claims[i] = _chain.claims[_startIndex + i];
        }
        
        return InboxTestUtils.encodeProveData(proposals, claims);
    }

    // ---------------------------------------------------------------
    // Mock Data Patterns
    // ---------------------------------------------------------------

    /// @dev Creates a standard genesis claim
    function genesisChain() internal pure returns (TestChain memory chain_) {
        chain_ = newChain(keccak256(abi.encode("genesis")));
        chain_.coreState.lastFinalizedClaimHash = chain_.currentParentHash;
    }

    /// @dev Creates a pre-populated chain with proposals and claims
    function populatedChain(
        uint48 _proposalCount,
        uint48 _claimCount,
        address _proposer,
        address _prover
    )
        internal
        view
        returns (TestChain memory chain_)
    {
        chain_ = genesisChain();
        
        for (uint48 i = 0; i < _proposalCount; i++) {
            chain_ = addProposal(chain_, _proposer);
        }
        
        for (uint48 i = 0; i < _claimCount && i < _proposalCount; i++) {
            chain_ = addClaim(chain_, _prover);
        }
    }

    /// @dev Creates a chain ready for finalization
    function finalizableChain(
        uint48 _totalProposals,
        uint48 _toFinalize,
        address _proposer,
        address _prover
    )
        internal
        view
        returns (TestChain memory chain_)
    {
        require(_toFinalize <= _totalProposals, "Cannot finalize more than total");
        
        chain_ = populatedChain(_totalProposals, _totalProposals, _proposer, _prover);
        
        if (_toFinalize > 0) {
            chain_ = finalizeUpTo(chain_, _toFinalize);
        }
    }
}