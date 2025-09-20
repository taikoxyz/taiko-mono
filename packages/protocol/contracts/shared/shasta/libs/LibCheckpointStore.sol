// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "../iface/ICheckpointStore.sol";

/// @title LibCheckpointStore
/// @notice Library for managing synced L1 or L2 checkpoints using a ring buffer
/// @dev This library implements a ring buffer to store the most recent checkpoints.
/// When the buffer is full, new blocks overwrite the oldest entries. The library
/// ensures blocks are saved in strictly increasing order by block number.
/// @custom:security-contact security@taiko.xyz
library LibCheckpointStore {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Storage for the checkpoint ring buffer
    /// @dev 2 slots used
    struct Storage {
        /// @notice Ring buffer as a stack for storing checkpoints
        /// @dev Maps slot indices (0 to maxHistorySize-1) to checkpoint data
        mapping(uint48 slot => ICheckpointStore.Checkpoint checkpoint) checkpoints;
        /// @notice The latest checkpoint number
        uint48 latestCheckpointBlockNumber;
        /// @notice The current top of the stack (ring buffer index)
        uint48 stackTop;
        /// @notice The current number of items in the stack
        uint48 stackSize;
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Saves a new checkpoint
    /// @param $ The storage struct
    /// @param _checkpoint The checkpoint to save
    /// @param _maxCheckpointHistory The maximum number of checkpoints to store
    function saveCheckpoint(
        Storage storage $,
        ICheckpointStore.Checkpoint memory _checkpoint,
        uint48 _maxCheckpointHistory
    )
        public
    {
        require(_maxCheckpointHistory != 0, InvalidMaxCheckpointHistory());
        require(_checkpoint.stateRoot != bytes32(0), InvalidCheckpoint());
        require(_checkpoint.blockHash != bytes32(0), InvalidCheckpoint());

        (uint48 latestCheckpointBlockNumber, uint48 stackTop, uint48 stackSize) =
            ($.latestCheckpointBlockNumber, $.stackTop, $.stackSize);

        require(_checkpoint.blockNumber > latestCheckpointBlockNumber, InvalidCheckpoint());

        unchecked {
            // Ring buffer implementation:
            // - stackTop starts at 0 and cycles through 0 to (maxHistorySize-1)
            // - When we reach maxHistorySize, it wraps back to 0
            // - This ensures we always overwrite the oldest entry when buffer is full
            stackTop = (stackTop + 1) % _maxCheckpointHistory;

            $.checkpoints[stackTop] = _checkpoint;

            // Update stack size (capped at maxHistorySize)
            if (stackSize < _maxCheckpointHistory) {
                stackSize += 1;
            }
        }

        ($.latestCheckpointBlockNumber, $.stackTop, $.stackSize) =
            (_checkpoint.blockNumber, stackTop, stackSize);

        emit ICheckpointStore.CheckpointSaved(
            _checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot
        );
    }

    /// @notice Gets a checkpoint by index
    /// @param $ The storage struct
    /// @param _offset The offset of the checkpoint. Use 0 for the last checkpoint, 1 for the
    /// second last, etc.
    /// @param _maxCheckpointHistory The maximum number of checkpoints to store
    /// @return _ The checkpoint
    function getCheckpoint(
        Storage storage $,
        uint48 _offset,
        uint48 _maxCheckpointHistory
    )
        public
        view
        returns (ICheckpointStore.Checkpoint memory)
    {
        (uint48 stackTop, uint48 stackSize) = ($.stackTop, $.stackSize);

        require(_offset < stackSize, IndexOutOfBounds());

        unchecked {
            // Calculate the slot position for the requested offset:
            // - offset 0 = most recent block (at stackTop)
            // - offset 1 = second most recent block
            // - etc.
            uint48 slot;
            if (stackTop >= _offset) {
                // Simple case: we can subtract directly
                slot = stackTop - _offset;
            } else {
                // Wrap-around case: when offset goes past index 0
                // Example: if stackTop=1 and _offset=3, we need slot=(5+1-3)=3
                // This correctly wraps to the end of the ring buffer
                slot = _maxCheckpointHistory + stackTop - _offset;
            }

            return $.checkpoints[slot];
        }
    }

    /// @notice Gets the latest checkpoint number
    /// @param $ The storage struct
    /// @return _ The latest checkpoint number
    function getLatestCheckpointBlockNumber(Storage storage $) public view returns (uint48) {
        return $.latestCheckpointBlockNumber;
    }

    /// @notice Gets the number of checkpoints
    /// @param $ The storage struct
    /// @return _ The number of checkpoints
    function getNumberOfCheckpoints(Storage storage $) public view returns (uint48) {
        return $.stackSize;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error IndexOutOfBounds();
    error InvalidCheckpoint();
    error InvalidMaxCheckpointHistory();
}
