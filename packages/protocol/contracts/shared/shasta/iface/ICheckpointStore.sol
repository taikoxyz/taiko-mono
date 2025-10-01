// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICheckpointStore
/// @notice Interface for storing and retrieving checkpoints
/// @custom:security-contact security@taiko.xyz
interface ICheckpointStore {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a synced checkpoint
    struct Checkpoint {
        uint48 blockNumber;
        /// @notice The block hash for the end (last) block in this proposal.
        bytes32 blockHash;
        /// @notice The state root for the end (last) block in this proposal.
        bytes32 stateRoot;
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
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Gets a checkpoint by index
    /// @param _offset The offset of the checkpoint. Use 0 for the last checkpoint, 1 for the
    /// second last, etc.
    /// @return _ The checkpoint
    function getCheckpoint(uint48 _offset) external view returns (Checkpoint memory);

    /// @notice Gets the latest checkpoint number
    /// @return _ The latest checkpoint number
    function getLatestCheckpointBlockNumber() external view returns (uint48);

    /// @notice Gets the number of checkpoints
    /// @return _ The number of checkpoints
    function getNumberOfCheckpoints() external view returns (uint48);
}
