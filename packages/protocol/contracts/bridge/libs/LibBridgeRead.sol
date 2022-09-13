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
        Message memory message,
        bytes memory mkproof
    ) internal view returns (bool received, bytes32 messageHash) {
        messageHash = message.hashMessage();
        // received = ISignalService(resolver.resolve("rollup")).isSignalValid(
        //     resolver.resolve(
        //         string(abi.encodePacked(message.srcChainId, ".bridge"))
        //     ),
        //     messageHash,
        //     mkproof
        // );
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
            state.ctx.xchainSender != LibBridgeData.XCHAIN_SENDER_DEFAULT,
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

    function getMessageFeeAndCapacity(AddressResolver resolver)
        internal
        view
        returns (uint256 fee, uint256 capacity)
    {
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
