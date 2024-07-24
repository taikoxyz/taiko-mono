// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TierProviderV2Base.sol";

/// @title TierProviderV2A
/// @custom:security-contact security@taiko.xyz
contract TierProviderV2A is TierProviderV2Base {
    /// @inheritdoc ITierProviderV2
    function getTierIds() public pure override returns (uint8[] memory tiers_) {
        tiers_ = new uint8[](3);
        tiers_[0] = LibTiersV2.TIER_SGX_ONTAKE;
        tiers_[1] = LibTiersV2.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTiersV2.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProviderV2
    function getMinTier(uint256) public pure override returns (uint8) {
        return LibTiersV2.TIER_SGX_ONTAKE;
    }
}
