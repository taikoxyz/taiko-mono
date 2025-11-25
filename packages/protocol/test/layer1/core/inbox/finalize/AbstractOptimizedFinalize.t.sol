// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";
import { AbstractFinalizeTest } from "./AbstractFinalize.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title AbstractOptimizedFinalize
/// @notice Shared finalization tests for optimized inbox implementations that aggregate spans
abstract contract AbstractOptimizedFinalize is AbstractFinalizeTest {
    function setUp() public virtual override {
        setDeployer(_createDeployer());
        super.setUp();
    }

    function _createDeployer() internal virtual returns (IInboxDeployer);

    /// @dev Ensures aggregated transition records finalize all proposals within the span and
    /// advance lastFinalizedProposalId/TransitionHash accordingly.
    function test_finalize_updatesLastFinalizedAcrossAggregatedSpan() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        IInbox.ProposedEventPayload memory secondPayload = _proposeNext(firstPayload.proposal);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = firstPayload.proposal;
        proposals[1] = secondPayload.proposal;

        (IInbox.TransitionRecord[] memory records, ICheckpointStore.Checkpoint memory checkpoint) =
            _proveConsecutiveProposalsAndGetRecords(proposals);

        assertEq(records.length, 1, "Expected a single aggregated record");
        assertEq(records[0].span, 2, "Unexpected span");

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    secondPayload.coreState,
                    _buildParentArray(secondPayload.proposal),
                    records,
                    checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();
        assertEq(finalizedPayload.coreState.lastFinalizedProposalId, secondPayload.proposal.id);
        assertEq(finalizedPayload.coreState.lastFinalizedTransitionHash, records[0].transitionHash);

        ICheckpointStore.Checkpoint memory saved =
            checkpointManager.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash, "Checkpoint block hash mismatch");
        assertEq(saved.stateRoot, checkpoint.stateRoot, "Checkpoint state root mismatch");
    }

    /// @dev Ensures aggregation enforces parent-child continuity; mismatched parents must not be
    /// aggregated or finalized.
    function test_finalize_doesNotAggregateWhenParentMismatch() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        IInbox.ProposedEventPayload memory secondPayload = _proposeNext(firstPayload.proposal);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = firstPayload.proposal;
        proposals[1] = secondPayload.proposal;

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _createTransitionForProposal(proposals[0]);
        transitions[0].parentTransitionHash = _getGenesisTransitionHash();

        transitions[1] = _createTransitionForProposal(proposals[1]);
        transitions[1].parentTransitionHash = keccak256("wrong-parent");

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](2);
        metadata[0] = _createMetadataForTransition(currentProver, currentProver);
        metadata[1] = _createMetadataForTransition(currentProver, currentProver);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        vm.recordLogs();
        vm.prank(currentProver);
        inbox.prove(_codec().encodeProveInput(proveInput), _createValidProof());

        IInbox.ProvedEventPayload[] memory provedPayloads = _decodeProvedEvents();
        assertEq(provedPayloads.length, 2, "Expected two proved events when parents mismatch");

        IInbox.TransitionRecord[] memory records = new IInbox.TransitionRecord[](2);
        records[0] = provedPayloads[0].transitionRecord;
        records[1] = provedPayloads[1].transitionRecord;

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    secondPayload.coreState,
                    _buildParentArray(secondPayload.proposal),
                    records,
                    transitions[0].checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();
        assertEq(
            finalizedPayload.coreState.lastFinalizedProposalId,
            firstPayload.proposal.id,
            "Should only finalize the first proposal"
        );
        assertEq(
            finalizedPayload.coreState.lastFinalizedTransitionHash,
            provedPayloads[0].transitionRecord.transitionHash,
            "Finalized tip must match chained transition"
        );
    }
}
