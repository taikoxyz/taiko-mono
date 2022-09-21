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
        uint256 gasStart = gasleft();
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
        message.owner.sendEther(message.depositValue);

        IBridge.MessageStatus status;
        uint256 refundAmount;

        if (message.to == address(this) || message.to == address(0)) {
            // For these two special addresses, the call will not be actually
            // invoked but will be marked DONE. The callValue will be refunded.
            status = IBridge.MessageStatus.DONE;
            refundAmount = message.callValue;
        } else if (message.gasLimit > 0 || message.owner == msg.sender) {
            bool success = state.invokeMessageCall(
                message,
                mhash,
                message.gasLimit == 0 ? gasleft() : message.gasLimit
            );

            status = success
                ? IBridge.MessageStatus.DONE
                : IBridge.MessageStatus.RETRIABLE;
        } else {
            revert("B:forbidden");
        }

        state.updateMessageStatus(mhash, status);

        // Refund processing fees if necessary
        address refundAddress = message.refundAddress == address(0)
            ? message.owner
            : message.refundAddress;

        if (refundAddress == msg.sender) {
            refundAddress.sendEther(refundAmount + message.maxProcessingFee);
        } else {
            uint256 processingCost = tx.gasprice *
                (LibBridgeData.MESSAGE_PROCESSING_OVERHEAD +
                    gasStart -
                    gasleft());
            uint256 processingFee = processingCost.min(
                message.maxProcessingFee
            );

            uint256 processingFeeRefund = message.maxProcessingFee -
                processingFee;

            refundAddress.sendEther(refundAmount + processingFeeRefund);
            msg.sender.sendEther(processingFee);
        }
    }
}
