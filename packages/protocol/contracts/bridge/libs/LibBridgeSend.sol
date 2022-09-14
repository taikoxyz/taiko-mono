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
        address sender,
        address refundFeeTo,
        Message memory message
    )
        internal
        returns (
            uint256 height,
            bytes32 signal,
            bytes32 messageHash
        )
    {
        require(
            message.destChainId != LibBridgeRead.chainId() &&
                state.isDestChainEnabled(message.destChainId),
            "B:invalid destChainId"
        );

        message.id = state.nextMessageId++;
        message.sender = sender;
        message.srcChainId = LibBridgeRead.chainId();

        if (message.owner == address(0)) {
            message.owner = sender;
        }

        messageHash = message.hashMessage();
        assembly {
            sstore(messageHash, 1)
        }

        _handleMessageFee(refundFeeTo, message);

        emit LibBridgeData.MessageSent(
            messageHash,
            message.owner,
            message.srcChainId,
            message.id,
            height,
            signal,
            abi.encode(message)
        );
    }

    function enableDestChain(
        LibBridgeData.State storage state,
        uint256 chainId,
        bool enabled
    ) internal {
        require(
            chainId > 0 && chainId != LibBridgeRead.chainId(),
            "B:invalid chainId"
        );
        state.destChains[chainId] = enabled;
        emit LibBridgeData.DestChainEnabled(chainId, enabled);
    }

    /*********************
     * Private Functions *
     *********************/

    function _handleMessageFee(address refundFeeTo, Message memory message)
        private
    {
        uint256 requiredEther = message.maxProcessingFee +
            message.depositValue +
            message.callValue +
            (message.gasLimit * message.gasPrice);

        if (msg.value > requiredEther) {
            refundFeeTo.sendEther(msg.value - requiredEther);
        } else if (msg.value < requiredEther) {
            revert("B:insufficient ether");
        }
    }
}
