// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract InboxProveTest is InboxTestBase {
    function test_prove_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _proveWithGas(input, "shasta-prove", "prove_single");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash, input.transitions[0].checkpointHash, "checkpoint hash"
        );
    }

    function test_prove_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        _proveWithGas(input, "shasta-prove", "prove_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 2, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash, input.transitions[2].checkpointHash, "checkpoint hash"
        );
    }

    function test_prove_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        _proveWithGas(input, "shasta-prove", "prove_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 4, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash, input.transitions[4].checkpointHash, "checkpoint hash"
        );
    }

    function test_prove_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        _proveWithGas(input, "shasta-prove", "prove_consecutive_10");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 9, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash, input.transitions[9].checkpointHash, "checkpoint hash"
        );
    }

    function test_prove_RevertWhen_EmptyBatch() public {
        IInbox.ProveInput memory emptyInput = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: new IInbox.Transition[](0),
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0,
                blockHash: bytes32(0),
                stateRoot: bytes32(0)
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(emptyInput);
        vm.expectRevert(Inbox.EmptyBatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_FirstProposalIdTooLarge() public {
        // Propose one block
        _proposeOne();

        // Try to prove starting from proposal 2 (which would skip proposal 1)
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 2, // lastFinalizedProposalId is 0, so max allowed is 1
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: bytes32(uint256(1))
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.FirstProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_LastProposalIdTooLarge() public {
        // Propose one block (id = 1)
        _proposeOne();

        // Try to prove proposals 1 and 2 when only 1 exists
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            checkpointHash: keccak256("checkpointHash1")
        });
        transitions[1] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            checkpointHash: keccak256("checkpointHash2")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[1].checkpointHash,
                stateRoot: bytes32(uint256(1))
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_ParentCheckpointHashMismatch() public {
        _proposeOne();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: bytes32(uint256(999)), // Wrong parent hash
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: bytes32(uint256(1))
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ParentCheckpointHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_emitsBondSignal_afterProvingWindow() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // Move past the extended proving window to trigger PROVABILITY bond
        vm.warp(block.timestamp + config.extendedProvingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, prover, keccak256("checkpointHash1"));
        transitions[1] = _transitionFor(p2, prover, keccak256("checkpointHash2"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[1].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // Verify bond signal was sent for PROVABILITY
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
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Move past proving window but still within extended window
        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        // Different designated prover than actual prover to trigger liveness bond
        transitions[0] = IInbox.Transition({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from prover
            timestamp: proposed.proposal.timestamp,
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // Verify bond signal was sent for LIVENESS
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver pays
            payee: prover // actualProver receives
        });
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), expectedSignal), "liveness bond signal"
        );
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
        // Propose 3 blocks
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        // First, prove just p1
        IInbox.Transition[] memory firstBatch = new IInbox.Transition[](1);
        bytes32 p1CheckpointHash = keccak256("checkpointHash1");
        firstBatch[0] = _transitionFor(p1, prover, p1CheckpointHash);

        IInbox.ProveInput memory firstInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: firstBatch,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: p1CheckpointHash,
                stateRoot: keccak256("stateRoot1")
            })
        });

        _prove(firstInput);

        assertEq(inbox.getState().lastFinalizedProposalId, p1.proposal.id, "p1 finalized");

        // Now prove p1, p2, p3 (p1 already finalized - should be skipped)
        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](3);
        fullBatch[0] = _transitionFor(p1, prover, p1CheckpointHash);
        fullBatch[1] = _transitionFor(p2, prover, keccak256("checkpointHash2"));
        fullBatch[2] = _transitionFor(p3, prover, keccak256("checkpointHash3"));

        IInbox.ProveInput memory fullInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentCheckpointHash: bytes32(0), // Ignored since offset > 0
            actualProver: prover,
            transitions: fullBatch,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: fullBatch[2].checkpointHash,
                stateRoot: keccak256("stateRoot3")
            })
        });

        _prove(fullInput);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, p3.proposal.id, "finalized id");
        assertEq(
            state.lastFinalizedCheckpointHash, fullBatch[2].checkpointHash, "checkpoint hash"
        );
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        // Propose 2 blocks
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // First, prove p1
        bytes32 p1CheckpointHash = keccak256("checkpointHash1");
        IInbox.Transition[] memory firstBatch = new IInbox.Transition[](1);
        firstBatch[0] = _transitionFor(p1, prover, p1CheckpointHash);

        IInbox.ProveInput memory firstInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: firstBatch,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: p1CheckpointHash,
                stateRoot: keccak256("stateRoot1")
            })
        });

        _prove(firstInput);

        // Try to prove p1, p2 with wrong p1 block hash (doesn't match finalized)
        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](2);
        fullBatch[0] = _transitionFor(p1, prover, keccak256("wrongCheckpointHash")); // Wrong!
        fullBatch[1] = _transitionFor(p2, prover, keccak256("checkpointHash2"));

        IInbox.ProveInput memory fullInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentCheckpointHash: bytes32(0),
            actualProver: prover,
            transitions: fullBatch,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: fullBatch[1].checkpointHash,
                stateRoot: keccak256("stateRoot2")
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(fullInput);
        vm.expectRevert(Inbox.ParentCheckpointHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_noBondSignal_withinProvingWindow() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Prove within the proving window - no bond signal should be emitted
        _prove(input);

        // No bond signal should be sent when proof is on time
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

        // Move past proving window but still within extended window
        vm.warp(block.timestamp + config.provingWindow + 1);

        // Set designatedProver = actualProver so payer == payee
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposed.proposal.proposer,
            designatedProver: prover, // Same as actualProver
            timestamp: proposed.proposal.timestamp,
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover, // Same as designatedProver
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // No bond signal should be sent when payer == payee
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

    // =========================================================================
    // Boundary Tests - prove() conditions
    // =========================================================================

    /// @notice Test firstProposalId at exact boundary (== lastFinalizedProposalId + 1)
    function test_prove_succeedsWhen_FirstProposalIdAtExactBoundary() public {
        // lastFinalizedProposalId = 0, so firstProposalId must be <= 1
        // Test with firstProposalId = 1 (exact boundary)
        IInbox.ProveInput memory input = _buildBatchInput(1);
        assertEq(input.firstProposalId, 1, "firstProposalId should be 1");
        assertEq(inbox.getState().lastFinalizedProposalId, 0, "lastFinalizedProposalId should be 0");

        _prove(input);

        assertEq(inbox.getState().lastFinalizedProposalId, 1, "should finalize");
    }

    /// @notice Test lastProposalId at exact boundary (== nextProposalId - 1)
    function test_prove_succeedsWhen_LastProposalIdAtExactBoundary() public {
        // Use _buildBatchInput which handles propose internally
        // This verifies that lastProposalId = nextProposalId - 1 succeeds
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // After _buildBatchInput(1), we have 1 proposal, nextProposalId = 2
        assertEq(inbox.getState().nextProposalId, 2, "nextProposalId should be 2");

        // lastProposalId = firstProposalId + numProposals - 1 = 1 + 1 - 1 = 1
        uint256 lastProposalId = input.firstProposalId + input.transitions.length - 1;
        assertEq(lastProposalId, 1, "lastProposalId at exact boundary");
        // Verify: lastProposalId (1) < nextProposalId (2) → passes

        _prove(input);

        assertEq(inbox.getState().lastFinalizedProposalId, 1, "should finalize");
    }

    /// @notice Test lastProposalId fails when == nextProposalId (just past boundary)
    function test_prove_RevertWhen_LastProposalIdEqualsNextProposalId() public {
        // Propose 1 block, nextProposalId = 2
        _proposeOne();

        // Try to prove 2 proposals (lastProposalId = 2 == nextProposalId)
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            checkpointHash: keccak256("checkpointHash1")
        });
        transitions[1] = IInbox.Transition({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            checkpointHash: keccak256("checkpointHash2")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[1].checkpointHash,
                stateRoot: bytes32(uint256(1))
            })
        });

        // lastProposalId = 1 + 2 - 1 = 2, nextProposalId = 2
        // Condition: lastProposalId < nextProposalId → 2 < 2 → false → revert
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // =========================================================================
    // Boundary Tests - Bond instruction timing
    // =========================================================================

    /// @notice Test proving at exact provingWindow boundary (proposalAge == provingWindow)
    /// - no bond
    function test_prove_noBondSignal_atExactProvingWindowBoundary() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to exactly provingWindow (proposalAge == provingWindow)
        vm.warp(proposed.proposal.timestamp + config.provingWindow);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver
            timestamp: proposed.proposal.timestamp,
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // At exact boundary (proposalAge <= provingWindow), no bond signal
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "no bond at exact provingWindow"
        );
    }

    /// @notice Test proving 1 second past provingWindow - triggers LIVENESS bond
    function test_prove_livenessBond_oneSecondPastProvingWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to provingWindow + 1 (just past boundary)
        vm.warp(proposed.proposal.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver to trigger bond
            timestamp: proposed.proposal.timestamp,
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // Just past provingWindow triggers LIVENESS bond
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver pays
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "liveness bond 1 sec past window"
        );
    }

    /// @notice Test proving at exact extendedProvingWindow boundary - still LIVENESS bond
    function test_prove_livenessBond_atExactExtendedWindowBoundary() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to exactly extendedProvingWindow (proposalAge == extendedProvingWindow)
        vm.warp(proposed.proposal.timestamp + config.extendedProvingWindow);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver to trigger bond
            timestamp: proposed.proposal.timestamp,
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // At exact extendedProvingWindow boundary (proposalAge <= extendedProvingWindow),
        // LIVENESS bond
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "liveness at exact extendedWindow"
        );
    }

    /// @notice Test proving 1 second past extendedProvingWindow - triggers PROVABILITY bond
    function test_prove_provabilityBond_oneSecondPastExtendedWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to extendedProvingWindow + 1 (just past boundary)
        vm.warp(proposed.proposal.timestamp + config.extendedProvingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver
            timestamp: proposed.proposal.timestamp,
            checkpointHash: keccak256("checkpointHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot")
            })
        });

        _prove(input);

        // Past extendedProvingWindow triggers PROVABILITY bond
        // (proposer pays, not designatedProver)
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: proposed.proposal.proposer, // proposer pays
            payee: prover
        });
        bytes32 provabilitySignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), provabilitySignal),
            "provability 1 sec past extended"
        );
    }

    function test_prove_noCheckpointSync_beforeDelay() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);
        input.lastCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: 0,
            blockHash: bytes32(0),
            stateRoot: bytes32(0)
        });

        // Do NOT warp past minCheckpointDelay - checkpoint should not sync
        _prove(input);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        // Checkpoint timestamp should remain 0 (initial value) since delay hasn't passed
        assertEq(state.lastCheckpointTimestamp, 0, "checkpoint timestamp unchanged");
    }

    function test_prove_checkpointSyncsWhenProvided() public {
        // First prove without checkpoint sync
        IInbox.ProveInput memory input1 = _buildBatchInput(1);
        input1.lastCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: 0,
            blockHash: bytes32(0),
            stateRoot: bytes32(0)
        });
        _prove(input1);

        assertEq(inbox.getState().lastCheckpointTimestamp, 0, "checkpoint not synced initially");

        // Advance block and propose another without waiting for minCheckpointDelay
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = _transitionFor(p2, prover, keccak256("checkpointHash2"));

        IInbox.ProveInput memory input2 = IInbox.ProveInput({
            firstProposalId: p2.proposal.id,
            firstProposalParentCheckpointHash: inbox.getState().lastFinalizedCheckpointHash,
            actualProver: prover,
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: transitions[0].checkpointHash,
                stateRoot: keccak256("stateRoot2")
            })
        });

        _prove(input2);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint synced");
    }
}
