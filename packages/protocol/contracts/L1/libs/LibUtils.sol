// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibEthDepositing } from "./LibEthDepositing.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { TaikoData } from "../TaikoData.sol";

library LibUtils {
    using LibMath for uint256;

    error L1_BLOCK_ID();

    function getL2ChainData(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId
    )
        internal
        view
        returns (bool found, TaikoData.Block storage blk)
    {
        checkBlockId(state, blockId);

        uint64 id = blockId == 0 ? state.slotB.lastVerifiedBlockId : blockId;
        blk = state.blocks[id % config.blockRingBufferSize];
        found = blk.verifiedForkChoiceId != 0;
    }

    function checkBlockId(
        TaikoData.State storage state,
        uint64 blockId
    )
        internal
        view
    {
        if (
            blockId <= state.slotB.lastVerifiedBlockId
                || blockId >= state.slotB.numBlocks
        ) {
            revert L1_BLOCK_ID();
        }
    }

    function getForkChoiceId(
        TaikoData.State storage state,
        TaikoData.Block storage blk,
        uint64 blockId,
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        internal
        view
        returns (uint16 fcId)
    {
        if (
            blk.forkChoices[1].key
                == keyForForkChoice(parentHash, parentGasUsed)
        ) {
            fcId = 1;
        } else {
            fcId = state.forkChoiceIds[blockId][parentHash][parentGasUsed];
        }

        if (fcId >= blk.nextForkChoiceId) {
            fcId = 0;
        }
    }

    function getStateVariables(TaikoData.State storage state)
        internal
        view
        returns (TaikoData.StateVariables memory)
    {
        TaikoData.SlotA memory slotA = state.slotA;
        TaikoData.SlotB memory slotB = state.slotB;

        return TaikoData.StateVariables({
            genesisHeight: slotA.genesisHeight,
            genesisTimestamp: slotA.genesisTimestamp,
            numBlocks: slotB.numBlocks,
            lastVerifiedBlockId: slotB.lastVerifiedBlockId,
            nextEthDepositToProcess: slotA.nextEthDepositToProcess,
            numEthDeposits: slotA.numEthDeposits - slotA.nextEthDepositToProcess
        });
    }

    /// @dev Hashing the block metadata.
    function hashMetadata(TaikoData.BlockMetadata memory meta)
        internal
        pure
        returns (bytes32 hash)
    {
        uint256[6] memory inputs;

        inputs[0] = (uint256(meta.id) << 192) | (uint256(meta.timestamp) << 128)
            | (uint256(meta.l1Height) << 64);

        inputs[1] = uint256(meta.l1Hash);
        inputs[2] = uint256(meta.mixHash);
        inputs[3] =
            uint256(LibEthDepositing.hashEthDeposits(meta.depositsProcessed));
        inputs[4] = uint256(meta.txListHash);

        inputs[5] = (uint256(meta.txListByteStart) << 232)
            | (uint256(meta.txListByteEnd) << 208) //
            | (uint256(meta.gasLimit) << 176)
            | (uint256(uint160(meta.beneficiary)) << 16);

        assembly {
            hash := keccak256(inputs, mul(6, 32))
        }
    }

    function keyForForkChoice(
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        internal
        pure
        returns (bytes32 key)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, parentGasUsed)
            mstore(add(ptr, 32), parentHash)
            key := keccak256(add(ptr, 28), 36)
            mstore(0x40, add(ptr, 64))
        }
    }

    function getVerifierName(uint16 id) internal pure returns (bytes32) {
        return bytes32(uint256(0x1000000) + id);
    }
}
