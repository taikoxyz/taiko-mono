// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibCheckpoints } from "src/layer1/shasta/libs/LibCheckpoints.sol";

/// @title ICheckpointProvider
/// @notice Interface for providing checkpoints
/// @custom:security-contact security@taiko.xyz
interface ICheckpointProvider {
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
    function saveCheckpoint(LibCheckpoints.Checkpoint calldata _checkpoint) external;

    /// @notice Gets a checkpoint by index
    /// @param _offset The offset of the checkpoint. Use 0 for the last checkpoint, 1 for the
    /// second last, etc.
    /// @return _ The checkpoint
    function getCheckpoint(uint48 _offset) external view returns (LibCheckpoints.Checkpoint memory);

    /// @notice Gets the latest checkpoint number
    /// @return _ The latest checkpoint number
    function getLatestCheckpointNumber() external view returns (uint48);

    /// @notice Gets the number of checkpoints
    /// @return _ The number of checkpoints
    function getNumberOfCheckpoints() external view returns (uint48);
}