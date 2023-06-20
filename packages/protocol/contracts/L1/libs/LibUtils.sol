// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibMath } from "../../libs/LibMath.sol";
import { LibEthDepositing } from "./LibEthDepositing.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../TaikoData.sol";

library LibUtils {
    using LibMath for uint256;

    error L1_BLOCK_ID();

    function getL2ChainData(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId
    )
        internal
        view
        returns (bool found, TaikoData.Block storage blk)
    {
        uint256 id = blockId == 0 ? state.lastVerifiedBlockId : blockId;
        blk = state.blocks[id % config.ringBufferSize];
        found = (blk.blockId == id && blk.verifiedForkChoiceId != 0);
    }

    function getForkChoiceId(
        TaikoData.State storage state,
        TaikoData.Block storage blk,
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        internal
        view
        returns (uint256 fcId)
    {
        if (
            blk.forkChoices[1].key
                == keyForForkChoice(parentHash, parentGasUsed)
        ) {
            fcId = 1;
        } else {
            fcId = state.forkChoiceIds[blk.blockId][parentHash][parentGasUsed];
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
        return TaikoData.StateVariables({
            blockFee: state.blockFee,
            genesisHeight: state.genesisHeight,
            genesisTimestamp: state.genesisTimestamp,
            numBlocks: state.numBlocks,
            lastVerifiedBlockId: state.lastVerifiedBlockId,
            nextEthDepositToProcess: state.nextEthDepositToProcess,
            numEthDeposits: state.numEthDeposits - state.nextEthDepositToProcess
        });
    }

    function movingAverage(
        uint256 maValue,
        uint256 newValue,
        uint256 maf
    )
        internal
        pure
        returns (uint256)
    {
        if (maValue == 0) {
            return newValue;
        }
        uint256 _ma = (maValue * (maf - 1) + newValue) / maf;
        return _ma > 0 ? _ma : maValue;
    }

    /// @dev Hashing the block metadata.
    function hashMetadata(TaikoData.BlockMetadata memory meta)
        internal
        pure
        returns (bytes32 hash)
    {
        uint256[7] memory inputs;

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

        inputs[6] = (uint256(uint160(meta.treasury)) << 96);

        assembly {
            hash := keccak256(inputs, mul(7, 32))
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
