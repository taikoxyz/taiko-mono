// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "../iface/ICheckpointStore.sol";

/// @title LibCheckpointStore
/// @notice Library for managing synced L1 or L2 checkpoints
/// @custom:security-contact security@taiko.xyz
library LibCheckpointStore {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Storage for checkpoints
    struct Storage {
        /// @notice Maps block number to checkpoint data
        mapping(uint48 blockNumber => ICheckpointStore.Checkpoint checkpoint) checkpoints;
        /// @notice The latest checkpoint number
        uint48 latestCheckpointBlockNumber;
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Saves a new checkpoint
    /// @param $ The storage struct
    /// @param _checkpoint The checkpoint to save
    function saveCheckpoint(
        Storage storage $,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        internal
    {
        require(_checkpoint.stateRoot != bytes32(0), InvalidCheckpoint());
        require(_checkpoint.blockHash != bytes32(0), InvalidCheckpoint());
        require(_checkpoint.blockNumber > $.latestCheckpointBlockNumber, InvalidCheckpoint());

        $.checkpoints[_checkpoint.blockNumber] = _checkpoint;
        $.latestCheckpointBlockNumber = _checkpoint.blockNumber;

        emit ICheckpointStore.CheckpointSaved(
            _checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot
        );
    }

    /// @notice Gets a checkpoint by block number
    /// @param $ The storage struct
    /// @param _blockNumber The block number of the checkpoint
    /// @return checkpoint The checkpoint
    function getCheckpoint(
        Storage storage $,
        uint48 _blockNumber
    )
        internal
        view
        returns (ICheckpointStore.Checkpoint memory checkpoint)
    {
        checkpoint = $.checkpoints[_blockNumber];
        require(checkpoint.blockNumber == _blockNumber, CheckpointNotFound());
    }

    /// @notice Gets the latest checkpoint number
    /// @param $ The storage struct
    /// @return _ The latest checkpoint number
    function getLatestCheckpointBlockNumber(Storage storage $) internal view returns (uint48) {
        return $.latestCheckpointBlockNumber;
    }


    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidCheckpoint();
    error CheckpointNotFound();
}
