// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/LibStrings.sol";
import "./ITierProvider.sol";

/// @title TierProviderV2
/// @custom:security-contact security@taiko.xyz
contract TierProviderV2 is ITierProvider {
    /// @dev Grace period for block proving service.
    /// @notice This constant defines the time window (in minutes) during which the block proving
    /// service may be paused if gas prices are excessively high. Since block proving is
    /// asynchronous, this grace period allows provers to defer submissions until gas
    /// prices become more favorable, potentially reducing transaction costs.
    uint16 public constant GRACE_PERIOD = 240; // 4 hours

    /// @inheritdoc ITierProvider
    /// @notice Each tier, except the top tier, has a validity bond that is 50 TAIKO higher than the
    /// previous tier. Additionally, each tier's contest bond is 6.5625 times its validity bond.
    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {
        if (_tierId == LibTierId.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: 100 ether, // TAIKO
                contestBond: 656.25 ether, // = 100 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 15, // 15 minutes
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_TEE) {
            return ITierProvider.Tier({
                // verifierName can also be B_VERIFIER_TEE
                verifierName: LibStrings.B_VERIFIER_TEE_SGX,
                validityBond: 150 ether, // TAIKO
                contestBond: 984.375 ether, // = 150 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 60, // 1 hour
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_ZK) {
            return ITierProvider.Tier({
                // verifierName can also be B_VERIFIER_ZK and B_VERIFIER_ZK_SP1
                verifierName: LibStrings.B_VERIFIER_ZK_RISC0,
                validityBond: 250 ether, // TAIKO
                contestBond: 1640.625 ether, // = 250 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 180, // 3 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_TEE_ZK) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_VERIFIER_ZKTEE,
                validityBond: 300 ether, // TAIKO
                contestBond: 1968.75 ether, // = 300 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 240, // 4 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_GUARDIAN_MINORITY) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_VERIFIER_GUARDIAN_MINORITY,
                validityBond: 350 ether, // TAIKO
                contestBond: 2296.875 ether, // = 350 TAIKO * 6.5625
                cooldownWindow: GRACE_PERIOD + 240, // 4 hours
                provingWindow: 2880, // 48 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTierId.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_VERIFIER_GUARDIAN,
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 2880, // 48 hours
                maxBlocksToVerifyPerProof: 0
            });
        }

        revert TIER_NOT_FOUND();
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public pure virtual override returns (uint16[] memory tiers_) {
        tiers_ = new uint16[](3);
        tiers_[0] = LibTierId.TIER_TEE;
        tiers_[1] = LibTierId.TIER_GUARDIAN_MINORITY;
        tiers_[2] = LibTierId.TIER_GUARDIAN;
    }

    /// @inheritdoc ITierProvider
    function getMinTier(address, uint256) public pure virtual override returns (uint16) {
        return LibTierId.TIER_TEE;
    }
}
