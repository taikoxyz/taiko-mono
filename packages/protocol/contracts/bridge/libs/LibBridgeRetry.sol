// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { EtherVault } from "../EtherVault.sol";
import { IBridge } from "../IBridge.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibBridgeData } from "./LibBridgeData.sol";
import { LibBridgeInvoke } from "./LibBridgeInvoke.sol";
import { LibBridgeStatus } from "./LibBridgeStatus.sol";

/// @title LibBridgeRetry
/// @notice This library provides functions for retrying bridge messages that
/// are marked as "RETRIABLE".
/// The library facilitates the process of invoking the messageCall after
/// releasing any associated Ether, allowing for retries.
/// It handles the transition of message status from "RETRIABLE" to "DONE" on
/// success, and to "FAILED" on the last attempt if unsuccessful.
library LibBridgeRetry {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    error B_DENIED();
    error B_MSG_NON_RETRIABLE();

    /// @notice Retries to invoke the messageCall after releasing associated
    /// Ether and tokens.
    /// @dev This function can be called by any address, including the
    /// `message.user`.
    /// It attempts to invoke the messageCall and updates the message status
    /// accordingly.
    /// @param state The current state of the Bridge.
    /// @param resolver The address resolver.
    /// @param message The message to retry.
    /// @param isLastAttempt Specifies if this is the last attempt to retry the
    /// message.
    function retryMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bool isLastAttempt
    )
        internal
    {
        // If the gasLimit is set to 0 or isLastAttempt is true, the caller must
        // be the message.user.
        if (message.gasLimit == 0 || isLastAttempt) {
            if (msg.sender != message.user) revert B_DENIED();
        }

        bytes32 msgHash = message.hashMessage();
        if (
            LibBridgeStatus.getMessageStatus(msgHash)
                != LibBridgeStatus.MessageStatus.RETRIABLE
        ) {
            revert B_MSG_NON_RETRIABLE();
        }

        // Release necessary Ether from EtherVault if on Taiko, otherwise it's
        // already available on this Bridge.
        address ethVault = resolver.resolve("ether_vault", true);
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).releaseEther(
                address(this), message.value
            );
        }

        // Attempt to invoke the messageCall.
        bool success = LibBridgeInvoke.invokeMessageCall({
            state: state,
            message: message,
            msgHash: msgHash,
            gasLimit: gasleft()
        });

        if (success) {
            // Update the message status to "DONE" on successful invocation.
            LibBridgeStatus.updateMessageStatus(
                msgHash, LibBridgeStatus.MessageStatus.DONE
            );
        } else {
            // Update the message status to "FAILED"
            LibBridgeStatus.updateMessageStatus(
                msgHash, LibBridgeStatus.MessageStatus.FAILED
            );
            // Release Ether back to EtherVault (if on Taiko it is OK)
            // otherwise funds stay at Bridge anyways.
            ethVault.sendEther(message.value);
        }
    }
}
