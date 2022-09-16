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
library LibBridgeSend {
    using LibAddress for address;
    using LibBridgeData for Message;
    using LibBridgeRead for LibBridgeData.State;

    /*********************
     * Internal Functions*
     *********************/

    function sendMessage(
        LibBridgeData.State storage state,
        Message memory message
    ) internal returns (bytes32 mhash) {
        require(
            message.destChainId != block.chainid &&
                state.isDestChainEnabled(message.destChainId),
            "B:destChainId"
        );

        require(message.owner != address(0), "B:owner");

        message.id = state.nextMessageId++;
        message.sender = msg.sender;
        message.srcChainId = block.chainid;

        mhash = message.hashMessage();
        assembly {
            sstore(mhash, 1)
        }

        // TODO(daniel): figure out maxProcessingFee <>  message.gasLimit * message.gasPrice
        uint256 expectedAmount = message.maxProcessingFee +
            message.depositValue +
            message.callValue +
            (message.gasLimit * message.gasPrice);

        require(expectedAmount == msg.value, "B:value");

        emit LibBridgeData.MessageSent(mhash, message);
    }

    function enableDestChain(
        LibBridgeData.State storage state,
        uint256 chainId,
        bool enabled
    ) internal {
        require(chainId > 0 && chainId != block.chainid, "B:chainId");
        state.destChains[chainId] = enabled;
        emit LibBridgeData.DestChainEnabled(chainId, enabled);
    }
}
