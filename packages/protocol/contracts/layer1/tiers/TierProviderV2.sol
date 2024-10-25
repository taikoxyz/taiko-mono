// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TierProviderBase.sol";

/// @title TierProviderV2
/// @custom:security-contact security@taiko.xyz
contract TierProviderV2 is TierProviderBase {
    /// @notice Returns an array of tier IDs.
    /// @return tiers_ An array of tier IDs.
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTiers.TIER_SGX;
        tiers_[1] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTiers.TIER_GUARDIAN;
    }

    /// @notice Returns the minimum tier for a given address and value.
    /// @param _address The address to check the tier for.
    /// @param _value The value to check the tier for.
    /// @return The minimum tier ID.
    // solhint-disable-next-line no-unused-vars
    function getMinTier(address _address, uint256 _value) public pure override returns (uint16) {
        return LibTiers.TIER_SGX;
    }
}
