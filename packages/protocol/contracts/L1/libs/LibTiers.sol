// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../../L1/TaikoData.sol";

library LibTiers {
    uint16 public constant TIER_OPTIMISTIC = 100;
    uint16 public constant TIER_PSE_ZKEVM = 300;
    uint16 public constant TIER_GUARDIAN = 1000;

    error L1_INVALID_TIER();

    function getTierConfig(uint16 tierId)
        internal
        pure
        returns (TaikoData.TierConfig memory)
    {
        if (tierId == TIER_OPTIMISTIC) {
            return TaikoData.TierConfig({
                name: "tier_optimistic",
                proofBond: 100_000,
                contestBond: 100_000,
                cooldownWindow: 4 hours,
                provingWindow: 30 minutes,
                id: tierId
            });
        }

        if (tierId == TIER_PSE_ZKEVM) {
            return TaikoData.TierConfig({
                name: "tier_pse_zkevm",
                proofBond: 10_000,
                contestBond: 10_000,
                cooldownWindow: 2 hours,
                provingWindow: 90 minutes,
                id: tierId
            });
        }

        if (tierId == TIER_GUARDIAN) {
            return TaikoData.TierConfig({
                name: "tier_guardian",
                proofBond: 0,
                contestBond: 0,
                cooldownWindow: 1 hours,
                provingWindow: 90 minutes,
                id: tierId
            });
        }

        revert L1_INVALID_TIER();
    }

    function getBlockMinTier(uint256 rand) internal pure returns (uint16) {
        if (rand % 100 == 0) return TIER_PSE_ZKEVM; // 1%

        else return TIER_OPTIMISTIC; // 99%
    }
}
