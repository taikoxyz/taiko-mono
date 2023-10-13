// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BridgeData } from "./BridgeData.sol";

/// @title IRecallableSender
/// @notice An interface that all recallable message senders shall implement.
interface IRecallableSender {
    function onMessageRecalled(BridgeData.Message calldata message)
        external
        payable;
}
