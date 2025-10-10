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
        /// @notice The block number associated with the checkpoint.
        uint48 blockNumber;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 blockHash;
        /// @notice The state root for the end (last) L2 block in this proposal.
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

    /// @notice Saves a checkpoint
    /// @param _checkpoint The checkpoint data to persist
    function saveCheckpoint(Checkpoint calldata _checkpoint) external;

    /// @notice Gets a checkpoint by its block number
    /// @param _blockNumber The block number associated with the checkpoint
    /// @return _ The checkpoint
    function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory);
}
