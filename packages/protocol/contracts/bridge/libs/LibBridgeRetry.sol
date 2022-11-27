// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../EtherVault.sol";
import "./LibBridgeInvoke.sol";
import "./LibBridgeData.sol";

/**
 * Retry bridge messages.
 *
 * @title LibBridgeRetry
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeRetry {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    /**
     * Retry a bridge message on the destination chain. This function can be
     * called by any address, including `message.owner`. It can only be called
     * on messages marked "RETRIABLE". It attempts to reinvoke the messageCall.
     * If reinvoking fails and `isLastAttempt` is set to true, then the message
     * is marked "DONE" and cannot be retried.
     *
     * @param state The bridge state.
     * @param resolver The address resolver.
     * @param message The message to retry.
     * @param isLastAttempt Specifies if this is the last attempt to retry the
     *        message.
     */
    function retryMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bool isLastAttempt
    ) external {
        // If the gasLimit is not set to 0 or isLastAttempt is true, the
        // address calling this function must be message.owner.
        if (message.gasLimit == 0 || isLastAttempt) {
            require(msg.sender == message.owner, "B:denied");
        }

        bytes32 signal = message.hashMessage();
        require(
            state.messageStatus[signal] ==
                LibBridgeData.MessageStatus.RETRIABLE,
            "B:notFound"
        );

        address ethVault = resolver.resolve("ether_vault");
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).receiveEther(message.callValue);
        }

        // successful invocation
        if (
            LibBridgeInvoke.invokeMessageCall({
                state: state,
                message: message,
                signal: signal,
                gasLimit: gasleft()
            })
        ) {
            state.updateMessageStatus(signal, LibBridgeData.MessageStatus.DONE);
        } else if (isLastAttempt) {
            state.updateMessageStatus(signal, LibBridgeData.MessageStatus.DONE);

            address refundAddress = message.refundAddress == address(0)
                ? message.owner
                : message.refundAddress;

            refundAddress.sendEther(message.callValue);
        } else if (ethVault != address(0)) {
            ethVault.sendEther(message.callValue);
        }
    }
}
