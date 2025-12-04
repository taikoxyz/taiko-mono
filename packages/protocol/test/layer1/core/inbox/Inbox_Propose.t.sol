// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Vm } from "forge-std/src/Vm.sol";

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import { InboxTestHelper } from "./common/InboxTestHelper.sol";

/// @title InboxProposeTest
/// @notice Tests for Inbox propose functionality
/// @custom:security-contact security@taiko.xyz
contract InboxProposeTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // Propose Happy Path Tests
    // ---------------------------------------------------------------

    function test_propose_firstProposal() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal was stored
        bytes32 proposalHash = inbox.getProposalHash(1);
        assertTrue(proposalHash != bytes32(0), "Proposal hash should be stored");

        // Verify event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(_countProposedEvents(logs), 1, "Should emit exactly one Proposed event");
    }

    function test_propose_consecutiveProposals() public {
        IInbox.ProposedEventPayload memory firstPayload = _proposeAndGetPayload();

        // Second proposal
        IInbox.ProposedEventPayload memory secondPayload = _proposeConsecutive(firstPayload);

        assertEq(secondPayload.proposal.id, 2, "Second proposal should have id 2");
        assertEq(
            secondPayload.proposal.parentProposalHash,
            codec.hashProposal(firstPayload.proposal),
            "Parent hash should match first proposal"
        );
    }

    function test_propose_multipleConsecutiveProposals() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        for (uint256 i = 0; i < 5; i++) {
            payload = _proposeConsecutive(payload);
            assertEq(payload.proposal.id, i + 2, "Proposal ID should increment");
        }
    }

    function test_propose_withMultipleBlobs() public {
        _setupBlobHashes(5);
        vm.roll(2);

        IInbox.ProposeInput memory input = _createProposeInputWithBlobs(3, 100);
        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        bytes32 proposalHash = inbox.getProposalHash(1);
        assertTrue(proposalHash != bytes32(0), "Proposal should be stored");
    }

    function test_propose_withDeadline() public {
        _setupBlobHashes();
        vm.roll(2);
        uint40 deadline = uint40(block.timestamp + 100);

        IInbox.ProposeInput memory input = _createProposeInputWithDeadline(deadline);
        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        bytes32 proposalHash = inbox.getProposalHash(1);
        assertTrue(proposalHash != bytes32(0), "Proposal should be stored");
    }

    function test_propose_emitsCorrectEventData() public {
        _setupBlobHashes();
        vm.roll(2);
        vm.warp(INITIAL_TIMESTAMP);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory payload = _decodeLastProposedEvent();

        assertEq(payload.proposal.id, 1, "Proposal ID should be 1");
        assertEq(payload.proposal.proposer, currentProposer, "Proposer should match");
        assertEq(payload.proposal.timestamp, uint40(block.timestamp), "Timestamp should match");
        assertEq(payload.coreState.proposalHead, 1, "Core state proposalHead should be 1");
    }

    // ---------------------------------------------------------------
    // Propose Error Path Tests
    // ---------------------------------------------------------------

    function test_propose_RevertWhen_DeadlineExceeded() public {
        _setupBlobHashes();
        vm.roll(2);
        uint40 deadline = uint40(block.timestamp - 1);

        IInbox.ProposeInput memory input = _createProposeInputWithDeadline(deadline);
        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.DeadlineExceeded.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_SameBlock() public {
        // First proposal
        _proposeAndGetPayload();

        // Try second proposal in same block (without rolling)
        _setupBlobHashes();
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        coreState.proposalHead = 1;
        coreState.proposalHeadContainerBlock = uint40(block.number);

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = IInbox.Proposal({
            id: 1,
            timestamp: uint40(block.timestamp),
            endOfSubmissionWindowTimestamp: 0,
            proposer: currentProposer,
            coreStateHash: codec.hashCoreState(coreState),
            derivationHash: bytes32(0),
            parentProposalHash: inbox.getProposalHash(0)
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0
        });

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.CannotProposeInCurrentBlock.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_EmptyProposals() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        input.headProposalAndProof = new IInbox.Proposal[](0);

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.EmptyProposals.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_InvalidState() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        // Tamper with core state - wrong proposalHead
        input.coreState.proposalHead = 999;

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.InvalidState.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_InvalidProposer() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        bytes memory proposeData = codec.encodeProposeInput(input);

        // Eve is not an allowed proposer
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        vm.prank(Emma);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_ProposalHashMismatch() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        // Tamper with parent proposal
        input.headProposalAndProof[0].timestamp = 999;

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.ProposalHashMismatch.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_ZeroBlobs() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();
        input.blobReference = _createBlobRef(0, 0, 0);

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(LibBlobs.NoBlobs.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Ring Buffer Tests
    // ---------------------------------------------------------------

    function test_propose_verifyRingBufferStorage() public {
        // Verify the default ring buffer size stores proposals correctly
        // Each proposal should be stored at id % ringBufferSize

        // Create first proposal
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        assertEq(payload1.proposal.id, 1, "First proposal should have id 1");

        // Verify proposal hash is stored
        bytes32 storedHash = inbox.getProposalHash(1);
        bytes32 computedHash = codec.hashProposal(payload1.proposal);
        assertEq(storedHash, computedHash, "Stored hash should match computed hash");
    }

    // ---------------------------------------------------------------
    // Head Proposal Verification Tests
    // ---------------------------------------------------------------

    function test_propose_RevertWhen_TooManyProofProposals() public {
        _setupBlobHashes();
        vm.roll(2);

        IInbox.ProposeInput memory input = _createFirstProposeInput();

        // Add extra proof proposal when next slot is empty (should be 1)
        IInbox.Proposal[] memory twoProposals = new IInbox.Proposal[](2);
        twoProposals[0] = input.headProposalAndProof[0];
        twoProposals[1] = input.headProposalAndProof[0];
        input.headProposalAndProof = twoProposals;

        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.TooManyProofProposals.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Ring Buffer Wrap-Around Tests
    // ---------------------------------------------------------------

    /// @dev When the ring buffer is full and wraps around, the next slot contains an old proposal.
    /// This triggers MissingProofProposal because only 1 proof proposal is provided when 2 are needed.
    function test_propose_RevertWhen_MissingProofProposal() public {
        // Fill the ring buffer until the NEXT proposal would wrap around
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Keep proposing until we're one away from wrap-around
        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;

        // Propose until id = ringBufferSize - 1 (e.g., id=99 with size 100)
        // The next proposal (id=100) will map to slot 0 where genesis is
        for (uint256 i = 2; i < ringBufferSize; i++) {
            payload = _proposeConsecutive(payload);
        }

        // Now payload.proposal.id = ringBufferSize - 1 = 99
        // Next proposal id = 100, which maps to slot 0
        // Slot 0 contains genesis (id=0), so next slot check finds occupied slot
        // This triggers MissingProofProposal since we only provide 1 proof proposal
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.ProposeInput memory input =
            _createConsecutiveProposeInput(payload.proposal, payload.coreState);
        bytes memory proposeData = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.MissingProofProposal.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }
}
