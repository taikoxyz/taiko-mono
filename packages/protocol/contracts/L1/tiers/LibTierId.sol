// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibTierId
/// @dev Unique identifiers for all supported tiers. Each tier must have a distinct ID to avoid
/// conflicts.
/// @custom:security-contact security@taiko.xyz
library LibTierId {
    /// @notice Optimistic tier ID.
    uint16 public constant TIER_OPTIMISTIC = 100;

    /// @notice TEE tier
    uint16 public constant TIER_TEE_SGX = 200;

    /// @notice ZK tier
    uint16 public constant TIER_ZK_RISC0 = 290;

    /// @notice TEE + ZK tier
    uint16 public constant TIER_TEE_ZK = 300;

    /// @notice Guardian tier ID with minority approval.
    uint16 public constant TIER_GUARDIAN_MINORITY = 900;

    /// @notice Guardian tier ID with majority approval.
    uint16 public constant TIER_GUARDIAN = 1000;
}
