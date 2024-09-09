// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title LibTiers
/// @dev Tier ID cannot be zero and must be unique.
/// @custom:security-contact security@taiko.xyz
library LibTiers {
    /// @notice Optimistic tier ID.
    uint16 public constant TIER_OPTIMISTIC = 100;

    /// @notice TEE tiers
    /// Although these tiers have diffeerent IDs, at most one should be selected in a verifier.
    uint16 public constant TIER_SGX = 200;
    uint16 public constant TIER_TDX = 201;
    uint16 public constant TIER_TEE_ANY = 202;

    /// @notice ZK Tiers.
    /// Although these tiers have diffeerent IDs, at most one should be selected in a verifier.
    uint16 public constant TIER_ZKVM_RISC0 = 250;
    uint16 public constant TIER_ZKVM_SP1 = 251;
    uint16 public constant TIER_ZKVM_ANY = 252;

    /// @notice Any ZKVM+TEE proof
    uint16 public constant TIER_ZKVM_AND_TEE = 300;

    /// @notice Guardian tier ID with minority approval.
    uint16 public constant TIER_GUARDIAN_MINORITY = 900;

    /// @notice Guardian tier ID with majority approval.
    uint16 public constant TIER_GUARDIAN = 1000;
}
