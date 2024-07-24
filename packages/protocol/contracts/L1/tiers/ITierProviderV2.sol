// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITierProviderV2
/// @notice Defines interface to return tier configuration.
/// @custom:security-contact security@taiko.xyz
interface ITierProviderV2 {
    struct Tier {
        bytes32 verifierName;
        uint96 validityBond;
        uint96 contestBond;
        uint24 cooldownWindow; // in minutes
        uint16 provingWindow; // in minutes
    }

    error TIER_NOT_FOUND();

    /// @dev Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return Tier struct containing the tier's parameters.
    function getTier(uint8 tierId) external view returns (Tier memory);

    /// @dev Retrieves the IDs of all supported tiers.
    /// Note that the core protocol requires the number of tiers to be smaller
    /// than 256. In reality, this number should be much smaller.
    /// @return The ids of the tiers.
    function getTierIds() external view returns (uint8[] memory);

    /// @dev Determines the minimal tier for a block based on a random input.
    /// @param rand A pseudo-random number.
    /// @return The tier id.
    function getMinTier(uint256 rand) external view returns (uint8);
}

/// @dev Tier ID cannot be zero!
library LibTiersV2 {
    /// @notice Optimistic tier ID.
    uint8 public constant TIER_OPTIMISTIC = 1;

    /// @notice SGX tier ID.
    uint8 public constant TIER_SGX_ONTAKE = 5;

    /// @notice Guardian tier ID with minority approval.
    uint8 public constant TIER_GUARDIAN_MINORITY = 250;

    /// @notice Guardian tier ID with majority approval.
    uint8 public constant TIER_GUARDIAN = 255;
}
