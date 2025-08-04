// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISyncedBlockManager } from "../iface/ISyncedBlockManager.sol";

/// @title SyncedBlockManager
/// @notice Contract for managing synced L2 blocks
/// @custom:security-contact security@taiko.xyz
contract SyncedBlockManager is ISyncedBlockManager {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice The address of the inbox contract that can update the synced block
    address public immutable inbox;

    /// @notice The current synced L2 block information
    SyncedBlock private _syncedBlock;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @notice Ensures only the inbox contract can call the function.
    modifier onlyInbox() {
        if (msg.sender != inbox) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(address _inbox) {
        inbox = _inbox;
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc ISyncedBlockManager
    function setSyncedBlock(SyncedBlock calldata _newSyncedBlock) external onlyInbox {
        if (_newSyncedBlock.blockNumber <= _syncedBlock.blockNumber) return;
        if (_newSyncedBlock.stateRoot == 0) return;

        _syncedBlock = _newSyncedBlock;
        emit SyncedBlockUpdated(
            _newSyncedBlock.blockNumber, _newSyncedBlock.blockHash, _newSyncedBlock.stateRoot
        );
    }

    /// @inheritdoc ISyncedBlockManager
    function getSyncedBlock() external view returns (SyncedBlock memory syncedBlock_) {
        syncedBlock_ = _syncedBlock;
    }

    /// @inheritdoc ISyncedBlockManager
    function getLatestSyncedBlockNumber() external view returns (uint48) {
        return _syncedBlock.blockNumber;
    }

    /// @inheritdoc ISyncedBlockManager
    function getLatestSyncedBlockHash() external view returns (bytes32) {
        return _syncedBlock.blockHash;
    }

    /// @inheritdoc ISyncedBlockManager
    function getLatestSyncedStateRoot() external view returns (bytes32) {
        return _syncedBlock.stateRoot;
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Virtual
    // -------------------------------------------------------------------------

    /// @dev Checks if the caller is authorized to update the synced block
    /// @dev This should be overridden in inheriting contracts to implement proper access control
    function _checkAuthorized() internal view virtual {
        // Default implementation - override in inheriting contracts
        // For example, check if msg.sender is the Inbox contract
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error Unauthorized();
    error InvalidSyncedBlock();
}
