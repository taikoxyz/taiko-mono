// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

abstract contract TaikoErrors {
    // The following custom errors must match the definitions in other V1 libraries.
    error L1_ALREADY_PROVEN();
    error L1_BLOCK_NUMBER();
    error L1_BLOCK_PROOF();
    error L1_CONFLICT_PROOF();
    error L1_CONTRACT_NOT_ALLOWED();
    error L1_DUP_PROVERS();
    error L1_EXTRA_DATA();
    error L1_GAS_LIMIT();
    error L1_ID();
    error L1_INPUT_SIZE();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_PARAM();
    error L1_METADATA_FIELD();
    error L1_NOT_ORACLE_PROVER();
    error L1_SOLO_PROPOSER();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_PROOF();
    error L1_TX_LIST();
    error L1_ZERO_FEE_BASE();
}
