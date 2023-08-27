// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { EtherVault } from "../EtherVault.sol";
import { IBridge } from "../IBridge.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibBridgeData } from "./LibBridgeData.sol";
import { LibBridgeInvoke } from "./LibBridgeInvoke.sol";
import { LibBridgeStatus } from "./LibBridgeStatus.sol";
import { LibMath } from "../../libs/LibMath.sol";

/// @title LibBridgeProcess Library
/// @notice This library provides functions for processing bridge messages on
/// the destination chain.
/// The library handles the execution of bridge messages, status updates, and
/// fee refunds.
library LibBridgeProcess {
    using LibMath for uint256;
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    error B_FORBIDDEN();
    error B_SIGNAL_NOT_RECEIVED();
    error B_STATUS_MISMATCH();
    error B_WRONG_CHAIN_ID();

    /// @notice Processes a bridge message on the destination chain. This
    /// function is callable by any address, including the `message.user`.
    /// @dev The process begins by hashing the message and checking the message
    /// status in the bridge state. If the status is "NEW", custody of Ether is
    /// taken from the EtherVault, and the message is invoked. The status is
    /// updated accordingly, and processing fees are refunded as needed.
    /// @param state The state of the bridge.
    /// @param resolver The address resolver.
    /// @param message The message to be processed.
    /// @param proof The proof of the message hash from the source chain.
    /// @param checkProof A boolean flag indicating whether to verify the signal
    /// receipt proof.
    function processMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof,
        bool checkProof
    )
        internal
    {
        // If the gas limit is set to zero, only the user can process the
        // message.
        if (message.gasLimit == 0 && msg.sender != message.user) {
            revert B_FORBIDDEN();
        }

        if (message.destChainId != block.chainid) {
            revert B_WRONG_CHAIN_ID();
        }

        // The message status must be "NEW"; "RETRIABLE" is managed in
        // LibBridgeRetry.sol.
        bytes32 msgHash = message.hashMessage();
        if (
            LibBridgeStatus.getMessageStatus(msgHash)
                != LibBridgeStatus.MessageStatus.NEW
        ) {
            revert B_STATUS_MISMATCH();
        }

        // Check if the signal has been received on the source chain
        address srcBridge =
            resolver.resolve(message.srcChainId, "bridge", false);

        if (
            checkProof
                && !ISignalService(resolver.resolve("signal_service", false))
                    .isSignalReceived({
                    srcChainId: message.srcChainId,
                    app: srcBridge,
                    signal: msgHash,
                    proof: proof
                })
        ) {
            revert B_SIGNAL_NOT_RECEIVED();
        }

        // Release necessary Ether from EtherVault if on Taiko, otherwise it's
        // already available on this Bridge.
        address ethVault = resolver.resolve("ether_vault", true);
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).releaseEther(
                address(this), message.value + message.fee
            );
        }

        LibBridgeStatus.MessageStatus status;
        uint256 refundAmount;

        // Process message differently based on the target address
        if (message.to == address(this) || message.to == address(0)) {
            // Handle special addresses that don't require actual invocation but
            // mark message as DONE
            status = LibBridgeStatus.MessageStatus.DONE;
            refundAmount = message.value;
        } else {
            // Use the specified message gas limit if called by the user, else
            // use remaining gas
            uint256 gasLimit =
                msg.sender == message.user ? gasleft() : message.gasLimit;

            bool success = LibBridgeInvoke.invokeMessageCall({
                state: state,
                message: message,
                msgHash: msgHash,
                gasLimit: gasLimit
            });

            if (success) {
                status = LibBridgeStatus.MessageStatus.DONE;
            } else {
                status = LibBridgeStatus.MessageStatus.RETRIABLE;
                ethVault.sendEther(message.value);
            }
        }

        // Update the message status
        LibBridgeStatus.updateMessageStatus(msgHash, status);

        // Determine the refund recipient
        address refundTo =
            message.refundTo == address(0) ? message.user : message.refundTo;

        // Refund the processing fee
        if (msg.sender == refundTo) {
            uint256 amount = message.fee + refundAmount;
            refundTo.sendEther(amount);
        } else {
            // If sender is another address, reward it and refund the rest
            msg.sender.sendEther(message.fee);
            refundTo.sendEther(refundAmount);
        }
    }
}
