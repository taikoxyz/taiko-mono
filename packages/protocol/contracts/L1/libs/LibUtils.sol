// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibMath} from "../../libs/LibMath.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibUtils {
    using LibMath for uint256;

    error L1_BLOCK_NUMBER();

    function getL2ChainData(
        TaikoData.State storage state,
        uint256 blockId,
        uint256 blockHashHistory
    ) internal view returns (TaikoData.ChainData storage chainData) {
        uint256 _blockId = blockId;
        if (_blockId == 0) {
            _blockId = state.lastBlockId;
        } else if (
            _blockId + blockHashHistory <= state.lastBlockId ||
            _blockId > state.lastBlockId
        ) revert L1_BLOCK_NUMBER();

        chainData = state.chainData[_blockId % blockHashHistory];
        if (chainData.blockId != blockId) revert L1_BLOCK_NUMBER();
    }

    function getStateVariables(
        TaikoData.State storage state
    ) internal view returns (TaikoData.StateVariables memory) {
        return
            TaikoData.StateVariables({
                feeBaseTwei: state.feeBaseTwei,
                genesisHeight: state.genesisHeight,
                genesisTimestamp: state.genesisTimestamp,
                nextBlockId: state.nextBlockId,
                lastProposedAt: state.lastProposedAt,
                avgBlockTime: state.avgBlockTime,
                lastBlockId: state.lastBlockId,
                avgProofTime: state.avgProofTime
            });
    }

    function movingAverage(
        uint256 maValue,
        uint256 newValue,
        uint256 maf
    ) internal pure returns (uint256) {
        if (maValue == 0) {
            return newValue;
        }
        uint256 _ma = (maValue * (maf - 1) + newValue) / maf;
        return _ma > 0 ? _ma : maValue;
    }

    function hashMetadata(
        TaikoData.BlockMetadata memory meta
    ) internal pure returns (bytes32 hash) {
        bytes32[5] memory inputs;
        inputs[0] =
            bytes32(uint256(meta.blockId) << 192) |
            bytes32(uint256(meta.gasLimit) << 128) |
            bytes32(uint256(meta.timestamp) << 64) |
            bytes32(uint256(meta.l1Height));

        inputs[1] = meta.l1Hash;
        inputs[2] = meta.mixHash;
        inputs[3] = meta.txListHash;
        inputs[4] = bytes32(uint256(uint160(meta.beneficiary)));

        assembly {
            hash := keccak256(inputs, mul(5, 32))
        }
    }
}
