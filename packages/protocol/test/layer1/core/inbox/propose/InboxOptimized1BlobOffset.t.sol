// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractProposeTest } from "./AbstractPropose.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

/// @title InboxOptimized1BlobOffsetTest
/// @notice Isolated test for blob offset functionality on Optimized1 Inbox
contract InboxOptimized1BlobOffsetTest is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    function test_InboxOptimized1_propose_withBlobOffset() public {
        _setupBlobHashes();

        vm.roll(block.number + 1);

        // Create proposal input with blob offset after block roll
        bytes memory proposeData = _codec().encodeProposeInput(_createProposeInputWithBlobs(2, 100));

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayloadWithBlobs(1, 2, 100);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash and check that offset was correctly included
        bytes32 expectedHash = _codec().hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Blob with offset proposal hash mismatch");
    }
}
