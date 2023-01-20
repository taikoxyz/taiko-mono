// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../../bridge/libs/LibBridgeData.sol";
import "../../../bridge/libs/LibBridgeStatus.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestLibBridgeData {
    function updateMessageStatus(
        bytes32 signal,
        LibBridgeStatus.MessageStatus status
    ) public {
        LibBridgeStatus.updateMessageStatus(signal, status);
    }

    function getMessageStatus(
        bytes32 signal
    ) public view returns (LibBridgeStatus.MessageStatus) {
        return LibBridgeStatus.getMessageStatus(signal);
    }

    function hashMessage(
        IBridge.Message memory message
    ) public pure returns (bytes32) {
        return LibBridgeData.hashMessage(message);
    }
}
