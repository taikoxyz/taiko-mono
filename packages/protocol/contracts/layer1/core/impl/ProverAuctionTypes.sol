// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ProverAuctionTypes
/// @notice Shared types for prover auction implementations.
/// @custom:security-contact security@taiko.xyz
library ProverAuctionTypes {
    /// @notice Bond information for an account.
    /// @param balance The current bond token balance.
    /// @param withdrawableAt Timestamp when withdrawal is allowed.
    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }
}
