// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibMath} from "../../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {Snippet} from "../../common/IXchainSync.sol";
import {TaikoData} from "../TaikoData.sol";

library LibTokenomics {
    using LibMath for uint256;

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bool isProposal,
        uint256 feeBase
    ) internal view returns (uint256) {
        // m is the `n'` in the whitepaper
        uint256 m = 1000 *
            (config.maxNumBlocks - 1) +
            config.slotSmoothingFactor;
        // n is the number of unverified blocks
        uint256 n = 1000 * (state.nextBlockId - state.latestVerifiedId - 1);
        // k is `m − n + 1` or `m − n - 1`in the whitepaper
        uint256 k = isProposal ? m - n - 1000 : m - n + 1000;
        return (feeBase * (m - 1000) * m) / (m - n) / k;
    }

    // Implement "Bootstrap Discount Multipliers", see the whitepaper.
    function getBootstrapDiscountedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 feeBase
    ) internal view returns (uint256) {
        uint256 halves = uint256(block.timestamp - state.genesisTimestamp) /
            config.bootstrapDiscountHalvingPeriod;
        uint256 gamma = 1024 - (1024 >> halves);
        return (feeBase * gamma) / 1024;
    }

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        TaikoData.Config memory config,
        uint256 feeBase,
        bool isProposal,
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg
    ) internal pure returns (uint256 newFeeBase, uint256 tRelBp) {
        if (tAvg == 0) {
            newFeeBase = feeBase;
            // tRelBp = 0;
        } else {
            uint256 _tAvg = tAvg > config.proofTimeCap
                ? config.proofTimeCap
                : tAvg;
            uint256 tMax = (config.feeMaxPeriodPctg * _tAvg) / 100;
            uint256 a = tLast + (config.feeGracePeriodPctg * _tAvg) / 100;
            uint256 b = tNow > a ? tNow - a : 0;
            tRelBp = (b.min(tMax) * 10000) / tMax; // [0 - 10000]
            uint256 alpha = 10000 +
                ((config.rewardMultiplierPctg - 100) * tRelBp) /
                100;
            if (isProposal) {
                newFeeBase = (feeBase * 10000) / alpha; // fee
            } else {
                newFeeBase = (feeBase * alpha) / 10000; // reward
            }
        }
    }

    function feeBaseSzaboToWei(uint64 amount) internal pure returns (uint256) {
        if (amount == 0) {
            return 1E12;
        } else {
            return amount * 1E12;
        }
    }

    function feeBaseWeiToSzabo(uint256 amount) internal pure returns (uint64) {
        uint _szabo = amount / 1E12;
        if (_szabo > type(uint64).max) {
            return type(uint64).max;
        } else if (_szabo == 0) {
            return uint64(1);
        } else {
            return uint64(_szabo);
        }
    }
}
