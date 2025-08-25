// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "src/layer1/shasta/impl/Inbox.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title InboxTest
/// @notice All common tests for Inbox implementations
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTest is InboxTestBase {
    function setUp() public virtual override {
        // Deploy dependencies
        _setupDependencies();

        // Setup mocks - we usually avoid mocks as much as possible since they might make testing
        // flaky
        _setupMocks();

        // Deploy inbox through implementation-specific method
        inbox = deployInbox(
            address(bondToken),
            address(syncedBlockManager),
            address(proofVerifier),
            address(proposerChecker),
            address(forcedInclusionStore)
        );

        _upgradeDependencies(address(inbox));

        // Advance block to ensure we have block history
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);

        //TODO: ideally we also setup the blob hashes here to avoid doing it on each test but it
        // doesn't last until the test run
    }

    // ---------------------------------------------------------------
    // Main tests with gas snapshot
    // ---------------------------------------------------------------

    function test_propose() public {
        _setupBlobHashes();

        // Arrange: Create the first proposal input after genesis
        bytes memory proposeData = _createFirstProposeInput();

        // Build expected event data
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);

        // Expect the Proposed event with the correct data
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));

        // Act: Submit the proposal
        vm.startSnapshotGas(
            "shasta-propose", 
            string.concat("propose_single_empty_ring_buffer_", getTestContractName())
        );
        vm.prank(currentProposer);
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

        // Create proposal with future deadline using helper
        bytes memory proposeData = _createProposeInputWithDeadline(uint48(block.timestamp + 1 hours));
        
        // Expect the correct event
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));
        
        // Should succeed with valid future deadline
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Verify proposal was created with correct hash
        bytes32 expectedHash = keccak256(abi.encode(expectedPayload.proposal));
        assertEq(inbox.getProposalHash(1), expectedHash, "Proposal hash mismatch");
    }

    function test_propose_withZeroDeadline() public {
        _setupBlobHashes();

        // Use existing helper - zero deadline means no expiration
        bytes memory proposeData = _createFirstProposeInput();
        
        // Expect the correct event
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));
        
        // Should succeed with zero deadline
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Verify proposal was created with correct hash
        bytes32 expectedHash = keccak256(abi.encode(expectedPayload.proposal));
        assertEq(inbox.getProposalHash(1), expectedHash, "Proposal hash mismatch");
    }

    function test_propose_RevertWhen_DeadlineExpired() public {
        _setupBlobHashes();
        
        // Advance time first
        vm.warp(block.timestamp + 2 hours);
        
        // Create proposal with expired deadline
        bytes memory proposeData = _createProposeInputWithDeadline(uint48(block.timestamp - 1 hours));
        
        // Should revert with DeadlineExceeded
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Blob Validation Tests
    // ---------------------------------------------------------------

    function test_propose_withSingleBlob() public {
        _setupBlobHashes();
        
        // This is already tested in test_propose, but let's be explicit
        bytes memory proposeData = _createFirstProposeInput();
        
        // Expect the correct event for single blob
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(1);
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Verify proposal hash and blob configuration
        bytes32 expectedHash = keccak256(abi.encode(expectedPayload.proposal));
        assertEq(inbox.getProposalHash(1), expectedHash, "Single blob proposal hash mismatch");
    }

    function test_propose_withMultipleBlobs() public {
        _setupBlobHashes();

        // Use helper to create proposal with multiple blobs
        bytes memory proposeData = _createProposeInputWithBlobs(3, 0);
        
        // Expect the correct event for multiple blobs
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayloadWithBlobs(1, 3, 0);
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Verify proposal hash
        bytes32 expectedHash = keccak256(abi.encode(expectedPayload.proposal));
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
            1,  // numBlobs
            0   // offset
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
        inbox.propose(bytes(""), proposeData);
    }

    function test_propose_withBlobOffset() public {
        _setupBlobHashes();

        // Use helper to create proposal with blob offset
        bytes memory proposeData = _createProposeInputWithBlobs(2, 100);
        
        // Expect the correct event with blob offset
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayloadWithBlobs(1, 2, 100);
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(expectedPayload));
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Verify proposal hash and check that offset was correctly included
        bytes32 expectedHash = keccak256(abi.encode(expectedPayload.proposal));
        assertEq(inbox.getProposalHash(1), expectedHash, "Blob with offset proposal hash mismatch");
    }

    // ---------------------------------------------------------------
    // Multiple Proposal Tests
    // ---------------------------------------------------------------

    function test_propose_twoConsecutiveProposals() public {
        _setupBlobHashes();

        // First proposal (ID 1)
        bytes memory firstProposeData = _createFirstProposeInput();
        IInbox.ProposedEventPayload memory firstExpectedPayload = _buildExpectedProposedPayload(1);
        
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(firstExpectedPayload));
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), firstProposeData);
        
        // Verify first proposal
        bytes32 firstProposalHash = inbox.getProposalHash(1);
        assertEq(firstProposalHash, keccak256(abi.encode(firstExpectedPayload.proposal)), "First proposal hash mismatch");

        // Advance block for second proposal
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // Second proposal (ID 2) - using the first proposal as parent
        IInbox.CoreState memory secondCoreState = IInbox.CoreState({
            nextProposalId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
        
        IInbox.Proposal[] memory secondParentProposals = new IInbox.Proposal[](1);
        secondParentProposals[0] = firstExpectedPayload.proposal;
        
        bytes memory secondProposeData = _createProposeInputWithCustomParams(
            0, // no deadline
            _createBlobRef(0, 1, 0),
            secondParentProposals,
            secondCoreState
        );
        
        // Build expected payload for second proposal
        IInbox.ProposedEventPayload memory secondExpectedPayload = _buildExpectedProposedPayload(2);
        
        vm.expectEmit();
        emit IInbox.Proposed(inbox.encodeProposedEventData(secondExpectedPayload));
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), secondProposeData);
        
        // Verify second proposal
        bytes32 secondProposalHash = inbox.getProposalHash(2);
        assertEq(secondProposalHash, keccak256(abi.encode(secondExpectedPayload.proposal)), "Second proposal hash mismatch");
        
        // Verify both proposals exist
        assertTrue(inbox.getProposalHash(1) != bytes32(0), "First proposal should still exist");
        assertTrue(inbox.getProposalHash(2) != bytes32(0), "Second proposal should exist");
        assertNotEq(inbox.getProposalHash(1), inbox.getProposalHash(2), "Proposals should have different hashes");
    }

    function test_propose_RevertWhen_WrongParentProposal() public {
        _setupBlobHashes();

        // First, create the first proposal successfully
        bytes memory firstProposeData = _createFirstProposeInput();
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), firstProposeData);

        // Now try to create a second proposal with a WRONG parent
        // We'll use genesis as parent instead of the first proposal (wrong!)
        IInbox.CoreState memory wrongCoreState = IInbox.CoreState({
            nextProposalId: 2,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Using genesis as parent instead of the first proposal - this is wrong!
        IInbox.Proposal[] memory wrongParentProposals = new IInbox.Proposal[](1);
        wrongParentProposals[0] = _createGenesisProposal();

        bytes memory wrongProposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            wrongParentProposals,
            wrongCoreState
        );

        // Should revert because parent proposal hash doesn't match
        vm.expectRevert(); // The specific error will depend on the Inbox implementation
        vm.prank(currentProposer);
        inbox.propose(bytes(""), wrongProposeData);
    }

    function test_propose_RevertWhen_ParentProposalDoesNotExist() public {
        _setupBlobHashes();

        // Create a fake parent proposal that doesn't exist on-chain
        IInbox.Proposal memory fakeParent = IInbox.Proposal({
            id: 99, // This proposal doesn't exist
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            coreStateHash: keccak256("fake"),
            derivationHash: keccak256("fake")
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = fakeParent;

        bytes memory proposeData = _createProposeInputWithCustomParams(
            0,
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );

        // Should revert because parent proposal doesn't exist
        vm.expectRevert();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }
}
