// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../../bridge/libs/LibBridgeData.sol";
import "../../../bridge/libs/LibBridgeStatus.sol";

contract TestLibBridgeData {
    function updateMessageStatus(
        bytes32 signal,
        LibBridgeStatus.MessageStatus status
    ) public {
        LibBridgeStatus.updateMessageStatus(signal, status);
    }

    function getMessageStatus(
        bytes32 signal
    ) public view returns (LibBridgeStatus.MessageStatus) {
        return LibBridgeStatus.getMessageStatus(signal);
    }

    function hashMessage(
        IBridge.Message memory message
    ) public pure returns (bytes32) {
        return LibBridgeData.hashMessage(message);
    }
}
