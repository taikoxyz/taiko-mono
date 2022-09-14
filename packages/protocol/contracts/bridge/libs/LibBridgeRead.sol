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
library LibBridgeRead {
    using LibBridgeData for Message;

    /*********************
     * Internal Functions*
     *********************/

    function isMessageReceived(
        AddressResolver resolver,
        LibBridgeData.State storage state,
        Message memory message,
        bytes memory mkproof
    ) internal view returns (bool received, bytes32 messageHash) {
        messageHash = state.messageIdToHash[message.srcChainId][message.id];

        require(messageHash == message.hashMessage(), "B:invalid message");

        // verify that the messageHash exists in state trie by proving that the messageHash exists in the source chain bridge contract address state
        // verifyMessage(message.bridgeContractAddress, messageHash, mkproof);
    }

    function getMessageStatus(
        LibBridgeData.State storage state,
        uint256 srcChainId,
        uint256 messageId
    ) internal view returns (IBridge.MessageStatus) {
        uint256 bits = state.statusBitmaps[srcChainId][messageId / 128];
        uint256 value = (bits >> ((messageId % 128) << 1)) & 3;
        return IBridge.MessageStatus(value);
    }

    function context(LibBridgeData.State storage state)
        internal
        view
        returns (IBridge.Context memory)
    {
        require(
            state.ctx.srcChainSender !=
                LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            "B:out of context"
        );
        return state.ctx;
    }

    function isDestChainEnabled(
        LibBridgeData.State storage state,
        uint256 _chainId
    ) internal view returns (bool) {
        return state.destChains[_chainId];
    }

    function getMessageFeeAndCapacity(
        AddressResolver resolver // can be removed
    ) internal view returns (uint256 fee, uint256 capacity) {
        // return
        //     ISignalService(resolver.resolve("rollup"))
        //         .getSignalFeeAndCapacity();
    }

    function chainId() internal view returns (uint256 _chainId) {
        assembly {
            _chainId := chainid()
        }
    }
}
