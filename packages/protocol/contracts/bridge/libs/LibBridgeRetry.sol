// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibBridgeInvoke.sol";
import "./LibBridgeData.sol";
import "./LibBridgeRead.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeRetry {
    using LibAddress for address;
    using LibBridgeData for Message;
    using LibBridgeData for LibBridgeData.State;
    using LibBridgeInvoke for LibBridgeData.State;
    using LibBridgeRead for LibBridgeData.State;
    using LibBridgeRead for AddressResolver;

    /*********************
     * Internal Functions*
     *********************/

    function retryMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        Message calldata message,
        bytes calldata proof,
        bool lastAttempt
    ) external {
        if (message.gasLimit == 0 || lastAttempt) {
            require(msg.sender == message.owner, "B:denied");
        }

        (bool received, bytes32 messageHash) = resolver.isMessageReceived(
            message,
            proof
        );
        require(received, "B:notReceived");

        require(
            state.messageStatus[messageHash] == IBridge.MessageStatus.RETRIABLE,
            "B:notFound"
        );

        if (state.invokeMessageCall(message, gasleft())) {
            state.updateMessageStatus(messageHash, IBridge.MessageStatus.DONE);
        } else if (lastAttempt) {
            state.updateMessageStatus(messageHash, IBridge.MessageStatus.DONE);

            if (message.callValue > 0) {
                address refundAddress = message.refundAddress == address(0)
                    ? message.owner
                    : message.refundAddress;

                refundAddress.sendEther(message.callValue);
            }
        }
    }
}
