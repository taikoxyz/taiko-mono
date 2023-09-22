// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../TaikoData.sol";

/// @title TierProvider
/// @notice Defines interface to return tier configuration.
abstract contract TierProvider {
    uint16 public constant TIER_OPTIMISTIC = 100;
    uint16 public constant TIER_SGX = 200;
    uint16 public constant TIER_PSE_ZKEVM = 300;
    uint16 public constant TIER_GUARDIAN = 1000;

    error L1_TIER_NOT_FOUND();

    /// @dev Retrieves the configuration for a specified tier.
    function getTierConfig(uint16 tierId)
        public
        view
        virtual
        returns (TaikoData.TierConfig memory);

    /// @dev Retrieves the IDs of all supported tiers.
    function getTierIds() public view virtual returns (uint16[] memory);

    /// @dev Determines the minimal tier for a block based on a random input.
    function getMinTier(uint256 rand) public view virtual returns (uint16);
}
