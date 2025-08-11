// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "../CommonTest.sol";
import { SyncedBlockManager } from "contracts/shared/based/impl/SyncedBlockManager.sol";
import { ISyncedBlockManager } from "contracts/shared/based/iface/ISyncedBlockManager.sol";

/// @custom:security-contact security@taiko.xyz
contract SyncedBlockManagerTest is CommonTest {
    SyncedBlockManager public syncedBlockManager;
    address public authorized = Alice;

    function setUp() public override {
        super.setUp();
        syncedBlockManager = new SyncedBlockManager(authorized, 5);
    }

    function test_constructor() public view {
        assertEq(syncedBlockManager.authorized(), authorized);
        assertEq(syncedBlockManager.maxStackSize(), 5);
    }

    function test_constructor_revert_zeroAddress() public {
        vm.expectRevert(SyncedBlockManager.InvalidAddress.selector);
        new SyncedBlockManager(address(0), 5);
    }

    function test_constructor_revert_zeroMaxStackSize() public {
        vm.expectRevert(SyncedBlockManager.InvalidMaxStackSize.selector);
        new SyncedBlockManager(authorized, 0);
    }

    function test_saveSyncedBlock() public {
        vm.prank(authorized);

        vm.expectEmit(true, true, true, true);
        emit ISyncedBlockManager.SyncedBlockSaved(100, bytes32(uint256(1)), bytes32(uint256(2)));

        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(1)), bytes32(uint256(2)));

        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 100);
        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 1);

        (uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot) =
            syncedBlockManager.getSyncedBlock(0);
        assertEq(blockNumber, 100);
        assertEq(blockHash, bytes32(uint256(1)));
        assertEq(stateRoot, bytes32(uint256(2)));
    }

    function test_saveSyncedBlock_multipleBlocks() public {
        vm.startPrank(authorized);

        for (uint48 i = 1; i <= 3; i++) {
            syncedBlockManager.saveSyncedBlock(
                i * 100, bytes32(uint256(i)), bytes32(uint256(i * 10))
            );
        }

        vm.stopPrank();

        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 300);
        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 3);

        // Check offset 0 (latest)
        (uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot) =
            syncedBlockManager.getSyncedBlock(0);
        assertEq(blockNumber, 300);
        assertEq(blockHash, bytes32(uint256(3)));
        assertEq(stateRoot, bytes32(uint256(30)));

        // Check offset 1 (second latest)
        (blockNumber, blockHash, stateRoot) = syncedBlockManager.getSyncedBlock(1);
        assertEq(blockNumber, 200);
        assertEq(blockHash, bytes32(uint256(2)));
        assertEq(stateRoot, bytes32(uint256(20)));

        // Check offset 2 (third latest)
        (blockNumber, blockHash, stateRoot) = syncedBlockManager.getSyncedBlock(2);
        assertEq(blockNumber, 100);
        assertEq(blockHash, bytes32(uint256(1)));
        assertEq(stateRoot, bytes32(uint256(10)));
    }

    function test_saveSyncedBlock_revert_unauthorized() public {
        vm.prank(Bob);

        vm.expectRevert(SyncedBlockManager.Unauthorized.selector);
        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function test_saveSyncedBlock_revert_zeroStateRoot() public {
        vm.prank(authorized);

        vm.expectRevert(SyncedBlockManager.InvalidSyncedBlock.selector);
        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(1)), bytes32(0));
    }

    function test_saveSyncedBlock_revert_zeroBlockHash() public {
        vm.prank(authorized);

        vm.expectRevert(SyncedBlockManager.InvalidSyncedBlock.selector);
        syncedBlockManager.saveSyncedBlock(100, bytes32(0), bytes32(uint256(2)));
    }

    function test_saveSyncedBlock_revert_zeroBlockNumber() public {
        vm.prank(authorized);

        vm.expectRevert(SyncedBlockManager.InvalidSyncedBlock.selector);
        syncedBlockManager.saveSyncedBlock(0, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function test_saveSyncedBlock_revert_decreasingBlockNumber() public {
        vm.startPrank(authorized);

        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SyncedBlockManager.InvalidSyncedBlock.selector);
        syncedBlockManager.saveSyncedBlock(99, bytes32(uint256(3)), bytes32(uint256(4)));

        vm.stopPrank();
    }

    function test_saveSyncedBlock_revert_sameBlockNumber() public {
        vm.startPrank(authorized);

        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SyncedBlockManager.InvalidSyncedBlock.selector);
        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(3)), bytes32(uint256(4)));

        vm.stopPrank();
    }

    function test_getSyncedBlock_revert_noSyncedBlocks() public {
        vm.expectRevert(SyncedBlockManager.NoSyncedBlocks.selector);
        syncedBlockManager.getSyncedBlock(0);
    }

    function test_getSyncedBlock_revert_indexOutOfBounds() public {
        vm.prank(authorized);

        syncedBlockManager.saveSyncedBlock(100, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SyncedBlockManager.IndexOutOfBounds.selector);
        syncedBlockManager.getSyncedBlock(1);
    }

    function test_ringBuffer_behavior() public {
        vm.startPrank(authorized);

        // Fill the ring buffer to capacity (5 blocks)
        for (uint48 i = 1; i <= 5; i++) {
            syncedBlockManager.saveSyncedBlock(
                i * 100, bytes32(uint256(i)), bytes32(uint256(i * 10))
            );
        }

        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 5);
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 500);

        // Add a 6th block - should overwrite the oldest
        syncedBlockManager.saveSyncedBlock(600, bytes32(uint256(6)), bytes32(uint256(60)));

        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 5);
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 600);

        // Verify we can still access the last 5 blocks
        (uint48 latestBlockNum,,) = syncedBlockManager.getSyncedBlock(0);
        assertEq(latestBlockNum, 600);

        (uint48 oldestBlockNum,,) = syncedBlockManager.getSyncedBlock(4);
        assertEq(oldestBlockNum, 200); // Block 100 was overwritten

        // Verify block 100 cannot be accessed
        vm.expectRevert(SyncedBlockManager.IndexOutOfBounds.selector);
        syncedBlockManager.getSyncedBlock(5);

        vm.stopPrank();
    }

    function test_ringBuffer_wrapAround() public {
        vm.startPrank(authorized);

        // Fill buffer completely multiple times to test wrap-around
        for (uint48 i = 1; i <= 12; i++) {
            syncedBlockManager.saveSyncedBlock(
                i * 100, bytes32(uint256(i)), bytes32(uint256(i * 10))
            );
        }

        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 5);
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 1200);

        // Check that we have blocks 8-12 (blocks 1-7 were overwritten)
        for (uint48 i = 0; i < 5; i++) {
            (uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot) =
                syncedBlockManager.getSyncedBlock(i);
            assertEq(blockNumber, (12 - i) * 100);
            assertEq(blockHash, bytes32(uint256(12 - i)));
            assertEq(stateRoot, bytes32(uint256((12 - i) * 10)));
        }

        vm.stopPrank();
    }

    function test_getLatestSyncedBlockNumber_empty() public view {
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 0);
    }

    function test_getNumberOfSyncedBlocks_empty() public view {
        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 0);
    }
}
