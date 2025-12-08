// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract InboxFinalizeTest is InboxTestBase {
    function test_finalize_single() public {
        (IInbox.ProveInput memory proveInput, IInbox.Transition[] memory transitions) =
            _buildBatchInput(1, true);

        vm.warp(block.timestamp + 1 hours);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_single");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedTimestamp, uint48(block.timestamp), "finalized timestamp");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");
        assertEq(
            state.lastFinalizedTransitionHash,
            codec.hashTransition(transitions[0]),
            "transition hash"
        );
    }

    function test_finalize_batch3() public {
        (IInbox.ProveInput memory proveInput,) = _buildBatchInput(3, true);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[2].id, "finalized id");
    }

    function test_finalize_batch5() public {
        (IInbox.ProveInput memory proveInput,) = _buildBatchInput(5, true);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[4].id, "finalized id");
    }

    function test_finalize_batch10() public {
        (IInbox.ProveInput memory proveInput,) = _buildBatchInput(10, true);
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "finalize_consecutive_10");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[9].id, "finalized id");
    }

    function test_finalize_RevertWhen_CheckpointMissing() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Transition memory transition = _transitionFor(
            proposed,
            inbox.getState().lastFinalizedTransitionHash,
            bytes32(uint256(1)),
            prover,
            prover
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

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _proposeOne() internal returns (IInbox.ProposedEventPayload memory payload_) {
        _setBlobHashes(3);
        payload_ = _proposeAndDecode(_defaultProposeInput());
    }

    function _checkpoint(bytes32 _stateRoot)
        internal
        view
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: uint48(block.number),
            blockHash: blockhash(block.number - 1),
            stateRoot: _stateRoot
        });
    }

    function _transitionFor(
        IInbox.ProposedEventPayload memory _proposal,
        bytes32 _parentTransitionHash,
        bytes32 _stateRoot,
        address _designatedProver,
        address _actualProver
    )
        internal
        view
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: codec.hashProposal(_proposal.proposal),
            parentTransitionHash: _parentTransitionHash,
            checkpoint: _checkpoint(_stateRoot),
            designatedProver: _designatedProver,
            actualProver: _actualProver
        });
    }

    function _buildBatchInput(
        uint256 _count,
        bool _syncCheckpoint
    )
        internal
        returns (IInbox.ProveInput memory input_, IInbox.Transition[] memory transitions_)
    {
        input_.proposals = new IInbox.Proposal[](_count);
        transitions_ = new IInbox.Transition[](_count);

        bytes32 parentHash = inbox.getState().lastFinalizedTransitionHash;
        for (uint256 i; i < _count; ++i) {
            if (i != 0) _advanceBlock();
            IInbox.ProposedEventPayload memory proposal = _proposeOne();
            input_.proposals[i] = proposal.proposal;
            transitions_[i] =
                _transitionFor(proposal, parentHash, bytes32(uint256(i + 1)), prover, prover);
            parentHash = codec.hashTransition(transitions_[i]);
        }

        input_.transitions = transitions_;
        input_.syncCheckpoint = _syncCheckpoint;
    }

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _proveAndDecodeWithGas(
        IInbox.ProveInput memory _input,
        string memory _profile,
        string memory _benchName
    )
        internal
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        bytes memory encodedInput = codec.encodeProveInput(_input);
        vm.recordLogs();
        vm.startPrank(prover);
        vm.startSnapshotGas(_profile, _benchName);
        inbox.prove(encodedInput, bytes(""));
        vm.stopSnapshotGas();
        vm.stopPrank();
        payload_ = _readProvedEvent();
    }

    function _readProvedEvent() private returns (IInbox.ProvedEventPayload memory payload_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 provedTopic = keccak256("Proved(bytes)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == provedTopic) {
                bytes memory payload = abi.decode(logs[i].data, (bytes));
                return codec.decodeProvedEvent(payload);
            }
        }
        revert("Proved event not found");
    }
}
