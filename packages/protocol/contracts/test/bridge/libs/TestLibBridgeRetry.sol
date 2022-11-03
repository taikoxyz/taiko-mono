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
import "../../../bridge/libs/LibBridgeRetry.sol";

contract TestLibBridgeRetry is EssentialContract {
    LibBridgeData.State public state;

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
        bytes32 signal = 0x9fb5e31aef639a9bc2a8ffeefa9c5dbb5d1e9a8aff5fb5fe479ed79b4fbf33df;
        state.messageStatus[signal] = LibBridgeData.MessageStatus.NEW;
    }

    function retryMessage(IBridge.Message calldata message, bool lastAttempt)
        public
    {
        LibBridgeRetry.retryMessage(
            state,
            AddressResolver(this),
            message,
            lastAttempt
        );
    }
}
