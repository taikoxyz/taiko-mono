// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

// Import errors from Inbox implementation
import "src/layer1/shasta/impl/Inbox.sol";

/// @title AbstractProposeTest
/// @notice All propose tests for Inbox implementations
abstract contract AbstractProposeTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address internal currentProposer = Bob;
    address internal nextProposer = Carol;
    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        // Select a proposer for testing
        currentProposer = _selectProposer(Bob);

        //TODO: ideally we also setup the blob hashes here to avoid doing it on each test but it
        // doesn't last until the test run
    }

    // ---------------------------------------------------------------
    // Main tests with gas snapshot
    // ---------------------------------------------------------------

    /// forge-config: default.isolate = true
    function test_propose() public {
        _setupBlobHashes();

        vm.startPrank(currentProposer);

        vm.roll(block.number + 1);

        // Create proposal input after block roll to match checkpoint values
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);

        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.startSnapshotGas(
            "shasta-propose", string.concat("propose_single_empty_ring_buffer_", inboxContractName)
        );
        inbox.propose(bytes(""), proposeData);
        vm.stopSnapshotGas();

        // Assert: Verify proposal hash is stored
        bytes32 storedHash = inbox.getProposalHash(1);
        assertTrue(storedHash != bytes32(0), "Proposal hash should be stored");
    }

    // ---------------------------------------------------------------
    // Deadline Validation Tests
    // ---------------------------------------------------------------

    function test_propose_withValidFutureDeadline() public {
        _setupBlobHashes();

        // Should succeed with valid future deadline
        vm.roll(block.number + 1);

        // Create proposal with future deadline after block roll
        bytes memory proposeData = _codec().encodeProposeInput(
            _createProposeInputWithDeadline(uint48(block.timestamp + 1 hours))
        );

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal was created with correct hash
        bytes32 expectedHash = _codec().hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Proposal hash mismatch");
    }

    function test_propose_withZeroDeadline() public {
        _setupBlobHashes();

        // Should succeed with zero deadline
        vm.roll(block.number + 1);

        // Create proposal input after block roll
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal was created with correct hash
        bytes32 expectedHash = _codec().hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Proposal hash mismatch");
    }

    function test_propose_RevertWhen_DeadlineExpired() public {
        _setupBlobHashes();

        // Advance time first
        vm.warp(block.timestamp + 2 hours);

        // Create proposal with expired deadline
        bytes memory proposeData = _codec().encodeProposeInput(
            _createProposeInputWithDeadline(uint48(block.timestamp - 1 hours))
        );

        // Should revert with DeadlineExceeded
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Blob Validation Tests
    // ---------------------------------------------------------------

    function test_propose_withSingleBlob() public {
        _setupBlobHashes();

        vm.roll(block.number + 1);

        // Create proposal input after block roll
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash and blob configuration
        bytes32 expectedHash = _codec().hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Single blob proposal hash mismatch");
    }

    function test_propose_withMultipleBlobs() public virtual {
        _setupBlobHashes();

        vm.roll(block.number + 1);

        // Create proposal input with multiple blobs after block roll
        bytes memory proposeData = _codec().encodeProposeInput(_createProposeInputWithBlobs(3, 0));

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayloadWithBlobs(1, 3, 0);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash
        bytes32 expectedHash = _codec().hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Multiple blob proposal hash mismatch");
    }

    function test_propose_RevertWhen_BlobIndexOutOfRange() public {
        _setupBlobHashes(); // Sets up 9 blob hashes

        // Create proposal with out-of-range blob index using custom params
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        LibBlobs.BlobReference memory blobRef = _createBlobRef(
            10, // Out of range (we only have 9 blobs)
            1, // numBlobs
            0 // offset
        );

        bytes memory proposeData = _codec().encodeProposeInput(
            _createProposeInputWithCustomParams(
                0, // no deadline
                blobRef,
                parentProposals,
                coreState
            )
        );

        // Should revert when accessing invalid blob
        vm.expectRevert();
        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_withBlobOffset() public virtual {
        _setupBlobHashes();

        vm.roll(block.number + 1);

        // Create proposal input with blob offset after block roll
        bytes memory proposeData = _codec().encodeProposeInput(_createProposeInputWithBlobs(2, 100));

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayloadWithBlobs(1, 2, 100);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash and check that offset was correctly included
        bytes32 expectedHash = _codec().hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Blob with offset proposal hash mismatch");
    }

    // ---------------------------------------------------------------
    // Multiple Proposal Tests
    // ---------------------------------------------------------------

    function test_propose_twoConsecutiveProposals() public virtual {
        _setupBlobHashes();

        // First proposal (ID 1)
        vm.roll(block.number + 1);

        // Create proposal input after block roll
        bytes memory firstProposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory firstExpectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(firstExpectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), firstProposeData);

        // Verify first proposal
        bytes32 firstProposalHash = inbox.getProposalHash(1);
        assertEq(
            firstProposalHash,
            _codec().hashProposal(firstExpectedPayload.proposal),
            "First proposal hash mismatch"
        );

        // Advance block for second proposal (need 1 block gap)
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // Second proposal (ID 2) - using the first proposal as parent
        // First proposal set nextProposalBlockId to its block + 1
        // We advanced by 1 block after first proposal, so we should be at the right block
        IInbox.CoreState memory secondCoreState = IInbox.CoreState({
            nextProposalId: 2,
            nextProposalBlockId: uint48(block.number), // Current block (first proposal set it to
                // this)
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory secondParentProposals = new IInbox.Proposal[](1);
        secondParentProposals[0] = firstExpectedPayload.proposal;

        // No additional roll needed - we already advanced by 1 block above

        // Create second proposal input after block roll
        bytes memory secondProposeData = _codec().encodeProposeInput(
            _createProposeInputWithCustomParams(
                0, // no deadline
                _createBlobRef(0, 1, 0),
                secondParentProposals,
                secondCoreState
            )
        );

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory secondExpectedPayload = _buildExpectedProposedPayload(2);
        vm.expectEmit();
        emit IInbox.Proposed(_codec().encodeProposedEvent(secondExpectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), secondProposeData);

        // Verify second proposal
        bytes32 secondProposalHash = inbox.getProposalHash(2);
        assertEq(
            secondProposalHash,
            _codec().hashProposal(secondExpectedPayload.proposal),
            "Second proposal hash mismatch"
        );

        // Verify both proposals exist
        assertTrue(inbox.getProposalHash(1) != bytes32(0), "First proposal should still exist");
        assertTrue(inbox.getProposalHash(2) != bytes32(0), "Second proposal should exist");
        assertNotEq(
            inbox.getProposalHash(1),
            inbox.getProposalHash(2),
            "Proposals should have different hashes"
        );
    }

    function test_propose_RevertWhen_WrongParentProposal() public {
        _setupBlobHashes();

        // First, create the first proposal successfully
        bytes memory firstProposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), firstProposeData);

        // Now try to create a second proposal with a WRONG parent
        // We'll use genesis as parent instead of the first proposal (wrong!)
        IInbox.CoreState memory wrongCoreState = IInbox.CoreState({
            nextProposalId: 2,
            nextProposalBlockId: 2,
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Using genesis as parent instead of the first proposal - this is wrong!
        IInbox.Proposal[] memory wrongParentProposals = new IInbox.Proposal[](1);
        wrongParentProposals[0] = _createGenesisProposal();

        bytes memory wrongProposeData = _codec().encodeProposeInput(
            _createProposeInputWithCustomParams(
                0, _createBlobRef(0, 1, 0), wrongParentProposals, wrongCoreState
            )
        );

        // Should revert because parent proposal hash doesn't match
        vm.expectRevert(); // The specific error will depend on the Inbox implementation
        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), wrongProposeData);
    }

    function test_propose_RevertWhen_ParentProposalDoesNotExist() public {
        _setupBlobHashes();

        // Create a fake parent proposal that doesn't exist on-chain
        IInbox.Proposal memory fakeParent = IInbox.Proposal({
            id: 99, // This proposal doesn't exist
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(block.timestamp + 12),
            coreStateHash: keccak256("fake"),
            derivationHash: keccak256("fake")
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            nextProposalBlockId: 0,
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = fakeParent;

        bytes memory proposeData = _codec().encodeProposeInput(
            _createProposeInputWithCustomParams(
                0, _createBlobRef(0, 1, 0), parentProposals, coreState
            )
        );

        // Should revert because parent proposal doesn't exist
        vm.expectRevert();
        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), proposeData);
    }

    // Convenience overload with default blob parameters using currentProposer
    function _buildExpectedProposedPayload(uint48 _proposalId)
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        return _buildExpectedProposedPayload(_proposalId, 1, 0, currentProposer);
    }

    // Convenience function for buildExpectedProposedPayload with custom blob params
    function _buildExpectedProposedPayloadWithBlobs(
        uint48 _proposalId,
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        return _buildExpectedProposedPayload(_proposalId, _numBlobs, _offset, currentProposer);
    }
}
