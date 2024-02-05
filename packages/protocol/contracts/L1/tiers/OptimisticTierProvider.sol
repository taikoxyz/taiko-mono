// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "./ITierProvider.sol";

contract OptimisticTierProvider is EssentialContract, ITierProvider {
    error TIER_NOT_FOUND();

    /// @notice Initializes the contract with the provided address manager.
    function init() external initializer {
        __Essential_init();
    }

    function getTier(uint16 tierId) public pure override returns (ITierProvider.Tier memory) {
        if (tierId == LibTiers.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "tier_optimistic",
                validityBond: 250 ether, // TKO
                contestBond: 500 ether, // TKO
                cooldownWindow: 24 hours,
                provingWindow: 2 hours,
                maxBlocksToVerifyPerProof: 10
            });
        }

        if (tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: "tier_guardian",
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 24 hours,
                provingWindow: 8 hours,
                maxBlocksToVerifyPerProof: 4
            });
        }

        revert TIER_NOT_FOUND();
    }

    function getTierIds() public pure override returns (uint16[] memory tiers) {
        tiers = new uint16[](2);
        tiers[0] = LibTiers.TIER_OPTIMISTIC;
        tiers[1] = LibTiers.TIER_GUARDIAN;
    }

    function getMinTier(uint256 rand) public pure override returns (uint16) {
        return LibTiers.TIER_OPTIMISTIC;
    }
}
