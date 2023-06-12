// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IBridge } from "../IBridge.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibBridgeData } from "./LibBridgeData.sol";

/**
 * This library provides functions for handling message invocations on the
 * Bridge.
 */
library LibBridgeInvoke {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    error B_GAS_LIMIT();

    /**
     * Invoke a call message
     * @param state The current state of the Bridge
     * @param message The call message to be invoked
     * @param msgHash The hash of the message
     * @param gasLimit The gas limit for the message call
     * @return success A boolean value indicating whether the message call was
     * successful
     * @dev This function updates the context in the state before and after the
     * message call.
     */
    function invokeMessageCall(
        LibBridgeData.State storage state,
        IBridge.Message calldata message,
        bytes32 msgHash,
        uint256 gasLimit
    )
        internal
        returns (bool success)
    {
        if (gasLimit == 0) {
            revert B_GAS_LIMIT();
        }

        state.ctx = IBridge.Context({
            msgHash: msgHash,
            sender: message.sender,
            srcChainId: message.srcChainId
        });

        (success,) = message.to.call{ value: message.callValue, gas: gasLimit }(
            message.data
        );

        state.ctx = IBridge.Context({
            msgHash: LibBridgeData.MESSAGE_HASH_PLACEHOLDER,
            sender: LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            srcChainId: LibBridgeData.CHAINID_PLACEHOLDER
        });
    }
}
