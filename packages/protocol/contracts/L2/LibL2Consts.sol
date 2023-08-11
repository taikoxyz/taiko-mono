// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title LibL2Consts
/// @notice This library contains constants related to Layer 2 operations.
library LibL2Consts {
    // Gas cost associated with the anchor transaction.
    uint32 public constant ANCHOR_GAS_COST = 180_000; // owner: david
}
