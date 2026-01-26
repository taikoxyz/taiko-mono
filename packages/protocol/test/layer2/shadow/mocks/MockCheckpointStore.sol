// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICheckpointStore} from "src/shared/signal/ICheckpointStore.sol";

contract MockCheckpointStore is ICheckpointStore {
    mapping(uint48 _blockNumber => Checkpoint _checkpoint) private _checkpoints;

    function setCheckpoint(uint48 _blockNumber, bytes32 _blockHash, bytes32 _stateRoot) external {
        _checkpoints[_blockNumber] = Checkpoint({
            blockNumber: _blockNumber,
            blockHash: _blockHash,
            stateRoot: _stateRoot
        });
    }

    function saveCheckpoint(Checkpoint calldata _checkpoint) external {
        _checkpoints[_checkpoint.blockNumber] = _checkpoint;
    }

    function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory) {
        return _checkpoints[_blockNumber];
    }
}
