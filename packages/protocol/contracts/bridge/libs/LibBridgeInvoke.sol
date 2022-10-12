// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibBridgeData.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeInvoke {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    /*********************
     * Internal Functions*
     *********************/

    function invokeMessageCall(
        LibBridgeData.State storage state,
        IBridge.Message memory message,
        bytes32 signal,
        uint256 gasLimit
    ) internal returns (bool success) {
        require(gasLimit > 0, "B:gasLimit");

        state.ctx = IBridge.Context({
            signal: signal,
            sender: message.sender,
            srcChainId: message.srcChainId
        });

        (success, ) = message.to.call{value: message.callValue, gas: gasLimit}(
            message.data
        );

        state.ctx = IBridge.Context({
            signal: LibBridgeData.SIGNAL_PLACEHOLDER,
            sender: LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            srcChainId: LibBridgeData.CHAINID_PLACEHOLDER
        });
    }
}
