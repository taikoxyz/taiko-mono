// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { Inbox, InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract without slot reuse functionality
/// @custom:security-contact security@taiko.xyz
contract InboxBasicTest is InboxTest {
    using InboxTestLib for *;

    /// @notice Test submitting a single valid proposal
    function test_propose_single_valid() public {
        setupBlobHashes();

        // Simply use the submitProposal helper which handles all setup
        IInbox.Proposal memory proposal = submitProposal(1, Alice);

        // Verify proposal was stored correctly
        assertProposalStored(1);
        assertEq(inbox.getProposalHash(1), proposal.hashProposal());

        // Verify core state was updated
        assertCoreState(2, 0); // nextProposalId should be 2, lastFinalized should be 0
    }

    /// @notice Test submitting multiple proposals sequentially
    function test_propose_multiple_sequential() public {
        setupBlobHashes();
        uint48 numProposals = 5;

        // Submit proposals efficiently
        for (uint48 i = 1; i <= numProposals; i++) {
            submitProposal(i, Alice);
        }

        // Batch verification
        assertProposalsStored(1, numProposals);
    }

    /// @notice Test proposal with invalid state reverts
    function test_propose_invalid_state_reverts() public {
        // Setup correct state
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Create proposal with wrong state
        IInbox.CoreState memory wrongCoreState = InboxTestLib.createCoreState(2, 0); // Wrong
            // nextProposalId
        bytes memory data = InboxTestLib.encodeProposalData(
            wrongCoreState, InboxTestLib.createBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Expect revert
        setupProposalMocks(Alice);
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with deadline exceeded reverts
    function test_propose_deadline_exceeded_reverts() public {
        setupBlobHashes();
        vm.warp(1000);

        // Setup state
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Create proposal with expired deadline
        bytes memory data = InboxTestLib.encodeProposalData(
            uint64(block.timestamp - 1),
            coreState,
            createValidBlobReference(1),
            new IInbox.ClaimRecord[](0)
        );

        // Expect revert
        setupProposalMocks(Alice);
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    function test_prove_single_claim() public {
        setupBlobHashes();

        // Submit proposal and prove it
        IInbox.Proposal memory proposal = submitProposal(1, Alice);
        proveProposal(proposal, Bob, bytes32(0));

        // Verify
        assertClaimRecordStored(1, bytes32(0));
    }
}
