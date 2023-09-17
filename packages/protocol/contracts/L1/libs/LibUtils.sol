// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibDepositing } from "./LibDepositing.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { TaikoData } from "../TaikoData.sol";

library LibUtils {
    using LibMath for uint256;

    address internal constant PLACEHOLDER_ADDR = address(1);

    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_TRANSITION_NOT_FOUND();

    function getBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId
    )
        internal
        view
        returns (TaikoData.Block storage blk)
    {
        blk = state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) {
            revert L1_INVALID_BLOCK_ID();
        }
    }

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

        assert(tid < blk.nextTransitionId);
    }

    function getTransition(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId,
        bytes32 parentHash
    )
        internal
        view
        returns (TaikoData.Transition storage tran)
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

        tran = state.transitions[slot][tid];
    }

    function getVerifyingTransition(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId
    )
        internal
        view
        returns (TaikoData.Transition memory transition)
    {
        uint64 id = blockId == 0 ? state.slotB.lastVerifiedBlockId : blockId;
        uint64 slot = id % config.blockRingBufferSize;

        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId == id) {
            transition = state.transitions[slot][blk.verifiedTransitionId];
        }
    }

    function getStateVariables(TaikoData.State storage state)
        internal
        view
        returns (TaikoData.StateVariables memory)
    {
        TaikoData.SlotA memory a = state.slotA;
        TaikoData.SlotB memory b = state.slotB;

        return TaikoData.StateVariables({
            genesisHeight: a.genesisHeight,
            genesisTimestamp: a.genesisTimestamp,
            numBlocks: b.numBlocks,
            lastVerifiedBlockId: b.lastVerifiedBlockId,
            nextEthDepositToProcess: a.nextEthDepositToProcess,
            numEthDeposits: a.numEthDeposits - a.nextEthDepositToProcess
        });
    }
}
