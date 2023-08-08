// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibBridgeData } from "./libs/LibBridgeData.sol";
/**
 * An interface that all recallable message sender shall implement.
 */

interface IRecallableMessageSender {
    function onMessageRecalled(IBridge.Message calldata message)
        external
        payable;
}

/**
 * Bridge interface.
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
 * not by token vaults.
 */
interface IBridge {
    struct Message {
        // Message ID.
        uint256 id;
        // Message sender address (auto filled).
        address from;
        // Source chain ID (auto filled).
        uint256 srcChainId;
        // Destination chain ID where the `to` address lives (auto filled).
        uint256 destChainId;
        // User address of the bridged asset.
        address user;
        // Destination user address.
        address to;
        // Alternate address to send any refund. If blank, defaults to user.
        address refundAddress;
        // value to invoke on the destination chain, for ERC20 transfers.
        uint256 value;
        // Processing fee for the relayer. Zero if user will process themself.
        uint256 fee;
        // gasLimit to invoke on the destination chain, for ERC20 transfers.
        uint256 gasLimit;
        // callData to invoke on the destination chain, for ERC20 transfers.
        bytes data;
        // Optional memo.
        string memo;
    }

    struct Context {
        bytes32 msgHash; // messageHash
        address from;
        uint256 srcChainId;
    }

    event SignalSent(address indexed sender, bytes32 msgHash);
    event MessageSent(bytes32 indexed msgHash, Message message);
    event MessageRecalled(bytes32 indexed msgHash);

    /// Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    function sendMessage(Message memory message)
        external
        payable
        returns (bytes32 msgHash);

    // Release Ether with a proof that the message processing on the destination
    // chain has been failed.
    function recallMessage(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external;

    /// Checks if a msgHash has been stored on the bridge contract by the
    /// current address.
    function isMessageSent(bytes32 msgHash) external view returns (bool);

    /// Checks if a msgHash has been received on the destination chain and
    /// sent by the src chain.
    function isMessageReceived(
        bytes32 msgHash,
        uint256 srcChainId,
        bytes calldata proof
    )
        external
        view
        returns (bool);

    /// Checks if a msgHash has been failed on the destination chain.
    function isMessageFailed(
        bytes32 msgHash,
        uint256 destChainId,
        bytes calldata proof
    )
        external
        view
        returns (bool);

    /// Returns the bridge state context.
    function context() external view returns (Context memory context);

    function hashMessage(IBridge.Message calldata message)
        external
        pure
        returns (bytes32);
}
