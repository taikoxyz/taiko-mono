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
    function updateBaseFee(
        LibData.State storage s,
        uint256 premium,
        uint256 actualFee
    ) public {
        s.baseFee = (s.baseFee * (1023 + actualFee / premium)) / 1024;
    }

    function getPremium(LibData.State storage s, bool releaseOneSlot)
        public
        view
        returns (uint256)
    {
        uint256 n = LibConstants.TAIKO_MAX_PROPOSED_BLOCKS +
            1 -
            s.nextBlockId +
            s.latestFinalizedId;
        uint256 p = n + LibConstants.TAIKO_FEE_PREMIUM_LAMDA;
        uint256 q = releaseOneSlot ? p + 1 : p - 1;
        return (s.baseFee * LibConstants.TAIKO_FEE_PREMIUM_PHI) / p / q;
    }
}
