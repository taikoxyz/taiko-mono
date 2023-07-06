// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC721Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { AddressResolver } from "../../../common/AddressResolver.sol";
import { IErc721Bridge } from "../IErc721Bridge.sol";
import { ISignalService } from "../../../signal/ISignalService.sol";
import { LibAddress } from "../../../libs/LibAddress.sol";
import { LibErc721BridgeData } from "./LibErc721BridgeData.sol";

/**
 * Entry point for starting a bridge transaction.
 */
library LibErc721BridgeSend {
    using LibAddress for address;
    using LibErc721BridgeData for IErc721Bridge.Message;

    error B_INCORRECT_VALUE();
    error ERC721_B_OWNER_IS_NULL();
    error ERC721_B_WRONG_CHAIN_ID();
    error ERC721_B_WRONG_TO_ADDRESS();

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
    function sendMessageErc721(
        LibErc721BridgeData.State storage state,
        AddressResolver resolver,
        IErc721Bridge.Message memory message
    )
        internal
        returns (bytes32 msgHash)
    {
        if (message.owner == address(0)) {
            revert ERC721_B_OWNER_IS_NULL();
        }

        (bool destChainEnabled, address destChain) =
            isDestChainEnabled(resolver, message.destChainId);

        if (!destChainEnabled || message.destChainId == block.chainid) {
            revert ERC721_B_WRONG_CHAIN_ID();
        }
        if (message.to == address(0) || message.to == destChain) {
            revert ERC721_B_WRONG_TO_ADDRESS();
        }

        // Send tokens to vault
        address tokenVault = resolver.resolve("erc721_vault", true);

        // User has to accept address(this) to transfer NFT tokens on behalf
        for (uint256 i; i < message.tokenIds.length; i++) {
            IERC721Upgradeable(message.tokenContract).safeTransferFrom(
                message.owner, tokenVault, message.tokenIds[i]);
        }

        message.id = state.nextMessageId++;
        message.sender = msg.sender;
        message.srcChainId = block.chainid;

        msgHash = message.hashMessage();
        // Store a key which is the hash of this contract address and the
        // msgHash, with a value of 1.
        ISignalService(resolver.resolve("signal_service", false)).sendSignal(
            msgHash
        );
        emit LibErc721BridgeData.MessageSentErc721(msgHash, message);
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
        destBridge = resolver.resolve(chainId, "erc721_bridge", true);
        enabled = destBridge != address(0);
    }

    /**
     * Check if the message was sent.
     * @param resolver The address resolver
     * @param msgHash The hash of the sent message
     * @return True if the message was sent
     */
    function isMessageSentErc721(
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
    function isMessageReceivedErc721(
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
