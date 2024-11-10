// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/tiers/TierProviderBase.sol";

/// @title MainnetTierProvider
/// @dev Any changes to the configuration in this file must be announced and documented on our site.
/// Ensure all modifications are reviewed by the devrel team.
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract MainnetTierProvider is TierProviderBase {
    address public immutable DAO_FALLBACK_PROPOSER;

    constructor(address _daoFallbackProposer) {
        // 0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9
        DAO_FALLBACK_PROPOSER = _daoFallbackProposer;
    }

    /// @inheritdoc ITierProvider
    function getTierIds() external pure returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTiers.TIER_SGX;
        tiers_[1] = LibTiers.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(
        uint64, /*_blockId*/
        address, /*_proposer*/
        uint256 /*_rand*/
    )
        public
        pure
        override
        returns (uint16)
    {
        return LibTiers.TIER_SGX;
    }
}
