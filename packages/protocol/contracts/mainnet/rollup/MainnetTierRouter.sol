// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../L1/tiers/ITierRouter.sol";

/// @title MainnetTierRouter
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract MainnetTierRouter is ITierRouter {
    /// @inheritdoc ITierRouter
    function getProvider(uint256) external pure returns (address) {
        return 0x4cffe56C947E26D07C14020499776DB3e9AE3a23; // TierProviderV2
    }
}
