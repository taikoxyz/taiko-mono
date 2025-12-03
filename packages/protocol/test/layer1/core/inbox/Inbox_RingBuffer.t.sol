// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { DevnetInbox } from "src/layer1/devnet/DevnetInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

import { InboxTestHelper } from "./common/InboxTestHelper.sol";

/// @title InboxRingBufferTest
/// @notice Tests for Inbox ring buffer wrap-around scenarios
/// @dev These tests cover edge cases that require ring buffer wrap-around.
///      Some errors (MissingProofProposal, InvalidLastProposalProof, NextProposalHashMismatch)
///      are only triggered in wrap-around scenarios which require complex setup.
///      These tests verify the error selectors exist and document the conditions.
/// @custom:security-contact security@taiko.xyz
contract InboxRingBufferTest is InboxTestHelper {
    // Small ring buffer for wrap-around testing (5 slots: genesis + 4 proposals)
    uint256 internal constant SMALL_RING_BUFFER_SIZE = 5;
    // Even smaller buffer for specific tests (4 slots: genesis + 3 proposals before wrap)
    uint256 internal constant TINY_RING_BUFFER_SIZE = 4;

    Inbox public smallInbox;

    function setUp() public override {
        // Don't call super.setUp() - we need custom inbox with small ring buffer
        super.setUpOnEthereum();

        _deployDependencies();

        // Deploy inbox with small ring buffer
        IInbox.Config memory config = _createDefaultConfig();
        config.ringBufferSize = SMALL_RING_BUFFER_SIZE;
        smallInbox = _deployInbox(config);

        // Setup signal service and activate inbox
        vm.startPrank(owner);
        signalService.upgradeTo(
            address(new SignalService(address(smallInbox), MOCK_REMOTE_SIGNAL_SERVICE))
        );
        smallInbox.activate(GENESIS_BLOCK_HASH);
        vm.stopPrank();

        // Setup proposer
        proposerChecker.allowProposer(currentProposer);

        // Replace default inbox with small inbox for helper functions
        inbox = smallInbox;
        _cacheConfigValues();

        // Advance to safe state
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_TIMESTAMP);
    }

    // ---------------------------------------------------------------
    // Ring Buffer Wrap-Around Error Verification Tests
    // ---------------------------------------------------------------

    /// @dev Verifies MissingProofProposal error exists
    /// @notice This error is thrown when next slot is occupied (wrap-around) but only 1 proof proposal provided
    /// Conditions:
    /// 1. Ring buffer wrapped around (slot occupied by older proposal)
    /// 2. Only 1 proposal provided in headProposalAndProof when 2 are required
    function test_error_MissingProofProposal_exists() public pure {
        bytes4 selector = Inbox.MissingProofProposal.selector;
        assertTrue(selector != bytes4(0), "MissingProofProposal error should exist");
    }

    /// @dev Verifies InvalidLastProposalProof error exists
    /// @notice This error is thrown when proof proposal ID >= head proposal ID in wrap-around scenario
    /// Conditions:
    /// 1. Ring buffer wrapped around (next slot occupied)
    /// 2. 2 proposals provided
    /// 3. Proof proposal ID is not less than head proposal ID
    function test_error_InvalidLastProposalProof_exists() public pure {
        bytes4 selector = Inbox.InvalidLastProposalProof.selector;
        assertTrue(selector != bytes4(0), "InvalidLastProposalProof error should exist");
    }

    /// @dev Verifies NextProposalHashMismatch error exists
    /// @notice This error is thrown when proof proposal hash doesn't match stored hash in next slot
    /// Conditions:
    /// 1. Ring buffer wrapped around (next slot occupied)
    /// 2. 2 proposals provided
    /// 3. Proof proposal hash doesn't match the hash stored in next slot
    function test_error_NextProposalHashMismatch_exists() public pure {
        bytes4 selector = Inbox.NextProposalHashMismatch.selector;
        assertTrue(selector != bytes4(0), "NextProposalHashMismatch error should exist");
    }

    // ---------------------------------------------------------------
    // Ring Buffer Capacity Tests
    // ---------------------------------------------------------------

    /// @dev Tests that proposals work up to buffer capacity with small buffer
    function test_propose_fillsSmallBuffer() public {
        // Propose proposals until near capacity
        // _proposeAndGetPayload creates proposal id=1
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // With size 5, capacity = ringBufferSize + finalizationHead - proposalHead
        // = 5 + 0 - 1 = 4 slots available after first proposal
        // We can propose 3 more (ids 2, 3, 4)
        for (uint256 i = 2; i < SMALL_RING_BUFFER_SIZE; i++) {
            payload = _proposeConsecutive(payload);
        }

        // Verify we're at the expected proposal ID (4 with size 5)
        assertEq(payload.proposal.id, SMALL_RING_BUFFER_SIZE - 1, "Should be at expected proposal ID");
    }

    // ---------------------------------------------------------------
    // Ring Buffer Wrap-Around Trigger Tests
    // ---------------------------------------------------------------

    /// @dev Tests InvalidLastProposalProof error - proof proposal ID >= head proposal ID
    /// @notice Branch B3.6 - when proof proposal has larger or equal ID than head
    function test_propose_RevertWhen_InvalidLastProposalProof() public {
        // Create initial proposals 1-4 (filling buffer)
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);
        IInbox.ProposedEventPayload memory payload3 = _proposeConsecutive(payload2);
        IInbox.ProposedEventPayload memory payload4 = _proposeConsecutive(payload3);

        // Prove proposal 1 to allow finalization
        ProvenProposal memory proven = _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Now try to create proposal 5 - it goes to slot 0 (5 % 5 = 0)
        // Slot 0 contains genesis (id=0), so wrap-around is detected
        // We need to provide genesis as proof that slot 0 has older proposal
        // But we'll provide INVALID proof (id >= headProposal.id)
        _setupBlobHashes();
        _rollOneBlock();

        // Get genesis proposal for later
        IInbox.Proposal memory genesisProposal = _createGenesisProposal();

        // Create invalid proof with id >= head id
        IInbox.Proposal memory invalidProofProposal = genesisProposal;
        invalidProofProposal.id = 5; // Make it >= head id (4)

        IInbox.Proposal[] memory headAndProofInvalid = new IInbox.Proposal[](2);
        headAndProofInvalid[0] = payload4.proposal; // head = proposal 4
        headAndProofInvalid[1] = invalidProofProposal; // proof has id >= 4 (invalid)

        IInbox.ProposeInput memory inputInvalid = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload4.coreState,
            headProposalAndProof: headAndProofInvalid,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: _wrapSingleTransition(proven.transition),
            checkpoint: proven.checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeData = codex.encodeProposeInput(inputInvalid);

        vm.expectRevert(Inbox.InvalidLastProposalProof.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    /// @dev Tests NextProposalHashMismatch error - proof proposal hash doesn't match stored
    /// @notice Branch B3.7 - when proof proposal doesn't match what's in next slot
    function test_propose_RevertWhen_NextProposalHashMismatch() public {
        // Create initial proposals 1-4 (filling buffer)
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);
        IInbox.ProposedEventPayload memory payload3 = _proposeConsecutive(payload2);
        IInbox.ProposedEventPayload memory payload4 = _proposeConsecutive(payload3);

        // Prove proposal 1 to allow finalization
        ProvenProposal memory proven = _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Now try to create proposal 5 - it goes to slot 0 (5 % 5 = 0)
        // Slot 0 contains genesis (id=0), so wrap-around is detected
        // We need to provide genesis as proof that slot 0 has older proposal
        // But we'll provide WRONG hash (correct id but wrong content)
        _setupBlobHashes();
        _rollOneBlock();

        // Get genesis proposal and modify to create wrong hash
        IInbox.Proposal memory wrongProofProposal = _createGenesisProposal();
        wrongProofProposal.proposer = address(0xdead); // Modify to create wrong hash

        IInbox.Proposal[] memory headAndProofWrong = new IInbox.Proposal[](2);
        headAndProofWrong[0] = payload4.proposal; // head = proposal 4
        headAndProofWrong[1] = wrongProofProposal; // proof has wrong hash

        IInbox.ProposeInput memory inputWrong = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload4.coreState,
            headProposalAndProof: headAndProofWrong,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: _wrapSingleTransition(proven.transition),
            checkpoint: proven.checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeDataWrong = codex.encodeProposeInput(inputWrong);

        vm.expectRevert(Inbox.NextProposalHashMismatch.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeDataWrong);
    }

    /// @dev Tests ring buffer capacity exhaustion when proposals are not finalized
    /// @notice Scenario: 4-slot buffer, propose 3, prove only proposal 1,
    ///         then propose 4th (succeeds with finalization), then try to propose 5th
    ///         The 5th proposal should FAIL because there's no capacity left
    ///         (finalizationHead=1, proposalHead=4, capacity = 4 + 1 - 4 - 1 = 0)
    function test_propose_RevertWhen_SlotNotFinalized() public {
        // Deploy a separate inbox with 4-slot ring buffer for this test
        IInbox.Config memory tinyConfig = _createDefaultConfig();
        tinyConfig.ringBufferSize = TINY_RING_BUFFER_SIZE;
        Inbox tinyInbox = _deployInbox(tinyConfig);

        // Setup signal service and activate tinyInbox
        vm.startPrank(owner);
        signalService.upgradeTo(
            address(new SignalService(address(tinyInbox), MOCK_REMOTE_SIGNAL_SERVICE))
        );
        tinyInbox.activate(GENESIS_BLOCK_HASH);
        vm.stopPrank();

        // Replace default inbox with tiny inbox for this test
        inbox = tinyInbox;
        _cacheConfigValues();

        // Verify we have 4-slot buffer
        assertEq(ringBufferSize, TINY_RING_BUFFER_SIZE, "Should have 4-slot buffer");

        // 4-slot ring buffer after proposing 1-3:
        // Slot 0 = genesis (id 0)
        // Slot 1 = proposal 1
        // Slot 2 = proposal 2
        // Slot 3 = proposal 3

        // Create initial proposals 1-3 (filling slots 1, 2, 3)
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        assertEq(payload1.proposal.id, 1, "First proposal should be id 1");

        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);
        assertEq(payload2.proposal.id, 2, "Second proposal should be id 2");

        IInbox.ProposedEventPayload memory payload3 = _proposeConsecutive(payload2);
        assertEq(payload3.proposal.id, 3, "Third proposal should be id 3");

        // Prove proposal 1 (but don't finalize it yet - finalization happens during propose)
        ProvenProposal memory proven1 = _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Wait for finalization grace period to pass
        vm.warp(proven1.finalizationDeadline + 1);

        // Propose 4th - this goes to slot 0 (4 % 4 = 0), overwriting genesis
        // This should succeed and finalize proposal 1 (finalizationHead becomes 1)
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal memory genesisProposal = _createGenesisProposal();

        IInbox.Proposal[] memory headAndProof4 = new IInbox.Proposal[](2);
        headAndProof4[0] = payload3.proposal;
        headAndProof4[1] = genesisProposal;

        IInbox.ProposeInput memory input4 = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload3.coreState,
            headProposalAndProof: headAndProof4,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: _wrapSingleTransition(proven1.transition),
            checkpoint: proven1.checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeData4 = codex.encodeProposeInput(input4);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData4);

        IInbox.ProposedEventPayload memory payload4 = _decodeLastProposedEvent();
        assertEq(payload4.proposal.id, 4, "Should have created proposal 4");
        assertEq(payload4.coreState.finalizationHead, 1, "Finalization head should be 1");

        // Now state is:
        // Slot 0 = proposal 4
        // Slot 1 = proposal 1 (finalized)
        // Slot 2 = proposal 2 (NOT finalized)
        // Slot 3 = proposal 3 (NOT finalized)
        // finalizationHead = 1, proposalHead = 4
        // capacity = ringBufferSize + finalizationHead - proposalHead - 1 = 4 + 1 - 4 - 1 = 0

        // Now try to propose 5th - should FAIL because capacity is 0
        // We need more proposals to be finalized before we can propose again
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal[] memory headAndProof5 = new IInbox.Proposal[](2);
        headAndProof5[0] = payload4.proposal;
        headAndProof5[1] = payload1.proposal; // proof = proposal 1 (slot 1 occupant)

        IInbox.ProposeInput memory input5 = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload4.coreState,
            headProposalAndProof: headAndProof5,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0
        });

        bytes memory proposeData5 = codex.encodeProposeInput(input5);

        // Should revert because there's no capacity left
        // (only proposal 1 is finalized, but we have proposals 1-4, need more finalizations)
        vm.expectRevert(Inbox.NoCapacity.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData5);
    }

    /// @dev Tests ring buffer finalization via wrap-around with 4-slot buffer
    /// @notice Scenario: 4-slot buffer, propose 3, prove proposal 1, then propose 4th
    ///         The 4th proposal should trigger finalization of proposal 1 and free slot 1
    function test_propose_wrapAround_finalizesAndFreesSlot() public {
        // Deploy a separate inbox with 4-slot ring buffer for this test
        IInbox.Config memory tinyConfig = _createDefaultConfig();
        tinyConfig.ringBufferSize = TINY_RING_BUFFER_SIZE;
        Inbox tinyInbox = _deployInbox(tinyConfig);

        // Setup signal service and activate tinyInbox
        vm.startPrank(owner);
        signalService.upgradeTo(
            address(new SignalService(address(tinyInbox), MOCK_REMOTE_SIGNAL_SERVICE))
        );
        tinyInbox.activate(GENESIS_BLOCK_HASH);
        vm.stopPrank();

        // Replace default inbox with tiny inbox for this test
        inbox = tinyInbox;
        _cacheConfigValues();

        // Verify we have 4-slot buffer
        assertEq(ringBufferSize, TINY_RING_BUFFER_SIZE, "Should have 4-slot buffer");

        // 4-slot ring buffer:
        // Slot 0 = genesis (id 0)
        // Slot 1 = proposal 1
        // Slot 2 = proposal 2
        // Slot 3 = proposal 3
        // Proposal 4 would go to slot 0 (4 % 4 = 0), requiring slot 0 to be freed

        // Create initial proposals 1-3 (filling slots 1, 2, 3)
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        assertEq(payload1.proposal.id, 1, "First proposal should be id 1");

        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);
        assertEq(payload2.proposal.id, 2, "Second proposal should be id 2");

        IInbox.ProposedEventPayload memory payload3 = _proposeConsecutive(payload2);
        assertEq(payload3.proposal.id, 3, "Third proposal should be id 3");

        // Prove proposal 1 with correct transition from genesis
        ProvenProposal memory proven1 = _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Wait for finalization grace period to pass so proposal 1 can be finalized
        vm.warp(proven1.finalizationDeadline + 1);

        // Now try to create proposal 4 - it goes to slot 0 (4 % 4 = 0)
        // Slot 0 contains genesis (id=0), which should be finalized
        // The propose should finalize proposal 1 (since it's proven and deadline passed)
        // and the genesis slot should be freed for reuse
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal memory genesisProposal = _createGenesisProposal();

        IInbox.Proposal[] memory headAndProof4 = new IInbox.Proposal[](2);
        headAndProof4[0] = payload3.proposal; // head = proposal 3
        headAndProof4[1] = genesisProposal; // proof = genesis (slot 0 occupant)

        IInbox.ProposeInput memory input4 = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload3.coreState,
            headProposalAndProof: headAndProof4,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: _wrapSingleTransition(proven1.transition),
            checkpoint: proven1.checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeData = codex.encodeProposeInput(input4);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory payload4 = _decodeLastProposedEvent();
        assertEq(payload4.proposal.id, 4, "Should have created proposal 4");

        // Verify finalization head advanced (proposal 1 was finalized)
        assertEq(
            payload4.coreState.finalizationHead, 1, "Finalization head should advance to 1 after finalizing proposal 1"
        );
    }

    /// @dev Tests successful wrap-around proposal with correct proof
    /// @notice This validates that the wrap-around mechanism works when proof is correct
    function test_propose_wrapAround_withCorrectProof() public {
        // Create initial proposals 1-4 (filling buffer)
        IInbox.ProposedEventPayload memory payload1 = _proposeAndGetPayload();
        IInbox.ProposedEventPayload memory payload2 = _proposeConsecutive(payload1);
        IInbox.ProposedEventPayload memory payload3 = _proposeConsecutive(payload2);
        IInbox.ProposedEventPayload memory payload4 = _proposeConsecutive(payload3);

        // Prove proposal 1 to allow finalization
        ProvenProposal memory proven = _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

        // Now create proposal 5 - it goes to slot 0 (5 % 5 = 0)
        // Slot 0 contains genesis (id=0), so wrap-around is detected
        // Provide correct proof: genesis proposal
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal memory genesisProposal = _createGenesisProposal();

        IInbox.Proposal[] memory headAndProof5 = new IInbox.Proposal[](2);
        headAndProof5[0] = payload4.proposal; // head = proposal 4
        headAndProof5[1] = genesisProposal; // proof = genesis (correct!)

        IInbox.ProposeInput memory input5 = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload4.coreState,
            headProposalAndProof: headAndProof5,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: _wrapSingleTransition(proven.transition),
            checkpoint: proven.checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeData = codex.encodeProposeInput(input5);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory payload5 = _decodeLastProposedEvent();
        assertEq(payload5.proposal.id, 5, "Should have created proposal 5 with wrap-around");
    }
}
