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
        mapping(uint256 => mapping(uint256 => uint256)) statusBitmaps;
        uint256 nextMessageId;
        IBridge.Context ctx; // 4 slots
        uint256[43] __gap;
    }

    /*********************
     * Constants         *
     *********************/

    // TODO: figure out this value
    uint256 internal constant MESSAGE_PROCESSING_OVERHEAD = 80000;
    uint256 internal constant CHAINID_PLACEHOLDER = type(uint256).max;
    address internal constant SRC_CHAIN_SENDER_PLACEHOLDER =
        0x000000000000000000000000000000000000dEaD;

    /*********************
     * Events            *
     *********************/

    // Note these events must match the one defined in Bridge.sol.
    event MessageSent(
        bytes32 indexed messageHash,
        address indexed owner,
        uint256 srcChainId,
        uint256 id,
        uint256 height, // used for compute message proofs
        bytes message
    );

    event MessageStatusChanged(
        bytes32 indexed messageHash,
        address indexed owner,
        uint256 srcChainId,
        uint256 id,
        IBridge.MessageStatus status,
        bool succeeded
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
}
