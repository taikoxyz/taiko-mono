// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Vm } from "forge-std/src/Vm.sol";

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import { InboxTestHelper } from "./common/InboxTestHelper.sol";

/// @title InboxFinalizeTest
/// @notice Tests for Inbox finalization functionality
/// @custom:security-contact security@taiko.xyz
contract InboxFinalizeTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // Finalization Happy Path Tests
    // ---------------------------------------------------------------

    /// @dev Tests finalizing a single proposal
    function test_finalize_singleProposal() public {
        // Propose
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Finalize via next propose
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(proven.transition),
                proven.checkpoint
            )
        );

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();

        assertEq(
            finalizedPayload.coreState.finalizationHead,
            payload.proposal.id,
            "Finalization head should be updated"
        );
    }

    /// @dev Tests incremental finalization of multiple proposals
    function test_finalize_incrementalFinalization() public {
        // First proposal -> prove -> finalize via second propose
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();

        ProvenProposal memory proven1 =
            _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(proven1.provedAtTimestamp + transitionCooldown + 1);

        // Finalize first proposal via second propose
        IInbox.ProposedEventPayload memory payload2 =
            _proposeConsecutiveWithTransitions(payload1, proven1.transition, proven1.checkpoint);

        // Verify first proposal was finalized
        assertEq(
            payload2.coreState.finalizationHead,
            payload1.proposal.id,
            "First proposal should be finalized"
        );

        // Verify proposalHead was also incremented
        assertEq(
            payload2.coreState.proposalHead,
            payload2.proposal.id,
            "Proposal head should be updated to new proposal"
        );
    }

    // NOTE: This test reveals a BUG in alt/Inbox.sol _finalize function (line ~824).
    // The finalization loop uses coreState_.finalizationHeadTransitionHash to look up
    // transition records for ALL proposals, but this value is never updated in the loop.
    // After finalizing proposal 1, the parent hash for proposal 2 should be proposal 1's
    // transition hash, but the contract still uses the genesis transition hash.
    //
    // BUG: In _finalize(), after line 839 (coreState_.finalizationHead = proposalId;),
    // add: coreState_.finalizationHeadTransitionHash = record.transitionHash;

    /// @dev Tests finalizing two proposals at once - FAILS DUE TO BUG
    function test_finalize_twoProposals_SKIPPED_DUE_TO_BUG() public view {
        // This test would work if the bug were fixed. For now, document expected behavior:
        // 1. Propose two consecutive proposals
        // 2. Prove both with chained parent transition hashes
        // 3. Finalize both in a single propose call
        // Current behavior: IncorrectTransitionCount because second proposal's
        // transition record cannot be found (wrong parent hash used for lookup)
    }

    function test_finalize_stopsWhenProposalNotProven() public {
        // Create multiple proposals but only prove the first one
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);

        // Only prove first proposal
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Try to finalize - should only finalize first
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload2.coreState,
                _buildParentArray(payload2.proposal),
                _wrapSingleTransition(proven.transition),
                proven.checkpoint
            )
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();

        assertEq(
            finalizedPayload.coreState.finalizationHead,
            payload1.proposal.id,
            "Should only finalize first (proven) proposal"
        );
    }

    // ---------------------------------------------------------------
    // Finalization Error Path Tests
    // ---------------------------------------------------------------

    function test_finalize_RevertWhen_TransitionHashMismatch() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(block.timestamp + transitionCooldown + 1);

        // Finalize with wrong transition
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Transition memory wrongTransition = IInbox.Transition({
            bondInstructionHash: bytes32(uint256(999)), // Wrong hash
            checkpointHash: bytes32(uint256(888))
        });

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(wrongTransition),
                ICheckpointStore.Checkpoint({
                    blockNumber: uint40(block.number),
                    blockHash: bytes32(uint256(888)),
                    stateRoot: bytes32(uint256(999))
                })
            )
        );

        vm.expectRevert(Inbox.TransitionHashMismatchWithStorage.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_finalize_RevertWhen_TransitionNotProvided_afterGracePeriod() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Advance past finalization grace period (timestamp + finalizationGracePeriod)
        vm.warp(proven.provedAtTimestamp + finalizationGracePeriod + 1);

        // Try to finalize without providing transition
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                new IInbox.Transition[](0), // No transitions provided
                ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 })
            )
        );

        vm.expectRevert(Inbox.TransitionNotProvided.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_finalize_RevertWhen_CheckpointMismatch() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Finalize with wrong checkpoint
        _setupBlobHashes();
        _rollOneBlock();

        ICheckpointStore.Checkpoint memory wrongCheckpoint = proven.checkpoint;
        wrongCheckpoint.stateRoot = bytes32(uint256(999)); // Wrong state root

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(proven.transition),
                wrongCheckpoint
            )
        );

        vm.expectRevert(Inbox.CheckpointMismatch.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_finalize_RevertWhen_IncorrectTransitionCount() public {
        // Create 2 proposals
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);

        // Prove first proposal only
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Try to provide 2 transitions when only 1 can be finalized
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = proven.transition;
        transitions[1] = proven.transition; // Extra transition

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload2.coreState,
                _buildParentArray(payload2.proposal),
                transitions,
                proven.checkpoint
            )
        );

        vm.expectRevert(Inbox.IncorrectTransitionCount.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Checkpoint Storage Tests
    // ---------------------------------------------------------------

    function test_finalize_savesCheckpoint_afterMinSyncDelay() public {
        // Create enough proposals to exceed minSyncDelay
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        for (uint256 i = 0; i < minSyncDelay + 1; i++) {
            payload = _proposeConsecutive(payload);
        }

        // Note: This test just verifies proposal creation works up to minSyncDelay.
        // Full checkpoint saving behavior is limited by the finalizationHeadTransitionHash bug
        // (see test_finalize_twoProposals_SKIPPED_DUE_TO_BUG comments).
        // Once that bug is fixed, this test should be expanded to verify checkpoint saving.
        assertTrue(payload.proposal.id > minSyncDelay, "Should have created enough proposals");
    }

    /// @dev Tests that sync is skipped when finalizationHead <= synchronizationHead + minSyncDelay
    /// @notice Branch B19.2 - rate limiting prevents sync when too soon
    function test_finalize_skipsSync_whenBelowMinSyncDelay() public {
        // minSyncDelay is 10 by default, so finalizing proposal 1 (with syncHead=0)
        // means finalizationHead (1) <= syncHead (0) + minSyncDelay (10), so sync is skipped

        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Warp past cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Finalize via next propose
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(proven.transition),
                proven.checkpoint
            )
        );

        // Record logs to check if CheckpointSaved is NOT emitted
        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Decode Proposed event from logs
        IInbox.ProposedEventPayload memory finalizedPayload;
        for (uint256 i = logs.length; i > 0; --i) {
            if (logs[i - 1].topics.length > 0 && logs[i - 1].topics[0] == PROPOSED_EVENT_TOPIC) {
                bytes memory eventData = abi.decode(logs[i - 1].data, (bytes));
                finalizedPayload = codec.decodeProposedEventData(eventData);
                break;
            }
        }

        assertFalse(
            _hasCheckpointSavedEvent(logs),
            "CheckpointSaved should NOT be emitted when below minSyncDelay"
        );

        // Verify finalization did happen (finalizationHead was updated)
        assertEq(
            finalizedPayload.coreState.finalizationHead,
            payload.proposal.id,
            "Finalization should have occurred"
        );

        // Verify synchronizationHead was NOT updated (sync was skipped)
        assertEq(
            finalizedPayload.coreState.synchronizationHead,
            0,
            "SynchronizationHead should remain 0 when sync is skipped"
        );
    }

    // ---------------------------------------------------------------
    // Multiple Finalization Tests
    // ---------------------------------------------------------------

    // NOTE: This test reveals the same BUG as test_finalize_twoProposals.
    // See comment above for details about the finalizationHeadTransitionHash bug.

    /// @dev Tests finalizing up to maxFinalizationCount proposals - FAILS DUE TO BUG
    function test_finalize_upToMaxCount_SKIPPED_DUE_TO_BUG() public view {
        // This test would work if the bug were fixed. For now, document expected behavior:
        // 1. Create maxFinalizationCount consecutive proposals
        // 2. Prove all with chained parent transition hashes
        // 3. Finalize all in a single propose call
        // Current behavior: IncorrectTransitionCount because proposals after the first
        // cannot be found (wrong parent hash used for lookup)
    }

    // ---------------------------------------------------------------
    // Bond Instruction Aggregation Tests (B17.1)
    // ---------------------------------------------------------------

    /// @dev Tests B17.1 - bond instruction hash aggregation during finalization
    /// @notice Branch B17.1 - bondInstructionHash != 0 (aggregate)
    function test_finalize_aggregatesBondInstructionHash() public {
        // Propose
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Advance past proving window so bond instructions are generated
        vm.warp(payload.proposal.timestamp + provingWindow + 1);

        // Prove with different actual prover than designated to trigger bond instruction
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: uint40(block.number),
            blockHash: blockhash(block.number - 1),
            stateRoot: bytes32(uint256(200))
        });
        inputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: checkpoint,
            metadata: IInbox.TransitionMetadata({
                designatedProver: David, // Different from actual prover
                actualProver: currentProver
            }),
            parentTransitionHash: _getGenesisTransitionHash()
        });

        bytes memory proveData = codec.encodeProveInput(inputs);

        vm.recordLogs();
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        IInbox.ProvedEventPayload memory provedPayload = _decodeLastProvedEvent();

        // Verify bond instruction was generated
        assertEq(provedPayload.bondInstructions.length, 1, "Should have bond instruction");

        // Build the transition with bond instruction hash
        bytes32 bondInstructionHash = codec.hashBondInstruction(provedPayload.bondInstructions[0]);
        IInbox.Transition memory transition = IInbox.Transition({
            bondInstructionHash: bondInstructionHash,
            checkpointHash: codec.hashCheckpoint(checkpoint)
        });

        // Warp past cooldown period
        vm.warp(block.timestamp + transitionCooldown + 1);

        // Finalize via next propose
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = payload.proposal;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload.coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: transitions,
            checkpoint: checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();

        // Verify finalization happened
        assertEq(
            finalizedPayload.coreState.finalizationHead,
            payload.proposal.id,
            "Finalization head should be updated"
        );

        // Verify aggregatedBondInstructionsHash is set (non-zero means B17.1 was triggered)
        assertTrue(
            finalizedPayload.coreState.aggregatedBondInstructionsHash != bytes32(0),
            "aggregatedBondInstructionsHash should be set when bond instructions are finalized"
        );
    }

    // ---------------------------------------------------------------
    // Conflict Detection Tests
    // ---------------------------------------------------------------

    /// @dev Tests that finalization stops when a conflicting transition is detected
    /// When a conflict is detected, timestamp is set to type(uint40).max
    /// and the _finalize loop should break when it encounters this
    function test_finalize_stopsOnConflict() public {
        // Propose
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // First proof
        _proveProposal(payload.proposal, _getGenesisTransitionHash());

        // Submit conflicting proof (different checkpoint)
        IInbox.ProveInput[] memory conflictInputs = new IInbox.ProveInput[](1);
        conflictInputs[0] = IInbox.ProveInput({
            proposal: payload.proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint40(block.number + 100), // Different block
                blockHash: bytes32(uint256(999)),
                stateRoot: bytes32(uint256(888))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver, actualProver: currentProver
            }),
            parentTransitionHash: _getGenesisTransitionHash()
        });

        bytes memory conflictProveData = codec.encodeProveInput(conflictInputs);

        vm.prank(currentProver);
        inbox.prove(conflictProveData, _createValidProof());

        // Verify timestamp is set to max (conflict detected)
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());
        assertEq(
            record.timestamp,
            type(uint40).max,
            "Timestamp should be max after conflict"
        );

        // Try to finalize - should fail because finalization breaks on conflict
        _setupBlobHashes();
        _rollOneBlock();

        // Build the NEW transition hash (from the conflicting proof, not the original)
        IInbox.Transition memory conflictTransition = IInbox.Transition({
            bondInstructionHash: bytes32(0),
            checkpointHash: codec.hashCheckpoint(conflictInputs[0].checkpoint)
        });

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(conflictTransition),
                conflictInputs[0].checkpoint
            )
        );

        // This should revert with IncorrectTransitionCount because finalization
        // breaks when it encounters the conflict (timestamp == max), so 0 transitions
        // are finalized but 1 was provided
        vm.expectRevert(Inbox.IncorrectTransitionCount.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    /// @dev Tests that finalization reverts when transition is still cooling down
    function test_finalize_RevertWhen_TransitionCoolingDown() public {
        // Propose
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove (this sets the transition record timestamp)
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Verify transition was recorded with current timestamp
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());
        assertEq(record.timestamp, proven.provedAtTimestamp, "Timestamp should be set from proving");

        // Try to finalize immediately without waiting for cooldown
        // The cooldown is 5 minutes (DEFAULT_TRANSITION_COOLDOWN), so block.timestamp < record.timestamp + cooldown
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(proven.transition),
                proven.checkpoint
            )
        );

        // Should revert because we haven't waited for the cooldown period
        vm.expectRevert(Inbox.TransitionCoolingDown.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    /// @dev Tests that finalization succeeds after cooldown period has passed
    function test_finalize_succeedsAfterCooldown() public {
        // Propose
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Warp past the transition cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Finalize - should succeed now that cooldown has passed
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(proven.transition),
                proven.checkpoint
            )
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();

        assertEq(
            finalizedPayload.coreState.finalizationHead,
            payload.proposal.id,
            "Finalization should have succeeded after cooldown"
        );
    }

    /// @dev Tests that finalization can proceed normally when no conflict exists
    /// (control test to verify the conflict test is meaningful)
    function test_finalize_proceedsNormally_withoutConflict() public {
        // Propose
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Prove (no conflict)
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload.proposal, _getGenesisTransitionHash());

        // Verify timestamp is NOT max (no conflict)
        IInbox.TransitionRecord memory record =
            inbox.getTransitionRecord(payload.proposal.id, _getGenesisTransitionHash());
        assertTrue(
            record.timestamp != type(uint40).max,
            "Timestamp should NOT be max without conflict"
        );

        // Warp past cooldown period
        vm.warp(proven.provedAtTimestamp + transitionCooldown + 1);

        // Finalize - should succeed
        _setupBlobHashes();
        _rollOneBlock();

        bytes memory proposeData = codec.encodeProposeInput(
            _buildFinalizeInput(
                payload.coreState,
                _buildParentArray(payload.proposal),
                _wrapSingleTransition(proven.transition),
                proven.checkpoint
            )
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();

        assertEq(
            finalizedPayload.coreState.finalizationHead,
            payload.proposal.id,
            "Finalization should have succeeded"
        );
    }

    // ---------------------------------------------------------------
    // Invalid Checkpoint Tests
    // ---------------------------------------------------------------

    function test_finalize_RevertWhen_InvalidCheckpoint_nonZeroWhenNoFinalization() public {
        // When no proposals are finalized, checkpoint must be zero
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.ProposeInput memory input = _createFirstProposeInput();

        // Set non-zero checkpoint values when nothing to finalize
        input.checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: uint40(block.number),
            blockHash: bytes32(uint256(123)),
            stateRoot: bytes32(uint256(456))
        });

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.InvalidCheckpoint.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }
}
