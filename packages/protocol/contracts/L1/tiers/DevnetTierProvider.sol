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

    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {
        if (_tierId == LibTiers.TIER_SGX_ZKVM) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_SGX_ZKVM,
                validityBond: 250 ether, // TKO
                contestBond: 1640 ether, // =500TKO * 6.5625
                cooldownWindow: 1440, //24 hours
                provingWindow: 240, // 4 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTiers.TIER_GUARDIAN_MINORITY) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_GUARDIAN_MINORITY,
                validityBond: 250 ether, // TKO
                contestBond: 1640 ether, // =500TKO * 6.5625
                cooldownWindow: 240, // 4 hours
                provingWindow: 2880, // 48 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_GUARDIAN,
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 60, //1 hours
                provingWindow: 2880, // 48 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        revert TIER_NOT_FOUND();
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTiers.TIER_SGX_ZKVM;
        tiers_[1] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(uint256) public pure override returns (uint16) {
        return LibTiers.TIER_SGX_ZKVM;
    }
}
