// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBondInstruction } from "src/layer1/core/libs/LibBondInstruction.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

// Import errors from Inbox implementation
import "src/layer1/core/impl/Inbox.sol";

/// @title AbstractFinalizeTest
/// @notice Finalization test suite shared across Inbox implementations
abstract contract AbstractFinalizeTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address internal currentProposer;
    address internal currentProver;

    uint48 internal provingWindow;
    uint48 internal extendedProvingWindow;
    uint48 internal finalizationGracePeriod;
    uint16 internal minCheckpointDelay;
    uint256 internal maxFinalizationCount;

    bytes32 private constant PROPOSED_EVENT_TOPIC = keccak256("Proposed(bytes)");

    struct ProvenProposal {
        IInbox.Proposal proposal;
        IInbox.TransitionRecord record;
        ICheckpointStore.Checkpoint checkpoint;
    }

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        currentProposer = _selectProposer(Bob);
        currentProver = Carol;

        IInbox.Config memory config = inbox.getConfig();
        provingWindow = config.provingWindow;
        extendedProvingWindow = config.extendedProvingWindow;
        finalizationGracePeriod = config.finalizationGracePeriod;
        minCheckpointDelay = config.minCheckpointDelay;
        maxFinalizationCount = config.maxFinalizationCount;
    }

    // ---------------------------------------------------------------
    // Finalization happy path tests
    // ---------------------------------------------------------------

    /// forge-config: default.isolate = true
    function test_finalize_singleProposal() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        ProvenProposal memory proven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    firstPayload.coreState,
                    _buildParentArray(firstPayload.proposal),
                    _wrapSingleRecord(proven.record),
                    proven.checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);

        vm.prank(currentProposer);
        vm.startSnapshotGas("shasta-finalize", _getGasSnapshotName("finalize_single"));
        inbox.propose(bytes(""), proposeData);
        vm.stopSnapshotGas();

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();

        assertEq(finalizedPayload.coreState.lastFinalizedProposalId, proven.proposal.id);
        assertEq(
            finalizedPayload.coreState.lastFinalizedTransitionHash, proven.record.transitionHash
        );
        assertEq(
            finalizedPayload.coreState.bondInstructionsHash,
            _aggregateBondInstructionsHash(proven.record.bondInstructions)
        );
        assertEq(
            finalizedPayload.coreState.lastCheckpointTimestamp,
            uint48(block.timestamp),
            "Checkpoint timestamp should match finalization time"
        );

        ICheckpointStore.Checkpoint memory saved =
            checkpointManager.getCheckpoint(proven.checkpoint.blockNumber);
        assertEq(saved.blockHash, proven.checkpoint.blockHash, "Checkpoint block hash mismatch");
        assertEq(saved.stateRoot, proven.checkpoint.stateRoot, "Checkpoint state root mismatch");
    }

    /// forge-config: default.isolate = true
    function test_finalize_twoProposals() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        ProvenProposal memory firstProven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        IInbox.ProposedEventPayload memory secondPayload = _proposeNext(firstPayload.proposal);
        ProvenProposal memory secondProven = _proveProposal(
            secondPayload.proposal, firstProven.record.transitionHash, currentProver, currentProver
        );

        _setupBlobHashes();
        IInbox.TransitionRecord[] memory records = new IInbox.TransitionRecord[](2);
        records[0] = firstProven.record;
        records[1] = secondProven.record;

        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    secondPayload.coreState,
                    _buildParentArray(secondPayload.proposal),
                    records,
                    secondProven.checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);

        vm.prank(currentProposer);
        vm.startSnapshotGas("shasta-finalize", _getGasSnapshotName("finalize_two"));
        inbox.propose(bytes(""), proposeData);
        vm.stopSnapshotGas();

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();
        assertEq(finalizedPayload.coreState.lastFinalizedProposalId, secondProven.proposal.id);
        assertEq(
            finalizedPayload.coreState.lastFinalizedTransitionHash,
            secondProven.record.transitionHash
        );
    }

    /// forge-config: default.isolate = true
    function test_finalize_multipleProposalsUpToMax() public {
        uint256 proposalCount = maxFinalizationCount + 2;

        IInbox.ProposedEventPayload memory payload = _proposeInitial();
        ProvenProposal[] memory proven = new ProvenProposal[](proposalCount);
        proven[0] = _proveProposal(
            payload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        for (uint256 i = 1; i < proposalCount; ++i) {
            payload = _proposeNext(payload.proposal);
            bytes32 parentHash = proven[i - 1].record.transitionHash;
            proven[i] = _proveProposal(payload.proposal, parentHash, currentProver, currentProver);
        }

        _setupBlobHashes();
        IInbox.TransitionRecord[] memory records = new IInbox.TransitionRecord[](proposalCount);
        for (uint256 i = 0; i < proposalCount; ++i) {
            records[i] = proven[i].record;
        }

        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    payload.coreState,
                    _buildParentArray(payload.proposal),
                    records,
                    proven[maxFinalizationCount - 1].checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);

        vm.prank(currentProposer);
        vm.startSnapshotGas(
            "shasta-finalize", _getGasSnapshotName(_labelForFinalizedCount(maxFinalizationCount))
        );
        inbox.propose(bytes(""), proposeData);
        vm.stopSnapshotGas();

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();
        uint48 expectedLastId = uint48(proven[maxFinalizationCount - 1].proposal.id);

        assertEq(finalizedPayload.coreState.lastFinalizedProposalId, expectedLastId);
        assertEq(
            finalizedPayload.coreState.lastFinalizedTransitionHash,
            proven[maxFinalizationCount - 1].record.transitionHash
        );

        (uint48 deadline, bytes26 recordHash) = inbox.getTransitionRecordHash(
            proven[maxFinalizationCount].proposal.id,
            proven[maxFinalizationCount - 1].record.transitionHash
        );
        assertTrue(recordHash != bytes26(0), "Next transition record should remain stored");
        assertTrue(deadline > 0, "Next transition record should keep original deadline");
    }

    /// forge-config: default.isolate = true
    function test_finalize_processesBondInstructions() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();

        address designatedProver = currentProver;
        address actualProver = David;
        vm.warp(firstPayload.proposal.timestamp + provingWindow + 1);

        ProvenProposal memory proven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), designatedProver, actualProver
        );
        assertGt(proven.record.bondInstructions.length, 0, "Expected non-empty bond instructions");

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    firstPayload.coreState,
                    _buildParentArray(firstPayload.proposal),
                    _wrapSingleRecord(proven.record),
                    proven.checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);

        vm.prank(currentProposer);
        vm.startSnapshotGas("shasta-finalize", _getGasSnapshotName("finalize_bonds"));
        inbox.propose(bytes(""), proposeData);
        vm.stopSnapshotGas();

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();
        bytes32 expectedHash = _aggregateBondInstructionsHash(proven.record.bondInstructions);
        assertEq(finalizedPayload.coreState.bondInstructionsHash, expectedHash);
    }

    function test_finalize_stopsWhenProposalNotProven() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        ProvenProposal memory firstProven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        IInbox.ProposedEventPayload memory secondPayload = _proposeNext(firstPayload.proposal);

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    secondPayload.coreState,
                    _buildParentArray(secondPayload.proposal),
                    _wrapSingleRecord(firstProven.record),
                    firstProven.checkpoint
                )
            );

        vm.recordLogs();
        vm.roll(block.number + 1);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory finalizedPayload = _decodeLastProposedEvent();
        assertEq(finalizedPayload.coreState.lastFinalizedProposalId, firstProven.proposal.id);
        assertEq(
            finalizedPayload.coreState.lastFinalizedTransitionHash,
            firstProven.record.transitionHash
        );

        (uint48 deadline, bytes26 recordHash) = inbox.getTransitionRecordHash(
            secondPayload.proposal.id, firstProven.record.transitionHash
        );
        assertEq(recordHash, bytes26(0), "Unproven proposal should not have a record");
        assertEq(deadline, 0, "Unproven proposal should not have a deadline");
    }

    // ---------------------------------------------------------------
    // Finalization error path tests
    // ---------------------------------------------------------------

    function test_finalize_RevertWhen_TransitionRecordHashMismatch() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        ProvenProposal memory proven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        IInbox.TransitionRecord memory tampered = proven.record;
        tampered.transitionHash = keccak256("mismatch");

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    firstPayload.coreState,
                    _buildParentArray(firstPayload.proposal),
                    _wrapSingleRecord(tampered),
                    proven.checkpoint
                )
            );

        vm.expectRevert(Inbox.TransitionRecordHashMismatchWithStorage.selector);
        vm.roll(block.number + 1);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_finalize_RevertWhen_TransitionRecordNotProvidedAfterGracePeriod() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        vm.warp(block.timestamp + finalizationGracePeriod + 1);

        _setupBlobHashes();
        IInbox.ProposeInput memory input = _buildFinalizeInput(
            firstPayload.coreState,
            _buildParentArray(firstPayload.proposal),
            new IInbox.TransitionRecord[](0),
            ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 })
        );

        bytes memory proposeData = _codec().encodeProposeInput(input);

        vm.expectRevert(Inbox.TransitionRecordNotProvided.selector);
        vm.roll(block.number + 1);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_finalize_RevertWhen_CheckpointMismatch() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        ProvenProposal memory proven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        ICheckpointStore.Checkpoint memory wrongCheckpoint = proven.checkpoint;
        wrongCheckpoint.stateRoot = bytes32(uint256(123_456));

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    firstPayload.coreState,
                    _buildParentArray(firstPayload.proposal),
                    _wrapSingleRecord(proven.record),
                    wrongCheckpoint
                )
            );

        vm.expectRevert(Inbox.CheckpointMismatch.selector);
        vm.roll(block.number + 1);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_finalize_RevertWhen_CheckpointNotProvided() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeInitial();
        ProvenProposal memory proven = _proveProposal(
            firstPayload.proposal, _getGenesisTransitionHash(), currentProver, currentProver
        );

        _setupBlobHashes();
        bytes memory proposeData = _codec()
            .encodeProposeInput(
                _buildFinalizeInput(
                    firstPayload.coreState,
                    _buildParentArray(firstPayload.proposal),
                    _wrapSingleRecord(proven.record),
                    ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 })
                )
            );

        vm.expectRevert(Inbox.CheckpointNotProvided.selector);
        vm.roll(block.number + 1);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    function _proposeInitial() internal returns (IInbox.ProposedEventPayload memory payload) {
        _setupBlobHashes();
        if (block.number < 2) {
            vm.roll(2);
        }

        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        payload = _decodeLastProposedEvent();
    }

    function _proposeNext(IInbox.Proposal memory parent)
        internal
        returns (IInbox.ProposedEventPayload memory payload)
    {
        _setupBlobHashes();

        uint48 expectedLastBlockId;
        if (parent.id == 0) {
            expectedLastBlockId = 1;
            vm.roll(2);
        } else {
            vm.roll(block.number + 1);
            expectedLastBlockId = uint48(block.number - 1);
        }

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: parent.id + 1,
            lastProposalBlockId: expectedLastBlockId,
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = parent;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: _createBlobRef(0, 1, 0),
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            numForcedInclusions: 0
        });

        bytes memory proposeData = _codec().encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        payload = _decodeLastProposedEvent();
    }

    function _proveProposal(
        IInbox.Proposal memory proposal,
        bytes32 parentTransitionHash,
        address designatedProver,
        address actualProver
    )
        internal
        returns (ProvenProposal memory result)
    {
        IInbox.Transition memory transition = _createTransitionForProposal(proposal);
        transition.parentTransitionHash = parentTransitionHash;

        IInbox.TransitionMetadata memory metadata =
            _createMetadataForTransition(designatedProver, actualProver);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;

        IInbox.TransitionMetadata[] memory metadataArr = new IInbox.TransitionMetadata[](1);
        metadataArr[0] = metadata;

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadataArr
        });

        IInbox.TransitionRecord memory record;
        record.span = 1;
        record.bondInstructions = LibBondInstruction.calculateBondInstructions(
            provingWindow, extendedProvingWindow, proposal, metadata
        );
        record.transitionHash = _codec().hashTransition(transition);
        record.checkpointHash = _codec().hashCheckpoint(transition.checkpoint);

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = _createValidProof();

        vm.prank(actualProver);
        inbox.prove(proveData, proof);

        result = ProvenProposal({
            proposal: proposal, record: record, checkpoint: transition.checkpoint
        });
    }

    function _buildFinalizeInput(
        IInbox.CoreState memory coreState,
        IInbox.Proposal[] memory parentProposals,
        IInbox.TransitionRecord[] memory records,
        ICheckpointStore.Checkpoint memory checkpoint
    )
        internal
        pure
        returns (IInbox.ProposeInput memory)
    {
        return IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: _createBlobRef(0, 1, 0),
            transitionRecords: records,
            checkpoint: checkpoint,
            numForcedInclusions: 0
        });
    }

    function _buildParentArray(IInbox.Proposal memory parent)
        internal
        pure
        returns (IInbox.Proposal[] memory parents)
    {
        parents = new IInbox.Proposal[](1);
        parents[0] = parent;
    }

    function _wrapSingleRecord(IInbox.TransitionRecord memory record)
        internal
        pure
        returns (IInbox.TransitionRecord[] memory records)
    {
        records = new IInbox.TransitionRecord[](1);
        records[0] = record;
    }

    function _aggregateBondInstructionsHash(LibBonds.BondInstruction[] memory instructions)
        internal
        pure
        returns (bytes32 hash)
    {
        for (uint256 i = 0; i < instructions.length; ++i) {
            hash = LibBonds.aggregateBondInstruction(hash, instructions[i]);
        }
    }

    function _decodeLastProposedEvent()
        internal
        returns (IInbox.ProposedEventPayload memory payload)
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = logs.length; i > 0; --i) {
            Vm.Log memory entry = logs[i - 1];
            if (entry.topics.length > 0 && entry.topics[0] == PROPOSED_EVENT_TOPIC) {
                bytes memory eventData = abi.decode(entry.data, (bytes));
                return _codec().decodeProposedEvent(eventData);
            }
        }

        revert("Proposed event not found");
    }

    function _createTransitionForProposal(IInbox.Proposal memory proposal)
        internal
        view
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _codec().hashProposal(proposal),
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

    function _labelForFinalizedCount(uint256 count) private pure returns (string memory) {
        return string.concat("finalize_", Strings.toString(count));
    }

    function _createValidProof() internal pure returns (bytes memory) {
        return abi.encode("valid_proof");
    }
}
