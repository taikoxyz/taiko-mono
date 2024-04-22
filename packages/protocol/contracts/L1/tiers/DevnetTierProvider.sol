// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "./ITierProvider.sol";

/// @title DevnetTierProvider
/// @dev Labeled in AddressResolver as "tier_provider"
/// @custom:security-contact security@taiko.xyz
contract DevnetTierProvider is EssentialContract, ITierProvider {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ITierProvider
    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {
        if (_tierId == LibTiers.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: 250 ether, // TKO
                contestBond: 500 ether, // TKO
                cooldownWindow: 1440, //24 hours
                provingWindow: 120, // 2 hours
                maxBlocksToVerifyPerProof: 16
            });
        }

        if (_tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: "tier_guardian",
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 60, //1 hours
                provingWindow: 2880, // 48 hours
                maxBlocksToVerifyPerProof: 16
            });
        }

        revert TIER_NOT_FOUND();
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](2);
        tiers_[0] = LibTiers.TIER_OPTIMISTIC;
        tiers_[1] = LibTiers.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(uint256) public pure override returns (uint16) {
        return LibTiers.TIER_OPTIMISTIC;
    }
}
