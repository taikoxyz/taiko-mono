// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IBridge } from "../IBridge.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibBridgeData } from "./LibBridgeData.sol";

/**
 * Entry point for starting a bridge transaction.
 */
library LibBridgeSend {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    error B_INCORRECT_VALUE();
    error B_OWNER_IS_NULL();
    error B_WRONG_CHAIN_ID();
    error B_WRONG_TO_ADDRESS();

    /**
     * Send a message to the Bridge with the details of the request.
     * @dev The Bridge takes custody of the funds, unless the source chain is
     * Taiko,
     * in which case the funds are sent to and managed by the EtherVault.
     * @param state The current state of the Bridge
     * @param resolver The address resolver
     * @param message Specifies the `depositValue`, `callValue`, and
     * `processingFee`.
     * These must sum to `msg.value`. It also specifies the `destChainId`
     * which must have a `bridge` address set on the AddressResolver and
     * differ from the current chain ID.
     * @return msgHash The hash of the sent message.
     * This is picked up by an off-chain relayer which indicates
     * a bridge message has been sent and is ready to be processed on the
     * destination chain.
     */
    function sendMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message memory message
    )
        internal
        returns (bytes32 msgHash)
    {
        if (message.owner == address(0)) {
            revert B_OWNER_IS_NULL();
        }

        (bool destChainEnabled, address destChain) =
            isDestChainEnabled(resolver, message.destChainId);

        if (!destChainEnabled || message.destChainId == block.chainid) {
            revert B_WRONG_CHAIN_ID();
        }
        if (message.to == address(0) || message.to == destChain) {
            revert B_WRONG_TO_ADDRESS();
        }

        uint256 expectedAmount =
            message.depositValue + message.callValue + message.processingFee;

        if (expectedAmount != msg.value) {
            revert B_INCORRECT_VALUE();
        }

        // If on Taiko, send the expectedAmount to the EtherVault. Otherwise,
        // store it here on the Bridge. Processing will release Ether from the
        // EtherVault or the Bridge on the destination chain.
        address ethVault = resolver.resolve("ether_vault", true);
        ethVault.sendEther(expectedAmount);

        message.id = state.nextMessageId++;
        message.sender = msg.sender;
        message.srcChainId = block.chainid;

        msgHash = message.hashMessage();
        // Store a key which is the hash of this contract address and the
        // msgHash, with a value of 1.
        ISignalService(resolver.resolve("signal_service", false)).sendSignal(
            msgHash
        );
        emit LibBridgeData.MessageSent(msgHash, message);
    }

    /**
     * Check if the destination chain is enabled.
     * @param resolver The address resolver
     * @param chainId The destination chain id
     * @return enabled True if the destination chain is enabled
     * @return destBridge The bridge of the destination chain
     */
    function isDestChainEnabled(
        AddressResolver resolver,
        uint256 chainId
    )
        internal
        view
        returns (bool enabled, address destBridge)
    {
        destBridge = resolver.resolve(chainId, "bridge", true);
        enabled = destBridge != address(0);
    }

    /**
     * Check if the message was sent.
     * @param resolver The address resolver
     * @param msgHash The hash of the sent message
     * @return True if the message was sent
     */
    function isMessageSent(
        AddressResolver resolver,
        bytes32 msgHash
    )
        internal
        view
        returns (bool)
    {
        return ISignalService(resolver.resolve("signal_service", false))
            .isSignalSent({ app: address(this), signal: msgHash });
    }

    /**
     * Check if the message was received.
     * @param resolver The address resolver
     * @param msgHash The hash of the received message
     * @param srcChainId The id of the source chain
     * @param proof The proof of message receipt
     * @return True if the message was received
     */
    function isMessageReceived(
        AddressResolver resolver,
        bytes32 msgHash,
        uint256 srcChainId,
        bytes calldata proof
    )
        internal
        view
        returns (bool)
    {
        address srcBridge = resolver.resolve(srcChainId, "bridge", false);
        return ISignalService(resolver.resolve("signal_service", false))
            .isSignalReceived({
            srcChainId: srcChainId,
            app: srcBridge,
            signal: msgHash,
            proof: proof
        });
    }
}
