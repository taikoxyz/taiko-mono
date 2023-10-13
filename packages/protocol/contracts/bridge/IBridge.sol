// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BridgeData } from "./BridgeData.sol";

/// @title IRecallableMessageSender
/// @notice An interface that all recallable message senders shall implement.
interface IRecallableMessageSender {
    function onMessageRecalled(BridgeData.Message calldata message)
        external
        payable;
}

/// @title IBridge
/// @notice The bridge used in conjunction with the {ISignalService}.
/// @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
/// not by token vaults.
interface IBridge {
    event SignalSent(address indexed sender, bytes32 msgHash);
    event MessageSent(bytes32 indexed msgHash, BridgeData.Message message);
    event MessageRecalled(bytes32 indexed msgHash);

    /// @notice Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    /// @param message The message to be sent.
    /// @return msgHash The hash of the sent message.
    function sendMessage(BridgeData.Message memory message)
        external
        payable
        returns (bytes32 msgHash);

    /// @notice Processes a message received from another chain.
    /// @param message The message to process.
    /// @param proofs The proofs of the cross-chain transfer.
    function processMessage(
        BridgeData.Message calldata message,
        bytes[] calldata proofs
    )
        external;

    /// @notice Retries executing a message that previously failed on its
    /// destination chain.
    /// @param message The message to retry.
    /// @param isLastAttempt Specifies whether this is the last attempt to send
    /// the message.
    function retryMessage(
        BridgeData.Message calldata message,
        bool isLastAttempt
    )
        external;

    /// @notice Recalls a failed message on its source chain.
    /// @param message The message to be recalled.
    /// @param proofs The proofs of message processing failure.
    function recallMessage(
        BridgeData.Message calldata message,
        bytes[] calldata proofs
    )
        external;

    /// @notice Checks if the message with the given hash has been sent on its
    /// source chain.
    /// @param msgHash The hash of the message.
    /// @return Returns true if the message has been sent, false otherwise.
    function isMessageSent(bytes32 msgHash) external view returns (bool);

    /// @notice Checks if the message with the given hash has been received on
    /// its destination chain.
    /// @param msgHash The hash of the message.
    /// @param srcChainId The source chain ID.
    /// @param proofs The proofs of message receipt.
    /// @return Returns true if the message has been received, false otherwise.
    function isMessageReceived(
        bytes32 msgHash,
        uint256 srcChainId,
        bytes[] calldata proofs
    )
        external
        view
        returns (bool);

    /// @notice Checks if a msgHash has failed on its destination chain.
    /// @param msgHash The hash of the message.
    /// @param destChainId The destination chain ID.
    /// @param proofs The proofs of message failure.
    /// @return Returns true if the message has failed, false otherwise.
    function isMessageFailed(
        bytes32 msgHash,
        uint256 destChainId,
        bytes[] calldata proofs
    )
        external
        view
        returns (bool);

    /// @notice Checks if a failed message has been recalled on its source
    /// chain.
    /// @param msgHash The hash of the message.
    /// @return Returns true if the Ether has been released, false otherwise.
    function isMessageRecalled(bytes32 msgHash) external view returns (bool);

    /// @notice Returns the bridge state context.
    /// @return context The context of the current bridge operation.
    function context()
        external
        view
        returns (BridgeData.Context memory context);
}
