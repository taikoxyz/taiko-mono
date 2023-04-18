// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

abstract contract TaikoErrors {
    // The following custom errors must match the definitions in other V1 libraries.
    error L1_1559_X_SCALE_TOO_LARGE();
    error L1_1559_Y_SCALE_TOO_LARGE();
    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID();
    error L1_CONTRACT_NOT_ALLOWED();
    error L1_EVIDENCE_MISMATCH(bytes32 expected, bytes32 actual);
    error L1_FORK_CHOICE_NOT_FOUND();
    error L1_INSUFFICIENT_ETHER();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_CONFIG();
    error L1_INVALID_ETH_DEPOSIT();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_L21559_PARAMS();
    error L1_INVALID_METADATA();

    error L1_INVALID_PARAM();
    error L1_INVALID_PROOF();

    error L1_NOT_ORACLE_PROVER();
    error L1_NOT_SOLO_PROPOSER();
    error L1_ORACLE_DISABLED();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();
}
