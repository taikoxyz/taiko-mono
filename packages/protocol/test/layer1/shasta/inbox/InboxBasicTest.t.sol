// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { Inbox, InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract without slot reuse functionality
/// @dev This test suite covers fundamental Inbox operations:
///      - Single and multiple proposal submissions
///      - Core state validation and updates
///      - Basic error conditions and validation
///      - Simple proof submission flow
/// @custom:security-contact security@taiko.xyz
contract InboxBasicTest is InboxTest {
    using InboxTestLib for *;

    /// @notice Test submitting a single valid proposal
    /// @dev Validates the complete proposal submission flow:
    ///      1. Blob hash setup for EIP-4844 compatibility
    ///      2. Proposal creation and submission via helper
    ///      3. Storage verification of proposal data
    ///      4. Core state progression validation
    function test_propose_single_valid() public {
        // Setup: Prepare blob hashes for EIP-4844 blob references
        setupBlobHashes();

        // Act: Submit a proposal with ID=1 from Alice
        // This helper handles core state setup, mocks, and submission
        IInbox.Proposal memory proposal = submitProposal(1, Alice);

        // Assert: Verify proposal was stored correctly
        assertProposalStored(1);
        assertEq(inbox.getProposalHash(1), proposal.hashProposal());

        // Assert: Verify core state progression (nextProposalId: 1→2, lastFinalized: 0→0)
        assertCoreState(2, 0);
    }

    /// @notice Test submitting multiple proposals sequentially
    /// @dev Validates batch proposal submission and storage:
    ///      1. Sequential ID assignment (1, 2, 3, 4, 5)
    ///      2. Independent proposal storage
    ///      3. Efficient batch verification
    function test_propose_multiple_sequential() public {
        // Setup: Prepare environment for multiple proposals
        setupBlobHashes();
        uint48 numProposals = 5;

        // Act: Submit proposals with sequential IDs from Alice
        for (uint48 i = 1; i <= numProposals; i++) {
            submitProposal(i, Alice);
        }

        // Assert: Verify all proposals were stored correctly
        assertProposalsStored(1, numProposals);
    }

    /// @notice Test proposal with invalid state reverts
    /// @dev Validates core state validation by testing state hash mismatch:
    ///      1. Sets correct core state in contract storage
    ///      2. Attempts submission with mismatched core state
    ///      3. Expects InvalidState error for security protection
    function test_propose_invalid_state_reverts() public {
        // Setup: Prepare blob hashes and set correct core state in contract storage (nextProposalId=1)
        setupBlobHashes();
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(1, 0);
        // Core state will be validated by the contract during propose()

        // Arrange: Create proposal data with wrong core state (nextProposalId=2)
        // This simulates an attack attempt or state desynchronization
        IInbox.CoreState memory wrongCoreState = InboxTestLib.createCoreState(2, 0);
        bytes memory data = InboxTestLib.encodeProposalDataWithGenesis(
            wrongCoreState, InboxTestLib.createBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Act & Assert: Attempt submission should fail with InvalidState
        setupProposalMocks(Alice);
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with deadline exceeded reverts
    /// @dev Validates deadline enforcement mechanism:
    ///      1. Advances block timestamp to create time context
    ///      2. Creates proposal with past deadline (timestamp - 1)
    ///      3. Expects DeadlineExceeded error for time-based protection
    function test_propose_deadline_exceeded_reverts() public {
        // Setup: Prepare environment and advance time to create context
        setupBlobHashes();
        vm.warp(1000); // Set block.timestamp = 1000

        // Setup: Configure valid core state - must match genesis
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        
        // Arrange: Create proposal with expired deadline (timestamp - 1 = 999)
        bytes memory data = InboxTestLib.encodeProposalDataWithGenesis(
            uint64(block.timestamp - 1), // Expired deadline
            coreState,
            createValidBlobReference(1),
            new IInbox.ClaimRecord[](0)
        );

        // Act & Assert: Submission should fail with DeadlineExceeded
        setupProposalMocks(Alice);
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    /// @dev Validates basic proof submission flow:
    ///      1. Submits a proposal to create something to prove
    ///      2. Submits a proof for the proposal with null parent
    ///      3. Verifies claim record is stored for future finalization
    function test_prove_single_claim() public {
        // Setup: Prepare environment for proof submission
        setupBlobHashes();

        // Arrange: Submit a proposal that can be proven
        IInbox.Proposal memory proposal = submitProposal(1, Alice);

        // Act: Submit proof for the proposal with null parent (genesis)
        proveProposal(proposal, Bob, bytes32(0));

        // Assert: Verify claim record was stored for later finalization
        assertClaimRecordStored(1, bytes32(0));
    }
}
