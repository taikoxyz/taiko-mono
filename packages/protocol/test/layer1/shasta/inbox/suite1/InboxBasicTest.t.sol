// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract fundamental operations
/// @dev This test suite covers:
///      - Single and multiple proposal submissions
///      - Core state validation and updates
///      - Basic error conditions and validation
///      - Simple proof submission flow
/// @custom:security-contact security@taiko.xyz
contract InboxBasicTest is InboxTest {
    using InboxTestLib for *;

    /// @notice Test submitting a single valid proposal
    /// @dev Validates the complete proposal submission flow
    function test_propose_single_valid() public {
        // Act: Submit a proposal with ID=1 from Alice
        IInbox.Proposal memory proposal = submitProposal(1, Alice);

        // Assert: Verify proposal was stored correctly
        assertProposalStored(1);
        assertProposalHashMatches(1, proposal);
        assertCoreState(2, 0);
    }

    /// @notice Test submitting multiple proposals sequentially
    /// @dev Validates batch proposal submission and storage
    function test_propose_multiple_sequential() public {
        uint48 numProposals = 5;

        // Act: Submit proposals with sequential IDs from Alice
        for (uint48 i = 1; i <= numProposals; i++) {
            submitProposal(i, Alice);
        }

        // Assert: Verify all proposals were stored correctly
        assertProposalsStored(1, numProposals);
    }

    /// @notice Test proposal with invalid state reverts
    /// @dev Validates core state validation by testing state hash mismatch
    function test_propose_invalid_state_reverts() public {
        // Arrange: Create the actual genesis proposal with correct coreStateHash
        IInbox.CoreState memory genesisCoreState = IInbox.CoreState({
            nextProposalId: 1,
            nextProposalBlockId: 2, // Genesis value - prevents blockhash(0) issue
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
        IInbox.Proposal memory genesisProposal =
            InboxTestLib.createGenesisProposal(genesisCoreState);

        // Create proposal data with wrong core state (nextProposalId=2 instead of 1)
        IInbox.CoreState memory wrongCoreState = InboxTestLib.createCoreState(2, 0);
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = genesisProposal;

        bytes memory data = InboxTestAdapter.encodeProposeInput(
            inboxType,
            uint48(0),
            wrongCoreState,
            proposals,
            createValidBlobReference(1),
            new IInbox.TransitionRecord[](0)
        );

        // Act & Assert: Invalid state should be rejected
        setupBlobHashes();
        setupProposalMocks(Alice);
        expectRevertWithReason(InvalidState.selector, "Wrong core state should be rejected");

        vm.prank(Alice);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with deadline exceeded reverts
    /// @dev Validates deadline enforcement mechanism
    function test_propose_deadline_exceeded_reverts() public {
        // Setup: Advance time to create context
        vm.warp(1000);

        // Arrange: Create proposal with expired deadline
        uint48 expiredDeadline = createDeadlineTestData(true);
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        bytes memory data = encodeProposeInputWithGenesis(
            expiredDeadline,
            coreState,
            createValidBlobReference(1),
            new IInbox.TransitionRecord[](0)
        );

        // Act & Assert: Expired deadline should be rejected
        setupBlobHashes();
        setupProposalMocks(Alice);
        expectRevertWithReason(DeadlineExceeded.selector, "Expired deadline should be rejected");

        vm.prank(Alice);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a transition
    /// @dev Validates basic proof submission flow
    function test_prove_single_transition() public {
        // Arrange: Submit a proposal that can be proven
        IInbox.Proposal memory proposal = submitProposal(1, Alice);

        // Act: Submit proof for the proposal with genesis parent
        bytes32 genesisTransitionHash = getGenesisTransitionHash();
        proveProposal(proposal, Bob, genesisTransitionHash);

        // Assert: Verify transition record was stored for later finalization
        assertTransitionRecordStored(1, genesisTransitionHash);
    }

    /// @notice Test proving multiple transitions individually
    /// @dev Validates individual proof submission for multiple proposals
    function test_prove_multiple_transitions() public {
        uint48 numProposals = 3;
        bytes32 genesisHash = getGenesisTransitionHash();

        // Submit proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Prove each proposal individually
        bytes32 currentParent = genesisHash;
        for (uint48 i = 0; i < numProposals; i++) {
            proveProposal(proposals[i], Bob, currentParent);
            // Update parent for next iteration
            IInbox.Transition memory transition =
                InboxTestLib.createTransition(proposals[i], currentParent);
            currentParent = InboxTestLib.hashTransition(transition);
        }

        // Verify all transition records stored
        currentParent = genesisHash;
        for (uint48 i = 0; i < numProposals; i++) {
            assertTransitionRecordStored(i + 1, currentParent);
            IInbox.Transition memory transition =
                InboxTestLib.createTransition(proposals[i], currentParent);
            currentParent = InboxTestLib.hashTransition(transition);
        }
    }
}
