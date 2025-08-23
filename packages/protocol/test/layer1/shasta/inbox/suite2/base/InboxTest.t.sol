// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title InboxTest
/// @notice All common tests for Inbox implementations
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTest is InboxTestBase {
    function setUp() public virtual override {
        // Deploy dependencies
        setupDependencies();

        // Setup mocks - we usually avoid mocks as much as possible since they might make testing
        // flaky
        setupMocks();

        // Deploy inbox through implementation-specific method
        inbox = deployInbox(
            address(bondToken),
            address(syncedBlockManager),
            address(proofVerifier),
            address(proposerChecker),
            address(forcedInclusionStore)
        );

        upgradeDependencies(address(inbox));

        // Advance block to ensure we have block history
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);

        //TODO: ideally we also setup the blob hashes here to avoid doing it on each test but it
        // doesn't last until the test run
    }

    // ---------------------------------------------------------------
    // Propose Tests
    // ---------------------------------------------------------------

    function test_propose_single() public {
        setupBlobHashes();

        // Arrange: Create the first proposal input after genesis
        bytes memory proposeData = createFirstProposeInput();

        // Build expected event data
        IInbox.ProposedEventPayload memory expectedPayload = buildExpectedProposedPayload(1);

        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));

        // Act: Submit the proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), proposeData);

        // Assert: Verify proposal hash is stored
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");
    }
}
