// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";
import { InboxStateManager } from "src/layer1/shasta/impl/InboxStateManager.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title InboxStateManagerTest
/// @notice Unit tests for InboxStateManager ring buffer implementation
/// @custom:security-contact security@taiko.xyz
contract InboxStateManagerTest is CommonTest {
    InboxStateManager private stateManager;
    address private inbox;
    bytes32 private constant GENESIS_BLOCK_HASH = keccak256("GENESIS");
    uint256 private constant RING_BUFFER_SIZE = 1000;

    function setUp() public override {
        super.setUp();

        // Deploy a mock inbox address
        inbox = Alice;

        // Deploy the state manager
        stateManager = new InboxStateManager(inbox, GENESIS_BLOCK_HASH, RING_BUFFER_SIZE);
    }

    // -------------------------------------------------------------------------
    // Access Control Tests
    // -------------------------------------------------------------------------

    function test_setCoreStateHash_onlyInbox() public {
        bytes32 newCoreStateHash = keccak256("NEW_CORE_STATE");

        // Should fail when called by non-inbox address
        vm.prank(Bob);
        vm.expectRevert(InboxStateManager.Unauthorized.selector);
        stateManager.setCoreStateHash(newCoreStateHash);

        // Should succeed when called by inbox
        vm.prank(inbox);
        stateManager.setCoreStateHash(newCoreStateHash);

        assertEq(stateManager.getCoreStateHash(), newCoreStateHash);
    }

    function test_setProposalHash_onlyInbox() public {
        uint48 proposalId = 1;
        bytes32 proposalHash = keccak256("PROPOSAL_1");

        // Should fail when called by non-inbox address
        vm.prank(Bob);
        vm.expectRevert(InboxStateManager.Unauthorized.selector);
        stateManager.setProposalHash(proposalId, proposalHash);

        // Should succeed when called by inbox
        vm.prank(inbox);
        stateManager.setProposalHash(proposalId, proposalHash);

        assertEq(stateManager.getProposalHash(proposalId), proposalHash);
    }

    function test_setClaimRecordHash_onlyInbox() public {
        uint48 proposalId = 1;
        bytes32 parentClaimHash = keccak256("PARENT_CLAIM");
        bytes32 claimRecordHash = keccak256("CLAIM_RECORD");

        // Should fail when called by non-inbox address
        vm.prank(Bob);
        vm.expectRevert(InboxStateManager.Unauthorized.selector);
        stateManager.setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash);

        // Should succeed when called by inbox
        vm.prank(inbox);
        stateManager.setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash);

        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash), claimRecordHash);
    }

    // -------------------------------------------------------------------------
    // Ring Buffer Functionality Tests
    // -------------------------------------------------------------------------

    function test_ringBuffer_basicStorage() public {
        vm.startPrank(inbox);

        // Store proposals
        for (uint48 i = 1; i <= 5; i++) {
            bytes32 proposalHash = keccak256(abi.encode("PROPOSAL", i));
            stateManager.setProposalHash(i, proposalHash);
            assertEq(stateManager.getProposalHash(i), proposalHash);
        }

        // Verify all proposals are stored correctly
        for (uint48 i = 1; i <= 5; i++) {
            bytes32 expectedHash = keccak256(abi.encode("PROPOSAL", i));
            assertEq(stateManager.getProposalHash(i), expectedHash);
        }

        vm.stopPrank();
    }

    function test_ringBuffer_overwriting() public {
        vm.startPrank(inbox);

        // Fill the ring buffer completely
        for (uint48 i = 0; i < RING_BUFFER_SIZE; i++) {
            bytes32 proposalHash = keccak256(abi.encode("PROPOSAL", i));
            stateManager.setProposalHash(i, proposalHash);
        }

        // Overwrite the first slot (proposal 0) with proposal RING_BUFFER_SIZE
        uint48 overwritingId = uint48(RING_BUFFER_SIZE);
        bytes32 overwritingHash = keccak256(abi.encode("OVERWRITING_PROPOSAL"));
        stateManager.setProposalHash(overwritingId, overwritingHash);

        // Verify the first slot has been overwritten
        assertEq(stateManager.getProposalHash(0), overwritingHash);
        assertEq(stateManager.getProposalHash(overwritingId), overwritingHash);

        // Verify other slots remain unchanged
        for (uint48 i = 1; i < RING_BUFFER_SIZE; i++) {
            bytes32 expectedHash = keccak256(abi.encode("PROPOSAL", i));
            assertEq(stateManager.getProposalHash(i), expectedHash);
        }

        vm.stopPrank();
    }

    function test_ringBuffer_moduloArithmetic() public {
        vm.startPrank(inbox);

        // Test that proposals with IDs that differ by RING_BUFFER_SIZE map to the same slot
        uint48 proposalId1 = 5;
        uint48 proposalId2 = uint48(5 + RING_BUFFER_SIZE);
        uint48 proposalId3 = uint48(5 + 2 * RING_BUFFER_SIZE);

        bytes32 hash1 = keccak256("HASH_1");
        bytes32 hash2 = keccak256("HASH_2");
        bytes32 hash3 = keccak256("HASH_3");

        // Set first proposal
        stateManager.setProposalHash(proposalId1, hash1);
        assertEq(stateManager.getProposalHash(proposalId1), hash1);

        // Set second proposal (overwrites first)
        stateManager.setProposalHash(proposalId2, hash2);
        assertEq(stateManager.getProposalHash(proposalId1), hash2); // Old ID returns new hash
        assertEq(stateManager.getProposalHash(proposalId2), hash2);

        // Set third proposal (overwrites second)
        stateManager.setProposalHash(proposalId3, hash3);
        assertEq(stateManager.getProposalHash(proposalId1), hash3); // All IDs return newest hash
        assertEq(stateManager.getProposalHash(proposalId2), hash3);
        assertEq(stateManager.getProposalHash(proposalId3), hash3);

        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Claim Record Tests
    // -------------------------------------------------------------------------

    function test_claimRecords_basicStorage() public {
        vm.startPrank(inbox);

        uint48 proposalId = 1;
        bytes32 proposalHash = keccak256("PROPOSAL");
        bytes32 parentClaimHash1 = keccak256("PARENT_1");
        bytes32 parentClaimHash2 = keccak256("PARENT_2");
        bytes32 claimRecordHash1 = keccak256("CLAIM_1");
        bytes32 claimRecordHash2 = keccak256("CLAIM_2");

        // Set proposal
        stateManager.setProposalHash(proposalId, proposalHash);

        // Set multiple claim records for the same proposal
        stateManager.setClaimRecordHash(proposalId, parentClaimHash1, claimRecordHash1);
        stateManager.setClaimRecordHash(proposalId, parentClaimHash2, claimRecordHash2);

        // Verify both claim records are stored
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash1), claimRecordHash1);
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash2), claimRecordHash2);

        vm.stopPrank();
    }

    function test_claimRecords_afterProposalOverwrite() public {
        vm.startPrank(inbox);

        uint48 proposalId1 = 1;
        uint48 proposalId2 = uint48(1 + RING_BUFFER_SIZE); // Maps to same slot

        bytes32 proposalHash1 = keccak256("PROPOSAL_1");
        bytes32 proposalHash2 = keccak256("PROPOSAL_2");
        bytes32 parentClaimHash = keccak256("PARENT");
        bytes32 claimRecordHash1 = keccak256("CLAIM_1");
        bytes32 claimRecordHash2 = keccak256("CLAIM_2");

        // Set first proposal and claim
        stateManager.setProposalHash(proposalId1, proposalHash1);
        stateManager.setClaimRecordHash(proposalId1, parentClaimHash, claimRecordHash1);

        // Overwrite with second proposal
        stateManager.setProposalHash(proposalId2, proposalHash2);

        // After overwriting the proposal, claims from the first proposal are still accessible
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash), claimRecordHash1);
        // The second proposal has no claims yet
        assertEq(stateManager.getClaimRecordHash(proposalId2, parentClaimHash), bytes32(0));

        // Set new claim for the second proposal
        stateManager.setClaimRecordHash(proposalId2, parentClaimHash, claimRecordHash2);

        // Now the first proposal's claim is no longer accessible (overwritten)
        assertEq(stateManager.getClaimRecordHash(proposalId1, parentClaimHash), bytes32(0));
        // The second proposal returns its claim
        assertEq(stateManager.getClaimRecordHash(proposalId2, parentClaimHash), claimRecordHash2);

        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Genesis State Tests
    // -------------------------------------------------------------------------

    function test_genesisState() public view {
        // Verify the initial core state hash is set correctly
        IInbox.Claim memory claim;
        claim.endBlockHash = GENESIS_BLOCK_HASH;

        IInbox.CoreState memory expectedCoreState;
        expectedCoreState.nextProposalId = 1;
        expectedCoreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));

        bytes32 expectedCoreStateHash = keccak256(abi.encode(expectedCoreState));
        assertEq(stateManager.getCoreStateHash(), expectedCoreStateHash);
    }

    // -------------------------------------------------------------------------
    // Edge Cases and Fuzz Tests
    // -------------------------------------------------------------------------

    function test_emptySlotReturnsZero() public view {
        // Query a proposal that was never set
        uint48 nonExistentId = 999;
        assertEq(stateManager.getProposalHash(nonExistentId), bytes32(0));

        // Query a claim record that was never set
        assertEq(stateManager.getClaimRecordHash(nonExistentId, keccak256("PARENT")), bytes32(0));
    }

    function testFuzz_ringBufferMapping(uint48 proposalId) public {
        vm.assume(proposalId > 0); // Avoid proposal ID 0

        vm.prank(inbox);
        bytes32 proposalHash = keccak256(abi.encode("PROPOSAL", proposalId));
        stateManager.setProposalHash(proposalId, proposalHash);

        // Verify the proposal is stored at the correct slot
        uint256 expectedSlot = proposalId % RING_BUFFER_SIZE;

        // Any proposal ID that maps to the same slot should return the same hash
        for (uint256 i = 0; i < 3; i++) {
            uint48 equivalentId = uint48(expectedSlot + i * RING_BUFFER_SIZE);
            assertEq(stateManager.getProposalHash(equivalentId), proposalHash);
        }
    }

    function testFuzz_claimRecordStorage(
        uint48 proposalId,
        bytes32 parentClaimHash,
        bytes32 claimRecordHash
    )
        public
    {
        vm.assume(proposalId > 0);
        vm.assume(parentClaimHash != bytes32(0));
        vm.assume(claimRecordHash != bytes32(0));

        vm.startPrank(inbox);

        // Set proposal and claim
        stateManager.setProposalHash(proposalId, keccak256(abi.encode("PROPOSAL", proposalId)));
        stateManager.setClaimRecordHash(proposalId, parentClaimHash, claimRecordHash);

        // Verify storage
        assertEq(stateManager.getClaimRecordHash(proposalId, parentClaimHash), claimRecordHash);

        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Invalid Ring Buffer Size Test
    // -------------------------------------------------------------------------

    function test_invalidRingBufferSize() public {
        vm.expectRevert(InboxStateManager.RingBufferSizeZero.selector);
        new InboxStateManager(inbox, GENESIS_BLOCK_HASH, 0);
    }
}
