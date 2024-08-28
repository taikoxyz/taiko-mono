// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibTiers
/// @dev Tier ID cannot be zero!
/// @custom:security-contact security@taiko.xyz
library LibTiers {
    /// @notice Optimistic tier ID.
    uint16 public constant TIER_OPTIMISTIC = 100;

    /// @notice SGX proof
    uint16 public constant TIER_SGX = 200;

    /// @notice TDX proof
    uint16 public constant TIER_TDX = 200;

    /// @notice Any TEE proof
    uint16 public constant TIER_TEE_ANY = 200;

    /// @notice Risc0's ZKVM proof
    uint16 public constant TIER_ZKVM_RISC0 = 290;

    /// @notice SP1's ZKVM proof
    uint16 public constant TIER_ZKVM_SP1 = 290;

    /// @notice Any ZKVM proof
    uint16 public constant TIER_ZKVM_ANY = 290;

    /// @notice Guardian tier ID with minority approval.
    uint16 public constant TIER_GUARDIAN_MINORITY = 900;

    /// @notice Guardian tier ID with majority approval.
    uint16 public constant TIER_GUARDIAN = 1000;
}
