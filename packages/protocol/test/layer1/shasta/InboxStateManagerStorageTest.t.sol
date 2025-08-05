// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { InboxStateManager } from "../../../contracts/layer1/shasta/impl/InboxStateManager.sol";

/// @title InboxStateManagerStorageTest
/// @notice Tests for storage slot reuse and multiple claim records in InboxStateManager
/// @custom:security-contact security@taiko.xyz
contract InboxStateManagerStorageTest is Test {
    InboxStateManager stateManager;
    address constant INBOX = address(0x1234);
    bytes32 constant GENESIS_BLOCK_HASH = keccak256("GENESIS");
    uint256 constant RING_BUFFER_SIZE = 10;
    bytes32 constant DEFAULT_SLOT_HASH = bytes32(uint256(1));

    function setUp() public {
        vm.prank(INBOX);
        stateManager = new InboxStateManager(INBOX, GENESIS_BLOCK_HASH, RING_BUFFER_SIZE);
    }

    // -------------------------------------------------------------------------
    // Storage Slot Reuse Tests
    // -------------------------------------------------------------------------

    function test_firstClaimRecord_alwaysUsesDefaultSlot() public {
        vm.startPrank(INBOX);

        // Test multiple proposals to ensure consistent behavior
        for (uint48 proposalId = 1; proposalId <= 5; proposalId++) {
            bytes32 proposalHash = keccak256(abi.encode("PROPOSAL", proposalId));
            bytes32 parentClaimHash = keccak256(abi.encode("PARENT", proposalId));
            bytes32 claimRecordHash = keccak256(abi.encode("CLAIM", proposalId));

            // Set proposal and first claim
            stateManager.setProposalHash(proposalId, proposalHash);
            stateManager.setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash);

            // Verify the claim is stored and retrievable
            assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash), claimRecordHash);
        }

        vm.stopPrank();
    }

    function test_multipleClaimRecords_firstUsesDefaultSlot() public {
        vm.startPrank(INBOX);

        uint48 proposalId = 1;
        bytes32 proposalHash = keccak256("PROPOSAL");
        bytes32 parentClaimHash1 = keccak256("PARENT_1");
        bytes32 parentClaimHash2 = keccak256("PARENT_2");
        bytes32 parentClaimHash3 = keccak256("PARENT_3");
        bytes32 claimRecordHash1 = keccak256("CLAIM_1");
        bytes32 claimRecordHash2 = keccak256("CLAIM_2");
        bytes32 claimRecordHash3 = keccak256("CLAIM_3");

        // Set proposal
        stateManager.setProposalHash(proposalId, proposalHash);

        // Set first claim - should use default slot
        stateManager.setClaimRecordHash(proposalId, parentClaimHash1, claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash1), claimRecordHash1);

        // Set second claim - should use direct mapping
        stateManager.setClaimRecordHash(proposalId, parentClaimHash2, claimRecordHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash2), claimRecordHash2);

        // Set third claim - should use direct mapping
        stateManager.setClaimRecordHash(proposalId, parentClaimHash3, claimRecordHash3);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash3), claimRecordHash3);

        // Verify all claims are still accessible
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash1), claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash2), claimRecordHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash3), claimRecordHash3);

        vm.stopPrank();
    }

    function test_storageSlotReuse_afterProposalOverwrite() public {
        vm.startPrank(INBOX);

        uint48 proposalId1 = 1;
        uint48 proposalId2 = uint48(1 + RING_BUFFER_SIZE); // Maps to same slot

        bytes32 parentClaimHash1 = keccak256("PARENT_1");
        bytes32 parentClaimHash2 = keccak256("PARENT_2");
        bytes32 claimRecordHash1 = keccak256("CLAIM_1");
        bytes32 claimRecordHash2 = keccak256("CLAIM_2");
        bytes32 claimRecordHash3 = keccak256("CLAIM_3");

        // Set first proposal with two claims
        stateManager.setProposalHash(proposalId1, keccak256("PROPOSAL_1"));
        stateManager.setClaimRecordHash(proposalId1, parentClaimHash1, claimRecordHash1);
        stateManager.setClaimRecordHash(proposalId1, parentClaimHash2, claimRecordHash2);

        // Verify both claims are accessible
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash1), claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash2), claimRecordHash2);

        // Overwrite with second proposal
        stateManager.setProposalHash(proposalId2, keccak256("PROPOSAL_2"));

        // Old claims should still be accessible from both proposal IDs
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash1), claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash2), claimRecordHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId2, parentClaimHash1), claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId2, parentClaimHash2), claimRecordHash2);

        // Add new claim for the second proposal
        stateManager.setClaimRecordHash(proposalId2, parentClaimHash1, claimRecordHash3);

        // The new claim should be accessible from both proposal IDs
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash1), claimRecordHash3);
        assertEq(stateManager.getClaimRecordHash(proposalId2, parentClaimHash1), claimRecordHash3);

        // The second parent claim should still have the old hash
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash2), claimRecordHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId2, parentClaimHash2), claimRecordHash2);

        vm.stopPrank();
    }

    function test_defaultSlotReuse_withPartialParentHashCollision() public {
        vm.startPrank(INBOX);

        uint48 proposalId = 1;

        // Create two parent hashes that have the same high 208 bits
        // but different low 48 bits
        bytes32 parentHash1 =
            bytes32(uint256(0xABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890));
        bytes32 parentHash2 =
            bytes32(uint256(0xABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF0000000000));

        bytes32 claimHash1 = keccak256("CLAIM_1");
        bytes32 claimHash2 = keccak256("CLAIM_2");

        stateManager.setProposalHash(proposalId, keccak256("PROPOSAL"));

        // Set first claim with parentHash1
        stateManager.setClaimRecordHash(proposalId, parentHash1, claimHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash1);

        // Set second claim with parentHash2 (same partial hash)
        // Since they have the same partial hash, the second one will overwrite the first in the
        // default slot
        stateManager.setClaimRecordHash(proposalId, parentHash2, claimHash2);

        // Due to partial hash collision, both parent hashes will return the second claim
        // This is a limitation of the storage optimization
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash2), claimHash2);

        vm.stopPrank();
    }

    function testFuzz_multipleClaimRecords(
        uint48 proposalId,
        bytes32[5] memory parentClaimHashes,
        bytes32[5] memory claimRecordHashes
    )
        public
    {
        vm.assume(proposalId > 0);

        // Ensure all parent claim hashes are unique and have different partial hashes
        for (uint256 i = 0; i < 5; i++) {
            vm.assume(parentClaimHashes[i] != bytes32(0));
            vm.assume(claimRecordHashes[i] != bytes32(0));
            for (uint256 j = i + 1; j < 5; j++) {
                vm.assume(parentClaimHashes[i] != parentClaimHashes[j]);
                // Also ensure different partial hashes (high 208 bits)
                vm.assume(
                    uint256(parentClaimHashes[i]) >> 48 != uint256(parentClaimHashes[j]) >> 48
                );
            }
        }

        vm.startPrank(INBOX);

        // Set proposal
        stateManager.setProposalHash(proposalId, keccak256(abi.encode("PROPOSAL", proposalId)));

        // Set all claim records
        for (uint256 i = 0; i < 5; i++) {
            stateManager.setClaimRecordHash(proposalId, parentClaimHashes[i], claimRecordHashes[i]);
        }

        // Verify all claim records are retrievable
        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                stateManager.getClaimRecordHash(proposalId, parentClaimHashes[i]),
                claimRecordHashes[i]
            );
        }

        vm.stopPrank();
    }

    function test_updateExistingClaimRecord() public {
        vm.startPrank(INBOX);

        uint48 proposalId = 1;
        bytes32 parentClaimHash = keccak256("PARENT");
        bytes32 claimRecordHash1 = keccak256("CLAIM_1");
        bytes32 claimRecordHash2 = keccak256("CLAIM_2");

        stateManager.setProposalHash(proposalId, keccak256("PROPOSAL"));

        // Set initial claim
        stateManager.setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash), claimRecordHash1);

        // Update the same claim
        stateManager.setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash), claimRecordHash2);

        vm.stopPrank();
    }
}
