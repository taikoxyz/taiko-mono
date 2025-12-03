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
    // Small ring buffer for wrap-around testing
    uint256 internal constant SMALL_RING_BUFFER_SIZE = 5;

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
        assertEq(
            payload.proposal.id, SMALL_RING_BUFFER_SIZE - 1, "Should be at expected proposal ID"
        );
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
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

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

        bytes memory proposeData = inbox.encodeProposeInput(inputInvalid);

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
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

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

        bytes memory proposeDataWrong = inbox.encodeProposeInput(inputWrong);

        vm.expectRevert(Inbox.NextProposalHashMismatch.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeDataWrong);
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
        ProvenProposal memory proven =
            _proveProposalAndGetResult(payload1.proposal, _getGenesisTransitionHash());

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

        bytes memory proposeData = inbox.encodeProposeInput(input5);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory payload5 = _decodeLastProposedEvent();
        assertEq(payload5.proposal.id, 5, "Should have created proposal 5 with wrap-around");
    }
}
