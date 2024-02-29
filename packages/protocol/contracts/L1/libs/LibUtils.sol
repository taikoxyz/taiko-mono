// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title LibUtils
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibUtils {
    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNEXPECTED_TRANSITION_ID();

    /// @notice This function will revert if the transition is not found.
    /// @dev Retrieves the transition with a given parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    /// @param _parentHash Parent hash of the block.
    /// @return The state transition data of the block.
    function getTransition(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId,
        bytes32 _parentHash
    )
        external
        view
        returns (TaikoData.TransitionState storage)
    {
        TaikoData.SlotB memory b = _state.slotB;
        if (_blockId < b.lastVerifiedBlockId || _blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = _blockId % _config.blockRingBufferSize;
        TaikoData.Block storage blk = _state.blocks[slot];
        if (blk.blockId != _blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = getTransitionId(_state, blk, slot, _parentHash);
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        return _state.transitions[slot][tid];
    }

    /// @dev Retrieves a block based on its ID.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    function getBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId
    )
        external
        view
        returns (TaikoData.Block storage blk_, uint64 slot_)
    {
        slot_ = _blockId % _config.blockRingBufferSize;
        blk_ = _state.blocks[slot_];
        if (blk_.blockId != _blockId) {
            revert L1_INVALID_BLOCK_ID();
        }
    }

    /// @dev Retrieves the ID of the transition with a given parentHash.
    /// This function will return 0 if the transition is not found.
    function getTransitionId(
        TaikoData.State storage _state,
        TaikoData.Block storage _blk,
        uint64 _slot,
        bytes32 _parentHash
    )
        internal
        view
        returns (uint32 tid_)
    {
        if (_state.transitions[_slot][1].key == _parentHash) {
            tid_ = 1;
        } else {
            tid_ = _state.transitionIds[_blk.blockId][_parentHash];
        }

        if (tid_ >= _blk.nextTransitionId) revert L1_UNEXPECTED_TRANSITION_ID();
    }
}
