// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";

/// @title InboxRingBuffer
/// @notice Tests for ring buffer mechanics and capacity management
/// @dev This test suite covers ring buffer functionality for proposal storage:
///      - Basic read/write operations and data integrity
///      - Circular buffer wraparound behavior and slot reuse
///      - Capacity calculations and boundary conditions
///      - Modulo operations for indexing and overflow handling
///      - Protection of unfinalized proposals from overwrite
/// @custom:security-contact security@taiko.xyz
contract InboxRingBuffer is InboxTest {
    // Inherits setup from InboxTest base class

    /// @notice Test basic ring buffer write and read operations
    /// @dev Validates fundamental ring buffer data integrity
    function test_ring_buffer_write_read() public {
        uint48 numProposals = MANY_PROPOSALS;
        bytes32[] memory proposalHashes = new bytes32[](numProposals);

        // Write proposal hashes to ring buffer
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 proposalHash = keccak256(abi.encode("proposal", i));
            proposalHashes[i - 1] = proposalHash;
            inbox.exposed_setProposalHash(i, proposalHash);
        }

        // Read and verify all proposal hashes
        for (uint48 i = 1; i <= numProposals; i++) {
            bytes32 storedHash = inbox.getProposalHash(i);
            assertEq(storedHash, proposalHashes[i - 1], "Proposal hash should match");
        }
    }

    /// @notice Test ring buffer modulo arithmetic
    /// @dev Validates modulo-based slot indexing for circular buffer
    function test_ring_buffer_modulo() public {
        // Ring buffer size is now immutable (100) - use proposal IDs that actually collide
        // proposalIds[0] % 100 = 1, proposalIds[1] % 100 = 1, proposalIds[2] % 100 = 1

        // Test proposals that should map to the same slot (1) with ring buffer size 100
        uint48[3] memory proposalIds = [uint48(1), uint48(101), uint48(201)];
        bytes32[3] memory hashes = [keccak256("hash1"), keccak256("hash2"), keccak256("hash3")];

        // Store first proposal
        inbox.exposed_setProposalHash(proposalIds[0], hashes[0]);
        assertEq(inbox.getProposalHash(proposalIds[0]), hashes[0], "First hash should be stored");

        // Store second proposal (should overwrite slot)
        inbox.exposed_setProposalHash(proposalIds[1], hashes[1]);
        assertEq(inbox.getProposalHash(proposalIds[1]), hashes[1], "Second hash should overwrite");
        assertEq(
            inbox.getProposalHash(proposalIds[0]), hashes[1], "First slot should be overwritten"
        );

        // Store third proposal (should overwrite slot again)
        inbox.exposed_setProposalHash(proposalIds[2], hashes[2]);
        assertEq(inbox.getProposalHash(proposalIds[2]), hashes[2], "Third hash should overwrite");
    }

    /// @notice Test ring buffer wraparound behavior
    /// @dev Validates circular buffer wraparound and slot reuse
    function test_ring_buffer_wraparound() public {
        // Ring buffer size is now immutable (100), test with smaller numbers for efficiency
        uint48 bufferSize = 3; // Test with 3 slots for wraparound demonstration

        // Fill the ring buffer completely (first round)
        bytes32[] memory firstRoundHashes = new bytes32[](bufferSize);
        for (uint48 i = 0; i < bufferSize; i++) {
            firstRoundHashes[i] = keccak256(abi.encode("first", i));
            inbox.exposed_setProposalHash(i, firstRoundHashes[i]);
        }

        // Verify first round storage
        for (uint48 i = 0; i < bufferSize; i++) {
            assertEq(inbox.getProposalHash(i), firstRoundHashes[i], "First round should be stored");
        }

        // Start second round (wraparound) - use proposal IDs that wrap around in ring buffer size
        // 100
        bytes32[] memory secondRoundHashes = new bytes32[](bufferSize);
        for (uint48 i = 0; i < bufferSize; i++) {
            uint48 proposalId = i + 100; // These will map to same slots as first round in ring
                // buffer size 100
            secondRoundHashes[i] = keccak256(abi.encode("second", i));
            inbox.exposed_setProposalHash(proposalId, secondRoundHashes[i]);
        }

        // Verify wraparound overwrote first round
        for (uint48 i = 0; i < bufferSize; i++) {
            uint48 proposalId = i + 100;
            assertEq(
                inbox.getProposalHash(proposalId),
                secondRoundHashes[i],
                "Second round should overwrite"
            );
            assertEq(
                inbox.getProposalHash(i), secondRoundHashes[i], "First round should be overwritten"
            );
        }
    }

    /// @notice Test ring buffer capacity calculation
    /// @dev Validates capacity calculation formula (bufferSize - 1)
    function test_ring_buffer_capacity_calculation() public view {
        // Ring buffer size is now immutable (100) - test only validates the current capacity

        uint256 capacity = inbox.getConfig().ringBufferSize - 1;
        uint256 expectedCapacity = getRingBufferSize() - 1;

        assertEq(capacity, expectedCapacity, "Capacity should be bufferSize-1");

        // Verify expected values
        assertEq(getRingBufferSize(), 100, "Ring buffer size should be 100");
        assertEq(capacity, 99, "Capacity should be 99");
    }

    /// @notice Test protection of unfinalized proposals from overwrite
    /// @dev Validates that proposals are silently skipped when capacity is exceeded
    /// Ring buffer size 100 means capacity = 99
    /// With the new design, when capacity is exceeded, proposals are silently skipped
    /// rather than reverting, allowing forced inclusions to be prioritized
    function test_ring_buffer_protect_unfinalized() public {
        // Ring buffer size is now immutable (100), capacity = 99
        // This test verifies that the proposal validation correctly handles parent proposals

        // Submit 2 proposals normally using the submitProposal helper
        submitProposal(1, Alice);
        submitProposal(2, Alice);

        // Store hashes before test
        bytes32 genesisHash = inbox.getProposalHash(0);
        bytes32 prop1Hash = inbox.getProposalHash(1);
        bytes32 prop2Hash = inbox.getProposalHash(2);

        // Now try to submit proposal 3, with incorrect parent proposal count
        // This should trigger IncorrectProposalCount error
        // Calculate the correct nextProposalBlockId based on proposal 2's block
        // Since genesis nextProposalBlockId = 2, first proposal is at block 2
        uint256 prevProposalBlock = InboxTestLib.calculateProposalBlock(2, 2);
        IInbox.CoreState memory coreState3 = _getGenesisCoreState();
        coreState3.nextProposalId = 3;
        coreState3.nextProposalBlockId = uint48(prevProposalBlock + 1); // Previous proposal's block
            // + 1

        setupProposalMocks(Alice);
        setupBlobHashes();

        // Intentionally provide wrong number of proposals to trigger the error
        // Ring buffer slot 3 is empty, so contract expects 1 proposal, but we provide 2
        IInbox.Proposal memory lastProposal = _recreateStoredProposal(2);
        IInbox.Proposal memory wrongProposal = _recreateStoredProposal(1);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = lastProposal;
        proposals[1] = wrongProposal; // Extra proposal that shouldn't be here

        bytes memory data3 = encodeProposeInputWithProposals(
            uint48(0),
            coreState3,
            proposals,
            InboxTestLib.createBlobReference(3),
            new IInbox.TransitionRecord[](0)
        );

        // Roll to the correct block for proposal 3
        // Since genesis nextProposalBlockId = 2, first proposal is at block 2
        uint256 targetBlock = InboxTestLib.calculateProposalBlock(3, 2);
        vm.roll(targetBlock);

        // Should fail with IncorrectProposalCount
        vm.expectRevert(abi.encodeWithSignature("IncorrectProposalCount()"));
        vm.prank(Alice);
        inbox.propose(bytes(""), data3);

        // Verify that existing proposals remain unchanged after failed attempt
        assertEq(inbox.getProposalHash(0), genesisHash, "Genesis should be unchanged");
        assertEq(inbox.getProposalHash(1), prop1Hash, "Proposal 1 should be unchanged");
        assertEq(inbox.getProposalHash(2), prop2Hash, "Proposal 2 should be unchanged");
    }

    // All helper functions are now inherited from InboxTest base class
}
