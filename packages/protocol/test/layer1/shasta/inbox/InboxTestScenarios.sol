// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "./InboxTestUtils.sol";
import "./InboxTestBuilder.sol";

/// @title InboxTestScenarios
/// @notice Common test scenarios and builders for Inbox tests
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTestScenarios is InboxTestBase {
    using InboxTestUtils for *;
    using InboxTestBuilder for *;

    // ---------------------------------------------------------------
    // Proposal creation scenarios
    // ---------------------------------------------------------------

    /// @dev Creates and submits a valid proposal (optimized)
    function submitProposal(
        uint48 _proposalId,
        address _proposer
    )
        internal
        returns (IInbox.Proposal memory proposal_)
    {
        return submitProposalWithState(_proposalId, _proposer, 0);
    }

    /// @dev Creates and submits a proposal with custom finalized state
    function submitProposalWithState(
        uint48 _proposalId,
        address _proposer,
        uint48 _lastFinalizedId
    )
        internal
        returns (IInbox.Proposal memory proposal_)
    {
        // Setup core state
        IInbox.CoreState memory coreState = InboxTestUtils.createCoreState(_proposalId, _lastFinalizedId);
        inbox.exposed_setCoreStateHash(InboxTestUtils.hashCoreState(coreState));

        // Setup standard mocks
        setupStandardProposalMocks(_proposer);

        // Create and submit proposal data
        bytes memory data = InboxTestUtils.encodeProposalData(
            coreState,
            InboxTestUtils.createBlobReference(uint8(_proposalId)),
            new IInbox.ClaimRecord[](0)
        );

        vm.prank(_proposer);
        inbox.propose(bytes(""), data);

        // Return expected proposal
        proposal_ = InboxTestUtils.createProposal(_proposalId, _proposer, DEFAULT_BASEFEE_SHARING_PCTG);
    }

    /// @dev Creates, submits, and proves a proposal
    function submitAndProveProposal(
        uint48 _proposalId,
        address _proposer,
        address _prover,
        bytes32 _parentClaimHash
    )
        internal
        returns (IInbox.Proposal memory proposal_, IInbox.Claim memory claim_)
    {
        // Submit proposal
        proposal_ = submitProposal(_proposalId, _proposer);

        // Prove proposal
        claim_ = proveProposal(proposal_, _prover, _parentClaimHash);
    }

    // ---------------------------------------------------------------
    // Proving scenarios
    // ---------------------------------------------------------------

    /// @dev Proves a previously submitted proposal
    function proveProposal(
        IInbox.Proposal memory _proposal,
        address _prover,
        bytes32 _parentClaimHash
    )
        internal
        returns (IInbox.Claim memory claim_)
    {
        // Create claim
        claim_ = InboxTestUtils.createClaim(_proposal, _parentClaimHash, _prover);

        // Setup proof verification
        mockProofVerification(true);

        // Prepare prove data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim_;

        bytes memory proveData = InboxTestUtils.encodeProveData(proposals, claims);

        // Submit proof
        vm.prank(_prover);
        inbox.prove(proveData, bytes("proof"));
    }

    /// @dev Proves multiple proposals in batch (optimized)
    function proveProposalsBatch(
        IInbox.Proposal[] memory _proposals,
        address _prover,
        bytes32 _initialParentHash
    )
        internal
        returns (IInbox.Claim[] memory claims_)
    {
        // Create claim chain efficiently
        claims_ = InboxTestBuilder.createClaimChain(_proposals, _initialParentHash, _prover);

        // Setup and submit proof
        setupStandardProofMocks(true);
        vm.prank(_prover);
        inbox.prove(InboxTestUtils.encodeProveData(_proposals, claims_), bytes("proof"));
    }

    // ---------------------------------------------------------------
    // Finalization scenarios
    // ---------------------------------------------------------------

    /// @dev Finalizes a single proposal
    function finalizeProposal(
        uint48 _proposalId,
        IInbox.Claim memory _claim,
        bytes32 _parentClaimHash
    )
        internal
    {
        // Store proposal and claim record
        IInbox.Proposal memory proposal = createValidProposal(_proposalId);
        bytes32 proposalHash = InboxTestUtils.hashProposal(proposal);
        inbox.exposed_setProposalHash(_proposalId, proposalHash);

        IInbox.ClaimRecord memory claimRecord = InboxTestUtils.createClaimRecord(_claim, 1);
        bytes32 claimRecordHash = InboxTestUtils.hashClaimRecord(claimRecord);
        inbox.exposed_setClaimRecordHash(_proposalId, _parentClaimHash, claimRecordHash);

        // Setup core state for finalization
        IInbox.CoreState memory coreState = InboxTestUtils.createCoreStateFull(
            _proposalId + 1, _proposalId - 1, _parentClaimHash, bytes32(0)
        );
        inbox.exposed_setCoreStateHash(InboxTestUtils.hashCoreState(coreState));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Expect synced block save
        expectSyncedBlockSave(_claim.endBlockNumber, _claim.endBlockHash, _claim.endStateRoot);

        // Create proposal data with claim records
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord;

        LibBlobs.BlobReference memory blobRef =
            InboxTestUtils.createBlobReference(uint8(_proposalId + 1));
        bytes memory data = InboxTestUtils.encodeProposalData(coreState, blobRef, claimRecords);

        // Submit proposal (triggers finalization)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @dev Finalizes multiple proposals in batch (optimized)
    function finalizeProposalsBatch(
        uint48 _startId,
        uint48 _count,
        bytes32 _initialParentHash
    )
        internal
        returns (bytes32 finalClaimHash_)
    {
        // Initialize claim records array
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](_count);
        bytes32 parentHash = _initialParentHash;
        
        // Store proposals and claims
        for (uint48 i = 0; i < _count; i++) {
            uint48 proposalId = _startId + i;
            
            // Store proposal
            IInbox.Proposal memory proposal = createValidProposal(proposalId);
            inbox.exposed_setProposalHash(proposalId, InboxTestUtils.hashProposal(proposal));
            
            // Create and store claim
            IInbox.Claim memory claim = InboxTestUtils.createClaim(proposal, parentHash, Alice);
            claimRecords[i] = InboxTestUtils.createClaimRecord(claim, 1);
            
            // Store claim record hash
            inbox.exposed_setClaimRecordHash(
                proposalId, parentHash, InboxTestUtils.hashClaimRecord(claimRecords[i])
            );
            
            parentHash = InboxTestUtils.hashClaim(claim);
        }
        
        finalClaimHash_ = parentHash;
        
        // Setup finalization
        IInbox.CoreState memory coreState = InboxTestUtils.createCoreStateFull(
            _startId + _count, _startId - 1, _initialParentHash, bytes32(0)
        );
        inbox.exposed_setCoreStateHash(InboxTestUtils.hashCoreState(coreState));
        
        // Setup mocks and expectations
        setupStandardProposalMocks(Alice);
        expectSyncedBlockSave(
            claimRecords[_count - 1].claim.endBlockNumber,
            claimRecords[_count - 1].claim.endBlockHash,
            claimRecords[_count - 1].claim.endStateRoot
        );
        
        // Submit finalization
        vm.prank(Alice);
        inbox.propose(
            bytes(""),
            InboxTestUtils.encodeProposalData(
                coreState,
                InboxTestUtils.createBlobReference(uint8(_startId + _count)),
                claimRecords
            )
        );
    }

    // ---------------------------------------------------------------
    // Chain advancement scenarios
    // ---------------------------------------------------------------

    /// @dev Creates a chain of proven proposals (optimized)
    function createProvenChain(
        uint48 _startId,
        uint48 _count,
        bytes32 _initialParentHash
    )
        internal
        returns (IInbox.Proposal[] memory proposals_, IInbox.Claim[] memory claims_)
    {
        // Create all proposals at once
        proposals_ = InboxTestBuilder.createSequentialProposals(_startId, _count, Alice);
        
        // Submit all proposals
        for (uint48 i = 0; i < _count; i++) {
            submitProposal(_startId + i, Alice);
        }
        
        // Create and prove all claims at once
        claims_ = InboxTestBuilder.createClaimChain(proposals_, _initialParentHash, Bob);
        setupStandardProofMocks(true);
        vm.prank(Bob);
        inbox.prove(InboxTestUtils.encodeProveData(proposals_, claims_), bytes("proof"));
    }

    // ---------------------------------------------------------------
    // Genesis setup scenarios
    // ---------------------------------------------------------------

    /// @dev Creates a genesis claim for testing
    function createGenesisClaim() internal pure returns (IInbox.Claim memory claim_) {
        claim_.endBlockHash = GENESIS_BLOCK_HASH;
    }

    /// @dev Gets the genesis claim hash
    function getGenesisClaimHash() internal pure returns (bytes32) {
        return InboxTestUtils.hashClaim(createGenesisClaim());
    }

    // ---------------------------------------------------------------
    // Assertion helpers
    // ---------------------------------------------------------------

    /// @dev Asserts that a proposal was stored correctly
    function assertProposalStored(uint48 _proposalId) internal view {
        bytes32 storedHash = inbox.getProposalHash(_proposalId);
        assertTrue(storedHash != bytes32(0), "Proposal not stored");
    }

    /// @dev Asserts that a claim record was stored correctly
    function assertClaimRecordStored(uint48 _proposalId, bytes32 _parentClaimHash) internal view {
        bytes32 storedHash = inbox.getClaimRecordHash(_proposalId, _parentClaimHash);
        assertTrue(storedHash != bytes32(0), "Claim record not stored");
    }

    /// @dev Asserts multiple proposals were stored
    function assertProposalsStored(uint48 _startId, uint48 _count) internal view {
        for (uint48 i = 0; i < _count; i++) {
            assertProposalStored(_startId + i);
        }
    }

    /// @dev Asserts core state matches expected values
    function assertCoreState(
        uint48 _expectedNextProposalId,
        uint48 _expectedLastFinalizedId
    )
        internal
        view
    {
        IInbox.CoreState memory expected =
            InboxTestUtils.createCoreState(_expectedNextProposalId, _expectedLastFinalizedId);
        bytes32 expectedHash = InboxTestUtils.hashCoreState(expected);
        bytes32 actualHash = inbox.getCoreStateHash();
        assertEq(actualHash, expectedHash, "Core state mismatch");
    }
}
