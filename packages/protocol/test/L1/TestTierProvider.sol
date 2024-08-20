// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../contracts/common/LibStrings.sol";
import "../../contracts/L1/tiers/ITierProvider.sol";
import "../../contracts/L1/tiers/ITierRouter.sol";

/// @title TestTierProvider
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract TestTierProvider is ITierProvider, ITierRouter {
    uint256[50] private __gap;

    /// @inheritdoc ITierRouter
    function getProvider(uint256) external view returns (address) {
        return address(this);
    }
    /// @inheritdoc ITierProvider

    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {
        if (_tierId == LibTierId.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: 250 ether, // TKO
                contestBond: 500 ether, // TKO
                cooldownWindow: 1440, //24 hours
                provingWindow: 30, // 0.5 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_TEE) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_VERIFIER_TEE_ANY,
                validityBond: 250 ether, // TKO
                contestBond: 1640 ether, // =250TKO * 6.5625
                cooldownWindow: 1440, //24 hours
                provingWindow: 60, // 1 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_VERIFIER_GUARDIAN,
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 60, //1 hours
                provingWindow: 2880, // 48 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        revert TIER_NOT_FOUND();
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTierId.TIER_OPTIMISTIC;
        tiers_[1] = LibTierId.TIER_TEE;
        tiers_[2] = LibTierId.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256 _rand) public pure override returns (uint16) {
        // 10% will be selected to require SGX proofs.
        if (_rand % 10 == 0) return LibTierId.TIER_TEE;
        // Other blocks are optimistic, without validity proofs.
        return LibTierId.TIER_OPTIMISTIC;
    }
}
