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

import "./LibBridgeSignal.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeSend {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    function sendMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message memory message
    ) internal returns (bytes32 signal) {
        require(message.owner != address(0), "B:owner");
        require(
            message.destChainId != block.chainid &&
                state.destChains[message.destChainId],
            "B:destChainId"
        );

        uint256 expectedAmount = message.depositValue +
            message.callValue +
            message.processingFee;
        require(expectedAmount == msg.value, "B:value");

        // For each message, expectedAmount is sent to ethVault to be handled.
        // Processing will retrieve these funds directly from ethVault.
        address ethVault = resolver.resolve("ether_vault");
        if (ethVault != address(0)) {
            ethVault.sendEther(expectedAmount);
        }

        message.id = state.nextMessageId++;
        message.sender = msg.sender;
        message.srcChainId = block.chainid;

        signal = message.hashMessage();
        LibBridgeSignal.sendSignal(address(this), signal);
        emit LibBridgeData.MessageSent(signal, message);
    }

    function enableDestChain(
        LibBridgeData.State storage state,
        uint256 chainId,
        bool enabled
    ) internal {
        require(chainId > 0 && chainId != block.chainid, "B:chainId");
        state.destChains[chainId] = enabled;
        emit LibBridgeData.DestChainEnabled(chainId, enabled);
    }
}
