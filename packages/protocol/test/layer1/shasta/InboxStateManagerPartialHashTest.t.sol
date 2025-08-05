// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { InboxStateManager } from "../../../contracts/layer1/shasta/impl/InboxStateManager.sol";

/// @title InboxStateManagerPartialHashTest
/// @notice Tests for partial hash collision behavior in InboxStateManager
/// @custom:security-contact security@taiko.xyz
contract InboxStateManagerPartialHashTest is Test {
    InboxStateManager stateManager;
    address constant INBOX = address(0x1234);
    bytes32 constant GENESIS_BLOCK_HASH = keccak256("GENESIS");
    uint256 constant RING_BUFFER_SIZE = 10;

    function setUp() public {
        vm.prank(INBOX);
        stateManager = new InboxStateManager(INBOX, GENESIS_BLOCK_HASH, RING_BUFFER_SIZE);
    }

    // -------------------------------------------------------------------------
    // Partial Hash Collision Tests
    // -------------------------------------------------------------------------

    function test_partialHashCollision_overwritesDefaultSlot() public {
        vm.startPrank(INBOX);

        uint48 proposalId = 1;

        // Create parent hashes with same high 208 bits but different low 48 bits
        bytes32 parentHash1 =
            bytes32(uint256(0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF));
        bytes32 parentHash2 =
            bytes32(uint256(0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890000000));

        bytes32 claimHash1 = keccak256("CLAIM_1");
        bytes32 claimHash2 = keccak256("CLAIM_2");

        stateManager.setProposalHash(proposalId, keccak256("PROPOSAL"));

        // Set first claim
        stateManager.setClaimRecordHash(proposalId, parentHash1, claimHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash1);

        // Set second claim with colliding partial hash
        stateManager.setClaimRecordHash(proposalId, parentHash2, claimHash2);

        // Both queries return the second claim due to collision
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash2), claimHash2);

        vm.stopPrank();
    }

    function test_avoidingPartialHashCollision() public {
        vm.startPrank(INBOX);

        uint48 proposalId = 1;

        // Create parent hashes with different high 208 bits
        bytes32 parentHash1 =
            bytes32(uint256(0x1111111111111111111111111111111111111111111111111111111111111111));
        bytes32 parentHash2 =
            bytes32(uint256(0x2222222222222222222222222222222222222222222222222222222222222222));
        bytes32 parentHash3 =
            bytes32(uint256(0x3333333333333333333333333333333333333333333333333333333333333333));

        bytes32 claimHash1 = keccak256("CLAIM_1");
        bytes32 claimHash2 = keccak256("CLAIM_2");
        bytes32 claimHash3 = keccak256("CLAIM_3");

        stateManager.setProposalHash(proposalId, keccak256("PROPOSAL"));

        // Set claims - first uses default slot, others use direct mapping
        stateManager.setClaimRecordHash(proposalId, parentHash1, claimHash1);
        stateManager.setClaimRecordHash(proposalId, parentHash2, claimHash2);
        stateManager.setClaimRecordHash(proposalId, parentHash3, claimHash3);

        // All claims are retrievable because they have different partial hashes
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash2), claimHash2);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentHash3), claimHash3);

        vm.stopPrank();
    }

    function testFuzz_partialHashCollisionProbability(
        bytes32 parentHash1,
        bytes32 parentHash2
    )
        public
    {
        vm.assume(parentHash1 != bytes32(0));
        vm.assume(parentHash2 != bytes32(0));
        vm.assume(parentHash1 != parentHash2);

        // Calculate if there's a partial hash collision
        bool hasCollision = (uint256(parentHash1) >> 48) == (uint256(parentHash2) >> 48);

        vm.startPrank(INBOX);

        uint48 proposalId = 1;
        bytes32 claimHash1 = keccak256(abi.encode("CLAIM_1", parentHash1));
        bytes32 claimHash2 = keccak256(abi.encode("CLAIM_2", parentHash2));

        stateManager.setProposalHash(proposalId, keccak256("PROPOSAL"));

        // Set both claims
        stateManager.setClaimRecordHash(proposalId, parentHash1, claimHash1);
        stateManager.setClaimRecordHash(proposalId, parentHash2, claimHash2);

        if (hasCollision) {
            // With collision, both queries return the second claim
            assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash2);
            assertEq(stateManager.getClaimRecordHash(proposalId, parentHash2), claimHash2);
        } else {
            // Without collision, each query returns its own claim
            assertEq(stateManager.getClaimRecordHash(proposalId, parentHash1), claimHash1);
            assertEq(stateManager.getClaimRecordHash(proposalId, parentHash2), claimHash2);
        }

        vm.stopPrank();
    }

    function test_documentedCollisionBehavior() public {
        vm.startPrank(INBOX);

        uint48 proposalId = 1;

        // Example: Two different transaction hashes that happen to have the same high 208 bits
        // In practice, this is extremely unlikely (2^-208 probability for random hashes)
        bytes32 txHash1 =
            bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
        bytes32 txHash2 =
            bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000));

        stateManager.setProposalHash(proposalId, keccak256("PROPOSAL"));

        // If these were used as parent claim hashes, the second would overwrite the first
        stateManager.setClaimRecordHash(proposalId, txHash1, keccak256("CLAIM_FOR_TX1"));
        stateManager.setClaimRecordHash(proposalId, txHash2, keccak256("CLAIM_FOR_TX2"));

        // Both return the second claim due to partial hash collision
        // This is acceptable given the extremely low probability of collision
        assertEq(stateManager.getClaimRecordHash(proposalId, txHash1), keccak256("CLAIM_FOR_TX2"));
        assertEq(stateManager.getClaimRecordHash(proposalId, txHash2), keccak256("CLAIM_FOR_TX2"));

        vm.stopPrank();
    }
}
