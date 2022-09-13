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
        AddressResolver resolver,
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

        // ISignalService signalService = ISignalService(
        //     resolver.resolve("rollup")
        // );

        uint256 fee;
        // uint256 capacity;
        // = signalService
        //     .getSignalFeeAndCapacity();
        // require(capacity > 0, "B:out of capacity");

        messageHash = message.hashMessage();

        // `signalFee` is paid to the Rollup contract.
        // (height, signal) = signalService.sendSignal{value: fee}(
        //     messageHash,
        //     address(0) // the signal fee refund amount is 0.
        // );

        _handleMessageFee(refundFeeTo, fee, message);

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

    function _handleMessageFee(
        address refundFeeTo,
        uint256 signalFee,
        Message memory message
    ) private {
        uint256 requiredEther = signalFee +
            message.maxProcessingFee +
            message.depositValue +
            message.callValue +
            (message.gasLimit * message.gasPrice);

        if (msg.value > requiredEther) {
            refundFeeTo.sendEther(msg.value - requiredEther);
        } else if (msg.value < requiredEther) {
            revert("B:insufficient ether");
        }

        // Important note:
        // All remaining ether, which equals (requiredEther - signalFee)
        // stay in this contract.
        //
        // The remote bridge will also have ether to credit to the message owner.
    }
}
