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

    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }

    /// @inheritdoc ITierProvider
    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {
        if (_tierId == 1) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: BOND_UINT,
                contestBond: BOND_UINT * 2,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == 2) {
            return ITierProvider.Tier({
                verifierName: "tier2",
                validityBond: BOND_UINT * 3,
                contestBond: BOND_UINT * 4,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == 3) {
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
        tiers_[0] = 1;
        tiers_[1] = 2;
        tiers_[2] = 3;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256) public pure override returns (uint16) {
        return 1;
    }
}
