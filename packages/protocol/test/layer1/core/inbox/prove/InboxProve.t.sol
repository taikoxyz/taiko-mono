// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { InboxOptimizedBase, InboxSimpleBase, InboxTestBase } from "../common/InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { LibProveInputDecoder } from "src/layer1/core/libs/LibProveInputDecoder.sol";
import { Vm } from "forge-std/src/Vm.sol";

abstract contract ProveTestBase is InboxTestBase {
    function test_prove_single_finalizes() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(bytes32(uint256(123)));

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: _hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: checkpoint
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            metadata: _metadata(prover, prover),
            checkpoint: checkpoint
        });

        vm.prank(prover);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proposed.proposal.id, "finalized id");
        assertEq(state.lastFinalizedTransitionHash, _hashTransition(transition), "transition hash");
        assertEq(state.bondInstructionsHash, bytes32(0), "bond hash");

        ICheckpointStore.Checkpoint memory saved = checkpointStore.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash, "checkpoint hash");
        assertEq(saved.stateRoot, checkpoint.stateRoot, "checkpoint root");
    }

    function test_prove_RevertWhen_EmptyProposals() public {
        IInbox.ProveInput memory emptyInput = IInbox.ProveInput({
            proposals: new IInbox.Proposal[](0),
            transitions: new IInbox.Transition[](0),
            metadata: new IInbox.TransitionMetadata[](0),
            checkpoint: _checkpoint(bytes32(uint256(1)))
        });

        vm.expectRevert(Inbox.EmptyProposals.selector);
        inbox.prove(_encodeProveInput(emptyInput), bytes(""));
    }

    function test_prove_RevertWhen_SkippingProposal() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Proposal memory wrong = proposed.proposal;
        wrong.id = proposed.proposal.id + 1;

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: _hashProposal(wrong),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: _checkpoint(bytes32(uint256(1)))
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(wrong),
            transitions: _transitions(transition),
            metadata: _metadata(prover, prover),
            checkpoint: transition.checkpoint
        });

        vm.prank(prover);
        vm.expectRevert(Inbox.InvalidProposalId.selector);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
    }

    function test_prove_RevertWhen_ParentMismatch() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        IInbox.Transition memory t1 = _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)));
        IInbox.Transition memory t2 = _transitionFor(p2, bytes32(uint256(999)), bytes32(uint256(2)));

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal),
            transitions: _transitions(t1, t2),
            metadata: _metadata(prover, prover, prover, prover),
            checkpoint: t2.checkpoint
        });

        vm.prank(prover);
        vm.expectRevert(Inbox.InvalidParentTransition.selector);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
    }

    function test_prove_RevertWhen_LengthMismatch() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();
        IInbox.Transition memory transition = _transitionFor(
            proposed, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1))
        );

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: new IInbox.Transition[](0),
            metadata: new IInbox.TransitionMetadata[](0),
            checkpoint: transition.checkpoint
        });

        bytes4 selector = _isOptimized()
            ? LibProveInputDecoder.ProposalTransitionLengthMismatch.selector
            : Inbox.InconsistentParams.selector;

        if (_isOptimized()) {
            vm.expectRevert(selector);
            this._encodeOptimizedProveInput(proveInput);
        } else {
            vm.expectRevert(selector);
            inbox.prove(_encodeProveInput(proveInput), bytes(""));
        }
    }

    function _callProve(bytes memory _data) external {
        inbox.prove(_data, bytes(""));
    }

    function _encodeOptimizedProveInput(IInbox.ProveInput memory _input)
        external
        returns (bytes memory)
    {
        return LibProveInputDecoder.encode(_input);
    }

    function test_prove_RevertWhen_CheckpointMismatch() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();
        IInbox.Transition memory transition = _transitionFor(
            proposed, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1))
        );

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            metadata: _metadata(prover, prover),
            checkpoint: _checkpoint(bytes32(uint256(999))) // wrong checkpoint hash
        });

        vm.expectRevert(Inbox.CheckpointMismatch.selector);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
    }

    function test_prove_batch_updatesBondHash() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        vm.warp(block.timestamp + 10 days);

        IInbox.Transition memory t1 = _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)));
        IInbox.Transition memory t2 = _transitionFor(p2, _hashTransition(t1), bytes32(uint256(2)));

        IInbox.TransitionMetadata[] memory metadata = _metadata(
            p1.proposal.proposer,
            prover,
            p2.proposal.proposer,
            prover
        );

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal),
            transitions: _transitions(t1, t2),
            metadata: metadata,
            checkpoint: t2.checkpoint
        });

        vm.prank(prover);
        inbox.prove(_encodeProveInput(proveInput), bytes(""));

        IInbox.CoreState memory state = inbox.getState();
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: p1.proposal.proposer,
            payee: prover
        });
        bytes32 expectedHash = LibBonds.aggregateBondInstruction(bytes32(0), expectedInstruction);
        assertEq(state.bondInstructionsHash, expectedHash, "bond hash");
        assertEq(state.lastFinalizedProposalId, p2.proposal.id, "finalized span");
    }

    function test_prove_lateWithinExtendedWindow_emitsLivenessBondInstruction() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Make the proof late but still inside the extended proving window.
        vm.warp(block.timestamp + config.provingWindow + 1);

        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(bytes32(uint256(1)));
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: _hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: checkpoint
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            metadata: _metadata(proposer, prover), // designated proposer, different prover
            checkpoint: checkpoint
        });

        IInbox.ProvedEventPayload memory provedPayload = _proveAndDecode(proveInput);

        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 expectedHash = LibBonds.aggregateBondInstruction(bytes32(0), expectedInstruction);
        assertEq(inbox.getState().bondInstructionsHash, expectedHash, "bond hash");
        assertEq(provedPayload.transitionRecord.bondInstructions.length, 1, "bond instruction count");

        LibBonds.BondInstruction memory instruction = provedPayload.transitionRecord.bondInstructions[0];
        assertEq(uint8(instruction.bondType), uint8(LibBonds.BondType.LIVENESS), "bond type");
        assertEq(instruction.payer, proposer, "payer");
        assertEq(instruction.payee, prover, "payee");
    }

    function _proposeOne() internal returns (IInbox.ProposedEventPayload memory payload_) {
        _setBlobHashes(3);
        payload_ = _proposeAndDecode(_defaultProposeInput());
    }

    function _checkpoint(bytes32 _stateRoot) internal view returns (ICheckpointStore.Checkpoint memory) {
        return ICheckpointStore.Checkpoint({
            blockNumber: uint48(block.number),
            blockHash: blockhash(block.number - 1),
            stateRoot: _stateRoot
        });
    }

    function _transitionFor(
        IInbox.ProposedEventPayload memory _proposal,
        bytes32 _parentTransitionHash,
        bytes32 _stateRoot
    )
        internal
        view
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _hashProposal(_proposal.proposal),
            parentTransitionHash: _parentTransitionHash,
            checkpoint: _checkpoint(_stateRoot)
        });
    }

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _proveAndDecode(IInbox.ProveInput memory _input)
        internal
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        vm.recordLogs();
        vm.prank(prover);
        inbox.prove(_encodeProveInput(_input), bytes(""));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 provedTopic = keccak256("Proved(bytes)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == provedTopic) {
                bytes memory payload = abi.decode(logs[i].data, (bytes));
                return _decodeProvedEvent(payload);
            }
        }
        revert("Proved event not found");
    }
}

contract InboxProveTest is ProveTestBase, InboxSimpleBase { }

contract InboxOptimizedProveTest is ProveTestBase, InboxOptimizedBase {
    function _isOptimized() internal view override(InboxOptimizedBase, InboxTestBase) returns (bool) {
        return true;
    }
}
