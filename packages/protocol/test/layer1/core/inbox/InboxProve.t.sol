// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract InboxProveTest is InboxTestBase {
    // ---------------------------------------------------------------------
    // Happy paths
    // ---------------------------------------------------------------------
    function test_prove_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _proveWithGas(input, "shasta-prove", "prove_single");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash, input.transitions[0].checkpointHash, "checkpoint"
        );
    }

    function test_prove_batch2() public {
        IInbox.ProveInput memory input = _buildBatchInput(2);

        _proveWithGas(input, "shasta-prove", "prove_batch_2");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 1, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash,
            input.transitions[1].checkpointHash,
            "checkpoint hash"
        );
    }

    function test_prove_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        _proveWithGas(input, "shasta-prove", "prove_batch_3");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 2, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash,
            input.transitions[2].checkpointHash,
            "checkpoint hash"
        );
    }

    function test_prove_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        _proveWithGas(input, "shasta-prove", "prove_batch_5");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 4, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash,
            input.transitions[4].checkpointHash,
            "checkpoint hash"
        );
    }

    function test_prove_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        _proveWithGas(input, "shasta-prove", "prove_batch_10");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 9, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash,
            input.transitions[9].checkpointHash,
            "checkpoint hash"
        );
    }

    // ---------------------------------------------------------------------
    // Bounds and validation
    // ---------------------------------------------------------------------
    function test_prove_RevertWhen_EmptyBatch() public {
        IInbox.ProveInput memory emptyInput = _buildInput(
            1,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            new IInbox.Transition[](0),
            bytes32(0)
        );

        bytes memory encodedInput = codec.encodeProveInput(emptyInput);
        vm.expectRevert(Inbox.EmptyBatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_FirstProposalIdTooLarge() public {
        IInbox.ProposedEventPayload memory payload = _proposeOne();

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, keccak256("checkpoint1"));

        IInbox.ProveInput memory input = _buildInput(
            payload.proposal.id + 1,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.FirstProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_LastProposalIdTooLarge() public {
        IInbox.ProposedEventPayload memory payload = _proposeOne();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(payload, prover, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(payload, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            payload.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_ParentCheckpointHashMismatch() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, prover, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input =
            _buildInput(1, bytes32(uint256(999)), transitions, keccak256("stateRoot"));

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ParentCheckpointHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        bytes32 p1Checkpoint = keccak256("checkpoint1");
        IInbox.Transition[] memory firstBatch = _transitionArrayFor(p1, p1Checkpoint);

        IInbox.ProveInput memory firstInput = _buildInput(
            p1.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            firstBatch,
            keccak256("stateRoot1")
        );
        _prove(firstInput);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, p1.proposal.id, "p1 finalized");

        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](3);
        fullBatch[0] = _transitionFor(p1, prover, p1Checkpoint);
        fullBatch[1] = _transitionFor(p2, prover, keccak256("checkpoint2"));
        fullBatch[2] = _transitionFor(p3, prover, keccak256("checkpoint3"));

        IInbox.ProveInput memory fullInput =
            _buildInput(p1.proposal.id, bytes32(0), fullBatch, keccak256("stateRoot3"));
        _prove(fullInput);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, p3.proposal.id, "finalized id");
        assertEq(state.lastFinalizedCheckpointHash, fullBatch[2].checkpointHash, "checkpoint hash");
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        bytes32 p1Checkpoint = keccak256("checkpoint1");
        IInbox.Transition[] memory firstBatch = _transitionArrayFor(p1, p1Checkpoint);

        IInbox.ProveInput memory firstInput = _buildInput(
            p1.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            firstBatch,
            keccak256("stateRoot1")
        );
        _prove(firstInput);

        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](2);
        fullBatch[0] = _transitionFor(p1, prover, keccak256("wrongCheckpoint"));
        fullBatch[1] = _transitionFor(p2, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory fullInput =
            _buildInput(p1.proposal.id, bytes32(0), fullBatch, keccak256("stateRoot2"));

        bytes memory encodedInput = codec.encodeProveInput(fullInput);
        vm.expectRevert(Inbox.ParentCheckpointHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Bond signalling
    // ---------------------------------------------------------------------
    function test_prove_emitsBondSignal_afterExtendedWindow() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        vm.warp(block.timestamp + config.extendedProvingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, prover, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            p1.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: p1.proposal.proposer,
            payee: prover
        });
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "bond signal sent");
    }

    function test_prove_emitsLivenessBond_withinExtendedWindow() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposal.proposer,
            designatedProver: proposer, // different from actual prover
            timestamp: p1.proposal.timestamp,
            checkpointHash: keccak256("checkpoint1")
        });
        transitions[1] = _transitionFor(p2, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            p1.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), expectedSignal), "liveness bond signal"
        );
    }

    function test_prove_noBondSignal_withinProvingWindow() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _prove(input);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: input.firstProposalId,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);

        instruction.bondType = LibBonds.BondType.PROVABILITY;
        bytes32 provabilitySignal = codec.hashBondInstruction(instruction);

        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal), "no liveness signal"
        );
        assertFalse(
            signalService.isSignalSent(address(inbox), provabilitySignal), "no provability signal"
        );
    }

    function test_prove_noBondSignal_whenPayerEqualsPayee() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();
        vm.warp(proposed.proposal.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(proposed, keccak256("checkpoint"));

        // designatedProver == actualProver so payer == payee
        transitions[0].designatedProver = prover;

        IInbox.ProveInput memory input = _buildInput(
            proposed.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: prover,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);

        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "no liveness signal when payer==payee"
        );
    }

    // ---------------------------------------------------------------------
    // Boundary Tests - prove() conditions
    // ---------------------------------------------------------------------
    function test_prove_succeedsWhen_FirstProposalIdAtExactBoundary() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);
        assertEq(input.firstProposalId, 1, "firstProposalId should be 1");
        assertEq(
            inbox.getCoreState().lastFinalizedProposalId, 0, "lastFinalizedProposalId should be 0"
        );

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    function test_prove_succeedsWhen_LastProposalIdAtExactBoundary() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        assertEq(inbox.getCoreState().nextProposalId, input.firstProposalId + 1, "nextProposalId");

        uint256 lastProposalId = input.firstProposalId + input.transitions.length - 1;
        assertEq(lastProposalId, 1, "lastProposalId at exact boundary");

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    function test_prove_RevertWhen_LastProposalIdEqualsNextProposalId() public {
        IInbox.ProposedEventPayload memory payload = _proposeOne(); // id = 1, nextProposalId = 2

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(payload, prover, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(payload, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            payload.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Boundary Tests - Bond instruction timing
    // ---------------------------------------------------------------------
    function test_prove_noBondSignal_atExactProvingWindowBoundary() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        vm.warp(proposed.proposal.timestamp + config.provingWindow);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(proposed, keccak256("checkpoint"));
        transitions[0].designatedProver = proposer; // Different from actual to exercise bond path

        IInbox.ProveInput memory input = _buildInput(
            proposed.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "no liveness at exact provingWindow"
        );
    }

    function test_prove_livenessBond_oneSecondPastProvingWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        vm.warp(proposed.proposal.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(proposed, keccak256("checkpoint"));
        transitions[0].designatedProver = proposer;

        IInbox.ProveInput memory input = _buildInput(
            proposed.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "liveness bond 1 sec past window"
        );
    }

    function test_prove_livenessBond_atExactExtendedWindowBoundary() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        vm.warp(proposed.proposal.timestamp + config.extendedProvingWindow);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(proposed, keccak256("checkpoint"));
        transitions[0].designatedProver = proposer;

        IInbox.ProveInput memory input = _buildInput(
            proposed.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "liveness at exact extended window"
        );
    }

    function test_prove_provabilityBond_oneSecondPastExtendedWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        vm.warp(proposed.proposal.timestamp + config.extendedProvingWindow + 1);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(proposed, keccak256("checkpoint"));
        transitions[0].designatedProver = proposer;

        IInbox.ProveInput memory input = _buildInput(
            proposed.proposal.id,
            inbox.getCoreState().lastFinalizedCheckpointHash,
            transitions,
            keccak256("stateRoot")
        );

        _prove(input);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: proposed.proposal.proposer,
            payee: prover
        });
        bytes32 provabilitySignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), provabilitySignal),
            "provability 1 sec past extended"
        );
    }

    // ---------------------------------------------------------------------
    // Checkpoint handling
    // ---------------------------------------------------------------------
    function test_prove_noCheckpointSync_beforeDelay() public {
        // Provide empty lastCheckpoint to avoid syncing
        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: inbox.getCoreState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: _transitionArrayFor(_proposeOne(), keccak256("checkpoint")),
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: 0, stateRoot: 0
            })
        });

        _prove(input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        assertEq(state.lastCheckpointTimestamp, 0, "checkpoint timestamp unchanged");
    }

    function test_prove_checkpointSyncsAfterDelay() public {
        // First prove without checkpoint sync
        IInbox.ProveInput memory input1 = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: inbox.getCoreState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: _transitionArrayFor(_proposeOne(), keccak256("checkpoint1")),
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: 0, stateRoot: 0
            })
        });
        _prove(input1);

        uint48 checkpointBefore = inbox.getCoreState().lastCheckpointTimestamp;
        assertEq(checkpointBefore, 0, "checkpoint not synced initially");

        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        IInbox.Transition[] memory transitions = _transitionArrayFor(p2, keccak256("checkpoint2"));

        IInbox.ProveInput memory input2 = IInbox.ProveInput({
            firstProposalId: p2.proposal.id,
            firstProposalParentCheckpointHash: inbox.getCoreState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot2")
            })
        });

        _prove(input2);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint synced");
    }

    function test_prove_RevertWhen_CheckpointMissingAfterDelay() public {
        IInbox.ProveInput memory firstInput = _buildBatchInput(1);
        _prove(firstInput);

        uint48 checkpointTimestamp = inbox.getCoreState().lastCheckpointTimestamp;

        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        vm.warp(uint256(checkpointTimestamp) + config.minCheckpointDelay + 1);

        IInbox.Transition[] memory transitions = _transitionArrayFor(p2, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: p2.proposal.id,
            firstProposalParentCheckpointHash: inbox.getCoreState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: 0, stateRoot: 0
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.CheckPointDelayHasPassed.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------
    function _buildInput(
        uint48 _firstProposalId,
        bytes32 _parentCheckpointHash,
        IInbox.Transition[] memory _transitions,
        bytes32 _stateRoot
    )
        internal
        view
        returns (IInbox.ProveInput memory)
    {
        bytes32 lastCheckpointHash = _transitions.length == 0
            ? bytes32(0)
            : _transitions[_transitions.length - 1].checkpointHash;

        return IInbox.ProveInput({
            firstProposalId: _firstProposalId,
            firstProposalParentCheckpointHash: _parentCheckpointHash,
            actualProver: prover,
            transitions: _transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: lastCheckpointHash,
                stateRoot: _stateRoot
            })
        });
    }

    function _transitionArrayFor(
        IInbox.ProposedEventPayload memory _payload,
        bytes32 _checkpointHash
    )
        internal
        view
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](1);
        transitions_[0] = _transitionFor(_payload, prover, _checkpointHash);
    }
}
