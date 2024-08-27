// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITierProvider
/// @notice Defines interface to return tier configuration.
/// @custom:security-contact security@taiko.xyz
interface ITierProvider {
    struct Tier {
        bytes32 verifierName;
        uint96 validityBond;
        uint96 contestBond;
        uint24 cooldownWindow; // in minutes
        uint16 provingWindow; // in minutes
    }

    error TIER_NOT_FOUND();

    /// @dev Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return Tier struct containing the tier's parameters.
    function getTier(uint16 tierId) external view returns (Tier memory);

    /// @dev Retrieves the IDs of all supported tiers.
    /// Note that the core protocol requires the number of tiers to be smaller
    /// than 256. In reality, this number should be much smaller.
    /// Additionally, each tier's ID value must be unique.
    /// @return The ids of the tiers.
    function getTierIds() external view returns (uint16[] memory);

    /// @dev Determines the minimal tier for a block based on a random input.
    /// @param proposer The address of the block proposer.
    /// @param rand A pseudo-random number.
    /// @return The tier id.
    function getMinTier(address proposer, uint256 rand) external view returns (uint16);
}

/// @title LibTiers
/// @dev Unique identifiers for all supported tiers. Each tier must have a distinct ID to avoid
/// conflicts.
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
