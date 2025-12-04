// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { InboxTestBase, InboxVariant } from "../common/InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { LibProveInputDecoder } from "src/layer1/core/libs/LibProveInputDecoder.sol";
import { Vm } from "forge-std/src/Vm.sol";

abstract contract ProveTestBase is InboxTestBase {
    constructor(InboxVariant _variant) InboxTestBase(_variant) { }

    function test_prove_single_finalizes() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(bytes32(uint256(123)));

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: codec.hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: checkpoint,
            designatedProver: prover,
            actualProver: prover
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            syncCheckpoint: true
        });

        uint256 snap = vm.snapshot();
        _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_single");

        bool reverted = vm.revertTo(snap);
        assertTrue(reverted, "revertTo snapshot");
        IInbox.ProvedEventPayload memory provedPayload =
            _proveAndDecodeWithGas(proveInput, "shasta-finalize", "finalize_single");
        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proposed.proposal.id, "finalized id");
        assertEq(state.lastFinalizedTransitionHash, codec.hashTransition(transition), "transition hash");
        assertEq(uint8(provedPayload.bondInstruction.bondType), uint8(LibBonds.BondType.NONE), "bond type");
        assertEq(provedPayload.bondSignal, bytes32(0), "bond signal");

        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash, "checkpoint hash");
        assertEq(saved.stateRoot, checkpoint.stateRoot, "checkpoint root");
    }

    function test_prove_RevertWhen_EmptyProposals() public {
        IInbox.ProveInput memory emptyInput = IInbox.ProveInput({
            proposals: new IInbox.Proposal[](0),
            transitions: new IInbox.Transition[](0),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(emptyInput);
        vm.expectRevert(Inbox.EmptyProposals.selector);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_RevertWhen_SkippingProposal() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Proposal memory wrong = proposed.proposal;
        wrong.id = proposed.proposal.id + 1;

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: codec.hashProposal(wrong),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: _checkpoint(bytes32(uint256(1))),
            designatedProver: prover,
            actualProver: prover
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(wrong),
            transitions: _transitions(transition),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.InvalidProposalId.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_RevertWhen_ParentMismatch() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        IInbox.Transition memory t1 =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover);
        IInbox.Transition memory t2 =
            _transitionFor(p2, bytes32(uint256(999)), bytes32(uint256(2)), prover, prover);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal),
            transitions: _transitions(t1, t2),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.InvalidParentTransition.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_RevertWhen_LengthMismatch() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: new IInbox.Transition[](0),
            syncCheckpoint: true
        });

        if (_isOptimized()) {
            vm.expectRevert(LibProveInputDecoder.ProposalTransitionLengthMismatch.selector);
            codec.encodeProveInput(proveInput);
            return;
        }
        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.InconsistentParams.selector);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_RevertWhen_CheckpointMismatch() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();
        IInbox.Transition memory transition = _transitionFor(
            proposed, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );
        transition.checkpoint.blockHash = bytes32(0);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.CheckpointMismatch.selector);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_batch_emitsBondSignal() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        vm.warp(block.timestamp + 10 days);

        IInbox.Transition memory t1 =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover);
        IInbox.Transition memory t2 =
            _transitionFor(p2, codec.hashTransition(t1), bytes32(uint256(2)), prover, prover);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal),
            transitions: _transitions(t1, t2),
            syncCheckpoint: true
        });

        IInbox.ProvedEventPayload memory provedPayload = _proveAndDecode(proveInput);

        IInbox.CoreState memory state = inbox.getState();
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: p1.proposal.proposer,
            payee: prover
        });
        bytes32 expectedSignal = _bondSignal(expectedInstruction);
        assertEq(state.lastFinalizedProposalId, p2.proposal.id, "finalized span");
        assertEq(provedPayload.bondSignal, expectedSignal, "bond signal");
        assertEq(
            uint8(provedPayload.bondInstruction.bondType),
            uint8(LibBonds.BondType.PROVABILITY),
            "bond type"
        );
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "signal sent");
        assertEq(provedPayload.bondInstruction.payer, expectedInstruction.payer, "payer");
        assertEq(provedPayload.bondInstruction.payee, expectedInstruction.payee, "payee");
    }

    function test_prove_lateWithinExtendedWindow_emitsLivenessBondSignal() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Make the proof late but still inside the extended proving window.
        vm.warp(block.timestamp + config.provingWindow + 1);

        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(bytes32(uint256(1)));
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: codec.hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: checkpoint,
            designatedProver: proposer,
            actualProver: prover
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            syncCheckpoint: true
        });

        IInbox.ProvedEventPayload memory provedPayload = _proveAndDecode(proveInput);

        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 expectedSignal = _bondSignal(expectedInstruction);
        assertEq(provedPayload.bondSignal, expectedSignal, "bond signal");
        assertEq(uint8(provedPayload.bondInstruction.bondType), uint8(LibBonds.BondType.LIVENESS), "bond type");
        assertEq(provedPayload.bondInstruction.payer, proposer, "payer");
        assertEq(provedPayload.bondInstruction.payee, prover, "payee");
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "signal recorded");
    }

    /// forge-config: default.isolate = true
    function test_prove_batch3_recordsGasAndFinalizes() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        IInbox.Transition memory t1 =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover);
        IInbox.Transition memory t2 =
            _transitionFor(p2, codec.hashTransition(t1), bytes32(uint256(2)), prover, prover);
        IInbox.Transition memory t3 =
            _transitionFor(p3, codec.hashTransition(t2), bytes32(uint256(3)), prover, prover);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal, p3.proposal),
            transitions: _transitions(t1, t2, t3),
            syncCheckpoint: true
        });

        IInbox.ProvedEventPayload memory proved =
            _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, p3.proposal.id, "finalized id");
        assertEq(proved.bondSignal, bytes32(0), "bond signal");
        assertEq(uint8(proved.bondInstruction.bondType), uint8(LibBonds.BondType.NONE), "bond type");
    }

    /// forge-config: default.isolate = true
    function test_prove_batch5_recordsGasAndFinalizes() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p4 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p5 = _proposeOne();

        IInbox.Transition memory t1 =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover);
        IInbox.Transition memory t2 =
            _transitionFor(p2, codec.hashTransition(t1), bytes32(uint256(2)), prover, prover);
        IInbox.Transition memory t3 =
            _transitionFor(p3, codec.hashTransition(t2), bytes32(uint256(3)), prover, prover);
        IInbox.Transition memory t4 =
            _transitionFor(p4, codec.hashTransition(t3), bytes32(uint256(4)), prover, prover);
        IInbox.Transition memory t5 =
            _transitionFor(p5, codec.hashTransition(t4), bytes32(uint256(5)), prover, prover);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal, p3.proposal, p4.proposal, p5.proposal),
            transitions: _transitions(t1, t2, t3, t4, t5),
            syncCheckpoint: true
        });

        IInbox.ProvedEventPayload memory proved =
            _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, p5.proposal.id, "finalized id");
        assertEq(proved.bondSignal, bytes32(0), "bond signal");
        assertEq(uint8(proved.bondInstruction.bondType), uint8(LibBonds.BondType.NONE), "bond type");
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        IInbox.Transition memory t1 =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover);
        IInbox.Transition memory t2 =
            _transitionFor(p2, codec.hashTransition(t1), bytes32(uint256(2)), prover, prover);
        IInbox.Transition memory t3 =
            _transitionFor(p3, codec.hashTransition(t2), bytes32(uint256(3)), prover, prover);

        IInbox.ProveInput memory prefixInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal),
            transitions: _transitions(t1),
            syncCheckpoint: true
        });
        _proveAndDecode(prefixInput);

        IInbox.ProveInput memory fullInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal, p3.proposal),
            transitions: _transitions(t1, t2, t3),
            syncCheckpoint: true
        });

        IInbox.ProvedEventPayload memory provedPayload = _proveAndDecode(fullInput);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, p3.proposal.id, "finalized id");
        assertEq(state.lastFinalizedTransitionHash, codec.hashTransition(t3), "transition hash");
        assertEq(provedPayload.proposalId, p2.proposal.id, "proved proposal id");
        assertEq(provedPayload.transition.proposalHash, codec.hashProposal(p2.proposal), "proved proposal hash");
        assertEq(provedPayload.transition.parentTransitionHash, codec.hashTransition(t1), "proved parent hash");
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        IInbox.Transition memory t1 =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover);
        IInbox.ProveInput memory prefixInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal),
            transitions: _transitions(t1),
            syncCheckpoint: true
        });
        _proveAndDecode(prefixInput);

        IInbox.Transition memory wrongPrefix =
            _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(999)), prover, prover);
        IInbox.Transition memory t2 =
            _transitionFor(p2, codec.hashTransition(wrongPrefix), bytes32(uint256(2)), prover, prover);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal),
            transitions: _transitions(wrongPrefix, t2),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.InvalidProposalId.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
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

    function _bondSignal(LibBonds.BondInstruction memory _instruction) internal pure returns (bytes32) {
        return keccak256(abi.encode(_instruction));
    }

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _proveAndDecode(IInbox.ProveInput memory _input)
        internal
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        bytes memory encodedInput = codec.encodeProveInput(_input);
        vm.recordLogs();
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
        payload_ = _readProvedEvent();
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
        vm.startSnapshotGas(_profile, _benchLabel(_benchName));
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

contract InboxProveTest is ProveTestBase {
    constructor() ProveTestBase(InboxVariant.Simple) { }
}

contract InboxOptimizedProveTest is ProveTestBase {
    constructor() ProveTestBase(InboxVariant.Optimized) { }
}

abstract contract RingBufferTestBase is ProveTestBase {
    constructor(InboxVariant _variant) ProveTestBase(_variant) { }

    function _buildConfig() internal override returns (IInbox.Config memory cfg) {
        cfg = super._buildConfig();
        cfg.ringBufferSize = 6;
        return cfg;
    }

    function test_ringBuffer_reuse_after_finalization_recordsGas() public {
        _setBlobHashes(6);
        IInbox.ProposedEventPayload memory p1 = _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        IInbox.ProposedEventPayload memory p5 = _proposeAndDecode(_defaultProposeInput());

        IInbox.Transition memory t1 = _transitionFor(
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal),
            transitions: _transitions(t1),
            syncCheckpoint: true
        });

        _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_after_ring_buffer_fill");

        _advanceBlock();
        IInbox.ProposedEventPayload memory p6 =
            _proposeAndDecodeWithGas(_defaultProposeInput(), "propose_after_ring_buffer_wrap");

        assertEq(p6.proposal.id, p5.proposal.id + 1, "proposal id");
        assertEq(inbox.getProposalHash(p6.proposal.id), codec.hashProposal(p6.proposal), "proposal hash");
    }
}

contract InboxRingBufferProveTest is RingBufferTestBase {
    constructor() RingBufferTestBase(InboxVariant.Simple) { }
}

contract InboxOptimizedRingBufferProveTest is RingBufferTestBase {
    constructor() RingBufferTestBase(InboxVariant.Optimized) { }
}
