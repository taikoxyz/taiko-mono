// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { InboxVariant } from "./InboxTestBase.sol";
import { ProveTestBase } from "./InboxProve.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

abstract contract FinalizeTestBase is ProveTestBase {
    constructor(InboxVariant _variant) ProveTestBase(_variant) { }

    function test_finalize_single() public {
        (IInbox.ProveInput memory proveInput, IInbox.Transition[] memory transitions) =
            _buildBatchInput(1, true);

        vm.warp(block.timestamp + 1 hours);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_single");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedTimestamp, uint48(block.timestamp), "finalized timestamp");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
        assertEq(
            state.lastFinalizedTransitionHash, codec.hashTransition(transitions[0]), "transition hash"
        );
    }

    function test_finalize_batch3() public {
        (IInbox.ProveInput memory proveInput,) =
            _buildBatchInput(3, true);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[2].id, "finalized id");
    }

    function test_finalize_batch5() public {
        (IInbox.ProveInput memory proveInput,) =
            _buildBatchInput(5, true);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[4].id, "finalized id");
    }

    function test_finalize_batch10() public {
        (IInbox.ProveInput memory proveInput,) =
            _buildBatchInput(10, true);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_consecutive_10");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[9].id, "finalized id");
    }

    function test_finalize_RevertWhen_CheckpointMissing() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Transition memory transition = _transitionFor(
            proposed, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            syncCheckpoint: false
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);
        vm.expectRevert(Inbox.CheckpointNotProvided.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
    }
}

contract InboxFinalizeTest is FinalizeTestBase {
    constructor() FinalizeTestBase(InboxVariant.Simple) { }
}

contract InboxOptimizedFinalizeTest is FinalizeTestBase {
    constructor() FinalizeTestBase(InboxVariant.Optimized) { }
}
