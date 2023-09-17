// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../../L1/TaikoData.sol";

library LibTiers {
    uint16 public constant TIER_OPTIMISTIC = 100;
    uint16 public constant TIER_SGX = 200;
    uint16 public constant TIER_PSE_ZKEVM = 300;
    uint16 public constant TIER_GUARDIAN = 1000;

    error L1_TIER_NOT_FOUND();

    function getTierConfig(uint16 tierId)
        internal
        pure
        returns (TaikoData.TierConfig memory)
    {
        if (tierId == TIER_OPTIMISTIC) {
            return TaikoData.TierConfig({
                name: "tier_optimistic",
                proofBond: 100_000 * 1e18, // TKO
                contestBond: 100_000 * 1e18, // TKO
                cooldownWindow: 4 hours,
                provingWindow: 20 minutes
            });
        }

        if (tierId == TIER_SGX) {
            return TaikoData.TierConfig({
                name: "tier_sgx",
                proofBond: 50_000 * 1e18, // TKO
                contestBond: 50_000 * 1e18, // TKO
                cooldownWindow: 3 hours,
                provingWindow: 60 minutes
            });
        }

        if (tierId == TIER_PSE_ZKEVM) {
            return TaikoData.TierConfig({
                name: "tier_pse_zkevm",
                proofBond: 10_000 * 1e18, // TKO
                contestBond: 10_000 * 1e18, // TKO
                cooldownWindow: 2 hours,
                provingWindow: 90 minutes
            });
        }

        if (tierId == TIER_GUARDIAN) {
            return TaikoData.TierConfig({
                name: "tier_guardian",
                proofBond: 0,
                contestBond: 0, // not contestable
                cooldownWindow: 1 hours,
                provingWindow: 120 minutes
            });
        }

        revert L1_TIER_NOT_FOUND();
    }

    function getMinTier(uint256 rand) internal pure returns (uint16) {
        if (rand % 100 == 0) return TIER_PSE_ZKEVM; // 1%

        else return TIER_OPTIMISTIC; // 99%
    }
}
