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

/**
 * Stores message data for the bridge.
 *
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeData {
    /*********************
     * Structs           *
     *********************/
    enum MessageStatus {
        NEW,
        RETRIABLE,
        DONE,
        FAILED
    }

    struct State {
        // chainId => isEnabled
        mapping(uint256 => bool) destChains;
        uint256 nextMessageId;
        IBridge.Context ctx; // 3 slots
        uint256[45] __gap;
    }

    /*********************
     * Constants         *
     *********************/

    // TODO: figure out this value
    bytes32 internal constant SIGNAL_PLACEHOLDER = bytes32(uint256(1));
    uint256 internal constant CHAINID_PLACEHOLDER = type(uint256).max;
    address internal constant SRC_CHAIN_SENDER_PLACEHOLDER =
        0x0000000000000000000000000000000000000001;

    /*********************
     * Events            *
     *********************/

    // Note: These events must match the ones defined in Bridge.sol.
    event MessageSent(bytes32 indexed signal, IBridge.Message message);

    event MessageStatusChanged(bytes32 indexed signal, MessageStatus status);

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /*********************
     * Internal Functions*
     *********************/

    /**
     * @dev If messageStatus is same as in the messageStatus mapping,
     *      does nothing.
     * @param state The current bridge state.
     * @param signal The messageHash of the message.
     * @param status The status of the message.
     */
    function updateMessageStatus(
        State storage state,
        bytes32 signal,
        MessageStatus status
    ) internal {
        if (getMessageStatus(signal) != status) {
            _setMessageStatus(signal, status);
            emit LibBridgeData.MessageStatusChanged(signal, status);
        }
    }

    /**
     * @dev Hashes messages and returns the hash signed with
     * "TAIKO_BRIDGE_MESSAGE" for verification.
     */
    function hashMessage(
        IBridge.Message memory message
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_BRIDGE_MESSAGE", message));
    }

    function _messageStatusKey(bytes32 signal) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("status", signal));
    }

    function _setMessageStatus(bytes32 signal, MessageStatus status) private {
        bytes32 key = _messageStatusKey(signal);
        uint256 v = uint256(status);
        assembly {
            sstore(key, v)
        }
    }

    function getMessageStatus(
        bytes32 signal
    ) internal view returns (MessageStatus) {
        bytes32 key = _messageStatusKey(signal);
        uint256 v;
        assembly {
            v := sload(key)
        }
        return MessageStatus(v);
    }
}
