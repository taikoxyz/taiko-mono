// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../signal/ISignalService.sol";
import "../EtherVault.sol";
import "./LibBridgeData.sol";
import "./LibBridgeInvoke.sol";
import "./LibBridgeStatus.sol";

/**
 * Process bridge messages on the destination chain.
 * @title LibBridgeProcess
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeProcess {
    using LibMath for uint256;
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeData for LibBridgeData.State;

    /**
     * Process the bridge message on the destination chain. It can be called by
     * any address, including `message.owner`. It starts by hashing the message,
     * and doing a lookup in the bridge state to see if the status is "NEW". It
     * then takes custody of the ether from the EtherVault and attempts to
     * invoke the messageCall, changing the message's status accordingly.
     * Finally, it refunds the processing fee if needed.
     * @param state The bridge state.
     * @param resolver The address resolver.
     * @param message The message to process.
     * @param proof The msgHash proof from the source chain.
     */
    function processMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    ) external {
        // If the gas limit is set to zero, only the owner can process the message.
        if (message.gasLimit == 0) {
            require(msg.sender == message.owner, "B:forbidden");
        }

        require(message.destChainId == block.chainid, "B:destChainId");

        // The message status must be "NEW"; "RETRIABLE" is handled in
        // LibBridgeRetry.sol.
        bytes32 msgHash = message.hashMessage();
        require(
            LibBridgeStatus.getMessageStatus(msgHash) ==
                LibBridgeStatus.MessageStatus.NEW,
            "B:status"
        );
        // Message must have been "received" on the destChain (current chain)
        address srcBridge = resolver.resolve(
            message.srcChainId,
            "bridge",
            false
        );

        require(
            ISignalService(resolver.resolve("signal_service", false))
                .isSignalReceived({
                    srcChainId: message.srcChainId,
                    app: srcBridge,
                    signal: msgHash,
                    proof: proof
                }),
            "B:notReceived"
        );

        // We retrieve the necessary ether from EtherVault if receiving on
        // Taiko, otherwise it is already available in this Bridge.
        address ethVault = resolver.resolve("ether_vault", true);
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).releaseEther(
                message.depositValue + message.callValue + message.processingFee
            );
        }
        // We send the Ether before the message call in case the call will
        // actually consume Ether.
        message.owner.sendEther(message.depositValue);

        LibBridgeStatus.MessageStatus status;
        uint256 refundAmount;

        // if the user is sending to the bridge or zero-address, just process as DONE
        // and refund the owner
        if (message.to == address(this) || message.to == address(0)) {
            // For these two special addresses, the call will not be actually
            // invoked but will be marked DONE. The callValue will be refunded.
            status = LibBridgeStatus.MessageStatus.DONE;
            refundAmount = message.callValue;
        } else {
            // use the specified message gas limit if not called by the owner
            uint256 gasLimit = msg.sender == message.owner
                ? gasleft()
                : message.gasLimit;

            // this will call receiveERC20 on the tokenVault, sending the tokens to the user
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
                if (ethVault != address(0)) {
                    ethVault.sendEther(message.callValue);
                }
            }
        }

        // Mark the status as DONE or RETRIABLE.
        LibBridgeStatus.updateMessageStatus(msgHash, status);

        address refundAddress = message.refundAddress == address(0)
            ? message.owner
            : message.refundAddress;

        // if sender is the refundAddress
        if (msg.sender == refundAddress) {
            refundAddress.sendEther(message.processingFee + refundAmount);
        } else {
            // if sender is another address (eg. the relayer)
            // First attempt relayer is rewarded the processingFee
            // message.owner has to eat the cost
            msg.sender.sendEther(message.processingFee);
            refundAddress.sendEther(refundAmount);
        }
    }
}
