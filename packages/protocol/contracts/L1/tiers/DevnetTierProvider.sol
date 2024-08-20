// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TierProviderV2.sol";
import "./ITierRouter.sol";

/// @title DevnetTierProvider
/// @custom:security-contact security@taiko.xyz
contract DevnetTierProvider is TierProviderV2, ITierRouter {
    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTierId.TIER_OPTIMISTIC;
        tiers_[1] = LibTierId.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTierId.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256) public pure override returns (uint16) {
        return LibTierId.TIER_OPTIMISTIC;
    }
}
