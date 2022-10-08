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
import "./LibBridgeSignal.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeProcess {
    using LibMath for uint256;
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    /**
     * @dev This function can be called by any address, including `message. owner`.
     * It "processes" the message, i.e. takes custody of the attached ether,
     * attempts to invoke the messageCall, changes the message's status accordingly.
     * Also refunds processing fee if necessary.
     */
    function processMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    ) external {
        if (message.gasLimit == 0) {
            require(msg.sender == message.owner, "B:forbidden");
        }

        // The message's destination chain must be the current chain.
        require(message.destChainId == block.chainid, "B:destChainId");

        // The status of the message must be "NEW"; RETRIABLE is handled in
        // LibBridgeRetry.sol
        bytes32 signal = message.hashMessage();
        require(
            state.messageStatus[signal] == LibBridgeData.MessageStatus.NEW,
            "B:status"
        );
        // Message must have been "received" on the destChain (current chain)
        address srcBridge = resolver.resolve(message.srcChainId, "bridge");
        require(
            LibBridgeSignal.isSignalReceived(
                resolver,
                srcBridge,
                srcBridge,
                signal,
                proof
            ),
            "B:notReceived"
        );

        // We retrieve the necessary ether from EtherVault
        address ethVault = resolver.resolve("ether_vault");
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).receiveEther(
                message.depositValue + message.callValue + message.processingFee
            );
        }
        // We deposit Ether first before the message call in case the call
        // will actually consume the Ether.
        message.owner.sendEther(message.depositValue);

        LibBridgeData.MessageStatus status;
        uint256 refundAmount;

        if (message.to == address(this) || message.to == address(0)) {
            // For these two special addresses, the call will not be actually
            // invoked but will be marked DONE. The callValue will be refunded.
            status = LibBridgeData.MessageStatus.DONE;
            refundAmount = message.callValue;
        } else {
            uint256 gasLimit = msg.sender == message.owner
                ? gasleft()
                : message.gasLimit;
            bool success = LibBridgeInvoke.invokeMessageCall(
                state,
                message,
                signal,
                gasLimit
            );

            if (success) {
                status = LibBridgeData.MessageStatus.DONE;
            } else {
                status = LibBridgeData.MessageStatus.RETRIABLE;
                if (ethVault != address(0)) {
                    ethVault.sendEther(message.callValue);
                }
            }
        }

        state.updateMessageStatus(signal, status);

        address refundAddress = message.refundAddress == address(0)
            ? message.owner
            : message.refundAddress;

        if (msg.sender == refundAddress) {
            refundAddress.sendEther(refundAmount + message.processingFee);
        } else {
            // First attempt relayer gets the processingFee
            // message.owner has to eat the cost.
            msg.sender.sendEther(message.processingFee);
            refundAddress.sendEther(refundAmount);
        }
    }
}
