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
        uint8 maxBlocksToVerifyPerProof; // DEPRECATED
    }

    error TIER_NOT_FOUND();

    /// @dev Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return Tier struct containing the tier's parameters.
    function getTier(uint16 tierId) external view returns (Tier memory);

    /// @dev Retrieves the IDs of all supported tiers.
    /// Note that the core protocol requires the number of tiers to be smaller
    /// than 256. In reality, this number should be much smaller.
    /// @return The ids of the tiers.
    function getTierIds() external view returns (uint16[] memory);

    /// @dev Determines the minimal tier for a block based on a random input.
    /// @param rand A pseudo-random number.
    /// @return The tier id.
    function getMinTier(uint256 rand) external view returns (uint16);
}

/// @dev Tier ID cannot be zero!
library LibTiers {
    /// @notice Optimistic tier ID.
    uint16 public constant TIER_OPTIMISTIC = 100;

    /// @notice SGX tier ID.
    uint16 public constant TIER_SGX = 200;
    uint16 public constant TIER_SGX2 = 200;

    /// @notice SGX + ZKVM tier ID.
    uint16 public constant TIER_SGX_ZKVM = 300; //This one itself is not really needed cause
        // SGX_ZKVM not really specifies which ZKVM (risc0 or sp1 for example) and also beside sgx
        // we will have tdx, etc.
    uint16 public constant TIER_SGX_RISC0 = 301;
    uint16 public constant TIER_SGX_SP1 = 302;
    //And more like: TIER_TDX_SP1 = 303;

    /// @notice Guardian tier ID with minority approval.
    uint16 public constant TIER_GUARDIAN_MINORITY = 900;

    /// @notice Guardian tier ID with majority approval.
    uint16 public constant TIER_GUARDIAN = 1000;
}
