// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../libs/LibMath.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Utils {
    using LibMath for uint256;

    function feeScaleBeta(
        LibData.State storage s,
        bool releaseOneSlot
    ) public view returns (uint256) {
        uint256 p = LibConstants.K_FEE_PREMIUM_LAMDA +
            LibConstants.K_MAX_NUM_BLOCKS +
            s.latestFinalizedId -
            s.nextBlockId;
        uint256 q = releaseOneSlot ? p + 1 : p - 1;
        return (10000 * LibConstants.K_FEE_PREMIUM_PHI) / p / q;
    }

    function feeScaleAlpha(
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg,
        uint64 tCap
    ) internal pure returns (uint256) {
        if (tAvg == 0) {
            return 10000;
        }
        uint256 _avg = tAvg > tCap ? tCap : tAvg;
        uint256 tGrace = (LibConstants.K_FEE_GRACE_PERIOD * _avg) / 100;
        uint256 tMax = (LibConstants.K_FEE_MAX_PERIOD * _avg) / 100;
        uint256 a = tLast + tGrace;
        uint256 b = tNow > a ? tNow - a : 0;
        uint256 tRel = (b.min(tMax) * 10000) / tMax;
        return 10000 + ((LibConstants.K_FEE_MULTIPLIER - 100) * tRel) / 100;
    }

    function feeScaleGamma(
        uint64 tNow,
        uint64 tGenesis
    ) internal pure returns (uint256) {
        return
            10000 -
            (10000 >> (uint256(tNow - tGenesis) / LibConstants.K_HALVING));
    }

    function movingAverage(
        uint256 ma,
        uint256 v,
        uint256 factor
    ) internal pure returns (uint256) {
        if (ma == 0) {
            return v;
        }
        uint256 _ma = (ma * (factor - 1) + v) / factor;
        return _ma > 0 ? _ma : ma;
    }
}
