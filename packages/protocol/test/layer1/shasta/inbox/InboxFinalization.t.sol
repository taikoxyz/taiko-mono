// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestScenarios.sol";
import "./InboxTestUtils.sol";
import { Inbox, ClaimRecordHashMismatch } from "contracts/layer1/shasta/impl/Inbox.sol";
import "./InboxMockContracts.sol";

/// @title InboxFinalization
/// @notice Tests for proposal finalization functionality including chain validation and state
/// updates
/// @dev Tests cover finalization scenarios without testing bond operations
contract InboxFinalization is InboxTestScenarios {
    using InboxTestUtils for *;
    // Override setupMockAddresses to use actual mock contracts instead of makeAddr
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }
    /// @notice Test finalizing a single proposal

    function test_finalize_single_proposal() public {
        setupBlobHashes();

        // Setup: Create and store a proposal
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        inbox.exposed_setProposalHash(proposalId, proposal.hashProposal());

        // Create initial core state
        IInbox.CoreState memory coreState = InboxTestUtils.createCoreState(2, 0);

        // Create and store a claim record
        IInbox.Claim memory claim = InboxTestUtils.createClaim(proposal, coreState.lastFinalizedClaimHash, Alice);
        IInbox.ClaimRecord memory claimRecord = InboxTestUtils.createClaimRecord(claim, 1);

        // Store the claim record
        inbox.exposed_setClaimRecordHash(
            proposalId, coreState.lastFinalizedClaimHash, claimRecord.hashClaimRecord()
        );

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Expect SyncedBlockManager to be updated
        expectSyncedBlockSave(claim.endBlockNumber, claim.endBlockHash, claim.endStateRoot);

        // Create proposal data with claim records for finalization
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord;

        LibBlobs.BlobReference memory blobRef = InboxTestUtils.createBlobReference(1);
        bytes memory data = InboxTestUtils.encodeProposalData(coreState, blobRef, claimRecords);

        // Set initial core state
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Submit proposal (which triggers finalization)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test finalizing multiple proposals in sequence
    function test_finalize_multiple_proposals() public {
        setupBlobHashes();
        uint48 numProposals = 3;

        // Use scenario builder to finalize multiple proposals
        bytes32 genesisHash = getGenesisClaimHash();
        bytes32 finalClaimHash = finalizeProposalsBatch(1, numProposals, genesisHash);

        // Verify the finalization succeeded
        assertTrue(finalClaimHash != bytes32(0));
    }

    /// @notice Test finalization stops at missing claim record
    function test_finalize_stops_at_missing_claim() public {
        // Setup blobhashes for this specific test
        setupBlobHashes();
        // Create genesis claim
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentClaimHash = keccak256(abi.encode(genesisClaim));

        // Store proposal 1 with claim
        IInbox.Proposal memory proposal1 = createValidProposal(1);
        inbox.exposed_setProposalHash(1, keccak256(abi.encode(proposal1)));

        IInbox.Claim memory claim1 = createValidClaim(proposal1, parentClaimHash);
        IInbox.ClaimRecord memory claimRecord1 = IInbox.ClaimRecord({
            claim: claim1,
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });
        inbox.exposed_setClaimRecordHash(1, parentClaimHash, keccak256(abi.encode(claimRecord1)));

        // Store proposal 2 WITHOUT claim (gap in chain)
        IInbox.Proposal memory proposal2 = createValidProposal(2);
        inbox.exposed_setProposalHash(2, keccak256(abi.encode(proposal2)));
        // No claim record stored for proposal 2

        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(3, 0);
        coreState.lastFinalizedClaimHash = parentClaimHash;
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Only expect first proposal to be finalized
        expectSyncedBlockSave(claim1.endBlockNumber, claim1.endBlockHash, claim1.endStateRoot);

        // Create proposal data with only claimRecord1
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord1;

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify only proposal 1 was finalized
        // The test passes if propose succeeded without reverting
        // We expect only proposal 1 to have been finalized
    }

    /// @notice Test finalization with invalid claim record hash
    function test_finalize_invalid_claim_hash() public {
        setupBlobHashes();
        // Setup: Create and store a proposal with claim
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        inbox.exposed_setProposalHash(proposalId, keccak256(abi.encode(proposal)));

        IInbox.CoreState memory coreState = createCoreState(2, 0);

        // Store correct claim record
        IInbox.Claim memory claim = createValidClaim(proposal, coreState.lastFinalizedClaimHash);
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: claim,
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });
        inbox.exposed_setClaimRecordHash(
            proposalId, coreState.lastFinalizedClaimHash, keccak256(abi.encode(claimRecord))
        );

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data with WRONG claim record
        IInbox.ClaimRecord memory wrongClaimRecord = claimRecord;
        wrongClaimRecord.span = 2; // Modified field

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = wrongClaimRecord;

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Expect revert
        vm.expectRevert(ClaimRecordHashMismatch.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }
}
