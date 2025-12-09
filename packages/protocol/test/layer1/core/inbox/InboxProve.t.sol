// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibProveInputCodec } from "src/layer1/core/libs/LibProveInputCodec.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract InboxProveTest is InboxTestBase {
    function test_prove_single() public {
        (IInbox.ProveInput memory proveInput, IInbox.Transition[] memory transitions) =
            _buildBatchInput(1, false);

        IInbox.ProvedEventPayload memory provedPayload =
            _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_single");
        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[0].id, "finalized id");
        assertEq(
            state.lastFinalizedTransitionHash,
            codec.hashTransition(transitions[0]),
            "transition hash"
        );
        assertEq(
            uint8(provedPayload.bondInstruction.bondType),
            uint8(LibBonds.BondType.NONE),
            "bond type"
        );
        assertEq(provedPayload.bondSignal, bytes32(0), "bond signal");

        assertEq(inbox.getState().lastCheckpointTimestamp, 0, "checkpoint timestamp unchanged");
    }

    function test_prove_batch3() public {
        (IInbox.ProveInput memory proveInput,) = _buildBatchInput(3, false);

        IInbox.ProvedEventPayload memory proved =
            _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[2].id, "finalized id");
        assertEq(proved.bondSignal, bytes32(0), "bond signal");
        assertEq(uint8(proved.bondInstruction.bondType), uint8(LibBonds.BondType.NONE), "bond type");
    }

    function test_prove_batch5() public {
        (IInbox.ProveInput memory proveInput,) = _buildBatchInput(5, false);

        IInbox.ProvedEventPayload memory proved =
            _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[4].id, "finalized id");
        assertEq(proved.bondSignal, bytes32(0), "bond signal");
        assertEq(uint8(proved.bondInstruction.bondType), uint8(LibBonds.BondType.NONE), "bond type");
    }

    function test_prove_batch10() public {
        (IInbox.ProveInput memory proveInput,) = _buildBatchInput(10, false);

        IInbox.ProvedEventPayload memory proved =
            _proveAndDecodeWithGas(proveInput, "shasta-prove", "prove_consecutive_10");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, proveInput.proposals[9].id, "finalized id");
        assertEq(proved.bondSignal, bytes32(0), "bond signal");
        assertEq(uint8(proved.bondInstruction.bondType), uint8(LibBonds.BondType.NONE), "bond type");
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

        IInbox.Transition memory t1 = _transitionFor(
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );
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

        vm.expectRevert(LibProveInputCodec.ProposalTransitionLengthMismatch.selector);
        codec.encodeProveInput(proveInput);
    }

    function test_prove_RevertWhen_CheckpointMismatch() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();
        IInbox.Transition memory transition = _transitionFor(
            proposed,
            inbox.getState().lastFinalizedTransitionHash,
            bytes32(uint256(1)),
            prover,
            prover
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

    function test_prove_RevertWhen_ProposalHashMismatch() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Proposal memory tampered = proposed.proposal;
        tampered.timestamp += 1;

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: codec.hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: _checkpoint(bytes32(uint256(1))),
            designatedProver: prover,
            actualProver: prover
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(tampered),
            transitions: _transitions(transition),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.ProposalHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_RevertWhen_ProposalHashMismatchWithTransition() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: bytes32(uint256(123)),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: _checkpoint(bytes32(uint256(1))),
            designatedProver: prover,
            actualProver: prover
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            syncCheckpoint: true
        });

        bytes memory encodedInput = codec.encodeProveInput(proveInput);
        vm.expectRevert(Inbox.ProposalHashMismatchWithTransition.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes(""));
    }

    function test_prove_batch_emitsBondSignal() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        vm.warp(block.timestamp + 10 days);

        IInbox.Transition memory t1 = _transitionFor(
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );
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
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
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
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
        assertEq(provedPayload.bondSignal, expectedSignal, "bond signal");
        assertEq(
            uint8(provedPayload.bondInstruction.bondType),
            uint8(LibBonds.BondType.LIVENESS),
            "bond type"
        );
        assertEq(provedPayload.bondInstruction.payer, proposer, "payer");
        assertEq(provedPayload.bondInstruction.payee, prover, "payee");
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "signal recorded");
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        IInbox.Transition memory t1 = _transitionFor(
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );
        IInbox.Transition memory t2 =
            _transitionFor(p2, codec.hashTransition(t1), bytes32(uint256(2)), prover, prover);
        IInbox.Transition memory t3 =
            _transitionFor(p3, codec.hashTransition(t2), bytes32(uint256(3)), prover, prover);

        IInbox.ProveInput memory prefixInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal), transitions: _transitions(t1), syncCheckpoint: true
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
        assertEq(
            provedPayload.transition.proposalHash,
            codec.hashProposal(p2.proposal),
            "proved proposal hash"
        );
        assertEq(
            provedPayload.transition.parentTransitionHash,
            codec.hashTransition(t1),
            "proved parent hash"
        );
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        IInbox.Transition memory t1 = _transitionFor(
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
        );
        IInbox.ProveInput memory prefixInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal), transitions: _transitions(t1), syncCheckpoint: true
        });
        _proveAndDecode(prefixInput);

        IInbox.Transition memory wrongPrefix = _transitionFor(
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(999)), prover, prover
        );
        IInbox.Transition memory t2 = _transitionFor(
            p2, codec.hashTransition(wrongPrefix), bytes32(uint256(2)), prover, prover
        );

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
}
