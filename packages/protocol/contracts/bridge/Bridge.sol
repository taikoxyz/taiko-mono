// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { IBridge } from "./IBridge.sol";
import { BridgeErrors } from "./BridgeErrors.sol";
import { LibBridgeData } from "./libs/LibBridgeData.sol";
import { LibBridgeProcess } from "./libs/LibBridgeProcess.sol";
import { LibBridgeRelease } from "./libs/LibBridgeRelease.sol";
import { LibBridgeRetry } from "./libs/LibBridgeRetry.sol";
import { LibBridgeSend } from "./libs/LibBridgeSend.sol";
import { LibBridgeStatus } from "./libs/LibBridgeStatus.sol";

/**
 * This contract is a Bridge contract which is deployed on both L1 and L2. Mostly
 * a thin wrapper
 * which calls the library implementations. See _IBridge_ for more details.
 * @dev The code hash for the same address on L1 and L2 may be different.
 * @custom:security-contact hello@taiko.xyz
 */
contract Bridge is EssentialContract, IBridge, BridgeErrors {
    using LibBridgeData for Message;

    LibBridgeData.State private _state; // 50 slots reserved

    event MessageStatusChanged(
        bytes32 indexed msgHash,
        LibBridgeStatus.MessageStatus status,
        address transactor
    );

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /// Allow Bridge to receive ETH from the TaikoL1, TokenVault or EtherVault.
    receive() external payable {
        if (
            msg.sender != resolve("token_vault", true)
                && msg.sender != resolve("ether_vault", true)
                && msg.sender != resolve("taiko", true) && msg.sender != owner()
        ) {
            revert B_CANNOT_RECEIVE();
        }
    }

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
     * @dev Sends a message by calling the LibBridgeSend.sendMessage library
     * function.
     * @param message The message to send. (See IBridge)
     * @return msgHash The hash of the message that was sent.
     */
    function sendMessage(Message calldata message)
        external
        payable
        nonReentrant
        returns (bytes32 msgHash)
    {
        return LibBridgeSend.sendMessage({
            state: _state,
            resolver: AddressResolver(this),
            message: message
        });
    }

    /**
     * Releases the Ether locked in the bridge as part of a cross-chain
     * transfer.
     * @dev Releases the Ether by calling the LibBridgeRelease.releaseEther
     * library function.
     * @param message The message containing the details of the Ether transfer.
     * (See IBridge)
     * @param proof The proof of the cross-chain transfer.
     */
    function releaseEther(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        return LibBridgeRelease.releaseEther({
            state: _state,
            resolver: AddressResolver(this),
            message: message,
            proof: proof
        });
    }

    /**
     * Processes a message received from another chain.
     * @dev Processes the message by calling the LibBridgeProcess.processMessage
     * library function.
     * @param message The message to process.
     * @param proof The proof of the cross-chain transfer.
     */
    function processMessage(
        Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        return LibBridgeProcess.processMessage({
            state: _state,
            resolver: AddressResolver(this),
            message: message,
            proof: proof
        });
    }

    /**
     * Retries sending a message that previously failed to send.
     * @dev Retries the message by calling the LibBridgeRetry.retryMessage
     * library function.
     * @param message The message to retry.
     * @param isLastAttempt Specifies whether this is the last attempt to send
     * the message.
     */
    function retryMessage(
        Message calldata message,
        bool isLastAttempt
    )
        external
        nonReentrant
    {
        return LibBridgeRetry.retryMessage({
            state: _state,
            resolver: AddressResolver(this),
            message: message,
            isLastAttempt: isLastAttempt
        });
    }

    /**
     * Check if the message with the given hash has been sent.
     * @param msgHash The hash of the message.
     * @return Returns true if the message has been sent, false otherwise.
     */
    function isMessageSent(bytes32 msgHash)
        public
        view
        virtual
        returns (bool)
    {
        return LibBridgeSend.isMessageSent(AddressResolver(this), msgHash);
    }

    /**
     * Check if the message with the given hash has been received.
     * @param msgHash The hash of the message.
     * @param srcChainId The source chain ID.
     * @param proof The proof of message receipt.
     * @return Returns true if the message has been received, false otherwise.
     */
    function isMessageReceived(
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
        return LibBridgeSend.isMessageReceived({
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
    function isMessageFailed(
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
        return LibBridgeStatus.isMessageFailed({
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
    function getMessageStatus(bytes32 msgHash)
        public
        view
        virtual
        returns (LibBridgeStatus.MessageStatus)
    {
        return LibBridgeStatus.getMessageStatus(msgHash);
    }

    /**
     * Get the current context
     * @return Returns the current context.
     */
    function context() public view returns (Context memory) {
        return _state.ctx;
    }

    /**
     * Check if the Ether associated with the given message hash has been
     * released.
     * @param msgHash The hash of the message.
     * @return Returns true if the Ether has been released, false otherwise.
     */
    function isEtherReleased(bytes32 msgHash) public view returns (bool) {
        return _state.etherReleased[msgHash];
    }

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
            LibBridgeSend.isDestChainEnabled(AddressResolver(this), _chainId);
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
        return LibBridgeData.hashMessage(message);
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
        return LibBridgeStatus.getMessageStatusSlot(msgHash);
    }
}

contract ProxiedBridge is Proxied, Bridge { }
