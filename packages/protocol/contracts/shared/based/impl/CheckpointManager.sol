// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointManager } from "../iface/ICheckpointManager.sol";

/// @title CheckpointManager
/// @notice Contract for managing synced L2 checkpoints using a ring buffer
/// @dev This contract implements a ring buffer to store the most recent checkpoints.
/// When the buffer is full, new blocks overwrite the oldest entries. The contract
/// ensures blocks are saved in strictly increasing order by block number.
/// @custom:security-contact security@taiko.xyz
contract CheckpointManager is EssentialContract, ICheckpointManager {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The address of the authorized contract that can update the checkpoint
    address public immutable authorized;

    /// @notice The number of checkpoints to keep in the ring buffer
    uint48 public immutable maxStackSize;

    /// @notice The latest checkpoint number
    uint48 private _latestCheckpointNumber;

    /// @notice The current top of the stack (ring buffer index)
    uint48 private _stackTop;

    /// @notice The current number of items in the stack
    uint48 private _stackSize;

    /// @notice Ring buffer as a stack for storing checkpoints
    /// @dev Maps slot indices (0 to maxStackSize-1) to checkpoint data
    mapping(uint48 slot => Checkpoint checkpoint) private _checkpoints;

    uint256[48] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initializer
    // ---------------------------------------------------------------

    /// @notice Initializes the CheckpointManager with the authorized address and ring buffer size
    /// @param _authorized The address of the authorized contract. On L1, this shall be the inbox,
    /// on L2, this shall be the anchor transactor.
    /// @param _maxStackSize The size of the ring buffer
    constructor(address _authorized, uint48 _maxStackSize) {
        require(_authorized != address(0), InvalidAddress());
        require(_maxStackSize != 0, InvalidMaxStackSize());

        authorized = _authorized;
        maxStackSize = _maxStackSize;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICheckpointManager
    function saveCheckpoint(Checkpoint calldata _checkpoint) external onlyFrom(authorized) {
        // Validate all fields
        require(_checkpoint.stateRoot != 0, InvalidCheckpoint());
        require(_checkpoint.blockHash != 0, InvalidCheckpoint());
        require(_checkpoint.blockNumber > _latestCheckpointNumber, InvalidCheckpoint());

        unchecked {
            // Ring buffer implementation:
            // - _stackTop starts at 0 and cycles through 0 to (maxStackSize-1)
            // - When we reach maxStackSize, it wraps back to 0
            // - This ensures we always overwrite the oldest entry when buffer is full
            _stackTop = (_stackTop + 1) % maxStackSize;
            _checkpoints[_stackTop] = _checkpoint;

            // Update stack size (capped at maxStackSize)
            if (_stackSize < maxStackSize) {
                ++_stackSize;
            }
        }
        _latestCheckpointNumber = _checkpoint.blockNumber;

        emit CheckpointSaved(_checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot);
    }

    /// @inheritdoc ICheckpointManager
    function getCheckpoint(uint48 _offset) external view returns (Checkpoint memory) {
        require(_stackSize != 0, NoCheckpoints());
        require(_offset < _stackSize, IndexOutOfBounds());

        unchecked {
            // Calculate the slot position for the requested offset:
            // - offset 0 = most recent block (at _stackTop)
            // - offset 1 = second most recent block
            // - etc.
            uint48 slot;
            if (_stackTop >= _offset) {
                // Simple case: we can subtract directly
                slot = _stackTop - _offset;
            } else {
                // Wrap-around case: when offset goes past index 0
                // Example: if _stackTop=1 and _offset=3, we need slot=(5+1-3)=3
                // This correctly wraps to the end of the ring buffer
                slot = maxStackSize + _stackTop - _offset;
            }

            return _checkpoints[slot];
        }
    }

    /// @inheritdoc ICheckpointManager
    function getLatestCheckpointNumber() external view returns (uint48) {
        return _latestCheckpointNumber;
    }

    /// @inheritdoc ICheckpointManager
    function getNumberOfCheckpoints() external view returns (uint48) {
        return _stackSize;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error IndexOutOfBounds();
    error InvalidAddress();
    error InvalidMaxStackSize();
    error InvalidCheckpoint();
    error NoCheckpoints();
}
