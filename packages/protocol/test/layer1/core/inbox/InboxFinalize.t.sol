// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

contract InboxFinalizeTest is InboxTestBase {
    function test_finalize_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Warp past minCheckpointDelay to trigger checkpoint sync
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        _proveWithGas(input, "shasta-prove", "finalize_single");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedTimestamp, uint48(block.timestamp), "finalized timestamp");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
        assertEq(state.lastFinalizedBlockHash, input.proposalStates[0].blockHash, "block hash");
    }

    function test_finalize_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        // Warp past minCheckpointDelay to trigger checkpoint sync
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        _proveWithGas(input, "shasta-prove", "finalize_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 2, "finalized id");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
    }

    function test_finalize_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        // Warp past minCheckpointDelay to trigger checkpoint sync
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        _proveWithGas(input, "shasta-prove", "finalize_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 4, "finalized id");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
    }

    function test_finalize_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        // Warp past minCheckpointDelay to trigger checkpoint sync
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        _proveWithGas(input, "shasta-prove", "finalize_consecutive_10");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 9, "finalized id");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
    }

    function test_finalize_noCheckpointSync_beforeDelay() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Do NOT warp past minCheckpointDelay - checkpoint should not sync
        _prove(input);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        // Checkpoint timestamp should remain 0 (initial value) since delay hasn't passed
        assertEq(state.lastCheckpointTimestamp, 0, "checkpoint timestamp unchanged");
    }

    function test_finalize_checkpointSyncsAfterDelay() public {
        // First prove without checkpoint sync
        IInbox.ProveInput memory input1 = _buildBatchInput(1);
        _prove(input1);

        uint48 checkpointBefore = inbox.getState().lastCheckpointTimestamp;
        assertEq(checkpointBefore, 0, "checkpoint not synced initially");

        // Advance block and propose another
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // Warp past minCheckpointDelay
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput memory input2 = IInbox.ProveInput({
            firstProposalId: p2.proposal.id,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot2"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input2);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint synced");
    }
}
