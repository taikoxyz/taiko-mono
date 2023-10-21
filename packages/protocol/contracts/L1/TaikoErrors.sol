// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title TaikoErrors
/// @notice This abstract contract provides custom error declartions used in
/// the Taiko protocol. Each error corresponds to specific situations where
/// exceptions might be thrown.
abstract contract TaikoErrors {
    // NOTE: The following custom errors must match the definitions in
    // `L1/libs/*.sol`.
    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID_MISMATCH();
    error L1_EVIDENCE_MISMATCH();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_ASSIGNMENT();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_CONFIG();
    error L1_INVALID_ETH_DEPOSIT();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_METADATA();
    error L1_INVALID_ORACLE_PROVER();
    error L1_INVALID_PARAM();
    error L1_INVALID_PROOF();
    error L1_INVALID_PROPOSER();
    error L1_INVALID_PROVER();
    error L1_INVALID_PROVER_SIG();
    error L1_NOT_PROVEABLE();
    error L1_SAME_PROOF();
    error L1_TOO_MANY_BLOCKS();
    error L1_TRANSITION_NOT_FOUND();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();
    error L1_UNEXPECTED_TRANSITION_ID();
}
