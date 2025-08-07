// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBondOperation
/// @notice Interface for managing bond operations
/// @custom:security-contact security@taiko.xyz
interface IBondOperation {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct BondOperation {
        uint48 proposalId;
        address receiver;
        uint256 credit;
    }
}