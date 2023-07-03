// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {EssentialContract} from "../../../common/EssentialContract.sol";
import {LibBridgeProcess} from "../../../bridge/libs/LibBridgeProcess.sol";
import {LibBridgeData} from "../../../bridge/libs/LibBridgeData.sol";
import {IBridge} from "../../../bridge/IBridge.sol";
import {AddressResolver} from "../../../common/AddressResolver.sol";

// TODO(roger): remove this file. If you need extra functionality in
// the Bridge contract, create a TestBridge.sol contract instead.
contract TestLibBridgeProcess is EssentialContract {
    LibBridgeData.State public state;

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function processMessage(IBridge.Message calldata message, bytes calldata proof)
        public
        payable
    {
        LibBridgeProcess.processMessage(state, AddressResolver(this), message, proof);
    }
}
