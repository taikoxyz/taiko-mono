// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../tiers/TierProviderBase.sol";
import "../tiers/ITierRouter.sol";

/// @title HeklaTierRouter
/// @custom:security-contact security@taiko.xyz
contract HeklaTierRouter is TierProviderBase, ITierRouter {
    address public immutable DAO_FALLBACK_PROPOSER;

    constructor(address _daoFallbackProposer) {
        // 0xD3f681bD6B49887A48cC9C9953720903967E9DC0
        DAO_FALLBACK_PROPOSER = _daoFallbackProposer;
    }

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
    function getMinTier(address _proposer, uint256 _rand) public view override returns (uint16) {
        if (_proposer == DAO_FALLBACK_PROPOSER) {
            if (_rand % 1000 == 0) return LibTiers.TIER_ZKVM_RISC0;
            else if (_rand % 1000 == 1) return LibTiers.TIER_ZKVM_SP1;
            else return LibTiers.TIER_SGX;
        }

        return _rand % 2 == 0 ? LibTiers.TIER_SGX : LibTiers.TIER_OPTIMISTIC;
    }
}
