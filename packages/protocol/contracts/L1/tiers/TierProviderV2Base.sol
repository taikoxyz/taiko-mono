// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/LibStrings.sol";
import "./ITierProviderV2.sol";

/// @title TierProviderV2Base
/// @custom:security-contact security@taiko.xyz
abstract contract TierProviderV2Base is ITierProviderV2 {
    /// @inheritdoc ITierProviderV2
    function getTier(uint8 _tierId)
        public
        pure
        virtual
        override
        returns (ITierProviderV2.Tier memory)
    {
        if (_tierId == LibTiersV2.TIER_OPTIMISTIC) {
            return ITierProviderV2.Tier({
                verifierName: "",
                validityBond: 125 ether, // TKO
                contestBond: 250 ether, // TKO
                cooldownWindow: 1440, //24 hours
                provingWindow: 15 // 15 minutes
             });
        }

        if (_tierId == LibTiersV2.TIER_SGX_ONTAKE) {
            return ITierProviderV2.Tier({
                verifierName: LibStrings.B_TIER_SGX_ONTAKE,
                validityBond: 125 ether, // TKO
                contestBond: 820 ether, // =250TKO * 6.5625
                cooldownWindow: 1440, //24 hours
                provingWindow: 60 // 1 hours
             });
        }

        if (_tierId == LibTiersV2.TIER_GUARDIAN_MINORITY) {
            return ITierProviderV2.Tier({
                verifierName: LibStrings.B_TIER_GUARDIAN_MINORITY,
                validityBond: 250 ether, // TKO
                contestBond: 1640 ether, // =500TKO * 6.5625
                cooldownWindow: 240, // 4 hours
                provingWindow: 2880 // 48 hours
             });
        }

        if (_tierId == LibTiersV2.TIER_GUARDIAN) {
            return ITierProviderV2.Tier({
                verifierName: LibStrings.B_TIER_GUARDIAN,
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 1440, // 24 hours
                provingWindow: 2880 // 48 hours
             });
        }

        revert TIER_NOT_FOUND();
    }
}
