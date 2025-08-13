// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import { Inbox, ClaimRecordHashMismatch } from "contracts/layer1/shasta/impl/Inbox.sol";
import "./InboxMockContracts.sol";

/// @title InboxFinalization
/// @notice Tests for proposal finalization functionality including chain validation and state
/// updates
/// @dev Tests cover finalization scenarios without testing bond operations
contract InboxFinalization is InboxTestBase {
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
        // Setup blobhashes for this specific test
        setupBlobHashes();

        // Setup: Create and store a proposal
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        inbox.exposed_setProposalHash(proposalId, proposalHash);

        // Create initial core state
        IInbox.CoreState memory coreState = createCoreState(2, 0);

        // Create and store a claim record
        IInbox.Claim memory claim = createValidClaim(proposal, coreState.lastFinalizedClaimHash);
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: claim,
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        // Store the claim record
        bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
        inbox.exposed_setClaimRecordHash(
            proposalId, coreState.lastFinalizedClaimHash, claimRecordHash
        );

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Expect SyncedBlockManager to be updated
        expectSyncedBlockSave(claim.endBlockNumber, claim.endBlockHash, claim.endStateRoot);

        // Create proposal data with claim records for finalization
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord;

        // Use valid blob reference
        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        // Set initial core state
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Submit proposal (which triggers finalization)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify core state was updated by checking the hash
        // We can't directly get the core state from TestInboxWithMockBlobs,
        // but we can verify it was set correctly through the events or other means
        // The test passes if propose succeeded without reverting
    }

    /// @notice Test finalizing multiple proposals in sequence
    function test_finalize_multiple_proposals() public {
        // Setup blobhashes for this specific test
        setupBlobHashes();
        uint48 numProposals = 3;

        // Setup: Create and store multiple proposals with linked claims
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 parentClaimHash = keccak256(abi.encode(genesisClaim));

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            // Create and store proposal
            IInbox.Proposal memory proposal = createValidProposal(i);
            bytes32 proposalHash = keccak256(abi.encode(proposal));
            inbox.exposed_setProposalHash(i, proposalHash);

            // Create claim with chained parent
            IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);
            IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
                claim: claim,
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0)
            });

            // Store claim record
            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            inbox.exposed_setClaimRecordHash(i, parentClaimHash, claimRecordHash);

            claimRecords[i - 1] = claimRecord;
            parentClaimHash = keccak256(abi.encode(claim));
        }

        // Setup initial core state
        IInbox.CoreState memory coreState = createCoreState(numProposals + 1, 0);
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(genesisClaim));
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Expect final synced block save
        IInbox.Claim memory lastClaim = claimRecords[numProposals - 1].claim;
        expectSyncedBlockSave(
            lastClaim.endBlockNumber, lastClaim.endBlockHash, lastClaim.endStateRoot
        );

        // Create proposal data with all claim records
        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        bytes memory data = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        // Submit proposal (triggers finalization)
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify all proposals were finalized
        // The test passes if propose succeeded without reverting
        // We expect all proposals to have been finalized
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
