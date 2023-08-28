// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IBridge } from "../IBridge.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibBridgeData } from "./LibBridgeData.sol";

/// @title LibBridgeInvoke
/// @notice This library provides functions for handling the invocation of call
/// messages on the Bridge.
/// The library facilitates the interaction with messages sent across the
/// bridge, allowing for call execution and state updates.
library LibBridgeInvoke {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    error B_GAS_LIMIT();

    /// @notice Invokes a call message on the Bridge.
    /// @param state The current state of the Bridge.
    /// @param message The call message to be invoked.
    /// @param msgHash The hash of the message.
    /// @param gasLimit The gas limit for the message call.
    /// @return success A boolean value indicating whether the message call was
    /// successful.
    /// @dev This function updates the context in the state before and after the
    /// message call.
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
        // Update the context for the message call
        // Should we simply provide the message itself rather than
        // a context object?
        state.ctx = IBridge.Context({
            msgHash: msgHash,
            from: message.from,
            srcChainId: message.srcChainId
        });

        // Perform the message call and capture the success value
        (success,) =
            message.to.call{ value: message.value, gas: gasLimit }(message.data);

        // Reset the context after the message call
        state.ctx = IBridge.Context({
            msgHash: LibBridgeData.MESSAGE_HASH_PLACEHOLDER,
            from: LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            srcChainId: LibBridgeData.CHAINID_PLACEHOLDER
        });
    }
}
