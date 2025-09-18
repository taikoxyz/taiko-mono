// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";
import { LibCheckpointStore } from "src/shared/shasta/libs/LibCheckpointStore.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

/// @title LibCheckpointStoreTest
/// @notice Comprehensive unit tests for LibCheckpointStore library
/// @dev Tests cover:
///      - Ring buffer behavior with various history sizes
///      - Checkpoint storage and retrieval
///      - Edge cases and error conditions
///      - Stack management and wraparound scenarios
/// @notice Wrapper contract to ensure proper call depth for reverts
contract CheckpointStoreWrapper {
    using LibCheckpointStore for LibCheckpointStore.Storage;

    LibCheckpointStore.Storage internal storage_;

    function saveCheckpoint(
        ICheckpointStore.Checkpoint memory _checkpoint,
        uint48 _maxCheckpointHistory
    )
        external
    {
        storage_.saveCheckpoint(_checkpoint, _maxCheckpointHistory);
    }
}

contract LibCheckpointStoreTest is CommonTest {
    using LibCheckpointStore for LibCheckpointStore.Storage;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint48 constant MAX_HISTORY = 5;
    uint48 constant LARGE_MAX_HISTORY = 100;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    LibCheckpointStore.Storage internal storage_;
    CheckpointStoreWrapper internal wrapper;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event CheckpointSaved(uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot);

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public override {
        super.setUp();
        // Initialize with a clean storage state
        delete storage_;
        wrapper = new CheckpointStoreWrapper();
    }

    // ---------------------------------------------------------------
    // Test: Basic Storage and Retrieval
    // ---------------------------------------------------------------

    function test_saveAndRetrieveSingleCheckpoint() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });

        // Note: Event is emitted from the library context during delegatecall
        storage_.saveCheckpoint(checkpoint, MAX_HISTORY);

        // Verify storage state
        assertEq(storage_.getLatestCheckpointBlockNumber(), 100);
        assertEq(storage_.getNumberOfCheckpoints(), 1);

        // Retrieve and verify checkpoint
        ICheckpointStore.Checkpoint memory retrieved = storage_.getCheckpoint(0, MAX_HISTORY);
        assertEq(retrieved.blockNumber, checkpoint.blockNumber);
        assertEq(retrieved.blockHash, checkpoint.blockHash);
        assertEq(retrieved.stateRoot, checkpoint.stateRoot);
    }

    function test_saveMultipleCheckpoints() public {
        uint48 numCheckpoints = 3;

        for (uint48 i = 1; i <= numCheckpoints; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i * 100,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint, MAX_HISTORY);
        }

        assertEq(storage_.getLatestCheckpointBlockNumber(), 300);
        assertEq(storage_.getNumberOfCheckpoints(), 3);

        // Verify retrieval in reverse order (most recent first)
        for (uint48 i = 0; i < numCheckpoints; i++) {
            ICheckpointStore.Checkpoint memory retrieved = storage_.getCheckpoint(i, MAX_HISTORY);
            uint48 expectedBlockNum = (numCheckpoints - i) * 100;
            assertEq(retrieved.blockNumber, expectedBlockNum);
            assertEq(retrieved.blockHash, bytes32(uint256(numCheckpoints - i)));
            assertEq(retrieved.stateRoot, bytes32(uint256((numCheckpoints - i) * 10)));
        }
    }

    // ---------------------------------------------------------------
    // Test: Ring Buffer Behavior
    // ---------------------------------------------------------------

    function test_ringBufferOverwrite() public {
        // Fill buffer beyond capacity
        uint48 totalCheckpoints = MAX_HISTORY + 3;

        for (uint48 i = 1; i <= totalCheckpoints; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i * 100,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint, MAX_HISTORY);
        }

        // Stack size should be capped at MAX_HISTORY
        assertEq(storage_.getNumberOfCheckpoints(), MAX_HISTORY);
        assertEq(storage_.getLatestCheckpointBlockNumber(), 800);

        // Verify only the most recent MAX_HISTORY checkpoints are stored
        // Should have checkpoints 4-8 (400-800)
        for (uint48 i = 0; i < MAX_HISTORY; i++) {
            ICheckpointStore.Checkpoint memory retrieved = storage_.getCheckpoint(i, MAX_HISTORY);
            uint48 expectedNum = (totalCheckpoints - i) * 100;
            assertEq(retrieved.blockNumber, expectedNum);
        }
    }

    function test_ringBufferWrapAroundCalculation() public {
        // Test with specific wrap-around scenarios
        uint48 historySize = 3;

        // Add 5 checkpoints to a buffer of size 3
        for (uint48 i = 1; i <= 5; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint, historySize);
        }

        // Should have checkpoints 3, 4, 5 in the buffer
        assertEq(storage_.getNumberOfCheckpoints(), 3);

        // Most recent (offset 0) should be checkpoint 5
        ICheckpointStore.Checkpoint memory latest = storage_.getCheckpoint(0, historySize);
        assertEq(latest.blockNumber, 5);

        // Second most recent (offset 1) should be checkpoint 4
        ICheckpointStore.Checkpoint memory secondLatest = storage_.getCheckpoint(1, historySize);
        assertEq(secondLatest.blockNumber, 4);

        // Oldest (offset 2) should be checkpoint 3
        ICheckpointStore.Checkpoint memory oldest = storage_.getCheckpoint(2, historySize);
        assertEq(oldest.blockNumber, 3);
    }

    // ---------------------------------------------------------------
    // Test: Error Conditions
    // ---------------------------------------------------------------

    function test_revert_invalidCheckpoint_zeroStateRoot() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(0)
        });

        vm.expectRevert(LibCheckpointStore.InvalidCheckpoint.selector);
        wrapper.saveCheckpoint(checkpoint, MAX_HISTORY);
    }

    function test_revert_invalidCheckpoint_zeroBlockHash() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(0),
            stateRoot: bytes32(uint256(1))
        });

        vm.expectRevert(LibCheckpointStore.InvalidCheckpoint.selector);
        wrapper.saveCheckpoint(checkpoint, MAX_HISTORY);
    }

    function test_revert_invalidCheckpoint_nonIncreasingBlockNumber() public {
        // Save first checkpoint
        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });
        wrapper.saveCheckpoint(checkpoint1, MAX_HISTORY);

        // Try to save checkpoint with same block number
        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(3)),
            stateRoot: bytes32(uint256(4))
        });

        vm.expectRevert(LibCheckpointStore.InvalidCheckpoint.selector);
        wrapper.saveCheckpoint(checkpoint2, MAX_HISTORY);

        // Try to save checkpoint with lower block number
        ICheckpointStore.Checkpoint memory checkpoint3 = ICheckpointStore.Checkpoint({
            blockNumber: 99,
            blockHash: bytes32(uint256(5)),
            stateRoot: bytes32(uint256(6))
        });

        vm.expectRevert(LibCheckpointStore.InvalidCheckpoint.selector);
        wrapper.saveCheckpoint(checkpoint3, MAX_HISTORY);
    }

    function test_revert_invalidCheckpointHistory_zero() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });

        vm.expectRevert(LibCheckpointStore.InvalidMaxCheckpointHistory.selector);
        wrapper.saveCheckpoint(checkpoint, 0);
    }

    function test_revert_getCheckpoint_noCheckpoints() public {
        vm.expectRevert(LibCheckpointStore.IndexOutOfBounds.selector);
        storage_.getCheckpoint(0, MAX_HISTORY);
    }

    function test_revert_getCheckpoint_indexOutOfBounds() public {
        // Save one checkpoint
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });
        storage_.saveCheckpoint(checkpoint, MAX_HISTORY);

        // Try to access index 1 when only 1 checkpoint exists
        vm.expectRevert(LibCheckpointStore.IndexOutOfBounds.selector);
        storage_.getCheckpoint(1, MAX_HISTORY);
    }

    // ---------------------------------------------------------------
    // Test: Edge Cases
    // ---------------------------------------------------------------

    function test_singleSlotRingBuffer() public {
        uint48 historySize = 1;

        // Add multiple checkpoints to a buffer of size 1
        for (uint48 i = 1; i <= 3; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i * 100,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint, historySize);
        }

        // Should only have the last checkpoint
        assertEq(storage_.getNumberOfCheckpoints(), 1);
        assertEq(storage_.getLatestCheckpointBlockNumber(), 300);

        ICheckpointStore.Checkpoint memory retrieved = storage_.getCheckpoint(0, historySize);
        assertEq(retrieved.blockNumber, 300);
    }

    function test_largeRingBuffer() public {
        // Test with a large buffer size
        for (uint48 i = 1; i <= 50; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint, LARGE_MAX_HISTORY);
        }

        assertEq(storage_.getNumberOfCheckpoints(), 50);
        assertEq(storage_.getLatestCheckpointBlockNumber(), 50);

        // Verify all 50 checkpoints are accessible
        for (uint48 i = 0; i < 50; i++) {
            ICheckpointStore.Checkpoint memory retrieved =
                storage_.getCheckpoint(i, LARGE_MAX_HISTORY);
            assertEq(retrieved.blockNumber, 50 - i);
        }
    }

    // ---------------------------------------------------------------
    // Test: Fuzz Testing
    // ---------------------------------------------------------------

    function testFuzz_saveAndRetrieve(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint48 maxHistory
    )
        public
    {
        // Bound inputs to valid ranges
        vm.assume(blockNumber > 0 && blockNumber < type(uint48).max);
        vm.assume(blockHash != bytes32(0));
        vm.assume(stateRoot != bytes32(0));
        vm.assume(maxHistory > 0 && maxHistory <= 1000);

        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber,
            blockHash: blockHash,
            stateRoot: stateRoot
        });

        storage_.saveCheckpoint(checkpoint, maxHistory);

        assertEq(storage_.getLatestCheckpointBlockNumber(), blockNumber);
        assertEq(storage_.getNumberOfCheckpoints(), 1);

        ICheckpointStore.Checkpoint memory retrieved = storage_.getCheckpoint(0, maxHistory);
        assertEq(retrieved.blockNumber, blockNumber);
        assertEq(retrieved.blockHash, blockHash);
        assertEq(retrieved.stateRoot, stateRoot);
    }

    function testFuzz_ringBufferBehavior(uint8 maxHistory, uint8 numCheckpoints) public {
        // Bound to reasonable values
        vm.assume(maxHistory > 0 && maxHistory <= 20);
        vm.assume(numCheckpoints > 0 && numCheckpoints <= 100);

        for (uint48 i = 1; i <= numCheckpoints; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint, maxHistory);
        }

        // Verify stack size is correctly capped
        uint48 expectedSize = numCheckpoints < maxHistory ? numCheckpoints : maxHistory;
        assertEq(storage_.getNumberOfCheckpoints(), expectedSize);
        assertEq(storage_.getLatestCheckpointBlockNumber(), numCheckpoints);

        // Verify most recent checkpoint is accessible
        if (numCheckpoints > 0) {
            ICheckpointStore.Checkpoint memory latest = storage_.getCheckpoint(0, maxHistory);
            assertEq(latest.blockNumber, numCheckpoints);
        }
    }

    // ---------------------------------------------------------------
    // Test: Gas Optimization Scenarios
    // ---------------------------------------------------------------

    function test_gasOptimization_continuousSaves() public {
        uint256 gasUsed;
        uint256 startGas;

        // Measure gas for saving checkpoints in a full buffer
        for (uint48 i = 1; i <= MAX_HISTORY * 2; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            startGas = gasleft();
            storage_.saveCheckpoint(checkpoint, MAX_HISTORY);
            gasUsed = startGas - gasleft();

            // Gas usage should be relatively constant after buffer fills
            if (i > MAX_HISTORY) {
                // Allow 10% variance in gas usage
                assertLt(gasUsed, 50_000, "Gas usage too high for checkpoint save");
            }
        }
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    function _createCheckpoint(uint48 blockNumber)
        private
        pure
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: blockNumber,
            blockHash: bytes32(uint256(blockNumber)),
            stateRoot: bytes32(uint256(blockNumber * 10))
        });
    }

    function _fillBuffer(uint48 count, uint48 maxHistory) private {
        for (uint48 i = 1; i <= count; i++) {
            storage_.saveCheckpoint(_createCheckpoint(i), maxHistory);
        }
    }
}
