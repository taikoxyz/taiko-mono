// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title InboxTransitionRecord
/// @notice Comprehensive test suite for _storeTransitionRecord functionality in standard Inbox
/// @dev Tests all branches and edge cases in the transition record storage logic
contract InboxTransitionRecord is InboxTestHelper {
    address internal currentProposer = Bob;
    address internal currentProver = Carol;

    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
        currentProposer = _selectProposer(Bob);
    }

    // ---------------------------------------------------------------
    // Test Case 1: New Proposal ID - First Store (recordHash == 0)
    // ---------------------------------------------------------------

    /// @notice Tests storing a transition record for a new proposal ID
    /// @dev This is the first branch: recordHash == 0, should store successfully
    function test_storeTransitionRecord_newProposalId_firstStore() public {
        // Create and propose a new proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create prove input
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();

        // Record logs to verify Proved event
        vm.recordLogs();

        // Prove the proposal (this stores the transition record)
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Verify the transition record was stored
        (uint48 deadline, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());

        assertTrue(recordHash != bytes26(0), "Record hash should be non-zero");
        assertTrue(deadline > 0, "Finalization deadline should be set");
        // Grace period is 48 hours for standard Inbox
        assertEq(
            deadline,
            uint48(block.timestamp + 48 hours),
            "Deadline should be timestamp + grace period"
        );

        // Verify exactly one Proved event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 provedEventCount = _countProvedEvents(logs);
        assertEq(provedEventCount, 1, "Should emit exactly one Proved event");
    }

    // ---------------------------------------------------------------
    // Test Case 2: Same Proposal & Parent - Duplicate Detection
    // ---------------------------------------------------------------

    /// @notice Tests duplicate transition record detection
    /// @dev Second branch: recordHash == _recordHash, should emit TransitionDuplicateDetected
    function test_storeTransitionRecord_duplicateDetection() public {
        // Create and propose a new proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create prove input
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();

        // First prove - should succeed
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Get the stored record hash for verification
        (, bytes26 firstRecordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());

        // Expect TransitionDuplicateDetected event on second prove
        vm.expectEmit(true, true, true, true);
        emit IInbox.TransitionDuplicateDetected();

        // Second prove with identical data - should detect duplicate
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Verify the record hash is unchanged
        (, bytes26 secondRecordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());
        assertEq(secondRecordHash, firstRecordHash, "Record hash should remain unchanged");
    }

    // ---------------------------------------------------------------
    // Test Case 3: Same Proposal & Parent - Conflict Detection
    // ---------------------------------------------------------------

    /// @notice Tests conflicting transition record detection
    /// @dev Third branch: recordHash != _recordHash, should emit TransitionConflictDetected
    function test_storeTransitionRecord_conflictDetection() public {
        // Create and propose a new proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create first prove input
        bytes memory proveData1 = _createProveInput(proposal);
        bytes memory proof1 = _createValidProof();

        // First prove - should succeed
        vm.prank(currentProver);
        inbox.prove(proveData1, proof1);

        // Get the stored deadline before conflict
        (, bytes26 firstRecordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());

        // Create second prove input with different checkpoint (causes conflict)
        IInbox.Transition memory transition = _createTransitionForProposal(proposal);
        transition.checkpoint.stateRoot = bytes32(uint256(999)); // Different state root

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = _createMetadataForTransition(currentProver, currentProver);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        bytes memory proveData2 = _codec().encodeProveInput(input);
        bytes memory proof2 = _createValidProof();

        // Expect TransitionConflictDetected event
        vm.expectEmit(true, true, true, true);
        emit IInbox.TransitionConflictDetected();

        // Second prove with conflicting data
        vm.prank(currentProver);
        inbox.prove(proveData2, proof2);

        // Verify conflict state was set
        assertTrue(inbox.conflictingTransitionDetected(), "Conflict flag should be set");

        // Verify finalization deadline was set to max
        (uint48 conflictDeadline, bytes26 conflictRecordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());
        assertEq(conflictDeadline, type(uint48).max, "Deadline should be set to max on conflict");
        assertEq(
            conflictRecordHash,
            firstRecordHash,
            "Original record hash should remain (not overwritten)"
        );
    }

    // ---------------------------------------------------------------
    // Test Case 4: Multiple Sequential Stores
    // ---------------------------------------------------------------

    /// @notice Tests storing multiple transition records sequentially
    /// @dev Verifies each new proposal ID stores independently
    function test_storeTransitionRecord_multipleSequentialStores() public {
        uint256 numProposals = 5;
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

        // Create and prove multiple proposals
        for (uint256 i = 0; i < numProposals; i++) {
            if (i == 0) {
                proposals[i] = _proposeAndGetProposal();
            } else {
                vm.warp(block.timestamp + 12);
                proposals[i] = _proposeConsecutiveProposal(proposals[i - 1]);
            }

            // Prove each proposal
            bytes memory proveData = _createProveInputForSingleProposal(proposals[i], i);
            bytes memory proof = _createValidProof();

            vm.prank(currentProver);
            inbox.prove(proveData, proof);

            // Verify each was stored correctly
            bytes32 parentHash =
                i == 0 ? _getGenesisTransitionHash() : _computeTransitionHash(i - 1);
            (, bytes26 recordHash) = inbox.getTransitionRecordHash(proposals[i].id, parentHash);
            assertTrue(recordHash != bytes26(0), "Each proposal should have stored record");
        }
    }

    // ---------------------------------------------------------------
    // Test Case 5: Same Proposal ID with Different Parent Hashes
    // ---------------------------------------------------------------

    /// @notice Tests storing transitions for same proposal but different parent transitions
    /// @dev This tests the composite key mapping functionality
    function test_storeTransitionRecord_sameProposalDifferentParents() public {
        // Create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create first transition with genesis parent
        bytes32 parent1 = _getGenesisTransitionHash();
        bytes memory proveData1 = _createProveInputWithParent(proposal, parent1);
        bytes memory proof1 = _createValidProof();

        vm.prank(currentProver);
        inbox.prove(proveData1, proof1);

        // Verify first record was stored
        (, bytes26 recordHash1) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertTrue(recordHash1 != bytes26(0), "First record should be stored");

        // Create second transition with different parent hash
        bytes32 parent2 = keccak256("different_parent");
        bytes memory proveData2 = _createProveInputWithParent(proposal, parent2);
        bytes memory proof2 = _createValidProof();

        vm.prank(currentProver);
        inbox.prove(proveData2, proof2);

        // Verify second record was stored independently
        (, bytes26 recordHash2) = inbox.getTransitionRecordHash(proposal.id, parent2);
        assertTrue(recordHash2 != bytes26(0), "Second record should be stored");

        // Verify both records exist and are different
        assertTrue(recordHash1 != recordHash2, "Records should be different for different parents");

        // Verify first record is still intact
        (, bytes26 recordHash1Again) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertEq(recordHash1Again, recordHash1, "First record should remain unchanged");
    }

    // ---------------------------------------------------------------
    // Test Case 6: Conflict After Multiple Valid Stores
    // ---------------------------------------------------------------

    /// @notice Tests conflict detection after multiple valid stores
    function test_storeTransitionRecord_conflictAfterMultipleStores() public {
        // Create multiple proposals
        IInbox.Proposal memory proposal1 = _proposeAndGetProposal();

        vm.warp(block.timestamp + 12);
        IInbox.Proposal memory proposal2 = _proposeConsecutiveProposal(proposal1);

        // Prove proposal1 successfully
        bytes memory proveData1 = _createProveInputForSingleProposal(proposal1, 0);
        vm.prank(currentProver);
        inbox.prove(proveData1, _createValidProof());

        // Prove proposal2 successfully
        bytes memory proveData2 = _createProveInputForSingleProposal(proposal2, 1);
        vm.prank(currentProver);
        inbox.prove(proveData2, _createValidProof());

        // Now create conflicting proof for proposal1
        IInbox.Transition memory conflictingTransition = _createTransitionForProposal(proposal1);
        conflictingTransition.checkpoint.stateRoot = bytes32(uint256(999));

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = conflictingTransition;

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = _createMetadataForTransition(currentProver, currentProver);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal1;

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        bytes memory conflictingProveData = _codec().encodeProveInput(input);

        // Expect conflict detection
        vm.expectEmit(true, true, true, true);
        emit IInbox.TransitionConflictDetected();

        vm.prank(currentProver);
        inbox.prove(conflictingProveData, _createValidProof());

        // Verify conflict flag is set
        assertTrue(inbox.conflictingTransitionDetected(), "Conflict should be detected");

        // Verify proposal2's record is unaffected
        (, bytes26 proposal2RecordHash) =
            inbox.getTransitionRecordHash(proposal2.id, _computeTransitionHash(0));
        assertTrue(proposal2RecordHash != bytes26(0), "Proposal2 record should remain valid");
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    function _proposeAndGetProposal() internal returns (IInbox.Proposal memory) {
        _setupBlobHashes();

        if (block.number < 2) {
            vm.roll(2);
        }
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(1, 1, 0, currentProposer);

        return expectedPayload.proposal;
    }

    function _proposeConsecutiveProposal(IInbox.Proposal memory _parent)
        internal
        returns (IInbox.Proposal memory)
    {
        uint48 expectedLastBlockId;
        if (_parent.id == 0) {
            expectedLastBlockId = 1;
            vm.roll(2);
        } else {
            vm.roll(block.number + 1);
            expectedLastBlockId = uint48(block.number - 1);
        }

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _parent.id + 1,
            lastProposalBlockId: expectedLastBlockId,
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _parent;

        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _createProposeInputWithCustomParams(
                    0, _createBlobRef(0, 1, 0), parentProposals, coreState
                )
            );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(_parent.id + 1, 1, 0, currentProposer);

        return expectedPayload.proposal;
    }

    function _createProveInput(IInbox.Proposal memory _proposal)
        internal
        view
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = _createTransitionForProposal(_proposal);

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = _createMetadataForTransition(currentProver, currentProver);

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        return _codec().encodeProveInput(input);
    }

    function _createProveInputForSingleProposal(
        IInbox.Proposal memory _proposal,
        uint256 _index
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 parentHash =
            _index == 0 ? _getGenesisTransitionHash() : _computeTransitionHash(_index - 1);

        return _createProveInputWithParent(_proposal, parentHash);
    }

    function _createProveInputWithParent(
        IInbox.Proposal memory _proposal,
        bytes32 _parentHash
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Transition memory transition = _createTransitionForProposal(_proposal);
        transition.parentTransitionHash = _parentHash;

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = _createMetadataForTransition(currentProver, currentProver);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        return _codec().encodeProveInput(input);
    }

    function _createTransitionForProposal(IInbox.Proposal memory _proposal)
        internal
        view
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _codec().hashProposal(_proposal),
            parentTransitionHash: _getGenesisTransitionHash(),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(200))
            })
        });
    }

    function _createMetadataForTransition(
        address designatedProver,
        address actualProver
    )
        internal
        pure
        returns (IInbox.TransitionMetadata memory)
    {
        return IInbox.TransitionMetadata({
            designatedProver: designatedProver, actualProver: actualProver
        });
    }

    function _createValidProof() internal pure returns (bytes memory) {
        return abi.encode("valid_proof");
    }

    function _computeTransitionHash(uint256 _index) internal pure returns (bytes32) {
        // Simplified - would need actual transition data in real scenario
        return keccak256(abi.encode("transition", _index));
    }

    function _countProvedEvents(Vm.Log[] memory logs) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proved(bytes)")) {
                count++;
            }
        }
    }
}
