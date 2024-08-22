// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/tiers/TierProviderBase.sol";

/// @title HeklaTierProvider
/// @custom:security-contact security@taiko.xyz
contract HeklaTierProvider is TierProviderBase {
    address public constant LAB_PROPOSER = 0xD3f681bD6B49887A48cC9C9953720903967E9DC0;

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](5);
        tiers_[0] = LibTiers.TIER_OPTIMISTIC;
        tiers_[1] = LibTiers.TIER_TEE_SGX;
        tiers_[2] = LibTiers.TIER_ZKVM_RISC0;
        tiers_[3] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[4] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address _proposer, uint256 _rand) public pure override returns (uint16) {
        if (_proposer == LAB_PROPOSER && _rand % 1000 == 0) {
            // 0.1% of the total blocks will require ZKVM proofs.
            return LibTiers.TIER_ZKVM_RISC0;
        } else if (_rand % 2 == 0) {
            // 50% of the total blocks will require SGX proofs.
            return LibTiers.TIER_TEE_SGX;
        } else {
            return LibTiers.TIER_OPTIMISTIC;
        }
    }
}
