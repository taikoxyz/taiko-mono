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
import { LibBridgeRecall } from "./libs/LibBridgeRecall.sol";
import { LibBridgeRetry } from "./libs/LibBridgeRetry.sol";
import { LibBridgeSend } from "./libs/LibBridgeSend.sol";
import { LibBridgeStatus } from "./libs/LibBridgeStatus.sol";

/**
 * @title Bridge
 * @notice This contract is a Bridge contract deployed on both L1 and L2 chains.
 * The contract acts as a thin wrapper around the library implementations and
 * follows the IBridge interface. It enables the communication and management of
 * bridge messages between different chains.
 * @dev The code hash for the same address on L1 and L2 may differ.
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

    receive() external payable { }

    /**
     * @notice Initializes the contract after being deployed behind a proxy.
     * @dev Initializer function to set up the EssentialContract.
     * @param _addressManager The address of the AddressManager contract.
     */
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /**
     * @notice Sends a message from the current chain to the specified
     * destination chain.
     * @dev Calls the LibBridgeSend.sendMessage library function to send a
     * message.
     * @param message The message to be sent (See IBridge).
     * @return msgHash The hash of the sent message.
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
     * @notice Recalls a failed message on its source chain.
     * @dev Releases locked Ether or tokens and updates message status.
     * @param message The message containing Ether details (See IBridge).
     * @param proof The proof of the cross-chain transfer.
     */
    function recallMessage(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        return LibBridgeRecall.recallMessage({
            state: _state,
            resolver: AddressResolver(this),
            message: message,
            proof: proof,
            checkProof: shouldCheckProof()
        });
    }

    /**
     * @notice Processes a message received from another chain.
     * @dev Calls the LibBridgeProcess.processMessage library function to
     * process a message.
     * @param message The message to be processed.
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
            proof: proof,
            checkProof: shouldCheckProof()
        });
    }

    /**
     * @notice Retries sending a previously failed message.
     * @dev Calls the LibBridgeRetry.retryMessage library function to retry
     * sending a message.
     * @param message The message to be retried.
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
     * @notice Checks, on the source chain, if the message with the given hash
     * has been sent.
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
     * @notice Checks, on the destination chain, whether the message with the
     * given hash has been received.
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
     * @notice Checks, on the source chain, whether a bridge message has failed
     * on its destination chain.
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
     * @notice Get, on the desination chain, the status of a bridge message.
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
     * @notice Gets the current context
     * @return Returns the current context.
     */

    function context() public view returns (Context memory) {
        return _state.ctx;
    }

    /**
     * @notice Checks if the Ether associated with a given message hash has been
     * released.
     * @param msgHash The hash of the message.
     * @return Returns true if the message has been recalled.
     */
    function isMessageRecalled(bytes32 msgHash) public view returns (bool) {
        return _state.recalls[msgHash];
    }

    /**
     * @notice Checks if the destination chain with the given ID is enabled.
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
     * @notice Computes the hash of a given message.
     * @param message The message to compute the hash for.
     * @return Returns the hash of the message.
     */
    function hashMessage(Message calldata message)
        public
        pure
        returns (bytes32)
    {
        return LibBridgeData.hashMessage(message);
    }

    /**
     * @notice Gets the slot associated with a given message hash status.
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

    /**
     * @notice Tells if we need to check real proof or it is a test.
     * @return Returns true if this contract, or can be false if mock/test.
     */
    function shouldCheckProof() internal pure virtual returns (bool) {
        return true;
    }
}

contract ProxiedBridge is Proxied, Bridge { }
