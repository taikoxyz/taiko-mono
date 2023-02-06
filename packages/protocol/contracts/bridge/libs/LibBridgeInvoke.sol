// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "./LibBridgeData.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeInvoke {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    /*********************
     * Internal Functions*
     *********************/
    // ERRORS

    error InvalidInvokeMessageGasLimit(uint256 provided, uint256 minimum);

    function invokeMessageCall(
        LibBridgeData.State storage state,
        IBridge.Message calldata message,
        bytes32 msgHash,
        uint256 gasLimit
    ) internal returns (bool success) {
        if (gasLimit == 0)
            revert InvalidInvokeMessageGasLimit({
                provided: gasLimit,
                minimum: 1
            });

        state.ctx = IBridge.Context({
            msgHash: msgHash,
            sender: message.sender,
            srcChainId: message.srcChainId
        });

        (success, ) = message.to.call{value: message.callValue, gas: gasLimit}(
            message.data
        );

        state.ctx = IBridge.Context({
            msgHash: LibBridgeData.MESSAGE_HASH_PLACEHOLDER,
            sender: LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            srcChainId: LibBridgeData.CHAINID_PLACEHOLDER
        });
    }
}
