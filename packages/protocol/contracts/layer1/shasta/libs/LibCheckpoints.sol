// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibCheckpoints
/// @notice Library for managing synced L2 checkpoints using a ring buffer
/// @dev This library implements a ring buffer to store the most recent checkpoints.
/// When the buffer is full, new blocks overwrite the oldest entries. The library
/// ensures blocks are saved in strictly increasing order by block number.
/// @custom:security-contact security@taiko.xyz
library LibCheckpoints {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a synced lock
    struct Checkpoint {
        uint48 blockNumber;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 blockHash;
        /// @notice The state root for the end (last) L2 block in this proposal.
        bytes32 stateRoot;
    }

    /// @notice Storage for the checkpoint ring buffer
    struct Storage {
        /// @notice The number of checkpoints to keep in the ring buffer
        uint48 maxStackSize;
        /// @notice The latest checkpoint number
        uint48 latestCheckpointNumber;
        /// @notice The current top of the stack (ring buffer index)
        uint48 stackTop;
        /// @notice The current number of items in the stack
        uint48 stackSize;
        /// @notice Ring buffer as a stack for storing checkpoints
        /// @dev Maps slot indices (0 to maxStackSize-1) to checkpoint data
        mapping(uint48 slot => Checkpoint checkpoint) checkpoints;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a checkpoint is saved
    /// @param blockNumber The block number
    /// @param blockHash The block hash
    /// @param stateRoot The state root
    event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the checkpoint storage
    /// @param $ The storage struct
    /// @param _maxStackSize The size of the ring buffer
    function init(Storage storage $, uint48 _maxStackSize) public {
        require(_maxStackSize != 0, InvalidMaxStackSize());
        $.maxStackSize = _maxStackSize;
    }

    /// @notice Saves a new checkpoint
    /// @param $ The storage struct
    /// @param _checkpoint The checkpoint to save
    function saveCheckpoint(Storage storage $, Checkpoint calldata _checkpoint) public {
        // Validate all fields
        require(_checkpoint.stateRoot != 0, InvalidCheckpoint());
        require(_checkpoint.blockHash != 0, InvalidCheckpoint());
        require(_checkpoint.blockNumber > $.latestCheckpointNumber, InvalidCheckpoint());

        unchecked {
            // Ring buffer implementation:
            // - stackTop starts at 0 and cycles through 0 to (maxStackSize-1)
            // - When we reach maxStackSize, it wraps back to 0
            // - This ensures we always overwrite the oldest entry when buffer is full
            $.stackTop = ($.stackTop + 1) % $.maxStackSize;
            $.checkpoints[$.stackTop] = _checkpoint;

            // Update stack size (capped at maxStackSize)
            if ($.stackSize < $.maxStackSize) {
                ++$.stackSize;
            }
        }
        $.latestCheckpointNumber = _checkpoint.blockNumber;

        emit CheckpointSaved(_checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot);
    }

    /// @notice Gets a checkpoint by index
    /// @param $ The storage struct
    /// @param _offset The offset of the checkpoint. Use 0 for the last checkpoint, 1 for the
    /// second last, etc.
    /// @return _ The checkpoint
    function getCheckpoint(Storage storage $, uint48 _offset) public view returns (Checkpoint memory) {
        require($.stackSize != 0, NoCheckpoints());
        require(_offset < $.stackSize, IndexOutOfBounds());

        unchecked {
            // Calculate the slot position for the requested offset:
            // - offset 0 = most recent block (at stackTop)
            // - offset 1 = second most recent block
            // - etc.
            uint48 slot;
            if ($.stackTop >= _offset) {
                // Simple case: we can subtract directly
                slot = $.stackTop - _offset;
            } else {
                // Wrap-around case: when offset goes past index 0
                // Example: if stackTop=1 and _offset=3, we need slot=(5+1-3)=3
                // This correctly wraps to the end of the ring buffer
                slot = $.maxStackSize + $.stackTop - _offset;
            }

            return $.checkpoints[slot];
        }
    }

    /// @notice Gets the latest checkpoint number
    /// @param $ The storage struct
    /// @return _ The latest checkpoint number
    function getLatestCheckpointNumber(Storage storage $) public view returns (uint48) {
        return $.latestCheckpointNumber;
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
    error InvalidMaxStackSize();
    error InvalidCheckpoint();
    error NoCheckpoints();
}