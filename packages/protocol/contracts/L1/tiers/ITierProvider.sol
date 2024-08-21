// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./LibTiers.sol";

/// @title ITierProvider
/// @notice Defines interface to return tier configuration.
/// @custom:security-contact security@taiko.xyz
interface ITierProvider {
    struct Tier {
        bytes32 verifierName;
        uint96 validityBond;
        uint96 contestBond;
        uint24 cooldownWindow; // in minutes
        uint16 provingWindow; // in minutes
        uint8 maxBlocksToVerifyPerProof; // DEPRECATED
    }

    error TIER_NOT_FOUND();

    /// @dev Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return Tier struct containing the tier's parameters.
    function getTier(uint16 tierId) external view returns (Tier memory);

    /// @dev Retrieves the IDs of all supported tiers.
    /// Note that the core protocol requires the number of tiers to be smaller
    /// than 256. In reality, this number should be much smaller.
    /// @return The ids of the tiers.
    function getTierIds() external view returns (uint16[] memory);

    /// @dev Determines the minimal tier for a block based on a random input.
    /// @param proposer The address of the block proposer.
    /// @param rand A pseudo-random number.
    /// @return The tier id.
    function getMinTier(address proposer, uint256 rand) external view returns (uint16);
}
