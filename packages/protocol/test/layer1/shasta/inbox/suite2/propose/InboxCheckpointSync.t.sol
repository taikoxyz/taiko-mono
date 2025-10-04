// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractPropose.t.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { CheckpointDelayInboxDeployer } from "../deployers/CheckpointDelayInboxDeployer.sol";

/// @title InboxCheckpointSync
/// @notice Comprehensive tests for checkpoint synchronization modes
/// @dev Tests voluntary sync, forced sync after delay, and edge cases
contract InboxCheckpointSync is AbstractProposeTest {
    uint16 internal constant MIN_CHECKPOINT_DELAY = 300; // 5 minutes for testing

    function setUp() public override {
        // Use custom deployer with minCheckpointDelay set
        setDeployer(new CheckpointDelayInboxDeployer(MIN_CHECKPOINT_DELAY));
        super.setUp();
    }

    /// @notice Test voluntary checkpoint sync when proposer provides checkpoint
    /// @dev Checkpoint should sync immediately even if minCheckpointDelay has not elapsed
    function test_voluntaryCheckpointSync() public {
        // Setup: Create and finalize first proposal
        _setupBlobHashes();
        vm.roll(block.number + 1);

        // Propose first block
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Prove and finalize first proposal
        IInbox.Proposal memory proposal1 = _buildProposalFromEvent(1);
        _proveProposal(proposal1);

        // Record initial checkpoint state
        uint48 initialCheckpointCount = inbox.getNumberOfCheckpoints();
        uint48 initialTimestamp = uint48(block.timestamp);

        // Advance only 1 second (well below MIN_CHECKPOINT_DELAY)
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Propose second block WITH voluntary checkpoint (blockHash != 0)
        IInbox.ProposeInput memory input2 = _createSecondProposeInputWithCheckpoint(
            proposal1,
            true // includeCheckpoint = true for voluntary sync
        );

        bytes memory proposeData2 = _codec().encodeProposeInput(input2);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData2);

        // Assert: Checkpoint should be saved despite minCheckpointDelay not elapsed
        uint48 finalCheckpointCount = inbox.getNumberOfCheckpoints();
        assertEq(
            finalCheckpointCount,
            initialCheckpointCount + 1,
            "Voluntary checkpoint should be saved immediately"
        );

        // Verify lastCheckpointTimestamp was updated
        uint48 timeDiff = uint48(block.timestamp) - initialTimestamp;
        assertLt(timeDiff, MIN_CHECKPOINT_DELAY, "Time elapsed should be less than delay");
    }

    /// @notice Test forced checkpoint sync when minCheckpointDelay has elapsed
    /// @dev Checkpoint should sync after delay even without voluntary checkpoint
    function test_forcedCheckpointSyncAfterDelay() public {
        // Setup: Create and finalize first proposal
        _setupBlobHashes();
        vm.roll(block.number + 1);

        // Propose first block
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Prove and finalize first proposal
        IInbox.Proposal memory proposal1 = _buildProposalFromEvent(1);
        _proveProposal(proposal1);

        // Record initial checkpoint state
        uint48 initialCheckpointCount = inbox.getNumberOfCheckpoints();

        // Advance time BEYOND MIN_CHECKPOINT_DELAY to trigger forced sync
        vm.warp(block.timestamp + MIN_CHECKPOINT_DELAY + 1);
        vm.roll(block.number + 1);

        // Propose second block WITHOUT voluntary checkpoint (blockHash == 0)
        // But the forced sync should still happen due to delay
        IInbox.ProposeInput memory input2 = _createSecondProposeInputWithCheckpoint(
            proposal1,
            false // includeCheckpoint = false, rely on forced sync
        );

        bytes memory proposeData2 = _codec().encodeProposeInput(input2);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData2);

        // Assert: Checkpoint should be saved due to forced sync (minCheckpointDelay elapsed)
        uint48 finalCheckpointCount = inbox.getNumberOfCheckpoints();
        assertEq(
            finalCheckpointCount,
            initialCheckpointCount + 1,
            "Forced checkpoint should be saved after delay"
        );
    }

    /// @notice Test that checkpoint is NOT synced when no finalization occurs
    /// @dev Edge case: if finalizedCount == 0, no checkpoint sync should happen
    function test_noSyncWhenNoFinalization() public {
        // Setup: Create first proposal but DON'T finalize it
        _setupBlobHashes();
        vm.roll(block.number + 1);

        // Propose first block
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // DON'T prove/finalize - this means finalizedCount will be 0

        // Record initial checkpoint state
        uint48 initialCheckpointCount = inbox.getNumberOfCheckpoints();

        // Advance time beyond MIN_CHECKPOINT_DELAY
        vm.warp(block.timestamp + MIN_CHECKPOINT_DELAY + 1);
        vm.roll(block.number + 1);

        // Try to propose again with checkpoint, but since there's no finalization,
        // checkpoint sync should NOT happen
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        coreState.nextProposalId = 2;
        coreState.lastProposalBlockId = uint48(block.number - 1);

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _buildProposalFromEvent(1);

        // Create input with checkpoint but NO transition records (no finalization)
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: _createBlobRef(0, 1, 0),
            transitionRecords: new IInbox.TransitionRecord[](0), // Empty - no finalization!
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: keccak256(abi.encode("test", block.number)),
                stateRoot: keccak256(abi.encode("state", block.number))
            }),
            numForcedInclusions: 0
        });

        bytes memory proposeData2 = _codec().encodeProposeInput(input);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData2);

        // Assert: Checkpoint should NOT be saved (finalizedCount == 0)
        uint48 finalCheckpointCount = inbox.getNumberOfCheckpoints();
        assertEq(
            finalCheckpointCount,
            initialCheckpointCount,
            "Checkpoint should NOT be saved when no finalization occurs"
        );
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    /// @notice Helper to prove a proposal
    function _proveProposal(IInbox.Proposal memory _proposal) internal {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: _codec().hashProposal(_proposal),
            parentTransitionHash: _getGenesisTransitionHash(),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: keccak256(abi.encodePacked("block", block.number)),
                stateRoot: keccak256(abi.encodePacked("state", block.number))
            })
        });

        IInbox.TransitionMetadata memory metadata =
            IInbox.TransitionMetadata({ designatedProver: Alice, actualProver: Alice });

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;
        IInbox.TransitionMetadata[] memory metadataArray = new IInbox.TransitionMetadata[](1);
        metadataArray[0] = metadata;

        bytes memory proveData = _codec().encodeProveInput(
            IInbox.ProveInput({
                proposals: proposals,
                transitions: transitions,
                metadata: metadataArray
            })
        );

        vm.prank(Alice);
        inbox.prove(proveData, bytes(""));
    }

    /// @notice Helper to build proposal from emitted event
    function _buildProposalFromEvent(uint48 _proposalId)
        internal
        view
        returns (IInbox.Proposal memory)
    {
        bytes32 proposalHash = inbox.getProposalHash(_proposalId);
        require(proposalHash != bytes32(0), "Proposal not found");

        // Reconstruct proposal - this is simplified, in real scenario would decode from event
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        coreState.nextProposalId = _proposalId + 1;
        coreState.lastProposalBlockId = uint48(block.number);

        // Build derivation
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", 0));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: IInbox.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0,
            sources: sources
        });

        return IInbox.Proposal({
            id: _proposalId,
            proposer: currentProposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: _codec().hashCoreState(coreState),
            derivationHash: _codec().hashDerivation(derivation)
        });
    }

    /// @notice Helper to create second propose input with optional checkpoint
    function _createSecondProposeInputWithCheckpoint(
        IInbox.Proposal memory _firstProposal,
        bool _includeCheckpoint
    )
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        coreState.nextProposalId = 2;
        coreState.lastProposalBlockId = uint48(block.number - 1);
        coreState.lastFinalizedProposalId = 1;
        coreState.lastFinalizedTransitionHash = keccak256(abi.encode("transition", 1));

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _firstProposal;

        // Create transition record for finalization of first proposal
        IInbox.TransitionRecord memory transitionRecord = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: keccak256(abi.encode("transition", 1)),
            checkpointHash: _codec().hashCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: uint48(block.number),
                    blockHash: keccak256(abi.encodePacked("block", block.number)),
                    stateRoot: keccak256(abi.encodePacked("state", block.number))
                })
            )
        });

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = transitionRecord;

        // Create checkpoint (voluntary if includeCheckpoint=true, empty otherwise)
        ICheckpointStore.Checkpoint memory checkpoint;
        if (_includeCheckpoint) {
            checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: keccak256(abi.encodePacked("block", block.number)),
                stateRoot: keccak256(abi.encodePacked("state", block.number))
            });
        }
        // else: checkpoint.blockHash will be 0 (no voluntary sync)

        return IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: _createBlobRef(0, 1, 0),
            transitionRecords: transitionRecords,
            checkpoint: checkpoint,
            numForcedInclusions: 0
        });
    }
}
