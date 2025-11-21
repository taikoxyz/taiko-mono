// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractProveTest } from "./AbstractProve.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { Vm } from "forge-std/src/Vm.sol";

/// @title InboxOptimized1Prove
/// @notice Test suite for prove functionality on InboxOptimized1 implementation
contract InboxOptimized1Prove is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    function _getExpectedAggregationBehavior(
        uint256 proposalCount,
        bool consecutive
    )
        internal
        pure
        override
        returns (uint256 expectedEvents, uint256 expectedMaxSpan)
    {
        if (consecutive) {
            return (1, proposalCount); // One event with span=proposalCount
        } else {
            return (proposalCount, 1); // Individual events for gaps
        }
    }

    /// @dev Extended test: Verify aggregated Proved event payload structure for span=2
    /// @dev This extends the base test_prove_twoConsecutiveProposals with event payload verification
    function test_prove_twoConsecutiveProposals_verifyEventPayload() public {
        // Create 2 consecutive proposals (same as parent test)
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(2);

        // Create prove input (same as parent test)
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        // Check expected events based on implementation (same as parent test)
        (uint256 expectedEvents,) = _getExpectedAggregationBehavior(2, true);

        // Record events to verify count later (same as parent test)
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas(
            "shasta-prove", string.concat("prove_consecutive_2_verify_", inboxContractName)
        );
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Verify correct number of events were emitted (same as parent test)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, expectedEvents, "Unexpected number of Proved events");

        // NEW: Extract and verify the aggregated event payload
        IInbox.ProvedEventPayload memory payload = _extractProvedEventPayload(logs);

        // NEW: Verify proposalId should be the FIRST proposal's ID
        assertEq(payload.proposalId, proposals[0].id, "ProposalId should match first proposal");

        // NEW: Verify transition.proposalHash should be the FIRST proposal's hash
        assertEq(
            payload.transition.proposalHash,
            _codec().hashProposal(proposals[0]),
            "Transition proposalHash should match first proposal"
        );

        // NEW: Verify span should be 2 (aggregating 2 consecutive proposals)
        assertEq(payload.transitionRecord.span, 2, "TransitionRecord span should be 2");
    }

    /// @notice Extract the ProvedEventPayload from recorded logs
    /// @dev Expects exactly one Proved event in the logs
    function _extractProvedEventPayload(Vm.Log[] memory _logs)
        internal
        view
        returns (IInbox.ProvedEventPayload memory payload)
    {
        for (uint256 i = 0; i < _logs.length; i++) {
            if (_logs[i].topics[0] == keccak256("Proved(bytes)")) {
                bytes memory eventData = _logs[i].data;
                // Event data is already ABI encoded, decode the outer wrapper first
                bytes memory innerData = abi.decode(eventData, (bytes));
                return _codec().decodeProvedEvent(innerData);
            }
        }
        revert("No Proved event found");
    }
}
