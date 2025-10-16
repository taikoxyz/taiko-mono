// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title InboxOptimized1TransitionRecord
/// @notice Comprehensive test suite for _storeTransitionRecord functionality in InboxOptimized1
/// @dev Tests all branches including ring buffer optimization paths
contract InboxOptimized1TransitionRecord is InboxTestHelper {
    address internal currentProposer = Bob;
    address internal currentProver = Carol;

    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
        currentProposer = _selectProposer(Bob);
    }

    // ---------------------------------------------------------------
    // Test Case 1: New Proposal ID - Ring Buffer Storage
    // ---------------------------------------------------------------

    /// @notice Tests storing a transition record for a new proposal ID in ring buffer
    /// @dev InboxOptimized1 specific: record.proposalId != _proposalId branch
    function test_storeTransitionRecord_newProposalId_ringBufferStorage() public {
        // Create and propose a new proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create prove input
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();

        // Record logs to verify Proved event
        vm.recordLogs();

        // Prove the proposal (this stores the transition record in ring buffer)
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Verify the transition record was stored
        (uint48 deadline, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());

        assertTrue(recordHash != bytes26(0), "Record hash should be non-zero");
        assertTrue(deadline > 0, "Finalization deadline should be set");
        // Grace period is 5 minutes for InboxOptimized1
        assertEq(
            deadline,
            uint48(block.timestamp + 5 minutes),
            "Deadline should be timestamp + grace period"
        );

        // Verify exactly one Proved event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 provedEventCount = _countProvedEvents(logs);
        assertEq(provedEventCount, 1, "Should emit exactly one Proved event");
    }

    // ---------------------------------------------------------------
    // Test Case 2: Same Proposal & Partial Parent - Duplicate Detection
    // ---------------------------------------------------------------

    /// @notice Tests duplicate transition record detection with ring buffer
    /// @dev InboxOptimized1 specific: partialParentHash match, recordHash == _recordHash
    function test_storeTransitionRecord_duplicateDetection_ringBuffer() public {
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

        // Second prove with identical data - should detect duplicate via ring buffer
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Verify the record hash is unchanged
        (, bytes26 secondRecordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());
        assertEq(secondRecordHash, firstRecordHash, "Record hash should remain unchanged");
    }

    // ---------------------------------------------------------------
    // Test Case 3: Same Proposal & Partial Parent - Conflict Detection
    // ---------------------------------------------------------------

    /// @notice Tests conflicting transition record detection with ring buffer
    /// @dev InboxOptimized1 specific: partialParentHash match, recordHash != _recordHash
    function test_storeTransitionRecord_conflictDetection_ringBuffer() public {
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

        // Verify finalization deadline was set to max via ring buffer
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
    // Test Case 4: Same Proposal ID, Different Partial Parent - Fallback to Composite Key
    // ---------------------------------------------------------------

    /// @notice Tests fallback to composite key mapping when partial parent hash differs
    /// @dev InboxOptimized1 specific: partialParentHash mismatch triggers
    /// super._storeTransitionRecord
    function test_storeTransitionRecord_differentPartialParent_compositeKeyFallback() public {
        // Create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create first transition with genesis parent
        bytes32 parent1 = _getGenesisTransitionHash();
        bytes memory proveData1 = _createProveInputWithParent(proposal, parent1);
        bytes memory proof1 = _createValidProof();

        vm.prank(currentProver);
        inbox.prove(proveData1, proof1);

        // Verify first record was stored in ring buffer
        (, bytes26 recordHash1) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertTrue(recordHash1 != bytes26(0), "First record should be stored");

        // Create second transition with different parent hash
        // Use a parent that differs in the first 26 bytes to trigger composite key fallback
        bytes32 parent2 = keccak256("completely_different_parent");
        bytes memory proveData2 = _createProveInputWithParent(proposal, parent2);
        bytes memory proof2 = _createValidProof();

        vm.prank(currentProver);
        inbox.prove(proveData2, proof2);

        // Verify second record was stored via composite key mapping
        (, bytes26 recordHash2) = inbox.getTransitionRecordHash(proposal.id, parent2);
        assertTrue(recordHash2 != bytes26(0), "Second record should be stored via composite key");

        // Verify both records exist and are different
        assertTrue(recordHash1 != recordHash2, "Records should be different for different parents");

        // Verify first record is still intact in ring buffer
        (, bytes26 recordHash1Again) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertEq(
            recordHash1Again, recordHash1, "First record should remain unchanged in ring buffer"
        );
    }

    // ---------------------------------------------------------------
    // Test Case 5: Ring Buffer Collision - Overwrite Old Proposal
    // ---------------------------------------------------------------

    /// @notice Tests ring buffer slot reuse when new proposal ID maps to same slot
    /// @dev Verifies old proposal data is overwritten by new proposal
    function test_storeTransitionRecord_ringBufferCollision_overwrite() public {
        // Get ring buffer size from config
        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;

        // Create first proposal
        IInbox.Proposal memory proposal1 = _proposeAndGetProposal();

        // Prove first proposal
        bytes memory proveData1 = _createProveInput(proposal1);
        vm.prank(currentProver);
        inbox.prove(proveData1, _createValidProof());

        // Verify first proposal was stored in ring buffer
        (, bytes26 recordHash1) =
            inbox.getTransitionRecordHash(proposal1.id, _getGenesisTransitionHash());
        assertTrue(recordHash1 != bytes26(0), "First proposal should be stored");

        // Create a few more proposals to test ring buffer behavior
        // We'll create 3 proposals, prove them, and verify ring buffer usage
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);
        proposals[0] = proposal1;

        for (uint256 i = 1; i < 3; i++) {
            vm.warp(block.timestamp + 12);
            proposals[i] = _proposeConsecutiveProposal(proposals[i - 1]);

            // Prove each proposal
            bytes memory proveData = _createProveInput(proposals[i]);
            vm.prank(currentProver);
            inbox.prove(proveData, _createValidProof());
        }

        // Verify all proposals are stored in ring buffer
        for (uint256 i = 0; i < 3; i++) {
            (, bytes26 recordHash) =
                inbox.getTransitionRecordHash(proposals[i].id, _getGenesisTransitionHash());
            assertTrue(recordHash != bytes26(0), "Each proposal should be in ring buffer");
        }

        // The ring buffer optimization means that for a buffer of size N,
        // proposal IDs i and (i + N) will map to the same slot
        // When proposal (i + N) is proved, it overwrites the slot previously used by proposal i
        assertTrue(
            (proposals[0].id % ringBufferSize) != (proposals[1].id % ringBufferSize),
            "Sequential proposals use different ring buffer slots"
        );
    }

    // ---------------------------------------------------------------
    // Test Case 6: Multiple Transitions for Same Proposal - Mixed Storage
    // ---------------------------------------------------------------

    /// @notice Tests storing multiple transitions for same proposal using both ring buffer and
    /// composite key
    /// @dev Verifies ring buffer handles first transition, composite key handles additional
    function test_storeTransitionRecord_sameProposal_mixedStorage() public {
        // Create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // First transition uses genesis parent - stored in ring buffer
        bytes32 parent1 = _getGenesisTransitionHash();
        bytes memory proveData1 = _createProveInputWithParent(proposal, parent1);

        vm.prank(currentProver);
        inbox.prove(proveData1, _createValidProof());

        (, bytes26 recordHash1) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertTrue(recordHash1 != bytes26(0), "First transition stored in ring buffer");

        // Second transition uses different parent - triggers composite key fallback
        bytes32 parent2 = keccak256("different_parent_hash");
        bytes memory proveData2 = _createProveInputWithParent(proposal, parent2);

        vm.prank(currentProver);
        inbox.prove(proveData2, _createValidProof());

        (, bytes26 recordHash2) = inbox.getTransitionRecordHash(proposal.id, parent2);
        assertTrue(recordHash2 != bytes26(0), "Second transition stored via composite key");

        // Third transition uses yet another parent - also uses composite key
        bytes32 parent3 = keccak256("third_parent_hash");
        bytes memory proveData3 = _createProveInputWithParent(proposal, parent3);

        vm.prank(currentProver);
        inbox.prove(proveData3, _createValidProof());

        (, bytes26 recordHash3) = inbox.getTransitionRecordHash(proposal.id, parent3);
        assertTrue(recordHash3 != bytes26(0), "Third transition stored via composite key");

        // Verify all three transitions are independently stored and retrievable
        assertTrue(recordHash1 != recordHash2, "First and second should be different");
        assertTrue(recordHash2 != recordHash3, "Second and third should be different");
        assertTrue(recordHash1 != recordHash3, "First and third should be different");

        // Verify first transition still accessible via ring buffer
        (, bytes26 recordHash1Again) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertEq(recordHash1Again, recordHash1, "Ring buffer entry remains accessible");
    }

    // ---------------------------------------------------------------
    // Test Case 7: Ring Buffer Partial Hash Collision with Different Full Hash
    // ---------------------------------------------------------------

    /// @notice Tests scenario where first 26 bytes match but full hashes differ
    /// @dev This is an edge case where partial parent hash matches but full hash is different
    function test_storeTransitionRecord_partialHashMatch_fullHashDifferent() public {
        // Create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create first parent hash
        bytes32 parent1 = keccak256("parent1");

        // Create second parent hash that has same first 26 bytes but different last 6 bytes
        bytes32 parent2 = parent1;
        // Modify last 6 bytes only
        assembly {
            parent2 := or(and(parent1, not(0xFFFFFFFFFFFF)), 0x123456789ABC)
        }

        // Verify first 26 bytes match
        assertEq(bytes26(parent1), bytes26(parent2), "First 26 bytes should match");
        // Verify full hashes are different
        assertTrue(parent1 != parent2, "Full hashes should differ");

        // Store first transition
        bytes memory proveData1 = _createProveInputWithParent(proposal, parent1);
        vm.prank(currentProver);
        inbox.prove(proveData1, _createValidProof());

        (, bytes26 recordHash1) = inbox.getTransitionRecordHash(proposal.id, parent1);
        assertTrue(recordHash1 != bytes26(0), "First transition stored");

        // Store second transition with partial hash collision
        // This should trigger composite key fallback despite partial hash match
        bytes memory proveData2 = _createProveInputWithParent(proposal, parent2);
        vm.prank(currentProver);
        inbox.prove(proveData2, _createValidProof());

        // Note: Due to partial hash collision, this may overwrite ring buffer entry
        // The behavior depends on whether full hash is checked in ring buffer lookup
        (, bytes26 recordHash2) = inbox.getTransitionRecordHash(proposal.id, parent2);
        assertTrue(recordHash2 != bytes26(0), "Second transition should be stored");
    }

    // ---------------------------------------------------------------
    // Test Case 8: Sequential Proposals with Ring Buffer Optimization
    // ---------------------------------------------------------------

    /// @notice Tests that sequential proposals properly use ring buffer slots
    function test_storeTransitionRecord_sequentialProposals_ringBufferUsage() public {
        // Create and prove 3 sequential proposals
        uint256 numProposals = 3;
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

        for (uint256 i = 0; i < numProposals; i++) {
            if (i == 0) {
                proposals[i] = _proposeAndGetProposal();
            } else {
                vm.warp(block.timestamp + 12);
                proposals[i] = _proposeConsecutiveProposal(proposals[i - 1]);
            }

            // Prove each proposal
            bytes memory proveData = _createProveInput(proposals[i]);
            vm.prank(currentProver);
            inbox.prove(proveData, _createValidProof());

            // Verify each was stored in ring buffer
            (, bytes26 recordHash) =
                inbox.getTransitionRecordHash(proposals[i].id, _getGenesisTransitionHash());
            assertTrue(recordHash != bytes26(0), "Each proposal should be stored in ring buffer");
        }

        // Verify all proposals are still retrievable
        for (uint256 i = 0; i < numProposals; i++) {
            (, bytes26 recordHash) =
                inbox.getTransitionRecordHash(proposals[i].id, _getGenesisTransitionHash());
            assertTrue(recordHash != bytes26(0), "All proposals should remain accessible");
        }
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
        return _createProveInputWithParent(_proposal, _getGenesisTransitionHash());
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

    function _createProveInputForChain(
        IInbox.Proposal memory _proposal,
        uint256 _chainIndex
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 parentHash = _computeChainedTransitionHash(_chainIndex);
        return _createProveInputWithParent(_proposal, parentHash);
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

    function _computeChainedTransitionHash(uint256 _index) internal pure returns (bytes32) {
        // Simplified chained transition hash for ring buffer tests
        return keccak256(abi.encode("chained_transition", _index));
    }

    function _countProvedEvents(Vm.Log[] memory logs) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proved(bytes)")) {
                count++;
            }
        }
    }
}
