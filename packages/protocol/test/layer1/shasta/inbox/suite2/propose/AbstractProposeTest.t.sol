// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";
import { InboxTestSetup } from "../common/InboxTestSetup.sol";
import { BlobTestUtils } from "../common/BlobTestUtils.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { InboxHelper } from "contracts/layer1/shasta/impl/InboxHelper.sol";

// Import errors from Inbox implementation
import "contracts/layer1/shasta/impl/Inbox.sol";
// Import InvalidProposer error
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
// Import IncorrectFee error
import "contracts/layer1/shasta/libs/LibForcedInclusion.sol";

/// @title AbstractProposeTest
/// @notice All propose tests for Inbox implementations
abstract contract AbstractProposeTest is InboxTestSetup, BlobTestUtils {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address internal currentProposer = Bob;
    address internal nextProposer = Carol;
    InboxHelper internal helper;

    // Cache contract name to avoid repeated calls and potential recursion
    string private contractName;
    bool private useOptimizedInputEncoding;
    bool private useOptimizedEventEncoding;
    bool private useOptimizedHashing;

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        // Initialize the helper for encoding/decoding operations
        helper = new InboxHelper();

        // Cache contract name and determine encoding types
        contractName = getTestContractName();
        useOptimizedInputEncoding =
            keccak256(bytes(contractName)) == keccak256(bytes("InboxOptimized3"))
            || keccak256(bytes(contractName)) == keccak256(bytes("InboxOptimized4"));
        useOptimizedEventEncoding = keccak256(bytes(contractName))
            == keccak256(bytes("InboxOptimized2"))
            || keccak256(bytes(contractName)) == keccak256(bytes("InboxOptimized3"))
            || keccak256(bytes(contractName)) == keccak256(bytes("InboxOptimized4"));
        useOptimizedHashing = keccak256(bytes(contractName))
            == keccak256(bytes("InboxOptimized4"));

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
        // Act: Submit the proposal
        vm.startSnapshotGas(
            "shasta-propose",
            string.concat("propose_single_empty_ring_buffer_", getTestContractName())
        );
        vm.roll(block.number + 1);

        // Create proposal input after block roll to match checkpoint values
        bytes memory proposeData = _createFirstProposeInput();

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);

        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

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
        bytes memory proposeData =
            _createProposeInputWithDeadline(uint48(block.timestamp + 1 hours));

        // Expect the correct event
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(useOptimizedHashing, 1, 1, 0, currentProposer);
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal was created with correct hash
        bytes32 expectedHash = useOptimizedHashing
            ? helper.hashProposalOptimized(expectedPayload.proposal)
            : helper.hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Proposal hash mismatch");
    }

    function test_propose_withZeroDeadline() public {
        _setupBlobHashes();

        // Should succeed with zero deadline
        vm.roll(block.number + 1);

        // Create proposal input after block roll
        bytes memory proposeData = _createFirstProposeInput();

        // Expect the correct event
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(useOptimizedHashing, 1, 1, 0, currentProposer);
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal was created with correct hash
        bytes32 expectedHash = useOptimizedHashing
            ? helper.hashProposalOptimized(expectedPayload.proposal)
            : helper.hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Proposal hash mismatch");
    }

    function test_propose_RevertWhen_DeadlineExpired() public {
        _setupBlobHashes();

        // Advance time first
        vm.warp(block.timestamp + 2 hours);

        // Create proposal with expired deadline
        bytes memory proposeData =
            _createProposeInputWithDeadline(uint48(block.timestamp - 1 hours));

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
        bytes memory proposeData = _createFirstProposeInput();

        // Expect the correct event for single blob
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(useOptimizedHashing, 1, 1, 0, currentProposer);
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash and blob configuration
        bytes32 expectedHash = useOptimizedHashing
            ? helper.hashProposalOptimized(expectedPayload.proposal)
            : helper.hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Single blob proposal hash mismatch");
    }

    function test_propose_withMultipleBlobs() public {
        _setupBlobHashes();

        vm.roll(block.number + 1);

        // Create proposal input with multiple blobs after block roll
        bytes memory proposeData = _createProposeInputWithBlobs(3, 0);

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(useOptimizedHashing, 1, 3, 0, currentProposer);
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash
        bytes32 expectedHash = useOptimizedHashing
            ? helper.hashProposalOptimized(expectedPayload.proposal)
            : helper.hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Multiple blob proposal hash mismatch");
    }

    function test_propose_RevertWhen_BlobIndexOutOfRange() public {
        _setupBlobHashes(); // Sets up 9 blob hashes

        // Create proposal with out-of-range blob index using custom params
        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal(useOptimizedHashing);

        LibBlobs.BlobReference memory blobRef = _createBlobRef(
            10, // Out of range (we only have 9 blobs)
            1, // numBlobs
            0 // offset
        );

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0, // no deadline
            blobRef,
            parentProposals,
            coreState
        );

        // Should revert when accessing invalid blob
        vm.expectRevert();
        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_withBlobOffset() public {
        _setupBlobHashes();

        vm.roll(block.number + 1);

        // Create proposal input with blob offset after block roll
        bytes memory proposeData = _createProposeInputWithBlobs(2, 100);

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(useOptimizedHashing, 1, 2, 100, currentProposer);
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(expectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal hash and check that offset was correctly included
        bytes32 expectedHash = useOptimizedHashing
            ? helper.hashProposalOptimized(expectedPayload.proposal)
            : helper.hashProposal(expectedPayload.proposal);
        assertEq(inbox.getProposalHash(1), expectedHash, "Blob with offset proposal hash mismatch");
    }

    // ---------------------------------------------------------------
    // Forced Inclusion Tests
    // ---------------------------------------------------------------

    function test_propose_withSingleForcedInclusion() public {
        _setupBlobHashes();

        (LibBlobs.BlobReference[] memory forcedRefs, uint48[] memory forcedTimestamps) =
            _storeForcedInclusions(1, 0);

        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory parentProposals = _singleParentArray(_createGenesisProposal(useOptimizedHashing));

        bytes memory proposeData = _createProposeInputWithForcedInclusions(
            0,
            _createBlobRef(1, 1, 0),
            parentProposals,
            coreState,
            1
        );

        // Expect forced inclusion event first (proposal ID 1)
        IInbox.ProposedEventPayload memory forcedPayload = _buildExpectedForcedInclusionPayload(
            useOptimizedHashing,
            1,
            uint16(forcedRefs[0].blobStartIndex),
            uint8(forcedRefs[0].numBlobs),
            forcedRefs[0].offset,
            forcedTimestamps[0]
        );
        forcedPayload.proposal.proposer = currentProposer; // Use actual proposer, not address(0)
        _expectProposedEvent(forcedPayload);

        // Then expect regular proposal event (proposal ID 2)
        _expectProposedEvent(
            _buildExpectedProposedPayloadWithStartIndex(useOptimizedHashing, 2, 1, 1, 0, currentProposer)
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        _assertProposalsPresent(1, 2);
    }

    function test_propose_withMultipleForcedInclusions() public {
        _setupBlobHashes();

        (LibBlobs.BlobReference[] memory forcedRefs, uint48[] memory forcedTimestamps) =
            _storeForcedInclusions(3, 0);

        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory parentProposals = _singleParentArray(_createGenesisProposal(useOptimizedHashing));

        bytes memory proposeData = _createProposeInputWithForcedInclusions(
            0,
            _createBlobRef(3, 1, 0),
            parentProposals,
            coreState,
            3
        );

        // Expect forced inclusion events for proposals 1-3
        for (uint256 i = 0; i < forcedRefs.length; i++) {
            IInbox.ProposedEventPayload memory forcedPayload = _buildExpectedForcedInclusionPayload(
                useOptimizedHashing,
                uint48(1 + i),
                uint16(forcedRefs[i].blobStartIndex),
                uint8(forcedRefs[i].numBlobs),
                forcedRefs[i].offset,
                forcedTimestamps[i]
            );
            forcedPayload.proposal.proposer = currentProposer; // Use actual proposer
            _expectProposedEvent(forcedPayload);
        }

        // Then expect regular proposal event (proposal ID 4)
        _expectProposedEvent(
            _buildExpectedProposedPayloadWithStartIndex(useOptimizedHashing, 4, 3, 1, 0, currentProposer)
        );

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        _assertProposalsPresent(1, 4);
    }

    function test_propose_RevertWhen_InsufficientCapacityForForcedInclusions() public {
        _setupBlobHashes();

        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;
        
        // Fill the ring buffer to near capacity (leave only 1 slot)
        (IInbox.Proposal memory lastProposal, IInbox.CoreState memory coreState) =
            _fillRingBufferTo(uint48(ringBufferSize - 1));

        // Try to store 2 forced inclusions when we only have 1 slot left
        _storeForcedInclusions(2, 0);

        bytes memory proposeData = _createProposeInputWithForcedInclusions(
            0,
            _createBlobRef(2, 1, 0),
            _singleParentArray(lastProposal),
            coreState,
            2 // Trying to include 2 forced inclusions
        );

        // Should revert because we don't have enough capacity
        vm.expectRevert(ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_UnprocessedForcedInclusionIsDue() public {
        _setupBlobHashes();

        _storeForcedInclusions(1, 0);

        uint64 forcedInclusionDelay = inbox.getConfig().forcedInclusionDelay;
        vm.warp(block.timestamp + forcedInclusionDelay + 1);

        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory parentProposals = _singleParentArray(_createGenesisProposal(useOptimizedHashing));

        uint256 minForcedInclusionCount = inbox.getConfig().minForcedInclusionCount;

        bytes memory proposeData = _createProposeInputWithForcedInclusions(
            0,
            _createBlobRef(1, 1, 0),
            parentProposals,
            coreState,
            uint8(minForcedInclusionCount - 1)
        );

        vm.expectRevert(UnprocessedForcedInclusionIsDue.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_ForcedInclusionPrioritizedWhenOneSpaceLeft() public {
        _setupBlobHashes();

        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;
        
        // Fill the ring buffer to leave only 1 space
        (IInbox.Proposal memory lastProposal, IInbox.CoreState memory coreState) = 
            _fillRingBufferTo(uint48(ringBufferSize - 1));

        // Store one forced inclusion
        _storeForcedInclusions(1, 0);

        // Try to propose with both a forced inclusion and a regular proposal
        // When there's only 1 space left and 1 forced inclusion is processed,
        // the regular proposal should NOT be included
        bytes memory proposeData = _createProposeInputWithForcedInclusions(
            0,
            _createBlobRef(1, 1, 0),  // Regular proposal blob
            _singleParentArray(lastProposal),
            coreState,
            1  // Process 1 forced inclusion
        );

        // We expect exactly one Proposed event to be emitted (for the forced inclusion only)
        // The regular proposal should NOT be emitted since there's no capacity left
        
        vm.prank(currentProposer);
        vm.recordLogs();
        inbox.propose(bytes(""), proposeData);
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Should have exactly one Proposed event
        uint256 proposedEventCount = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == IInbox.Proposed.selector) {
                proposedEventCount++;
            }
        }
        assertEq(proposedEventCount, 1, "Should emit exactly one Proposed event");

        // Verify that the forced inclusion was stored at the expected slot
        bytes32 forcedInclusionHash = inbox.getProposalHash(uint48(ringBufferSize - 1));
        assertNotEq(forcedInclusionHash, bytes32(0), "Forced inclusion should be stored");

        // Verify that no regular proposal was stored by checking slot 0 still contains genesis
        bytes32 slot0Hash = inbox.getProposalHash(0);
        IInbox.Proposal memory genesisProposal = _createGenesisProposal(useOptimizedHashing);
        bytes32 genesisHash = useOptimizedHashing
            ? helper.hashProposalOptimized(genesisProposal)
            : helper.hashProposal(genesisProposal);
        assertEq(slot0Hash, genesisHash, "Slot 0 should still contain genesis proposal (no regular proposal stored)");
    }

    // ---------------------------------------------------------------
    // Core State Validation Tests
    // ---------------------------------------------------------------

    function test_propose_RevertWhen_CoreStateHashMismatch() public {
        _setupBlobHashes();

        // Create a core state that doesn't match the parent proposal
        IInbox.CoreState memory wrongCoreState = IInbox.CoreState({
            nextProposalId: 5, // Wrong nextProposalId
            nextProposalBlockId: 0,  // Add missing field
            lastFinalizedProposalId: 2, // Wrong finalized ID
            lastFinalizedTransitionHash: keccak256("wrong"),
            bondInstructionsHash: bytes32(uint256(123))
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal(useOptimizedHashing);

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0, // no deadline
            _createBlobRef(0, 1, 0),
            parentProposals,
            wrongCoreState
        );

        vm.expectRevert(InvalidState.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_EmptyParentProposals() public {
        _setupBlobHashes();

        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory emptyParentProposals = new IInbox.Proposal[](0);

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            emptyParentProposals,
            coreState
        );

        vm.expectRevert(EmptyProposals.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Proposer Authorization Tests
    // ---------------------------------------------------------------

    function test_propose_RevertWhen_UnauthorizedProposer() public {
        _setupBlobHashes();

        bytes memory proposeData = _createFirstProposeInput();

        // Try to propose with an unauthorized address (not currentProposer)
        address unauthorizedProposer = address(0x9999);
        
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        vm.prank(unauthorizedProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Chain Head Verification Tests
    // ---------------------------------------------------------------

    // Test the scenario where the ring buffer has wrapped and the next slot is occupied
    // This requires providing 2 parent proposals instead of 1
    function test_propose_withOccupiedNextSlot() public {
        _setupBlobHashes();

        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;
        
        // Fill the ring buffer completely to cause it to wrap
        (IInbox.Proposal memory lastProposal, IInbox.CoreState memory coreState) = 
            _fillRingBufferTo(uint48(ringBufferSize));

        // Now the ring buffer has wrapped - slot 0 is occupied by proposal 100
        // When we create proposal 101, we need to provide 2 parents:
        // 1. The last proposal (id=100) 
        // 2. The proposal in the next slot that will be overwritten (id=0, genesis)
        
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // For wrapped ring buffer, we need 2 parent proposals
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](2);
        parentProposals[0] = lastProposal; // proposal 100
        parentProposals[1] = _createGenesisProposal(useOptimizedHashing); // proposal 0 in slot 0

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );

        // Should succeed with 2 parent proposals
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        assertNotEq(
            inbox.getProposalHash(uint48(ringBufferSize)), 
            bytes32(0), 
            "Proposal should exist after ring buffer wrap"
        );
    }

    // Test that providing wrong number of parent proposals fails

    function test_propose_RevertWhen_InvalidSecondParentProposal() public {
        _setupBlobHashes();

        // Create a simple scenario where slot is NOT occupied
        // First create proposal 1
        _createAndSubmitProposal(1);
        
        // Advance time
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        
        // Build proposal 1 reference
        IInbox.Proposal memory proposal1 = _buildProposal(1, currentProposer, INITIAL_BLOCK_TIMESTAMP);
        
        // Try to provide 2 parent proposals when only 1 is needed (slot 2 is empty)
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](2);
        parentProposals[0] = proposal1;
        parentProposals[1] = _createGenesisProposal(useOptimizedHashing); // Wrong - slot 2 is empty!

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            parentProposals,
            _buildCoreState(2, 0, _getGenesisTransitionHash(useOptimizedHashing))
        );

        // Should revert because we provided 2 parents when slot is empty
        vm.expectRevert(IncorrectProposalCount.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_RevertWhen_SecondParentHashMismatch() public {
        _setupBlobHashes();

        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;
        
        // Fill the ring buffer completely to cause wrapping
        (IInbox.Proposal memory lastProposal, IInbox.CoreState memory coreState) = 
            _fillRingBufferTo(uint48(ringBufferSize));

        // Now slot 0 is occupied by proposal 100 (genesis)
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // Create an INVALID second parent (wrong hash for the occupied slot)
        IInbox.Proposal memory wrongSecondParent = _createGenesisProposal(useOptimizedHashing);
        wrongSecondParent.coreStateHash = keccak256("wrong_hash"); // Modify to make hash wrong

        // Try with 2 parents where second parent has wrong hash
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](2);
        parentProposals[0] = lastProposal; // Correct first parent
        parentProposals[1] = wrongSecondParent; // Wrong second parent hash

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );

        // Should revert because second parent hash doesn't match what's in the slot
        vm.expectRevert(NextProposalHashMismatch.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Multiple Proposal Tests
    // ---------------------------------------------------------------

    function test_propose_twoConsecutiveProposals() public {
        _setupBlobHashes();

        // First proposal (ID 1)
        vm.roll(block.number + 1);

        // Create proposal input after block roll
        bytes memory firstProposeData = _createFirstProposeInput();

        // Build expected event data after block roll to match timestamps
        IInbox.ProposedEventPayload memory firstExpectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(firstExpectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), firstProposeData);

        // Verify first proposal
        bytes32 firstProposalHash = inbox.getProposalHash(1);
        bytes32 expectedFirstHash = useOptimizedHashing
            ? helper.hashProposalOptimized(firstExpectedPayload.proposal)
            : helper.hashProposal(firstExpectedPayload.proposal);
        assertEq(
            firstProposalHash,
            expectedFirstHash,
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
            lastFinalizedTransitionHash: _getGenesisTransitionHash(useOptimizedHashing),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory secondParentProposals = new IInbox.Proposal[](1);
        secondParentProposals[0] = firstExpectedPayload.proposal;

        // No additional roll needed - we already advanced by 1 block above

        // Create second proposal input after block roll
        bytes memory secondProposeData = _createProposeInputWithCustomParams(
            0, // no deadline
            _createBlobRef(0, 1, 0),
            secondParentProposals,
            secondCoreState
        );

        // Build expected payload for second proposal
        IInbox.ProposedEventPayload memory secondExpectedPayload = _buildExpectedProposedPayload(useOptimizedHashing, 2, 1, 0, currentProposer);

        vm.expectEmit();
        emit IInbox.Proposed(_encodeProposedEvent(secondExpectedPayload));

        vm.prank(currentProposer);
        inbox.propose(bytes(""), secondProposeData);

        // Verify second proposal
        bytes32 secondProposalHash = inbox.getProposalHash(2);
        bytes32 expectedSecondHash = useOptimizedHashing
            ? helper.hashProposalOptimized(secondExpectedPayload.proposal)
            : helper.hashProposal(secondExpectedPayload.proposal);
        assertEq(
            secondProposalHash,
            expectedSecondHash,
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
        bytes memory firstProposeData = _createFirstProposeInput();

        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), firstProposeData);

        // Now try to create a second proposal with a WRONG parent
        // We'll use genesis as parent instead of the first proposal (wrong!)
        IInbox.CoreState memory wrongCoreState = IInbox.CoreState({
            nextProposalId: 2,
            nextProposalBlockId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(useOptimizedHashing),
            bondInstructionsHash: bytes32(0)
        });

        // Using genesis as parent instead of the first proposal - this is wrong!
        IInbox.Proposal[] memory wrongParentProposals = new IInbox.Proposal[](1);
        wrongParentProposals[0] = _createGenesisProposal(useOptimizedHashing);

        bytes memory wrongProposeData = _createProposeInputWithCustomParams(
            0, _createBlobRef(0, 1, 0), wrongParentProposals, wrongCoreState
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
            lastFinalizedTransitionHash: _getGenesisTransitionHash(useOptimizedHashing),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = fakeParent;

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0, _createBlobRef(0, 1, 0), parentProposals, coreState
        );

        // Should revert because parent proposal doesn't exist
        vm.expectRevert();
        vm.prank(currentProposer);
        vm.roll(block.number + 1);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Ring buffer tests
    // ---------------------------------------------------------------


    function test_propose_ringBufferFull() public {
        _setupBlobHashes();

        uint256 ringBufferSize = inbox.getConfig().ringBufferSize;

        // Fill the ring buffer completely (creates proposals 1-99)
        (IInbox.Proposal memory lastProposal, IInbox.CoreState memory coreState) =
            _fillRingBufferTo(uint48(ringBufferSize));

        // Now the ring buffer is full, next proposal will wrap to slot 0
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // For wrapped ring buffer, we need 2 parent proposals
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](2);
        parentProposals[0] = lastProposal; // proposal 99
        parentProposals[1] = _createGenesisProposal(useOptimizedHashing); // proposal 0 in slot 0

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );

        // Use Alice as the proposer (fallback after crossing epochs)
        vm.startPrank(Alice);
        vm.startSnapshotGas(
            "shasta-propose",
            string.concat("propose_single_empty_ring_buffer_", getTestContractName())
        );
        inbox.propose(bytes(""), proposeData);
        vm.stopSnapshotGas();
        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Propose Input Builders
    // ---------------------------------------------------------------

    /// @notice Encodes ProposeInput using appropriate method based on inbox type
    function _encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedInputEncoding) {
            return helper.encodeProposeInputOptimized(_input);
        } else {
            return helper.encodeProposeInput(_input);
        }
    }

    /// @notice Encodes ProposedEventPayload using appropriate method based on inbox type
    function _encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedEventEncoding) {
            return helper.encodeProposedEventOptimized(_payload);
        } else {
            return helper.encodeProposedEvent(_payload);
        }
    }
    function _createProposeInputWithForcedInclusions(
        uint48 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _parentProposals,
        IInbox.CoreState memory _coreState,
        uint8 _numForcedInclusions
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            parentProposals: _parentProposals,
            blobReference: _blobRef,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            numForcedInclusions: _numForcedInclusions
        });

        return _encodeProposeInput(input);
    }

    function _createProposeInputWithCustomParams(
        uint48 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _parentProposals,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            parentProposals: _parentProposals,
            blobReference: _blobRef,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            numForcedInclusions: 0
        });

        return _encodeProposeInput(input);
    }

    function _createFirstProposeInput() internal view returns (bytes memory) {
        // For the first proposal after genesis, we need specific state
        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);

        // Parent proposal is genesis (id=0)
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal(useOptimizedHashing);

        // Create blob reference
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        // Create the propose input
        IInbox.ProposeInput memory input;
        input.coreState = coreState;
        input.parentProposals = parentProposals;
        input.blobReference = blobRef;

        return _encodeProposeInput(input);
    }

    function _createProposeInputWithDeadline(uint48 _deadline)
        internal
        view
        returns (bytes memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal(useOptimizedHashing);

        return _createProposeInputWithCustomParams(
            _deadline, _createBlobRef(0, 1, 0), parentProposals, coreState
        );
    }

    function _createProposeInputWithBlobs(
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState(useOptimizedHashing);
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal(useOptimizedHashing);

        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, _numBlobs, _offset);

        return _createProposeInputWithCustomParams(
            0, // no deadline
            blobRef,
            parentProposals,
            coreState
        );
    }

    function _expectProposedEvent(IInbox.ProposedEventPayload memory _payload) private {
        vm.expectEmit();
        bytes memory encodedData = useOptimizedEventEncoding
            ? helper.encodeProposedEventOptimized(_payload)
            : helper.encodeProposedEvent(_payload);
        emit IInbox.Proposed(encodedData);
    }

    function _singleParentArray(IInbox.Proposal memory _parent)
        private
        pure
        returns (IInbox.Proposal[] memory)
    {
        IInbox.Proposal[] memory parents = new IInbox.Proposal[](1);
        parents[0] = _parent;
        return parents;
    }

    function _storeForcedInclusions(uint8 _count, uint8 _startBlobIndex)
        private
        returns (LibBlobs.BlobReference[] memory refs_, uint48[] memory timestamps_)
    {
        refs_ = new LibBlobs.BlobReference[](_count);
        timestamps_ = new uint48[](_count);

        uint256 forcedInclusionFee = inbox.getConfig().forcedInclusionFeeInGwei * 1 gwei;

        for (uint8 i = 0; i < _count; i++) {
            LibBlobs.BlobReference memory ref = _createBlobRef(_startBlobIndex + i, 1, 0);
            refs_[i] = ref;
            timestamps_[i] = uint48(block.timestamp);

            vm.deal(Alice, forcedInclusionFee);
            vm.prank(Alice);
            inbox.storeForcedInclusion{value: forcedInclusionFee}(ref);
        }
    }


    function _assertProposalsPresent(uint48 _startProposalId, uint48 _count) private view {
        for (uint48 i = 0; i < _count; i++) {
            uint48 proposalId = _startProposalId + i;
            assertNotEq(
                inbox.getProposalHash(proposalId),
                bytes32(0),
                string.concat("Proposal ", vm.toString(proposalId), " missing")
            );
        }
    }

    // ---------------------------------------------------------------
    // Helper functions that directly use the boolean flag
    // ---------------------------------------------------------------

    function _buildExpectedProposedPayload(uint48 _proposalId)
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        return _buildExpectedProposedPayload(useOptimizedHashing, _proposalId, 1, 0, currentProposer);
    }

    // ---------------------------------------------------------------
    // Simplified Helper Functions for Tests
    // ---------------------------------------------------------------

    function _createAndSubmitProposal(uint48) private {
        bytes memory proposeData = _createFirstProposeInput();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    function _buildProposal(
        uint48 _id,
        address _proposer,
        uint48 _timestamp
    )
        private
        view
        returns (IInbox.Proposal memory)
    {
        return IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: useOptimizedHashing
                ? helper.hashCoreStateOptimized(_buildCoreState(_id + 1, 0, _getGenesisTransitionHash(useOptimizedHashing)))
                : helper.hashCoreState(_buildCoreState(_id + 1, 0, _getGenesisTransitionHash(useOptimizedHashing))),
            derivationHash: useOptimizedHashing
                ? helper.hashDerivationOptimized(_buildDerivation(_timestamp))
                : helper.hashDerivation(_buildDerivation(_timestamp))
        });
    }

    function _buildCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedTransitionHash
    )
        private
        pure
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            nextProposalBlockId: 0,  // Add missing field
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedTransitionHash: _lastFinalizedTransitionHash,
            bondInstructionsHash: bytes32(0)
        });
    }

    function _buildDerivation(uint48 _timestamp) private view returns (IInbox.Derivation memory) {
        return IInbox.Derivation({
            originBlockNumber: uint48(INITIAL_BLOCK_NUMBER - 1),
            originBlockHash: blockhash(INITIAL_BLOCK_NUMBER - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: 0,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _getBlobHashesForTest(1),
                offset: 0,
                timestamp: _timestamp
            })
        });
    }

    // ---------------------------------------------------------------
    // Ring Buffer Management Helpers
    // ---------------------------------------------------------------

    /// @notice Fills the ring buffer up to a target proposal ID
    /// @dev It advances the timestamp by 12 seconds for each proposal
    /// @dev This is useful for testing edge cases near ring buffer capacity
    /// @param _targetNextProposalId The proposal ID to fill up to (exclusive)
    /// @return lastProposal_ The last proposal created
    /// @return coreState_ The core state after filling
    function _fillRingBufferTo(uint48 _targetNextProposalId)
        private
        returns (IInbox.Proposal memory lastProposal_, IInbox.CoreState memory coreState_)
    {
        // Start from genesis
        lastProposal_ = _createGenesisProposal(useOptimizedHashing);
        coreState_ = _getGenesisCoreState(useOptimizedHashing);

        // If target is already reached, return early
        if (_targetNextProposalId <= coreState_.nextProposalId) {
            return (lastProposal_, coreState_);
        }

        // Fill the ring buffer with proposals
        for (uint48 proposalId = coreState_.nextProposalId; proposalId < _targetNextProposalId; proposalId++) {
            // Advance time for each proposal to ensure unique timestamps
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 12);

            // Update core state for this proposal
            coreState_.nextProposalId = proposalId;
            coreState_.nextProposalBlockId = uint48(block.number); // Update to match current block

            // Create proposal input
            bytes memory proposeData = _createProposeInputWithCustomParams(
                0, // no deadline
                _createBlobRef(0, 1, 0), // single blob
                _singleParentArray(lastProposal_),
                coreState_
            );

            // Submit the proposal
            vm.prank(currentProposer);
            inbox.propose(bytes(""), proposeData);

            // Build the actual proposal that was created
            // The derivation hash needs to match what was actually submitted
            IInbox.Derivation memory actualDerivation = IInbox.Derivation({
                originBlockNumber: uint48(block.number - 1),
                originBlockHash: blockhash(block.number - 1),
                isForcedInclusion: false,
                basefeeSharingPctg: 0,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: _getBlobHashesForTest(1),
                    offset: 0,
                    timestamp: uint48(block.timestamp)
                })
            });
            
            // Create a copy of core state for the proposal hash before updating for next iteration
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: proposalId + 1,
                nextProposalBlockId: uint48(block.number + 1), // Contract sets this to block.number + 1
                lastFinalizedProposalId: coreState_.lastFinalizedProposalId,
                lastFinalizedTransitionHash: coreState_.lastFinalizedTransitionHash,
                bondInstructionsHash: coreState_.bondInstructionsHash
            });

            // Update last proposal reference for next iteration
            lastProposal_ = IInbox.Proposal({
                id: proposalId,
                proposer: currentProposer,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: 0,
                coreStateHash: useOptimizedHashing
                    ? helper.hashCoreStateOptimized(proposalCoreState)
                    : helper.hashCoreState(proposalCoreState),
                derivationHash: useOptimizedHashing
                    ? helper.hashDerivationOptimized(actualDerivation)
                    : helper.hashDerivation(actualDerivation)
            });

            // Update core state for next iteration
            coreState_ = proposalCoreState;
        }

        return (lastProposal_, coreState_);
    }
}
