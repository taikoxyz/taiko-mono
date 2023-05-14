// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

abstract contract TaikoErrors {
    // The following custom errors must match the definitions in other V1 libraries.
    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID();
    error L1_EVIDENCE_MISMATCH(bytes32 expected, bytes32 actual);
    error L1_FORK_CHOICE_NOT_FOUND();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_CONFIG();
    error L1_INVALID_ETH_DEPOSIT();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_METADATA();
    error L1_INVALID_PARAM();
    error L1_INVALID_PROOF();
    error L1_INVALID_PROOF_OVERWRITE();
    error L1_NOT_SPECIAL_PROVER();
    error L1_ORACLE_PROVER_DISABLED();
    error L1_SAME_PROOF();
    error L1_SYSTEM_PROVER_DISABLED();
    error L1_SYSTEM_PROVER_PROHIBITED();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();
}
