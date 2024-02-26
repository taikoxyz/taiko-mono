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

/// @title MainnetTierProvider
/// @dev Labeled in AddressResolver as "tier_provider"
contract MainnetTierProvider is EssentialContract, ITierProvider {
    uint256[50] private __gap;

    /// @notice Initializes the contract with the provided address manager.
   function init(address _owner) external initializer initEssential(_owner, address(0)) {
    }

    function getTier(uint16 tierId) public pure override returns (ITierProvider.Tier memory) {
        if (tierId == LibTiers.TIER_SGX) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx",
                validityBond: 250 ether, // TKO
                contestBond: 500 ether, // TKO
                cooldownWindow: 1440, //24 hours
                provingWindow: 60, // 1 hours
                maxBlocksToVerifyPerProof: 8
            });
        }

        if (tierId == LibTiers.TIER_SGX_ZKVM) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx_zkvm",
                validityBond: 500 ether, // TKO
                contestBond: 1000 ether, // TKO
                cooldownWindow: 1440, //24 hours
                provingWindow: 240, // 4 hours
                maxBlocksToVerifyPerProof: 4
            });
        }

        if (tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: "tier_guardian",
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 60, //1 hours
                provingWindow: 2880, // 48 hours
                maxBlocksToVerifyPerProof: 16
            });
        }

        revert TIER_NOT_FOUND();
    }

    function getTierIds() public pure override returns (uint16[] memory tiers) {
        tiers = new uint16[](3);
        tiers[0] = LibTiers.TIER_SGX;
        tiers[1] = LibTiers.TIER_SGX_ZKVM;
        tiers[2] = LibTiers.TIER_GUARDIAN;
    }

    function getMinTier(uint256 rand) public pure override returns (uint16) {
        // 0.1% require SGX + ZKVM; all others require SGX
        if (rand % 1000 == 0) return LibTiers.TIER_SGX_ZKVM;
        else return LibTiers.TIER_SGX;
    }
}
