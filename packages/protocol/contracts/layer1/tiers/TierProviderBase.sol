// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/LibStrings.sol";
import "./ITierProvider.sol";
import "./LibTiers.sol";

/// @title TierProviderBase
/// @dev Any changes to the configuration in this file must be announced and documented on our site.
/// Ensure all modifications are reviewed by the devrel team.
/// @custom:security-contact security@taiko.xyz
abstract contract TierProviderBase is ITierProvider {
    /// @dev Grace period for block proving service.
    /// @notice This constant defines the time window (in minutes) during which the block proving
    /// service may be paused if gas prices are excessively high. Since block proving is
    /// asynchronous, this grace period allows provers to defer submissions until gas
    /// prices become more favorable, potentially reducing transaction costs.
    uint96 public constant BOND_UNIT = 50 ether; // TAIKO tokens

    /// @inheritdoc ITierProvider
    /// @notice Each tier, except the top tier, has a validity bond that is 75 TAIKO higher than the
    /// previous tier. Additionally, each tier's contest bond is 6.5625 times its validity bond.
    function getTier(uint16 _tierId) public pure virtual returns (ITierProvider.Tier memory) {
        if (_tierId == LibTiers.TIER_OPTIMISTIC) {
            // cooldownWindow is 24 hours and provingWindow is 90+0 minutes
            return _buildTier(LibStrings.B_TIER_OPTIMISTIC, 1, 1440, 0);
        }

        // TEE Tiers
        if (_tierId == LibTiers.TIER_SGX) {
            return _buildTier(LibStrings.B_TIER_SGX, 2, 60, 60);
        }
        if (_tierId == LibTiers.TIER_TDX) {
            return _buildTier(LibStrings.B_TIER_TDX, 2, 60, 60);
        }
        if (_tierId == LibTiers.TIER_TEE_ANY) {
            return _buildTier(LibStrings.B_TIER_TEE_ANY, 2, 60, 60);
        }

        // ZKVM Tiers
        if (_tierId == LibTiers.TIER_ZKVM_RISC0) {
            return _buildTier(LibStrings.B_TIER_ZKVM_RISC0, 3, 60, 90);
        }
        if (_tierId == LibTiers.TIER_ZKVM_SP1) {
            return _buildTier(LibStrings.B_TIER_ZKVM_SP1, 3, 60, 90);
        }
        if (_tierId == LibTiers.TIER_ZKVM_ANY) {
            return _buildTier(LibStrings.B_TIER_ZKVM_ANY, 3, 60, 90);
        }
        if (_tierId == LibTiers.TIER_ZKVM_AND_TEE) {
            return _buildTier(LibStrings.B_TIER_ZKVM_AND_TEE, 3, 60, 90);
        }

        // Guardian Minority Tiers
        if (_tierId == LibTiers.TIER_GUARDIAN_MINORITY) {
            return _buildTier(LibStrings.B_TIER_GUARDIAN_MINORITY, 4, 60, 90);
        }

        // Guardian Major Tiers
        if (_tierId == LibTiers.TIER_GUARDIAN) {
            return _buildTier(LibStrings.B_TIER_GUARDIAN, 0, 120, 0);
        }

        revert TIER_NOT_FOUND();
    }

    /// @dev Builds a generic tier with specified parameters.
    /// @param _verifierName The name of the verifier.
    /// @param _validityBondUnits The units of validity bonds.
    /// @param _cooldownWindow The cooldown window duration in minutes.
    /// @param _provingWindow The proving window duration in minutes.
    /// @return A Tier struct with the provided parameters.
    function _buildTier(
        bytes32 _verifierName,
        uint8 _validityBondUnits,
        uint16 _cooldownWindow,
        uint16 _provingWindow
    )
        private
        pure
        returns (ITierProvider.Tier memory)
    {
        uint96 validityBond = BOND_UNIT * _validityBondUnits;
        return ITierProvider.Tier({
            verifierName: _verifierName,
            validityBond: validityBond,
            contestBond: validityBond / 10_000 * 65_625,
            cooldownWindow: _cooldownWindow,
            provingWindow: _provingWindow,
            maxBlocksToVerifyPerProof: 0
        });
    }
}
