// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxSlotOptimization
/// @notice Tests for storage slot optimization mechanism
/// @dev Tests cover slot reuse marker encoding/decoding, default slot usage, and collision handling
contract InboxSlotOptimization is ShastaInboxTestBase {
    /// @notice Test slot reuse marker encoding and decoding
    /// @dev Verifies that proposal ID and partial parent claim hash are correctly encoded/decoded
    /// Expected behavior: Encoding preserves proposal ID and high 208 bits of parent hash
    function test_slot_reuse_marker_encoding() public {
        // Test various proposal IDs and parent hashes
        uint48[] memory proposalIds = new uint48[](3);
        proposalIds[0] = 1;
        proposalIds[1] = 65_535; // Near max uint48
        proposalIds[2] = 281_474_976_710_655; // Max uint48

        bytes32[] memory parentHashes = new bytes32[](3);
        parentHashes[0] = bytes32(uint256(1));
        parentHashes[1] = keccak256("test_parent");
        parentHashes[2] = bytes32(type(uint256).max);

        for (uint256 i = 0; i < proposalIds.length; i++) {
            // Store claim record using internal function
            bytes32 claimRecordHash = keccak256(abi.encode("claim", i));
            inbox.exposed_setClaimRecordHash(proposalIds[i], parentHashes[i], claimRecordHash);

            // Retrieve and verify
            bytes32 retrieved = inbox.exposed_getClaimRecordHash(proposalIds[i], parentHashes[i]);

            // Should match what we stored
            assertEq(retrieved, claimRecordHash);
        }
    }

    /// @notice Test default slot usage for first claim
    /// @dev Verifies that the first claim for a proposal uses the default slot
    /// Expected behavior: First claim is stored in _DEFAULT_SLOT_HASH slot
    function test_default_slot_first_claim() public {
        uint48 proposalId = 10;
        bytes32 parentClaimHash = keccak256("parent");
        bytes32 claimRecordHash = keccak256("claim_record");

        // Store first claim - should use default slot
        inbox.exposed_setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash);

        // Retrieve using the same parent hash
        bytes32 retrieved = inbox.exposed_getClaimRecordHash(proposalId, parentClaimHash);
        assertEq(retrieved, claimRecordHash);

        // Verify it was stored in default slot by checking with different parent
        // that has same high 208 bits
        bytes32 similarParent = bytes32(uint256(parentClaimHash) & ~uint256(0xFFFFFFFFFFFF));
        similarParent = bytes32(uint256(similarParent) | uint256(0xABCDEF)); // Different low bits

        // Should still retrieve the same record if high bits match
        bytes32 retrievedSimilar = inbox.exposed_getClaimRecordHash(proposalId, similarParent);

        // Check if partial match works (high 208 bits)
        if ((uint256(parentClaimHash) >> 48) == (uint256(similarParent) >> 48)) {
            assertEq(retrievedSimilar, claimRecordHash);
        }
    }

    /// @notice Test collision handling when parent hashes differ
    /// @dev Verifies that collisions use direct mapping instead of default slot
    /// Expected behavior: Second claim with different parent uses direct mapping
    function test_default_slot_collision() public {
        uint48 proposalId = 20;

        // First claim uses default slot
        bytes32 parentHash1 = bytes32(uint256(0x1111111111111111));
        bytes32 claimRecord1 = keccak256("claim1");
        inbox.exposed_setClaimRecordHash(proposalId, parentHash1, claimRecord1);

        // Second claim with different parent hash (collision)
        bytes32 parentHash2 = bytes32(uint256(0x2222222222222222));
        bytes32 claimRecord2 = keccak256("claim2");
        inbox.exposed_setClaimRecordHash(proposalId, parentHash2, claimRecord2);

        // Both should be retrievable
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash1), claimRecord1);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash2), claimRecord2);

        // Third claim with yet another parent hash
        bytes32 parentHash3 = bytes32(uint256(0x3333333333333333));
        bytes32 claimRecord3 = keccak256("claim3");
        inbox.exposed_setClaimRecordHash(proposalId, parentHash3, claimRecord3);

        // All three should be retrievable
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash1), claimRecord1);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash2), claimRecord2);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash3), claimRecord3);
    }

    /// @notice Test default slot reuse for different proposals
    /// @dev Verifies that default slot can be reused when proposal ID changes
    /// Expected behavior: Different proposal IDs can reuse the default slot
    function test_default_slot_different_proposal() public {
        // Store claim for proposal 1
        uint48 proposalId1 = 1;
        bytes32 parentHash1 = keccak256("parent1");
        bytes32 claimRecord1 = keccak256("claim1");
        inbox.exposed_setClaimRecordHash(proposalId1, parentHash1, claimRecord1);

        // Store claim for proposal 2 (different proposal)
        uint48 proposalId2 = 2;
        bytes32 parentHash2 = keccak256("parent2");
        bytes32 claimRecord2 = keccak256("claim2");
        inbox.exposed_setClaimRecordHash(proposalId2, parentHash2, claimRecord2);

        // Both should be retrievable
        assertEq(inbox.exposed_getClaimRecordHash(proposalId1, parentHash1), claimRecord1);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId2, parentHash2), claimRecord2);

        // Now overwrite proposal 1's slot with proposal 3 (ring buffer wraparound scenario)
        uint48 proposalId3 = 101; // Assuming ring buffer size 100, this maps to same slot as 1
        bytes32 parentHash3 = keccak256("parent3");
        bytes32 claimRecord3 = keccak256("claim3");

        // This simulates ring buffer reuse
        inbox.exposed_setClaimRecordHash(proposalId3, parentHash3, claimRecord3);

        // Proposal 3 should be retrievable
        assertEq(inbox.exposed_getClaimRecordHash(proposalId3, parentHash3), claimRecord3);

        // Proposal 1's claim might be overwritten if they share the same buffer slot
        // This is expected behavior when ring buffer wraps around
    }

    /// @notice Test partial parent claim hash matching
    /// @dev Verifies that only high 208 bits are used for matching in default slot
    /// Expected behavior: Hashes with same high 208 bits match
    function test_partial_parent_hash_matching() public {
        uint48 proposalId = 50;

        // Create parent hash with specific pattern
        bytes32 baseParentHash =
            bytes32(0xAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDD);

        // Store claim with base parent hash
        bytes32 claimRecord = keccak256("claim");
        inbox.exposed_setClaimRecordHash(proposalId, baseParentHash, claimRecord);

        // Create variations with same high 208 bits but different low 48 bits
        bytes32 variation1 =
            bytes32((uint256(baseParentHash) & ~uint256(0xFFFFFFFFFFFF)) | uint256(0x111111));
        bytes32 variation2 =
            bytes32((uint256(baseParentHash) & ~uint256(0xFFFFFFFFFFFF)) | uint256(0x222222));
        bytes32 variation3 =
            bytes32((uint256(baseParentHash) & ~uint256(0xFFFFFFFFFFFF)) | uint256(0x333333));

        // All variations should retrieve the same claim record (partial match)
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, variation1), claimRecord);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, variation2), claimRecord);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, variation3), claimRecord);

        // Create a hash with different high bits
        bytes32 differentHash =
            bytes32(0xFFFFFFFFFFFFFFFFBBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDD);

        // Should not retrieve the claim record (no match)
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, differentHash), bytes32(0));
    }

    /// @notice Test storage gas optimization with multiple claims
    /// @dev Verifies that the optimization reduces SSTORE operations
    /// Expected behavior: First claim uses 1 SSTORE, subsequent same-parent claims reuse slot
    function test_storage_gas_optimization() public {
        uint48 proposalId = 100;
        bytes32 parentHash = keccak256("common_parent");

        // Store first claim (uses default slot - 1 SSTORE for metadata + hash)
        uint256 gasBefore1 = gasleft();
        inbox.exposed_setClaimRecordHash(proposalId, parentHash, keccak256("claim1"));
        uint256 gasAfter1 = gasleft();
        uint256 gasUsed1 = gasBefore1 - gasAfter1;

        // Update same slot (should be cheaper - only updates hash)
        uint256 gasBefore2 = gasleft();
        inbox.exposed_setClaimRecordHash(proposalId, parentHash, keccak256("claim2"));
        uint256 gasAfter2 = gasleft();
        uint256 gasUsed2 = gasBefore2 - gasAfter2;

        // Second update should use less gas (warm storage slot)
        assertTrue(gasUsed2 < gasUsed1);

        // Store claim with different parent (uses direct mapping - additional SSTORE)
        bytes32 differentParent = keccak256("different_parent");
        uint256 gasBefore3 = gasleft();
        inbox.exposed_setClaimRecordHash(proposalId, differentParent, keccak256("claim3"));
        uint256 gasAfter3 = gasleft();
        uint256 gasUsed3 = gasBefore3 - gasAfter3;

        // Different parent should use more gas than updating same slot
        assertTrue(gasUsed3 > gasUsed2);
    }

    /// @notice Test handling of hash collisions in partial matching
    /// @dev Verifies correct behavior when different hashes have same high 208 bits
    /// Expected behavior: System correctly differentiates using full hash when needed
    function test_storage_collision_handling() public {
        uint48 proposalId = 200;

        // Create two parent hashes with same high 208 bits but different low 48 bits
        uint256 highBits = 0xAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCC000000000000;
        bytes32 parentHash1 = bytes32(highBits | uint256(0x111111));
        bytes32 parentHash2 = bytes32(highBits | uint256(0x222222));

        // Store first claim in default slot
        bytes32 claimRecord1 = keccak256("claim1");
        inbox.exposed_setClaimRecordHash(proposalId, parentHash1, claimRecord1);

        // Try to store second claim with similar parent (same high bits)
        // This should detect the collision and use direct mapping
        bytes32 claimRecord2 = keccak256("claim2");
        inbox.exposed_setClaimRecordHash(proposalId, parentHash2, claimRecord2);

        // Verify first claim is still in default slot
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash1), claimRecord1);

        // Verify second claim is in direct mapping
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash2), claimRecord2);

        // Both should be independently retrievable
        assertTrue(
            inbox.exposed_getClaimRecordHash(proposalId, parentHash1)
                != inbox.exposed_getClaimRecordHash(proposalId, parentHash2)
        );
    }

    /// @notice Test edge case with zero values
    /// @dev Verifies that zero proposal ID and zero parent hash are handled correctly
    /// Expected behavior: System handles zero values without issues
    function test_slot_optimization_zero_values() public {
        // Test with proposal ID 0 (edge case)
        uint48 proposalId = 0;
        bytes32 parentHash = bytes32(0);
        bytes32 claimRecord = keccak256("zero_claim");

        // Should handle zero values
        inbox.exposed_setClaimRecordHash(proposalId, parentHash, claimRecord);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash), claimRecord);

        // Test with non-zero proposal ID but zero parent hash
        proposalId = 1;
        claimRecord = keccak256("zero_parent_claim");
        inbox.exposed_setClaimRecordHash(proposalId, parentHash, claimRecord);
        assertEq(inbox.exposed_getClaimRecordHash(proposalId, parentHash), claimRecord);
    }
}
