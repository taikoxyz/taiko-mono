// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISyncedBlockManager } from "../iface/ISyncedBlockManager.sol";

/// @title SyncedBlockManager
/// @notice Contract for managing synced L2 blocks using a ring buffer
/// @dev This contract implements a ring buffer to store the most recent synced blocks.
/// When the buffer is full, new blocks overwrite the oldest entries. The contract
/// ensures blocks are saved in strictly increasing order by block number.
/// @custom:security-contact security@taiko.xyz
contract SyncedBlockManager is ISyncedBlockManager {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice The address of the authorized contract that can update the synced block
    address public immutable authorized;

    /// @notice The number of synced blocks to keep in the ring buffer
    uint48 public immutable maxStackSize;

    /// @notice The latest synced block number
    uint48 private _latestSyncedBlockNumber;

    /// @notice The current top of the stack (ring buffer index)
    uint48 private _stackTop;

    /// @notice The current number of items in the stack
    uint48 private _stackSize;

    /// @notice Ring buffer as a stack for storing synced blocks
    /// @dev Maps slot indices (0 to maxStackSize-1) to synced block data
    mapping(uint48 slot => SyncedBlock syncedBlock) private _syncedBlocks;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @notice Ensures only the authorized contract can call the function
    modifier onlyAuthorized() {
        if (msg.sender != authorized) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Initializes the SyncedBlockManager with the authorized address and ring buffer size
    /// @param _authorized The address of the authorized contract. On L1, this shall be the inbox,
    /// on L2, this shall be the anchor transactor.
    /// @param _maxStackSize The size of the ring buffer
    constructor(address _authorized, uint48 _maxStackSize) {
        if (_authorized == address(0)) revert InvalidAddress();
        if (_maxStackSize == 0) revert InvalidMaxStackSize();

        authorized = _authorized;
        maxStackSize = _maxStackSize;
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc ISyncedBlockManager
    function saveSyncedBlock(SyncedBlock calldata _syncedBlock) external onlyAuthorized {
        // Validate all fields in a single check to save gas
        if (
            _syncedBlock.stateRoot == 0 || _syncedBlock.blockHash == 0
                || _syncedBlock.blockNumber <= _latestSyncedBlockNumber
        ) {
            revert InvalidSyncedBlock();
        }

        unchecked {
            // Ring buffer implementation:
            // - _stackTop starts at 0 and cycles through 0 to (maxStackSize-1)
            // - When we reach maxStackSize, it wraps back to 0
            // - This ensures we always overwrite the oldest entry when buffer is full
            _stackTop = (_stackTop + 1) % maxStackSize;
            _syncedBlocks[_stackTop] = _syncedBlock;

            // Update stack size (capped at maxStackSize)
            if (_stackSize < maxStackSize) {
                ++_stackSize;
            }
        }
        _latestSyncedBlockNumber = _syncedBlock.blockNumber;

        emit SyncedBlockSaved(
            _syncedBlock.blockNumber, _syncedBlock.blockHash, _syncedBlock.stateRoot
        );
    }

    /// @inheritdoc ISyncedBlockManager
    function getSyncedBlock(uint48 _offset)
        external
        view
        returns (SyncedBlock memory syncedBlock_)
    {
        if (_stackSize == 0) revert NoSyncedBlocks();
        if (_offset >= _stackSize) revert IndexOutOfBounds();

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

            syncedBlock_ = _syncedBlocks[slot];
        }
    }

    /// @inheritdoc ISyncedBlockManager
    function getLatestSyncedBlockNumber() external view returns (uint48) {
        return _latestSyncedBlockNumber;
    }

    /// @inheritdoc ISyncedBlockManager
    function getNumberOfSyncedBlocks() external view returns (uint48) {
        return _stackSize;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error IndexOutOfBounds();
    error InvalidAddress();
    error InvalidMaxStackSize();
    error InvalidSyncedBlock();
    error NoSyncedBlocks();
    error Unauthorized();
}
