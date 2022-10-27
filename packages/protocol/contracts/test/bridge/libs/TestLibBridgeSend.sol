// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../../bridge/libs/LibBridgeSend.sol";

contract TestLibBridgeSend {
    LibBridgeData.State public state;

    function sendMessage(
        AddressResolver resolver,
        IBridge.Message memory message
    ) public returns (bytes32 signal) {
        return LibBridgeSend.sendMessage(state, resolver, message);
    }
    
    function enableDestChain(
        uint256 chainId,
        bool enabled
    ) public {
        LibBridgeSend.enableDestChain(state, chainId, enabled);
    }

    function getDestChainStatus(
        uint256 chainId
    ) public view returns (bool) {
        return state.destChains[chainId];
    }
}
