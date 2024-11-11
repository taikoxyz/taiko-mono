// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/tiers/TierProviderBase.sol";

/// @title MainnetTierProvider
/// @dev Any changes to the configuration in this file must be announced and documented on our site.
/// Ensure all modifications are reviewed by the devrel team.
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract MainnetTierProvider is TierProviderBase {
    address public immutable taikoBeatsProposer;

    constructor(address _taikoBeatsProposer) {
        // 0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9
        taikoBeatsProposer = _taikoBeatsProposer;
    }

    /// @inheritdoc ITierProvider
    function getTierIds() external pure returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](5);
        tiers_[0] = LibTiers.TIER_SGX;
        tiers_[1] = LibTiers.TIER_ZKVM_RISC0;
        tiers_[2] = LibTiers.TIER_ZKVM_SP1;
        tiers_[3] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[4] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(
        uint64, /*_blockId*/
        address _proposer,
        uint256 _rand
    )
        public
        view
        override
        returns (uint16)
    {
        if (_proposer == taikoBeatsProposer) {
            if (_rand % 200 == 0) return LibTiers.TIER_ZKVM_RISC0;
            else if (_rand % 40 == 1) return LibTiers.TIER_ZKVM_SP1;
            else return LibTiers.TIER_SGX;
        }
        return LibTiers.TIER_SGX;
    }
}
