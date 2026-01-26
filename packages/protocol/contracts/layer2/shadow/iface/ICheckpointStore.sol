// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title ICheckpointStore
/// @notice Interface for storing and retrieving checkpoints
/// @custom:security-contact security@taiko.xyz
interface ICheckpointStore {
    /// @notice Represents a synced checkpoint
    struct Checkpoint {
        /// @notice The block number associated with the checkpoint.
        uint48 blockNumber;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 blockHash;
        /// @notice The state root for the end (last) L2 block in this proposal.
        bytes32 stateRoot;
    }

    /// @notice Gets a checkpoint by its block number
    /// @param _blockNumber The block number associated with the checkpoint
    /// @return _ The checkpoint
    function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory);
}
