// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title BridgeErrors
/// @dev This abstract contract defines custom errors that are used throughout
/// the Bridge contract.
abstract contract BridgeErrors {
    error B_INVALID_APP();
    error B_INVALID_CHAINID();
    error B_INVALID_GAS_LIMIT();
    error B_INVALID_SIGNAL();
    error B_INVALID_TO();
    error B_INVALID_USER();
    error B_INVALID_VALUE();
    error B_NON_RETRIABLE();
    error B_NOT_FAILED();
    error B_NOT_RECEIVED();
    error B_PERMISSION_DENIED();
    error B_RECALLED_ALREADY();
    error B_STATUS_MISMATCH();
}
