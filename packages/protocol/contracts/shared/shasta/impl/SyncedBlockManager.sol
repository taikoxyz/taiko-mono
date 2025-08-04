// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISyncedBlockManager } from "../iface/ISyncedBlockManager.sol";

/// @title SyncedBlockManager
/// @notice Contract for managing synced L2 blocks
/// @custom:security-contact security@taiko.xyz
/// TODOs:
/// - [ ] use a ring buffer so previously synecd blocks can be used in merkle proofs.
contract SyncedBlockManager is ISyncedBlockManager {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice The address of the authorized contract that can update the synced block
    address public immutable authorized;

    /// @notice The current synced L2 block information
    SyncedBlock private _syncedBlock;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @notice Ensures only the inbox contract can call the function.
    modifier onlyAuthorized() {
        if (msg.sender != authorized) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Initializes the SyncedBlockManager with the authorized address
    /// @param _authorized The address of the authorized contract. On L1, this shall be the inbox, on L2, this shall be the anchor transactor.
    constructor(address _authorized) {
        authorized = _authorized;
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc ISyncedBlockManager
    function setSyncedBlock(SyncedBlock calldata _newSyncedBlock) external onlyAuthorized {
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
    // Errors
    // -------------------------------------------------------------------------

    error InvalidSyncedBlock();
    error Unauthorized();
}
