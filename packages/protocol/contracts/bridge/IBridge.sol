// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

/// @title IBridge
/// @custom:security-contact security@taiko.xyz
/// @notice The bridge used in conjunction with the {ISignalService}.
/// @dev Ether is held by Bridges on L1 and L2s.
interface IBridge {
    struct Message {
        // Message ID.
        uint128 id;
        // The address, EOA or contract, that interacts with this bridge.
        address from;
        // Source chain ID.
        uint64 srcChainId;
        // Destination chain ID where the `to` address lives.
        uint64 destChainId;
        // The owner of the message on the source chain.
        address srcOwner;
        // The owner of the message on the destination chain.
        address destOwner;
        // The destination address on the destination chain.
        address to;
        // Alternate address to send any refund on the destination chain.
        // If blank, defaults to destOwner.
        address refundTo;
        // value to invoke on the destination chain.
        uint256 value;
        // Processing fee for the relayer. Zero if owner will process themself.
        uint256 fee;
        // gasLimit to invoke on the destination chain.
        uint256 gasLimit;
        // callData to invoke on the destination chain.
        bytes data;
        // Optional memo.
        string memo;
    }

    // Struct representing the context of a bridge operation.
    struct Context {
        bytes32 msgHash; // Message hash.
        address from; // Sender's address.
        uint64 srcChainId; // Source chain ID.
    }

    /// @notice Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    /// @param message The message to be sent.
    /// @return rMsgHash The hash of the sent message.
    /// @return rMessage The updated message sent.
    function sendMessage(Message calldata message)
        external
        payable
        returns (bytes32 rMsgHash, Message memory rMessage);

    /// @notice Returns the bridge state context.
    /// @return context The context of the current bridge operation.
    function context() external view returns (Context memory context);
}

/// @title IRecallableSender
/// @notice An interface that all recallable message senders shall implement.
interface IRecallableSender {
    function onMessageRecalled(
        IBridge.Message calldata message,
        bytes32 msgHash
    )
        external
        payable;
}

/// @title IMessageInvocable
/// @notice An interface that all bridge message receiver shall implement
interface IMessageInvocable {
    /// @notice Called when this contract is the bridge target.
    /// @param data The data for this contract to interpret.
    /// @dev This method should be guarded with `onlyFromNamed("bridge")`.
    function onMessageInvocation(bytes calldata data) external payable;
}
