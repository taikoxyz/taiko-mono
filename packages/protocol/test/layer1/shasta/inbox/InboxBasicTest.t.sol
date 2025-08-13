// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestScenarios.sol";
import "./InboxMockContracts.sol";
import "./InboxTestUtils.sol";
import { Inbox, InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract without slot reuse functionality
contract InboxBasicTest is InboxTestScenarios {
    using InboxTestUtils for *;
    function setUp() public virtual override {
        super.setUp();
    }

    // Override setupMockAddresses to use actual mock contracts instead of makeAddr
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }

    /// @notice Test submitting a single valid proposal
    function test_propose_single_valid() public {
        setupBlobHashes();

        // Setup initial core state
        IInbox.CoreState memory coreState = InboxTestUtils.createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data
        LibBlobs.BlobReference memory blobRef = InboxTestUtils.createBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = InboxTestUtils.encodeProposalData(coreState, blobRef, claimRecords);

        // Expected proposal and core state
        IInbox.Proposal memory expectedProposal = InboxTestUtils.createProposal(1, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 2;

        // Expect Proposed event
        vm.expectEmit(true, true, true, true);
        emit Proposed(expectedProposal, expectedCoreState);

        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify proposal and state
        assertProposalStored(1);
        assertEq(inbox.getProposalHash(1), expectedProposal.hashProposal());
        assertEq(inbox.getCoreStateHash(), expectedCoreState.hashCoreState());
    }

    /// @notice Test submitting multiple proposals sequentially
    function test_propose_multiple_sequential() public {
        setupBlobHashes();
        uint48 numProposals = 5;

        for (uint48 i = 1; i <= numProposals; i++) {
            submitProposal(i, Alice);
        }

        // Verify all proposals are accessible
        assertProposalsStored(1, numProposals);
    }

    /// @notice Test proposal with invalid state reverts
    function test_propose_invalid_state_reverts() public {
        // Setup initial core state
        IInbox.CoreState memory coreState = InboxTestUtils.createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data with wrong core state
        IInbox.CoreState memory wrongCoreState = InboxTestUtils.createCoreState(2, 0); // Wrong nextProposalId
        LibBlobs.BlobReference memory blobRef = InboxTestUtils.createBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = InboxTestUtils.encodeProposalData(wrongCoreState, blobRef, claimRecords);

        // Expect revert with InvalidState error
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with deadline exceeded reverts
    function test_propose_deadline_exceeded_reverts() public {
        setupBlobHashes();

        // Move time forward to ensure block.timestamp > 1
        vm.warp(1000);

        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data with expired deadline
        uint64 deadline = uint64(block.timestamp - 1); // Expired deadline
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data =
            encodeProposalDataWithDeadline(deadline, coreState, blobRef, claimRecords);

        // Expect revert with DeadlineExceeded error
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    function test_prove_single_claim() public {
        setupBlobHashes();
        
        // Submit proposal and prove it
        (IInbox.Proposal memory proposal, IInbox.Claim memory claim) = submitAndProveProposal(
            1,
            Alice,
            Bob,
            bytes32(0)
        );

        // Verify claim is stored
        assertClaimRecordStored(1, bytes32(0));
    }
}
