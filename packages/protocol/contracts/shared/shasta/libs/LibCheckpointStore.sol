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

    /// @notice Storage-optimized checkpoint record with only persisted fields
    struct CheckpointRecord {
        /// @notice The block hash for the end (last) block in this proposal.
        bytes32 blockHash;
        /// @notice The state root for the end (last) block in this proposal.
        bytes32 stateRoot;
    }

    /// @notice Storage for checkpoints
    struct Storage {
        /// @notice Maps block number to checkpoint data
        mapping(uint48 blockNumber => CheckpointRecord checkpoint) checkpoints;
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

        $.checkpoints[_checkpoint.blockNumber] =
            CheckpointRecord({ blockHash: _checkpoint.blockHash, stateRoot: _checkpoint.stateRoot });

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
        CheckpointRecord storage record = $.checkpoints[_blockNumber];
        if (record.blockHash == bytes32(0)) revert CheckpointNotFound();

        checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber,
            blockHash: record.blockHash,
            stateRoot: record.stateRoot
        });
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidCheckpoint();
    error CheckpointNotFound();
}
