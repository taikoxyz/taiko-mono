// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {ChainData} from "../../common/IXchainSync.sol";
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
        uint256 number,
        uint256 blockHashHistory
    ) internal view returns (ChainData storage) {
        uint256 _number = number;
        if (_number == 0) {
            _number = state.latestVerifiedId;
        } else if (
            _number + blockHashHistory <= state.latestVerifiedId ||
            _number > state.latestVerifiedId
        ) revert L1_BLOCK_NUMBER();

        return state.l2ChainDatas[_number % blockHashHistory];
    }

    function getStateVariables(
        TaikoData.State storage state
    ) internal view returns (TaikoData.StateVariables memory) {
        return
            TaikoData.StateVariables({
                feeBase: LibTokenomics.fromSzabo(state.feeBaseSzabo),
                genesisHeight: state.genesisHeight,
                genesisTimestamp: state.genesisTimestamp,
                nextBlockId: state.nextBlockId,
                lastProposedAt: state.lastProposedAt,
                avgBlockTime: state.avgBlockTime,
                latestVerifiedId: state.latestVerifiedId,
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
}
