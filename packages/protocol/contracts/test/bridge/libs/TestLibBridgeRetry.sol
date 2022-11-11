// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../../common/EssentialContract.sol";
import "../../../bridge/libs/LibBridgeData.sol";
import "../../../bridge/libs/LibBridgeRetry.sol";

contract TestLibBridgeRetry is EssentialContract {
    LibBridgeData.State public state;

    receive() external payable {}

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function retryMessage(
        IBridge.Message calldata message,
        bool lastAttempt
    ) public payable {
        LibBridgeRetry.retryMessage(
            state,
            AddressResolver(this),
            message,
            lastAttempt
        );
    }
}
