// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/tiers/ITierRouter.sol";
import "src/layer1/tiers/TierProviderV2.sol";

/// @title MainnetTierRouter
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract MainnetTierRouter is ITierRouter, TierProviderV2 {
    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }
}
