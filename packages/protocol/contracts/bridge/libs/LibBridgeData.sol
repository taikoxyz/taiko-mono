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
        IBridge.Context ctx; // 2 slots
        uint256[45] __gap;
    }

    /*********************
     * Constants         *
     *********************/

    // TODO: figure out this value
    uint256 internal constant MESSAGE_PROCESSING_OVERHEAD = 80000;

    /*********************
     * Events            *
     *********************/

    // Note these events must match the one defined in Bridge.sol.
    event MessageSent(bytes32 indexed mhash, IBridge.Message message);

    event MessageStatusChanged(
        bytes32 indexed mhash,
        IBridge.MessageStatus status
    );

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /*********************
     * Internal Functions*
     *********************/
    function updateMessageStatus(
        State storage state,
        bytes32 mhash,
        IBridge.MessageStatus status
    ) internal {
        if (state.messageStatus[mhash] != status) {
            state.messageStatus[mhash] = status;
            emit LibBridgeData.MessageStatusChanged(mhash, status);
        }
    }

    function hashMessage(IBridge.Message memory message)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode("TAIKO_BRIDGE_MESSAGE", message));
    }
}
