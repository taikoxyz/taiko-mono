// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISyncedBlockManager
/// @notice Interface for managing synced blocks
/// @custom:security-contact security@taiko.xyz
interface ISyncedBlockManager {
    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a synced block is saved
    /// @param blockNumber The block number
    /// @param blockHash The block hash
    /// @param stateRoot The state root
    event SyncedBlockSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Saves a new synced block
    /// @param _blockNumber The block number
    /// @param _blockHash The block hash
    /// @param _stateRoot The state root
    function saveSyncedBlock(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        external;

    /// @notice Gets a synced block by index
    /// @param _offset The offset of the synced block. Use 0 for the last synced block, 1 for the
    /// second last, etc.
    /// @return blockNumber_ The block number
    /// @return blockHash_ The block hash
    /// @return stateRoot_ The state root
    function getSyncedBlock(uint48 _offset)
        external
        view
        returns (uint48 blockNumber_, bytes32 blockHash_, bytes32 stateRoot_);

    /// @notice Gets the latest synced block number
    /// @return _ The latest synced block number
    function getLatestSyncedBlockNumber() external view returns (uint48);

    /// @notice Gets the number of synced blocks
    /// @return _ The number of synced blocks
    function getNumberOfSyncedBlocks() external view returns (uint48);
}
