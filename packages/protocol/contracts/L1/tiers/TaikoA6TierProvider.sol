// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ITierProvider, LibTiers } from "./ITierProvider.sol";

/// @title TaikoA6TierProvider
contract TaikoA6TierProvider is ITierProvider {
    uint96 private constant UNIT = 10_000e18; // 10_000 Taiko token (equal to
        // livenessBond)
    // QUESTION(david): This value makes sense to me, but the L2 => L1 bridging
    // will take much longer time
    // than ever before, shall we notify users about this in bridge UI?
    uint24 private constant COOLDOWN_BASE = 24 hours;

    error TIER_NOT_FOUND();

    function getTier(uint16 tierId)
        public
        pure
        override
        returns (ITierProvider.Tier memory)
    {
        if (tierId == LibTiers.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "tier_optimistic",
                validityBond: 20 * UNIT,
                contestBond: 20 * UNIT,
                cooldownWindow: 4 hours + COOLDOWN_BASE,
                provingWindow: 1 hours,
                maxBlocksToVerify: 10
            });
        }

        if (tierId == LibTiers.TIER_SGX) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx",
                validityBond: 10 * UNIT,
                contestBond: 10 * UNIT,
                cooldownWindow: 3 hours + COOLDOWN_BASE,
                provingWindow: 2 hours,
                maxBlocksToVerify: 8
            });
        }

        if (tierId == LibTiers.TIER_SGX_AND_PSE_ZKEVM) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx_and_pse_zkevm",
                validityBond: 5 * UNIT,
                contestBond: 5 * UNIT,
                cooldownWindow: 2 hours + COOLDOWN_BASE,
                provingWindow: 4 hours, // TODO(david): tune this value based on
                    // the A6 circuits benchmark
                maxBlocksToVerify: 6
            });
        }

        if (tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: "tier_guardian",
                validityBond: 0,
                contestBond: 0, // not contestable
                cooldownWindow: 1 hours + COOLDOWN_BASE,
                provingWindow: 4 hours,
                maxBlocksToVerify: 4
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
        tiers = new uint16[](4);
        tiers[0] = LibTiers.TIER_OPTIMISTIC;
        tiers[1] = LibTiers.TIER_SGX;
        tiers[2] = LibTiers.TIER_SGX_AND_PSE_ZKEVM;
        tiers[3] = LibTiers.TIER_GUARDIAN;
    }

    function getMinTier(uint256 rand) public pure override returns (uint16) {
        // If we assume the block time is 3 seconds, and the proof generation
        // time is ~90 mins
        // and half of the blocks are unprovable: 90 * 60 / 3 / 2  = 900.
        // TODO(david): tune this value based on the A6 circuits benchmark.
        if (rand % 900 == 0) return LibTiers.TIER_SGX_AND_PSE_ZKEVM;
        else if (rand % 100 == 0) return LibTiers.TIER_SGX; // 1% of the blocks
            // will be slected to require a SGX proof.

        else return LibTiers.TIER_OPTIMISTIC;
    }
}
