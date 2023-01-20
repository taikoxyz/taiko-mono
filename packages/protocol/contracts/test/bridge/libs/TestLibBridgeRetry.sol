// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../../common/EssentialContract.sol";
import "../../../bridge/libs/LibBridgeData.sol";
import "../../../bridge/libs/LibBridgeRetry.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestLibBridgeRetry is EssentialContract {
    LibBridgeData.State public state;

    receive() external payable {}

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function retryMessage(
        IBridge.Message calldata message,
        bool lastAttempt
    ) public payable {
        LibBridgeRetry.retryMessage(
            state,
            AddressResolver(this),
            message,
            lastAttempt
        );
    }
}
