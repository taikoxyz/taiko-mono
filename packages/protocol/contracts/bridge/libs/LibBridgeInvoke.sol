// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibBridgeData.sol";
import "./LibBridgeRead.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeInvoke {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;
    using LibBridgeRead for LibBridgeData.State;

    function invokeMessageCall(
        LibBridgeData.State storage state,
        IBridge.Message memory message,
        uint256 gasLimit
    ) internal returns (bool success) {
        require(gasLimit > 0, "B:gasLimit");

        (success, ) = message.to.call{value: message.callValue, gas: gasLimit}(
            message.data
        );
    }
}
