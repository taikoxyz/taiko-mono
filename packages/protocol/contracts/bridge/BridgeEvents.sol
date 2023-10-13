// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BridgeData } from "./BridgeData.sol";

/// @title BridgeEvents
/// @notice This abstract contract provides event declarations for the Bridge.
/// @dev The events defined here must match the definitions in the corresponding
/// libraries.
abstract contract BridgeEvents {
    event SignalSent(address indexed sender, bytes32 msgHash);
    event MessageSent(bytes32 indexed msgHash, BridgeData.Message message);
    event MessageRecalled(bytes32 indexed msgHash);
}
