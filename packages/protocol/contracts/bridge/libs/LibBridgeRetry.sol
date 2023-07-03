// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {EtherVault} from "../EtherVault.sol";
import {IBridge} from "../IBridge.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {LibBridgeData} from "./LibBridgeData.sol";
import {LibBridgeInvoke} from "./LibBridgeInvoke.sol";
import {LibBridgeStatus} from "./LibBridgeStatus.sol";

/**
 * Retry bridge messages.
 * @title LibBridgeRetry
 */
library LibBridgeRetry {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    error B_DENIED();
    error B_MSG_NON_RETRIABLE();

    /**
     * Retries to invoke the messageCall, the owner has already been sent Ether.
     * - This function can be called by any address, including `message.owner`.
     * - Can only be called on messages marked "RETRIABLE".
     * - It attempts to reinvoke the messageCall.
     * - If it succeeds, the message is marked as "DONE".
     * - If it fails and `isLastAttempt` is set to true, the message is marked
     *   as "FAILED" and cannot be retried.
     * @param state The bridge state.
     * @param resolver The address resolver.
     * @param message The message to retry.
     * @param isLastAttempt Specifies if this is the last attempt to retry the
     * message.
     */
    function retryMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bool isLastAttempt
    ) internal {
        // If the gasLimit is not set to 0 or isLastAttempt is true, the
        // address calling this function must be message.owner.
        if (message.gasLimit == 0 || isLastAttempt) {
            if (msg.sender != message.owner) revert B_DENIED();
        }

        bytes32 msgHash = message.hashMessage();
        if (LibBridgeStatus.getMessageStatus(msgHash) != LibBridgeStatus.MessageStatus.RETRIABLE) {
            revert B_MSG_NON_RETRIABLE();
        }

        address ethVault = resolver.resolve("ether_vault", true);
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).releaseEther(message.callValue);
        }

        // successful invocation
        if (
            LibBridgeInvoke
                // The message.gasLimit only apply for processMessage, if it fails
                // then whoever calls retryMessage will use the tx's gasLimit.
                .invokeMessageCall({
                state: state,
                message: message,
                msgHash: msgHash,
                gasLimit: gasleft()
            })
        ) {
            LibBridgeStatus.updateMessageStatus(msgHash, LibBridgeStatus.MessageStatus.DONE);
        } else if (isLastAttempt) {
            LibBridgeStatus.updateMessageStatus(msgHash, LibBridgeStatus.MessageStatus.FAILED);

            address refundAddress =
                message.refundAddress == address(0) ? message.owner : message.refundAddress;

            refundAddress.sendEther(message.callValue);
        } else {
            ethVault.sendEther(message.callValue);
        }
    }
}
