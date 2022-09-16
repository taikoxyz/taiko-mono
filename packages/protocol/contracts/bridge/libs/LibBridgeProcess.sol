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
    using LibBridgeInvoke for LibBridgeData.State;
    using LibBridgeRead for AddressResolver;
    using LibBridgeRead for LibBridgeData.State;

    /*********************
     * Internal Functions*
     *********************/

    /**
     * @dev This function can be called by any address, including `message.owner`.
     */
    function processMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        address sender,
        Message memory message,
        bytes memory proof
    ) internal {
        uint256 gasStart = gasleft();
        require(message.destChainId == block.chainid, "B:destChainId mismatch");
        require(
            state.getMessageStatus(message.srcChainId, message.id) ==
                IBridge.MessageStatus.NEW,
            "B:invalid status"
        );
        (bool received, bytes32 messageHash) = resolver.isMessageReceived(
            message,
            proof
        );
        require(received, "B:not received");

        // We deposit Ether first before the message call in case the call
        // will actually consume the Ether.
        if (message.depositValue > 0) {
            // sending ether may end up with another contract calling back to
            // this contract.
            message.owner.sendEther(message.depositValue);
        }

        IBridge.MessageStatus status;
        uint256 refundAmount;
        uint256 invocationGasUsed;
        bool success;

        if (message.to == address(this) || message.to == address(0)) {
            // For these two special addresses, the call will not be actually
            // invoked but will be marked DONE. The callValue will be refunded.
            status = IBridge.MessageStatus.DONE;
            success = true;
            refundAmount = message.callValue;
        } else if (message.gasLimit > 0 || sender == message.owner) {
            invocationGasUsed = gasleft();

            success = state.invokeMessageCall(
                message,
                message.gasLimit == 0 ? gasleft() : message.gasLimit
            );

            status = success
                ? IBridge.MessageStatus.DONE
                : IBridge.MessageStatus.RETRIABLE;

            invocationGasUsed -= gasleft();
        } else {
            revert("B:forbidden");
        }

        state.setMessageStatus(message, status);

        address refundAddress = message.refundAddress == address(0)
            ? message.owner
            : message.refundAddress;

        (uint256 feeRefundAmound, uint256 fees) = _calculateFees(
            message,
            gasStart,
            invocationGasUsed
        );

        if (refundAddress == sender) {
            sender.sendEther(refundAmount + feeRefundAmound + fees);
        } else {
            refundAddress.sendEther(refundAmount + feeRefundAmound);
            sender.sendEther(fees);
        }

        emit LibBridgeData.MessageStatusChanged(
            messageHash,
            message.owner,
            message.srcChainId,
            message.id,
            status,
            success
        );
    }

    /*********************
     * Private Functions *
     *********************/

    /**
     * @dev Calculates the amount of fee Ether that should be refuned
     *      and the amount of fees to message processor.
     */
    function _calculateFees(
        Message memory message,
        uint256 gasStart,
        uint256 invocationGasUsed
    ) private view returns (uint256 feeRefundAmound, uint256 fees) {
        uint256 processingFee = (gasStart -
            gasleft() -
            invocationGasUsed +
            LibBridgeData.MESSAGE_PROCESSING_OVERHEAD).min(
                message.maxProcessingFee
            );

        uint256 invocationFee = message.gasLimit.min(invocationGasUsed) *
            message.gasPrice.min(tx.gasprice);

        fees = processingFee + invocationFee;

        feeRefundAmound =
            message.gasPrice *
            message.gasLimit +
            message.maxProcessingFee -
            fees;
    }
}
