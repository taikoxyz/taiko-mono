// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/**
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeStatus {
    enum MessageStatus {
        NEW,
        RETRIABLE,
        DONE,
        FAILED
    }

    event MessageStatusChanged(bytes32 indexed signal, MessageStatus status);

    /**
     * @dev If messageStatus is same as in the messageStatus mapping,
     *      does nothing.
     * @param signal The messageHash of the message.
     * @param status The status of the message.
     */
    function updateMessageStatus(
        bytes32 signal,
        MessageStatus status
    ) internal {
        if (getMessageStatus(signal) != status) {
            _setMessageStatus(signal, status);
            emit LibBridgeStatus.MessageStatusChanged(signal, status);
        }
    }

    function getMessageStatus(
        bytes32 signal
    ) internal view returns (MessageStatus) {
        bytes32 key = _statusSlot(signal);
        uint256 v;
        assembly {
            v := sload(key)
        }
        return MessageStatus(v);
    }

    function _setMessageStatus(bytes32 signal, MessageStatus status) private {
        bytes32 key = _statusSlot(signal);
        uint256 v = uint256(status);
        assembly {
            sstore(key, v)
        }
    }

    function _statusSlot(bytes32 signal) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("status", signal));
    }
}
