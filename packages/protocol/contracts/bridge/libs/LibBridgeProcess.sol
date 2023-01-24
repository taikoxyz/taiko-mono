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
 *
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
     *
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
        if (message.gasLimit == 0) {
            require(msg.sender == message.owner, "B:forbidden");
        }

        // The message's destination chain must be the current chain.
        require(message.destChainId == block.chainid, "B:destChainId");

        // The status of the message must be "NEW"; RETRIABLE is handled in
        // LibBridgeRetry.sol
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

        // We retrieve the necessary ether from EtherVault
        address ethVault = resolver.resolve("ether_vault", false);
        if (ethVault != address(0)) {
            EtherVault(payable(ethVault)).releaseEther(
                message.depositValue + message.callValue + message.processingFee
            );
        }
        // We deposit Ether first before the message call in case the call
        // will actually consume the Ether.
        message.owner.sendEther(message.depositValue);

        LibBridgeStatus.MessageStatus status;
        uint256 refundAmount;

        if (message.to == address(this) || message.to == address(0)) {
            // For these two special addresses, the call will not be actually
            // invoked but will be marked DONE. The callValue will be refunded.
            status = LibBridgeStatus.MessageStatus.DONE;
            refundAmount = message.callValue;
        } else {
            uint256 gasLimit = msg.sender == message.owner
                ? gasleft()
                : message.gasLimit;

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

        LibBridgeStatus.updateMessageStatus(msgHash, status);

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
