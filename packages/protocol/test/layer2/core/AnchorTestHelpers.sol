// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract MockCheckpointStore is ICheckpointStore {
    mapping(uint48 blockNumber => Checkpoint checkpoint) private _checkpoints;

    function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
        _checkpoints[_checkpoint.blockNumber] = _checkpoint;
    }

    function getCheckpoint(uint48 _blockNumber)
        external
        view
        override
        returns (Checkpoint memory)
    {
        return _checkpoints[_blockNumber];
    }
}
