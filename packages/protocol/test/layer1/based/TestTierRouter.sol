// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibStrings.sol";
import "src/layer1/tiers/ITierProvider.sol";
import "src/layer1/tiers/LibTiers.sol";
import "src/layer1/tiers/ITierRouter.sol";

/// @title TestTierRouter
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract TestTierRouter is ITierProvider, ITierRouter {
    uint96 public constant BOND_UINT = 100 ether;
    uint16 public constant ONE_HOUR = 60;

    uint16 public constant TIER_1 = 10;
    uint16 public constant TIER_2 = 20;
    uint16 public constant TIER_3 = 30;

    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }

    /// @inheritdoc ITierProvider
    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {
        if (_tierId == TIER_1) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: BOND_UINT,
                contestBond: BOND_UINT * 2,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == TIER_2) {
            return ITierProvider.Tier({
                verifierName: "tier2",
                validityBond: BOND_UINT * 3,
                contestBond: BOND_UINT * 4,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == TIER_3) {
            return ITierProvider.Tier({
                verifierName: "tier3",
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        revert TIER_NOT_FOUND();
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = TIER_1;
        tiers_[1] = TIER_2;
        tiers_[2] = TIER_3;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256) public pure override returns (uint16) {
        return TIER_1;
    }
}
