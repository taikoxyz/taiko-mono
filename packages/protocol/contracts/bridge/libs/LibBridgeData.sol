// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../../libs/LibAddress.sol";
import "../../libs/LibMath.sol";
import "../IBridge.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeData {
    /*********************
     * Structs           *
     *********************/

    struct State {
        mapping(uint256 => bool) destChains;
        mapping(bytes32 => IBridge.MessageStatus) messageStatus;
        uint256 nextMessageId;
        IBridge.Context ctx; // 3 slots
        uint256[44] __gap;
    }

    /*********************
     * Constants         *
     *********************/

    // TODO: figure out this value
    uint256 internal constant MESSAGE_PROCESSING_OVERHEAD = 80000;
    uint256 internal constant CHAINID_PLACEHOLDER = type(uint256).max;
    address internal constant SRC_CHAIN_SENDER_PLACEHOLDER =
        0x0000000000000000000000000000000000000001;

    /*********************
     * Events            *
     *********************/

    // Note these events must match the one defined in Bridge.sol.
    event MessageSent(
        uint256 indexed height, // used for compute message proofs
        bytes32 indexed messageHash,
        Message message
    );

    event MessageStatusChanged(
        bytes32 indexed messageHash,
        IBridge.MessageStatus status
    );

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /*********************
     * Internal Functions*
     *********************/

    function hashMessage(Message memory message)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(message));
    }

    function updateMessageStatus(
        State storage state,
        bytes32 messageHash,
        IBridge.MessageStatus status
    ) internal {
        state.messageStatus[messageHash] = status;
        emit LibBridgeData.MessageStatusChanged(messageHash, status);
    }
}
