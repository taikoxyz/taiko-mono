// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { IErc721Bridge } from "./erc721/IErc721Bridge.sol";
import { NftBridgeErrors } from "./NftBridgeErrors.sol";
import { LibErc721BridgeData } from "./erc721/libs/LibErc721BridgeData.sol";
// import { LibBridgeProcess } from "./libs/LibBridgeProcess.sol";
// import { LibBridgeRelease } from "./libs/LibBridgeRelease.sol";
// import { LibBridgeRetry } from "./libs/LibBridgeRetry.sol";
import { LibErc721BridgeSend } from "./erc721/libs/LibErc721BridgeSend.sol";
import { LibErc721BridgeStatus } from "./erc721/libs/LibErc721BridgeStatus.sol";

/**
 * This contract is an ERC-721 token bridge contract which is deployed on both L1 and L2.
 * which calls the library implementations. See _IErc721Bridge_ for more details.
 * @dev The code hash for the same address on L1 and L2 may be different.
 * @custom:security-contact hello@taiko.xyz
 */
contract Erc721Bridge is EssentialContract, IErc721Bridge, NftBridgeErrors {
    using LibErc721BridgeData for Message;

    LibErc721BridgeData.State private _state; // 50 slots reserved

    event MessageStatusChanged(
        bytes32 indexed msgHash,
        LibErc721BridgeStatus.MessageStatus status,
        address transactor
    );

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /**
     * Initializer to be called after being deployed behind a proxy.
     * @dev Initializer function to setup the EssentialContract.
     * @param _addressManager The address of the AddressManager contract.
     */
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /**
     * Sends a message from the current chain to the destination chain specified
     * in the message.
     * @dev Sends a message by calling the LibErc721BridgeSend.sendMessageErc721 library
     * function.
     * @param message The message to send. (See IBridge)
     * @return msgHash The hash of the message that was sent.
     */
    function sendMessageErc721(Message calldata message)
        external
        payable
        nonReentrant
        returns (bytes32 msgHash)
    {
        return LibErc721BridgeSend.sendMessageErc721({
            state: _state,
            resolver: AddressResolver(this),
            message: message
        });
    }

    // TODO: Implement them gradually
    /**
     * Releases the Ether locked in the bridge as part of a cross-chain
     * transfer.
     * @dev Releases the Ether by calling the LibBridgeRelease.releaseEther
     * library function.
     * @param message The message containing the details of the Ether transfer.
     * (See IBridge)
     * @param proof The proof of the cross-chain transfer.
     */
    function releaseTokenErc721(
        IErc721Bridge.Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        return;
        // TODO: Implement
        // return LibBridgeRelease.releaseEther({
        //     state: _state,
        //     resolver: AddressResolver(this),
        //     message: message,
        //     proof: proof
        // });
    }

    // /**
    //  * Processes a message received from another chain.
    //  * @dev Processes the message by calling the LibBridgeProcess.processMessage
    //  * library function.
    //  * @param message The message to process.
    //  * @param proof The proof of the cross-chain transfer.
    //  */
    // function processMessage(
    //     Message calldata message,
    //     bytes calldata proof
    // )
    //     external
    //     nonReentrant
    // {
    //     return LibBridgeProcess.processMessage({
    //         state: _state,
    //         resolver: AddressResolver(this),
    //         message: message,
    //         proof: proof
    //     });
    // }

    // /**
    //  * Retries sending a message that previously failed to send.
    //  * @dev Retries the message by calling the LibBridgeRetry.retryMessage
    //  * library function.
    //  * @param message The message to retry.
    //  * @param isLastAttempt Specifies whether this is the last attempt to send
    //  * the message.
    //  */
    // function retryMessage(
    //     Message calldata message,
    //     bool isLastAttempt
    // )
    //     external
    //     nonReentrant
    // {
    //     return LibBridgeRetry.retryMessage({
    //         state: _state,
    //         resolver: AddressResolver(this),
    //         message: message,
    //         isLastAttempt: isLastAttempt
    //     });
    // }

    /**
     * Check if the message with the given hash has been sent.
     * @param msgHash The hash of the message.
     * @return Returns true if the message has been sent, false otherwise.
     */
    function isMessageSentErc721(bytes32 msgHash)
        public
        view
        virtual
        returns (bool)
    {
        return LibErc721BridgeSend.isMessageSentErc721(AddressResolver(this), msgHash);
    }

    /**
     * Check if the message with the given hash has been received.
     * @param msgHash The hash of the message.
     * @param srcChainId The source chain ID.
     * @param proof The proof of message receipt.
     * @return Returns true if the message has been received, false otherwise.
     */
    function isMessageReceivedErc721(
        bytes32 msgHash,
        uint256 srcChainId,
        bytes calldata proof
    )
        public
        view
        virtual
        override
        returns (bool)
    {
        return LibErc721BridgeSend.isMessageReceivedErc721({
            resolver: AddressResolver(this),
            msgHash: msgHash,
            srcChainId: srcChainId,
            proof: proof
        });
    }

    /**
     * Check if the message with the given hash has failed.
     * @param msgHash The hash of the message.
     * @param destChainId The destination chain ID.
     * @param proof The proof of message failure.
     * @return Returns true if the message has failed, false otherwise.
     */
    function isMessageFailedErc721(
        bytes32 msgHash,
        uint256 destChainId,
        bytes calldata proof
    )
        public
        view
        virtual
        override
        returns (bool)
    {
        return LibErc721BridgeStatus.isMessageFailedErc721({
            resolver: AddressResolver(this),
            msgHash: msgHash,
            destChainId: destChainId,
            proof: proof
        });
    }

    /**
     * Get the status of the message with the given hash.
     * @param msgHash The hash of the message.
     * @return Returns the status of the message.
     */
    function getMessageStatusErc721(bytes32 msgHash)
        public
        view
        virtual
        returns (LibErc721BridgeStatus.MessageStatus)
    {
        return LibErc721BridgeStatus.getMessageStatusErc721(msgHash);
    }

    /**
     * Get the current context
     * @return Returns the current context.
     */
    function context() public view returns (Context memory) {
        return _state.ctx;
    }

    // /**
    //  * Check if the Ether associated with the given message hash has been
    //  * released.
    //  * @param msgHash The hash of the message.
    //  * @return Returns true if the Ether has been released, false otherwise.
    //  */
    // function isEtherReleased(bytes32 msgHash) public view returns (bool) {
    //     return _state.etherReleased[msgHash];
    // }

    /**
     * Check if the destination chain with the given ID is enabled.
     * @param _chainId The ID of the chain.
     * @return enabled Returns true if the destination chain is enabled, false
     * otherwise.
     */

    function isDestChainEnabled(uint256 _chainId)
        public
        view
        returns (bool enabled)
    {
        (enabled,) =
            LibErc721BridgeSend.isDestChainEnabled(AddressResolver(this), _chainId);
    }

    /**
     * Compute the hash of a given message.
     * @param message The message to compute the hash for.
     * @return Returns the hash of the message.
     */
    function hashMessage(Message calldata message)
        public
        pure
        override
        returns (bytes32)
    {
        return LibErc721BridgeData.hashMessage(message);
    }

    /**
     * Get the slot associated with a given message hash status.
     * @param msgHash The hash of the message.
     * @return Returns the slot associated with the given message hash status.
     */
    function getMessageStatusSlot(bytes32 msgHash)
        public
        pure
        returns (bytes32)
    {
        return LibErc721BridgeStatus.getMessageStatusSlot(msgHash);
    }
}

contract ProxiedErc721Bridge is Proxied, Erc721Bridge { }
