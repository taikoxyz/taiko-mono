// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title LibUtils
/// @custom:security-contact security@taiko.xyz
/// @notice A library that offers helper functions.
library LibUtils {
    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNEXPECTED_TRANSITION_ID();

    /// @dev Retrieves the transition with a given parentHash.
    /// This function will revert if the transition is not found.
    /// @param state Current TaikoData.State.
    /// @param config Actual TaikoData.Config.
    /// @param blockId Id of the block.
    /// @param parentHash Parent hash of the block.
    /// @return ts The state transition data of the block.
    function getTransition(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId,
        bytes32 parentHash
    )
        external
        view
        returns (TaikoData.TransitionState storage ts)
    {
        TaikoData.SlotB memory b = state.slotB;
        if (blockId < b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = getTransitionId(state, blk, slot, parentHash);
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        ts = state.transitions[slot][tid];
    }

    /// @dev Retrieves a block based on its ID.
    /// @param state Current TaikoData.State.
    /// @param config Actual TaikoData.Config.
    /// @param blockId Id of the block.
    function getBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId
    )
        external
        view
        returns (TaikoData.Block storage blk, uint64 slot)
    {
        slot = blockId % config.blockRingBufferSize;
        blk = state.blocks[slot];
        if (blk.blockId != blockId) {
            revert L1_INVALID_BLOCK_ID();
        }
    }

    /// @dev Retrieves the ID of the transition with a given parentHash.
    /// This function will return 0 if the transtion is not found.
    function getTransitionId(
        TaikoData.State storage state,
        TaikoData.Block storage blk,
        uint64 slot,
        bytes32 parentHash
    )
        internal
        view
        returns (uint32 tid)
    {
        if (state.transitions[slot][1].key == parentHash) {
            tid = 1;
        } else {
            tid = state.transitionIds[blk.blockId][parentHash];
        }

        if (tid >= blk.nextTransitionId) revert L1_UNEXPECTED_TRANSITION_ID();
    }
}
