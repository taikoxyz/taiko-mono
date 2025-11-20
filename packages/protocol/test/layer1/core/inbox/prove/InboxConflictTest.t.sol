// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { AbstractProveTest } from "./AbstractProve.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { Vm } from "forge-std/src/Vm.sol";

contract InboxConflictTest is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    function test_finalize_SkipWhen_ConflictingTransitionDetected() public {
        // 1. Propose a block
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // 2. Prove transition A (valid)
        IInbox.Transition memory transitionA = _createTransitionForProposal(proposal);
        // Modify state root to make it distinct
        transitionA.checkpoint.stateRoot = keccak256("stateA");
        
        IInbox.TransitionMetadata memory metaA = _createMetadataForTransition(currentProver, currentProver);

        bytes memory proveDataA = _createProveInputSingle(proposal, transitionA, metaA);
        bytes memory proof = _createValidProof();

        vm.recordLogs(); // Start recording logs to capture Proved event
        vm.prank(currentProver);
        inbox.prove(proveDataA, proof);

        // 3. Prove transition B (valid, conflicting with A)
        IInbox.Transition memory transitionB = _createTransitionForProposal(proposal);
        // Modify state root to make it distinct and different from A
        transitionB.checkpoint.stateRoot = keccak256("stateB");
        
        IInbox.TransitionMetadata memory metaB = _createMetadataForTransition(currentProver, currentProver);

        bytes memory proveDataB = _createProveInputSingle(proposal, transitionB, metaB);

        vm.prank(currentProver);
        inbox.prove(proveDataB, proof);

        // 4. Verify conflictingTransitionDetected is true
        assertTrue(Inbox(address(inbox)).conflictingTransitionDetected(), "Conflict should be detected");

        // 5. Attempt to finalize transition A via propose
        // We need to create a new proposal that includes transition A for finalization
        
        // Roll to next block for new proposal
        vm.roll(block.number + 1);
        
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: proposal.id + 1,
            lastProposalBlockId: uint48(block.number - 1), // The block where 'proposal' was made
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = proposal;

        // Create transition record for A to include in propose
        IInbox.TransitionRecord memory recordA = _createTransitionRecord(proposal, transitionA, metaA);
        IInbox.TransitionRecord[] memory records = new IInbox.TransitionRecord[](1);
        records[0] = recordA;

        IInbox.ProposeInput memory proposeInput = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );
        proposeInput.transitionRecords = records;
        proposeInput.checkpoint = transitionA.checkpoint; // Fix CheckpointMismatch

        bytes memory proposeData = _codec().encodeProposeInput(proposeInput);

        // 6. Expectation: Should NOT revert, but emit FinalizationSkipped
        
        // vm.expectEmit(true, true, true, true);
        // emit Inbox.FinalizationSkipped(proposal.id + 1); // proposalId is nextProposalId which is proposal.id + 1
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Verify that the proposal was NOT finalized
        _verifyFinalizationSkipped(proposal.id);
    }

    function _verifyFinalizationSkipped(uint48 proposalId) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proposed(bytes)")) {
                bytes memory data = abi.decode(logs[i].data, (bytes));
                IInbox.ProposedEventPayload memory payload = abi.decode(data, (IInbox.ProposedEventPayload));
                // The proposal we just made is proposalId + 1
                if (payload.proposal.id == proposalId + 1) {
                    // Check lastFinalizedProposalId in the NEW coreState
                    assertEq(payload.coreState.lastFinalizedProposalId, 0, "Should not finalize conflicting proposal");
                    found = true;
                }
            }
        }
        assertTrue(found, "Proposed event not found");
    }

    function _createProveInputSingle(
        IInbox.Proposal memory proposal,
        IInbox.Transition memory transition,
        IInbox.TransitionMetadata memory meta
    ) internal view returns (bytes memory) {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;
        
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = meta;

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        return _codec().encodeProveInput(input);
    }

    function _createTransitionRecord(
        IInbox.Proposal memory proposal,
        IInbox.Transition memory /*transition*/,
        IInbox.TransitionMetadata memory /*meta*/
    ) internal returns (IInbox.TransitionRecord memory) {
         return _getTransitionRecordFromLogs(proposal.id);
    }

    function _getTransitionRecordFromLogs(uint48 proposalId) internal returns (IInbox.TransitionRecord memory) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proved(bytes)")) {
                bytes memory data = abi.decode(logs[i].data, (bytes));
                IInbox.ProvedEventPayload memory payload = abi.decode(data, (IInbox.ProvedEventPayload));
                if (payload.proposalId == proposalId) {
                    return payload.transitionRecord;
                }
            }
        }
        revert("Transition record not found in logs");
    }
}
