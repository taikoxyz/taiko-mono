// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";

/// @title InboxStandardGasTest
/// @notice Gas measurement test for standard Inbox implementation
/// @dev Use this to measure baseline gas usage for comparison
contract InboxStandardGasTest is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    /// forge-config: default.isolate = true
    function test_gasUsage_singleProposal() public {
        _setupBlobHashes();

        vm.startPrank(currentProposer);

        // Start gas measurement before the proposal
        uint256 gasStart = gasleft();

        vm.roll(block.number + 1);

        // Create proposal input after block roll to match checkpoint values
        bytes memory proposeData = _createFirstProposeInput();

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);

        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        inbox.propose(bytes(""), proposeData);

        // Calculate gas used
        uint256 gasUsed = gasStart - gasleft();

        // Log result - note: this will show in forge test -vvv output
        emit log_named_uint("Standard Inbox Gas Usage", gasUsed);

        vm.stopPrank();

        // Assert: Verify proposal hash is stored
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");
    }
}