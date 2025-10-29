// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

// Import errors from Inbox implementation
import "src/layer1/core/impl/Inbox.sol";

/// @title AbstractProveTest
/// @notice All prove tests for Inbox implementations
abstract contract AbstractProveTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address internal currentProposer = Bob;
    address internal currentProver = Carol;
    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        // Select a proposer for creating proposals to prove
        currentProposer = _selectProposer(Bob);
    }

    // ---------------------------------------------------------------
    // Main prove tests with gas snapshot
    // ---------------------------------------------------------------

    /// @dev Tests proving a single proposal - baseline gas measurement
    /// forge-config: default.isolate = true
    function test_prove_singleProposal() public {
        // First create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create prove input for this proposal
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();

        // Record events to verify count later
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_single_", inboxContractName));
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Verify transition record is stored
        (, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());
        assertTrue(recordHash != bytes32(0), "Transition record should be stored");

        // Verify exactly one Proved event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, 1, "Should emit exactly one Proved event");
    }

    /// @dev Tests proving 2 consecutive proposals - optimized implementations should aggregate into
    /// 1 event
    /// forge-config: default.isolate = true
    function test_prove_twoConsecutiveProposals() public {
        // Create 2 consecutive proposals
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(2);

        // Create prove input
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        // Check expected events based on implementation
        (uint256 expectedEvents,) = _getExpectedAggregationBehavior(2, true);

        // Record events to verify count later
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas(
            "shasta-prove", string.concat("prove_consecutive_2_", inboxContractName)
        );
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Verify all proposals were proven

        // Verify correct number of events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, expectedEvents, "Unexpected number of Proved events");
    }

    /// @dev Tests proving 3 consecutive proposals - demonstrates gas efficiency of aggregation
    /// forge-config: default.isolate = true
    function test_prove_threeConsecutiveProposals() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(3);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        // Check expected events based on implementation
        (uint256 expectedEvents,) = _getExpectedAggregationBehavior(3, true);

        // Record events to verify count later
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas(
            "shasta-prove", string.concat("prove_consecutive_3_", inboxContractName)
        );
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Verify correct number of events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, expectedEvents, "Unexpected number of Proved events");
    }

    /// @dev Tests proving 5 consecutive proposals - maximum aggregation benefit measurement
    /// forge-config: default.isolate = true
    function test_prove_fiveConsecutiveProposals() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(5);
        bytes memory proveData = _createProveInputForMultipleProposals(proposals, true);
        bytes memory proof = _createValidProof();

        // Check expected events based on implementation
        (uint256 expectedEvents,) = _getExpectedAggregationBehavior(5, true);

        // Record events to verify count later
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas(
            "shasta-prove", string.concat("prove_consecutive_5_", inboxContractName)
        );
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Verify correct number of events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, expectedEvents, "Unexpected number of Proved events");
    }

    /// @dev Tests proving non-consecutive proposals with single gap [1,3] - no aggregation possible
    /// forge-config: default.isolate = true
    function test_prove_nonConsecutive_singleGap() public {
        // Create proposals 1,2,3 but prove only 1 and 3
        uint8[] memory indices = new uint8[](2);
        indices[0] = 1;
        indices[1] = 3;
        IInbox.Proposal[] memory proposals = _createProposalsWithGaps(indices);

        bytes memory proveData = _createProveInputForMultipleProposals(proposals, false);
        bytes memory proof = _createValidProof();

        // Record events to verify count
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_gaps_1_", inboxContractName));
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Should have 2 separate events (no aggregation for gaps)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, 2, "Should emit 2 events for non-consecutive");
    }

    /// @dev Tests proving non-consecutive proposals with multiple gaps [1,3,5] - measures
    /// individual proving
    /// forge-config: default.isolate = true
    function test_prove_nonConsecutive_multipleGaps() public {
        // Create proposals 1,2,3,4,5 but prove 1,3,5
        uint8[] memory indices = new uint8[](3);
        indices[0] = 1;
        indices[1] = 3;
        indices[2] = 5;
        IInbox.Proposal[] memory proposals = _createProposalsWithGaps(indices);

        bytes memory proveData = _createProveInputForMultipleProposals(proposals, false);
        bytes memory proof = _createValidProof();

        // Record events to verify count
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_gaps_2_", inboxContractName));
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Should have 3 separate events (no aggregation for gaps)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, 3, "Should emit 3 events for non-consecutive");
    }

    /// @dev Tests mixed scenario [1,2,4,5,6] with consecutive groups and gaps - partial aggregation
    /// forge-config: default.isolate = true
    function test_prove_mixed_consecutiveAndGaps() public {
        // Create 1,2,3,4,5,6 but prove 1,2,4,5,6 (consecutive groups with gap)
        uint8[] memory indices = new uint8[](5);
        indices[0] = 1;
        indices[1] = 2;
        indices[2] = 4;
        indices[3] = 5;
        indices[4] = 6;
        IInbox.Proposal[] memory proposals = _createProposalsWithGaps(indices);

        bytes memory proveData = _createProveInputForMultipleProposals(proposals, false);
        bytes memory proof = _createValidProof();

        // Record events to verify count
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_mixed_groups_", inboxContractName));
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Calculate expected events dynamically for mixed scenario [1,2,4,5,6]:
        // Basic implementation: 5 events (one per proposal)
        // Optimized implementations: 2 events (group 1-2 and group 4-6)
        uint256 expectedEvents;
        (uint256 consecutiveEvents,) = _getExpectedAggregationBehavior(2, true); // Test consecutive
        // behavior
        if (consecutiveEvents == 1) {
            // Optimized implementation: supports aggregation
            // Mixed scenario has 2 consecutive groups: [1,2] and [4,5,6]
            expectedEvents = 2;
        } else {
            // Basic implementation: no aggregation, one event per proposal
            expectedEvents = proposals.length; // 5 events
        }
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, expectedEvents, "Unexpected event count for mixed scenario");
    }

    /// @dev Tests proving proposals in reverse order [3,2,1] - no aggregation due to ordering
    /// forge-config: default.isolate = true
    function test_prove_reverseOrder() public {
        // Create 3 proposals but prove them in reverse order [3,2,1]
        IInbox.Proposal[] memory allProposals = _createConsecutiveProposals(3);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);
        proposals[0] = allProposals[2]; // proposal 3
        proposals[1] = allProposals[1]; // proposal 2
        proposals[2] = allProposals[0]; // proposal 1

        bytes memory proveData = _createProveInputForMultipleProposals(proposals, false);
        bytes memory proof = _createValidProof();

        // Record events to verify count
        vm.recordLogs();

        vm.prank(currentProver);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_reverse_", inboxContractName));
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();

        // Should have 3 separate events (reverse order, no aggregation)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);
        assertEq(eventCount, 3, "Should emit 3 events for reverse order");
    }

    // ---------------------------------------------------------------
    // Validation tests
    // ---------------------------------------------------------------

    function test_prove_RevertWhen_EmptyProposals() public {
        // Create empty ProveInput
        IInbox.ProveInput memory input;
        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = _createValidProof();

        // Should revert with EmptyProposals
        vm.expectRevert(Inbox.EmptyProposals.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
    }

    function test_prove_RevertWhen_InconsistentParams() public virtual {
        // Create ProveInput with mismatched array lengths
        IInbox.ProveInput memory input;
        input.proposals = new IInbox.Proposal[](2);
        input.transitions = new IInbox.Transition[](1); // Mismatch!

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = _createValidProof();

        // Should revert with InconsistentParams
        vm.expectRevert(Inbox.InconsistentParams.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
    }

    function test_prove_RevertWhen_ProposalNotFound() public {
        // Create a fake proposal that doesn't exist on-chain
        IInbox.Proposal memory fakeProposal = IInbox.Proposal({
            id: 999,
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(block.timestamp + 12),
            coreStateHash: keccak256("fake"),
            derivationHash: keccak256("fake")
        });

        bytes memory proveData = _createProveInput(fakeProposal);
        bytes memory proof = _createValidProof();

        // Should revert because proposal doesn't exist
        vm.expectRevert();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
    }

    function test_prove_withCustomDesignatedProver() public {
        // Create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();

        // Create transition and metadata with different designated prover
        IInbox.Transition memory transition = _createTransitionForProposal(proposal);
        IInbox.TransitionMetadata memory meta = _createMetadataForTransition(Alice, currentProver);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = meta;

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = _createValidProof();

        // Should succeed with any designated prover
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Verify transition record was stored
        (, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposal.id, _getGenesisTransitionHash());
        assertTrue(recordHash != bytes32(0), "Transition record should be stored");
    }

    // ---------------------------------------------------------------
    // Helper functions for prove input creation
    // ---------------------------------------------------------------

    function _createConsecutiveProposals(uint8 count)
        internal
        returns (IInbox.Proposal[] memory proposals)
    {
        proposals = new IInbox.Proposal[](count);
        for (uint256 i = 0; i < count; i++) {
            if (i == 0) {
                proposals[i] = _proposeAndGetProposal();
            } else {
                // Don't roll here - _proposeConsecutiveProposal handles the rolling
                vm.warp(block.timestamp + 12);
                proposals[i] = _proposeConsecutiveProposal(proposals[i - 1]);
            }
        }
    }

    function _createProposalsWithGaps(uint8[] memory indices)
        internal
        returns (IInbox.Proposal[] memory proposals)
    {
        // Create all proposals sequentially first
        uint8 maxIndex = 0;
        for (uint256 i = 0; i < indices.length; i++) {
            if (indices[i] > maxIndex) maxIndex = indices[i];
        }
        IInbox.Proposal[] memory allProposals = _createConsecutiveProposals(maxIndex);

        // Return only the requested indices
        proposals = new IInbox.Proposal[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) {
            proposals[i] = allProposals[indices[i] - 1];
        }
    }

    function _createProveInputForMultipleProposals(
        IInbox.Proposal[] memory proposals,
        bool consecutive
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](proposals.length);
        IInbox.TransitionMetadata[] memory metadata =
            new IInbox.TransitionMetadata[](proposals.length);

        // Build transitions with proper parent hash chaining
        // For consecutive proposals, chain the transition hashes
        // For non-consecutive, each starts from genesis (or their actual parent in real scenarios)
        bytes32 parentHash = _getGenesisTransitionHash();

        for (uint256 i = 0; i < proposals.length; i++) {
            transitions[i] = _createTransitionForProposal(proposals[i]);
            transitions[i].parentTransitionHash = parentHash;

            // Create metadata for each transition
            metadata[i] = _createMetadataForTransition(Alice, Alice);

            if (consecutive) {
                // Chain transitions for consecutive proposals
                parentHash = keccak256(abi.encode(transitions[i]));
            } else {
                // For non-consecutive, each transition starts from genesis
                // This is simplified - in reality each would have its proper parent
                parentHash = _getGenesisTransitionHash();
            }
        }

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        return _codec().encodeProveInput(input);
    }

    function _countProvedEvents(Vm.Log[] memory logs) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Proved(bytes)")) {
                count++;
            }
        }
    }

    // ---------------------------------------------------------------
    // Virtual functions for implementation-specific behavior
    // ---------------------------------------------------------------

    function _getExpectedAggregationBehavior(
        uint256 proposalCount,
        bool /* consecutive */
    )
        internal
        view
        virtual
        returns (uint256 expectedEvents, uint256 expectedMaxSpan)
    {
        // Default (Basic Inbox): no aggregation
        return (proposalCount, 1);
    }

    function _proposeAndGetProposal() internal returns (IInbox.Proposal memory) {
        _setupBlobHashes();

        // Create and submit proposal
        // For the first proposal, we must be at block >= 2
        // since genesis lastProposalBlockId = 1 (last proposal was made at block 1)
        if (block.number < 2) {
            vm.roll(2);
        }
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Build and return the expected proposal
        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(1, 1, 0, currentProposer);

        return expectedPayload.proposal;
    }

    function _proposeConsecutiveProposal(IInbox.Proposal memory _parent)
        internal
        returns (IInbox.Proposal memory)
    {
        // Build state for consecutive proposal
        // Each proposal sets lastProposalBlockId = block.number
        // Need to roll 1 block forward from the last proposal
        uint48 expectedLastBlockId;
        if (_parent.id == 0) {
            expectedLastBlockId = 1; // Genesis value - last proposal was made at block 1
            // For first proposal after genesis, roll to block 2
            vm.roll(2);
        } else {
            // For subsequent proposals, need 1-block gap
            // Roll forward by 1 block from current position
            vm.roll(block.number + 1);
            // lastProposalBlockId should be the block where the last proposal was made (current -
            // 1)
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
                    0, // no deadline
                    _createBlobRef(0, 1, 0),
                    parentProposals,
                    coreState
                )
            );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Build and return the expected proposal
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
        return _createProveInputForProposals(proposals);
    }

    function _createProveInputForProposals(IInbox.Proposal[] memory _proposals)
        internal
        view
        returns (bytes memory)
    {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](_proposals.length);
        IInbox.TransitionMetadata[] memory metadata =
            new IInbox.TransitionMetadata[](_proposals.length);

        bytes32 parentTransitionHash = _getGenesisTransitionHash();

        for (uint256 i = 0; i < _proposals.length; i++) {
            transitions[i] = _createTransitionForProposal(_proposals[i]);
            transitions[i].parentTransitionHash = parentTransitionHash;
            metadata[i] = _createMetadataForTransition(currentProver, currentProver);

            // Update parent hash for next iteration
            parentTransitionHash = keccak256(abi.encode(transitions[i]));
        }

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: _proposals, transitions: transitions, metadata: metadata
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
        // MockProofVerifier always accepts, so return any non-empty proof
        return abi.encode("valid_proof");
    }
}
