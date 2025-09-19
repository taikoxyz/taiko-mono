// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxOptimized4Deployer } from "../deployers/InboxOptimized4Deployer.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibProveInputDecoder } from "contracts/layer1/shasta/libs/LibProveInputDecoder.sol";

/// @title InboxOptimized4Prove
/// @notice Test suite for prove functionality on InboxOptimized4 implementation
contract InboxOptimized4Prove is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized4Deployer());
        super.setUp();
    }

    // Override the inconsistent params test for InboxOptimized4 which uses different error
    // NOTE: This test will fail because InboxOptimized4 inherits from InboxOptimized3 which uses
    // LibProveInputDecoder that throws ProposalTransitionLengthMismatch() instead of 
    // InconsistentParams() during encoding. This is expected behavior for this optimized version
    function test_prove_RevertWhen_InconsistentParams() public override(AbstractProveTest) {
        // Create ProveInput with mismatched array lengths
        IInbox.ProveInput memory input;
        input.proposals = new IInbox.Proposal[](2);
        input.transitions = new IInbox.Transition[](1); // Mismatch!

        // InboxOptimized4 (inheriting from InboxOptimized3) uses LibProveInputDecoder which throws
        // ProposalTransitionLengthMismatch() during encoding itself, not during prove()
        vm.expectRevert(LibProveInputDecoder.ProposalTransitionLengthMismatch.selector);
        helper.encodeProveInputOptimized(input);
    }

    function _getExpectedAggregationBehavior(
        uint256 proposalCount,
        bool consecutive
    )
        internal
        pure
        override(AbstractProveTest)
        returns (uint256 expectedEvents, uint256 expectedMaxSpan)
    {
        if (consecutive) {
            return (1, proposalCount); // One event with span=proposalCount
        } else {
            return (proposalCount, 1); // Individual events for gaps
        }
    }
}