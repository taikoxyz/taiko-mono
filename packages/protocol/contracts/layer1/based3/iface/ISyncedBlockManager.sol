// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISyncedBlockManager
/// @notice Interface for managing synced L2 blocks
/// @custom:security-contact security@taiko.xyz
interface ISyncedBlockManager {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Represents a synced L2 block
    struct SyncedBlock {
        /// @notice The L2 block number
        uint48 blockNumber;
        /// @notice The L2 block hash
        bytes32 blockHash;
        /// @notice The L2 state root
        bytes32 stateRoot;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a synced block is updated
    /// @param blockNumber The L2 block number
    /// @param blockHash The L2 block hash
    /// @param stateRoot The L2 state root
    event SyncedBlockUpdated(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @notice Updates the synced block
    /// @param _syncedBlock The new synced block data
    function setSyncedBlock(SyncedBlock memory _syncedBlock) external;

    /// @notice Gets the current synced block
    /// @return syncedBlock_ The current synced block data
    function getSyncedBlock() external view returns (SyncedBlock memory syncedBlock_);

    /// @notice Gets the latest synced L2 block number
    /// @return The latest synced L2 block number
    function getLatestSyncedBlockNumber() external view returns (uint48);

    /// @notice Gets the latest synced L2 block hash
    /// @return The latest synced L2 block hash
    function getLatestSyncedBlockHash() external view returns (bytes32);

    /// @notice Gets the latest synced L2 state root
    /// @return The latest synced L2 state root
    function getLatestSyncedStateRoot() external view returns (bytes32);
}
