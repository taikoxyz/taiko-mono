// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICheckpointManager
/// @notice Interface for managing checkpoints
/// @custom:security-contact security@taiko.xyz
interface ICheckpointManager {
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

    /// @notice Saves a new checkpoint
    /// @param _checkpoint The checkpoint to save
    function saveCheckpoint(Checkpoint calldata _checkpoint) external;

    /// @notice Gets a checkpoint by index
    /// @param _offset The offset of the checkpoint. Use 0 for the last checkpoint, 1 for the
    /// second last, etc.
    /// @return blockNumber_ The block number
    /// @return blockHash_ The block hash
    /// @return stateRoot_ The state root
    function getCheckpoint(uint48 _offset)
        external
        view
        returns (uint48 blockNumber_, bytes32 blockHash_, bytes32 stateRoot_);

    /// @notice Gets the latest checkpoint number
    /// @return _ The latest checkpoint number
    function getLatestCheckpointNumber() external view returns (uint48);

    /// @notice Gets the number of checkpoints
    /// @return _ The number of checkpoints
    function getNumberOfCheckpoints() external view returns (uint48);
}
