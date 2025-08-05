// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "../CommonTest.sol";
import { SyncedBlockManager } from "contracts/shared/shasta/impl/SyncedBlockManager.sol";
import { ISyncedBlockManager } from "contracts/shared/shasta/iface/ISyncedBlockManager.sol";

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

        ISyncedBlockManager.SyncedBlock memory block1 = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 100
        });

        vm.expectEmit(true, true, true, true);
        emit ISyncedBlockManager.SyncedBlockSaved(100, bytes32(uint256(1)), bytes32(uint256(2)));

        syncedBlockManager.saveSyncedBlock(block1);

        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 100);
        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 1);

        ISyncedBlockManager.SyncedBlock memory retrieved = syncedBlockManager.getSyncedBlock(0);
        assertEq(retrieved.blockNumber, 100);
        assertEq(retrieved.blockHash, bytes32(uint256(1)));
        assertEq(retrieved.stateRoot, bytes32(uint256(2)));
    }

    function test_saveSyncedBlock_multipleBlocks() public {
        vm.startPrank(authorized);

        for (uint48 i = 1; i <= 3; i++) {
            ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10)),
                blockNumber: i * 100
            });
            syncedBlockManager.saveSyncedBlock(block_);
        }

        vm.stopPrank();

        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 300);
        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 3);

        // Check offset 0 (latest)
        ISyncedBlockManager.SyncedBlock memory latest = syncedBlockManager.getSyncedBlock(0);
        assertEq(latest.blockNumber, 300);
        assertEq(latest.blockHash, bytes32(uint256(3)));
        assertEq(latest.stateRoot, bytes32(uint256(30)));

        // Check offset 1 (second latest)
        ISyncedBlockManager.SyncedBlock memory secondLatest = syncedBlockManager.getSyncedBlock(1);
        assertEq(secondLatest.blockNumber, 200);
        assertEq(secondLatest.blockHash, bytes32(uint256(2)));
        assertEq(secondLatest.stateRoot, bytes32(uint256(20)));

        // Check offset 2 (third latest)
        ISyncedBlockManager.SyncedBlock memory thirdLatest = syncedBlockManager.getSyncedBlock(2);
        assertEq(thirdLatest.blockNumber, 100);
        assertEq(thirdLatest.blockHash, bytes32(uint256(1)));
        assertEq(thirdLatest.stateRoot, bytes32(uint256(10)));
    }

    function test_saveSyncedBlock_revert_unauthorized() public {
        vm.prank(Bob);

        ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 100
        });

        vm.expectRevert(SyncedBlockManager.Unauthorized.selector);
        syncedBlockManager.saveSyncedBlock(block_);
    }

    function test_saveSyncedBlock_revert_zeroStateRoot() public {
        vm.prank(authorized);

        ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(0),
            blockNumber: 100
        });

        vm.expectRevert(
            abi.encodeWithSelector(SyncedBlockManager.InvalidSyncedBlock.selector, 100, 0)
        );
        syncedBlockManager.saveSyncedBlock(block_);
    }

    function test_saveSyncedBlock_revert_zeroBlockHash() public {
        vm.prank(authorized);

        ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(0),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 100
        });

        vm.expectRevert(
            abi.encodeWithSelector(SyncedBlockManager.InvalidSyncedBlock.selector, 100, 0)
        );
        syncedBlockManager.saveSyncedBlock(block_);
    }

    function test_saveSyncedBlock_revert_zeroBlockNumber() public {
        vm.prank(authorized);

        ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(SyncedBlockManager.InvalidSyncedBlock.selector, 0, 0)
        );
        syncedBlockManager.saveSyncedBlock(block_);
    }

    function test_saveSyncedBlock_revert_decreasingBlockNumber() public {
        vm.startPrank(authorized);

        ISyncedBlockManager.SyncedBlock memory block1 = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 100
        });
        syncedBlockManager.saveSyncedBlock(block1);

        ISyncedBlockManager.SyncedBlock memory block2 = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(3)),
            stateRoot: bytes32(uint256(4)),
            blockNumber: 99
        });

        vm.expectRevert(
            abi.encodeWithSelector(SyncedBlockManager.InvalidSyncedBlock.selector, 99, 100)
        );
        syncedBlockManager.saveSyncedBlock(block2);

        vm.stopPrank();
    }

    function test_saveSyncedBlock_revert_sameBlockNumber() public {
        vm.startPrank(authorized);

        ISyncedBlockManager.SyncedBlock memory block1 = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 100
        });
        syncedBlockManager.saveSyncedBlock(block1);

        ISyncedBlockManager.SyncedBlock memory block2 = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(3)),
            stateRoot: bytes32(uint256(4)),
            blockNumber: 100
        });

        vm.expectRevert(
            abi.encodeWithSelector(SyncedBlockManager.InvalidSyncedBlock.selector, 100, 100)
        );
        syncedBlockManager.saveSyncedBlock(block2);

        vm.stopPrank();
    }

    function test_getSyncedBlock_revert_noSyncedBlocks() public {
        vm.expectRevert(SyncedBlockManager.NoSyncedBlocks.selector);
        syncedBlockManager.getSyncedBlock(0);
    }

    function test_getSyncedBlock_revert_indexOutOfBounds() public {
        vm.prank(authorized);

        ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            blockNumber: 100
        });
        syncedBlockManager.saveSyncedBlock(block_);

        vm.expectRevert(abi.encodeWithSelector(SyncedBlockManager.IndexOutOfBounds.selector, 1, 1));
        syncedBlockManager.getSyncedBlock(1);
    }

    function test_ringBuffer_behavior() public {
        vm.startPrank(authorized);

        // Fill the ring buffer to capacity (5 blocks)
        for (uint48 i = 1; i <= 5; i++) {
            ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10)),
                blockNumber: i * 100
            });
            syncedBlockManager.saveSyncedBlock(block_);
        }

        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 5);
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 500);

        // Add a 6th block - should overwrite the oldest
        ISyncedBlockManager.SyncedBlock memory block6 = ISyncedBlockManager.SyncedBlock({
            blockHash: bytes32(uint256(6)),
            stateRoot: bytes32(uint256(60)),
            blockNumber: 600
        });
        syncedBlockManager.saveSyncedBlock(block6);

        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 5);
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 600);

        // Verify we can still access the last 5 blocks
        ISyncedBlockManager.SyncedBlock memory latest = syncedBlockManager.getSyncedBlock(0);
        assertEq(latest.blockNumber, 600);

        ISyncedBlockManager.SyncedBlock memory oldest = syncedBlockManager.getSyncedBlock(4);
        assertEq(oldest.blockNumber, 200); // Block 100 was overwritten

        // Verify block 100 cannot be accessed
        vm.expectRevert(abi.encodeWithSelector(SyncedBlockManager.IndexOutOfBounds.selector, 5, 5));
        syncedBlockManager.getSyncedBlock(5);

        vm.stopPrank();
    }

    function test_ringBuffer_wrapAround() public {
        vm.startPrank(authorized);

        // Fill buffer completely multiple times to test wrap-around
        for (uint48 i = 1; i <= 12; i++) {
            ISyncedBlockManager.SyncedBlock memory block_ = ISyncedBlockManager.SyncedBlock({
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10)),
                blockNumber: i * 100
            });
            syncedBlockManager.saveSyncedBlock(block_);
        }

        assertEq(syncedBlockManager.getNumberOfSyncedBlocks(), 5);
        assertEq(syncedBlockManager.getLatestSyncedBlockNumber(), 1200);

        // Check that we have blocks 8-12 (blocks 1-7 were overwritten)
        for (uint48 i = 0; i < 5; i++) {
            ISyncedBlockManager.SyncedBlock memory block_ = syncedBlockManager.getSyncedBlock(i);
            assertEq(block_.blockNumber, (12 - i) * 100);
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
