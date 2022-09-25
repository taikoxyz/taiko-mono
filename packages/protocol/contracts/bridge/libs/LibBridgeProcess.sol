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
import "./LibBridgeRead.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeProcess {
    using LibMath for uint256;
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;
    using LibBridgeInvoke for LibBridgeData.State;
    using LibBridgeRead for LibBridgeData.State;

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
        bytes32 mhash = message.hashMessage();
        require(
            state.messageStatus[mhash] == IBridge.MessageStatus.NEW,
            "B:status"
        );
        // Message must have been "received" on the destChain (current chain)
        require(
            LibBridgeRead.isMessageReceived(
                resolver,
                mhash,
                message.srcChainId,
                proof
            ),
            "B:notReceived"
        );

        // We deposit Ether first before the message call in case the call
        // will actually consume the Ether.
        address ethVault = resolver.resolve("ether_vault");
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).receiveEther(
                message.depositValue + message.callValue + message.processingFee
            );
        }

        message.owner.sendEther(message.depositValue);

        IBridge.MessageStatus status;
        uint256 refundAmount;

        if (message.to == address(this) || message.to == address(0)) {
            // For these two special addresses, the call will not be actually
            // invoked but will be marked DONE. The callValue will be refunded.
            status = IBridge.MessageStatus.DONE;
            refundAmount = message.callValue;
        } else {
            uint gasLimit = msg.sender == message.owner ?
                gasleft() :
                message.gasLimit;
            bool success = state.invokeMessageCall(
                message,
                mhash,
                gasLimit
            );

            if (success) {
                status = IBridge.MessageStatus.DONE;
            } else {
                status = IBridge.MessageStatus.RETRIABLE;
                if (ethVault != address(0)) {
                    ethVault.sendEther(message.callValue);
                }
            }
        }

        state.updateMessageStatus(mhash, status);

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
