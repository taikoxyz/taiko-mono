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

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        LibData.State storage s,
        bool isProposal,
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg,
        uint64 tCap
    ) internal view returns (uint256) {
        if (tAvg == 0) {
            return s.feeBase;
        }
        uint256 _tAvg = tAvg > tCap ? tCap : tAvg;
        uint256 tGrace = (LibConstants.K_FEE_GRACE_PERIOD * _tAvg) / 100;
        uint256 tMax = (LibConstants.K_FEE_MAX_PERIOD * _tAvg) / 100;
        uint256 a = tLast + tGrace;
        uint256 b = tNow > a ? tNow - a : 0;
        uint256 tRel = (b.min(tMax) * 10000) / tMax; // [0 - 10000]
        uint256 alpha = 10000 +
            ((LibConstants.K_reward_multiplier - 100) * tRel) /
            100;
        if (isProposal) {
            return (s.feeBase * 10000) / alpha; // fee
        } else {
            return (s.feeBase * alpha) / 10000; // reward
        }
    }

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        LibData.State storage s,
        bool isProposal,
        uint256 fee
    ) public view returns (uint256) {
        // m is the `n'` in the whitepaper
        uint256 m = LibConstants.K_MAX_NUM_BLOCKS -
            1 +
            LibConstants.K_FEE_PREMIUM_LAMDA;
        // n is the number of unverified blocks
        uint256 n = s.latestFinalizedId - s.nextBlockId - 1;
        // k is `m − n + 1` or `m − n - 1`in the whitepaper
        uint256 k = isProposal ? m - n - 1 : m - n + 1;
        return (fee * (m - 1) * m) / (m - n) / k;
    }

    // Implement "Bootstrap Discount Multipliers", see the whitepaper.
    function getBootstrapDiscountedFee(
        LibData.State storage s,
        uint256 fee
    ) internal view returns (uint256) {
        uint256 halves = uint256(block.timestamp - s.genesisTimestamp) /
            LibConstants.K_HALVING;
        uint256 gamma = 1024 - (1024 >> halves);
        return (fee * gamma) / 1024;
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
