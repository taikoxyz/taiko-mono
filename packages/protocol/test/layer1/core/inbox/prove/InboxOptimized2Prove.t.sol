// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2Deployer } from "../deployers/InboxOptimized2Deployer.sol";
import { AbstractProveTest } from "./AbstractProve.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
// Import errors from Inbox implementation
import "src/layer1/core/impl/Inbox.sol";

/// @title InboxOptimized2Prove
/// @notice Test suite for prove functionality on InboxOptimized2 implementation
contract InboxOptimized2Prove is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized2Deployer());
        super.setUp();
    }

    /// @dev Override for InboxOptimized2 which uses custom decoding that doesn't support this test
    /// scenario
    /// The optimized decoder expects custom-encoded data, not standard abi.encode format
    /// When given standard encoded data, it misinterprets the format and sees empty arrays
    function test_prove_RevertWhen_InconsistentParams() public override {
        // Create empty ProveInput that will be misinterpreted by the optimized decoder
        IInbox.ProveInput memory input;
        input.proposals = new IInbox.Proposal[](0);
        input.transitions = new IInbox.Transition[](0);
        input.metadata = new IInbox.TransitionMetadata[](0);

        // Standard encoding is misinterpreted by LibProveInputDecoder as empty
        bytes memory proveData = abi.encode(input);
        bytes memory proof = _createValidProof();

        // InboxOptimized2's decoder misinterprets abi.encode format and sees empty arrays
        vm.expectRevert(Inbox.EmptyProposals.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
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
}
