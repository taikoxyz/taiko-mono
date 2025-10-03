// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { CodecSimple } from "src/layer1/shasta/impl/CodecSimple.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { InboxTestHelper } from "./common/InboxTestHelper.sol";
import { IInboxDeployer } from "./deployers/IInboxDeployer.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";

/// @title CheckpointDelayInbox
/// @notice Test inbox with configurable minCheckpointDelay
contract CheckpointDelayInbox is Inbox {
    constructor(
        address codec,
        address bondToken,
        uint16 maxCheckpointHistory,
        address proofVerifier,
        address proposerChecker,
        uint16 minCheckpointDelay
    )
        Inbox(
            IInbox.Config({
                codec: codec,
                bondToken: bondToken,
                proofVerifier: proofVerifier,
                proposerChecker: proposerChecker,
                provingWindow: 2 hours,
                extendedProvingWindow: 4 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 48 hours,
                ringBufferSize: 100,
                basefeeSharingPctg: 0,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000,
                maxCheckpointHistory: maxCheckpointHistory,
                minCheckpointDelay: minCheckpointDelay,
                permissionlessInclusionMultiplier: 5
            })
        )
    { }
}

/// @title CheckpointDelayInboxDeployer
/// @notice Deployer for test inbox with checkpoint delay
contract CheckpointDelayInboxDeployer is InboxTestHelper, IInboxDeployer {
    uint16 internal minCheckpointDelay;

    constructor(uint16 _minCheckpointDelay) {
        minCheckpointDelay = _minCheckpointDelay;
    }

    function getTestContractName() external pure returns (string memory) {
        return "CheckpointDelayInbox";
    }

    function deployInbox(
        address bondToken,
        uint16 maxCheckpointHistory,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address codec = address(new CodecSimple());
        address impl = address(
            new CheckpointDelayInbox(
                codec, bondToken, maxCheckpointHistory, proofVerifier, proposerChecker, minCheckpointDelay
            )
        );

        CheckpointDelayInbox inbox = CheckpointDelayInbox(
            deploy({ name: "", impl: impl, data: abi.encodeCall(Inbox.init, (Alice, Alice)) })
        );

        vm.prank(Alice);
        inbox.activate(bytes32(uint256(1)));

        return inbox;
    }
}

/// @title InboxCheckpointSync
/// @notice Test suite for checkpoint synchronization functionality
/// @dev Tests both voluntary and forced checkpoint sync modes
contract InboxCheckpointSync is InboxTestHelper {
    // Test constants
    uint16 internal constant MIN_CHECKPOINT_DELAY = 300; // 5 minutes
    address internal currentProposer = Bob;

    function setUp() public override {
        setDeployer(new CheckpointDelayInboxDeployer(MIN_CHECKPOINT_DELAY));
        super.setUp();
        currentProposer = _selectProposer(Bob);
    }

    /// @notice Test voluntary checkpoint sync when proposer provides checkpoint
    /// @dev Checkpoint should sync immediately even if minCheckpointDelay has not elapsed
    function test_checkpoint_voluntarySync() public {
        _setupBlobHashes();

        // Propose and prove first proposal
        vm.roll(block.number + 1);
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Create proof for first proposal
        IInbox.Proposal memory proposal = _getProposal(1);
        IInbox.Transition memory transition = _createTransition(proposal);
        IInbox.TransitionMetadata memory metadata = _createMetadata();

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;
        IInbox.TransitionMetadata[] memory metadataArray = new IInbox.TransitionMetadata[](1);
        metadataArray[0] = metadata;

        bytes memory proveData = _codec().encodeProveInput(
            IInbox.ProveInput({ proposals: proposals, transitions: transitions, metadata: metadataArray })
        );

        vm.prank(Alice);
        inbox.prove(proveData, bytes(""));

        // Record initial checkpoint state
        uint48 initialCheckpointCount = inbox.getNumberOfCheckpoints();

        // Advance time by only 1 second (well below MIN_CHECKPOINT_DELAY)
        vm.warp(block.timestamp + 1);

        // Propose second proposal with voluntary checkpoint
        vm.roll(block.number + 1);

        ICheckpointStore.Checkpoint memory voluntaryCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: uint48(block.number),
            blockHash: transition.checkpoint.blockHash,
            stateRoot: transition.checkpoint.stateRoot
        });

        IInbox.TransitionRecord[] memory records = new IInbox.TransitionRecord[](1);
        records[0] = _createTransitionRecord(transition);

        bytes memory proposeData2 = _codec().encodeProposeInput(
            _createProposeInputWithCheckpoint(voluntaryCheckpoint, records)
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData2);

        // Assert: Checkpoint should be saved despite minCheckpointDelay not elapsed
        uint48 finalCheckpointCount = inbox.getNumberOfCheckpoints();
        assertEq(
            finalCheckpointCount,
            initialCheckpointCount + 1,
            "Voluntary checkpoint should be saved immediately"
        );

        // Verify the checkpoint was saved correctly
        ICheckpointStore.Checkpoint memory savedCheckpoint = inbox.getCheckpoint(0);
        assertEq(
            savedCheckpoint.blockHash,
            voluntaryCheckpoint.blockHash,
            "Checkpoint blockHash should match"
        );
    }

    /// @notice Test forced checkpoint sync when minCheckpointDelay has elapsed
    /// @dev Checkpoint should sync after delay even without voluntary checkpoint
    function test_checkpoint_forcedSync() public {
        _setupBlobHashes();

        // Propose and prove first proposal
        vm.roll(block.number + 1);
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Create proof for first proposal
        IInbox.Proposal memory proposal = _getProposal(1);
        IInbox.Transition memory transition = _createTransition(proposal);
        IInbox.TransitionMetadata memory metadata = _createMetadata();

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;
        IInbox.TransitionMetadata[] memory metadataArray = new IInbox.TransitionMetadata[](1);
        metadataArray[0] = metadata;

        bytes memory proveData = _codec().encodeProveInput(
            IInbox.ProveInput({ proposals: proposals, transitions: transitions, metadata: metadataArray })
        );

        vm.prank(Alice);
        inbox.prove(proveData, bytes(""));

        // Record initial state
        uint48 initialCheckpointCount = inbox.getNumberOfCheckpoints();
        uint48 lastCheckpointTime = uint48(block.timestamp);

        // Advance time beyond MIN_CHECKPOINT_DELAY to trigger forced sync
        vm.warp(block.timestamp + MIN_CHECKPOINT_DELAY + 1);

        // Propose second proposal WITHOUT voluntary checkpoint (empty checkpoint)
        vm.roll(block.number + 1);

        ICheckpointStore.Checkpoint memory emptyCheckpoint; // blockHash == 0 means no voluntary checkpoint

        IInbox.TransitionRecord[] memory records = new IInbox.TransitionRecord[](1);
        records[0] = _createTransitionRecord(transition);

        bytes memory proposeData2 = _codec().encodeProposeInput(
            _createProposeInputWithCheckpoint(emptyCheckpoint, records)
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData2);

        // Assert: Checkpoint should be saved due to forced sync (minCheckpointDelay elapsed)
        uint48 finalCheckpointCount = inbox.getNumberOfCheckpoints();
        assertEq(
            finalCheckpointCount,
            initialCheckpointCount + 1,
            "Forced checkpoint should be saved after delay"
        );

        // Verify the checkpoint timestamp was updated
        uint48 newCheckpointTime = inbox.getLatestCheckpointBlockNumber();
        assertGt(
            newCheckpointTime,
            lastCheckpointTime,
            "Checkpoint timestamp should be updated after forced sync"
        );
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    /// @notice Helper to get a proposal by ID
    function _getProposal(uint48 _proposalId) internal view returns (IInbox.Proposal memory) {
        bytes32 proposalHash = inbox.getProposalHash(_proposalId);
        require(proposalHash != bytes32(0), "Proposal not found");

        // Reconstruct proposal from stored data
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        coreState.nextProposalId = _proposalId + 1;
        coreState.lastProposalBlockId = uint48(block.number);

        IInbox.Derivation memory derivation;
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", 0));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        derivation.originBlockNumber = uint48(block.number - 1);
        derivation.originBlockHash = blockhash(block.number - 1);
        derivation.basefeeSharingPctg = 0;
        derivation.sources = sources;

        return IInbox.Proposal({
            id: _proposalId,
            proposer: currentProposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: _codec().hashCoreState(coreState),
            derivationHash: _codec().hashDerivation(derivation)
        });
    }

    /// @notice Helper to create a transition for a proposal
    function _createTransition(IInbox.Proposal memory _proposal)
        internal
        view
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _codec().hashProposal(_proposal),
            parentTransitionHash: _getGenesisTransitionHash(),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: keccak256(abi.encodePacked("block", block.number)),
                stateRoot: keccak256(abi.encodePacked("state", block.number))
            })
        });
    }

    /// @notice Helper to create transition metadata
    function _createMetadata() internal view returns (IInbox.TransitionMetadata memory) {
        return IInbox.TransitionMetadata({ designatedProver: Alice, actualProver: Alice });
    }

    /// @notice Helper to create transition record
    function _createTransitionRecord(IInbox.Transition memory _transition)
        internal
        view
        returns (IInbox.TransitionRecord memory)
    {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](0);

        return IInbox.TransitionRecord({
            span: 1,
            transitionHash: _codec().hashTransition(_transition),
            checkpointHash: _codec().hashCheckpoint(_transition.checkpoint),
            bondInstructions: bondInstructions
        });
    }

    /// @notice Helper to create propose input with checkpoint
    function _createProposeInputWithCheckpoint(
        ICheckpointStore.Checkpoint memory _checkpoint,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        coreState.nextProposalId = 2;
        coreState.lastProposalBlockId = uint48(block.number - 1);

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _getProposal(1);

        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        return IInbox.ProposeInput({
            deadline: 0,
            numForcedInclusions: 0,
            blobReference: blobRef,
            parentProposals: parentProposals,
            coreState: coreState,
            transitionRecords: _transitionRecords,
            checkpoint: _checkpoint
        });
    }
}
