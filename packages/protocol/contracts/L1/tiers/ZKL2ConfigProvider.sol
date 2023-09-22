// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TierProvider } from "./TierProvider.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

/// @title ZKL2ConfigProvider
contract ZKL2ConfigProvider is TierProvider {
    function getTierConfig(uint16 tierId)
        public
        pure
        override
        returns (TaikoData.TierConfig memory)
    {
        if (tierId == TIER_PSE_ZKEVM) {
            return TaikoData.TierConfig({
                verifierName: "tier_pse_zkevm",
                proofBond: 10_000 ether, // TKO
                contestBond: 10_000 ether, // TKO
                cooldownWindow: 2 hours,
                provingWindow: 90 minutes
            });
        }

        if (tierId == TIER_GUARDIAN) {
            return TaikoData.TierConfig({
                verifierName: "tier_guardian",
                proofBond: 0,
                contestBond: 0, // not contestable
                cooldownWindow: 1 hours,
                provingWindow: 120 minutes
            });
        }

        revert L1_TIER_NOT_FOUND();
    }

    function getTierIds()
        public
        pure
        override
        returns (uint16[] memory tiers)
    {
        tiers = new uint16[](2);
        tiers[0] = TIER_PSE_ZKEVM;
        tiers[1] = TIER_GUARDIAN;
    }

    function getMinTier(uint256 rand) public pure override returns (uint16) {
        return TIER_PSE_ZKEVM;
    }
}
