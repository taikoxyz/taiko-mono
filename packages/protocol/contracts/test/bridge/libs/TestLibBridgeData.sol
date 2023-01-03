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

contract TestLibBridgeData {
    LibBridgeData.State public state;

    function updateMessageStatus(
        bytes32 signal,
        LibBridgeData.MessageStatus status
    ) public {
        LibBridgeData.updateMessageStatus(state, signal, status);
    }

    function getMessageStatus(
        bytes32 signal
    ) public view returns (LibBridgeData.MessageStatus) {
        return LibBridgeData.getMessageStatus(signal);
    }

    function hashMessage(
        IBridge.Message memory message
    ) public pure returns (bytes32) {
        return LibBridgeData.hashMessage(message);
    }
}
