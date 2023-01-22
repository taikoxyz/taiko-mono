// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../../bridge/libs/LibBridgeInvoke.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestLibBridgeInvoke {
    LibBridgeData.State public state;

    event MessageInvoked(bytes32 signal, bool success);

    function invokeMessageCall(
        IBridge.Message calldata message,
        bytes32 signal,
        uint256 gasLimit
    ) public payable {
        bool success = LibBridgeInvoke.invokeMessageCall(
            state,
            message,
            signal,
            gasLimit
        );
        emit MessageInvoked(signal, success);
    }
}
