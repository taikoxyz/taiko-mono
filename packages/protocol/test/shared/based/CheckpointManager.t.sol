// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "../CommonTest.sol";
import {CheckpointManager } from "src/shared/based/impl/SyncedBlockManager.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @custom:security-contact security@taiko.xyz
contract CheckpointManagerTest is CommonTest {
   CheckpointManager public checkpointManager;
    address public authorized = Alice;

    function setUp() public override {
        super.setUp();
        checkpointManager = newCheckpointManager(authorized, 5);
    }

    function test_constructor() public view {
        assertEq(checkpointManager.authorized(), authorized);
        assertEq(checkpointManager.maxStackSize(), 5);
    }

    function test_constructor_revert_zeroAddress() public {
        vm.expectRevert(SyncedBlockManager.InvalidAddress.selector);
        newCheckpointManager(address(0), 5);
    }

    function test_constructor_revert_zeroMaxStackSize() public {
        vm.expectRevert(SyncedBlockManager.InvalidMaxStackSize.selector);
        newCheckpointManager(authorized, 0);
    }

    function test_saveCheckpoint() public {
        vm.prank(authorized);

        vm.expectEmit(true, true, true, true);
        emit ICheckpointManager.SyncedBlockSaved(100, bytes32(uint256(1)), bytes32(uint256(2)));

        checkpointManager.saveCheckpoint(100, bytes32(uint256(1)), bytes32(uint256(2)));

        assertEq(checkpointManager.getLatestSyncedBlockNumber(), 100);
        assertEq(checkpointManager.getNumberOfSyncedBlocks(), 1);

        (uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot) =
            checkpointManager.getSyncedBlock(0);
        assertEq(blockNumber, 100);
        assertEq(blockHash, bytes32(uint256(1)));
        assertEq(stateRoot, bytes32(uint256(2)));
    }

    function test_saveCheckpoint_multipleBlocks() public {
        vm.startPrank(authorized);

        for (uint48 i = 1; i <= 3; i++) {
            checkpointManager.saveCheckpoint(i * 100, bytes32(uint256(i)), bytes32(uint256(i * 10)));
        }

        vm.stopPrank();

        assertEq(checkpointManager.getLatestSyncedBlockNumber(), 300);
        assertEq(checkpointManager.getNumberOfSyncedBlocks(), 3);

        // Check offset 0 (latest)
        (uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot) =
            checkpointManager.getSyncedBlock(0);
        assertEq(blockNumber, 300);
        assertEq(blockHash, bytes32(uint256(3)));
        assertEq(stateRoot, bytes32(uint256(30)));

        // Check offset 1 (second latest)
        (blockNumber, blockHash, stateRoot) = checkpointManager.getSyncedBlock(1);
        assertEq(blockNumber, 200);
        assertEq(blockHash, bytes32(uint256(2)));
        assertEq(stateRoot, bytes32(uint256(20)));

        // Check offset 2 (third latest)
        (blockNumber, blockHash, stateRoot) = checkpointManager.getSyncedBlock(2);
        assertEq(blockNumber, 100);
        assertEq(blockHash, bytes32(uint256(1)));
        assertEq(stateRoot, bytes32(uint256(10)));
    }

    function test_saveCheckpoint_revert_unauthorized() public {
        vm.prank(Bob);

        vm.expectRevert();
        checkpointManager.saveCheckpoint(100, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function test_saveCheckpoint_revert_zeroStateRoot() public {
        vm.prank(authorized);

        vm.expectRevert(SyncedBlockManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(100, bytes32(uint256(1)), bytes32(0));
    }

    function test_saveCheckpoint_revert_zeroBlockHash() public {
        vm.prank(authorized);

        vm.expectRevert(SyncedBlockManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(100, bytes32(0), bytes32(uint256(2)));
    }

    function test_saveCheckpoint_revert_zeroBlockNumber() public {
        vm.prank(authorized);

        vm.expectRevert(SyncedBlockManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(0, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function test_saveCheckpoint_revert_decreasingBlockNumber() public {
        vm.startPrank(authorized);

        checkpointManager.saveCheckpoint(100, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SyncedBlockManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(99, bytes32(uint256(3)), bytes32(uint256(4)));

        vm.stopPrank();
    }

    function test_saveCheckpoint_revert_sameBlockNumber() public {
        vm.startPrank(authorized);

        checkpointManager.saveCheckpoint(100, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SyncedBlockManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(100, bytes32(uint256(3)), bytes32(uint256(4)));

        vm.stopPrank();
    }

    function test_getSyncedBlock_revert_noSyncedBlocks() public {
        vm.expectRevert(SyncedBlockManager.NoSyncedBlocks.selector);
        checkpointManager.getSyncedBlock(0);
    }

    function test_getSyncedBlock_revert_indexOutOfBounds() public {
        vm.prank(authorized);

        checkpointManager.saveCheckpoint(100, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SyncedBlockManager.IndexOutOfBounds.selector);
        checkpointManager.getSyncedBlock(1);
    }

    function test_ringBuffer_behavior() public {
        vm.startPrank(authorized);

        // Fill the ring buffer to capacity (5 blocks)
        for (uint48 i = 1; i <= 5; i++) {
            checkpointManager.saveCheckpoint(i * 100, bytes32(uint256(i)), bytes32(uint256(i * 10)));
        }

        assertEq(checkpointManager.getNumberOfSyncedBlocks(), 5);
        assertEq(checkpointManager.getLatestSyncedBlockNumber(), 500);

        // Add a 6th block - should overwrite the oldest
        checkpointManager.saveCheckpoint(600, bytes32(uint256(6)), bytes32(uint256(60)));

        assertEq(checkpointManager.getNumberOfSyncedBlocks(), 5);
        assertEq(checkpointManager.getLatestSyncedBlockNumber(), 600);

        // Verify we can still access the last 5 blocks
        (uint48 latestBlockNum,,) = checkpointManager.getSyncedBlock(0);
        assertEq(latestBlockNum, 600);

        (uint48 oldestBlockNum,,) = checkpointManager.getSyncedBlock(4);
        assertEq(oldestBlockNum, 200); // Block 100 was overwritten

        // Verify block 100 cannot be accessed
        vm.expectRevert(SyncedBlockManager.IndexOutOfBounds.selector);
        checkpointManager.getSyncedBlock(5);

        vm.stopPrank();
    }

    function test_ringBuffer_wrapAround() public {
        vm.startPrank(authorized);

        // Fill buffer completely multiple times to test wrap-around
        for (uint48 i = 1; i <= 12; i++) {
            checkpointManager.saveCheckpoint(i * 100, bytes32(uint256(i)), bytes32(uint256(i * 10)));
        }

        assertEq(checkpointManager.getNumberOfSyncedBlocks(), 5);
        assertEq(checkpointManager.getLatestSyncedBlockNumber(), 1200);

        // Check that we have blocks 8-12 (blocks 1-7 were overwritten)
        for (uint48 i = 0; i < 5; i++) {
            (uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot) =
                checkpointManager.getSyncedBlock(i);
            assertEq(blockNumber, (12 - i) * 100);
            assertEq(blockHash, bytes32(uint256(12 - i)));
            assertEq(stateRoot, bytes32(uint256((12 - i) * 10)));
        }

        vm.stopPrank();
    }

    function test_getLatestSyncedBlockNumber_empty() public view {
        assertEq(checkpointManager.getLatestSyncedBlockNumber(), 0);
    }

    function test_getNumberOfSyncedBlocks_empty() public view {
        assertEq(checkpointManager.getNumberOfSyncedBlocks(), 0);
    }
}
