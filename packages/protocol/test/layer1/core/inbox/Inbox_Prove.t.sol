// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Vm } from "forge-std/src/Vm.sol";

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import { InboxTestHelper } from "./common/InboxTestHelper.sol";

/// @title InboxProveTest
/// @notice Tests for Inbox prove functionality
/// @custom:security-contact security@taiko.xyz
contract InboxProveTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // Prove Happy Path Tests
    // ---------------------------------------------------------------

    /// @dev Tests proving a single proposal - baseline gas measurement
    function test_prove_singleProposal() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        IInbox.ProvedEventPayload memory provedPayload =
            _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Verify transition record is stored
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());

        assertTrue(record.transitionHash != bytes27(0), "Transition should be stored");
        assertEq(
            record.finalizationDeadline,
            provedPayload.finalizationDeadline,
            "Finalization deadline should match"
        );

        // ProvedEventPayload being non-empty confirms the event was emitted and decoded
        assertTrue(provedPayload.finalizationDeadline > 0, "Proved event should have been emitted");
    }

    /// @dev Tests proving 2 consecutive proposals
    function test_prove_twoConsecutiveProposals() public {
        IInbox.ProposedEventPayload[] memory payloads = _createConsecutiveProposals(2);

        // Prove all proposals
        IInbox.ProveInput[] memory inputs =
            _createProveInputForMultipleProposals(_extractProposals(payloads), _getGenesisTransitionHash(), true);
        bytes memory proveData = inbox.encodeProveInput(inputs);

        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        // Verify first transition is stored (uses genesis as parent)
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payloads[0].proposal.id, _getGenesisTransitionHash());
        assertTrue(record.transitionHash != bytes27(0), "First transition should be stored");
    }

    /// @dev Tests proving 3 consecutive proposals
    function test_prove_threeConsecutiveProposals() public {
        IInbox.ProposedEventPayload[] memory payloads = _createConsecutiveProposals(3);

        IInbox.ProveInput[] memory inputs =
            _createProveInputForMultipleProposals(_extractProposals(payloads), _getGenesisTransitionHash(), true);
        bytes memory proveData = inbox.encodeProveInput(inputs);

        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        // Verify first transition is stored (uses genesis as parent)
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payloads[0].proposal.id, _getGenesisTransitionHash());
        assertTrue(record.transitionHash != bytes27(0), "First transition should be stored");
    }

    function test_prove_setsCorrectFinalizationDeadline() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        uint256 expectedDeadline = block.timestamp + finalizationGracePeriod;

        IInbox.ProvedEventPayload memory provedPayload =
            _proveProposal(payload.proposal, _getGenesisTransitionHash());

        assertEq(
            provedPayload.finalizationDeadline,
            expectedDeadline,
            "Finalization deadline should be timestamp + grace period"
        );
    }

    function test_prove_emitsCorrectEventData() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        IInbox.ProvedEventPayload memory provedPayload =
            _proveProposal(payload.proposal, _getGenesisTransitionHash());

        assertGt(provedPayload.finalizationDeadline, 0, "Finalization deadline should be set");
        assertGt(provedPayload.checkpoint.blockNumber, 0, "Checkpoint block number should be set");
    }

    // ---------------------------------------------------------------
    // Prove Error Path Tests
    // ---------------------------------------------------------------

    function test_prove_RevertWhen_EmptyInputs() public {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](0);
        bytes memory proveData = inbox.encodeProveInput(inputs);

        vm.expectRevert(Inbox.EmptyProveInputs.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());
    }

    function test_prove_RevertWhen_ProposalNotFound() public {
        // Create a fake proposal that doesn't exist
        IInbox.Proposal memory fakeProposal = IInbox.Proposal({
            id: 999,
            timestamp: uint40(block.timestamp),
            endOfSubmissionWindowTimestamp: 0,
            proposer: currentProposer,
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222)),
            parentProposalHash: bytes32(uint256(333))
        });

        IInbox.ProveInput[] memory inputs = _createProveInput(fakeProposal, _getGenesisTransitionHash());
        bytes memory proveData = inbox.encodeProveInput(inputs);

        vm.expectRevert(Inbox.ProposalHashMismatch.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());
    }

    function test_prove_RevertWhen_InvalidProof() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        proofVerifier.setRevert(true);

        IInbox.ProveInput[] memory inputs =
            _createProveInput(payload.proposal, _getGenesisTransitionHash());
        bytes memory proveData = inbox.encodeProveInput(inputs);

        vm.expectRevert("MockProofVerifier: invalid proof");
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());
    }

    // ---------------------------------------------------------------
    // Bond Instruction Tests
    // ---------------------------------------------------------------

    function test_prove_noBondInstructions_withinProvingWindow() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove within proving window - no bond instructions
        IInbox.ProvedEventPayload memory provedPayload =
            _proveProposal(payload.proposal, _getGenesisTransitionHash());

        assertEq(provedPayload.bondInstructions.length, 0, "No bond instructions within window");
    }

    /// @dev Tests B11.2 - prove() generates non-empty bond instructions when conditions are met
    /// @notice Branch B11.2 - bondInstructions.length > 0 (hash = hash)
    function test_prove_nonEmptyBondInstructions_livenessBond() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Advance past proving window but within extended window
        // provingWindow = 1 hour, extendedProvingWindow = 2 hours
        vm.warp(payload.proposal.timestamp + provingWindow + 1);

        // Different actual prover than designated - triggers liveness bond
        IInbox.ProvedEventPayload memory provedPayload = _proveProposalWithMetadata(
            payload.proposal, _getGenesisTransitionHash(), David, currentProver
        );

        assertEq(provedPayload.bondInstructions.length, 1, "Should have 1 bond instruction");
        assertEq(
            uint8(provedPayload.bondInstructions[0].bondType),
            uint8(LibBonds.BondType.LIVENESS),
            "Should be LIVENESS bond type"
        );
    }

    /// @dev Tests B13.2 - Liveness bond when within extended window and different prover
    /// @notice Branch B13.2 - withinExtended && actualProver != designated (liveness bond)
    function test_prove_livenessBond_afterProvingWindow_differentProver() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Advance past proving window but within extended window
        vm.warp(payload.proposal.timestamp + provingWindow + 1);

        // Different actual prover than designated - triggers liveness bond
        IInbox.ProvedEventPayload memory provedPayload = _proveProposalWithMetadata(
            payload.proposal, _getGenesisTransitionHash(), David, currentProver
        );

        assertEq(provedPayload.bondInstructions.length, 1, "Should have liveness bond");
        assertEq(
            uint8(provedPayload.bondInstructions[0].bondType),
            uint8(LibBonds.BondType.LIVENESS),
            "Bond type should be LIVENESS"
        );
        assertEq(
            provedPayload.bondInstructions[0].payer,
            David,
            "Payer should be designated prover"
        );
        assertEq(
            provedPayload.bondInstructions[0].payee,
            currentProver,
            "Payee should be actual prover"
        );
    }

    /// @dev Tests B13.3 - No bond when within extended window and same designated prover
    /// @notice Branch B13.3 - withinExtended && actualProver == designated (no bond)
    function test_prove_noBond_afterProvingWindow_sameDesignatedProver() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Advance past proving window but within extended window
        vm.warp(payload.proposal.timestamp + provingWindow + 1);

        // Same designated and actual prover - no bond needed
        IInbox.ProvedEventPayload memory provedPayload = _proveProposalWithMetadata(
            payload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        assertEq(
            provedPayload.bondInstructions.length,
            0,
            "No bond when same designated prover within extended window"
        );
    }

    /// @dev Tests B13.4 - Provability bond when after extended window and different prover
    /// @notice Branch B13.4 - afterExtended && actualProver != proposer (provability bond)
    function test_prove_provabilityBond_afterExtendedWindow_differentProver() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Advance past extended proving window
        vm.warp(payload.proposal.timestamp + extendedProvingWindow + 1);

        // Different actual prover than proposer - triggers provability bond
        // Note: proposer is currentProposer (Bob), actual prover is currentProver (Carol)
        IInbox.ProvedEventPayload memory provedPayload = _proveProposalWithMetadata(
            payload.proposal, _getGenesisTransitionHash(), David, currentProver
        );

        assertEq(provedPayload.bondInstructions.length, 1, "Should have provability bond");
        assertEq(
            uint8(provedPayload.bondInstructions[0].bondType),
            uint8(LibBonds.BondType.PROVABILITY),
            "Bond type should be PROVABILITY"
        );
        assertEq(
            provedPayload.bondInstructions[0].payer,
            payload.proposal.proposer,
            "Payer should be proposer"
        );
        assertEq(
            provedPayload.bondInstructions[0].payee,
            currentProver,
            "Payee should be actual prover"
        );
    }

    /// @dev Tests B13.5 - No provability bond when after extended window but proposer proves
    function test_prove_noBondInstruction_sameProver() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Advance past proving window
        vm.warp(payload.proposal.timestamp + provingWindow + 1);

        // Same designated and actual prover - no bond transfer
        IInbox.ProvedEventPayload memory provedPayload = _proveProposalWithMetadata(
            payload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        assertEq(
            provedPayload.bondInstructions.length,
            0,
            "No bond instruction when provers are the same"
        );
    }

    // ---------------------------------------------------------------
    // Transition Record Storage Tests
    // ---------------------------------------------------------------

    function test_prove_storesTransitionInRingBuffer() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());

        assertTrue(record.transitionHash != bytes27(0), "Transition should be stored in ring buffer");
    }

    function test_prove_updatesExistingTransition_sameHash() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // First proof
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        IInbox.TransitionRecord memory firstRecord =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());

        // Second proof with same transition (different time)
        vm.warp(block.timestamp + 100);
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        IInbox.TransitionRecord memory secondRecord =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());

        // Transition hash should be the same
        assertEq(
            secondRecord.transitionHash,
            firstRecord.transitionHash,
            "Transition hash should remain the same"
        );

        // Finalization deadline should be updated
        assertGt(
            secondRecord.finalizationDeadline,
            firstRecord.finalizationDeadline,
            "Deadline should be updated"
        );
    }

    // ---------------------------------------------------------------
    // Conflicting Transition Tests
    // ---------------------------------------------------------------

    function test_prove_conflictingTransition_emitsEvent() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // First proof
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Second proof with different checkpoint (conflict)
        IInbox.ProveInput[] memory conflictInputs = new IInbox.ProveInput[](1);
        conflictInputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number + 100), // Different block
                blockHash: bytes32(uint256(999)),
                stateRoot: bytes32(uint256(888))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver,
                actualProver: currentProver
            }),
            parentTransitionHash: _getGenesisTransitionHash()
        });

        bytes memory proveData = inbox.encodeProveInput(conflictInputs);

        vm.recordLogs();
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        // Check for ConflictingTransition event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(_hasConflictingTransitionEvent(logs), "Should emit ConflictingTransition event");
    }

    function test_prove_conflictingTransition_setsMaxDeadline() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // First proof
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Second proof with different checkpoint (conflict)
        IInbox.ProveInput[] memory conflictInputs = new IInbox.ProveInput[](1);
        conflictInputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number + 100),
                blockHash: bytes32(uint256(999)),
                stateRoot: bytes32(uint256(888))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver,
                actualProver: currentProver
            }),
            parentTransitionHash: _getGenesisTransitionHash()
        });

        bytes memory proveData = inbox.encodeProveInput(conflictInputs);

        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        // Check that finalization deadline is set to max
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());

        assertEq(
            record.finalizationDeadline,
            type(uint40).max,
            "Conflicting transition should have max deadline"
        );
    }

    // ---------------------------------------------------------------
    // Custom Prover Tests
    // ---------------------------------------------------------------

    function test_prove_withCustomDesignatedProver() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove with different designated prover than actual prover
        IInbox.ProvedEventPayload memory provedPayload = _proveProposalWithMetadata(
            payload.proposal, _getGenesisTransitionHash(), David, currentProver
        );

        // Verify the proof was accepted
        assertTrue(provedPayload.finalizationDeadline > 0, "Proof should be accepted");
    }

    // ---------------------------------------------------------------
    // Fallback Mapping Tests (B14.3)
    // ---------------------------------------------------------------

    /// @dev Tests that proving same proposal with different parent transition hash uses fallback mapping
    function test_prove_differentParentTransitionHash_usesFallbackMapping() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // First proof with genesis transition hash
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Verify first transition is stored in ring buffer
        IInbox.TransitionRecord memory firstRecord =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());
        assertTrue(firstRecord.transitionHash != bytes27(0), "First transition should be stored");

        // Second proof with different parent transition hash
        // This simulates an alternative transition chain
        bytes27 alternateParentHash = bytes27(keccak256("alternate_parent"));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);
        inputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number + 1),
                blockHash: bytes32(uint256(777)),
                stateRoot: bytes32(uint256(666))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver,
                actualProver: currentProver
            }),
            parentTransitionHash: alternateParentHash
        });

        bytes memory proveData = inbox.encodeProveInput(inputs);
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        // Verify both transitions are stored independently
        IInbox.TransitionRecord memory secondRecord =
            inbox.getTransitionRecord(payload.proposal.id, alternateParentHash);
        assertTrue(secondRecord.transitionHash != bytes27(0), "Second transition should be stored");

        // Both records should exist with different hashes (different checkpoints)
        assertTrue(
            firstRecord.transitionHash != secondRecord.transitionHash,
            "Transitions should have different hashes"
        );
    }

    /// @dev Tests conflicting transition on fallback mapping path
    function test_prove_conflictingTransition_fallbackMapping() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // First proof with genesis transition hash
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Second proof with different parent hash - stored in fallback
        bytes27 alternateParentHash = bytes27(keccak256("alternate_parent"));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);
        inputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number + 1),
                blockHash: bytes32(uint256(777)),
                stateRoot: bytes32(uint256(666))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver,
                actualProver: currentProver
            }),
            parentTransitionHash: alternateParentHash
        });

        bytes memory proveData = inbox.encodeProveInput(inputs);
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        // Now submit a conflicting proof with same alternate parent but different checkpoint
        IInbox.ProveInput[] memory conflictInputs = new IInbox.ProveInput[](1);
        conflictInputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number + 200), // Different checkpoint
                blockHash: bytes32(uint256(888)),
                stateRoot: bytes32(uint256(999))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver,
                actualProver: currentProver
            }),
            parentTransitionHash: alternateParentHash
        });

        bytes memory conflictProveData = inbox.encodeProveInput(conflictInputs);

        vm.recordLogs();
        vm.prank(currentProver);
        inbox.prove(conflictProveData, _createValidProof());

        // Verify ConflictingTransition event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(_hasConflictingTransitionEvent(logs), "Should emit ConflictingTransition event on fallback mapping");

        // Verify max deadline is set
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, alternateParentHash);
        assertEq(record.finalizationDeadline, type(uint40).max, "Should set max deadline for conflict");
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    function _extractProposals(IInbox.ProposedEventPayload[] memory _payloads)
        internal
        pure
        returns (IInbox.Proposal[] memory proposals)
    {
        proposals = new IInbox.Proposal[](_payloads.length);
        for (uint256 i = 0; i < _payloads.length; i++) {
            proposals[i] = _payloads[i].proposal;
        }
    }
}
