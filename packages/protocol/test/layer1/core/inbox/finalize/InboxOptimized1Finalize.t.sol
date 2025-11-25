// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractOptimizedFinalize } from "./AbstractOptimizedFinalize.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

/// @title InboxOptimized1Finalize
/// @notice Finalization tests for the InboxOptimized1 implementation
contract InboxOptimized1Finalize is AbstractOptimizedFinalize {
    function _createDeployer() internal override returns (IInboxDeployer) {
        return new InboxOptimized1Deployer();
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
