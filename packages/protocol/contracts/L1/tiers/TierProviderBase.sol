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
    function getTier(uint16 _tierId) public pure virtual returns (ITierProvider.Tier memory) {
        // Using _buildTier to simplify tier creation
        if (_tierId == LibTiers.TIER_OPTIMISTIC) {
            // cooldownWindow is 24 hours and provingWindow is 15 minutes
            return _buildTier("", 100 ether, 1440, 15);
        }

        // TEE Tiers
        if (_tierId == LibTiers.TIER_SGX) return _buildTeeTier(LibStrings.B_TIER_SGX);
        if (_tierId == LibTiers.TIER_TDX) return _buildTeeTier(LibStrings.B_TIER_TDX);
        if (_tierId == LibTiers.TIER_TEE_ANY) return _buildTeeTier(LibStrings.B_TIER_TEE_ANY);

        // ZKVM Tiers
        if (_tierId == LibTiers.TIER_ZKVM_RISC0) return _buildZkTier(LibStrings.B_TIER_ZKVM_RISC0);
        if (_tierId == LibTiers.TIER_ZKVM_SP1) return _buildZkTier(LibStrings.B_TIER_ZKVM_SP1);
        if (_tierId == LibTiers.TIER_ZKVM_ANY) return _buildZkTier(LibStrings.B_TIER_ZKVM_ANY);

        if (_tierId == LibTiers.TIER_GUARDIAN_MINORITY) {
            // cooldownWindow is 4 hours and provingWindow is 48 hours
            return _buildTier(LibStrings.B_TIER_GUARDIAN_MINORITY, 400 ether, 240, 2880);
        }

        if (_tierId == LibTiers.TIER_GUARDIAN) {
            // cooldownWindow is 24 hours and provingWindow is 48 hours
            return _buildTier(LibStrings.B_TIER_GUARDIAN, 0, 1440, 2880);
        }

        revert TIER_NOT_FOUND();
    }

    /// @dev Builds a TEE tier with a specific verifier name.
    /// @param _verifierName The name of the verifier.
    /// @return A Tier struct with predefined parameters for TEE.
    function _buildTeeTier(
        bytes32 _verifierName
    )
        private
        pure
        returns (ITierProvider.Tier memory)
    {
        // cooldownWindow is 24 hours and provingWindow is 1 hour
        return _buildTier(_verifierName, 200 ether, 1440, 60);
    }

    /// @dev Builds a ZK tier with a specific verifier name.
    /// @param _verifierName The name of the verifier.
    /// @return A Tier struct with predefined parameters for ZK.
    function _buildZkTier(bytes32 _verifierName) private pure returns (ITierProvider.Tier memory) {
        // cooldownWindow is 24 hours and provingWindow is 3 hours
        return _buildTier(_verifierName, 300 ether, 1440, 180);
    }

    /// @dev Builds a generic tier with specified parameters.
    /// @param _verifierName The name of the verifier.
    /// @param _validityBond The validity bond amount.
    /// @param _cooldownWindow The cooldown window duration in minutes.
    /// @param _provingWindow The proving window duration in minutes.
    /// @return A Tier struct with the provided parameters.
    function _buildTier(
        bytes32 _verifierName,
        uint96 _validityBond,
        uint16 _cooldownWindow,
        uint16 _provingWindow
    )
        private
        pure
        returns (ITierProvider.Tier memory)
    {
        return ITierProvider.Tier({
            verifierName: _verifierName,
            validityBond: _validityBond,
            contestBond: _validityBond / 10_000 * 65_625,
            cooldownWindow: _cooldownWindow,
            provingWindow: GRACE_PERIOD + _provingWindow,
            maxBlocksToVerifyPerProof: 0
        });
    }
}
