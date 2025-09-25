// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";
import { LibCheckpointStore } from "src/shared/shasta/libs/LibCheckpointStore.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

/// @title LibCheckpointStoreTest
/// @notice Unit tests for LibCheckpointStore library
/// @notice Wrapper contract to ensure proper call depth for reverts
contract CheckpointStoreWrapper {
    using LibCheckpointStore for LibCheckpointStore.Storage;

    LibCheckpointStore.Storage internal storage_;

    function saveCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint) external {
        storage_.saveCheckpoint(_checkpoint);
    }

    function getCheckpoint(uint48 _blockNumber)
        external
        view
        returns (ICheckpointStore.Checkpoint memory)
    {
        return storage_.getCheckpoint(_blockNumber);
    }
}

contract LibCheckpointStoreTest is CommonTest {
    using LibCheckpointStore for LibCheckpointStore.Storage;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    LibCheckpointStore.Storage internal storage_;
    CheckpointStoreWrapper internal wrapper;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);

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

        storage_.saveCheckpoint(checkpoint);

        // Retrieve and verify checkpoint
        ICheckpointStore.Checkpoint memory retrieved = storage_.getCheckpoint(100);
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

            storage_.saveCheckpoint(checkpoint);
        }

        // Verify retrieval of each checkpoint
        for (uint48 i = 1; i <= numCheckpoints; i++) {
            ICheckpointStore.Checkpoint memory retrieved =
                storage_.getCheckpoint(i * 100);
            assertEq(retrieved.blockNumber, i * 100);
            assertEq(retrieved.blockHash, bytes32(uint256(i)));
            assertEq(retrieved.stateRoot, bytes32(uint256(i * 10)));
        }
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
        wrapper.saveCheckpoint(checkpoint);
    }

    function test_revert_invalidCheckpoint_zeroBlockHash() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(0),
            stateRoot: bytes32(uint256(1))
        });

        vm.expectRevert(LibCheckpointStore.InvalidCheckpoint.selector);
        wrapper.saveCheckpoint(checkpoint);
    }


    function test_revert_getCheckpoint_notFound() public {
        vm.expectRevert(LibCheckpointStore.CheckpointNotFound.selector);
        wrapper.getCheckpoint(100);

        // Save a checkpoint at block 200
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 200,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });
        storage_.saveCheckpoint(checkpoint);

        // Try to get a non-existent checkpoint
        vm.expectRevert(LibCheckpointStore.CheckpointNotFound.selector);
        wrapper.getCheckpoint(100);
    }

    // ---------------------------------------------------------------
    // Test: Overwriting Checkpoints
    // ---------------------------------------------------------------

    function test_overwriteExistingCheckpoint() public {
        // Save initial checkpoint
        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });
        storage_.saveCheckpoint(checkpoint1);

        // Save new checkpoint at block 200
        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: 200,
            blockHash: bytes32(uint256(3)),
            stateRoot: bytes32(uint256(4))
        });
        storage_.saveCheckpoint(checkpoint2);

        // Now update checkpoint at block 300 (should work fine)
        ICheckpointStore.Checkpoint memory checkpoint3 = ICheckpointStore.Checkpoint({
            blockNumber: 300,
            blockHash: bytes32(uint256(5)),
            stateRoot: bytes32(uint256(6))
        });
        storage_.saveCheckpoint(checkpoint3);

        // Verify all checkpoints are stored correctly
        ICheckpointStore.Checkpoint memory retrieved1 = storage_.getCheckpoint(100);
        assertEq(retrieved1.blockHash, checkpoint1.blockHash);

        ICheckpointStore.Checkpoint memory retrieved2 = storage_.getCheckpoint(200);
        assertEq(retrieved2.blockHash, checkpoint2.blockHash);

        ICheckpointStore.Checkpoint memory retrieved3 = storage_.getCheckpoint(300);
        assertEq(retrieved3.blockHash, checkpoint3.blockHash);
    }

    // ---------------------------------------------------------------
    // Test: Fuzz Testing
    // ---------------------------------------------------------------

    function testFuzz_saveAndRetrieve(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
    {
        // Bound inputs to valid ranges
        vm.assume(blockNumber > 0 && blockNumber < type(uint48).max);
        vm.assume(blockHash != bytes32(0));
        vm.assume(stateRoot != bytes32(0));

        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber,
            blockHash: blockHash,
            stateRoot: stateRoot
        });

        storage_.saveCheckpoint(checkpoint);

        ICheckpointStore.Checkpoint memory retrieved =
            storage_.getCheckpoint(blockNumber);
        assertEq(retrieved.blockNumber, blockNumber);
        assertEq(retrieved.blockHash, blockHash);
        assertEq(retrieved.stateRoot, stateRoot);
    }

    function testFuzz_multipleCheckpoints(uint8 numCheckpoints) public {
        vm.assume(numCheckpoints > 0 && numCheckpoints <= 100);

        uint48 lastBlockNumber = 0;
        for (uint48 i = 1; i <= numCheckpoints; i++) {
            uint48 blockNum = i * 100;
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: blockNum,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            storage_.saveCheckpoint(checkpoint);
            lastBlockNumber = blockNum;
        }

        // Verify all checkpoints are retrievable
        for (uint48 i = 1; i <= numCheckpoints; i++) {
            ICheckpointStore.Checkpoint memory retrieved =
                storage_.getCheckpoint(i * 100);
            assertEq(retrieved.blockNumber, i * 100);
            assertEq(retrieved.blockHash, bytes32(uint256(i)));
            assertEq(retrieved.stateRoot, bytes32(uint256(i * 10)));
        }
    }

    // ---------------------------------------------------------------
    // Test: Gas Optimization Scenarios
    // ---------------------------------------------------------------

    function test_gasOptimization_continuousSaves() public {
        uint256 gasUsed;
        uint256 startGas;

        // Measure gas for saving checkpoints
        for (uint48 i = 1; i <= 10; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: i,
                blockHash: bytes32(uint256(i)),
                stateRoot: bytes32(uint256(i * 10))
            });

            startGas = gasleft();
            storage_.saveCheckpoint(checkpoint);
            gasUsed = startGas - gasleft();

            // Gas usage for first write to a storage slot is higher (around 90k)
            // Subsequent writes to same slot would be cheaper (~5k)
            assertLt(gasUsed, 95_000, "Gas usage too high for checkpoint save");
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
}