// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxRingBuffer
/// @notice Tests for ring buffer mechanics and capacity management
/// @dev Tests cover ring buffer operations, wraparound behavior, and capacity constraints
contract InboxRingBuffer is ShastaInboxTestBase {
    /// @notice Test basic ring buffer write and read operations
    /// @dev Verifies that proposal hashes can be written to and read from ring buffer slots
    /// Expected behavior: Proposal hashes are stored and retrieved correctly
    function test_ring_buffer_write_read() public {
        uint48 numProposals = 10;
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
            assertEq(storedHash, proposalHashes[i - 1]);
        }
    }

    /// @notice Test ring buffer modulo arithmetic
    /// @dev Verifies that proposal IDs map to correct buffer slots using modulo
    /// Expected behavior: proposalId % ringBufferSize determines the slot
    function test_ring_buffer_modulo() public {
        // Set small ring buffer size for testing
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 5;
        inbox.setConfig(config);

        // Test that proposals map to expected slots
        uint48[] memory proposalIds = new uint48[](3);
        proposalIds[0] = 1; // Should map to slot 1
        proposalIds[1] = 6; // Should map to slot 1 (6 % 5 = 1)
        proposalIds[2] = 11; // Should map to slot 1 (11 % 5 = 1)

        // Store first proposal
        bytes32 hash1 = keccak256("hash1");
        inbox.exposed_setProposalHash(proposalIds[0], hash1);
        assertEq(inbox.getProposalHash(proposalIds[0]), hash1);

        // Store second proposal (should overwrite slot)
        bytes32 hash2 = keccak256("hash2");
        inbox.exposed_setProposalHash(proposalIds[1], hash2);
        assertEq(inbox.getProposalHash(proposalIds[1]), hash2);

        // Verify first proposal's slot was overwritten
        // Note: In real usage, this wouldn't happen as unfinalized proposals are protected
        assertEq(inbox.getProposalHash(proposalIds[0]), hash2);

        // Store third proposal (should overwrite slot again)
        bytes32 hash3 = keccak256("hash3");
        inbox.exposed_setProposalHash(proposalIds[2], hash3);
        assertEq(inbox.getProposalHash(proposalIds[2]), hash3);
    }

    /// @notice Test ring buffer wraparound behavior
    /// @dev Verifies that the ring buffer wraps around correctly when reaching its size
    /// Expected behavior: Slots are reused after ringBufferSize proposals
    function test_ring_buffer_wraparound() public {
        // Set small ring buffer size
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 3;
        inbox.setConfig(config);

        // Fill the ring buffer completely
        bytes32[] memory firstRoundHashes = new bytes32[](3);
        for (uint48 i = 0; i < 3; i++) {
            firstRoundHashes[i] = keccak256(abi.encode("first", i));
            inbox.exposed_setProposalHash(i, firstRoundHashes[i]);
        }

        // Verify first round
        for (uint48 i = 0; i < 3; i++) {
            assertEq(inbox.getProposalHash(i), firstRoundHashes[i]);
        }

        // Start second round (wraparound)
        bytes32[] memory secondRoundHashes = new bytes32[](3);
        for (uint48 i = 0; i < 3; i++) {
            uint48 proposalId = i + 3; // IDs 3, 4, 5
            secondRoundHashes[i] = keccak256(abi.encode("second", i));
            inbox.exposed_setProposalHash(proposalId, secondRoundHashes[i]);
        }

        // Verify second round overwrote first round
        for (uint48 i = 0; i < 3; i++) {
            uint48 proposalId = i + 3;
            assertEq(inbox.getProposalHash(proposalId), secondRoundHashes[i]);
            // First round hashes should be overwritten
            assertEq(inbox.getProposalHash(i), secondRoundHashes[i]);
        }
    }

    /// @notice Test ring buffer capacity calculation
    /// @dev Verifies that capacity is correctly calculated as ringBufferSize - 1
    /// Expected behavior: getCapacity() returns ringBufferSize - 1
    function test_ring_buffer_capacity_calculation() public {
        uint256[] memory bufferSizes = new uint256[](4);
        bufferSizes[0] = 10;
        bufferSizes[1] = 100;
        bufferSizes[2] = 1000;
        bufferSizes[3] = 5;

        for (uint256 i = 0; i < bufferSizes.length; i++) {
            IInbox.Config memory config = defaultConfig;
            config.ringBufferSize = bufferSizes[i];
            inbox.setConfig(config);

            uint256 capacity = inbox.getCapacity();
            assertEq(capacity, bufferSizes[i] - 1);
        }
    }

    /// @notice Test behavior at full ring buffer capacity
    /// @dev Verifies that proposals can fill up to capacity without issues
    /// Expected behavior: Can store ringBufferSize - 1 unfinalized proposals
    function test_ring_buffer_full_behavior() public {
        // Set small buffer for testing
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 5; // Capacity = 4
        inbox.setConfig(config);

        // Fill to capacity (4 unfinalized proposals)
        for (uint48 i = 1; i <= 4; i++) {
            IInbox.CoreState memory coreState = createCoreState(i, 0);
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

            mockProposerAllowed(Alice);
            mockHasSufficientBond(Alice, true);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), data);
        }

        // Verify all 4 proposals are stored
        for (uint48 i = 1; i <= 4; i++) {
            bytes32 proposalHash = inbox.getProposalHash(i);
            assertTrue(proposalHash != bytes32(0));
        }

        // Try to add one more (should fail - exceeds capacity)
        IInbox.CoreState memory coreState5 = createCoreState(5, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState5)));

        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef5 = createValidBlobReference(5);
        IInbox.ClaimRecord[] memory claimRecords5 = new IInbox.ClaimRecord[](0);
        bytes memory data5 = encodeProposeProposeData(coreState5, blobRef5, claimRecords5);

        vm.expectRevert(InboxBase.ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data5);
    }

    /// @notice Test that the LAST finalized proposal cannot be overwritten
    /// @dev Verifies that the last finalized proposal is protected from overwriting
    ///      to maintain chain integrity. Only older finalized proposals can be overwritten.
    /// Expected behavior: Attempting to overwrite the last finalized proposal fails
    function test_ring_buffer_overwrite_finalized() public {
        // Set small buffer
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 3; // Slots 0, 1, 2
        inbox.setConfig(config);

        // Create proposal 1 and finalize it
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal1 = createValidProposal(proposalId);
        bytes32 proposalHash1 = keccak256(abi.encode(proposal1));
        inbox.exposed_setProposalHash(proposalId, proposalHash1);

        // Create and store claim record for finalization
        IInbox.CoreState memory coreState = createCoreState(2, 0);
        IInbox.Claim memory claim = createValidClaim(proposal1, coreState.lastFinalizedClaimHash);
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: claim,
            proposer: proposal1.proposer,
            livenessBondGwei: 0,
            provabilityBondGwei: 0,
            nextProposalId: 2,
            bondDecision: IInbox.BondDecision.NoOp
        });

        inbox.exposed_setClaimRecordHash(
            proposalId, coreState.lastFinalizedClaimHash, keccak256(abi.encode(claimRecord))
        );
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks for finalization
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);
        expectSyncedBlockSave(claim.endBlockNumber, claim.endBlockHash, claim.endStateRoot);

        // Submit proposal 2 with finalization of proposal 1
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = claimRecord;

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(2);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // After this, we have:
        // - Proposal 1: finalized (but it's the LAST finalized, so protected)
        // - Proposal 2: unfinalized
        // - nextProposalId = 3, lastFinalizedProposalId = 1

        // Now trying to create proposal 4 would exceed capacity because:
        // - We can't overwrite proposal 1 (last finalized)
        // - We can't overwrite proposal 2 (unfinalized)
        // - 4 - 1 = 3, but capacity is only 2
        coreState = createCoreState(4, 1); // nextId=4, lastFinalized=1
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        blobRef = createValidBlobReference(4);
        claimRecords = new IInbox.ClaimRecord[](0);
        data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        // This should revert because it would exceed capacity
        vm.expectRevert(abi.encodeWithSignature("ExceedsUnfinalizedProposalCapacity()"));
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test protection of unfinalized proposals from overwrite
    /// @dev Verifies that unfinalized proposals cannot be overwritten
    /// Expected behavior: Transaction reverts when trying to use slot of unfinalized proposal
    function test_ring_buffer_protect_unfinalized() public {
        // Set small buffer
        IInbox.Config memory config = defaultConfig;
        config.ringBufferSize = 3; // Capacity = 2
        inbox.setConfig(config);

        // Create 2 unfinalized proposals (fills capacity)
        for (uint48 i = 1; i <= 2; i++) {
            IInbox.CoreState memory coreState = createCoreState(i, 0);
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

            mockProposerAllowed(Alice);
            mockHasSufficientBond(Alice, true);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), data);
        }

        // Try to add proposal 3 (would need slot 0, but proposals 1 and 2 are unfinalized)
        IInbox.CoreState memory coreState3 = createCoreState(3, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState3)));

        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef3 = createValidBlobReference(3);
        IInbox.ClaimRecord[] memory claimRecords3 = new IInbox.ClaimRecord[](0);
        bytes memory data3 = encodeProposeProposeData(coreState3, blobRef3, claimRecords3);

        // Should fail - exceeds capacity
        vm.expectRevert(InboxBase.ExceedsUnfinalizedProposalCapacity.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data3);
    }
}
