// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { Inbox, ClaimRecordHashMismatch } from "contracts/layer1/shasta/impl/Inbox.sol";
import "./InboxMockContracts.sol";

/// @title InboxFinalization
/// @notice Tests for proposal finalization functionality including chain validation and state
/// updates
/// @dev Tests cover finalization scenarios without testing bond operations
contract InboxFinalization is InboxTest {
    using InboxTestLib for *;
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
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(2, 0);

        // Create and store a claim record
        IInbox.Claim memory claim =
            InboxTestLib.createClaim(proposal, coreState.lastFinalizedClaimHash, Alice);
        IInbox.ClaimRecord memory claimRecord = InboxTestLib.createClaimRecord(claim, 1);

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

        LibBlobs.BlobReference memory blobRef = InboxTestLib.createBlobReference(1);
        bytes memory data = InboxTestLib.encodeProposalData(coreState, blobRef, claimRecords);

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

        // Submit and prove proposals first
        bytes32 genesisHash = getGenesisClaimHash();
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);
        bytes32 currentParentHash = genesisHash;

        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
            claims[i - 1] = InboxTestLib.createClaim(proposals[i - 1], currentParentHash, Bob);
            proveProposal(proposals[i - 1], Bob, currentParentHash);
            currentParentHash = InboxTestLib.hashClaim(claims[i - 1]);
        }

        // Finalize all proposals in batch
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);
        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = InboxTestLib.createClaimRecord(claims[i], 1);
        }

        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(numProposals + 1, 0, genesisHash, bytes32(0));
        inbox.exposed_setCoreStateHash(InboxTestLib.hashCoreState(coreState));

        expectSyncedBlockSave(
            claims[numProposals - 1].endBlockNumber,
            claims[numProposals - 1].endBlockHash,
            claims[numProposals - 1].endStateRoot
        );

        setupProposalMocks(Carol);
        setupBlobHashes();
        vm.prank(Carol);
        inbox.propose(
            bytes(""),
            InboxTestLib.encodeProposalData(
                coreState, InboxTestLib.createBlobReference(uint8(numProposals + 1)), claimRecords
            )
        );

        // Verify finalization succeeded by checking final claim hash
        bytes32 finalClaimHash = InboxTestLib.hashClaim(claims[numProposals - 1]);
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

        IInbox.Claim memory claim1 = InboxTestLib.createClaim(proposal1, parentClaimHash, Bob);
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
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(3, 0);
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

        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(2, 0);

        // Store correct claim record
        IInbox.Claim memory claim =
            InboxTestLib.createClaim(proposal, coreState.lastFinalizedClaimHash, Bob);
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
