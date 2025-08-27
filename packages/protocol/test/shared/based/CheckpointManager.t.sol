// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "../CommonTest.sol";
import {CheckpointManager } from "src/shared/based/impl/CheckpointManager.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @custom:security-contact security@taiko.xyz
contract CheckpointManagerTest is CommonTest {
   CheckpointManager public checkpointManager;
    address public authorized = Alice;

    function setUp() public override {
        super.setUp();
        checkpointManager = new CheckpointManager(authorized, 5);
    }

    function test_constructor() public view {
        assertEq(checkpointManager.authorized(), authorized);
        assertEq(checkpointManager.maxStackSize(), 5);
    }

    function test_constructor_revert_zeroAddress() public {
        vm.expectRevert(CheckpointManager.InvalidAddress.selector);
        new CheckpointManager(address(0), 5);
    }

    function test_constructor_revert_zeroMaxStackSize() public {
        vm.expectRevert(CheckpointManager.InvalidMaxStackSize.selector);
        new CheckpointManager(authorized, 0);
    }

    function test_saveCheckpoint() public {
        vm.prank(authorized);

        vm.expectEmit(true, true, true, true);
        emit ICheckpointManager.CheckpointSaved(100, bytes32(uint256(1)), bytes32(uint256(2)));

        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        }));

        assertEq(checkpointManager.getLatestCheckpointNumber(), 100);
        assertEq(checkpointManager.getNumberOfCheckpoints(), 1);

        ICheckpointManager.Checkpoint memory checkpoint = checkpointManager.getCheckpoint(0);
        assertEq(checkpoint.blockNumber, 100);
        assertEq(checkpoint.blockHash, bytes32(uint256(1)));
        assertEq(checkpoint.stateRoot, bytes32(uint256(2)));
    }

    function test_saveCheckpoint_multipleBlocks() public {
        vm.startPrank(authorized);

        for (uint48 i = 1; i <= 3; i++) {
            checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
                blockNumber: i * 100,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            }));
        }

        vm.stopPrank();

        assertEq(checkpointManager.getLatestCheckpointNumber(), 300);
        assertEq(checkpointManager.getNumberOfCheckpoints(), 3);

        // Check offset 0 (latest)
        ICheckpointManager.Checkpoint memory checkpoint = checkpointManager.getCheckpoint(0);
        assertEq(checkpoint.blockNumber, 300);
        assertEq(checkpoint.blockHash, bytes32(uint256(3)));
        assertEq(checkpoint.stateRoot, bytes32(uint256(30)));

        // Check offset 1 (second latest)
        checkpoint = checkpointManager.getCheckpoint(1);
        assertEq(checkpoint.blockNumber, 200);
        assertEq(checkpoint.blockHash, bytes32(uint256(2)));
        assertEq(checkpoint.stateRoot, bytes32(uint256(20)));

        // Check offset 2 (third latest)
       checkpoint = checkpointManager.getCheckpoint(2);
        assertEq(checkpoint.blockNumber, 100);
        assertEq(checkpoint.blockHash, bytes32(uint256(1)));
        assertEq(checkpoint.stateRoot, bytes32(uint256(10)));
    }

    function test_saveCheckpoint_revert_unauthorized() public {
        vm.prank(Bob);

        vm.expectRevert();
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        }));
    }

    function test_saveCheckpoint_revert_zeroStateRoot() public {
        vm.prank(authorized);

            vm.expectRevert(CheckpointManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(0)
        }));
    }

    function test_saveCheckpoint_revert_zeroBlockHash() public {
        vm.prank(authorized);

        vm.expectRevert(CheckpointManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(0),
            stateRoot: bytes32(uint256(2))
        }));
    }

    function test_saveCheckpoint_revert_zeroBlockNumber() public {
        vm.prank(authorized);

        vm.expectRevert(CheckpointManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 0,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        }));
    }

    function test_saveCheckpoint_revert_decreasingBlockNumber() public {
        vm.startPrank(authorized);

        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        }));

        vm.expectRevert(CheckpointManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 99,
            blockHash: bytes32(uint256(3)),
            stateRoot: bytes32(uint256(4))
        }));

        vm.stopPrank();
    }

    function test_saveCheckpoint_revert_sameBlockNumber() public {
        vm.startPrank(authorized);

        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        }));

        vm.expectRevert(CheckpointManager.InvalidCheckpoint.selector);
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(3)),
            stateRoot: bytes32(uint256(4))
        }));

        vm.stopPrank();
    }

    function test_getSyncedBlock_revert_noCheckpoints() public {
        vm.expectRevert(CheckpointManager.NoCheckpoints.selector);
        checkpointManager.getCheckpoint(0);
    }

    function test_getSyncedBlock_revert_indexOutOfBounds() public {
        vm.prank(authorized);

        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        }));

        vm.expectRevert(CheckpointManager.IndexOutOfBounds.selector);
        checkpointManager.getCheckpoint(1);
    }

    function test_ringBuffer_behavior() public {
        vm.startPrank(authorized);

        // Fill the ring buffer to capacity (5 blocks)
        for (uint48 i = 1; i <= 5; i++) {
            checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
                blockNumber: i * 100,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            }));
        }

        assertEq(checkpointManager.getNumberOfCheckpoints(), 5);
        assertEq(checkpointManager.getLatestCheckpointNumber(), 500);

        // Add a 6th block - should overwrite the oldest
        checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
            blockNumber: 600,
            blockHash: bytes32(uint256(6)),
            stateRoot: bytes32(uint256(60))
        }));

        assertEq(checkpointManager.getNumberOfCheckpoints(), 5);
        assertEq(checkpointManager.getLatestCheckpointNumber(), 600);

        // Verify we can still access the last 5 blocks
        assertEq( checkpointManager.getCheckpoint(0).blockNumber, 600);

        assertEq(checkpointManager.getCheckpoint(4).blockNumber, 200); // Block 100 was overwritten

        // Verify block 100 cannot be accessed
        vm.expectRevert(CheckpointManager.IndexOutOfBounds.selector);
        checkpointManager.getCheckpoint(5);

        vm.stopPrank();
    }

    function test_ringBuffer_wrapAround() public {
        vm.startPrank(authorized);

        // Fill buffer completely multiple times to test wrap-around
        for (uint48 i = 1; i <= 12; i++) {
            checkpointManager.saveCheckpoint(ICheckpointManager.Checkpoint({
                blockNumber: i * 100,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            }));
        }

        assertEq(checkpointManager.getNumberOfCheckpoints(), 5);
        assertEq(checkpointManager.getLatestCheckpointNumber(), 1200);

        // Check that we have blocks 8-12 (blocks 1-7 were overwritten)
        for (uint48 i = 0; i < 5; i++) {
            ICheckpointManager.Checkpoint memory checkpoint = checkpointManager.getCheckpoint(i);
            assertEq(checkpoint.blockNumber, (12 - i) * 100);
            assertEq(checkpoint.blockHash, bytes32(uint256(12 - i)));
            assertEq(checkpoint.stateRoot, bytes32(uint256((12 - i) * 10)));
        }

        vm.stopPrank();
    }

    function test_getLatestCheckpointNumber_empty() public view {
        assertEq(checkpointManager.getLatestCheckpointNumber(), 0);
    }

    function test_getNumberOfCheckpoints_empty() public view {
        assertEq(checkpointManager.getNumberOfCheckpoints(), 0);
    }
}
