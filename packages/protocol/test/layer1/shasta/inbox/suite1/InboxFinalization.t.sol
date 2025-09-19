// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import { TransitionRecordHashMismatchWithStorage } from "contracts/layer1/shasta/impl/Inbox.sol";
import "./InboxMockContracts.sol";

/// @title InboxFinalization
/// @notice Tests for proposal finalization functionality
/// @dev This test suite covers:
///      - Single proposal finalization with state updates
///      - Multiple proposal batch finalization
///      - Missing transition handling and partial finalization
///      - Invalid transition hash rejection and error handling
/// @custom:security-contact security@taiko.xyz
contract InboxFinalization is InboxTest {
    using InboxTestLib for *;
    // Override setupMockAddresses to use actual mock contracts instead of makeAddr

    function setupMockAddresses() internal override {
        setupMockAddresses(true); // Use real mock contracts for finalization tests
    }
    /// @notice Test finalizing a single proposal
    /// @dev Validates complete single proposal finalization flow:
    ///      1. Creates and stores proposal with valid transition record
    ///      2. Triggers finalization through new proposal submission
    ///      3. Verifies checkpoint manager update and state progression

    function test_finalize_single_proposal() public {
        // Arrange: Create a proposal and transition record ready for finalization
        uint48 proposalId = 1;
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Proposal memory proposal = _createStoredProposal(proposalId, coreState);
        IInbox.Transition memory transition =
            InboxTestLib.createTransition(proposal, coreState.lastFinalizedTransitionHash, Alice);
        IInbox.TransitionRecord memory transitionRecord = _createStoredTransitionRecord(
            proposalId, transition, coreState.lastFinalizedTransitionHash
        );

        // Setup expectations
        expectCheckpointSaved(transition.checkpoint);

        // Act: Submit proposal that triggers finalization with the transition's checkpoint
        _submitFinalizationProposal(proposal, transitionRecord, transition.checkpoint);
    }

    /// @dev Helper to create and store a proposal for testing
    function _createStoredProposal(
        uint48 _proposalId,
        IInbox.CoreState memory _coreState
    )
        private
        returns (IInbox.Proposal memory proposal)
    {
        IInbox.CoreState memory updatedCoreState = _coreState;
        updatedCoreState.nextProposalId = _proposalId + 1;
        updatedCoreState.nextProposalBlockId =
            uint48(InboxTestLib.calculateProposalBlock(_proposalId + 1, 2));

        proposal = createValidProposal(_proposalId);
        proposal.coreStateHash = keccak256(abi.encode(updatedCoreState));
        inbox.exposed_setProposalHash(_proposalId, InboxTestLib.hashProposal(proposal));
    }

    /// @dev Helper to create and store a transition record for testing
    function _createStoredTransitionRecord(
        uint48 _proposalId,
        IInbox.Transition memory _transition,
        bytes32 _parentTransitionHash
    )
        private
        returns (IInbox.TransitionRecord memory transitionRecord)
    {
        transitionRecord = InboxTestLib.createTransitionRecord(_transition, 1);
        // Create a parent transition with the parentTransitionHash for the function call
        IInbox.Transition memory parentTransition;
        parentTransition.parentTransitionHash = _parentTransitionHash;
        inbox.exposed_setTransitionRecordHashAndDeadline(
            _proposalId, parentTransition, transitionRecord
        );
    }

    /// @dev Helper to submit a finalization proposal
    function _submitFinalizationProposal(
        IInbox.Proposal memory _proposalToValidate,
        IInbox.TransitionRecord memory _transitionRecord,
        ICheckpointManager.Checkpoint memory _checkpoint
    )
        private
    {
        setupProposalMocks(Alice);

        // Advance time to pass the finalization grace period (5 minutes)
        vm.warp(block.timestamp + 5 minutes + 1);

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = _transitionRecord;

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposalToValidate;

        IInbox.CoreState memory newCoreState = _getGenesisCoreState();
        newCoreState.nextProposalId = 2;
        newCoreState.nextProposalBlockId = uint48(InboxTestLib.calculateProposalBlock(2, 2));

        // Use the adapter with explicit checkpoint
        bytes memory data = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType,
            uint48(0),
            newCoreState,
            proposals,
            InboxTestLib.createBlobReference(2),
            transitionRecords,
            _checkpoint
        );

        setupBlobHashes();
        uint256 targetBlock = InboxTestLib.calculateProposalBlock(2, 2);
        vm.roll(targetBlock);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test finalizing multiple proposals in sequence
    /// @dev Validates batch finalization of multiple proposals:
    ///      1. Submits and proves multiple proposals with linked transitions
    ///      2. Batch finalizes all proposals in one transaction
    ///      3. Verifies final state consistency and transition hash progression
    function test_finalize_multiple_proposals() public {
        uint48 numProposals = 3;
        bytes32 genesisHash = getGenesisTransitionHash();

        // Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Then prove them all
        IInbox.Transition[] memory transitions = new IInbox.Transition[](numProposals);
        bytes32 currentParentHash = genesisHash;

        for (uint48 i = 0; i < numProposals; i++) {
            transitions[i] = InboxTestLib.createTransition(proposals[i], currentParentHash, Bob);
            proveProposal(proposals[i], Bob, currentParentHash);
            currentParentHash = InboxTestLib.hashTransition(transitions[i]);
        }

        // Create transition records for finalization
        IInbox.TransitionRecord[] memory transitionRecords =
            new IInbox.TransitionRecord[](numProposals);
        for (uint48 i = 0; i < numProposals; i++) {
            transitionRecords[i] = InboxTestLib.createTransitionRecord(transitions[i], 1);
        }

        // Advance time to pass the finalization grace period
        vm.warp(block.timestamp + 5 minutes + 1);

        // Setup expectations for finalization
        expectCheckpointSaved(transitions[numProposals - 1].checkpoint);

        // Act: Submit finalization proposal with the last transition's checkpoint
        _submitBatchFinalizationProposal(
            proposals[numProposals - 1],
            transitionRecords,
            numProposals + 1,
            transitions[numProposals - 1].checkpoint
        );

        // Assert: Verify finalization completed
        bytes32 finalTransitionHash = InboxTestLib.hashTransition(transitions[numProposals - 1]);
        assertFinalizationCompleted(numProposals, finalTransitionHash);
    }

    /// @dev Helper to submit a batch finalization proposal
    function _submitBatchFinalizationProposal(
        IInbox.Proposal memory _lastProposal,
        IInbox.TransitionRecord[] memory _transitionRecords,
        uint48 _nextProposalId,
        ICheckpointManager.Checkpoint memory _checkpoint
    )
        private
    {
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(_nextProposalId, 0, getGenesisTransitionHash(), bytes32(0));
        coreState.nextProposalBlockId =
            uint48(InboxTestLib.calculateProposalBlock(_nextProposalId, 2));

        setupProposalMocks(Carol);
        setupBlobHashes();

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _lastProposal;

        uint256 targetBlock = InboxTestLib.calculateProposalBlock(_nextProposalId, 2);
        vm.roll(targetBlock);
        vm.prank(Carol);
        inbox.propose(
            bytes(""),
            InboxTestAdapter.encodeProposeInputWithEndBlock(
                inboxType,
                uint48(0),
                coreState,
                proposals,
                InboxTestLib.createBlobReference(uint8(_nextProposalId)),
                _transitionRecords,
                _checkpoint
            )
        );
    }

    /// @notice Test finalization stops at missing transition record
    /// @dev Validates partial finalization when transition records are missing:
    ///      1. Creates proposals with only first having transition record
    ///      2. Attempts finalization and expects stopping at missing transition
    ///      3. Verifies only proven consecutive proposals are finalized
    function test_finalize_stops_at_missing_transition() public {
        // Setup blobhashes for this specific test
        setupBlobHashes();
        // Create genesis transition
        IInbox.Transition memory genesisTransition;
        genesisTransition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        bytes32 parentTransitionHash = keccak256(abi.encode(genesisTransition));

        // Store proposal 1 with transition
        IInbox.CoreState memory coreState1 = _getGenesisCoreState();
        coreState1.nextProposalId = 2; // After proposal 1
        coreState1.nextProposalBlockId = uint48(InboxTestLib.calculateProposalBlock(2, 2));

        IInbox.Proposal memory proposal1 = createValidProposal(1);
        proposal1.coreStateHash = keccak256(abi.encode(coreState1));
        inbox.exposed_setProposalHash(1, keccak256(abi.encode(proposal1)));

        IInbox.Transition memory transition1 =
            InboxTestLib.createTransition(proposal1, parentTransitionHash, Bob);
        IInbox.TransitionRecord memory transitionRecord1 = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: InboxTestLib.hashTransition(transition1),
            checkpointHash: keccak256(abi.encode(transition1.checkpoint))
        });
        // Create a parent transition struct for the function call
        IInbox.Transition memory parentTransition;
        parentTransition.parentTransitionHash = parentTransitionHash;
        inbox.exposed_setTransitionRecordHashAndDeadline(1, parentTransition, transitionRecord1);

        // Store proposal 2 WITHOUT transition (gap in chain)
        IInbox.CoreState memory coreState2 = _getGenesisCoreState();
        coreState2.nextProposalId = 3; // After proposal 2
        coreState2.nextProposalBlockId = uint48(InboxTestLib.calculateProposalBlock(3, 2));

        IInbox.Proposal memory proposal2 = createValidProposal(2);
        proposal2.coreStateHash = keccak256(abi.encode(coreState2));
        inbox.exposed_setProposalHash(2, keccak256(abi.encode(proposal2)));
        // No transition record stored for proposal 2

        // Setup core state for new proposal
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(3, 0);
        coreState.nextProposalBlockId = uint48(InboxTestLib.calculateProposalBlock(3, 2));
        coreState.lastFinalizedTransitionHash = parentTransitionHash;

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Advance time to pass the finalization grace period (5 minutes)
        vm.warp(block.timestamp + 5 minutes + 1);

        // Only expect first proposal to be finalized
        expectCheckpointSaved(transition1.checkpoint);

        // Create proposal data with only transitionRecord1
        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = transitionRecord1;

        // Include proposal 2 for validation (as the last proposal)
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal2;

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });

        // Use the adapter with the checkpoint from transition1 since that's what we're
        // finalizing
        // Extract to local variable to avoid stack too deep
        ICheckpointManager.Checkpoint memory endBlockHeader = transition1.checkpoint;
        bytes memory data = InboxTestAdapter.encodeProposeInputWithEndBlock(
            inboxType, uint48(0), coreState, proposals, blobRef, transitionRecords, endBlockHeader
        );

        // Submit proposal
        uint256 targetBlock = InboxTestLib.calculateProposalBlock(3, 2);
        vm.roll(targetBlock);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify only proposal 1 was finalized
        // The test passes if propose succeeded without reverting
        // We expect only proposal 1 to have been finalized
    }

    /// @notice Test finalization with invalid transition record hash
    /// @dev Validates transition record integrity protection:
    ///      1. Stores correct transition record in contract storage
    ///      2. Submits modified transition record for finalization
    ///      3. Expects TransitionRecordHashMismatchWithStorage error for security
    function test_finalize_invalid_transition_hash() public {
        setupBlobHashes();

        // Submit and prove proposal 1 correctly first
        IInbox.Proposal memory proposal1 = submitProposal(1, Alice);
        bytes32 parentTransitionHash = getGenesisTransitionHash();
        IInbox.Transition memory transition1 =
            InboxTestLib.createTransition(proposal1, parentTransitionHash, Bob);
        proveProposal(proposal1, Bob, parentTransitionHash);

        // Now try to finalize with a WRONG transition record
        IInbox.TransitionRecord memory wrongTransitionRecord = IInbox.TransitionRecord({
            span: 2, // Modified field - wrong span value
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: InboxTestLib.hashTransition(transition1),
            checkpointHash: keccak256(abi.encode(transition1.checkpoint))
        });

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = wrongTransitionRecord;

        // Create core state for next proposal
        IInbox.CoreState memory coreState =
            InboxTestLib.createCoreState(2, 0, parentTransitionHash, bytes32(0));
        coreState.nextProposalBlockId = uint48(InboxTestLib.calculateProposalBlock(2, 2));

        // Setup mocks for new proposal
        setupProposalMocks(Carol);
        setupBlobHashes();

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal1;

        // Expect revert due to mismatched transition record hash
        vm.expectRevert(TransitionRecordHashMismatchWithStorage.selector);
        uint256 targetBlock = InboxTestLib.calculateProposalBlock(2, 2);
        vm.roll(targetBlock);
        vm.prank(Carol);
        inbox.propose(
            bytes(""),
            InboxTestAdapter.encodeProposeInputWithEndBlock(
                inboxType,
                uint48(0),
                coreState,
                proposals,
                InboxTestLib.createBlobReference(2),
                transitionRecords,
                transition1.checkpoint // Use the actual transition's checkpoint
            )
        );
    }
}
