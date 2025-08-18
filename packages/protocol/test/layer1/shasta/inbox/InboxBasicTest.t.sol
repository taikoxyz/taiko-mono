// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { Inbox, InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

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
        // Arrange: Create proposal data with wrong core state (nextProposalId=2 instead of 1)
        IInbox.CoreState memory wrongCoreState = InboxTestLib.createCoreState(2, 0);
        bytes memory data = encodeProposalDataWithGenesis(
            wrongCoreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Act & Assert: Invalid state should be rejected
        setupBlobHashes();
        setupProposalMocks(Alice);
        expectRevertWithReason(InvalidState.selector, "Wrong core state should be rejected");

        vm.prank(Alice);
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

        bytes memory data = encodeProposalDataWithGenesis(
            expiredDeadline, coreState, createValidBlobReference(1), new IInbox.ClaimRecord[](0)
        );

        // Act & Assert: Expired deadline should be rejected
        setupBlobHashes();
        setupProposalMocks(Alice);
        expectRevertWithReason(DeadlineExceeded.selector, "Expired deadline should be rejected");

        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    /// @dev Validates basic proof submission flow
    function test_prove_single_claim() public {
        // Arrange: Submit a proposal that can be proven
        IInbox.Proposal memory proposal = submitProposal(1, Alice);

        // Act: Submit proof for the proposal with genesis parent
        bytes32 genesisClaimHash = getGenesisClaimHash();
        proveProposal(proposal, Bob, genesisClaimHash);

        // Assert: Verify claim record was stored for later finalization
        assertClaimRecordStored(1, genesisClaimHash);
    }

    /// @notice Test proving multiple claims individually
    /// @dev Validates individual proof submission for multiple proposals
    function test_prove_multiple_claims() public {
        uint48 numProposals = 3;
        bytes32 genesisHash = getGenesisClaimHash();

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
            IInbox.Claim memory claim = InboxTestLib.createClaim(proposals[i], currentParent, Bob);
            currentParent = InboxTestLib.hashClaim(claim);
        }

        // Verify all claim records stored
        currentParent = genesisHash;
        for (uint48 i = 0; i < numProposals; i++) {
            assertClaimRecordStored(i + 1, currentParent);
            IInbox.Claim memory claim = InboxTestLib.createClaim(proposals[i], currentParent, Bob);
            currentParent = InboxTestLib.hashClaim(claim);
        }
    }
}
