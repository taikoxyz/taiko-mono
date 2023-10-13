// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title BridgeData
/// @notice This library defines various data structures used by the Bridge
library BridgeData {
    enum Status {
        NEW,
        RETRIABLE,
        DONE,
        FAILED
    }

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
        // Destination address.
        address to;
        // Alternate address to send any refund. If blank, defaults to user.
        address refundTo;
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

    struct IntermediateProof {
        uint256 chainId;
        bytes32 signalRoot;
        bytes mkproof;
    }

    // Struct representing the context of a bridge operation.
    struct Context {
        bytes32 msgHash; // Message hash.
        address from; // Sender's address.
        uint256 srcChainId; // Source chain ID.
    }

    struct State {
        uint256 nextMessageId;
        Context ctx; // 3 slots
        mapping(bytes32 msgHash => bool recalled) recalls;
        mapping(bytes32 msgHash => Status) statuses;
        uint256[44] __gap;
    }

    bytes32 internal constant MESSAGE_HASH_PLACEHOLDER = bytes32(uint256(1));
    uint256 internal constant CHAINID_PLACEHOLDER = type(uint256).max;
    address internal constant SRC_CHAIN_SENDER_PLACEHOLDER =
        address(uint160(uint256(1)));
}
