// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

abstract contract BridgeCustomErrors {
    // Libraries having custom errors in place
    error B_CANNOT_RECEIVE();
    error B_INIT_PARAM_ERROR();
    error B_ERC20_CANNOT_RECEIVE();
    error B_EV_NOT_AUTHORIZED();
    error B_EV_DO_NOT_BURN();
    error B_EV_PARAM();
}
