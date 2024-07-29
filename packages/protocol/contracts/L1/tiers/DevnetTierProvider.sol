// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TierProviderBase.sol";
import "./ITierRouter.sol";

/// @title DevnetTierProvider
/// @custom:security-contact security@taiko.xyz
contract DevnetTierProvider is TierProviderBase, ITierRouter {
    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTiers.TIER_OPTIMISTIC;
        tiers_[1] = LibTiers.TIER_SGX_ZKVM;
        tiers_[2] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[3] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(uint256 rand) public pure override returns (uint16) {
        if (rand % 500 == 0) {
            return LibTiers.TIER_SGX_ZKVM;
        } else {
            return LibTiers.TIER_OPTIMISTIC;
        }

    }
}
