// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/LibStrings.sol";
import "./ITierProvider.sol";

/// @title TierProviderBase
/// @custom:security-contact security@taiko.xyz
abstract contract TierProviderBase is ITierProvider {
    /// @dev Grace period for block proving service.
    /// @notice This constant defines the time window (in minutes) during which the block proving
    /// service may be paused if gas prices are excessively high. Since block proving is
    /// asynchronous, this grace period allows provers to defer submissions until gas
    /// prices become more favorable, potentially reducing transaction costs.
    uint16 public constant GRACE_PERIOD = 240; // 4 hours

    /// @inheritdoc ITierProvider
    /// @notice Each tier, except the top tier, has a validity bond that is 50 TAIKO higher than the
    /// previous tier. Additionally, each tier's contest bond is 6.5625 times its validity bond.
    function getTier(
        uint16 _tierId
    )
        public
        pure
        virtual
        override
        returns (ITierProvider.Tier memory)
    {
        if (_tierId == LibTiers.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "",
                validityBond: 100 ether, // TAIKO
                contestBond: 656.25 ether, // = 100 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 15 // 15 minutes
             });
        }

        if (_tierId == LibTiers.TIER_SGX) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_SGX,
                validityBond: 150 ether, // TAIKO
                contestBond: 984.375 ether, // = 150 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 60 // 1 hour
             });
        }

        if (_tierId == LibTiers.TIER_TDX) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_TDX,
                validityBond: 150 ether, // TAIKO
                contestBond: 984.375 ether, // = 150 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 60, // 1 hour
                maxBlocksToVerifyPerProof: 0
            });
        }

        if (_tierId == LibTiers.TIER_TEE_ANY) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_TEE_ANY,
                validityBond: 150 ether, // TAIKO
                contestBond: 984.375 ether, // = 150 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 60 // 1 hour
             });
        }

        if (_tierId == LibTiers.TIER_ZKVM_RISC0) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_ZKVM_RISC0,
                validityBond: 250 ether, // TAIKO
                contestBond: 1640.625 ether, // = 250 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 180 // 3 hours
             });
        }

        if (_tierId == LibTiers.TIER_ZKVM_SP1) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_ZKVM_SP1,
                validityBond: 250 ether, // TAIKO
                contestBond: 1640.625 ether, // = 250 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 180 // 3 hours
             });
        }

        if (_tierId == LibTiers.TIER_ZKVM_ANY) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_ZKVM_ANY,
                validityBond: 250 ether, // TAIKO
                contestBond: 1640.625 ether, // = 250 TAIKO * 6.5625
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 240 // 4 hours
             });
        }

        if (_tierId == LibTiers.TIER_GUARDIAN_MINORITY) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_GUARDIAN_MINORITY,
                validityBond: 350 ether, // TAIKO
                contestBond: 2296.875 ether, // = 350 TAIKO * 6.5625
                cooldownWindow: GRACE_PERIOD + 240, // 4 hours
                provingWindow: 2880 // 48 hours
             });
        }

        if (_tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: LibStrings.B_TIER_GUARDIAN,
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 1440, // 24 hours
                provingWindow: GRACE_PERIOD + 2880 // 48 hours
             });
        }

        revert TIER_NOT_FOUND();
    }
}
