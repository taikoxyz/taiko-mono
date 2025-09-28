// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractPropose.t.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title InboxOptimized1ConsecutiveTest
/// @notice Isolated test for consecutive proposals functionality on Optimized1 Inbox
contract InboxOptimized1ConsecutiveTest is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    function test_propose_twoConsecutiveProposals() public override {
        _setupBlobHashes();

        // First proposal (ID 1)
        vm.roll(block.number + 1);

        // Create proposal input after block roll
        bytes memory firstProposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory firstExpectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(firstExpectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), firstProposeData);

        // Verify first proposal
        bytes32 firstProposalHash = inbox.getProposalHash(1);
        assertEq(
            firstProposalHash,
            _codec().hashProposal(firstExpectedPayload.proposal),
            "First proposal hash mismatch"
        );

        // Advance block for second proposal (need 1 block gap)
        uint48 firstProposalBlock = uint48(block.number); // Store the block number where first
            // proposal was made
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // Second proposal (ID 2) - using the first proposal as parent
        // First proposal set lastProposalBlockId to firstProposalBlock
        IInbox.CoreState memory secondCoreState = IInbox.CoreState({
            nextProposalId: 2,
            lastProposalBlockId: firstProposalBlock, // Block where first proposal was made
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory secondParentProposals = new IInbox.Proposal[](1);
        secondParentProposals[0] = firstExpectedPayload.proposal;

        // No additional roll needed - we already advanced by 1 block above

        // Create second proposal input after block roll
        bytes memory secondProposeData = _codec().encodeProposeInput(
            _createProposeInputWithCustomParams(
                0, // no deadline
                _createBlobRef(0, 1, 0),
                secondParentProposals,
                secondCoreState
            )
        );

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory secondExpectedPayload = _buildExpectedProposedPayload(2);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(secondExpectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), secondProposeData);

        // Verify second proposal
        bytes32 secondProposalHash = inbox.getProposalHash(2);
        assertEq(
            secondProposalHash,
            _codec().hashProposal(secondExpectedPayload.proposal),
            "Second proposal hash mismatch"
        );

        // Verify both proposals exist
        assertTrue(inbox.getProposalHash(1) != bytes32(0), "First proposal should still exist");
        assertTrue(inbox.getProposalHash(2) != bytes32(0), "Second proposal should exist");
        assertNotEq(
            inbox.getProposalHash(1),
            inbox.getProposalHash(2),
            "Proposals should have different hashes"
        );
    }
}
