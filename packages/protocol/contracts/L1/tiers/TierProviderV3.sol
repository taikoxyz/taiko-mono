// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TierProviderBase.sol";

/// @title TierProviderV3
/// @custom:security-contact security@taiko.xyz
contract TierProviderV3 is TierProviderBase {
    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTiers.TIER_SGX2;
        tiers_[1] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256) public pure override returns (uint16) {
        return LibTiers.TIER_SGX2;
    }
}
