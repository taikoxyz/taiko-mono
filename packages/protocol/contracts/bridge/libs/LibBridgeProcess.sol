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
    using LibBridgeData for Message;
    using LibBridgeData for LibBridgeData.State;
    using LibBridgeInvoke for LibBridgeData.State;
    using LibBridgeRead for LibBridgeData.State;

    /**
     * @dev This function can be called by any address, including `message.owner`.
     */
    function processMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        Message calldata message,
        bytes calldata proof
    ) external {
        uint256 gasStart = gasleft();

        require(message.destChainId == block.chainid, "B:destChainId");

        bytes32 mhash = message.hashMessage();
        require(
            state.messageStatus[mhash] == IBridge.MessageStatus.NEW,
            "B:status"
        );
        require(
            LibBridgeRead.isMessageReceived(resolver, mhash, proof),
            "B:notReceived"
        );

        // We deposit Ether first before the message call in case the call
        // will actually consume the Ether.
        if (message.depositValue > 0) {
            // sending ether may end up with another contract calling back to
            // this contract.
            message.owner.sendEther(message.depositValue);
        }

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
            uint256 processingCost = tx.gasprice * (gasStart - gasleft());
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
