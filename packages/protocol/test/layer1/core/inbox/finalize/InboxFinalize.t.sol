// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { InboxVariant } from "../common/InboxTestBase.sol";
import { ProveTestBase } from "../prove/InboxProve.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

abstract contract FinalizeTestBase is ProveTestBase {
    constructor(InboxVariant _variant) ProveTestBase(_variant) { }

    function test_finalize_updatesTimestamps() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        vm.warp(block.timestamp + 1 hours);

        IInbox.Transition memory transition = _transitionFor(
            proposed, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            checkpoint: transition.checkpoint
        });

        vm.prank(prover);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedTimestamp, uint48(block.timestamp), "finalized timestamp");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
        assertEq(state.bondInstructionsHash, bytes32(0), "bond hash unchanged");
    }

    function test_finalize_RevertWhen_CheckpointMissing() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Transition memory transition = _transitionFor(
            proposed, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0) })
        });

        vm.prank(prover);
        vm.expectRevert(Inbox.CheckpointNotProvided.selector);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
    }
}

contract InboxFinalizeTest is FinalizeTestBase {
    constructor() FinalizeTestBase(InboxVariant.Simple) { }
}

contract InboxOptimizedFinalizeTest is FinalizeTestBase {
    constructor() FinalizeTestBase(InboxVariant.Optimized) { }
}
