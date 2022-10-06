// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibBridgeData.sol";

contract TestLibBridgeData {
    function hashMessage(IBridge.Message memory message)
        public
        pure
        returns (bytes32)
    {
        return LibBridgeData.hashMessage(message);
    }

    function test(IBridge.Message memory message)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode("TAIKO_BRIDGE_MESSAGE", abi.encode(message));
    }

    // function updateMessageStatus(
    //     LibBridgeData.State memory state,
    //     bytes32 mhash,
    //     IBridge.MessageStatus status
    // ) public pure {
    //     LibBridgeData.updateMessageStatus(state, mhash, status);
    // }
}
