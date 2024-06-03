// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TierProviderBase.sol";

/// @title TierProviderV3
/// @custom:security-contact security@taiko.xyz
contract TierProviderV3 is TierProviderBase {
    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](4);
        tiers_[0] = LibTiers.TIER_SGX;
        tiers_[1] = LibTiers.TIER_SGX_ZKVM;
        tiers_[2] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[3] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(uint256 _rand) public pure override returns (uint16) {
        // 0.1% require SGX + ZKVM; all others require SGX
        if (_rand % 1000 == 0) return LibTiers.TIER_SGX_ZKVM;
        else return LibTiers.TIER_SGX;
    }
}
