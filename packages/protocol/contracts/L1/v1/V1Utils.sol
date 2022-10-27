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

import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Utils {
    function updateBaseFee(LibData.State storage s, uint256 actual) public {
        s.baseFee = movingAverage(s.baseFee, actual, 1024);
    }

    function applyOversellPremium(
        LibData.State storage s,
        uint256 fee,
        bool releaseOneSlot
    ) public view returns (uint256) {
        uint256 n = LibConstants.TAIKO_MAX_PROPOSED_BLOCKS +
            1 -
            s.nextBlockId +
            s.latestFinalizedId;
        uint256 p = n + LibConstants.TAIKO_FEE_PREMIUM_LAMDA;
        uint256 q = releaseOneSlot ? p + 1 : p - 1;
        return (fee * LibConstants.TAIKO_FEE_PREMIUM_PHI) / p / q;
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
