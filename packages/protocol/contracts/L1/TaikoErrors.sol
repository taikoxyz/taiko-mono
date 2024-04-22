// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title TaikoErrors
/// @notice This abstract contract provides custom error declarations used in
/// the Taiko protocol. Each error corresponds to specific situations where
/// exceptions might be thrown.
/// @dev The errors defined here must match the definitions in the corresponding
/// L1 libraries.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoErrors {
    error L1_ALREADY_CONTESTED();
    error L1_ALREADY_PROVED();
    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_BLOCK_MISMATCH();
    error L1_CANNOT_CONTEST();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_CONFIG();
    error L1_INVALID_GENESIS_HASH();
    error L1_INVALID_HOOK();
    error L1_INVALID_PARAM();
    error L1_INVALID_PAUSE_STATUS();
    error L1_INVALID_PROVER();
    error L1_INVALID_SIG();
    error L1_INVALID_TIER();
    error L1_INVALID_TRANSITION();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_NOT_ASSIGNED_PROVER();
    error L1_PROVING_PAUSED();
    error L1_RECEIVE_DISABLED();
    error L1_TOO_MANY_BLOCKS();
    error L1_TRANSITION_ID_ZERO();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNAUTHORIZED();
    error L1_UNEXPECTED_PARENT();
    error L1_UNEXPECTED_TRANSITION_ID();
}
