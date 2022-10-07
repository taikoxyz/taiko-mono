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

/// @author dantaik <dan@taiko.xyz>
library LibBridgeRetry {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    /**
     * @dev This function can be called by any address including 'message.owner'.
     * It can only be called on messages marked "RETRIABLE".
     * It attempts to reinvoke the messageCall.
     * If invoking fails and the message owner marks lastAttempt
     * as true, the message is marked "DONE" and cannot be retried.
     */
    function retryMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bool lastAttempt
    ) external {
        // If the gasLimit is not set to 0 or lastAttempt is true, the
        // address calling this function must be message.owner.
        if (message.gasLimit == 0 || lastAttempt) {
            require(msg.sender == message.owner, "B:denied");
        }

        bytes32 signal = message.hashMessage();
        require(
            state.messageStatus[signal] == IBridge.MessageStatus.RETRIABLE,
            "B:notFound"
        );

        address ethVault = resolver.resolve("ether_vault");
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).receiveEther(message.callValue);
        }

        // successful invocation
        if (
            LibBridgeInvoke.invokeMessageCall(state, message, signal, gasleft())
        ) {
            state.updateMessageStatus(signal, IBridge.MessageStatus.DONE);
        } else if (lastAttempt) {
            state.updateMessageStatus(signal, IBridge.MessageStatus.DONE);

            address refundAddress = message.refundAddress == address(0)
                ? message.owner
                : message.refundAddress;

            refundAddress.sendEther(message.callValue);
        } else if (ethVault != address(0)) {
            ethVault.sendEther(message.callValue);
        }
    }
}
