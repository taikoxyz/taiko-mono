// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

abstract contract BridgeErrors {
    error B_CANNOT_RECEIVE();
    error B_DENIED();
    error B_ERC20_CANNOT_RECEIVE();
    error B_ETHER_RELEASED_ALREADY();
    error B_EV_DO_NOT_BURN();
    error B_EV_NOT_AUTHORIZED();
    error B_EV_PARAM();
    error B_FAILED_TRANSFER();
    error B_FORBIDDEN();
    error B_GAS_LIMIT();
    error B_INCORRECT_VALUE();
    error B_INIT_PARAM_ERROR();
    error B_MSG_HASH_NULL();
    error B_MSG_NON_RETRIABLE();
    error B_MSG_NOT_FAILED();
    error B_NULL_APP_ADDR();
    error B_OWNER_IS_NULL();
    error B_SIGNAL_NOT_RECEIVED();
    error B_STATUS_MISMATCH();
    error B_WRONG_CHAIN_ID();
    error B_WRONG_TO_ADDRESS();
    error B_ZERO_SIGNAL();
}
