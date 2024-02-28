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

/// @title DevnetTierProvider
/// @custom:security-contact security@taiko.xyz
/// @dev Labeled in AddressResolver as "tier_provider"
contract DevnetTierProvider is EssentialContract, ITierProvider {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function getTier(uint16 tierId) public pure override returns (ITierProvider.Tier memory) {
        if (tierId == LibTiers.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "tier_optimistic",
                validityBond: 250 ether, // TKO
                contestBond: 500 ether, // TKO
                cooldownWindow: 1440, //24 hours
                provingWindow: 120, // 2 hours
                maxBlocksToVerifyPerProof: 16
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

    function getTierIds() public pure override returns (uint16[] memory rTiers) {
        rTiers = new uint16[](2);
        rTiers[0] = LibTiers.TIER_OPTIMISTIC;
        rTiers[1] = LibTiers.TIER_GUARDIAN;
    }

    function getMinTier(uint256) public pure override returns (uint16) {
        return LibTiers.TIER_OPTIMISTIC;
    }
}
