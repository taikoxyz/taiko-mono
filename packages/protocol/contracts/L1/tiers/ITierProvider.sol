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

/// @title ITierProvider
/// @custom:security-contact security@taiko.xyz
/// @notice Defines interface to return tier configuration.
interface ITierProvider {
    struct Tier {
        bytes32 verifierName;
        uint96 validityBond;
        uint96 contestBond;
        uint24 cooldownWindow; // in minutes
        uint16 provingWindow; // in minutes
        uint8 maxBlocksToVerifyPerProof;
    }

    error TIER_NOT_FOUND();

    /// @dev Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return Tier struct containing the tier's parameters.
    function getTier(uint16 tierId) external view returns (Tier memory);

    /// @dev Retrieves the IDs of all supported tiers.
    /// Note that the core protocol requires the number of tiers to be smaller
    /// than 256. In reality, this number should be much smaller.
    /// @return uint16[] struct containing the ids of the tiers.
    function getTierIds() external view returns (uint16[] memory);

    /// @dev Determines the minimal tier for a block based on a random input.
    /// @param rand (Semi) random number.
    /// @return uint16 Tier id.
    function getMinTier(uint256 rand) external view returns (uint16);
}

/// @dev Tier ID cannot be zero!
library LibTiers {
    uint16 public constant TIER_OPTIMISTIC = 100;
    uint16 public constant TIER_SGX = 200;
    uint16 public constant TIER_SGX_ZKVM = 300;
    uint16 public constant TIER_GUARDIAN = 1000;
}
