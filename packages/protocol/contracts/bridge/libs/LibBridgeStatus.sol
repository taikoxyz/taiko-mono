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

    event MessageStatusChanged(bytes32 indexed msgHash, MessageStatus status);

    /**
     * @dev If messageStatus is same as in the messageStatus mapping,
     *      does nothing.
     * @param msgHash The messageHash of the message.
     * @param status The status of the message.
     */
    function updateMessageStatus(
        bytes32 msgHash,
        MessageStatus status
    ) internal {
        if (getMessageStatus(msgHash) != status) {
            _setMessageStatus(msgHash, status);
            emit LibBridgeStatus.MessageStatusChanged(msgHash, status);
        }
    }

    function getMessageStatus(
        bytes32 msgHash
    ) internal view returns (MessageStatus) {
        bytes32 k = _statusSlot(msgHash);
        uint256 v;
        assembly {
            v := sload(k)
        }
        return MessageStatus(v);
    }

    function _setMessageStatus(bytes32 msgHash, MessageStatus status) private {
        bytes32 k = _statusSlot(msgHash);
        uint256 v = uint256(status);
        assembly {
            sstore(k, v)
        }
    }

    function _statusSlot(bytes32 msgHash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("MESSAGE_STATUS", msgHash));
    }
}
