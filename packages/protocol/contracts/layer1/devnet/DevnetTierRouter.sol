// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../tiers/TierProviderBase.sol";
import "../tiers/ITierRouter.sol";

/// @title DevnetTierRouter
/// @custom:security-contact security@taiko.xyz
contract DevnetTierRouter is TierProviderBase, ITierRouter {
    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }

    /// @inheritdoc ITierProvider
    function getTierIds() external pure returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](6);
        tiers_[0] = LibTiers.TIER_OPTIMISTIC;
        tiers_[1] = LibTiers.TIER_SGX;
        tiers_[2] = LibTiers.TIER_ZKVM_RISC0;
        tiers_[3] = LibTiers.TIER_ZKVM_SP1;
        tiers_[4] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[5] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256) public pure override returns (uint16) {
        return LibTiers.TIER_SGX;
    }
}
