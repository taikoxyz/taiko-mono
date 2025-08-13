// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestScenarios.sol";
import "./InboxMockContracts.sol";
import "./InboxTestUtils.sol";
import "./InboxTestBuilder.sol";
import { Inbox, InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract without slot reuse functionality
contract InboxBasicTest is InboxTestScenarios {
    using InboxTestUtils for *;
    using InboxTestBuilder for *;

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

        // Setup initial state and expectations
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        IInbox.Proposal memory expectedProposal = InboxTestUtils.createProposal(1, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 2;

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit Proposed(expectedProposal, expectedCoreState);

        // Submit proposal with standard setup
        setupStandardProposalMocks(Alice);
        vm.prank(Alice);
        inbox.propose(
            bytes(""),
            InboxTestUtils.encodeProposalData(coreState, InboxTestUtils.createBlobReference(1), new IInbox.ClaimRecord[](0))
        );

        // Verify
        assertProposalStored(1);
        assertEq(inbox.getProposalHash(1), expectedProposal.hashProposal());
        assertEq(inbox.getCoreStateHash(), expectedCoreState.hashCoreState());
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
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Create proposal with wrong state
        IInbox.CoreState memory wrongCoreState = createCoreState(2, 0); // Wrong nextProposalId
        bytes memory data = InboxTestUtils.encodeProposalData(
            wrongCoreState,
            InboxTestUtils.createBlobReference(1),
            new IInbox.ClaimRecord[](0)
        );

        // Expect revert
        setupStandardProposalMocks(Alice);
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with deadline exceeded reverts
    function test_propose_deadline_exceeded_reverts() public {
        setupBlobHashes();
        vm.warp(1000);

        // Setup state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Create proposal with expired deadline
        bytes memory data = InboxTestUtils.encodeProposalDataWithDeadline(
            uint64(block.timestamp - 1),
            coreState,
            createValidBlobReference(1),
            new IInbox.ClaimRecord[](0)
        );

        // Expect revert
        setupStandardProposalMocks(Alice);
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    function test_prove_single_claim() public {
        setupBlobHashes();

        // Submit and prove efficiently
        submitAndProveProposal(1, Alice, Bob, bytes32(0));

        // Verify
        assertClaimRecordStored(1, bytes32(0));
    }
}
