// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISyncedBlockManager } from "../iface/ISyncedBlockManager.sol";

/// @title SyncedBlockManager
/// @notice Contract for managing synced L2 blocks using a ring buffer
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
        // Validate all fields in one check to save gas
        if (_syncedBlock.stateRoot == 0) revert InvalidSyncedBlock();
        if (_syncedBlock.blockHash == 0) revert InvalidSyncedBlock();
        if (_syncedBlock.blockNumber <= _latestSyncedBlockNumber) revert InvalidSyncedBlock();

        unchecked {
            // Push to the top of the stack (next position in ring buffer)
            _stackTop = (_stackTop + 1) % maxStackSize;
            _syncedBlocks[_stackTop] = _syncedBlock;

            // Update stack size
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
            uint48 slot;
            if (_stackTop >= _offset) {
                slot = _stackTop - _offset;
            } else {
                // Wrap around to the end of the ring buffer
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
