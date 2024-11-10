// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibStrings.sol";
import "src/layer1/tiers/ITierProvider.sol";

/// @title TierProvider_With4Tiers
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract TierProvider_With4Tiers is ITierProvider {
    uint16 private minTier = 72;
    uint96 public constant BOND_UINT = 100 ether;
    uint16 public constant ONE_HOUR = 60;

    function setMinTier(uint16 _minTier) external {
        minTier = _minTier;
    }

    /// @inheritdoc ITierProvider
    function getTier(
        uint64,
        uint16 _tierId
    )
        public
        pure
        override
        returns (ITierProvider.Tier memory)
    {
        if (_tierId == 71) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: BOND_UINT,
                contestBond: BOND_UINT * 2,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == 72) {
            return ITierProvider.Tier({
                verifierName: "tier_2",
                validityBond: BOND_UINT * 3,
                contestBond: BOND_UINT * 4,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == 73) {
            return ITierProvider.Tier({
                verifierName: "tier_3",
                validityBond: BOND_UINT * 5,
                contestBond: BOND_UINT * 6,
                cooldownWindow: ONE_HOUR,
                provingWindow: ONE_HOUR,
                maxBlocksToVerifyPerProof: 0 // DEPRECATED
             });
        }

        if (_tierId == 74) {
            return ITierProvider.Tier({
                verifierName: "tier_4",
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
        tiers_ = new uint16[](4);
        tiers_[0] = 71;
        tiers_[1] = 72;
        tiers_[2] = 73;
        tiers_[3] = 74;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(uint64, address, uint256) public view override returns (uint16) {
        return minTier;
    }
}
