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

    function applyOversellPremium(
        LibData.State storage s,
        uint256 fee,
        bool releaseOneSlot
    ) public view returns (uint256) {
        uint256 p = LibConstants.TAIKO_INCENTIVE_PREMIUM_LAMDA +
            LibConstants.TAIKO_BLOCK_BUFFER_SIZE +
            s.latestFinalizedId -
            s.nextBlockId;
        uint256 q = releaseOneSlot ? p + 1 : p - 1;
        return (fee * LibConstants.TAIKO_INCENTIVE_PREMIUM_PHI) / p / q;
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

    function feeScale(
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg,
        uint256 gracePerid,
        uint256 maxPeriod
    ) internal pure returns (uint256) {
        if (tAvg == 0) {
            return 10000;
        }
        uint256 tGrace = (gracePerid * tAvg) / 100;
        uint256 tMax = (maxPeriod * tAvg) / 100;
        uint256 a = tLast + tGrace;
        uint256 b = tNow > a ? tNow - a : 0;
        uint256 tRel = (b.min(tMax) * 10000) / tMax;
        return
            10000 +
            ((LibConstants.TAIKO_INCENTIVE_MULTIPLIER - 100) * tRel) /
            100;
    }
}
