// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

abstract contract TaikoErrors {
    // The following custom errors must match the definitions in other V1 libraries.
    error L1_1559_GAS_CHANGE_NOT_MATCH(
        uint64 expectedRatio,
        uint64 actualRatio
    );
    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID();
    error L1_CONTRACT_NOT_ALLOWED();
    error L1_EVIDENCE_MISMATCH();
    error L1_FORK_CHOICE_NOT_FOUND();
    error L1_INSUFFICIENT_ETHER();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_CONFIG();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_METADATA();
    error L1_INVALID_PARAM();
    error L1_INVALID_PROOF();
    error L1_NOT_ORACLE_PROVER();
    error L1_NOT_SOLO_PROPOSER();
    error L1_OUT_OF_BLOCK_SPACE();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();
    error L1_UNEXPECTED_FORK_CHOICE_ID();
}
