// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/ITaikoInbox.sol";

/// @title LibWriteTransition
/// @dev This library's writeTransition function is made public to reduce HeklaInbox's code size.
/// @custom:security-contact security@taiko.xyz
library LibWriteTransition {
    error InvalidParams();

    /// @notice Emitted when a transition is written to the state by the owner.
    /// @param batchId The ID of the batch containing the transition.
    /// @param tid The ID of the transition within the batch.
    /// @param ts The transition state written.
    event TransitionWritten(uint64 batchId, uint24 tid, ITaikoInbox.TransitionState ts);

    /// @dev This function is supposed to be used by the owner to force prove a transition for a
    /// block that has not been verified.
    function writeTransition(
        ITaikoInbox.State storage _state,
        ITaikoInbox.Config memory _config,
        uint64 _batchId,
        bytes32 _parentHash,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        address _prover,
        bool _inProvingWindow
    )
        public // reduce code size
    {
        require(_blockHash != 0, InvalidParams());
        require(_parentHash != 0, InvalidParams());
        require(_stateRoot != 0, InvalidParams());
        require(_batchId > _state.stats2.lastVerifiedBatchId, InvalidParams());

        uint256 slot = _batchId % _config.batchRingBufferSize;
        ITaikoInbox.Batch storage batch = _state.batches[slot];
        require(batch.batchId == _batchId, InvalidParams());

        uint24 tid = _state.transitionIds[_batchId][_parentHash];
        if (tid == 0) {
            tid = batch.nextTransitionId++;
        }

        ITaikoInbox.TransitionState storage ts = _state.transitions[slot][tid];
        ts.stateRoot = _batchId % _config.stateRootSyncInternal == 0 ? _stateRoot : bytes32(0);
        ts.blockHash = _blockHash;
        ts.prover = _prover;
        ts.inProvingWindow = _inProvingWindow;
        ts.createdAt = uint48(block.timestamp);

        if (tid == 1) {
            ts.parentHash = _parentHash;
        } else {
            _state.transitionIds[_batchId][_parentHash] = tid;
        }

        emit TransitionWritten(
            _batchId,
            tid,
            ITaikoInbox.TransitionState(
                _parentHash,
                _blockHash,
                _stateRoot,
                _prover,
                _inProvingWindow,
                uint48(block.timestamp)
            )
        );
    }
}
