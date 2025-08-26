// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { TestInboxOptimized3 } from "../implementations/TestInboxOptimized3.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { LibProveInputDecoder } from "contracts/layer1/shasta/libs/LibProveInputDecoder.sol";

/// @title InboxOptimized3Prove
/// @notice Test suite for prove functionality on InboxOptimized3 implementation
contract InboxOptimized3Prove is AbstractProveTest {
    function getTestContractName() internal pure override returns (string memory) {
        return "InboxOptimized3";
    }

    // Override the inconsistent params test for InboxOptimized3 which uses different error
    // NOTE: This test will fail because InboxOptimized3 uses LibProveInputDecoder which throws
    // ProposalTransitionLengthMismatch() instead of InconsistentParams() during encoding
    // This is expected behavior for this optimized version
    function test_prove_RevertWhen_InconsistentParams() public override {
        // Create ProveInput with mismatched array lengths
        IInbox.ProveInput memory input;
        input.proposals = new IInbox.Proposal[](2);
        input.transitions = new IInbox.Transition[](1); // Mismatch!
        
        // InboxOptimized3 uses LibProveInputDecoder which throws ProposalTransitionLengthMismatch()
        // during encoding itself, not during prove()
        vm.expectRevert(LibProveInputDecoder.ProposalTransitionLengthMismatch.selector);
        inbox.encodeProveInput(input);
    }

    function _getExpectedAggregationBehavior(uint256 proposalCount, bool consecutive) 
        internal pure override returns (uint256 expectedEvents, uint256 expectedMaxSpan) {
        if (consecutive) {
            return (1, proposalCount); // One event with span=proposalCount
        } else {
            return (proposalCount, 1); // Individual events for gaps
        }
    }

    function _getExpectedMixedScenarioEvents() internal pure override returns (uint256) {
        // Optimized: 2 events (groups 1-2 and 4-6)
        return 2;
    }

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override
        returns (Inbox)
    {
        // Deploy implementation
        address impl = address(
            new TestInboxOptimized3(
                bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );

        // Deploy proxy using the helper function
        return Inbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (owner, GENESIS_BLOCK_HASH))
            })
        );
    }
}