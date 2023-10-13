// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ITierProvider, LibTiers } from "./ITierProvider.sol";

/// @title ValidityRollupConfigProvider
contract ValidityRollupConfigProvider is ITierProvider {
    error TIER_NOT_FOUND();

    function getTier(uint16 tierId)
        public
        pure
        override
        returns (ITierProvider.Tier memory)
    {
        if (tierId == LibTiers.TIER_SGX) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx",
                validityBond: 50_000 ether, // TKO
                contestBond: 50_000 ether, // TKO
                cooldownWindow: 3 hours,
                provingWindow: 60 minutes,
                maxBlocksToVerify: 12
            });
        }

        if (tierId == LibTiers.TIER_PSE_ZKEVM) {
            return ITierProvider.Tier({
                verifierName: "tier_pse_zkevm",
                validityBond: 10_000 ether, // TKO
                contestBond: 10_000 ether, // TKO
                cooldownWindow: 2 hours,
                provingWindow: 90 minutes,
                maxBlocksToVerify: 8
            });
        }

        if (tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: "tier_guardian",
                validityBond: 0,
                contestBond: 0, // not contestable
                cooldownWindow: 1 hours,
                provingWindow: 120 minutes,
                maxBlocksToVerify: 0
            });
        }

        revert TIER_NOT_FOUND();
    }

    function getTierIds()
        public
        pure
        override
        returns (uint16[] memory tiers)
    {
        tiers = new uint16[](3);
        tiers[0] = LibTiers.TIER_SGX;
        tiers[1] = LibTiers.TIER_PSE_ZKEVM;
        tiers[2] = LibTiers.TIER_GUARDIAN;
    }

    function getMinTier(uint256 rand) public pure override returns (uint16) {
        if (rand % 100 == 0) return LibTiers.TIER_PSE_ZKEVM;
        else return LibTiers.TIER_SGX;
    }
}
