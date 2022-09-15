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
import "./LibBridgeRead.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeInvoke {
    using LibAddress for address;
    using LibBridgeData for Message;
    using LibBridgeRead for LibBridgeData.State;

    /*********************
     * Internal Functions*
     *********************/

    function invokeMessageCall(
        LibBridgeData.State storage state,
        Message memory message,
        uint256 gasLimit
    ) internal returns (bool success) {
        require(gasLimit > 0, "B:gasLimit");

        state.ctx = IBridge.Context({
            srcChainSender: message.sender,
            srcChainId: message.srcChainId,
            destChainId: message.destChainId
        });

        (success, ) = message.to.call{value: message.callValue, gas: gasLimit}(
            message.data
        );

        state.ctx = IBridge.Context({
            srcChainSender: LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            srcChainId: LibBridgeData.CHAINID_PLACEHOLDER,
            destChainId: LibBridgeData.CHAINID_PLACEHOLDER
        });
    }

    // TODO: add comment and get back to Roger
    function setMessageStatus(
        LibBridgeData.State storage state,
        Message memory message,
        IBridge.MessageStatus status
    ) internal {
        uint256 idx = message.id / 128;
        uint256 offset = (message.id % 128) << 1;
        uint256 bitmap = state.statusBitmaps[message.srcChainId][idx];
        // [prefix][2bit][postfix]
        uint256 _bitmap = bitmap >> (offset + 2); // prefix
        _bitmap <<= 2; // [prefix][0-2bit]
        _bitmap |= uint256(status); // [prefix][2bit]
        _bitmap <<= offset; // [prefix][2bit][0-postfix]

        uint256 y = 256 - offset;
        _bitmap |= (bitmap << y) >> y; // [prefix][2bit][postfix]

        state.statusBitmaps[message.srcChainId][idx] = _bitmap;
    }
}
